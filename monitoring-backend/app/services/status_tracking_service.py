from datetime import datetime, timezone
from typing import Dict

from sqlalchemy.orm import Session

from app.models import Device, StatusHistory, Switch
from app.services.librenms_service import LibreNMSService


def _to_status(value) -> str:
    if value == 1 or str(value) == "1":
        return "online"
    if value == 0 or str(value) == "0":
        return "offline"
    return "unknown"


class StatusTrackingService:
    def __init__(self, db: Session):
        self.db = db
        self.librenms = LibreNMSService()

    async def poll_and_track_all(self) -> Dict:
        now = datetime.now(timezone.utc)

        lnms_devices = await self.librenms.get_devices()
        lnms_by_id = {}
        for d in lnms_devices:
            did = d.get("device_id")
            if did is not None:
                lnms_by_id[int(did)] = d

        summary = {
            "devices_processed": 0,
            "switches_processed": 0,
            "history_inserted": 0,
            "status_changed": 0,
        }

        # Devices
        devices = self.db.query(Device).all()
        for dev in devices:
            if not dev.librenms_device_id:
                continue

            lnms = lnms_by_id.get(int(dev.librenms_device_id))
            new_status = "offline" if lnms is None else _to_status(lnms.get("status"))

            inserted, changed = self._track_node(
                node_type="device",
                node_id=dev.device_id,
                new_status=new_status,
                now=now,
                current_status=dev.status,
            )

            dev.status = new_status
            dev.librenms_last_synced = now

            summary["devices_processed"] += 1
            summary["history_inserted"] += 1 if inserted else 0
            summary["status_changed"] += 1 if changed else 0

        # Switches
        switches = self.db.query(Switch).all()
        for sw in switches:
            if not sw.librenms_device_id:
                continue

            lnms = lnms_by_id.get(int(sw.librenms_device_id))
            new_status = "offline" if lnms is None else _to_status(lnms.get("status"))

            inserted, changed = self._track_node(
                node_type="switch",
                node_id=sw.switch_id,
                new_status=new_status,
                now=now,
                current_status=sw.status,
            )

            sw.status = new_status
            sw.librenms_last_synced = now

            summary["switches_processed"] += 1
            summary["history_inserted"] += 1 if inserted else 0
            summary["status_changed"] += 1 if changed else 0

        self.db.commit()
        return summary

    def _track_node(
        self,
        *,
        node_type: str,
        node_id: int,
        new_status: str,
        now: datetime,
        current_status: str | None,
    ) -> tuple[bool, bool]:
        last = (
            self.db.query(StatusHistory)
            .filter(
                StatusHistory.node_type == node_type,
                StatusHistory.node_id == node_id,
            )
            .order_by(StatusHistory.changed_at.desc())
            .first()
        )

        # First snapshot
        if last is None:
            self.db.add(
                StatusHistory(
                    node_type=node_type,
                    node_id=node_id,
                    status=new_status,
                    changed_at=now,
                )
            )
            return True, False

        # No transition
        if last.status == new_status:
            return False, False

        # Transition
        self.db.add(
            StatusHistory(
                node_type=node_type,
                node_id=node_id,
                status=new_status,
                changed_at=now,
            )
        )
        return True, True
