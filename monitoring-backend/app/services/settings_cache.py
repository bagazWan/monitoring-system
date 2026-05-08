import threading

from sqlalchemy.orm import Session

from app.models.setting import SystemConfig, ThresholdRule


class SettingsCache:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super(SettingsCache, cls).__new__(cls)
                    cls._instance._system_config = None
                    cls._instance._device_rules = {}
        return cls._instance

    def refresh_cache(self, db: Session):
        with self._lock:
            self._system_config = db.query(SystemConfig).first()

            rules = db.query(ThresholdRule).all()

            new_rules_dict = {}
            for rule in rules:
                dt = rule.device_type.lower()
                if dt not in new_rules_dict:
                    new_rules_dict[dt] = []
                new_rules_dict[dt].append(rule)

            self._device_rules = new_rules_dict
            print(
                f"[Cache] Settings refreshed. Loaded rules for: {list(self._device_rules.keys())}"
            )

    def get_system_config(self):
        return self._system_config

    def get_rules_for_device(self, device_type: str) -> list:
        return self._device_rules.get(device_type.lower(), [])

    def get_all_rules(self) -> dict:
        return self._device_rules


settings_cache = SettingsCache()
