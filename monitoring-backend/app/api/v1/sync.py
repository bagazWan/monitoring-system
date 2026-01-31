from datetime import datetime
from typing import Optional, Tuple

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Device, LibreNMSPort, Switch, User
from app.schemas.device import AllDevicesSyncConfig, AllDevicesSyncReport
from app.services.alerts_service import sync_alerts_once
from app.services.librenms_ports_service import discover_and_store_ports_for
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/sync", tags=["Sync"])


def _pick_display_name(lnms_device: dict) -> str:
    """
    Display name from LibreNMS payload.
    Priority: sysName -> hostname -> ip
    """
    sys_name = (lnms_device.get("sysName") or "").strip()
    hostname = (lnms_device.get("hostname") or "").strip()
    ip = (lnms_device.get("ip") or "").strip()
    return sys_name or hostname or ip or "Unknown"


def _safe_set_device_ip(
    db: Session, device: Device, new_ip: Optional[str]
) -> Optional[str]:
    """
    Update device.ip_address from LibreNMS if it does not conflict with another device. If it conflicts, do not update
    """
    if not new_ip:
        return None
    new_ip = str(new_ip).strip()
    if not new_ip or device.ip_address == new_ip:
        return None

    conflict = db.query(Device).filter(Device.ip_address == new_ip).first()
    if conflict and conflict.device_id != device.device_id:
        return f"ip_address conflict: {new_ip} already used by device_id={conflict.device_id}; kept old ip {device.ip_address}"

    device.ip_address = new_ip
    return None


def _safe_set_switch_ip(
    db: Session, switch: Switch, new_ip: Optional[str]
) -> Optional[str]:
    """
    Same idea as devices, but for switches.
    """
    if not new_ip:
        return None
    new_ip = str(new_ip).strip()
    if not new_ip or switch.ip_address == new_ip:
        return None

    conflict = db.query(Switch).filter(Switch.ip_address == new_ip).first()
    if conflict and conflict.switch_id != switch.switch_id:
        return f"ip_address conflict: {new_ip} already used by switch_id={conflict.switch_id}; kept old ip {switch.ip_address}"

    switch.ip_address = new_ip
    return None


def _find_existing_device(
    db: Session,
    librenms_id: int,
    ip: Optional[str],
    hostname: Optional[str],
) -> Tuple[Optional[Device], Optional[str]]:
    """
    Idempotent matching order:
    1. librenms_device_id
    2. ip_address
    3. librenms_hostname
    Returns: (device or None, match_reason)
    """
    existing = db.query(Device).filter(Device.librenms_device_id == librenms_id).first()
    if existing:
        return existing, "librenms_device_id"

    if ip:
        existing = db.query(Device).filter(Device.ip_address == ip).first()
        if existing:
            return existing, "ip_address"

    if hostname:
        existing = db.query(Device).filter(Device.librenms_hostname == hostname).first()
        if existing:
            return existing, "librenms_hostname"

    return None, None


def _find_existing_switch(
    db: Session,
    librenms_id: int,
    ip: Optional[str],
    hostname: Optional[str],
) -> Tuple[Optional[Switch], Optional[str]]:
    """
    Same matching for switches.
    """
    existing = db.query(Switch).filter(Switch.librenms_device_id == librenms_id).first()
    if existing:
        return existing, "librenms_device_id"

    if ip:
        existing = db.query(Switch).filter(Switch.ip_address == ip).first()
        if existing:
            return existing, "ip_address"

    if hostname:
        existing = db.query(Switch).filter(Switch.librenms_hostname == hostname).first()
        if existing:
            return existing, "librenms_hostname"

    return None, None


@router.post("/from-librenms", response_model=AllDevicesSyncReport)
async def sync_all_from_librenms(
    config: AllDevicesSyncConfig,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    librenms = LibreNMSService()
    report: dict = {
        "created": [],
        "updated": [],
        "errors": [],
        "summary": {"total_created": 0, "total_updated": 0, "total_errors": 0},
    }

    try:
        librenms_devices = await librenms.get_devices()

        for lnms_device in librenms_devices:
            try:
                sys_descr = (lnms_device.get("sysDescr") or "").lower()
                librenms_id = int(lnms_device["device_id"])
                hostname = lnms_device.get("hostname")
                ip = lnms_device.get("ip")

                # Less aggressive splitting:
                should_sync_as_switch = ("switch" in sys_descr) and (
                    "routeros" not in sys_descr
                )

                if should_sync_as_switch:
                    result = await _sync_switch(
                        db=db,
                        librenms=librenms,
                        lnms_device=lnms_device,
                        librenms_id=librenms_id,
                        config=config,
                    )
                else:
                    result = await _sync_device(
                        db=db,
                        librenms=librenms,
                        lnms_device=lnms_device,
                        librenms_id=librenms_id,
                        config=config,
                    )

                if result["action"] == "created":
                    report["created"].append(result["info"])
                    report["summary"]["total_created"] += 1
                elif result["action"] == "updated":
                    report["updated"].append(result["info"])
                    report["summary"]["total_updated"] += 1

            except Exception as e:
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
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync failed: {str(e)}",
        )

    return report


