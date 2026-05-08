from sqlalchemy.orm import Session

from app.models.setting import SystemConfig

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
    config = db.query(SystemConfig).first()
    if is_offline:
        fail_count = config.offline_fail_required if config else " "
        sync_node_alert(
            db,
            node_type="switch",
            node_id=switch_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="critical",
            message=f"Switch offline ({fail_count} ping gagal)",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
    else:
        success_count = config.recovery_success_required if config else " "
        sync_node_alert(
            db,
            node_type="switch",
            node_id=switch_id,
            alert_type=ALERT_TYPE_OFFLINE,
            severity="green",
            message=f"Koneksi switch pulih ({success_count} ping sukses)",
            data_found=data_found,
            clear_streak_required=1,
            raise_streak_required=1,
        )
