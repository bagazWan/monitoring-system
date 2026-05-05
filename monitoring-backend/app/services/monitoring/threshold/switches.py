from sqlalchemy.orm import Session

from .core import sync_node_alert

ALERT_TYPE_UTILIZATION = "Utilization Threshold"
ALERT_TYPE_OFFLINE = "Offline"


def sync_switch_threshold_alert(
    db: Session, *, switch_id: int, severity: str, message: str, data_found: bool
) -> None:
    sync_node_alert(
        db,
        node_type="switch",
        node_id=switch_id,
        alert_type=ALERT_TYPE_UTILIZATION,
        severity=severity,
        message=message,
        data_found=data_found,
    )


def sync_switch_offline_alert(
    db: Session, *, switch_id: int, is_offline: bool, data_found: bool = True
) -> None:
    if is_offline:
        sync_node_alert(
            db,
            node_type="switch",
            node_id=switch_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="critical",
            message="Switch is offline (3 consecutive ping failures)",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
    else:
        sync_node_alert(
            db,
            node_type="switch",
            node_id=switch_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="green",
            message="Switch connectivity restored",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
