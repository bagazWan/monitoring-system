from sqlalchemy.orm import Session

from .core import sync_node_alert

ALERT_TYPE_BANDWIDTH = "Bandwidth Threshold"
ALERT_TYPE_LATENCY = "Latency Threshold"
ALERT_TYPE_OFFLINE = "Offline"


def sync_device_threshold_alert(
    db: Session, *, device_id: int, severity: str, message: str, data_found: bool
) -> None:
    sync_node_alert(
        db,
        node_type="device",
        node_id=device_id,
        alert_type=ALERT_TYPE_BANDWIDTH,
        severity=severity,
        message=message,
        data_found=data_found,
    )


def sync_device_latency_alert(
    db: Session, *, device_id: int, severity: str, message: str, data_found: bool
) -> None:
    sync_node_alert(
        db,
        node_type="device",
        node_id=device_id,
        alert_type=ALERT_TYPE_LATENCY,
        severity=severity,
        message=message,
        data_found=data_found,
    )


def sync_device_offline_alert(
    db: Session, *, device_id: int, is_offline: bool, data_found: bool = True
) -> None:
    if is_offline:
        sync_node_alert(
            db,
            node_type="device",
            node_id=device_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="critical",
            message="Device is offline (3 consecutive ping failures)",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
    else:
        sync_node_alert(
            db,
            node_type="device",
            node_id=device_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="green",
            message="Device connectivity restored",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
