import asyncio
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models import Device, Switch
from app.services.librenms_service import LibreNMSService
from app.services.websocket_manager import ws_manager

logger = logging.getLogger(__name__)

# Module-level poller control
_status_poller_task: Optional[asyncio.Task] = None
_status_poller_stop_event: Optional[asyncio.Event] = None

# Cache to track previous status and detect changes
_device_status_cache: Dict[int, str] = {}
_switch_status_cache: Dict[int, str] = {}


def _open_db() -> Session:
    return SessionLocal()


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
        for lnms_device in librenms_devices:
            device_id = lnms_device.get("device_id")
            if device_id:
                librenms_status_map[int(device_id)] = {
                    "status": "online" if lnms_device.get("status") == 1 else "offline",
                    "hostname": lnms_device.get("hostname", ""),
                    "uptime": lnms_device.get("uptime", 0),
                    "last_polled": lnms_device.get("last_polled", ""),
                }

        # Check devices
        devices = db.query(Device).filter(Device.librenms_device_id.isnot(None)).all()
        for device in devices:
            lnms_id = device.librenms_device_id
            if lnms_id not in librenms_status_map:
                continue

            lnms_data = librenms_status_map[lnms_id]
            new_status = lnms_data["status"]
            old_status = _device_status_cache.get(device.device_id)

            # Check if status changed
            if old_status is None:
                _device_status_cache[device.device_id] = new_status
            elif old_status != new_status:
                _device_status_cache[device.device_id] = new_status
                changes_detected += 1

                # Update database
                device.status = new_status
                device.librenms_last_synced = datetime.now()

                # Broadcast status change
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

                logger.info(
                    "Device %s (%s) status changed:  %s -> %s",
                    device.name,
                    device.ip_address,
                    old_status,
                    new_status,
                )

        # Check switches
        switches = db.query(Switch).filter(Switch.librenms_device_id.isnot(None)).all()
        for switch in switches:
            lnms_id = switch.librenms_device_id
            if lnms_id not in librenms_status_map:
                continue

            lnms_data = librenms_status_map[lnms_id]
            new_status = lnms_data["status"]
            old_status = _switch_status_cache.get(switch.switch_id)

            if old_status is None:
                _switch_status_cache[switch.switch_id] = new_status
            elif old_status != new_status:
                _switch_status_cache[switch.switch_id] = new_status
                changes_detected += 1

                # Update database
                switch.status = new_status
                switch.librenms_last_synced = datetime.now()

                # Broadcast status change
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

                logger.info(
                    "Switch %s (%s) status changed: %s -> %s",
                    switch.name,
                    switch.ip_address,
                    old_status,
                    new_status,
                )

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

            # Wait for interval or stop event
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
