from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# Creating new device with manual input
class DeviceCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Device name")
    ip_address: str = Field(..., description="Device IP address")
    mac_address: Optional[str] = Field(None, description="Device MAC address")
    device_type: str = Field(..., description="Device type (CCTV, Router, etc.)")
    location_id: Optional[int] = Field(
        None, description="Location where device is installed"
    )
    switch_id: Optional[int] = Field(None, description="Switch device is connected to")
    status: str = Field(default="offline", description="Device status")


# Creating a new device from LibreNMS data
class DeviceCreateWithLibreNMS(BaseModel):
    name: str
    ip_address: str
    mac_address: Optional[str]
    device_type: Optional[str]
    location_id: Optional[int]
    librenms_device_id: int
    librenms_hostname: str


# Syncing devices from LibreNMS
class DeviceSyncConfig(BaseModel):
    default_location_id: int = Field(1, description="Default location for new devices")
    update_existing: bool = Field(True, description="Update already-synced devices")


class DeviceSyncReport(BaseModel):
    """Sync result report"""

    created: list[dict]
    updated: list[dict]
    errors: list[dict]
    summary: dict


class DeviceUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    location_id: Optional[int] = Field(None, gt=0)
    device_type: Optional[str] = None
    ip_address: Optional[str] = None
    mac_address: Optional[str] = None
    status: Optional[str] = None
    switch_id: Optional[int] = None
    description: Optional[str] = Field(None, max_length=500)


class DeviceResponse(BaseModel):
    device_id: int
    name: str
    ip_address: str
    mac_address: Optional[str]
    device_type: Optional[str]
    location_id: Optional[int]
    switch_id: Optional[int]
    status: str
    librenms_device_id: Optional[int]
    librenms_hostname: Optional[str]
    librenms_last_synced: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    last_replaced_at: Optional[datetime]

    class Config:
        from_attributes = True  # Allows conversion from SQLAlchemy model


# Schema for device with location info for map display
class DeviceWithLocation(BaseModel):
    device_id: int
    name: str
    device_type: Optional[str]
    status: str
    # Location info
    latitude: float
    longitude: float
    location_name: str
