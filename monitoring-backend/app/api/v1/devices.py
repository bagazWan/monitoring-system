from typing import List, Optional

from app.api.dependencies import require_admin, require_technician_or_admin
from app.core.database import get_db
from app.models import Device, LibreNMSPort, Location, User
from app.schemas.device import (
    BulkLiveDetailsRequest,
    DeviceResponse,
    DeviceUpdate,
    DeviceWithLocation,
)
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/devices", tags=["Devices"])


async def _calculate_device_metrics(
    device: Device, db: Session, librenms: LibreNMSService
) -> dict:
    default_response = {
        "device_id": device.device_id,
        "status": device.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
        "monitored": False,
    }

    if not device.librenms_device_id:
        return default_response

    try:
        enabled_ports = (
            db.query(LibreNMSPort)
            .filter(
                LibreNMSPort.device_id == device.device_id,
                LibreNMSPort.enabled.is_(True),
            )
            .all()
        )

        total_in = 0.0
        total_out = 0.0

        if enabled_ports:
            for port_row in enabled_ports:
                try:
                    port_detail = await librenms.get_port_by_id(int(port_row.port_id))
                    p_list = port_detail.get("port", [])
                    if p_list:
                        p_data = p_list[0]
                        if (
                            int(p_data.get("disabled", 0) or 0) == 1
                            or int(p_data.get("ignore", 0) or 0) == 1
                        ):
                            continue

                        total_in += float(p_data.get("ifInOctets_rate", 0) or 0)
                        total_out += float(p_data.get("ifOutOctets_rate", 0) or 0)
                except Exception:
                    continue

        return {
            "device_id": device.device_id,
            "status": device.status,
            "in_mbps": round((total_in * 8) / 1_000_000, 2),
            "out_mbps": round((total_out * 8) / 1_000_000, 2),
            "monitored": True,
        }

    except Exception as e:
        print(f"Error calculating metrics for device {device.device_id}: {e}")
        return default_response


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
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    librenms = LibreNMSService()
    return await _calculate_device_metrics(device, db, librenms)


@router.post("/bulk-live-details")
async def get_bulk_device_details(
    payload: BulkLiveDetailsRequest, db: Session = Depends(get_db)
):
    librenms = LibreNMSService()
    results = []

    devices = db.query(Device).filter(Device.device_id.in_(payload.device_ids)).all()
    device_map = {d.device_id: d for d in devices}

    for device_id in payload.device_ids:
        device = device_map.get(device_id)
        if not device:
            continue

        metrics = await _calculate_device_metrics(device, db, librenms)
        results.append(metrics)

    return results


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


@router.patch("/{device_id}", response_model=DeviceResponse)
def update_device(
    device_id: int,
    device_data: DeviceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
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
