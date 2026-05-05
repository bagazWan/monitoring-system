import asyncio
import logging
import time
from datetime import datetime

from app.core.config import settings
from app.core.database import create_session
from app.models import Device, Switch
from app.services.librenms.client import LibreNMSService
from app.services.metrics.aggregation import (
    aggregate_port_metrics_by_node,
    to_finite_float,
    to_float,
)
from app.services.metrics.cache import MetricsCacheService
from app.services.metrics.ping import ping_probe
from app.services.monitoring.websocket_manager import ws_manager

from . import state
from .evaluator import evaluate_node_state, sync_threshold_alerts_logic

logger = logging.getLogger(__name__)


async def run_librenms_sync_loop(libre_service: LibreNMSService):
    logger.info("Started Background LibreNMS Traffic Sync (60s interval)")
    while not state.status_poller_stop_event.is_set():
        try:
            db = create_session()
            try:
                librenms_devices = await libre_service.get_devices()
                state.cached_librenms_status_map = {
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
                state.cached_device_totals = device_totals
                state.cached_switch_totals = switch_totals
                state.cached_switch_capacity = switch_capacity
            finally:
                db.close()
        except asyncio.CancelledError:
            raise
        except Exception as e:
            logger.error("Error in LibreNMS background sync: %s", e)

        try:
            await asyncio.wait_for(state.status_poller_stop_event.wait(), timeout=60.0)
        except asyncio.TimeoutError:
            continue


async def _broadcast_websocket_metrics(devices, switches):
    def clean_for_json(data: dict) -> dict:
        cleaned = data.copy()
        if "updated_at" in cleaned and isinstance(cleaned["updated_at"], datetime):
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

    now_iso = datetime.now().isoformat()
    await ws_manager.broadcast(
        {
            "type": "metrics_update",
            "timestamp": now_iso,
            "device_metrics": live_device_metrics,
            "switch_metrics": live_switch_metrics,
        }
    )
    await ws_manager.broadcast(
        {
            "type": "heartbeat",
            "timestamp": now_iso,
            "total_devices": len(devices),
            "total_switches": len(switches),
            "online_devices": sum(
                1
                for d in devices
                if state.device_status_cache.get(d.device_id) == "online"
            ),
            "online_switches": sum(
                1
                for s in switches
                if state.switch_status_cache.get(s.switch_id) == "online"
            ),
        }
    )


async def poll_and_broadcast_status() -> int:
    changes = 0
    db = create_session()
    try:
        devices = db.query(Device).all()
        ips_to_ping = [d.ip_address for d in devices if d.ip_address]
        bulk_ping_results = (
            await ping_probe.ping_bulk(ips_to_ping)
            if settings.PING_PROBE_ENABLED
            else {}
        )

        for device in devices:
            curr_status, changed = await evaluate_node_state(db, device, "device")
            if changed:
                changes += 1

            latency_ms = bulk_ping_results.get(device.ip_address)
            if (
                latency_ms is None
                and device.librenms_device_id in state.cached_librenms_status_map
            ):
                latency_ms = state.cached_librenms_status_map[
                    device.librenms_device_id
                ]["latency_ms"]

            in_mbps, out_mbps = state.cached_device_totals.get(
                device.device_id, (0.0, 0.0)
            )
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
            curr_status, changed = await evaluate_node_state(db, switch, "switch")
            if changed:
                changes += 1

            in_mbps, out_mbps = state.cached_switch_totals.get(
                switch.switch_id, (0.0, 0.0)
            )
            capacity = state.cached_switch_capacity.get(switch.switch_id, 0.0)
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

        sync_threshold_alerts_logic(db, devices, switches)
        db.commit()

        if ws_manager.connection_count > 0:
            await _broadcast_websocket_metrics(devices, switches)

    except Exception as e:
        logger.exception("Error polling device status: %s", e)
        db.rollback()
    finally:
        db.close()
    return changes


async def run_status_poller(interval_seconds: int) -> None:
    logger.info("Fast Ping poller starting (interval=%s seconds)", interval_seconds)
    while not state.status_poller_stop_event.is_set():
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
        try:
            await asyncio.wait_for(
                state.status_poller_stop_event.wait(),
                timeout=max(0.0, interval_seconds - elapsed),
            )
        except asyncio.TimeoutError:
            continue
