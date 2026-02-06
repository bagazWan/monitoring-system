from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class LibreNMSRegisterRequest(BaseModel):
    hostname: str = Field(..., description="IP or hostname to add into LibreNMS")
    community: str = Field(default="public")
    snmp_version: str = Field(default="v2c")
    port: int = Field(default=161)
    transport: str = Field(default="udp")
    force_add: bool = Field(default=False)

    node_type: Optional[str] = Field(
        default=None, description='Either "device" or "switch"'
    )

    # Optional info for DB record
    name: Optional[str] = None
    device_type: Optional[str] = None
    location_id: Optional[int] = None
    switch_id: Optional[int] = None
    node_id: Optional[int] = None
    description: Optional[str] = None


# Syncing all devices (include switch) from LibreNMS
class AllDevicesSyncConfig(BaseModel):
    default_location_id: int = Field(1, description="Default location for new devices")
    update_existing: bool = Field(True, description="Update already-synced devices")


class AllDevicesSyncReport(BaseModel):
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
    librenms_device_id: Optional[int] = None


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
    description: Optional[str]
    created_at: datetime
    updated_at: datetime
    last_replaced_at: Optional[datetime]

    class Config:
        from_attributes = True  # Allows conversion from SQLAlchemy model


class BulkLiveDetailsRequest(BaseModel):
    device_ids: List[int]


# Schema for device with location info for map display
class DeviceWithLocation(BaseModel):
    device_id: int
    name: str
    ip_address: str
    mac_address: Optional[str]
    device_type: Optional[str]
    status: str
    description: Optional[str]
    last_replaced_at: Optional[datetime]
    # Location info
    latitude: float
    longitude: float
    location_name: str
