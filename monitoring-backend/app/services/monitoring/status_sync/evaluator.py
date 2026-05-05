from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Device, StatusHistory, Switch
from app.services.metrics.cache import MetricsCacheService
from app.services.monitoring.threshold import (
    sync_device_latency_alert,
    sync_device_offline_alert,
    sync_device_threshold_alert,
    sync_switch_offline_alert,
    sync_switch_threshold_alert,
)
from app.services.monitoring.websocket_manager import ws_manager
from app.utils.thresholds import (
    DEVICE_THRESHOLDS,
    evaluate_device_latency_severity,
    evaluate_device_severity,
    evaluate_switch_severity,
)

from . import state


def append_status_history_if_changed(
    db: Session,
    *,
    node_type: str,
    node_id: int,
    old_status: Optional[str],
    new_status: str,
) -> None:
    if old_status is None or old_status == new_status:
        return
    db.add(
        StatusHistory(
            node_type=node_type,
            node_id=node_id,
            status=new_status,
            changed_at=datetime.now(),
        )
    )


async def evaluate_node_state(db: Session, node, node_type: str) -> tuple[str, bool]:
    """Evaluates node health. Returns (new_status, changed_bool)"""
    node_id = getattr(node, f"{node_type}_id")

    cache_dict = (
        state.switch_status_cache
        if node_type == "switch"
        else state.device_status_cache
    )
    fail_dict = (
        state.switch_failure_count
        if node_type == "switch"
        else state.device_failure_count
    )
    succ_dict = (
        state.switch_success_count
        if node_type == "switch"
        else state.device_success_count
    )

    old_status = cache_dict.get(node_id)
    lnms_id = node.librenms_device_id

    raw_status = "offline"
    if lnms_id and lnms_id in state.cached_librenms_status_map:
        raw_status = state.cached_librenms_status_map[lnms_id]["status"]

    if raw_status == "offline":
        succ_dict[node_id] = 0
        fail_dict[node_id] = fail_dict.get(node_id, 0) + 1
        new_status = (
            "offline"
            if fail_dict[node_id] >= state.OFFLINE_FAIL_REQUIRED
            else "warning"
        )
    else:
        fail_dict[node_id] = 0
        succ_dict[node_id] = succ_dict.get(node_id, 0) + 1
        new_status = (
            "online"
            if succ_dict[node_id] >= state.RECOVERY_SUCCESS_REQUIRED
            else old_status or "online"
        )

    changed = old_status != new_status
    if changed:
        cache_dict[node_id] = new_status
        node.status = new_status
        node.librenms_last_synced = datetime.now()
        db.add(node)

        append_status_history_if_changed(
            db,
            node_type=node_type,
            node_id=node_id,
            old_status=old_status,
            new_status=new_status,
        )

        is_offline = new_status == "offline"
        if new_status == "offline" or (
            old_status == "offline" and new_status == "online"
        ):
            if node_type == "device":
                sync_device_offline_alert(
                    db, device_id=node_id, is_offline=is_offline, data_found=True
                )
            else:
                sync_switch_offline_alert(
                    db, switch_id=node_id, is_offline=is_offline, data_found=True
                )

        await ws_manager.broadcast(
            {
                "type": "status_change",
                "node_type": node_type,
                "id": node_id,
                "name": node.name,
                "ip_address": node.ip_address,
                "old_status": old_status,
                "new_status": new_status,
                "timestamp": datetime.now().isoformat(),
            }
        )

    return new_status, changed


def sync_threshold_alerts_logic(
    db: Session, devices: list[Device], switches: list[Switch]
):
    latency_by_lnms_id = {
        k: v["latency_ms"] for k, v in state.cached_librenms_status_map.items()
    }

    for device in devices:
        status = (device.status or "").lower()
        if status != "online":
            sync_device_threshold_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="Device not online",
                data_found=True,
            )
            sync_device_latency_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="Device not online",
                data_found=True,
            )
            continue

        if device.device_id not in state.cached_device_totals:
            sync_device_threshold_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="No valid rate data",
                data_found=False,
            )
        else:
            in_mbps, out_mbps = state.cached_device_totals[device.device_id]
            severity = evaluate_device_severity(device.device_type, in_mbps, out_mbps)
            sync_device_threshold_alert(
                db,
                device_id=device.device_id,
                severity=severity,
                message=f"Throughput: {in_mbps:.2f} Mbps in / {out_mbps:.2f} Mbps out",
                data_found=True,
            )

        device_type_key = (device.device_type or "").strip().lower().replace("_", " ")
        if (
            device_type_key in DEVICE_THRESHOLDS
            and "latency" in DEVICE_THRESHOLDS[device_type_key]
        ):
            lnms_id = device.librenms_device_id
            latency_ms = latency_by_lnms_id.get(int(lnms_id)) if lnms_id else None
            cached_dev = MetricsCacheService.get_device(device.device_id)
            if cached_dev and cached_dev.get("latency_ms") is not None:
                latency_ms = cached_dev["latency_ms"]

            latency_sev = evaluate_device_latency_severity(
                device.device_type, latency_ms
            )
            sync_device_latency_alert(
                db,
                device_id=device.device_id,
                severity=latency_sev,
                message=f"Latency: {latency_ms:.2f} ms"
                if latency_ms is not None
                else "Latency unavailable",
                data_found=latency_ms is not None,
            )
        else:
            sync_device_latency_alert(
                db,
                device_id=device.device_id,
                severity="green",
                message="Latency rule not configured",
                data_found=True,
            )

    for switch in switches:
        status = (switch.status or "").lower()
        if status != "online":
            sync_switch_threshold_alert(
                db,
                switch_id=switch.switch_id,
                severity="green",
                message="Switch not online",
                data_found=True,
            )
            continue

        if switch.switch_id not in state.cached_switch_totals:
            sync_switch_threshold_alert(
                db,
                switch_id=switch.switch_id,
                severity="green",
                message="No valid rate data",
                data_found=False,
            )
            continue

        in_mbps, out_mbps = state.cached_switch_totals[switch.switch_id]
        capacity = state.cached_switch_capacity.get(switch.switch_id, 0.0)
        utilization = ((in_mbps + out_mbps) / capacity) * 100 if capacity > 0 else None
        severity = evaluate_switch_severity(utilization, "switch")
        sync_switch_threshold_alert(
            db,
            switch_id=switch.switch_id,
            severity=severity,
            message=f"Utilization: {utilization:.2f}%"
            if utilization is not None
            else "Utilization unavailable",
            data_found=True,
        )
