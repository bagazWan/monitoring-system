import asyncio
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Alert, Device, Switch, SwitchAlert
from app.notifications import notify_all_channels

ALERT_TYPE_BANDWIDTH = "Bandwidth Threshold"
ALERT_TYPE_UTILIZATION = "Utilization Threshold"
ALERT_TYPE_LATENCY = "Latency Threshold"

CLEAR_STREAK_REQUIRED = 2
RAISE_STREAK_REQUIRED = 2

_device_clear_streak: dict[int, int] = {}
_switch_clear_streak: dict[int, int] = {}
_device_raise_streak: dict[int, int] = {}
_switch_raise_streak: dict[int, int] = {}

_device_latency_clear_streak: dict[int, int] = {}
_device_latency_raise_streak: dict[int, int] = {}


def _now():
    return datetime.now(timezone.utc)


def _map_severity(severity: str) -> Optional[str]:
    s = (severity or "").lower()
    if s == "red":
        return "critical"
    if s == "yellow":
        return "warning"
    return None


def _latest_device_alert(
    db: Session, device_id: int, alert_type: str
) -> Optional[Alert]:
    return (
        db.query(Alert)
        .filter(Alert.device_id == device_id, Alert.alert_type == alert_type)
        .order_by(Alert.created_at.desc())
        .first()
    )


def _latest_switch_alert(db: Session, switch_id: int) -> Optional[SwitchAlert]:
    return (
        db.query(SwitchAlert)
        .filter(
            SwitchAlert.switch_id == switch_id,
            SwitchAlert.alert_type == ALERT_TYPE_UTILIZATION,
        )
        .order_by(SwitchAlert.created_at.desc())
        .first()
    )


def _schedule_notify(payload: dict) -> None:
    if not notify_all_channels:
        return
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(notify_all_channels(payload))
    except RuntimeError:
        pass


def _schedule_refresh() -> None:
    _schedule_notify({"type": "alerts_refresh"})


def _device_context(db: Session, device_id: int) -> dict:
    device = db.query(Device).filter(Device.device_id == device_id).first()
    if not device:
        return {}
    return {
        "device_name": device.name,
        "location_name": device.location.name if device.location else None,
    }


def _switch_context(db: Session, switch_id: int) -> dict:
    switch = db.query(Switch).filter(Switch.switch_id == switch_id).first()
    if not switch:
        return {}
    return {
        "switch_name": switch.name,
        "location_name": switch.location.name if switch.location else None,
    }


def _is_active(alert) -> bool:
    return alert.status in ("active", "1")


def _is_cleared(alert) -> bool:
    return alert.status in ("cleared", "0")


def sync_device_threshold_alert(
    db: Session,
    *,
    device_id: int,
    severity: str,
    message: str,
    data_found: bool,
) -> None:
    if not data_found:
        return

    mapped = _map_severity(severity)
    latest = _latest_device_alert(db, device_id, ALERT_TYPE_BANDWIDTH)

    if mapped is None:
        streak = _device_clear_streak.get(device_id, 0) + 1
        _device_clear_streak[device_id] = streak
        if streak < CLEAR_STREAK_REQUIRED:
            return

        if latest and _is_active(latest):
            latest.status = "cleared"
            if latest.cleared_at is None:
                latest.cleared_at = _now()
            db.add(latest)
            _schedule_refresh()

        _device_clear_streak[device_id] = 0
        _device_raise_streak[device_id] = 0
        return

    _device_clear_streak[device_id] = 0
    raise_streak = _device_raise_streak.get(device_id, 0) + 1
    _device_raise_streak[device_id] = raise_streak
    if raise_streak < RAISE_STREAK_REQUIRED:
        return

    if latest and _is_cleared(latest):
        latest = None

    if latest:
        if (
            latest.severity == mapped
            and latest.message == message
            and _is_active(latest)
        ):
            return

        latest.severity = mapped
        latest.message = message
        latest.status = "active"
        latest.cleared_at = None
        db.add(latest)
        _schedule_refresh()
    else:
        new_alert = Alert(
            device_id=device_id,
            librenms_alert_id=None,
            category_id=None,
            alert_type=ALERT_TYPE_BANDWIDTH,
            severity=mapped,
            message=message,
            assigned_to_user_id=None,
            created_at=_now(),
            cleared_at=None,
            status="active",
        )
        db.add(new_alert)
        db.flush()

        payload = {
            "type": "alert",
            "alert_id": new_alert.alert_id,
            "device_id": device_id,
            "alert_type": ALERT_TYPE_BANDWIDTH,
            "severity": new_alert.severity,
            "message": new_alert.message,
            "status": "active",
        }
        payload.update(_device_context(db, device_id))
        _schedule_notify(payload)


