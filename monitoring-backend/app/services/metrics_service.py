import asyncio
import logging
import math
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple

from sqlalchemy.orm import Session

from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_service import LibreNMSService

logger = logging.getLogger(__name__)


def to_float(value) -> Optional[float]:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def to_finite_float(value) -> Optional[float]:
    v = to_float(value)
    if v is None:
        return None
    if math.isnan(v) or math.isinf(v):
        return None
    return v


def extract_port_rate_parts_mbps(port: dict) -> Tuple[float, float, bool]:
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
        v = to_float(port.get(key))
        if v is not None:
            in_rate = v
            break

    for key in out_candidates:
        v = to_float(port.get(key))
        if v is not None:
            out_rate = v
            break

    if in_rate is None and out_rate is None:
        return 0.0, 0.0, False

    in_mbps = (in_rate or 0.0) * 8 / 1_000_000
    out_mbps = (out_rate or 0.0) * 8 / 1_000_000
    return in_mbps, out_mbps, True


def extract_port_capacity_mbps(port: dict) -> Optional[float]:
    high_speed = port.get("ifHighSpeed") or port.get("ifhighspeed")
    if high_speed:
        return to_float(high_speed)

    speed = port.get("ifSpeed") or port.get("ifspeed")
    if speed:
        value = to_float(speed)
        return None if value is None else value / 1_000_000

    return None


def get_ports_for_location(db: Session, location_id: Optional[int]):
    ports_query = db.query(LibreNMSPort)

    if location_id:
        ports_query = ports_query.outerjoin(
            Device, LibreNMSPort.device_id == Device.device_id
        ).outerjoin(Switch, LibreNMSPort.switch_id == Switch.switch_id)
        ports_query = ports_query.filter(
            (Device.location_id == location_id) | (Switch.location_id == location_id)
        )

    enabled_ports = ports_query.filter(LibreNMSPort.enabled.is_(True)).all()
    if enabled_ports:
        return enabled_ports

    return ports_query.all()


def add_interval(day_map, start: datetime, end: datetime, is_online: bool):
    if end <= start:
        return

    current = start
    while current < end:
        day_start = datetime.combine(
            current.date(), datetime.min.time(), tzinfo=current.tzinfo
        )
        day_end = day_start + timedelta(days=1)
        slice_end = min(day_end, end)
        seconds = (slice_end - current).total_seconds()

        if current.date() in day_map:
            day_map[current.date()]["total"] += seconds
            if is_online:
                day_map[current.date()]["online"] += seconds

        current = slice_end


async def fetch_port_metrics(
    librenms: LibreNMSService, port_rows
) -> Tuple[float, float, float, bool]:
    port_tasks = [
        (port_row, librenms.get_port_by_id(int(port_row.port_id)))
        for port_row in port_rows
        if port_row.port_id is not None
    ]

    if not port_tasks:
        return 0.0, 0.0, 0.0, False

    results = await asyncio.gather(
        *[task for _, task in port_tasks], return_exceptions=True
    )

    total_in = 0.0
    total_out = 0.0
    total_capacity = 0.0
    data_found = False

    for (port_row, _), res in zip(port_tasks, results):
        if isinstance(res, Exception):
            logger.warning("Port fetch failed for port_id=%s", port_row.port_id)
            continue
        if not isinstance(res, dict):
            continue

        port_list = res.get("port", []) or []
        for port in port_list:
            if (
                int(port.get("disabled", 0) or 0) == 1
                or int(port.get("ignore", 0) or 0) == 1
            ):
                continue

            in_mbps, out_mbps, has_valid = extract_port_rate_parts_mbps(port)
            total_in += in_mbps
            total_out += out_mbps
            data_found = data_found or has_valid

            capacity = extract_port_capacity_mbps(port)
            if capacity:
                total_capacity += capacity

    return total_in, total_out, total_capacity, data_found


async def aggregate_port_rates(
    db: Session, location_id: Optional[int]
) -> Tuple[float, float, bool]:
    ports = get_ports_for_location(db, location_id)
    if not ports:
        return 0.0, 0.0, False

    librenms = LibreNMSService()
    total_in, total_out, _, data_found = await fetch_port_metrics(librenms, ports)
    return total_in, total_out, data_found


async def aggregate_port_metrics_by_node(
    db: Session, location_id: Optional[int]
) -> Tuple[
    Dict[int, Tuple[float, float]],
    Dict[int, Tuple[float, float]],
    Dict[int, float],
    Dict[int, float],
    bool,
]:
    ports = get_ports_for_location(db, location_id)
    if not ports:
        return {}, {}, {}, {}, False

    librenms = LibreNMSService()
    port_tasks = [
        (port_row, librenms.get_port_by_id(int(port_row.port_id)))
        for port_row in ports
        if port_row.port_id is not None
    ]
    results = await asyncio.gather(
        *[task for _, task in port_tasks], return_exceptions=True
    )

    device_totals: Dict[int, Tuple[float, float]] = {}
    switch_totals: Dict[int, Tuple[float, float]] = {}
    device_capacity: Dict[int, float] = {}
    switch_capacity: Dict[int, float] = {}
    data_found = False

    for (port_row, _), res in zip(port_tasks, results):
        if isinstance(res, Exception):
            continue
        if not isinstance(res, dict):
            continue

        port_list = res.get("port", []) or []
        if not port_list:
            continue

        port = port_list[0]
        if (
            int(port.get("disabled", 0) or 0) == 1
            or int(port.get("ignore", 0) or 0) == 1
        ):
            continue

        in_mbps, out_mbps, has_valid = extract_port_rate_parts_mbps(port)
        capacity = extract_port_capacity_mbps(port)

        data_found = data_found or has_valid

        if port_row.device_id:
            current_in, current_out = device_totals.get(port_row.device_id, (0.0, 0.0))
            device_totals[port_row.device_id] = (
                current_in + in_mbps,
                current_out + out_mbps,
            )
            if capacity:
                device_capacity[port_row.device_id] = (
                    device_capacity.get(port_row.device_id, 0.0) + capacity
                )

        if port_row.switch_id:
            current_in, current_out = switch_totals.get(port_row.switch_id, (0.0, 0.0))
            switch_totals[port_row.switch_id] = (
                current_in + in_mbps,
                current_out + out_mbps,
            )
            if capacity:
                switch_capacity[port_row.switch_id] = (
                    switch_capacity.get(port_row.switch_id, 0.0) + capacity
                )

    return device_totals, switch_totals, device_capacity, switch_capacity, data_found
