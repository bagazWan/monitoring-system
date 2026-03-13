from typing import List, Optional

from app.api.dependencies import require_admin, require_technician_or_admin
from app.core.database import get_db
from app.models import Location, Switch, User
from app.schemas.switch import (
    BulkSwitchDetailsRequest,
    SwitchResponse,
    SwitchUpdate,
    SwitchWithLocation,
)
from app.services.librenms_service import LibreNMSService
from app.services.node_metrics import calculate_switch_metrics
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/switches", tags=["Switches"])


@router.get("", response_model=List[SwitchResponse])
def get_all_switches(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Max records to return"),
    status: Optional[str] = Query(None, description="Filter by status"),
    db: Session = Depends(get_db),
):
    query = db.query(Switch)

    # Apply filters if provided
    if status:
        query = query.filter(Switch.status == status)

    # Get switches with pagination
    switches = query.offset(skip).limit(limit).all()

    return switches


@router.get("/{switch_id}/live-details")
async def get_switch_live_details(switch_id: int, db: Session = Depends(get_db)):
    switch = db.query(Switch).filter(Switch.switch_id == switch_id).first()
    if not switch:
        raise HTTPException(status_code=404, detail="Switch not found")

    librenms = LibreNMSService()
    return await calculate_switch_metrics(switch, db, librenms)


@router.post("/bulk-live-details")
async def get_bulk_switch_details(
    payload: BulkSwitchDetailsRequest, db: Session = Depends(get_db)
):
    librenms = LibreNMSService()
    results = []

    switches = db.query(Switch).filter(Switch.switch_id.in_(payload.switch_ids)).all()
    switch_map = {s.switch_id: s for s in switches}

    for switch_id in payload.switch_ids:
        switch = switch_map.get(switch_id)
        if not switch:
            continue
        metrics = await calculate_switch_metrics(switch, db, librenms)
        results.append(metrics)

    return results


# get switch by location for map display
@router.get("/with-locations", response_model=List[SwitchWithLocation])
def get_switch_with_locations(db: Session = Depends(get_db)):
    # Join Switch and Location tables
    results = (
        db.query(Switch, Location)
        .join(Location, Switch.location_id == Location.location_id)
        .all()
    )

    switches_with_locations = []
    for switch, location in results:
        switches_with_locations.append(
            {
                "switch_id": switch.switch_id,
                "name": switch.name,
                "ip_address": switch.ip_address,
                "status": switch.status,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "location_name": location.name,
                "description": switch.description,
                "last_replaced_at": switch.last_replaced_at,
            }
        )

    return switches_with_locations


# Get single switch
@router.get("/{switch_id}", response_model=SwitchResponse)
def get_switch(switch_id: int, db: Session = Depends(get_db)):
    switch = db.query(Switch).filter(Switch.switch_id == switch_id).first()
    if not switch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Switch with id {switch_id} not found",
        )

    return switch


@router.patch("/{switch_id}", response_model=SwitchResponse)
def update_switch(
    switch_id: int,
    switch_data: SwitchUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    switch = db.query(Switch).filter(Switch.switch_id == switch_id).first()

    if not switch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Switch with id {switch_id} not found",
        )

    # Update only provided fields
    update_data = switch_data.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(switch, field, value)

    db.commit()
    db.refresh(switch)

    return switch


@router.delete("/{switch_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_switch(
    switch_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    switch = db.query(Switch).filter(Switch.switch_id == switch_id).first()

    if not switch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Switch with id {switch_id} not found",
        )

    if switch.librenms_device_id:
        try:
            librenms = LibreNMSService()
            await librenms.delete_device(int(switch.librenms_device_id))
        except Exception as e:
            # Log error but proceed with DB deletion
            print(f"Warning: Failed to delete from LibreNMS: {e}")

    db.delete(switch)
    db.commit()

    return None
