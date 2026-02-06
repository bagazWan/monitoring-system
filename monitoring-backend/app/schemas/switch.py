from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class SwitchUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    location_id: Optional[int] = None
    ip_address: Optional[str] = None
    status: Optional[str] = None
    node_id: Optional[int] = None
    description: Optional[str] = Field(None, max_length=500)
    librenms_device_id: Optional[int] = None


class SwitchResponse(BaseModel):
    switch_id: int
    name: str
    ip_address: str
    location_id: Optional[int]
    node_id: Optional[int]
    status: str
    librenms_device_id: Optional[int]
    librenms_hostname: Optional[str]
    librenms_last_synced: Optional[datetime]
    description: Optional[str]
    created_at: datetime
    updated_at: datetime
    last_replaced_at: Optional[datetime]

    class Config:
        from_attributes = True


class BulkSwitchDetailsRequest(BaseModel):
    switch_ids: List[int]


class SwitchWithLocation(BaseModel):
    switch_id: int
    name: str
    ip_address: str
    status: str
    description: Optional[str]
    last_replaced_at: Optional[datetime]
    # Location info
    latitude: float
    longitude: float
    location_name: str
