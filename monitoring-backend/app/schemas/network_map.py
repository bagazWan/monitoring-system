from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class NetworkNodeCreate(BaseModel):
    location_id: int = Field(..., gt=0)
    name: Optional[str] = None
    node_type: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None


class NetworkNodeUpdate(BaseModel):
    location_id: Optional[int] = Field(None, gt=0)
    name: Optional[str] = None
    node_type: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None


class NetworkNodeResponse(BaseModel):
    node_id: int
    location_id: int
    name: Optional[str]
    node_type: str
    description: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class FORouteCreate(BaseModel):
    start_node_id: int = Field(..., gt=0)
    end_node_id: int = Field(..., gt=0)
    length_m: Optional[float] = Field(None, ge=0)
    description: Optional[str] = None


class FORouteUpdate(BaseModel):
    start_node_id: Optional[int] = Field(None, gt=0)
    end_node_id: Optional[int] = Field(None, gt=0)
    length_m: Optional[float] = Field(None, ge=0)
    description: Optional[str] = None


class FORouteResponse(BaseModel):
    routes_id: int
    start_node_id: int
    end_node_id: int
    length_m: Optional[float]
    description: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Map topology payload
class MapLocation(BaseModel):
    location_id: int
    name: Optional[str]
    location_type: str
    address: Optional[str]
    latitude: float
    longitude: float
    description: Optional[str]


class MapDevice(BaseModel):
    device_id: int
    name: str
    ip_address: str
    status: str
    location_id: Optional[int]
    switch_id: Optional[int]
    description: Optional[str]


class MapSwitch(BaseModel):
    switch_id: int
    name: str
    ip_address: str
    status: str
    location_id: Optional[int]
    node_id: Optional[int]
    description: Optional[str]


class MapTopologyResponse(BaseModel):
    locations: List[MapLocation]
    network_nodes: List[NetworkNodeResponse]
    fo_routes: List[FORouteResponse]
    devices: List[MapDevice]
    switches: List[MapSwitch]