def sync_device_latency_alert(
    db: Session,
    *,
    device_id: int,
    severity: str,
    message: str,
    data_found: bool,
) -> None:
    if not data_found:
        return

    mapped = _map_severity(severity)
    latest = _latest_device_alert(db, device_id, ALERT_TYPE_LATENCY)

    if mapped is None:
        streak = _device_latency_clear_streak.get(device_id, 0) + 1
        _device_latency_clear_streak[device_id] = streak
        if streak < CLEAR_STREAK_REQUIRED:
            return

        if latest and _is_active(latest):
            latest.status = "cleared"
            if latest.cleared_at is None:
                latest.cleared_at = _now()
            db.add(latest)
            _schedule_refresh()

        _device_latency_clear_streak[device_id] = 0
        _device_latency_raise_streak[device_id] = 0
        return

    _device_latency_clear_streak[device_id] = 0
    raise_streak = _device_latency_raise_streak.get(device_id, 0) + 1
    _device_latency_raise_streak[device_id] = raise_streak
    if raise_streak < RAISE_STREAK_REQUIRED:
        return

    if latest and _is_cleared(latest):
        latest = None

    if latest:
        if (
            latest.severity == mapped
            and latest.message == message
            and _is_active(latest)
        ):
            return

        latest.severity = mapped
        latest.message = message
        latest.status = "active"
        latest.cleared_at = None
        db.add(latest)
        _schedule_refresh()
    else:
        new_alert = Alert(
            device_id=device_id,
            librenms_alert_id=None,
            category_id=None,
            alert_type=ALERT_TYPE_LATENCY,
            severity=mapped,
            message=message,
            assigned_to_user_id=None,
            created_at=_now(),
            cleared_at=None,
            status="active",
        )
        db.add(new_alert)
        db.flush()

        payload = {
            "type": "alert",
            "alert_id": new_alert.alert_id,
            "device_id": device_id,
            "alert_type": ALERT_TYPE_LATENCY,
            "severity": new_alert.severity,
            "message": new_alert.message,
            "status": "active",
        }
        payload.update(_device_context(db, device_id))
        _schedule_notify(payload)


def sync_switch_threshold_alert(
    db: Session,
    *,
    switch_id: int,
    severity: str,
    message: str,
    data_found: bool,
) -> None:
    if not data_found:
        return

    mapped = _map_severity(severity)
    latest = _latest_switch_alert(db, switch_id)

    if mapped is None:
        streak = _switch_clear_streak.get(switch_id, 0) + 1
        _switch_clear_streak[switch_id] = streak
        if streak < CLEAR_STREAK_REQUIRED:
            return

        if latest and _is_active(latest):
            latest.status = "cleared"
            if latest.cleared_at is None:
                latest.cleared_at = _now()
            db.add(latest)
            _schedule_refresh()

        _switch_clear_streak[switch_id] = 0
        _switch_raise_streak[switch_id] = 0
        return

    _switch_clear_streak[switch_id] = 0
    raise_streak = _switch_raise_streak.get(switch_id, 0) + 1
    _switch_raise_streak[switch_id] = raise_streak
    if raise_streak < RAISE_STREAK_REQUIRED:
        return

    if latest and _is_cleared(latest):
        latest = None

    if latest:
        if (
            latest.severity == mapped
            and latest.message == message
            and _is_active(latest)
        ):
            return

        latest.severity = mapped
        latest.message = message
        latest.status = "active"
        latest.cleared_at = None
        db.add(latest)
        _schedule_refresh()
    else:
        new_alert = SwitchAlert(
            switch_id=switch_id,
            librenms_alert_id=None,
            category_id=None,
            alert_type=ALERT_TYPE_UTILIZATION,
            severity=mapped,
            message=message,
            assigned_to_user_id=None,
            created_at=_now(),
            cleared_at=None,
            status="active",
        )
        db.add(new_alert)
        db.flush()

        payload = {
            "type": "alert",
            "alert_id": new_alert.alert_id,
            "switch_id": switch_id,
            "alert_type": ALERT_TYPE_UTILIZATION,
            "severity": new_alert.severity,
            "message": new_alert.message,
            "status": "active",
        }
        payload.update(_switch_context(db, switch_id))
        _schedule_notify(payload)
