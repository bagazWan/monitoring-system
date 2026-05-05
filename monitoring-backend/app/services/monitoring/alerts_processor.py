import asyncio
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import create_session
from app.models import Alert, Device, Switch, SwitchAlert
from app.services.normalizer import normalize_status

logger = logging.getLogger(__name__)

try:
    from app.notifications import notify_all_channels  # type: ignore
except Exception:
    notify_all_channels = None  # type: ignore


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _is_device_down_alert(message: str, rule: str) -> bool:
    msg = (message or "").lower()
    r = (rule or "").lower()
    keywords = ["device down", "no response", "unreachable", "icmp", "ping"]
    return any(k in msg for k in keywords) or any(k in r for k in keywords)


def _parse_alert_payload(raw: Dict[str, Any]) -> Dict[str, Any]:
    librenms_alert_id = raw.get("id") or raw.get("alert_id") or raw.get("alertId")
    try:
        librenms_alert_id_int = (
            int(librenms_alert_id) if librenms_alert_id is not None else None
        )
    except Exception:
        librenms_alert_id_int = None

    status = normalize_status(
        raw.get("status") or raw.get("state") or raw.get("alert_status") or "active"
    )

    return {
        "librenms_alert_id": librenms_alert_id_int,
        "librenms_device_id": raw.get("device_id")
        or raw.get("deviceId")
        or raw.get("device")
        or raw.get("hostname_device_id"),
        "alert_type": raw.get("type")
        or raw.get("rule")
        or raw.get("alert")
        or raw.get("event")
        or "",
        "severity": raw.get("severity")
        or raw.get("priority")
        or raw.get("level")
        or "",
        "message": raw.get("message")
        or raw.get("note")
        or raw.get("text")
        or raw.get("description")
        or "",
        "status": status,
        "cleared_at": _utcnow() if status == "cleared" else None,
    }


async def _maybe_notify(payload: Dict[str, Any]) -> None:
    if not notify_all_channels:
        return
    try:
        result = notify_all_channels(payload)
        if asyncio.iscoroutine(result):
            await result
    except Exception:
        logger.exception(
            "notify_all_channels raised an exception for payload: %s", payload
        )


async def _notify_alert_change(
    event_type: str,
    alert_obj,
    lnms_id: Optional[int],
    dev_name: Optional[str],
    sw_name: Optional[str],
    loc_name: Optional[str],
) -> None:
    try:
        payload = {
            "type": "alert",
            "alert_id": getattr(alert_obj, "alert_id", None),
            "librenms_alert_id": lnms_id,
            "device_id": getattr(alert_obj, "device_id", None),
            "switch_id": getattr(alert_obj, "switch_id", None),
            "device_name": dev_name,
            "switch_name": sw_name,
            "location_name": loc_name,
            "alert_type": alert_obj.alert_type,
            "severity": alert_obj.severity,
            "message": alert_obj.message,
            "status": alert_obj.status,
        }
        await _maybe_notify(payload)
    except Exception:
        logger.exception(
            "Notification failed for %s alert librenms_id=%s", event_type, lnms_id
        )


