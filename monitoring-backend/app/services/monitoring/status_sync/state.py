import asyncio
from typing import Dict, Optional

OFFLINE_FAIL_REQUIRED = 3
RECOVERY_SUCCESS_REQUIRED = 2

# Global Tasks
status_poller_task: Optional[asyncio.Task] = None
librenms_sync_task: Optional[asyncio.Task] = None
status_poller_stop_event: Optional[asyncio.Event] = None

# Status & Ping Counters
device_status_cache: Dict[int, str] = {}
switch_status_cache: Dict[int, str] = {}
device_failure_count: Dict[int, int] = {}
switch_failure_count: Dict[int, int] = {}
device_success_count: Dict[int, int] = {}
switch_success_count: Dict[int, int] = {}

# LibreNMS Cache
cached_device_totals: Dict[int, tuple] = {}
cached_switch_totals: Dict[int, tuple] = {}
cached_switch_capacity: Dict[int, float] = {}
cached_librenms_status_map: Dict[int, dict] = {}
