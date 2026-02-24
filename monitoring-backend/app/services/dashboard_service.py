import asyncio
import logging
from datetime import datetime, time, timedelta, timezone
from typing import Optional, Tuple

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app.models import (
    Alert,
    Device,
    LibreNMSPort,
    Location,
    StatusHistory,
    Switch,
    SwitchAlert,
)
from app.services.librenms_service import LibreNMSService

logger = logging.getLogger(__name__)


def _to_float(value) -> Optional[float]:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _extract_port_rate_parts_mbps(port: dict) -> Tuple[float, float, bool]:
    in_candidates = [
        "ifInOctets_rate",
        "ifinoctets_rate",
        "ifInOctetsRate",
        "in_rate",
    ]
    out_candidates = [
        "ifOutOctets_rate",
        "ifoutoctets_rate",
        "ifOutOctetsRate",
        "out_rate",
    ]

    in_rate = None
    out_rate = None

    for key in in_candidates:
        v = _to_float(port.get(key))
        if v is not None:
            in_rate = v
            break

    for key in out_candidates:
        v = _to_float(port.get(key))
        if v is not None:
            out_rate = v
            break

    if in_rate is None and out_rate is None:
        return 0.0, 0.0, False

    in_mbps = (in_rate or 0.0) * 8 / 1_000_000
    out_mbps = (out_rate or 0.0) * 8 / 1_000_000
    return in_mbps, out_mbps, True


def _get_ports_for_location(db: Session, location_id: Optional[int]):
    ports_query = db.query(LibreNMSPort)

    if location_id:
        ports_query = ports_query.outerjoin(
            Device, LibreNMSPort.device_id == Device.device_id
        ).outerjoin(Switch, LibreNMSPort.switch_id == Switch.switch_id)
        ports_query = ports_query.filter(
            or_(Device.location_id == location_id, Switch.location_id == location_id)
        )

    enabled_ports = ports_query.filter(LibreNMSPort.enabled.is_(True)).all()
    if enabled_ports:
        return enabled_ports

    return ports_query.all()


def _add_interval(day_map, start: datetime, end: datetime, is_online: bool):
    if end <= start:
        return

    current = start
    while current < end:
        day_start = datetime.combine(current.date(), time.min, tzinfo=current.tzinfo)
        day_end = day_start + timedelta(days=1)
        slice_end = min(day_end, end)
        seconds = (slice_end - current).total_seconds()

        if current.date() in day_map:
            day_map[current.date()]["total"] += seconds
            if is_online:
                day_map[current.date()]["online"] += seconds

        current = slice_end


