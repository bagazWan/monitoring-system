import asyncio
import logging
from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal
from app.models import Device, StatusHistory, Switch
from app.services.librenms_service import LibreNMSService
from app.services.metrics_service import aggregate_port_metrics_by_node, to_float
from app.services.ping_probe import ping_probe
from app.services.threshold_alerts import (
    sync_device_latency_alert,
    sync_device_threshold_alert,
    sync_switch_threshold_alert,
)
from app.services.websocket_manager import ws_manager
from app.utils.thresholds import (
    evaluate_device_latency_severity,
    evaluate_device_severity,
    evaluate_switch_severity,
)

logger = logging.getLogger(__name__)

# Module-level poller control
_status_poller_task: Optional[asyncio.Task] = None
_status_poller_stop_event: Optional[asyncio.Event] = None

# Cache to track previous status and detect changes
_device_status_cache: Dict[int, str] = {}
_switch_status_cache: Dict[int, str] = {}
_device_failure_count: Dict[int, int] = {}
_switch_failure_count: Dict[int, int] = {}


def _open_db() -> Session:
    return SessionLocal()


async def _sync_threshold_alerts(
    db: Session,
    devices: list[Device],
    switches: list[Switch],
    latency_by_lnms_id: Dict[int, Optional[float]],
):
    (
        device_totals,
        switch_totals,
        device_capacity,
        switch_capacity,
        _,
    ) = await aggregate_port_metrics_by_node(db, None)

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

        if (device.device_type or "").strip().lower() == "cctv":
            if settings.PING_PROBE_ENABLED:
                latency_ms = await ping_probe.ping(device.ip_address)
            else:
                lnms_id = device.librenms_device_id
                latency_ms = latency_by_lnms_id.get(int(lnms_id)) if lnms_id else None

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


async def poll_and_broadcast_status(libre_service: LibreNMSService) -> int:
    """
    Poll LibreNMS for all device statuses and broadcast changes via WebSocket.
    Returns the number of status changes detected.
    """
    global _device_status_cache, _switch_status_cache

    changes_detected = 0
    db = _open_db()

    try:
        librenms_devices = await libre_service.get_devices()

        librenms_status_map: Dict[int, Dict[str, Any]] = {}
        latency_by_lnms_id: Dict[int, Optional[float]] = {}

        for lnms_device in librenms_devices:
            device_id = lnms_device.get("device_id")
            if device_id:
                lnms_id = int(device_id)
                librenms_status_map[lnms_id] = {
                    "status": "online" if lnms_device.get("status") == 1 else "offline",
                    "hostname": lnms_device.get("hostname", ""),
                    "uptime": lnms_device.get("uptime", 0),
                    "last_polled": lnms_device.get("last_polled", ""),
                }
                latency_by_lnms_id[lnms_id] = to_float(
                    lnms_device.get("latency_ms") or lnms_device.get("latency")
                )

        # Check devices
        devices = db.query(Device).filter(Device.librenms_device_id.isnot(None)).all()
        for device in devices:
            lnms_id = device.librenms_device_id
            if lnms_id not in librenms_status_map:
                continue

            lnms_data = librenms_status_map[lnms_id]
            raw_status = lnms_data["status"]
            old_status = _device_status_cache.get(device.device_id)

            failure_count = _device_failure_count.get(device.device_id, 0)

            if raw_status == "offline":
                failure_count += 1
                _device_failure_count[device.device_id] = failure_count
                if failure_count >= 3:
                    new_status = "offline"
                else:
                    new_status = "warning"
            else:
                _device_failure_count[device.device_id] = 0
                new_status = "online"

            if old_status is None:
                _device_status_cache[device.device_id] = new_status
            elif old_status != new_status:
                _device_status_cache[device.device_id] = new_status
                changes_detected += 1

                device.status = new_status
                device.librenms_last_synced = datetime.now()

                db.add(
                    StatusHistory(
                        node_type="device",
                        node_id=device.device_id,
                        status=new_status,
                        changed_at=datetime.now(),
                    )
                )

                await ws_manager.broadcast(
                    {
                        "type": "status_change",
                        "node_type": "device",
                        "id": device.device_id,
                        "name": device.name,
                        "ip_address": device.ip_address,
                        "old_status": old_status,
                        "new_status": new_status,
                        "timestamp": datetime.now().isoformat(),
                    }
                )

        switches = db.query(Switch).filter(Switch.librenms_device_id.isnot(None)).all()
        for switch in switches:
            lnms_id = switch.librenms_device_id
            if lnms_id not in librenms_status_map:
                continue

            lnms_data = librenms_status_map[lnms_id]
            raw_status = lnms_data["status"]
            old_status = _switch_status_cache.get(switch.switch_id)

            failure_count = _switch_failure_count.get(switch.switch_id, 0)

            if raw_status == "offline":
                failure_count += 1
                _switch_failure_count[switch.switch_id] = failure_count
                if failure_count >= 3:
                    new_status = "offline"
                else:
                    new_status = "warning"
            else:
                _switch_failure_count[switch.switch_id] = 0
                new_status = "online"

            if old_status is None:
                _switch_status_cache[switch.switch_id] = new_status
            elif old_status != new_status:
                _switch_status_cache[switch.switch_id] = new_status
                changes_detected += 1

                switch.status = new_status
                switch.librenms_last_synced = datetime.now()

                db.add(
                    StatusHistory(
                        node_type="switch",
                        node_id=switch.switch_id,
                        status=new_status,
                        changed_at=datetime.now(),
                    )
                )

                await ws_manager.broadcast(
                    {
                        "type": "status_change",
                        "node_type": "switch",
                        "id": switch.switch_id,
                        "name": switch.name,
                        "ip_address": switch.ip_address,
                        "old_status": old_status,
                        "new_status": new_status,
                        "timestamp": datetime.now().isoformat(),
                    }
                )

        await _sync_threshold_alerts(db, devices, switches, latency_by_lnms_id)

        db.commit()

        if ws_manager.connection_count > 0:
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
        logger.exception("Error polling device status:  %s", e)
    finally:
        db.close()

    return changes_detected


