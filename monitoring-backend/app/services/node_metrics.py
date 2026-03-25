from typing import Dict, Optional

from sqlalchemy.orm import Session

from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_service import LibreNMSService
from app.services.metrics_service import (
    extract_port_capacity_mbps,
    extract_port_rate_parts_mbps,
)
from app.services.threshold_alerts import (
    sync_device_threshold_alert,
    sync_switch_threshold_alert,
)
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
    data_found = False

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
                in_mbps, out_mbps, has_valid = extract_port_rate_parts_mbps(p_data)
                total_in += in_mbps
                total_out += out_mbps
                data_found = data_found or has_valid
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

    sync_device_threshold_alert(
        db,
        device_id=device.device_id,
        severity=severity,
        message=f"Throughput: {in_mbps:.2f} Mbps in / {out_mbps:.2f} Mbps out",
        data_found=data_found,
    )
    db.commit()

    return {
        "device_id": device.device_id,
        "status": device.status,
        "in_mbps": in_mbps,
        "out_mbps": out_mbps,
        "monitored": True,
        "severity": severity,
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
    data_found = False

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
                in_mbps, out_mbps, has_valid = extract_port_rate_parts_mbps(p_data)
                total_in += in_mbps
                total_out += out_mbps
                data_found = data_found or has_valid

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

    sync_switch_threshold_alert(
        db,
        switch_id=switch.switch_id,
        severity=severity,
        message=f"Utilization: {utilization:.2f}%"
        if utilization is not None
        else "Utilization unavailable",
        data_found=data_found,
    )
    db.commit()

    return {
        "switch_id": switch.switch_id,
        "status": switch.status,
        "in_mbps": in_mbps,
        "out_mbps": out_mbps,
        "severity": severity,
    }
