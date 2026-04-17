import asyncio
import logging
import time
from datetime import datetime
from typing import Dict, Optional

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal
from app.models import Device, StatusHistory, Switch
from app.services.librenms_service import LibreNMSService
from app.services.metrics_cache_service import MetricsCacheService
from app.services.metrics_service import (
    aggregate_port_metrics_by_node,
    to_finite_float,
    to_float,
)
from app.services.ping_probe import ping_probe
from app.services.threshold_alerts import (
    sync_device_latency_alert,
    sync_device_offline_alert,
    sync_device_threshold_alert,
    sync_switch_offline_alert,
    sync_switch_threshold_alert,
)
from app.services.websocket_manager import ws_manager
from app.utils.thresholds import (
    DEVICE_THRESHOLDS,
    evaluate_device_latency_severity,
    evaluate_device_severity,
    evaluate_switch_severity,
)

logger = logging.getLogger(__name__)

_status_poller_task: Optional[asyncio.Task] = None
_librenms_sync_task: Optional[asyncio.Task] = None
_status_poller_stop_event: Optional[asyncio.Event] = None

_device_status_cache: Dict[int, str] = {}
_switch_status_cache: Dict[int, str] = {}
_device_failure_count: Dict[int, int] = {}
_switch_failure_count: Dict[int, int] = {}
_device_success_count: Dict[int, int] = {}
_switch_success_count: Dict[int, int] = {}

_cached_device_totals: Dict[int, tuple] = {}
_cached_switch_totals: Dict[int, tuple] = {}
_cached_switch_capacity: Dict[int, float] = {}
_cached_librenms_status_map: Dict[int, dict] = {}

OFFLINE_FAIL_REQUIRED = 3
RECOVERY_SUCCESS_REQUIRED = 2


def _open_db() -> Session:
    return SessionLocal()


def _append_status_history_if_changed(
    db: Session,
    *,
    node_type: str,
    node_id: int,
    old_status: Optional[str],
    new_status: str,
) -> None:
    if old_status is None or old_status == new_status:
        return
    db.add(
        StatusHistory(
            node_type=node_type,
            node_id=node_id,
            status=new_status,
            changed_at=datetime.now(),
        )
    )


async def _sync_threshold_alerts(
    db: Session,
    devices: list[Device],
    switches: list[Switch],
    latency_by_lnms_id: Dict[int, Optional[float]],
    device_totals: dict,
    switch_totals: dict,
    switch_capacity: dict,
):
    for device in devices:
        status = (device.status or "").lower()
        if status != "online":
            sync_device_threshold_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="Device not online",
                data_found=True,
            )
            sync_device_latency_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="Device not online",
                data_found=True,
            )
            continue

        if device.device_id not in device_totals:
            sync_device_threshold_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="No valid rate data",
                data_found=False,
            )
        else:
            in_mbps, out_mbps = device_totals.get(device.device_id, (0.0, 0.0))
            severity = evaluate_device_severity(device.device_type, in_mbps, out_mbps)
            sync_device_threshold_alert(
                db,
                device_id=device.device_id,
                severity=severity,
                message=f"Throughput: {in_mbps:.2f} Mbps in / {out_mbps:.2f} Mbps out",
                data_found=True,
            )

        device_type_key = (device.device_type or "").strip().lower().replace("_", " ")
        has_latency_rule = (
            device_type_key in DEVICE_THRESHOLDS
            and "latency" in DEVICE_THRESHOLDS[device_type_key]
        )

        if has_latency_rule:
            lnms_id = device.librenms_device_id
            latency_ms = latency_by_lnms_id.get(int(lnms_id)) if lnms_id else None
            cached_dev = MetricsCacheService.get_device(device.device_id)

            if cached_dev and cached_dev.get("latency_ms") is not None:
                latency_ms = cached_dev["latency_ms"]

            latency_sev = evaluate_device_latency_severity(
                device.device_type, latency_ms
            )
            sync_device_latency_alert(
                db,
                device_id=device.device_id,
                severity=latency_sev,
                message=(
                    f"Latency: {latency_ms:.2f} ms"
                    if latency_ms is not None
                    else "Latency unavailable"
                ),
                data_found=latency_ms is not None,
            )
        else:
            sync_device_latency_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="Latency rule not configured for this device type",
                data_found=True,
            )

    for switch in switches:
        status = (switch.status or "").lower()
        if status != "online":
            sync_switch_threshold_alert(
                db,
                switch_id=switch.switch_id,
                severity="green",
                message="Switch not online",
                data_found=True,
            )
            continue

        if switch.switch_id not in switch_totals:
            sync_switch_threshold_alert(
                db,
                switch_id=switch.switch_id,
                severity="green",
                message="No valid rate data",
                data_found=False,
            )
            continue

        in_mbps, out_mbps = switch_totals.get(switch.switch_id, (0.0, 0.0))
        capacity = switch_capacity.get(switch.switch_id, 0.0)
        utilization = ((in_mbps + out_mbps) / capacity) * 100 if capacity > 0 else None
        severity = evaluate_switch_severity(utilization, "switch")

        sync_switch_threshold_alert(
            db,
            switch_id=switch.switch_id,
            severity=severity,
            message=(
                f"Utilization: {utilization:.2f}%"
                if utilization is not None
                else "Utilization unavailable"
            ),
            data_found=True,
        )