async def _run_status_poller(
    libre_service: LibreNMSService, interval_seconds: int
) -> None:
    """
    Background loop that periodically polls status and broadcasts changes.
    """
    global _status_poller_stop_event

    if _status_poller_stop_event is None:
        _status_poller_stop_event = asyncio.Event()

    logger.info("Status poller starting (interval=%s seconds)", interval_seconds)

    try:
        while not _status_poller_stop_event.is_set():
            try:
                changes = await poll_and_broadcast_status(libre_service)
                if changes > 0:
                    logger.info("Detected %d status changes", changes)
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Error in status poller loop")

            try:
                await asyncio.wait_for(
                    _status_poller_stop_event.wait(), timeout=interval_seconds
                )
            except asyncio.TimeoutError:
                continue
    except asyncio.CancelledError:
        logger.info("Status poller task cancelled")
    finally:
        logger.info("Status poller stopped")


def start_status_poller_task(
    libre_service: LibreNMSService, interval_seconds: int = 5
) -> asyncio.Task:
    """
    Start the status poller as a background task.
    Default interval is 5 seconds for responsive real-time updates.
    """
    global _status_poller_task, _status_poller_stop_event

    if _status_poller_task and not _status_poller_task.done():
        return _status_poller_task

    _status_poller_stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    _status_poller_task = loop.create_task(
        _run_status_poller(libre_service, interval_seconds)
    )
    return _status_poller_task


async def stop_status_poller_task() -> None:
    """Stop the status poller task."""
    global _status_poller_task, _status_poller_stop_event

    if _status_poller_stop_event:
        _status_poller_stop_event.set()

    if _status_poller_task:
        _status_poller_task.cancel()
        try:
            await _status_poller_task
        except asyncio.CancelledError:
            pass
        _status_poller_task = None
        _status_poller_stop_event = None
