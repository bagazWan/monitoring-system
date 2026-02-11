from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from app.models import Device, Switch
from app.services.librenms_ports_service import discover_and_store_ports_for
from app.services.librenms_service import LibreNMSService


class SyncService:
    def __init__(self, db: Session):
        self.db = db
        self.librenms = LibreNMSService()
        self.default_location_id = 1

    async def sync_all_from_librenms(
        self, update_existing: bool = False
    ) -> Dict[str, Any]:
        """
        Fetches ALL devices from LibreNMS and syncs them to local DB.
        """
        all_devices = await self.librenms.get_devices()

        stats = {
            "total_scanned": len(all_devices),
            "created_switches": 0,
            "created_devices": 0,
            "updated_devices": 0,
            "errors": [],
        }

        logs = []

        for lnms_dev in all_devices:
            try:
                is_switch = (
                    lnms_dev.get("os") == "ios"
                    or "switch" in (lnms_dev.get("sysDescr") or "").lower()
                    or "switch" in (lnms_dev.get("sysName") or "").lower()
                )

                if is_switch:
                    msg = await self._process_switch(lnms_dev)
                    if "Created" in msg:
                        stats["created_switches"] += 1
                    logs.append(msg)
                else:
                    msg = await self._process_device(lnms_dev, update_existing)
                    if "Created" in msg:
                        stats["created_devices"] += 1
                    if "Updated" in msg:
                        stats["updated_devices"] += 1
                    logs.append(msg)

            except Exception as e:
                error_msg = f"Error processing {lnms_dev.get('hostname')}: {str(e)}"
                print(error_msg)
                stats["errors"].append(error_msg)

        return {"stats": stats, "logs": logs}

    async def _process_switch(self, lnms_dev: dict) -> str:
        librenms_id = int(lnms_dev.get("device_id"))
        existing_switch = self._find_existing_switch(
            librenms_id, lnms_dev.get("ip"), lnms_dev.get("hostname")
        )

        if existing_switch:
            return f"Skipped Switch: {existing_switch.name} (Already exists)"

        new_switch = Switch(
            name=self._pick_display_name(lnms_dev),
            ip_address=lnms_dev.get("ip"),
            location_id=self.default_location_id,
            librenms_device_id=librenms_id,
            librenms_hostname=lnms_dev.get("hostname"),
            status="online" if lnms_dev.get("status") == 1 else "offline",
            librenms_last_synced=datetime.now(),
        )
        self.db.add(new_switch)
        self.db.commit()
        self.db.refresh(new_switch)

        await discover_and_store_ports_for(
            db=self.db,
            librenms=self.librenms,
            librenms_device_id=librenms_id,
            switch=new_switch,
        )
        self.db.commit()

        return f"Created Switch: {new_switch.name}"

    async def _process_device(self, lnms_dev: dict, update_existing: bool) -> str:
        librenms_id = int(lnms_dev.get("device_id"))
        ip = lnms_dev.get("ip")
        detected_type = self._determine_device_type(lnms_dev)
        status_str = "online" if lnms_dev.get("status") == 1 else "offline"

        existing_device = self._find_existing_device(
            librenms_id, ip, lnms_dev.get("hostname")
        )

        if not existing_device:
            new_device = Device(
                name=self._pick_display_name(lnms_dev),
                ip_address=ip,
                location_id=self.default_location_id,
                librenms_device_id=librenms_id,
                librenms_hostname=lnms_dev.get("hostname"),
                status=status_str,
                device_type=detected_type,
                created_at=datetime.now(),
                updated_at=datetime.now(),
            )
            self.db.add(new_device)
            self.db.commit()
            self.db.refresh(new_device)

            await discover_and_store_ports_for(
                db=self.db,
                librenms=self.librenms,
                librenms_device_id=librenms_id,
                device=new_device,
            )
            self.db.commit()

            return f"Created Device: {new_device.name} ({detected_type})"

        elif update_existing:
            updates_made = []

            existing_device.librenms_device_id = librenms_id

            if existing_device.device_type != detected_type:
                existing_device.device_type = detected_type
                updates_made.append("type")

            if existing_device.ip_address != ip:
                new_ip = self._safe_set_device_ip(existing_device, ip)
                if new_ip:
                    existing_device.ip_address = new_ip
                    updates_made.append("ip")

            if existing_device.status != status_str:
                existing_device.status = status_str
                updates_made.append("status")

            existing_device.librenms_last_synced = datetime.now()

            await discover_and_store_ports_for(
                db=self.db,
                librenms=self.librenms,
                librenms_device_id=librenms_id,
                device=existing_device,
            )

            self.db.commit()

            if updates_made:
                return f"Updated Device: {existing_device.name} ({', '.join(updates_made)})"
            return f"Checked Device: {existing_device.name} (No changes)"

        return f"Skipped Device: {existing_device.name} (Exists)"

    def _find_existing_device(
        self, librenms_id: int, ip: str, hostname: str
    ) -> Optional[Device]:
        """Matches by ID, then IP, then Hostname to avoid duplicates."""
        existing = (
            self.db.query(Device)
            .filter(Device.librenms_device_id == librenms_id)
            .first()
        )
        if existing:
            return existing

        if ip:
            existing = self.db.query(Device).filter(Device.ip_address == ip).first()
            if existing:
                return existing

        if hostname:
            existing = (
                self.db.query(Device)
                .filter(Device.librenms_hostname == hostname)
                .first()
            )
            if existing:
                return existing

        return None

    def _find_existing_switch(
        self, librenms_id: int, ip: str, hostname: str
    ) -> Optional[Switch]:
        existing = (
            self.db.query(Switch)
            .filter(Switch.librenms_device_id == librenms_id)
            .first()
        )
        if existing:
            return existing

        if ip:
            existing = self.db.query(Switch).filter(Switch.ip_address == ip).first()
            if existing:
                return existing

        if hostname:
            existing = (
                self.db.query(Switch)
                .filter(Switch.librenms_hostname == hostname)
                .first()
            )
            if existing:
                return existing

        return None

    def _safe_set_device_ip(
        self, device: Device, new_ip: Optional[str]
    ) -> Optional[str]:
        if not new_ip or device.ip_address == new_ip:
            return None

        conflict = (
            self.db.query(Device)
            .filter(Device.ip_address == new_ip, Device.device_id != device.device_id)
            .first()
        )

        if conflict:
            print(
                f"Skipping IP update for {device.name}: {new_ip} is taken by {conflict.name}"
            )
            return None

        return new_ip

    def _determine_device_type(self, lnms_device: dict) -> str:
        if lnms_device.get("hardware"):
            return lnms_device["hardware"]

        sys_descr = (lnms_device.get("sysDescr") or "").lower()
        sys_name = (lnms_device.get("sysName") or "").lower()

        if "cctv" in sys_descr or "camera" in sys_descr or "cctv" in sys_name:
            return "CCTV"
        if "access point" in sys_descr or "ap" in sys_name:
            return "Access Point"
        if "switch" in sys_descr or "router" in sys_descr:
            return "Switch"
        if "server" in sys_descr or "linux" in sys_descr or "windows" in sys_descr:
            return "Server"
        return "Unknown"

    def _pick_display_name(self, lnms_device: dict) -> str:
        return (
            lnms_device.get("sysName")
            or lnms_device.get("hostname")
            or lnms_device.get("ip")
            or "Unknown"
        ).strip()
