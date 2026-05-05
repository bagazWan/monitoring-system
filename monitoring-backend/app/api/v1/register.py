import logging
from datetime import datetime

from app.api.dependencies import require_technician_or_admin
from app.core.database import get_db
from app.models import Device, LibreNMSPort, Location, Switch, User
from app.schemas.device import LibreNMSRegisterRequest
from app.services.librenms.client import LibreNMSService
from app.services.librenms.register import (
    infer_node_type_from_sysdescr,
    safe_discover_ports,
    schedule_port_retry_if_needed,
)
from app.services.normalizer import normalize_node_type
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/register", tags=["Register"])
logger = logging.getLogger(__name__)


@router.post("/librenms")
async def register_in_librenms(
    payload: LibreNMSRegisterRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    librenms = LibreNMSService()

    librenms_device_id = await librenms.add_device(
        hostname=payload.hostname,
        community=payload.community,
        snmp_version=payload.snmp_version,
        port=payload.port,
        transport=payload.transport,
        force_add=payload.force_add,
        snmp_enabled=payload.snmp_enabled,
    )
    if not librenms_device_id:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to add device to LibreNMS",
        )

    lnms_device = await librenms.get_device_by_id(librenms_device_id)
    if not lnms_device:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"LibreNMS device {librenms_device_id} added but cannot be fetched",
        )

    hostname = (lnms_device.get("hostname") or payload.hostname or "").strip()
    ip = (lnms_device.get("ip") or payload.hostname or "").strip()
    sys_name = (lnms_device.get("sysName") or "").strip()
    sys_descr = (lnms_device.get("sysDescr") or "").strip()

    inferred_type = infer_node_type_from_sysdescr(sys_descr)
    node_type = normalize_node_type(payload.node_type) or inferred_type

    if payload.location_id is not None:
        loc = (
            db.query(Location)
            .filter(Location.location_id == payload.location_id)
            .first()
        )
        if not loc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Location with id {payload.location_id} not found",
            )

    display_name = (
        payload.name or sys_name or hostname or ip or ""
    ).strip() or f"LNMS-{librenms_device_id}"

    if node_type == "switch":
        existing = (
            db.query(Switch)
            .filter(Switch.librenms_device_id == int(librenms_device_id))
            .first()
        )
        if not existing:
            existing = db.query(Switch).filter(Switch.ip_address == ip).first()

        if existing:
            existing.ip_address = ip
            existing.name = display_name
            existing.location_id = (
                payload.location_id
                if payload.location_id is not None
                else existing.location_id
            )
            existing.node_id = (
                payload.node_id if payload.node_id is not None else existing.node_id
            )
            existing.description = (
                payload.description
                if payload.description is not None
                else existing.description
            )
            existing.status = "online" if lnms_device.get("status") == 1 else "offline"
            existing.librenms_device_id = int(librenms_device_id)
            existing.librenms_hostname = hostname
            existing.librenms_last_synced = datetime.utcnow()
            db.commit()
            db.refresh(existing)

            ports_discovered = False
            warning = None
            if payload.snmp_enabled:
                ports_discovered, warning = await safe_discover_ports(
                    db=db,
                    librenms=librenms,
                    librenms_device_id=int(librenms_device_id),
                    switch=existing,
                )

            schedule_port_retry_if_needed(
                payload=payload,
                ports_discovered=ports_discovered,
                node_type="switch",
                local_id=existing.switch_id,
                librenms_device_id=int(librenms_device_id),
            )

            return {
                "status": "ok",
                "node_type": "switch",
                "switch_id": existing.switch_id,
                "librenms_device_id": existing.librenms_device_id,
                "name": existing.name,
                "ip_address": existing.ip_address,
                "ports_discovered": ports_discovered if payload.snmp_enabled else None,
                "warning": warning,
            }

        new_switch = Switch(
            name=display_name,
            ip_address=ip,
            location_id=payload.location_id,
            node_id=payload.node_id,
            status="online" if lnms_device.get("status") == 1 else "offline",
            description=payload.description,
            librenms_device_id=int(librenms_device_id),
            librenms_hostname=hostname,
            librenms_last_synced=datetime.utcnow(),
        )
        db.add(new_switch)
        db.commit()
        db.refresh(new_switch)

        ports_discovered = False
        warning = None
        if payload.snmp_enabled:
            ports_discovered, warning = await safe_discover_ports(
                db=db,
                librenms=librenms,
                librenms_device_id=int(librenms_device_id),
                switch=new_switch,
            )

        schedule_port_retry_if_needed(
            payload=payload,
            ports_discovered=ports_discovered,
            node_type="switch",
            local_id=new_switch.switch_id,
            librenms_device_id=int(librenms_device_id),
        )

        return {
            "status": "ok",
            "node_type": "switch",
            "switch_id": new_switch.switch_id,
            "librenms_device_id": new_switch.librenms_device_id,
            "name": new_switch.name,
            "ip_address": new_switch.ip_address,
            "ports_discovered": ports_discovered if payload.snmp_enabled else None,
            "warning": warning,
        }

    existing = (
        db.query(Device)
        .filter(Device.librenms_device_id == int(librenms_device_id))
        .first()
    )
    if not existing:
        existing = db.query(Device).filter(Device.ip_address == ip).first()

    if existing:
        existing.ip_address = ip
        existing.name = display_name
        existing.location_id = (
            payload.location_id
            if payload.location_id is not None
            else existing.location_id
        )
        existing.switch_id = (
            payload.switch_id if payload.switch_id is not None else existing.switch_id
        )
        existing.device_type = (
            payload.device_type
            if payload.device_type is not None
            else existing.device_type
        )
        existing.description = (
            payload.description
            if payload.description is not None
            else existing.description
        )
        existing.status = "online" if lnms_device.get("status") == 1 else "offline"
        existing.librenms_device_id = int(librenms_device_id)
        existing.librenms_hostname = hostname
        existing.librenms_last_synced = datetime.utcnow()
        db.commit()
        db.refresh(existing)

        ports_discovered = False
        warning = None
        if payload.snmp_enabled:
            ports_discovered, warning = await safe_discover_ports(
                db=db,
                librenms=librenms,
                librenms_device_id=int(librenms_device_id),
                device=existing,
            )

        schedule_port_retry_if_needed(
            payload=payload,
            ports_discovered=ports_discovered,
            node_type="device",
            local_id=existing.device_id,
            librenms_device_id=int(librenms_device_id),
        )

        return {
            "status": "ok",
            "node_type": "device",
            "device_id": existing.device_id,
            "librenms_device_id": existing.librenms_device_id,
            "name": existing.name,
            "ip_address": existing.ip_address,
            "ports_discovered": ports_discovered if payload.snmp_enabled else None,
            "warning": warning,
        }

    new_device = Device(
        name=display_name,
        ip_address=ip,
        mac_address=lnms_device.get("mac"),
        device_type=payload.device_type or "unknown",
        location_id=payload.location_id,
        switch_id=payload.switch_id,
        status="online" if lnms_device.get("status") == 1 else "offline",
        description=payload.description,
        librenms_device_id=int(librenms_device_id),
        librenms_hostname=hostname,
        librenms_last_synced=datetime.utcnow(),
    )
    db.add(new_device)
    db.commit()
    db.refresh(new_device)

    ports_discovered = False
    warning = None
    if payload.snmp_enabled:
        ports_discovered, warning = await safe_discover_ports(
            db=db,
            librenms=librenms,
            librenms_device_id=int(librenms_device_id),
            device=new_device,
        )

    schedule_port_retry_if_needed(
        payload=payload,
        ports_discovered=ports_discovered,
        node_type="device",
        local_id=new_device.device_id,
        librenms_device_id=int(librenms_device_id),
    )

    return {
        "status": "ok",
        "node_type": "device",
        "device_id": new_device.device_id,
        "librenms_device_id": new_device.librenms_device_id,
        "name": new_device.name,
        "ip_address": new_device.ip_address,
        "ports_discovered": ports_discovered if payload.snmp_enabled else None,
        "warning": warning,
    }


