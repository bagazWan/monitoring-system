from datetime import datetime, timedelta, timezone
from typing import Dict, Optional

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_ports_service import discover_and_store_ports_for
from app.services.librenms_service import LibreNMSService
from app.services.metrics_service import (
    extract_port_capacity_mbps,
    extract_port_rate_parts_mbps,
    to_finite_float,
    to_float,
)
from app.services.ping_probe import ping_probe
from app.utils.thresholds import (
    DEVICE_THRESHOLDS,
    evaluate_device_latency_severity,
    evaluate_device_severity,
    evaluate_switch_severity,
)

_LAST_RESYNC_AT: dict[str, datetime] = {}


def _status_severity(status: Optional[str]) -> str:
    s = (status or "").lower()
    if s == "offline":
        return "red"
    if s == "warning":
        return "yellow"
    return "green"


def _normalize_device_type(value: Optional[str]) -> str:
    return (value or "").strip().lower().replace("_", " ")


def _resync_key_device(device_id: int) -> str:
    return f"device:{device_id}"


def _resync_key_switch(switch_id: int) -> str:
    return f"switch:{switch_id}"


def _can_resync(key: str) -> bool:
    now = datetime.now(timezone.utc)
    last = _LAST_RESYNC_AT.get(key)
    if last is None:
        return True
    return (now - last) >= timedelta(seconds=settings.PORT_RESYNC_TTL_SECONDS)


def _mark_resynced(key: str) -> None:
    _LAST_RESYNC_AT[key] = datetime.now(timezone.utc)


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
        "latency_severity": _status_severity(device.status),
    }

    if not device.librenms_device_id:
        return default_response

    async def _compute_once():
        enabled_ports = (
            db.query(LibreNMSPort)
            .filter(
                LibreNMSPort.device_id == device.device_id,
                LibreNMSPort.enabled.is_(True),
            )
            .all()
        )
        total_in, total_out, ok_count = 0.0, 0.0, 0

        for row in enabled_ports:
            try:
                d = await librenms.get_port_by_id(int(row.port_id))
                p = d.get("port") or []
                if not p:
                    continue
                pd = p[0]

                if int(pd.get("device_id", -1)) != int(device.librenms_device_id):
                    continue
                if (
                    int(pd.get("disabled", 0) or 0) == 1
                    or int(pd.get("ignore", 0) or 0) == 1
                ):
                    continue

                i, o, _ = extract_port_rate_parts_mbps(pd)
                total_in += i
                total_out += o
                ok_count += 1
            except Exception:
                continue

        return total_in, total_out, ok_count, len(enabled_ports)

    total_in, total_out, ok_count, enabled_count = await _compute_once()

    is_offline = (device.status or "").lower() == "offline"
    should_try_repair = (
        not is_offline
        and enabled_count > 0
        and (
            ok_count == 0 or (round(total_in, 4) == 0.0 and round(total_out, 4) == 0.0)
        )
    )

    if should_try_repair:
        key = _resync_key_device(device.device_id)
        if _can_resync(key):
            try:
                await discover_and_store_ports_for(
                    db=db,
                    librenms=librenms,
                    librenms_device_id=int(device.librenms_device_id),
                    device=device,
                )
                db.commit()
                _mark_resynced(key)
                total_in, total_out, ok_count, enabled_count = await _compute_once()
            except Exception:
                pass

    in_mbps, out_mbps = round(total_in, 2), round(total_out, 2)

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

    if (device.status or "").lower() == "offline":
        severity = "red"
        latency_severity = "red"
    elif (device.status or "").lower() == "warning":
        severity = "yellow"
        latency_severity = "yellow"
    else:
        severity = evaluate_device_severity(device.device_type, in_mbps, out_mbps)

        device_type_key = _normalize_device_type(device.device_type)
        has_latency_rule = (
            device_type_key in DEVICE_THRESHOLDS
            and "latency" in DEVICE_THRESHOLDS[device_type_key]
        )

        latency_severity = (
            evaluate_device_latency_severity(device.device_type, latency_ms)
            if has_latency_rule
            else "green"
        )

    return {
        "device_id": device.device_id,
        "status": device.status,
        "in_mbps": to_finite_float(in_mbps) or 0.0,
        "out_mbps": to_finite_float(out_mbps) or 0.0,
        "monitored": enabled_count > 0,
        "severity": severity,
        "latency_ms": to_finite_float(latency_ms),
        "latency_severity": latency_severity,
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

    async def _compute_once():
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
                LibreNMSPort.switch_id == switch.switch_id,
                LibreNMSPort.enabled.is_(True),
            )
            .all()
        )

        total_in = 0.0
        total_out = 0.0
        total_capacity = 0.0
        ok_count = 0

        for row in used_ports:
            try:
                detail = await librenms.get_port_by_id(int(row.port_id))
                p_list = detail.get("port", [])
                if not p_list:
                    continue
                pd = p_list[0]

                if int(pd.get("device_id", -1)) != int(switch.librenms_device_id):
                    continue
                if (
                    int(pd.get("disabled", 0) or 0) == 1
                    or int(pd.get("ignore", 0) or 0) == 1
                ):
                    continue

                i, o, _ = extract_port_rate_parts_mbps(pd)
                total_in += i
                total_out += o
                cap = extract_port_capacity_mbps(pd)
                if cap:
                    total_capacity += cap
                ok_count += 1
            except Exception:
                continue

        return total_in, total_out, total_capacity, ok_count, len(used_ports)

    total_in, total_out, total_capacity, ok_count, used_count = await _compute_once()

    is_offline = (switch.status or "").lower() == "offline"
    should_try_repair = (
        not is_offline
        and used_count > 0
        and (
            ok_count == 0 or (round(total_in, 4) == 0.0 and round(total_out, 4) == 0.0)
        )
    )

    if should_try_repair:
        key = _resync_key_switch(switch.switch_id)
        if _can_resync(key):
            try:
                await discover_and_store_ports_for(
                    db=db,
                    librenms=librenms,
                    librenms_device_id=int(switch.librenms_device_id),
                    switch=switch,
                )
                db.commit()
                _mark_resynced(key)
                (
                    total_in,
                    total_out,
                    total_capacity,
                    ok_count,
                    used_count,
                ) = await _compute_once()
            except Exception:
                pass

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
        "in_mbps": to_finite_float(in_mbps) or 0.0,
        "out_mbps": to_finite_float(out_mbps) or 0.0,
        "severity": severity,
    }
