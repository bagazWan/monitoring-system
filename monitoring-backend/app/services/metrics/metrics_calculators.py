from datetime import datetime, timezone
from typing import Dict

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import Device, LibreNMSPort, Switch
from app.services.librenms.client import LibreNMSService
from app.services.librenms.ports import discover_and_store_ports_for
from app.services.metrics.aggregation import (
    extract_port_capacity_mbps,
    extract_port_rate_parts_mbps,
    to_finite_float,
    to_float,
)
from app.services.metrics.ping import ping_probe
from app.services.normalizer import normalize_device_type, status_to_severity
from app.utils.thresholds import (
    DEVICE_THRESHOLDS,
    evaluate_device_latency_severity,
    evaluate_device_severity,
    evaluate_switch_severity,
)

_LAST_RESYNC_AT: dict[str, datetime] = {}


def _can_resync(key: str) -> bool:
    last = _LAST_RESYNC_AT.get(key)
    if last is None:
        return True
    return (
        datetime.now(timezone.utc) - last
    ).total_seconds() >= settings.PORT_RESYNC_TTL_SECONDS


async def _attempt_port_resync(
    db: Session, librenms: LibreNMSService, node_type: str, node
) -> None:
    node_id = getattr(node, f"{node_type}_id")
    key = f"{node_type}:{node_id}"

    if _can_resync(key):
        try:
            kwargs = {
                "db": db,
                "librenms": librenms,
                "librenms_device_id": int(node.librenms_device_id),
                node_type: node,
            }
            await discover_and_store_ports_for(**kwargs)
            db.commit()
            _LAST_RESYNC_AT[key] = datetime.now(timezone.utc)
        except Exception:
            pass


async def _fetch_and_aggregate_ports(
    librenms: LibreNMSService, ports: list, lnms_device_id: int
):
    tin, tout, cap, ok = 0.0, 0.0, 0.0, 0
    for row in ports:
        try:
            d = await librenms.get_port_by_id(int(row.port_id))
            p_list = d.get("port")
            if not p_list:
                continue

            pd = p_list[0]
            if int(pd.get("device_id", -1)) != int(lnms_device_id):
                continue
            if (
                int(pd.get("disabled", 0) or 0) == 1
                or int(pd.get("ignore", 0) or 0) == 1
            ):
                continue

            i, o, _ = extract_port_rate_parts_mbps(pd)
            tin += i
            tout += o
            cap += extract_port_capacity_mbps(pd) or 0.0
            ok += 1
        except Exception:
            pass

    return tin, tout, cap, ok, len(ports)


async def calculate_device_metrics(
    device: Device, db: Session, librenms: LibreNMSService
) -> Dict:
    status = (device.status or "offline").lower()
    res = {
        "device_id": device.device_id,
        "status": device.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
        "monitored": False,
        "severity": status_to_severity(device.status),
        "latency_ms": None,
        "latency_severity": status_to_severity(device.status),
    }

    if not device.librenms_device_id:
        return res

    async def _compute():
        ports = (
            db.query(LibreNMSPort)
            .filter(
                LibreNMSPort.device_id == device.device_id,
                LibreNMSPort.enabled.is_(True),
            )
            .all()
        )
        return await _fetch_and_aggregate_ports(
            librenms, ports, device.librenms_device_id
        )

    tin, tout, _, ok_count, used_count = await _compute()

    if (
        status != "offline"
        and used_count > 0
        and (ok_count == 0 or (round(tin, 4) == 0.0 and round(tout, 4) == 0.0))
    ):
        await _attempt_port_resync(db, librenms, "device", device)
        tin, tout, _, ok_count, used_count = await _compute()

    res["monitored"] = used_count > 0
    res["in_mbps"] = to_finite_float(round(tin, 2)) or 0.0
    res["out_mbps"] = to_finite_float(round(tout, 2)) or 0.0

    if settings.PING_PROBE_ENABLED:
        latency_ms = await ping_probe.ping(device.ip_address)
    else:
        try:
            detail = await librenms.get_device_by_id(int(device.librenms_device_id))
            latency_ms = (
                to_float(detail.get("latency_ms") or detail.get("latency"))
                if detail
                else None
            )
        except Exception:
            latency_ms = None

    res["latency_ms"] = to_finite_float(latency_ms)

    if status == "offline":
        res["severity"] = res["latency_severity"] = "red"
    elif status == "warning":
        res["severity"] = res["latency_severity"] = "yellow"
    else:
        res["severity"] = evaluate_device_severity(
            device.device_type, res["in_mbps"], res["out_mbps"]
        )
        dt_key = normalize_device_type(device.device_type)
        if dt_key in DEVICE_THRESHOLDS and "latency" in DEVICE_THRESHOLDS[dt_key]:
            res["latency_severity"] = evaluate_device_latency_severity(
                device.device_type, latency_ms
            )
        else:
            res["latency_severity"] = "green"

    return res


async def calculate_switch_metrics(
    switch: Switch, db: Session, librenms: LibreNMSService
) -> Dict:
    status = (switch.status or "offline").lower()
    res = {
        "switch_id": switch.switch_id,
        "status": switch.status or "offline",
        "in_mbps": 0.0,
        "out_mbps": 0.0,
        "severity": status_to_severity(switch.status),
    }

    if not switch.librenms_device_id:
        return res

    async def _compute():
        ports = (
            db.query(LibreNMSPort)
            .filter(
                LibreNMSPort.switch_id == switch.switch_id,
                LibreNMSPort.enabled.is_(True),
                LibreNMSPort.is_uplink.is_(True),
            )
            .all()
        )
        if not ports:
            ports = (
                db.query(LibreNMSPort)
                .filter(
                    LibreNMSPort.switch_id == switch.switch_id,
                    LibreNMSPort.enabled.is_(True),
                )
                .all()
            )
        return await _fetch_and_aggregate_ports(
            librenms, ports, switch.librenms_device_id
        )

    tin, tout, cap, ok_count, used_count = await _compute()

    if (
        status != "offline"
        and used_count > 0
        and (ok_count == 0 or (round(tin, 4) == 0.0 and round(tout, 4) == 0.0))
    ):
        await _attempt_port_resync(db, librenms, "switch", switch)
        tin, tout, cap, ok_count, used_count = await _compute()

    res["in_mbps"] = to_finite_float(round(tin, 2)) or 0.0
    res["out_mbps"] = to_finite_float(round(tout, 2)) or 0.0
    utilization = ((res["in_mbps"] + res["out_mbps"]) / cap) * 100 if cap > 0 else None

    if status == "offline":
        res["severity"] = "red"
    elif status == "warning":
        res["severity"] = "yellow"
    else:
        res["severity"] = evaluate_switch_severity(utilization, "switch")

    return res
