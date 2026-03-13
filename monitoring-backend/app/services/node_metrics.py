from typing import Dict

from sqlalchemy.orm import Session

from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_service import LibreNMSService
from app.services.metrics_service import extract_port_rate_parts_mbps


async def calculate_device_metrics(
    device: Device, db: Session, librenms: LibreNMSService
) -> Dict:
    default_response = {
        "device_id": device.device_id,
        "status": device.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
        "monitored": False,
    }

    if not device.librenms_device_id:
        return default_response

    enabled_ports = (
        db.query(LibreNMSPort)
        .filter(
            LibreNMSPort.device_id == device.device_id, LibreNMSPort.enabled.is_(True)
        )
        .all()
    )

    total_in = 0.0
    total_out = 0.0

    for port_row in enabled_ports:
        try:
            port_detail = await librenms.get_port_by_id(int(port_row.port_id))
            p_list = port_detail.get("port", [])
            for p_data in p_list:
                if (
                    int(p_data.get("disabled", 0) or 0) == 1
                    or int(p_data.get("ignore", 0) or 0) == 1
                ):
                    continue
                in_mbps, out_mbps, _ = extract_port_rate_parts_mbps(p_data)
                total_in += in_mbps
                total_out += out_mbps
        except Exception:
            continue

    return {
        "device_id": device.device_id,
        "status": device.status,
        "in_mbps": round(total_in, 2),
        "out_mbps": round(total_out, 2),
        "monitored": True,
    }


async def calculate_switch_metrics(
    switch: Switch, db: Session, librenms: LibreNMSService
) -> Dict:
    default_response = {
        "switch_id": switch.switch_id,
        "status": switch.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
    }

    if not switch.librenms_device_id:
        return default_response

    uplink_ports = (
        db.query(LibreNMSPort)
        .filter(
            LibreNMSPort.switch_id == switch.switch_id,
            LibreNMSPort.enabled.is_(True),
            LibreNMSPort.is_uplink.is_(True),
        )
        .all()
    )

    used_ports = uplink_ports or (
        db.query(LibreNMSPort)
        .filter(
            LibreNMSPort.switch_id == switch.switch_id, LibreNMSPort.enabled.is_(True)
        )
        .all()
    )

    total_in = 0.0
    total_out = 0.0

    for port_row in used_ports:
        try:
            port_detail = await librenms.get_port_by_id(int(port_row.port_id))
            p_list = port_detail.get("port", [])
            for p_data in p_list:
                if (
                    int(p_data.get("disabled", 0) or 0) == 1
                    or int(p_data.get("ignore", 0) or 0) == 1
                ):
                    continue
                in_mbps, out_mbps, _ = extract_port_rate_parts_mbps(p_data)
                total_in += in_mbps
                total_out += out_mbps
        except Exception:
            continue

    return {
        "switch_id": switch.switch_id,
        "status": switch.status,
        "in_mbps": round(total_in, 2),
        "out_mbps": round(total_out, 2),
    }
