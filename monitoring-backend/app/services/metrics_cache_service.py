import logging
from datetime import datetime
from typing import Dict, Optional

logger = logging.getLogger(__name__)


class MetricsCacheService:
    _device_cache: Dict[int, Dict] = {}
    _switch_cache: Dict[int, Dict] = {}

    @classmethod
    def update_device(cls, device_id: int, metrics: Dict):
        cls._device_cache[device_id] = {**metrics, "updated_at": datetime.now()}

    @classmethod
    def update_switch(cls, switch_id: int, metrics: Dict):
        cls._switch_cache[switch_id] = {**metrics, "updated_at": datetime.now()}

    @classmethod
    def get_device(cls, device_id: int) -> Optional[Dict]:
        return cls._device_cache.get(device_id)

    @classmethod
    def get_switch(cls, switch_id: int) -> Optional[Dict]:
        return cls._switch_cache.get(switch_id)
