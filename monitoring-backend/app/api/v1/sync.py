from datetime import datetime

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Device, Switch, User
from app.schemas.device import AllDevicesSyncConfig, AllDevicesSyncReport
from app.services.alerts_service import sync_alerts_once
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

router = APIRouter(prefix="/sync", tags=["Sync"])


@router.post("/from-librenms", response_model=AllDevicesSyncReport)
async def sync_all_from_librenms(
    config: AllDevicesSyncConfig,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Import/sync all devices (include switch/hub) from LibreNMS into database

    This endpoint:
    1. Fetches all devices from LibreNMS API
    2. Creates new devices in database
    3. Updates existing devices
    4. Returns the report
    """
    librenms = LibreNMSService()
    report = {
        "created": [],
        "updated": [],
        "errors": [],
        "summary": {"total_created": 0, "total_updated": 0, "total_errors": 0},
    }
    # Get all from LibreNMS
    try:
        librenms_devices = await librenms.get_devices()

        for lnms_device in librenms_devices:
            try:
                sys_descr = lnms_device.get("sysDescr", "").lower()
                librenms_id = lnms_device["device_id"]
                if "switch" in sys_descr:
                    result = await _sync_switch(
                        db=db,
                        lnms_device=lnms_device,
                        librenms_id=librenms_id,
                        config=config,
                    )
                else:
                    result = await _sync_device(
                        db=db,
                        lnms_device=lnms_device,
                        librenms_id=librenms_id,
                        config=config,
                    )

                # Add result to report
                if result["action"] == "created":
                    report["created"].append(result["info"])
                    report["summary"]["total_created"] += 1
                elif result["action"] == "updated":
                    report["updated"].append(result["info"])
                    report["summary"]["total_updated"] += 1

            except Exception as e:
                # If error processing this specific device, log it and continue
                report["errors"].append(
                    {
                        "librenms_device_id": lnms_device.get("device_id"),
                        "hostname": lnms_device.get("hostname"),
                        "error": str(e),
                    }
                )
                report["summary"]["total_errors"] += 1

        db.commit()

    except Exception as e:
        # If overall sync fails, rollback everything
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync failed: {str(e)}",
        )

    return report


async def _sync_device(
    db: Session, lnms_device: dict, librenms_id: int, config: AllDevicesSyncConfig
) -> dict:
    """
    Sync a single device (non-switch/hub) to devices table
    """
    # Check if device already exists in database
    existing = (
        db.query(Device)
        .filter(
            or_(
                Device.librenms_device_id == librenms_id,
                Device.name == lnms_device.get("hostname"),
            )
        )
        .first()
    )

    if existing and config.update_existing:
        old_status = existing.status
        existing.librenms_hostname = lnms_device.get("hostname")
        existing.ip_address = lnms_device.get("ip", existing.ip_address)
        existing.mac_address = lnms_device.get("mac", existing.mac_address)
        existing.librenms_device_id = librenms_id
        existing.status = "online" if lnms_device.get("status") == 1 else "offline"
        existing.librenms_last_synced = datetime.now()

        if old_status != existing.status:
            try:
                from app.notifications import notify_all_channels

                await notify_all_channels(
                    {
                        "type": "status_update",
                        "device_id": existing.device_id,
                        "old_status": old_status,
                        "new_status": existing.status,
                        "timestamp": datetime.now().isoformat(),
                    }
                )
            except Exception as e:
                print(f"Failed to broadcast status update: {e}")

        return {
            "action": "updated",
            "info": {
                "device_id": existing.device_id,
                "name": existing.name,
                "ip_address": existing.ip_address,
                "type": "device",
            },
        }

    elif not existing:
        new_device = Device(
            name=lnms_device.get("hostname", lnms_device.get("ip")),
            ip_address=lnms_device.get("ip"),
            mac_address=lnms_device.get("mac"),
            device_type="unknown",  # Corrected manually via admin panel later
            location_id=config.default_location_id,  # Default location
            librenms_device_id=librenms_id,
            librenms_hostname=lnms_device.get("hostname"),
            status="online" if lnms_device.get("status") == 1 else "offline",
            librenms_last_synced=datetime.now(),
        )
        db.add(new_device)
        db.flush()  # Get device_id without committing

        return {
            "action": "created",
            "info": {
                "device_id": new_device.device_id,
                "name": new_device.name,
                "ip_address": new_device.ip_address,
                "type": "device",
            },
        }

    else:
        # Device exists but update_existing=False, so skip
        return {
            "action": "skipped",
            "info": {
                "device_id": existing.device_id,
                "name": existing.name,
                "reason": "update_existing is false",
            },
        }


async def _sync_switch(
    db: Session, lnms_device: dict, librenms_id: int, config: AllDevicesSyncConfig
) -> dict:
    """
    Sync a single switch/hub to switches table
    """

    # Check if switch already exists in database
    existing = (
        db.query(Switch).filter_by(librenms_device_id=librenms_id)
        | (Switch.name == lnms_device.get("hostname")).first()
    )

    if existing and config.update_existing:
        old_status = existing.status
        existing.librenms_hostname = lnms_device.get("hostname")
        existing.ip_address = lnms_device.get("ip", existing.ip_address)
        existing.status = "online" if lnms_device.get("status") == 1 else "offline"
        existing.librenms_device_id = librenms_id
        existing.librenms_last_synced = datetime.now()

        if old_status != existing.status:
            try:
                from app.notifications import notify_all_channels

                await notify_all_channels(
                    {
                        "type": "status_update",
                        "switch_id": existing.switch_id,
                        "old_status": old_status,
                        "new_status": existing.status,
                        "timestamp": datetime.now().isoformat(),
                    }
                )
            except Exception as e:
                print(f"Failed to broadcast status update: {e}")

        return {
            "action": "updated",
            "info": {
                "switch_id": existing.switch_id,
                "name": existing.name,
                "ip_address": existing.ip_address,
                "type": "switch",
            },
        }

    elif not existing:
        new_switch = Switch(
            name=lnms_device.get("hostname", lnms_device.get("ip")),
            ip_address=lnms_device.get("ip"),
            location_id=config.default_location_id,  # Default location
            librenms_device_id=librenms_id,
            librenms_hostname=lnms_device.get("hostname"),
            status="online" if lnms_device.get("status") == 1 else "offline",
            librenms_last_synced=datetime.now(),
        )
        db.add(new_switch)
        db.flush()  # Get switch_id without committing

        return {
            "action": "created",
            "info": {
                "switch_id": new_switch.switch_id,
                "name": new_switch.name,
                "ip_address": new_switch.ip_address,
                "type": "switch",
            },
        }

    else:
        # Switch exists but update_existing=False, so skip
        return {
            "action": "skipped",
            "info": {
                "switch_id": existing.switch_id,
                "name": existing.name,
                "reason": "update_existing is false",
            },
        }


@router.post("/alerts", status_code=status.HTTP_200_OK)
async def sync_alerts_now(
    current_user: User = Depends(require_admin),
):
    """
    Manual trigger to immediately fetch alerts from LibreNMS and process them.
    For testing, admin-triggered scans, or to force a sync.
    Returns:
        {"processed": <number_of_alerts_processed>}
    """
    librenms = LibreNMSService()
    try:
        processed = await sync_alerts_once(librenms)
    except Exception as exc:
        # Surface a 502 Bad Gateway if LibreNMS cannot be contacted or processing fails
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to sync alerts from LibreNMS: {str(exc)}",
        )

    return {"processed": processed}