def build_uptime_trend(
    db: Session, days: int, location_id: Optional[int] = None
) -> dict:
    now = datetime.now(timezone.utc)
    window_start = (now - timedelta(days=days - 1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    dev_query = db.query(Device.device_id, Device.status)
    sw_query = db.query(Switch.switch_id, Switch.status)

    if location_id:
        dev_query = dev_query.filter(Device.location_id == location_id)
        sw_query = sw_query.filter(Switch.location_id == location_id)

    devices = dev_query.all()
    switches = sw_query.all()

    node_keys = [("device", d.device_id, d.status) for d in devices] + [
        ("switch", s.switch_id, s.status) for s in switches
    ]

    if not node_keys:
        return {"days": 0, "data": []}

    device_ids = {d.device_id for d in devices}
    switch_ids = {s.switch_id for s in switches}

    filters = []
    if device_ids:
        filters.append(
            and_(
                StatusHistory.node_type == "device",
                StatusHistory.node_id.in_(device_ids),
            )
        )
    if switch_ids:
        filters.append(
            and_(
                StatusHistory.node_type == "switch",
                StatusHistory.node_id.in_(switch_ids),
            )
        )

    if not filters:
        return {"days": 0, "data": []}

    day_map = {
        (window_start.date() + timedelta(days=i)): {"online": 0.0, "total": 0.0}
        for i in range(days)
    }

    history_rows = (
        db.query(StatusHistory)
        .filter(StatusHistory.changed_at >= window_start)
        .filter(or_(*filters))
        .order_by(StatusHistory.changed_at.asc())
        .all()
    )

    days_with_events = {row.changed_at.date() for row in history_rows}

    last_sub = (
        db.query(
            StatusHistory.node_type,
            StatusHistory.node_id,
            func.max(StatusHistory.changed_at).label("last_changed_at"),
        )
        .filter(StatusHistory.changed_at < window_start)
        .filter(or_(*filters))
        .group_by(StatusHistory.node_type, StatusHistory.node_id)
        .subquery()
    )

    last_rows = (
        db.query(StatusHistory.node_type, StatusHistory.node_id, StatusHistory.status)
        .join(
            last_sub,
            and_(
                StatusHistory.node_type == last_sub.c.node_type,
                StatusHistory.node_id == last_sub.c.node_id,
                StatusHistory.changed_at == last_sub.c.last_changed_at,
            ),
        )
        .all()
    )

    last_status_map = {(row.node_type, row.node_id): row.status for row in last_rows}

    history_map = {}
    for row in history_rows:
        key = (row.node_type, row.node_id)
        history_map.setdefault(key, []).append(row)

    for node_type, node_id, current_status in node_keys:
        key = (node_type, node_id)
        events = history_map.get(key, [])

        last_status = last_status_map.get(key)
        if last_status is None:
            if not events:
                continue
            status = events[0].status
            cursor = events[0].changed_at
            events = events[1:]
        else:
            status = last_status
            cursor = window_start

        for ev in events:
            _add_interval(day_map, cursor, ev.changed_at, status == "online")
            status = ev.status
            cursor = ev.changed_at

        _add_interval(day_map, cursor, now, status == "online")

    data = []
    for day in sorted(day_map.keys()):
        total = day_map[day]["total"]
        online = day_map[day]["online"]
        uptime = round((online / total * 100), 2) if total > 0 else None

        if day not in days_with_events:
            uptime = None

        data.append({"date": day.strftime("%Y-%m-%d"), "uptime_percentage": uptime})

    return {"days": len(data), "data": data}


async def _aggregate_port_rates(
    db: Session, location_id: Optional[int]
) -> Tuple[float, float, bool]:
    ports = _get_ports_for_location(db, location_id)
    if not ports:
        return 0.0, 0.0, False

    librenms = LibreNMSService()
    tasks = [
        librenms.get_port_by_id(int(p.port_id)) for p in ports if p.port_id is not None
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    total_in = 0.0
    total_out = 0.0
    data_found = False

    for idx, res in enumerate(results):
        if isinstance(res, Exception):
            logger.warning(
                "Dashboard port fetch failed for port_index=%s: %s", idx, res
            )
            continue
        if not isinstance(res, dict):
            continue

        port_list = res.get("port", []) or []
        for port in port_list:
            in_mbps, out_mbps, has_valid = _extract_port_rate_parts_mbps(port)
            total_in += in_mbps
            total_out += out_mbps
            data_found = data_found or has_valid

    return total_in, total_out, data_found


async def build_dashboard_stats(
    *,
    db: Session,
    location_id: Optional[int],
    top_down_window: int,
):
    dev_query = db.query(Device)
    sw_query = db.query(Switch)

    if location_id:
        dev_query = dev_query.filter(Device.location_id == location_id)
        sw_query = sw_query.filter(Switch.location_id == location_id)

    total_devices = dev_query.count()
    total_switches = sw_query.count()
    online_devices = dev_query.filter(Device.status == "online").count()
    online_switches = sw_query.filter(Switch.status == "online").count()

    total_all = total_devices + total_switches
    all_online = online_devices + online_switches

    cctv_filter = or_(
        func.lower(Device.device_type).like("%cctv%"),
        func.lower(Device.device_type).like("%camera%"),
    )
    cctv_total = dev_query.filter(cctv_filter).count()
    cctv_online = dev_query.filter(cctv_filter, Device.status == "online").count()
    cctv_uptime = (cctv_online / cctv_total * 100) if cctv_total > 0 else 0.0

    total_in, total_out, data_found = await _aggregate_port_rates(db, location_id)
    total_bandwidth_mbps = total_in + total_out

    top_down = []
    window_start = datetime.now(timezone.utc) - timedelta(days=top_down_window)
    critical_filter = func.lower(func.coalesce(Alert.severity, "")) == "critical"
    critical_sw_filter = (
        func.lower(func.coalesce(SwitchAlert.severity, "")) == "critical"
    )

    dev_down = (
        db.query(
            Location.location_id.label("location_id"),
            Location.name.label("location_name"),
            func.count(Alert.alert_id).label("offline_count"),
        )
        .join(Device, Location.location_id == Device.location_id)
        .join(Alert, Alert.device_id == Device.device_id)
        .filter(Alert.created_at >= window_start)
        .filter(critical_filter)
        .group_by(Location.location_id, Location.name)
        .all()
    )

    sw_down = (
        db.query(
            Location.location_id.label("location_id"),
            Location.name.label("location_name"),
            func.count(SwitchAlert.alert_id).label("offline_count"),
        )
        .join(Switch, Location.location_id == Switch.location_id)
        .join(SwitchAlert, SwitchAlert.switch_id == Switch.switch_id)
        .filter(SwitchAlert.created_at >= window_start)
        .filter(critical_sw_filter)
        .group_by(Location.location_id, Location.name)
        .all()
    )

    device_type_rows = (
        dev_query.with_entities(
            func.coalesce(func.lower(func.trim(Device.device_type)), "unknown").label(
                "device_type"
            ),
            func.count(Device.device_id).label("count"),
        )
        .group_by(func.coalesce(func.lower(func.trim(Device.device_type)), "unknown"))
        .all()
    )

    breakdown_map = {row.device_type: int(row.count) for row in device_type_rows}

    if total_switches > 0:
        breakdown_map["switch"] = breakdown_map.get("switch", 0) + total_switches

    def _format_device_type(value: str) -> str:
        if value == "cctv":
            return "CCTV"
        if value == "switch":
            return "Switch"
        if value == "router":
            return "Router"
        if value == "access_point":
            return "Access Point"
        if value == "unknown":
            return "Unknown"
        return value.replace("_", " ").title()

    device_type_stats = [
        {"device_type": _format_device_type(key), "count": value}
        for key, value in sorted(
            breakdown_map.items(), key=lambda item: (-item[1], item[0])
        )
    ]

    merged = {}
    for row in dev_down + sw_down:
        loc_id = row.location_id
        if loc_id not in merged:
            merged[loc_id] = {
                "location_id": row.location_id,
                "location_name": row.location_name,
                "offline_count": 0,
            }
        merged[loc_id]["offline_count"] += int(row.offline_count or 0)

    top_down = sorted(merged.values(), key=lambda x: x["offline_count"], reverse=True)[
        :10
    ]

    active_alerts = (
        db.query(Alert)
        .filter(or_(Alert.status == "active", Alert.status == "1"))
        .count()
        + db.query(SwitchAlert)
        .filter(or_(SwitchAlert.status == "active", SwitchAlert.status == "1"))
        .count()
    )

    uptime = (all_online / total_all * 100) if total_all > 0 else 0.0

    return {
        "total_all_devices": total_all,
        "all_online_devices": all_online,
        "active_alerts": active_alerts,
        "total_bandwidth": round(total_bandwidth_mbps, 2) if data_found else None,
        "uptime_percentage": round(uptime, 2),
        "top_down_locations": top_down,
        "top_down_window_days": top_down_window,
        "cctv_total": cctv_total,
        "cctv_online": cctv_online,
        "cctv_uptime_percentage": round(cctv_uptime, 2),
        "device_type_stats": device_type_stats,
    }


async def build_dashboard_traffic(*, db: Session, location_id: Optional[int]) -> dict:
    total_in, total_out, data_found = await _aggregate_port_rates(db, location_id)
    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "inbound_mbps": round(total_in, 2) if data_found else None,
        "outbound_mbps": round(total_out, 2) if data_found else None,
    }
