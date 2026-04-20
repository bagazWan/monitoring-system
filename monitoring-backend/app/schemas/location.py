from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class LocationGroupBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None


class LocationGroupCreate(LocationGroupBase):
    pass


class LocationGroupUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None


class LocationGroupResponse(LocationGroupBase):
    group_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LocationCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Location name")
    address: str = Field(..., description="Location address")
    location_type: str = Field(..., description="Location type")
    latitude: float = Field(..., description="Location latitude")
    longitude: float = Field(..., description="Location longitude")
    description: Optional[str] = None
    group_id: Optional[int] = None


class LocationUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    address: Optional[str] = None
    location_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    description: Optional[str] = None
    group_id: Optional[int] = None


class LocationResponse(BaseModel):
    location_id: int
    name: str
    address: str
    location_type: str
    latitude: float
    longitude: float
    description: Optional[str]
    group_id: Optional[int]
    group_name: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LocationOptionResponse(BaseModel):
    location_id: int
    name: str
    location_type: str
    location_type_label: str
    group_id: Optional[int]
    group_name: Optional[str]


class LocationPageResponse(BaseModel):
    items: list[LocationResponse]
    total: int
    page: int
    page_size: int
