from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SwitchCreate(BaseModel):
    name: str = Field(..., title="Name", description="Switch name")
    ip_address: str = Field(..., title="IP Address", description="Switch IP address")
    location_id: int = Field(..., title="Location ID", description="Switch location")
    node_id: Optional[int] = Field(
        None, title="Node ID", description="Network node is connected to"
    )
    status: str = Field(default="offline", description="Switch status")


class SwitchUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    ip_address: Optional[str] = None
    status: Optional[str] = None


class SwitchResponse(BaseModel):
    switch_id: int
    name: str
    ip_address: str
    location_id: int
    node_id: Optional[int]
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SwitchWithLocation(BaseModel):
    switch_id: int
    name: str
    status: str
    # Location info
    latitude: float
    longitude: float
    location_name: str
