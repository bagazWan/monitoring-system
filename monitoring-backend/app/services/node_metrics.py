from typing import Dict, Optional

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_service import LibreNMSService
from app.services.metrics_service import (
    extract_port_capacity_mbps,
    extract_port_rate_parts_mbps,
    to_float,
)
from app.services.ping_probe import ping_probe
from app.utils.thresholds import evaluate_device_severity, evaluate_switch_severity


def _status_severity(status: Optional[str]) -> str:
    s = (status or "").lower()
    if s == "offline":
        return "red"
    if s == "warning":
        return "yellow"
    return "green"


async def calculate_device_metrics(
    device: Device, db: Session, librenms: LibreNMSService
) -> Dict:
    default_response = {
        "device_id": device.device_id,
        "status": device.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
        "monitored": False,
        "severity": _status_severity(device.status),
        "latency_ms": None,
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

    in_mbps = round(total_in, 2)
    out_mbps = round(total_out, 2)

    if (device.status or "").lower() == "offline":
        severity = "red"
    elif (device.status or "").lower() == "warning":
        severity = "yellow"
    else:
        severity = evaluate_device_severity(device.device_type, in_mbps, out_mbps)

    latency_ms = None
    if settings.PING_PROBE_ENABLED:
        latency_ms = await ping_probe.ping(device.ip_address)
    else:
        try:
            detail = await librenms.get_device_by_id(int(device.librenms_device_id))
            if detail:
                latency_ms = to_float(detail.get("latency_ms") or detail.get("latency"))
        except Exception:
            pass

    return {
        "device_id": device.device_id,
        "status": device.status,
        "in_mbps": in_mbps,
        "out_mbps": out_mbps,
        "monitored": True,
        "severity": severity,
        "latency_ms": latency_ms,
    }


async def calculate_switch_metrics(
    switch: Switch, db: Session, librenms: LibreNMSService
) -> Dict:
    default_response = {
        "switch_id": switch.switch_id,
        "status": switch.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
        "severity": _status_severity(switch.status),
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
    total_capacity = 0.0

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

                capacity = extract_port_capacity_mbps(p_data)
                if capacity:
                    total_capacity += capacity
        except Exception:
            continue

    in_mbps = round(total_in, 2)
    out_mbps = round(total_out, 2)
    utilization = (
        ((in_mbps + out_mbps) / total_capacity) * 100 if total_capacity > 0 else None
    )

    if (switch.status or "").lower() == "offline":
        severity = "red"
    elif (switch.status or "").lower() == "warning":
        severity = "yellow"
    else:
        severity = evaluate_switch_severity(utilization, "switch")

    return {
        "switch_id": switch.switch_id,
        "status": switch.status,
        "in_mbps": in_mbps,
        "out_mbps": out_mbps,
        "severity": severity,
    }
