from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AlertResponse(BaseModel):
    alert_id: int
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    category_id: Optional[int]
    alert_type: str
    severity: str
    message: str
    status: str
    assigned_to_user_id: Optional[int]
    created_at: datetime
    cleared_at: Optional[datetime]

    class Config:
        from_attributes = True


class AlertUpdate(BaseModel):
    message: Optional[str] = Field(None)
    severity: Optional[str] = Field(None)
    status: Optional[str] = Field(None)
    assigned_to_user_id: Optional[int] = Field(None)
    cleared_at: Optional[datetime] = Field(None)


class AlertFilters(BaseModel):
    status: Optional[str] = None
    severity: Optional[str] = None
    alert_type: Optional[str] = None
    device_id: Optional[int] = None
    switch_id: Optional[int] = None
    category_id: Optional[int] = None
