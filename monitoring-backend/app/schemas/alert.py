from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AlertResponse(BaseModel):
    alert_id: int
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    librenms_alert_id: Optional[int]
    category_id: Optional[int]
    alert_type: str
    severity: str
    message: str
    status: str
    assigned_to_user_id: Optional[int] = None
    created_at: datetime
    cleared_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AlertUpdate(BaseModel):
    message: Optional[str] = Field(None, max_length=500)
    severity: Optional[str] = None
    status: Optional[str] = None
    assigned_to_user_id: Optional[int] = None
    cleared_at: Optional[datetime] = None


class AlertFilters(BaseModel):
    status: Optional[str] = None
    severity: Optional[str] = None
    alert_type: Optional[str] = None
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    category_id: Optional[int] = None
