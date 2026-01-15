import asyncio
import logging
from datetime import datetime
from hashlib import sha1
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models import Alert, Device, Switch, SwitchAlert
from app.services.librenms_service import LibreNMSService

logger = logging.getLogger(__name__)

# Module-level poller control variables
_poller_task: Optional[asyncio.Task] = None
_poller_stop_event: Optional[asyncio.Event] = None

try:
    from app.notifications import notify_all_channels  # type: ignore
except Exception:
    notify_all_channels = None  # type: ignore


def _make_synthetic_alert_id(payload: Dict[str, Any]) -> str:
    """
    Create a deterministic synthetic id for alerts that don't have an external id.
    Uses device id + type + message + truncated timestamp (if present) to form hash.
    """
    device_part = str(payload.get("device_id") or payload.get("device") or "")
    alert_type = str(payload.get("type") or payload.get("alert_type") or "")
    message = str(
        payload.get("message") or payload.get("note") or payload.get("text") or ""
    )
    ts = str(payload.get("time") or payload.get("timestamp") or "")
    base = "|".join([device_part, alert_type, message, ts])
    return sha1(base.encode("utf-8")).hexdigest()


def _open_db() -> Session:
    """
    Open and return a SQLAlchemy Session from SessionLocal.
    Callers must close() the returned session.
    """
    return SessionLocal()


