import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Alert, Device, Switch, SwitchAlert
from app.notifications import notify_all_channels

logger = logging.getLogger(__name__)

ALERT_TYPE_BANDWIDTH = "Bandwidth Threshold"
ALERT_TYPE_UTILIZATION = "Utilization Threshold"
ALERT_TYPE_LATENCY = "Latency Threshold"
ALERT_TYPE_OFFLINE = "Offline"

CLEAR_STREAK_REQUIRED = 2
RAISE_STREAK_REQUIRED = 2

_device_clear_streak: dict[tuple[int, str], int] = {}
_switch_clear_streak: dict[tuple[int, str], int] = {}
_device_raise_streak: dict[tuple[int, str], int] = {}
_switch_raise_streak: dict[tuple[int, str], int] = {}


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


def _latest_device_alert(
    db: Session, device_id: int, alert_type: str
) -> Optional[Alert]:
    return (
        db.query(Alert)
        .filter(Alert.device_id == device_id, Alert.alert_type == alert_type)
        .order_by(Alert.created_at.desc())
        .first()
    )


def _latest_switch_alert(
    db: Session, switch_id: int, alert_type: str
) -> Optional[SwitchAlert]:
    return (
        db.query(SwitchAlert)
        .filter(
            SwitchAlert.switch_id == switch_id, SwitchAlert.alert_type == alert_type
        )
        .order_by(SwitchAlert.created_at.desc())
        .first()
    )


def _is_active(alert) -> bool:
    return alert.status in ("active", "1")


def _is_cleared(alert) -> bool:
    return alert.status in ("cleared", "0")


def _sync_device_alert(
    db: Session,
    *,
    device_id: int,
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
    k = (device_id, alert_type)
    latest = _latest_device_alert(db, device_id, alert_type)
    is_offline_type = alert_type == ALERT_TYPE_OFFLINE

    if mapped is None:
        streak = _device_clear_streak.get(k, 0) + 1
        _device_clear_streak[k] = streak
        if streak < clear_streak_required:
            return

        if latest and _is_active(latest):
            latest.status = "cleared"
            latest.cleared_at = _now()
            db.add(latest)
            db.commit()

            if is_offline_type:
                payload = {
                    "type": "alert",
                    "event": "cleared",
                    "alert_id": latest.alert_id,
                    "device_id": device_id,
                    "alert_type": alert_type,
                    "severity": "normal",
                    "message": message,
                    "status": "cleared",
                }
                payload.update(_device_context(db, device_id))
                _schedule_notify(payload)

            _schedule_refresh()

        _device_clear_streak[k] = 0
        _device_raise_streak[k] = 0
        return

    _device_clear_streak[k] = 0
    raise_streak = _device_raise_streak.get(k, 0) + 1
    _device_raise_streak[k] = raise_streak
    if raise_streak < raise_streak_required:
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
        db.commit()
        _schedule_refresh()
    else:
        new_alert = Alert(
            device_id=device_id,
            librenms_alert_id=None,
            category_id=None,
            alert_type=alert_type,
            severity=mapped,
            message=message,
            assigned_to_user_id=None,
            created_at=_now(),
            cleared_at=None,
            status="active",
        )
        db.add(new_alert)
        db.commit()
        db.refresh(new_alert)

        payload = {
            "type": "alert",
            "event": "raised",
            "alert_id": new_alert.alert_id,
            "device_id": device_id,
            "alert_type": alert_type,
            "severity": new_alert.severity,
            "message": new_alert.message,
            "status": "active",
        }
        payload.update(_device_context(db, device_id))
        _schedule_notify(payload)
        _schedule_refresh()


def _sync_switch_alert(
    db: Session,
    *,
    switch_id: int,
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
    k = (switch_id, alert_type)
    latest = _latest_switch_alert(db, switch_id, alert_type)
    is_offline_type = alert_type == ALERT_TYPE_OFFLINE

    if mapped is None:
        streak = _switch_clear_streak.get(k, 0) + 1
        _switch_clear_streak[k] = streak
        if streak < clear_streak_required:
            return

        if latest and _is_active(latest):
            latest.status = "cleared"
            latest.cleared_at = _now()
            db.add(latest)
            db.commit()

            if is_offline_type:
                payload = {
                    "type": "alert",
                    "event": "cleared",
                    "alert_id": latest.alert_id,
                    "switch_id": switch_id,
                    "alert_type": alert_type,
                    "severity": "normal",
                    "message": message,
                    "status": "cleared",
                }
                payload.update(_switch_context(db, switch_id))
                _schedule_notify(payload)

            _schedule_refresh()

        _switch_clear_streak[k] = 0
        _switch_raise_streak[k] = 0
        return

    _switch_clear_streak[k] = 0
    raise_streak = _switch_raise_streak.get(k, 0) + 1
    _switch_raise_streak[k] = raise_streak
    if raise_streak < raise_streak_required:
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
        db.commit()
        _schedule_refresh()
    else:
        new_alert = SwitchAlert(
            switch_id=switch_id,
            librenms_alert_id=None,
            category_id=None,
            alert_type=alert_type,
            severity=mapped,
            message=message,
            assigned_to_user_id=None,
            created_at=_now(),
            cleared_at=None,
            status="active",
        )
        db.add(new_alert)
        db.commit()
        db.refresh(new_alert)

        payload = {
            "type": "alert",
            "event": "raised",
            "alert_id": new_alert.alert_id,
            "switch_id": switch_id,
            "alert_type": alert_type,
            "severity": new_alert.severity,
            "message": new_alert.message,
            "status": "active",
        }
        payload.update(_switch_context(db, switch_id))
        _schedule_notify(payload)
        _schedule_refresh()


def sync_device_threshold_alert(
    db: Session, *, device_id: int, severity: str, message: str, data_found: bool
) -> None:
    _sync_device_alert(
        db,
        device_id=device_id,
        alert_type=ALERT_TYPE_BANDWIDTH,
        severity=severity,
        message=message,
        data_found=data_found,
    )


def sync_device_latency_alert(
    db: Session, *, device_id: int, severity: str, message: str, data_found: bool
) -> None:
    _sync_device_alert(
        db,
        device_id=device_id,
        alert_type=ALERT_TYPE_LATENCY,
        severity=severity,
        message=message,
        data_found=data_found,
    )


def sync_switch_threshold_alert(
    db: Session, *, switch_id: int, severity: str, message: str, data_found: bool
) -> None:
    _sync_switch_alert(
        db,
        switch_id=switch_id,
        alert_type=ALERT_TYPE_UTILIZATION,
        severity=severity,
        message=message,
        data_found=data_found,
    )


def sync_device_offline_alert(
    db: Session, *, device_id: int, is_offline: bool, data_found: bool = True
) -> None:
    if is_offline:
        _sync_device_alert(
            db,
            device_id=device_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="critical",
            message="Device is offline (3 consecutive ping failures)",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
    else:
        _sync_device_alert(
            db,
            device_id=device_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="green",
            message="Device connectivity restored",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )


def sync_switch_offline_alert(
    db: Session, *, switch_id: int, is_offline: bool, data_found: bool = True
) -> None:
    if is_offline:
        _sync_switch_alert(
            db,
            switch_id=switch_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="critical",
            message="Switch is offline (3 consecutive ping failures)",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
    else:
        _sync_switch_alert(
            db,
            switch_id=switch_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="green",
            message="Switch connectivity restored",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