@router.delete("/librenms/{node_type}/{local_id}")
async def unregister_from_librenms(
    node_type: str,
    local_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    nt = node_type.strip().lower()
    if nt not in {"device", "switch"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='node_type must be "device" or "switch"',
        )

    librenms = LibreNMSService()

    if nt == "switch":
        sw = db.query(Switch).filter(Switch.switch_id == local_id).first()
        if not sw:
            raise HTTPException(status_code=404, detail="Switch not found")

        if not sw.librenms_device_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Switch is not connected to LibreNMS",
            )

        lnms_id = int(sw.librenms_device_id)
        deleted = await librenms.delete_device(lnms_id)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to delete device {lnms_id} from LibreNMS",
            )

        db.query(LibreNMSPort).filter(LibreNMSPort.switch_id == sw.switch_id).delete()

        sw.librenms_device_id = None
        sw.librenms_hostname = None
        sw.librenms_last_synced = None
        db.commit()

        return {
            "status": "ok",
            "node_type": "switch",
            "switch_id": sw.switch_id,
            "librenms_device_id": lnms_id,
            "message": "Unregistered from LibreNMS",
        }

    dev = db.query(Device).filter(Device.device_id == local_id).first()
    if not dev:
        raise HTTPException(status_code=404, detail="Device not found")

    if not dev.librenms_device_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Device is not connected to LibreNMS",
        )

    lnms_id = int(dev.librenms_device_id)
    deleted = await librenms.delete_device(lnms_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to delete device {lnms_id} from LibreNMS",
        )

    db.query(LibreNMSPort).filter(LibreNMSPort.device_id == dev.device_id).delete()

    dev.librenms_device_id = None
    dev.librenms_hostname = None
    dev.librenms_last_synced = None
    db.commit()

    return {
        "status": "ok",
        "node_type": "device",
        "device_id": dev.device_id,
        "librenms_device_id": lnms_id,
        "message": "Unregistered from LibreNMS",
    }
