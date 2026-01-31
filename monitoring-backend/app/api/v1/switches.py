from datetime import datetime
from typing import List, Optional

from app.api.dependencies import require_admin, require_technician_or_admin
from app.core.database import get_db
from app.models import Location, Switch, User
from app.models.librenms_port import LibreNMSPort
from app.schemas.switch import (
    SwitchCreate,
    SwitchResponse,
    SwitchUpdate,
    SwitchWithLocation,
)
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/switches", tags=["Switches"])


# get all registered switches
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
    switch = db.query(Switch).filter_by(switch_id=switch_id).first()
    if not switch:
        raise HTTPException(status_code=404, detail="Switch not found")

    if not switch.librenms_device_id:
        return {
            "switch_id": switch.switch_id,
            "status": switch.status,
            "in_mbps": 0.0,
            "out_mbps": 0.0,
            "monitored": False,
            "message": "Switch not connected to LibreNMS",
        }

    librenms = LibreNMSService()
    current_status = switch.status

    try:
        lnms_device = await librenms.get_device_by_id(switch.librenms_device_id)
        if lnms_device:
            new_status = "online" if lnms_device.get("status") == 1 else "offline"
            if switch.status != new_status:
                switch.status = new_status
                switch.librenms_last_synced = datetime.utcnow()
                db.commit()
                current_status = new_status

        # Prefer uplink ports if configured
        uplink_ports = (
            db.query(LibreNMSPort)
            .filter(
                LibreNMSPort.switch_id == switch.switch_id,
                LibreNMSPort.enabled.is_(True),
                LibreNMSPort.is_uplink.is_(True),
            )
            .all()
        )

        used_ports = uplink_ports
        warning = None

        if not used_ports:
            used_ports = (
                db.query(LibreNMSPort)
                .filter(
                    LibreNMSPort.switch_id == switch.switch_id,
                    LibreNMSPort.enabled.is_(True),
                )
                .all()
            )
            if used_ports:
                warning = "No uplink ports configured; using all enabled ports (may be misleading/double-count)."
            else:
                warning = "No enabled ports configured for this switch (run sync or enable a port)."

        total_in_octets_rate = 0.0
        total_out_octets_rate = 0.0

        for port_row in used_ports:
            port_detail = await librenms.get_port_by_id(int(port_row.port_id))
            port_list = port_detail.get("port", [])
            if not port_list:
                continue

            port_data = port_list[0]

            if (
                int(port_data.get("disabled", 0) or 0) == 1
                or int(port_data.get("ignore", 0) or 0) == 1
            ):
                continue

            total_in_octets_rate += float(port_data.get("ifInOctets_rate", 0) or 0)
            total_out_octets_rate += float(port_data.get("ifOutOctets_rate", 0) or 0)

        in_mbps = (total_in_octets_rate * 8) / 1_000_000
        out_mbps = (total_out_octets_rate * 8) / 1_000_000

        response = {
            "switch_id": switch.switch_id,
            "name": switch.name,
            "status": current_status,
            "in_mbps": round(in_mbps, 2),
            "out_mbps": round(out_mbps, 2),
            "total_mbps": round(in_mbps + out_mbps, 2),
            "last_seen": lnms_device.get("last_polled") if lnms_device else "N/A",
            "uplink_mode": bool(uplink_ports),
            "ports_used": len(used_ports),
        }
        if warning:
            response["warning"] = warning
        return response

    except Exception as e:
        return {
            "switch_id": switch.switch_id,
            "status": switch.status,
            "in_mbps": 0.0,
            "out_mbps": 0.0,
            "error": str(e),
        }


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


# Create new switch by manual input
@router.post("", response_model=SwitchResponse, status_code=status.HTTP_201_CREATED)
def create_switch(
    switch_data: SwitchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    # Check if IP address already exists
    existing_switch = (
        db.query(Switch).filter(Switch.ip_address == switch_data.ip_address).first()
    )

    if existing_switch:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Switch with IP address {switch_data.ip_address} already exists",
        )

    if switch_data.location_id is not None:
        location = (
            db.query(Location)
            .filter(Location.location_id == switch_data.location_id)
            .first()
        )
        if not location:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Location with id {switch_data.location_id} not found",
            )

    # Create new switch
    new_switch = Switch(**switch_data.model_dump())

    db.add(new_switch)
    db.commit()
    db.refresh(new_switch)

    return new_switch


# Update switch
@router.patch("/{switch_id}", response_model=SwitchResponse)
def update_switch(
    switch_id: int,
    switch_data: SwitchUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    # Find switch
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


# Delete switch
@router.delete("/{switch_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_switch(
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

    db.delete(switch)
    db.commit()

    return None
