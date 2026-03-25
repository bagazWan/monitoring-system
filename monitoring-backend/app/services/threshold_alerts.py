from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models import Alert, SwitchAlert

ALERT_TYPE_BANDWIDTH = "Bandwidth Threshold"
ALERT_TYPE_UTILIZATION = "Utilization Threshold"

CLEAR_STREAK_REQUIRED = 2
RAISE_STREAK_REQUIRED = 2

_device_clear_streak: dict[int, int] = {}
_switch_clear_streak: dict[int, int] = {}
_device_raise_streak: dict[int, int] = {}
_switch_raise_streak: dict[int, int] = {}


def _now():
    return datetime.now(timezone.utc)


def _map_severity(severity: str) -> Optional[str]:
    s = (severity or "").lower()
    if s == "red":
        return "critical"
    if s == "yellow":
        return "warning"
    return None


def _latest_device_alert(db: Session, device_id: int) -> Optional[Alert]:
    return (
        db.query(Alert)
        .filter(Alert.device_id == device_id, Alert.alert_type == ALERT_TYPE_BANDWIDTH)
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
    latest = _latest_device_alert(db, device_id)

    if mapped is None:
        streak = _device_clear_streak.get(device_id, 0) + 1
        _device_clear_streak[device_id] = streak
        if streak < CLEAR_STREAK_REQUIRED:
            return

        if latest and latest.status in ("active", "1"):
            latest.status = "cleared"
            if latest.cleared_at is None:
                latest.cleared_at = _now()
            db.add(latest)
        _device_clear_streak[device_id] = 0
        _device_raise_streak[device_id] = 0
        return

    _device_clear_streak[device_id] = 0
    raise_streak = _device_raise_streak.get(device_id, 0) + 1
    _device_raise_streak[device_id] = raise_streak
    if raise_streak < RAISE_STREAK_REQUIRED:
        return

    if latest:
        latest.severity = mapped
        latest.message = message
        latest.status = "active"
        latest.cleared_at = None
        db.add(latest)
    else:
        db.add(
            Alert(
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
        )


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

        if latest and latest.status in ("active", "1"):
            latest.status = "cleared"
            if latest.cleared_at is None:
                latest.cleared_at = _now()
            db.add(latest)
        _switch_clear_streak[switch_id] = 0
        _switch_raise_streak[switch_id] = 0
        return

    _switch_clear_streak[switch_id] = 0
    raise_streak = _switch_raise_streak.get(switch_id, 0) + 1
    _switch_raise_streak[switch_id] = raise_streak
    if raise_streak < RAISE_STREAK_REQUIRED:
        return

    if latest:
        latest.severity = mapped
        latest.message = message
        latest.status = "active"
        latest.cleared_at = None
        db.add(latest)
    else:
        db.add(
            SwitchAlert(
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
        )
