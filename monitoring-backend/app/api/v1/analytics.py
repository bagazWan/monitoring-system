from collections import defaultdict
from datetime import datetime
from typing import List, TypedDict

from app.core.database import get_db
from app.models import Device, Switch
from app.models.bandwidth import DeviceBandwidth, SwitchBandwidth
from app.schemas.analytic import AnalyticsDataPoint
from app.services.locations_service import resolve_location_ids
from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

router = APIRouter(prefix="/analytics", tags=["Analytics"])


class HourMetrics(TypedDict):
    in_mbps: float
    out_mbps: float
    latencies: List[float]


@router.get("/history", response_model=list[AnalyticsDataPoint])
def get_historical_metrics(
    start_date: datetime,
    end_date: datetime,
    location_name: str,
    db: Session = Depends(get_db),
):
    loc_ids = resolve_location_ids(db, None, location_name)
    if not loc_ids or loc_ids == [-1]:
        return []

    dev_hour = func.date_trunc("hour", DeviceBandwidth.timestamp).label("hour")
    dev_query = (
        db.query(
            dev_hour,
            DeviceBandwidth.device_id,
            func.avg(DeviceBandwidth.in_usage_mbps).label("avg_in"),
            func.avg(DeviceBandwidth.out_usage_mbps).label("avg_out"),
            func.avg(DeviceBandwidth.latency_ms).label("avg_latency"),
        )
        .join(Device, Device.device_id == DeviceBandwidth.device_id)
        .filter(Device.location_id.in_(loc_ids))
        .filter(DeviceBandwidth.timestamp >= start_date)
        .filter(DeviceBandwidth.timestamp <= end_date)
        .group_by(dev_hour, DeviceBandwidth.device_id)
        .all()
    )

    sw_hour = func.date_trunc("hour", SwitchBandwidth.timestamp).label("hour")
    sw_query = (
        db.query(
            sw_hour,
            SwitchBandwidth.switch_id,
            func.avg(SwitchBandwidth.in_usage_mbps).label("avg_in"),
            func.avg(SwitchBandwidth.out_usage_mbps).label("avg_out"),
            func.avg(SwitchBandwidth.latency_ms).label("avg_latency"),
        )
        .join(Switch, Switch.switch_id == SwitchBandwidth.switch_id)
        .filter(Switch.location_id.in_(loc_ids))
        .filter(SwitchBandwidth.timestamp >= start_date)
        .filter(SwitchBandwidth.timestamp <= end_date)
        .group_by(sw_hour, SwitchBandwidth.switch_id)
        .all()
    )

    merged_data: dict[datetime, HourMetrics] = defaultdict(
        lambda: {"in_mbps": 0.0, "out_mbps": 0.0, "latencies": []}
    )

    for row in dev_query + sw_query:
        hour = row.hour
        merged_data[hour]["in_mbps"] += row.avg_in or 0.0
        merged_data[hour]["out_mbps"] += row.avg_out or 0.0

        if row.avg_latency is not None:
            merged_data[hour]["latencies"].append(row.avg_latency)

    results = []
    for hour in sorted(merged_data.keys()):
        data = merged_data[hour]

        avg_lat = None
        if data["latencies"]:
            avg_lat = sum(data["latencies"]) / len(data["latencies"])

        results.append(
            AnalyticsDataPoint(
                timestamp=hour,
                inbound_mbps=round(data["in_mbps"], 2),
                outbound_mbps=round(data["out_mbps"], 2),
                latency_ms=round(avg_lat, 2) if avg_lat else None,
            )
        )

    return results
