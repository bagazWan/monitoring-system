import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional

from app.models import Alert, Device, Switch, SwitchAlert
from app.notifications import notify_all_channels
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

CLEAR_STREAK_REQUIRED = 2
RAISE_STREAK_REQUIRED = 2

# Unified streak tracking: Key = (node_type, node_id, alert_type)
_clear_streaks: dict[tuple[str, int, str], int] = {}
_raise_streaks: dict[tuple[str, int, str], int] = {}


def _now():
    return datetime.now(timezone.utc)


def _map_severity(severity: str) -> Optional[str]:
    s = (severity or "").lower()
    if s in ("red", "critical"):
        return "critical"
    if s in ("yellow", "warning"):
        return "warning"
    return None


def _schedule_notify(payload: dict) -> None:
    if not notify_all_channels:
        return
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(notify_all_channels(payload))
    except RuntimeError:
        pass


def _get_latest_alert(db: Session, node_type: str, node_id: int, alert_type: str):
    Model = SwitchAlert if node_type == "switch" else Alert
    id_col = Model.switch_id if node_type == "switch" else Model.device_id
    return (
        db.query(Model)
        .filter(id_col == node_id, Model.alert_type == alert_type)
        .order_by(Model.created_at.desc())
        .first()
    )


def _get_node_context(db: Session, node_type: str, node_id: int) -> dict:
    Model = Switch if node_type == "switch" else Device
    id_col = Model.switch_id if node_type == "switch" else Model.device_id
    node = db.query(Model).filter(id_col == node_id).first()
    if not node:
        return {}
    return {
        f"{node_type}_name": node.name,
        "location_name": node.location.name if node.location else None,
    }


def sync_node_alert(
    db: Session,
    *,
    node_type: str,  # 'device' or 'switch'
    node_id: int,
    alert_type: str,
    severity: str,
    message: str,
    data_found: bool,
    clear_streak_required: int = CLEAR_STREAK_REQUIRED,
    raise_streak_required: int = RAISE_STREAK_REQUIRED,
) -> None:
    if not data_found:
        return

    mapped = _map_severity(severity)
    k = (node_type, node_id, alert_type)
    latest = _get_latest_alert(db, node_type, node_id, alert_type)
    is_offline_type = alert_type == "Offline"

    if mapped is None:
        streak = _clear_streaks.get(k, 0) + 1
        _clear_streaks[k] = streak
        if streak < clear_streak_required:
            return

        if latest and latest.status in ("active", "1"):
            latest.status = "cleared"
            latest.cleared_at = _now()
            db.commit()

            if is_offline_type:
                payload = {
                    "type": "alert",
                    "event": "cleared",
                    "alert_id": latest.alert_id,
                    f"{node_type}_id": node_id,
                    "alert_type": alert_type,
                    "severity": "normal",
                    "message": message,
                    "status": "cleared",
                }
                payload.update(_get_node_context(db, node_type, node_id))
                _schedule_notify(payload)
            _schedule_notify({"type": "alerts_refresh"})

        _clear_streaks[k] = 0
        _raise_streaks[k] = 0
        return

    _clear_streaks[k] = 0
    raise_streak = _raise_streaks.get(k, 0) + 1
    _raise_streaks[k] = raise_streak
    if raise_streak < raise_streak_required:
        return

    if latest and latest.status in ("cleared", "0"):
        latest = None

    if latest:
        if (
            latest.severity == mapped
            and latest.message == message
            and latest.status in ("active", "1")
        ):
            return
        latest.severity = mapped
        latest.message = message
        latest.status = "active"
        latest.cleared_at = None
        db.commit()
        _schedule_notify({"type": "alerts_refresh"})
    else:
        Model = SwitchAlert if node_type == "switch" else Alert
        kwargs = {
            f"{node_type}_id": node_id,
            "librenms_alert_id": None,
            "category_id": None,
            "alert_type": alert_type,
            "severity": mapped,
            "message": message,
            "created_at": _now(),
            "status": "active",
        }
        new_alert = Model(**kwargs)
        db.add(new_alert)
        db.commit()
        db.refresh(new_alert)

        payload = {
            "type": "alert",
            "event": "raised",
            "alert_id": new_alert.alert_id,
            f"{node_type}_id": node_id,
            "alert_type": alert_type,
            "severity": new_alert.severity,
            "message": new_alert.message,
            "status": "active",
        }
        payload.update(_get_node_context(db, node_type, node_id))
        _schedule_notify(payload)
        _schedule_notify({"type": "alerts_refresh"})