async def process_librenms_alerts(librenms_alerts: List[Dict[str, Any]]) -> int:
    """
    Process a list of raw alerts returned from LibreNMS.
    - Deduplicate using `librenms_alert_id` when present
    - Map to either `Alert` (device) or `SwitchAlert` (switch) depending on whether the device exists in switches
    - Persist new alerts or update existing alert status/severity/message
    - Trigger notifications (if notify_all_channels exists)
    Returns number of processed alerts (created + updated)
    """
    if not librenms_alerts:
        return 0

    processed = 0
    db = _open_db()
    try:
        for raw in librenms_alerts:
            try:
                # canonicalize fields from LibreNMS payload
                librenms_alert_id = (
                    raw.get("id") or raw.get("alert_id") or raw.get("alertId")
                )
                librenms_device_id = (
                    raw.get("device_id")
                    or raw.get("deviceId")
                    or raw.get("device")
                    or raw.get("hostname_device_id")
                )
                try:
                    if librenms_alert_id is not None:
                        librenms_alert_id = int(librenms_alert_id)
                except Exception:
                    # if cannot cast, keep as-is (DB column is Integer nullable; casting failures will be ignored)
                    pass

                alert_type = (
                    raw.get("type")
                    or raw.get("rule")
                    or raw.get("alert")
                    or raw.get("event")
                    or ""
                )
                severity = (
                    raw.get("severity") or raw.get("priority") or raw.get("level") or ""
                )
                message = (
                    raw.get("message")
                    or raw.get("note")
                    or raw.get("text")
                    or raw.get("description")
                    or ""
                )
                status = (
                    raw.get("status")
                    or raw.get("state")
                    or raw.get("alert_status")
                    or "active"
                )

                cleared_at = None
                if str(status).lower() in ("cleared", "resolved", "closed", "ok"):
                    cleared_at = datetime.utcnow()

                # Lookup whether this librenms device is stored as a Switch or a generic Device
                target_switch = None
                target_device = None
                if librenms_device_id is not None:
                    # prefer Switch first
                    target_switch = (
                        db.query(Switch)
                        .filter(
                            getattr(Switch, "librenms_device_id") == librenms_device_id
                        )
                        .first()
                    )
                    if not target_switch:
                        target_device = (
                            db.query(Device)
                            .filter(
                                getattr(Device, "librenms_device_id")
                                == librenms_device_id
                            )
                            .first()
                        )

                # If no DB object found, skip processing this alert
                if not target_switch and not target_device:
                    logger.debug(
                        "Skipping alert from LibreNMS because corresponding device not found in DB (librenms_device_id=%s). Raw: %s",
                        librenms_device_id,
                        raw,
                    )
                    continue

                # Determine whether to create/update SwitchAlert or Alert
                Model = SwitchAlert if target_switch else Alert

                # Deduplication: try to find existing by librenms_alert_id if present
                existing = None
                if librenms_alert_id:
                    existing = (
                        db.query(Model)
                        .filter(
                            getattr(Model, "librenms_alert_id") == librenms_alert_id
                        )
                        .first()
                    )
                else:
                    # fallback dedupe: match by device/switch id + alert_type + message (for active alerts)
                    if target_switch:
                        existing = (
                            db.query(SwitchAlert)
                            .filter(SwitchAlert.switch_id == target_switch.switch_id)
                            .filter(SwitchAlert.alert_type == alert_type)
                            .filter(SwitchAlert.message == message)
                            .filter(SwitchAlert.status != "cleared")
                            .first()
                        )
                    else:
                        existing = (
                            db.query(Alert)
                            .filter(Alert.device_id == target_device.device_id)
                            .filter(Alert.alert_type == alert_type)
                            .filter(Alert.message == message)
                            .filter(Alert.status != "cleared")
                            .first()
                        )

                if existing:
                    # Update existing alert record
                    changed = False
                    if existing.status != "cleared":
                        if existing.status != status:
                            existing.status = status
                            changed = True
                    if str(status).lower() in ("cleared", "ok", "closed"):
                        if existing.status != status:
                            existing.status = status
                            changed = True
                    if existing.severity != severity:
                        existing.severity = severity
                        changed = True
                    if existing.message != message:
                        existing.message = message
                        changed = True
                    if existing.status != status:
                        existing.status = status
                        changed = True
                    if cleared_at and getattr(existing, "cleared_at", None) is None:
                        existing.cleared_at = cleared_at
                        changed = True

                    if changed:
                        db.add(existing)
                        processed += 1
                        logger.debug(
                            "Updated existing alert %s (librenms_alert_id=%s)",
                            existing,
                            librenms_alert_id,
                        )
                        # notify update
                        try:
                            if notify_all_channels:
                                # send minimal payload with DB id and new status
                                await _maybe_notify(
                                    {
                                        "alert_id": getattr(existing, "alert_id", None),
                                        "librenms_alert_id": librenms_alert_id,
                                        "device_id": getattr(
                                            existing, "device_id", None
                                        ),
                                        "switch_id": getattr(
                                            existing, "switch_id", None
                                        ),
                                        "alert_type": existing.alert_type,
                                        "severity": existing.severity,
                                        "message": existing.message,
                                        "status": existing.status,
                                    }
                                )
                        except Exception:
                            logger.exception(
                                "Notification failed for updated alert librenms_id=%s",
                                librenms_alert_id,
                            )
                else:
                    # Create new alert
                    if target_switch:
                        new_alert = SwitchAlert(
                            switch_id=target_switch.switch_id,
                            librenms_alert_id=librenms_alert_id
                            if isinstance(librenms_alert_id, int)
                            else None,
                            category_id=None,
                            alert_type=alert_type or "unknown",
                            severity=severity,
                            message=message,
                            assigned_to_user_id=None,
                            created_at=datetime.utcnow(),
                            cleared_at=cleared_at,
                            status=status,
                        )
                    else:
                        new_alert = Alert(
                            device_id=target_device.device_id,
                            librenms_alert_id=librenms_alert_id
                            if isinstance(librenms_alert_id, int)
                            else None,
                            category_id=None,
                            alert_type=alert_type or "unknown",
                            severity=severity,
                            message=message,
                            assigned_to_user_id=None,
                            created_at=datetime.utcnow(),
                            cleared_at=cleared_at,
                            status=status,
                        )

                    db.add(new_alert)
                    db.flush()  # ensure PK is available
                    processed += 1
                    logger.info(
                        "Created new alert for %s (librenms_alert_id=%s) -> %s",
                        "switch" if target_switch else "device",
                        librenms_alert_id,
                        message,
                    )

                    try:
                        if notify_all_channels:
                            payload = {
                                "type": "alert",
                                "alert_id": getattr(new_alert, "alert_id", None),
                                "librenms_alert_id": librenms_alert_id,
                                "device_id": getattr(new_alert, "device_id", None),
                                "switch_id": getattr(new_alert, "switch_id", None),
                                "alert_type": new_alert.alert_type,
                                "severity": new_alert.severity,
                                "message": new_alert.message,
                                "status": new_alert.status,
                            }
                            await _maybe_notify(payload)
                    except Exception:
                        logger.exception(
                            "Notification failed for new alert librenms_id=%s",
                            librenms_alert_id,
                        )

            except Exception:
                logger.exception("Failed to process single librenms alert: %s", raw)
                # continue with next alert

        # commit once after processing the batch
        db.commit()
    finally:
        db.close()

    return processed


