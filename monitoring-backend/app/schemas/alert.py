from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class AlertResponse(BaseModel):
    alert_id: int
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    device_name: Optional[str] = None
    location_name: Optional[str] = None
    librenms_alert_id: Optional[int]
    category_id: Optional[int]
    alert_type: str
    severity: str
    message: str
    status: str
    assigned_to_user_id: Optional[int] = None
    resolved_by_full_name: Optional[str] = None
    acknowledged_at: Optional[datetime] = None
    resolution_note: Optional[str] = None
    created_at: datetime
    cleared_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AlertUpdate(BaseModel):
    resolution_note: Optional[str] = Field(None, max_length=2000)
    assigned_to_user_id: Optional[int] = None


class AlertFilters(BaseModel):
    status: Optional[str] = None
    severity: Optional[str] = None
    alert_type: Optional[str] = None
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    category_id: Optional[int] = None


class AlertPageResponse(BaseModel):
    items: List[AlertResponse]
    total: int
    page: int
    page_size: int


class AlertBulkDeleteResponse(BaseModel):
    deleted: int
