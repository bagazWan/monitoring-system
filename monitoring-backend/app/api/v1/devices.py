from datetime import datetime
from typing import List, Optional

from app.api.dependencies import require_admin, require_technician_or_admin
from app.core.database import get_db
from app.models import Device, LibreNMSPort, Location, User
from app.schemas.device import (
    DeviceResponse,
    DeviceUpdate,
    DeviceWithLocation,
)
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/devices", tags=["Devices"])


# get all registered device
@router.get("", response_model=List[DeviceResponse])
def get_all_devices(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Max records to return"),
    device_type: Optional[str] = Query(None, description="Filter by device type"),
    status: Optional[str] = Query(None, description="Filter by status"),
    db: Session = Depends(get_db),
):
    query = db.query(Device)

    # Apply filters if provided
    if device_type:
        query = query.filter(Device.device_type == device_type)
    if status:
        query = query.filter(Device.status == status)

    # Get devices with pagination
    devices = query.offset(skip).limit(limit).all()

    return devices


@router.get("/{device_id}/live-details")
async def get_device_live_details(device_id: int, db: Session = Depends(get_db)):
    device = db.query(Device).filter_by(device_id=device_id).first()
    if not device:
        raise HTTPException(404, "Device not found")

    if not device.librenms_device_id:
        return {
            "device_id": device.device_id,
            "status": device.status,
            "in_mbps": 0.0,
            "out_mbps": 0.0,
            "monitored": False,
            "message": "Device not connected to LibreNMS",
        }

    librenms = LibreNMSService()
    current_status = device.status

    try:
        lnms_device = await librenms.get_device_by_id(device.librenms_device_id)
        if lnms_device:
            new_status = "online" if lnms_device.get("status") == 1 else "offline"
            if device.status != new_status:
                device.status = new_status
                device.librenms_last_synced = datetime.utcnow()
                db.commit()
                current_status = new_status

        enabled_ports = (
            db.query(LibreNMSPort)
            .filter(
                LibreNMSPort.device_id == device.device_id,
                LibreNMSPort.enabled.is_(True),
            )
            .all()
        )

        if not enabled_ports:
            return {
                "device_id": device.device_id,
                "status": current_status,
                "in_mbps": 0.0,
                "out_mbps": 0.0,
                "monitored": True,
                "warning": "No enabled ports configured for this device (run sync or enable a port).",
                "last_seen": lnms_device.get("last_polled") if lnms_device else "N/A",
            }

        total_in_octets_rate = 0.0
        total_out_octets_rate = 0.0

        for port_row in enabled_ports:
            port_detail = await librenms.get_port_by_id(int(port_row.port_id))
            port_list = port_detail.get("port", [])
            if not port_list:
                continue

            port_data = port_list[0]

            # Skip disabled/ignored ports just in case (defensive)
            if (
                int(port_data.get("disabled", 0) or 0) == 1
                or int(port_data.get("ignore", 0) or 0) == 1
            ):
                continue

            total_in_octets_rate += float(port_data.get("ifInOctets_rate", 0) or 0)
            total_out_octets_rate += float(port_data.get("ifOutOctets_rate", 0) or 0)

        in_mbps = (total_in_octets_rate * 8) / 1_000_000
        out_mbps = (total_out_octets_rate * 8) / 1_000_000

        return {
            "device_id": device.device_id,
            "status": current_status,
            "in_mbps": round(in_mbps, 2),
            "out_mbps": round(out_mbps, 2),
            "last_seen": lnms_device.get("last_polled") if lnms_device else "N/A",
        }

    except Exception as e:
        return {
            "device_id": device.device_id,
            "status": device.status,
            "in_mbps": 0.0,
            "out_mbps": 0.0,
            "error": str(e),
        }


# Get devices with location data for map display
@router.get("/with-locations", response_model=List[DeviceWithLocation])
def get_devices_with_locations(db: Session = Depends(get_db)):
    # Join Device and Location tables
    results = (
        db.query(Device, Location)
        .join(Location, Device.location_id == Location.location_id)
        .all()
    )

    # Format response
    devices_with_locations = []
    for device, location in results:
        devices_with_locations.append(
            {
                "device_id": device.device_id,
                "name": device.name,
                "ip_address": device.ip_address,
                "mac_address": device.mac_address,
                "device_type": device.device_type,
                "status": device.status,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "location_name": location.name,
                "description": device.description,
                "last_replaced_at": device.last_replaced_at,
            }
        )

    return devices_with_locations


# Get single device
@router.get("/{device_id}", response_model=DeviceResponse)
def get_device(device_id: int, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with id {device_id} not found",
        )

    return device


# Update device
@router.patch("/{device_id}", response_model=DeviceResponse)
def update_device(
    device_id: int,
    device_data: DeviceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    # Find device
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with id {device_id} not found",
        )

    # Update only provided fields
    update_data = device_data.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(device, field, value)

    db.commit()
    db.refresh(device)

    return device


# Delete device
@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with id {device_id} not found",
        )

    if device.librenms_device_id:
        try:
            librenms = LibreNMSService()
            await librenms.delete_device(int(device.librenms_device_id))
        except Exception as e:
            # Log error but proceed with DB deletion
            print(f"Warning: Failed to delete from LibreNMS: {e}")

    db.delete(device)
    db.commit()

    return None