async def _run_librenms_sync_loop(libre_service: LibreNMSService):
    global \
        _cached_device_totals, \
        _cached_switch_totals, \
        _cached_switch_capacity, \
        _cached_librenms_status_map
    logger.info("Started Background LibreNMS Traffic Sync (60s interval)")

    while not _status_poller_stop_event.is_set():
        try:
            db = _open_db()
            try:
                librenms_devices = await libre_service.get_devices()
                _cached_librenms_status_map = {
                    int(d["device_id"]): {
                        "status": "online" if d.get("status") == 1 else "offline",
                        "latency_ms": to_float(d.get("last_ping_timetaken")),
                    }
                    for d in librenms_devices
                    if d.get("device_id")
                }

                (
                    device_totals,
                    switch_totals,
                    _,
                    switch_capacity,
                    _,
                ) = await aggregate_port_metrics_by_node(db, None)

                _cached_device_totals = device_totals
                _cached_switch_totals = switch_totals
                _cached_switch_capacity = switch_capacity
                logger.info("Successfully cached 1-minute LibreNMS traffic data.")
            finally:
                db.close()
        except asyncio.CancelledError:
            raise
        except Exception as e:
            logger.error("Error in LibreNMS background sync: %s", e)

        try:
            await asyncio.wait_for(_status_poller_stop_event.wait(), timeout=60.0)
        except asyncio.TimeoutError:
            continue


