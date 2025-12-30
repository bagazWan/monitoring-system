from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class LocationCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Location name")
    address: str = Field(..., description="Location address")
    location_type: str = Field(..., description="Location type")
    latitude: float = Field(..., description="Location latitude")
    longitude: float = Field(..., description="Location longitude")


class LocationUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class LocationResponse(BaseModel):
    location_id: int
    name: str
    address: str
    location_type: str
    latitude: float
    longitude: float
    description: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True  # Allows conversion from SQLAlchemy model