async def _sync_device(
    *,
    db: Session,
    librenms: LibreNMSService,
    lnms_device: dict,
    librenms_id: int,
    config: AllDevicesSyncConfig,
) -> dict:
    conflict_switch = (
        db.query(Switch).filter(Switch.librenms_device_id == librenms_id).first()
    )
    if conflict_switch:
        raise Exception(
            f"librenms_device_id {librenms_id} already exists in switches "
            f"(switch_id={conflict_switch.switch_id}, name={conflict_switch.name}). "
            f"Cannot sync into devices."
        )

    display_name = _pick_display_name(lnms_device)
    hostname = lnms_device.get("hostname")
    ip = lnms_device.get("ip")

    existing, match_reason = _find_existing_device(db, librenms_id, ip, hostname)

    if existing and config.update_existing:
        old_status = existing.status

        existing.name = display_name
        existing.librenms_hostname = hostname
        ip_warning = _safe_set_device_ip(db, existing, ip)
        existing.mac_address = lnms_device.get("mac", existing.mac_address)
        existing.librenms_device_id = librenms_id
        existing.status = "online" if lnms_device.get("status") == 1 else "offline"
        existing.librenms_last_synced = datetime.now()

        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=librenms_id,
            device=existing,
        )

        info = {
            "device_id": existing.device_id,
            "name": existing.name,
            "ip_address": existing.ip_address,
            "type": "device",
        }
        if ip_warning:
            info["warning"] = ip_warning
        if match_reason and match_reason != "librenms_device_id":
            info["matched_by"] = match_reason

        return {"action": "updated", "info": info}

    if not existing:
        new_device = Device(
            name=display_name,
            ip_address=ip,
            mac_address=lnms_device.get("mac"),
            device_type="unknown",
            location_id=config.default_location_id,
            librenms_device_id=librenms_id,
            librenms_hostname=hostname,
            status="online" if lnms_device.get("status") == 1 else "offline",
            librenms_last_synced=datetime.now(),
        )
        db.add(new_device)
        db.flush()

        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=librenms_id,
            device=new_device,
        )

        return {
            "action": "created",
            "info": {
                "device_id": new_device.device_id,
                "name": new_device.name,
                "ip_address": new_device.ip_address,
                "type": "device",
            },
        }

    return {
        "action": "skipped",
        "info": {
            "device_id": existing.device_id,
            "name": existing.name,
            "reason": "update_existing is false",
        },
    }


async def _sync_switch(
    *,
    db: Session,
    librenms: LibreNMSService,
    lnms_device: dict,
    librenms_id: int,
    config: AllDevicesSyncConfig,
) -> dict:
    conflict_device = (
        db.query(Device).filter(Device.librenms_device_id == librenms_id).first()
    )
    if conflict_device:
        raise Exception(
            f"librenms_device_id {librenms_id} already exists in devices "
            f"(device_id={conflict_device.device_id}, name={conflict_device.name}). "
            f"Cannot sync into switches."
        )

    display_name = _pick_display_name(lnms_device)
    hostname = lnms_device.get("hostname")
    ip = lnms_device.get("ip")

    existing, match_reason = _find_existing_switch(db, librenms_id, ip, hostname)

    if existing and config.update_existing:
        old_status = existing.status
        existing.name = display_name
        existing.librenms_hostname = hostname
        ip_warning = _safe_set_switch_ip(db, existing, ip)
        existing.librenms_device_id = librenms_id
        existing.status = "online" if lnms_device.get("status") == 1 else "offline"
        existing.librenms_last_synced = datetime.now()

        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=librenms_id,
            switch=existing,
        )

        info = {
            "switch_id": existing.switch_id,
            "name": existing.name,
            "ip_address": existing.ip_address,
            "type": "switch",
        }
        if ip_warning:
            info["warning"] = ip_warning
        if match_reason and match_reason != "librenms_device_id":
            info["matched_by"] = match_reason

        return {"action": "updated", "info": info}

    if not existing:
        new_switch = Switch(
            name=display_name,
            ip_address=ip,
            location_id=config.default_location_id,
            librenms_device_id=librenms_id,
            librenms_hostname=hostname,
            status="online" if lnms_device.get("status") == 1 else "offline",
            librenms_last_synced=datetime.now(),
        )
        db.add(new_switch)
        db.flush()

        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=librenms_id,
            switch=new_switch,
        )

        return {
            "action": "created",
            "info": {
                "switch_id": new_switch.switch_id,
                "name": new_switch.name,
                "ip_address": new_switch.ip_address,
                "type": "switch",
            },
        }

    return {
        "action": "skipped",
        "info": {
            "switch_id": existing.switch_id,
            "name": existing.name,
            "reason": "update_existing is false",
        },
    }


@router.post("/alerts", status_code=status.HTTP_200_OK)
async def sync_alerts_now(current_user: User = Depends(require_admin)):
    librenms = LibreNMSService()
    try:
        processed = await sync_alerts_once(librenms)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to sync alerts from LibreNMS: {str(exc)}",
        )
    return {"processed": processed}