async def poll_and_broadcast_status() -> int:
    global _device_status_cache, _switch_status_cache
    changes_detected = 0
    db = _open_db()

    try:

        async def _evaluate_node_state(
            node, node_type, cache_dict, fail_dict, succ_dict
        ):
            nonlocal changes_detected
            node_id = getattr(node, f"{node_type}_id")
            old_status = cache_dict.get(node_id)

            lnms_id = node.librenms_device_id
            raw_status = "offline"
            if lnms_id and lnms_id in _cached_librenms_status_map:
                raw_status = _cached_librenms_status_map[lnms_id]["status"]

            if raw_status == "offline":
                succ_dict[node_id] = 0
                fail_dict[node_id] = fail_dict.get(node_id, 0) + 1
                new_status = (
                    "offline"
                    if fail_dict[node_id] >= OFFLINE_FAIL_REQUIRED
                    else "warning"
                )
            else:
                fail_dict[node_id] = 0
                succ_dict[node_id] = succ_dict.get(node_id, 0) + 1
                new_status = (
                    "online"
                    if succ_dict[node_id] >= RECOVERY_SUCCESS_REQUIRED
                    else old_status or "online"
                )

            if old_status != new_status:
                cache_dict[node_id] = new_status
                if old_status is not None:
                    changes_detected += 1

                node.status = new_status
                node.librenms_last_synced = datetime.now()
                db.add(node)

                _append_status_history_if_changed(
                    db,
                    node_type=node_type,
                    node_id=node_id,
                    old_status=old_status,
                    new_status=new_status,
                )

                if new_status == "offline":
                    if node_type == "device":
                        sync_device_offline_alert(
                            db, device_id=node_id, is_offline=True, data_found=True
                        )
                    else:
                        sync_switch_offline_alert(
                            db, switch_id=node_id, is_offline=True, data_found=True
                        )
                elif old_status == "offline" and new_status == "online":
                    if node_type == "device":
                        sync_device_offline_alert(
                            db, device_id=node_id, is_offline=False, data_found=True
                        )
                    else:
                        sync_switch_offline_alert(
                            db, switch_id=node_id, is_offline=False, data_found=True
                        )

                await ws_manager.broadcast(
                    {
                        "type": "status_change",
                        "node_type": node_type,
                        "id": node_id,
                        "name": node.name,
                        "ip_address": node.ip_address,
                        "old_status": old_status,
                        "new_status": new_status,
                        "timestamp": datetime.now().isoformat(),
                    }
                )
            return new_status

        devices = db.query(Device).all()

        ips_to_ping = [d.ip_address for d in devices if d.ip_address]

        if settings.PING_PROBE_ENABLED:
            bulk_ping_results = await ping_probe.ping_bulk(ips_to_ping)
        else:
            bulk_ping_results = {}

        for device in devices:
            curr_status = await _evaluate_node_state(
                device,
                "device",
                _device_status_cache,
                _device_failure_count,
                _device_success_count,
            )

            latency_ms = bulk_ping_results.get(device.ip_address)

            if latency_ms is None:
                if device.librenms_device_id in _cached_librenms_status_map:
                    latency_ms = _cached_librenms_status_map[device.librenms_device_id][
                        "latency_ms"
                    ]
                else:
                    latency_ms = None

            in_mbps, out_mbps = _cached_device_totals.get(device.device_id, (0.0, 0.0))

            MetricsCacheService.update_device(
                device.device_id,
                {
                    "device_id": device.device_id,
                    "status": curr_status,
                    "in_mbps": round(in_mbps, 2),
                    "out_mbps": round(out_mbps, 2),
                    "latency_ms": to_finite_float(latency_ms),
                    "monitored": device.librenms_device_id is not None,
                },
            )

        switches = db.query(Switch).all()
        for switch in switches:
            curr_status = await _evaluate_node_state(
                switch,
                "switch",
                _switch_status_cache,
                _switch_failure_count,
                _switch_success_count,
            )

            in_mbps, out_mbps = _cached_switch_totals.get(switch.switch_id, (0.0, 0.0))
            capacity = _cached_switch_capacity.get(switch.switch_id, 0.0)

            MetricsCacheService.update_switch(
                switch.switch_id,
                {
                    "switch_id": switch.switch_id,
                    "status": curr_status,
                    "in_mbps": round(in_mbps, 2),
                    "out_mbps": round(out_mbps, 2),
                    "capacity_mbps": capacity,
                },
            )

        await _sync_threshold_alerts(
            db,
            devices,
            switches,
            {k: v["latency_ms"] for k, v in _cached_librenms_status_map.items()},
            _cached_device_totals,
            _cached_switch_totals,
            _cached_switch_capacity,
        )
        db.commit()

        if ws_manager.connection_count > 0:

            def clean_for_json(data: dict) -> dict:
                cleaned = data.copy()
                if "updated_at" in cleaned and isinstance(
                    cleaned["updated_at"], datetime
                ):
                    cleaned["updated_at"] = cleaned["updated_at"].isoformat()
                return cleaned

            live_device_metrics = [
                clean_for_json(MetricsCacheService.get_device(d.device_id))
                for d in devices
                if MetricsCacheService.get_device(d.device_id)
            ]
            live_switch_metrics = [
                clean_for_json(MetricsCacheService.get_switch(s.switch_id))
                for s in switches
                if MetricsCacheService.get_switch(s.switch_id)
            ]

            await ws_manager.broadcast(
                {
                    "type": "metrics_update",
                    "timestamp": datetime.now().isoformat(),
                    "device_metrics": live_device_metrics,
                    "switch_metrics": live_switch_metrics,
                }
            )

            await ws_manager.broadcast(
                {
                    "type": "heartbeat",
                    "timestamp": datetime.now().isoformat(),
                    "total_devices": len(devices),
                    "total_switches": len(switches),
                    "online_devices": sum(
                        1
                        for d in devices
                        if _device_status_cache.get(d.device_id) == "online"
                    ),
                    "online_switches": sum(
                        1
                        for s in switches
                        if _switch_status_cache.get(s.switch_id) == "online"
                    ),
                }
            )

    except Exception as e:
        logger.exception("Error polling device status: %s", e)
        db.rollback()
    finally:
        db.close()

    return changes_detected


async def _run_status_poller(interval_seconds: int) -> None:
    logger.info("Fast Ping poller starting (interval=%s seconds)", interval_seconds)
    while not _status_poller_stop_event.is_set():
        loop_start = time.monotonic()

        try:
            changes = await poll_and_broadcast_status()
            if changes > 0:
                logger.info("Detected %d status changes", changes)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Error in status poller loop")

        elapsed = time.monotonic() - loop_start

        sleep_time = max(0.0, interval_seconds - elapsed)

        try:
            await asyncio.wait_for(_status_poller_stop_event.wait(), timeout=sleep_time)
        except asyncio.TimeoutError:
            continue


def start_status_poller_task(
    libre_service: LibreNMSService, interval_seconds: int = 5
) -> asyncio.Task:
    global _status_poller_task, _librenms_sync_task, _status_poller_stop_event

    if _status_poller_task and not _status_poller_task.done():
        return _status_poller_task

    _status_poller_stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()

    _librenms_sync_task = loop.create_task(_run_librenms_sync_loop(libre_service))
    _status_poller_task = loop.create_task(_run_status_poller(interval_seconds))

    return _status_poller_task


async def stop_status_poller_task() -> None:
    global _status_poller_task, _librenms_sync_task, _status_poller_stop_event

    if _status_poller_stop_event:
        _status_poller_stop_event.set()

    tasks = []
    if _status_poller_task:
        tasks.append(_status_poller_task)
    if _librenms_sync_task:
        tasks.append(_librenms_sync_task)

    for task in tasks:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

    _status_poller_task = None
    _librenms_sync_task = None
    _status_poller_stop_event = None
