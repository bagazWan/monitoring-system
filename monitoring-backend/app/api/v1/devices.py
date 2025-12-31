from datetime import datetime
from typing import List, Optional

from app.api.dependencies import require_admin, require_technician_or_admin
from app.core.database import get_db
from app.models import Device, Location, User
from app.schemas.device import (
    DeviceCreate,
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


@router.get("/{device_id}/bandwidth/current")
async def get_device_bandwidth(device_id: int, db: Session = Depends(get_db)):
    """
    Get real-time bandwidth from LibreNMS for a device
    """
    device = db.query(Device).filter_by(device_id=device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Device not found"
        )

    if not device.librenms_device_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Device is not monitored by LibreNMS. Cannot fetch bandwidth.",
        )

    try:
        librenms = LibreNMSService()
        port_stats = await librenms.get_device_port_stats(device.librenms_device_id)

        # Aggregate bandwidth from all ports
        total_in = 0.0
        total_out = 0.0

        for port in port_stats.get("ports", []):
            # Convert bytes/sec to Mbps
            in_rate = port.get("ifInOctets_rate", 0) * 8 / 1_000_000
            out_rate = port.get("ifOutOctets_rate", 0) * 8 / 1_000_000
            total_in += in_rate
            total_out += out_rate

        return {
            "device_id": device.device_id,
            "device_name": device.name,
            "timestamp": datetime.now(),
            "in_mbps": round(total_in, 2),
            "out_mbps": round(total_out, 2),
            "total_mbps": round(total_in + total_out, 2),
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to fetch bandwidth from LibreNMS: {str(e)}",
        )


@router.get("/{device_id}/status")
async def check_device_status(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    """
    Check device status from LibreNMS
    """
    device = db.query(Device).filter_by(device_id=device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Device not found"
        )

    if not device.librenms_device_id:
        return {
            "device_id": device.device_id,
            "status": device.status,
            "monitored": False,
            "message": "Device not linked to LibreNMS",
        }

    try:
        librenms = LibreNMSService()
        lnms_device = await librenms.get_device_by_id(device.librenms_device_id)

        if lnms_device:
            librenms_status = "online" if lnms_device.get("status") == 1 else "offline"

            # Update database
            device.status = librenms_status
            device.librenms_last_synced = datetime.now()
            db.commit()

            return {
                "device_id": device.device_id,
                "status": librenms_status,
                "monitored": True,
                "last_seen": lnms_device.get("last_polled"),
            }
    except Exception as e:
        return {
            "device_id": device.device_id,
            "status": device.status,
            "monitored": True,
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
                "device_type": device.device_type,
                "status": device.status,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "location_name": location.name,
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


# Create new device by manual input
@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
def create_device(
    device_data: DeviceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    # Check if IP address already exists
    existing_device = (
        db.query(Device).filter(Device.ip_address == device_data.ip_address).first()
    )

    if existing_device:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Device with IP address {device_data.ip_address} already exists",
        )

    if device_data.location_id is not None:
        location = (
            db.query(Location)
            .filter(Location.location_id == device_data.location_id)
            .first()
        )
        if not location:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Location with id {device_data.location_id} not found",
            )

    # Create new device
    new_device = Device(**device_data.model_dump())

    db.add(new_device)
    db.commit()
    db.refresh(new_device)

    return new_device


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
def delete_device(
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

    db.delete(device)
    db.commit()

    return None
