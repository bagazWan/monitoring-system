from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# Create switch with manual input
class SwitchCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Switch name")
    ip_address: str = Field(..., description="Switch IP address")
    location_id: Optional[int] = Field(None, description="Switch location")
    node_id: Optional[int] = Field(None, description="Network node is connected to")
    status: str = Field(default="offline", description="Switch status")
    description: Optional[str] = Field(None, max_length=500)


class SwitchUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    location_id: Optional[int] = None
    ip_address: Optional[str] = None
    status: Optional[str] = None
    node_id: Optional[int] = None
    description: Optional[str] = Field(None, max_length=500)


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
