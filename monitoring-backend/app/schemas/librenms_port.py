from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class LibreNMSPortResponse(BaseModel):
    id: int
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    librenms_device_id: int
    port_id: int
    if_name: str
    if_type: Optional[str] = None
    if_oper_status: Optional[str] = None
    enabled: bool
    is_uplink: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LibreNMSPortUpdate(BaseModel):
    enabled: Optional[bool] = None
    is_uplink: Optional[bool] = None
