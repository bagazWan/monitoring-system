from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class AnalyticsDataPoint(BaseModel):
    timestamp: datetime
    inbound_mbps: float
    outbound_mbps: float
    latency_ms: Optional[float] = None

    class Config:
        from_attributes = True