async def _maybe_notify(payload: Dict[str, Any]) -> None:
    """
    Wrapper to call notify_all_channels() if available.
    Keep notifications best-effort: exceptions are logged but not re-raised.
    """
    if not notify_all_channels:
        return
    try:
        # notify_all_channels may be sync or async; handle both
        result = notify_all_channels(payload)
        if asyncio.iscoroutine(result):
            await result
    except Exception:
        logger.exception(
            "notify_all_channels raised an exception for payload: %s", payload
        )


async def sync_alerts_once(libre_service: LibreNMSService) -> int:
    """
    Fetch alerts once from LibreNMS and process them immediately.
    Returns count processed (created + updated).
    """
    lib_alerts: List[Dict[str, Any]] = []
    try:
        lib_alerts = await libre_service.get_alerts()
    except Exception as exc:
        logger.exception("Failed to fetch alerts from LibreNMS: %s", exc)
        raise

    processed = await process_librenms_alerts(lib_alerts)
    logger.info("Processed %d alerts from LibreNMS (one-shot)", processed)
    return processed


async def _run_poller(libre_service: LibreNMSService, interval_seconds: int) -> None:
    """
    The actual background loop that periodically pulls alerts and processes them.
    This coroutine returns when the stop event is set or when cancelled.
    """
    global _poller_stop_event
    if _poller_stop_event is None:
        _poller_stop_event = asyncio.Event()

    logger.info("Alerts poller starting (interval=%s seconds)", interval_seconds)
    try:
        while not _poller_stop_event.is_set():
            try:
                await sync_alerts_once(libre_service)
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Error occurred while polling/processing alerts")

            # Wait for either stop event or timeout
            try:
                await asyncio.wait_for(
                    _poller_stop_event.wait(), timeout=interval_seconds
                )
            except asyncio.TimeoutError:
                # timeout means continue loop
                continue
    except asyncio.CancelledError:
        logger.info("Alerts poller task cancelled")
    finally:
        logger.info("Alerts poller stopped")


def start_alerts_poller_task(
    libre_service: LibreNMSService, interval_seconds: int = 30
) -> asyncio.Task:
    """
    Create and return an asyncio.Task that runs the alerts poller in background.
    If a poller task is already running, the existing task is returned.
    This function must be called from an active event loop (e.g. FastAPI startup).
    """
    global _poller_task, _poller_stop_event

    if _poller_task and not _poller_task.done():
        return _poller_task

    _poller_stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    _poller_task = loop.create_task(_run_poller(libre_service, interval_seconds))
    return _poller_task


async def stop_alerts_poller_task() -> None:
    """
    Stop the running poller task (if any) and wait for it to finish.
    Safe to call from shutdown handlers.
    """
    global _poller_task, _poller_stop_event
    if _poller_stop_event:
        _poller_stop_event.set()

    if _poller_task:
        _poller_task.cancel()
        try:
            await _poller_task
        except asyncio.CancelledError:
            pass
        _poller_task = None
        _poller_stop_event = None
