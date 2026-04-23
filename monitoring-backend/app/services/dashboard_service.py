import asyncio
import math
import time
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, aliased

from app.models import (
    Alert,
    Device,
    Location,
    LocationGroup,
    StatusHistory,
    Switch,
    SwitchAlert,
)
from app.services.metrics_service import add_interval, aggregate_port_rates
from app.services.ping_probe import ping_probe


async def get_current_average_latency(
    db: Session, location_ids: Optional[list[int]]
) -> Optional[float]:
    dev_query = db.query(Device.ip_address).filter(
        Device.ip_address.isnot(None), Device.ip_address != ""
    )
    sw_query = db.query(Switch.ip_address).filter(
        Switch.ip_address.isnot(None), Switch.ip_address != ""
    )

    if location_ids:
        dev_query = dev_query.filter(Device.location_id.in_(location_ids))
        sw_query = sw_query.filter(Switch.location_id.in_(location_ids))

    ips = [row[0] for row in dev_query.all()] + [row[0] for row in sw_query.all()]

    if not ips:
        return None

    await asyncio.gather(*[ping_probe.ping(ip) for ip in ips], return_exceptions=True)

    latencies = []

    for ip in ips:
        cached = ping_probe._cache.get(ip)
        if cached and cached[1] is not None and not math.isnan(cached[1]):
            latencies.append(cached[1])

    if not latencies:
        return None

    avg_latency = sum(latencies) / len(latencies)
    if math.isnan(avg_latency):
        return None

    return avg_latency


def build_uptime_trend(
    db: Session, days: int, location_ids: Optional[list[int]] = None
) -> dict:
    now = datetime.now(timezone.utc)
    window_start = (now - timedelta(days=days - 1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    dev_query = db.query(Device.device_id)
    sw_query = db.query(Switch.switch_id)

    if location_ids:
        dev_query = dev_query.filter(Device.location_id.in_(location_ids))
        sw_query = sw_query.filter(Switch.location_id.in_(location_ids))

    devices = dev_query.all()
    switches = sw_query.all()

    node_keys = [("device", d.device_id) for d in devices] + [
        ("switch", s.switch_id) for s in switches
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

    first_seen_row = (
        db.query(StatusHistory.changed_at)
        .filter(or_(*filters))
        .order_by(StatusHistory.changed_at.asc())
        .first()
    )
    first_seen_at = first_seen_row[0] if first_seen_row else None

    history_rows = (
        db.query(StatusHistory)
        .filter(StatusHistory.changed_at >= window_start)
        .filter(StatusHistory.changed_at <= now)
        .filter(or_(*filters))
        .order_by(StatusHistory.changed_at.asc())
        .all()
    )

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
    last_status_map = {(r.node_type, r.node_id): r.status for r in last_rows}

    history_map = {}
    for row in history_rows:
        history_map.setdefault((row.node_type, row.node_id), []).append(row)

    for node_type, node_id in node_keys:
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
            add_interval(day_map, cursor, ev.changed_at, status == "online")
            status = ev.status
            cursor = ev.changed_at

        add_interval(day_map, cursor, now, status == "online")

    data = []
    for day in sorted(day_map.keys()):
        total = day_map[day]["total"]
        online = day_map[day]["online"]

        if first_seen_at is None or day < first_seen_at.date():
            uptime = None
        else:
            uptime = round((online / total * 100), 2) if total > 0 else None

        data.append({"date": day.strftime("%Y-%m-%d"), "uptime_percentage": uptime})

    return {"days": len(data), "data": data}


async def build_dashboard_stats(
    *,
    db: Session,
    location_ids: Optional[list[int]],
    top_down_window: int,
):
    dev_query = db.query(Device)
    sw_query = db.query(Switch)

    if location_ids:
        dev_query = dev_query.filter(Device.location_id.in_(location_ids))
        sw_query = sw_query.filter(Switch.location_id.in_(location_ids))

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

    total_in, total_out, data_found = await aggregate_port_rates(db, location_ids)
    total_bandwidth_mbps = total_in + total_out

    avg_latency = await get_current_average_latency(db, location_ids)

    top_down = []
    window_start = datetime.now(timezone.utc) - timedelta(days=top_down_window)
    critical_filter = func.lower(func.coalesce(Alert.severity, "")) == "critical"
    critical_sw_filter = (
        func.lower(func.coalesce(SwitchAlert.severity, "")) == "critical"
    )

    # UPDATED TOP DOWN AGGREGATION
    ParentGroup = aliased(LocationGroup)

    dev_down = (
        db.query(
            func.coalesce(
                ParentGroup.group_id, LocationGroup.group_id, Location.location_id
            ).label("location_id"),
            func.coalesce(ParentGroup.name, LocationGroup.name, Location.name).label(
                "location_name"
            ),
            func.count(Alert.alert_id).label("offline_count"),
        )
        .select_from(Alert)
        .join(Device, Alert.device_id == Device.device_id)
        .join(Location, Device.location_id == Location.location_id)
        .outerjoin(LocationGroup, Location.group_id == LocationGroup.group_id)
        .outerjoin(ParentGroup, LocationGroup.parent_id == ParentGroup.group_id)
        .filter(Alert.created_at >= window_start)
        .filter(critical_filter)
        .group_by(
            func.coalesce(
                ParentGroup.group_id, LocationGroup.group_id, Location.location_id
            ),
            func.coalesce(ParentGroup.name, LocationGroup.name, Location.name),
        )
        .all()
    )

    sw_down = (
        db.query(
            func.coalesce(
                ParentGroup.group_id, LocationGroup.group_id, Location.location_id
            ).label("location_id"),
            func.coalesce(ParentGroup.name, LocationGroup.name, Location.name).label(
                "location_name"
            ),
            func.count(SwitchAlert.alert_id).label("offline_count"),
        )
        .select_from(SwitchAlert)
        .join(Switch, SwitchAlert.switch_id == Switch.switch_id)
        .join(Location, Switch.location_id == Location.location_id)
        .outerjoin(LocationGroup, Location.group_id == LocationGroup.group_id)
        .outerjoin(ParentGroup, LocationGroup.parent_id == ParentGroup.group_id)
        .filter(SwitchAlert.created_at >= window_start)
        .filter(critical_sw_filter)
        .group_by(
            func.coalesce(
                ParentGroup.group_id, LocationGroup.group_id, Location.location_id
            ),
            func.coalesce(ParentGroup.name, LocationGroup.name, Location.name),
        )
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

    top_down = sorted(
        merged.values(),
        key=lambda item: item["offline_count"],
        reverse=True,
    )[:10]

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
        "average_latency": round(avg_latency, 2)
        if (avg_latency is not None and not math.isnan(avg_latency))
        else None,
    }


async def build_dashboard_traffic(
    *, db: Session, location_ids: Optional[list[int]]
) -> dict:
    total_in, total_out, data_found = await aggregate_port_rates(db, location_ids)
    avg_latency = await get_current_average_latency(db, location_ids)

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "inbound_mbps": round(total_in, 2) if data_found else None,
        "outbound_mbps": round(total_out, 2) if data_found else None,
        "latency_ms": round(avg_latency, 2)
        if (avg_latency is not None and not math.isnan(avg_latency))
        else None,
    }
