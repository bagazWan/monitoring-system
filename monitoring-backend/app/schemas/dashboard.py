from typing import List, Optional

from pydantic import BaseModel


class LocationDownSummary(BaseModel):
    location_id: int
    location_name: str
    offline_count: int


class DashboardStats(BaseModel):
    total_all_devices: int
    all_online_devices: int
    active_alerts: int
    total_bandwidth: Optional[float]
    uptime_percentage: float
    top_down_locations: List[LocationDownSummary]
