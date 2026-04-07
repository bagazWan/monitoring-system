from datetime import datetime
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

    if status:
        query = query.filter(Switch.status == status)

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


@router.get("/with-locations", response_model=List[SwitchWithLocation])
def get_switch_with_locations(db: Session = Depends(get_db)):
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
async def update_switch(
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

    update_data = switch_data.model_dump(exclude_unset=True)

    ip_in_payload = (
        "ip_address" in update_data and update_data["ip_address"] is not None
    )
    old_ip = (switch.ip_address or "").strip()
    new_ip = str(update_data.get("ip_address") or "").strip()
    ip_changed = ip_in_payload and (new_ip != old_ip)

    if ip_changed and switch.librenms_device_id:
        librenms = LibreNMSService()
        updated = await librenms.update_device_hostname(
            int(switch.librenms_device_id), new_ip
        )
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to update IP in LibreNMS. Local database was not changed.",
            )

        refreshed = await librenms.get_device_by_id(int(switch.librenms_device_id))
        switch.librenms_hostname = (
            (refreshed or {}).get("hostname") if refreshed else None
        ) or new_ip
        switch.librenms_last_synced = datetime.utcnow()

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
            print(f"Warning: Failed to delete from LibreNMS: {e}")

    db.delete(switch)
    db.commit()

    return None