async def _upsert_librenms_alert(
    db: Session,
    parsed: Dict[str, Any],
    active_dev_ids: Set[int],
    active_sw_ids: Set[int],
) -> int:
    if not _is_device_down_alert(parsed["message"], parsed["alert_type"]):
        return 0

    lnms_dev_id = parsed["librenms_device_id"]
    lnms_alert_id = parsed["librenms_alert_id"]
    status = parsed["status"]

    target_switch = (
        db.query(Switch).filter(Switch.librenms_device_id == lnms_dev_id).first()
        if lnms_dev_id
        else None
    )
    target_device = (
        db.query(Device).filter(Device.librenms_device_id == lnms_dev_id).first()
        if lnms_dev_id
        else None
    )

    if (target_switch and target_device) or (not target_switch and not target_device):
        return 0

    Model = SwitchAlert if target_switch else Alert
    if status == "active" and lnms_alert_id is not None:
        (active_sw_ids if target_switch else active_dev_ids).add(lnms_alert_id)

    existing = (
        db.query(Model).filter(Model.librenms_alert_id == lnms_alert_id).first()
        if lnms_alert_id
        else None
    )

    dev_name = target_device.name if target_device else None
    sw_name = target_switch.name if target_switch else None
    loc_name = (
        target_switch.location.name
        if target_switch and target_switch.location
        else (
            target_device.location.name
            if target_device and target_device.location
            else None
        )
    )

    if existing:
        changed = False
        if existing.status != status:
            existing.status, changed = status, True
        if existing.severity != parsed["severity"]:
            existing.severity, changed = parsed["severity"], True
        if existing.message != parsed["message"]:
            existing.message, changed = parsed["message"], True
        if status == "cleared" and not getattr(existing, "cleared_at", None):
            existing.cleared_at, changed = parsed["cleared_at"] or _utcnow(), True

        if changed:
            db.add(existing)
            db.flush()
            await _notify_alert_change(
                "update", existing, lnms_alert_id, dev_name, sw_name, loc_name
            )
            return 1
        return 0

    kwargs = {
        "librenms_alert_id": lnms_alert_id,
        "category_id": None,
        "alert_type": parsed["alert_type"] or "unknown",
        "severity": parsed["severity"],
        "message": parsed["message"],
        "assigned_to_user_id": None,
        "created_at": _utcnow(),
        "cleared_at": parsed["cleared_at"],
        "status": status,
        "switch_id": target_switch.switch_id if target_switch else None,
        "device_id": target_device.device_id if target_device else None,
    }

    new_alert = Model(
        **{
            k: v
            for k, v in kwargs.items()
            if v is not None
            or k in ["cleared_at", "category_id", "assigned_to_user_id"]
        }
    )
    db.add(new_alert)
    db.flush()
    await _notify_alert_change(
        "new", new_alert, lnms_alert_id, dev_name, sw_name, loc_name
    )
    return 1


async def _clear_stale_alerts(
    db: Session, active_dev_ids: Set[int], active_sw_ids: Set[int]
) -> int:
    cleared = 0
    now = _utcnow()

    for a in (
        db.query(Alert)
        .filter(
            or_(Alert.status == "active", Alert.status == "1"),
            Alert.librenms_alert_id.isnot(None),
        )
        .all()
    ):
        if a.librenms_alert_id not in active_dev_ids:
            a.status, a.cleared_at = "cleared", a.cleared_at or now
            db.add(a)
            cleared += 1

    for a in (
        db.query(SwitchAlert)
        .filter(
            or_(SwitchAlert.status == "active", SwitchAlert.status == "1"),
            SwitchAlert.librenms_alert_id.isnot(None),
        )
        .all()
    ):
        if a.librenms_alert_id not in active_sw_ids:
            a.status, a.cleared_at = "cleared", a.cleared_at or now
            db.add(a)
            cleared += 1

    if cleared > 0:
        await _maybe_notify(
            {
                "type": "alert",
                "message": f"Cleared {cleared} missing alerts",
                "severity": "info",
                "status": "cleared",
            }
        )
    return cleared


async def process_librenms_alerts(librenms_alerts: List[Dict[str, Any]]) -> int:
    processed = 0
    db = create_session()
    try:
        active_dev_ids: Set[int] = set()
        active_sw_ids: Set[int] = set()

        for raw in librenms_alerts or []:
            try:
                parsed = _parse_alert_payload(raw)
                processed += await _upsert_librenms_alert(
                    db, parsed, active_dev_ids, active_sw_ids
                )
            except Exception:
                logger.exception("Failed to process single librenms alert: %s", raw)

        processed += await _clear_stale_alerts(db, active_dev_ids, active_sw_ids)
        db.commit()
    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()

    return processed
