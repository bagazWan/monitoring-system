import asyncio
import logging
from typing import Optional, Tuple

from app.core.database import get_db
from app.models import Alert, Device, Location, Switch, SwitchAlert
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])
logger = logging.getLogger(__name__)


def _to_float(value) -> Optional[float]:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _extract_port_rate_mbps(port: dict) -> Tuple[float, bool]:
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
        return 0.0, False

    in_mbps = (in_rate or 0.0) * 8 / 1_000_000
    out_mbps = (out_rate or 0.0) * 8 / 1_000_000
    return in_mbps + out_mbps, True


@router.get("/stats")
async def get_dashboard_summary(
    location_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
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

    monitored_nodes = (
        dev_query.filter(Device.librenms_device_id.isnot(None)).all()
        + sw_query.filter(Switch.librenms_device_id.isnot(None)).all()
    )

    total_bandwidth_mbps = 0.0
    data_found = False
    debug_logged_once = False

    if monitored_nodes:
        librenms = LibreNMSService()
        tasks = [
            librenms.get_device_port_stats(node.librenms_device_id)
            for node in monitored_nodes
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        for idx, res in enumerate(results):
            if isinstance(res, Exception):
                logger.warning(
                    "Dashboard bandwidth fetch failed for node_index=%s: %s", idx, res
                )
                continue
            if not isinstance(res, dict):
                continue

            ports = res.get("ports", []) or []
            if ports and not debug_logged_once:
                sample = ports[0]
                logger.info("LibreNMS sample port keys: %s", list(sample.keys())[:40])
                logger.info(
                    "LibreNMS sample rate fields: %s",
                    {
                        "ifInOctets_rate": sample.get("ifInOctets_rate"),
                        "ifOutOctets_rate": sample.get("ifOutOctets_rate"),
                        "ifinoctets_rate": sample.get("ifinoctets_rate"),
                        "ifoutoctets_rate": sample.get("ifoutoctets_rate"),
                        "ifSpeed": sample.get("ifSpeed"),
                        "ifOperStatus": sample.get("ifOperStatus"),
                    },
                )
                debug_logged_once = True

            for port in ports:
                if int(port.get("disabled", 0) or 0) == 1:
                    continue
                if int(port.get("ignore", 0) or 0) == 1:
                    continue

                mbps, has_valid = _extract_port_rate_mbps(port)
                total_bandwidth_mbps += mbps
                data_found = data_found or has_valid

    top_down = []
    if not location_id:
        dev_down = (
            db.query(
                Location.location_id.label("location_id"),
                Location.name.label("location_name"),
                func.count(Device.device_id).label("offline_count"),
            )
            .join(Device, Location.location_id == Device.location_id)
            .filter(Device.status == "offline")
            .group_by(Location.location_id, Location.name)
            .all()
        )

        sw_down = (
            db.query(
                Location.location_id.label("location_id"),
                Location.name.label("location_name"),
                func.count(Switch.switch_id).label("offline_count"),
            )
            .join(Switch, Location.location_id == Switch.location_id)
            .filter(Switch.status == "offline")
            .group_by(Location.location_id, Location.name)
            .all()
        )

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
            merged.values(), key=lambda x: x["offline_count"], reverse=True
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
    }
