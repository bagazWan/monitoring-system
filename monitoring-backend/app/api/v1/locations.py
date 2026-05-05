from typing import List, Optional

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Device, Location, LocationGroup, Switch, User
from app.schemas.location import (
    LocationCreate,
    LocationOptionResponse,
    LocationPageResponse,
    LocationResponse,
    LocationUpdate,
)
from app.services.locations_service import (
    normalize_location_type,
    type_label,
    validate_group_rule,
)
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

router = APIRouter(prefix="/locations", tags=["Locations"])


@router.get("", response_model=LocationPageResponse)
def get_all_locations(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=1000),
    search: Optional[str] = Query(None),
    location_type: Optional[str] = Query(None),
    group_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(Location).outerjoin(
        LocationGroup, Location.group_id == LocationGroup.group_id
    )

    if location_type:
        query = query.filter(
            Location.location_type == normalize_location_type(location_type)
        )
    if group_id is not None:
        query = query.filter(Location.group_id == group_id)
    if search:
        term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                func.lower(Location.name).like(term),
                func.lower(Location.address).like(term),
                func.lower(func.coalesce(LocationGroup.name, "")).like(term),
            )
        )

    total = query.count()
    rows = (
        query.order_by(Location.location_id.asc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    items = [
        LocationResponse(
            location_id=location.location_id,
            name=location.name,
            address=location.address,
            location_type=location.location_type,
            latitude=location.latitude,
            longitude=location.longitude,
            description=location.description,
            group_id=location.group_id,
            group_name=location.group.name if location.group else None,
            created_at=location.created_at,
            updated_at=location.updated_at,
        )
        for location in rows
    ]
    return {"items": items, "total": total, "page": page, "page_size": limit}


@router.get("/options", response_model=List[LocationOptionResponse])
def get_location_options(db: Session = Depends(get_db)):
    rows = (
        db.query(Location)
        .outerjoin(LocationGroup, Location.group_id == LocationGroup.group_id)
        .order_by(
            Location.location_type.asc(),
            func.coalesce(LocationGroup.name, "").asc(),
            Location.name.asc(),
        )
        .all()
    )
    return [
        {
            "location_id": location.location_id,
            "name": location.name,
            "location_type": location.location_type,
            "location_type_label": type_label(location.location_type),
            "group_id": location.group_id,
            "group_name": location.group.name if location.group else None,
        }
        for location in rows
    ]


@router.get("/with-nodes", response_model=List[str])
def get_locations_with_nodes(db: Session = Depends(get_db)):
    device_locations = (
        db.query(Location.name)
        .join(Device, Location.location_id == Device.location_id)
        .distinct()
        .all()
    )
    switch_locations = (
        db.query(Location.name)
        .join(Switch, Location.location_id == Switch.location_id)
        .distinct()
        .all()
    )
    names = {name for (name,) in device_locations + switch_locations if name}
    return sorted(names)


@router.get("/{location_id}", response_model=LocationResponse)
def get_location(location_id: int, db: Session = Depends(get_db)):
    location = db.query(Location).filter(Location.location_id == location_id).first()
    if not location:
        raise HTTPException(status_code=404, detail=f"Location {location_id} not found")
    return LocationResponse(
        location_id=location.location_id,
        name=location.name,
        address=location.address,
        location_type=location.location_type,
        latitude=location.latitude,
        longitude=location.longitude,
        description=location.description,
        group_id=location.group_id,
        group_name=location.group.name if location.group else None,
        created_at=location.created_at,
        updated_at=location.updated_at,
    )


@router.post("", response_model=LocationResponse, status_code=status.HTTP_201_CREATED)
def create_location(
    payload: LocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    normalized_type = normalize_location_type(payload.location_type)
    validate_group_rule(normalized_type, payload.group_id)

    existing = (
        db.query(Location)
        .filter(func.lower(Location.name) == payload.name.strip().lower())
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=400, detail=f"Location {payload.name} already exists"
        )

    if payload.group_id is not None:
        group = (
            db.query(LocationGroup)
            .filter(LocationGroup.group_id == payload.group_id)
            .first()
        )
        if not group:
            raise HTTPException(
                status_code=404, detail=f"LocationGroup {payload.group_id} not found"
            )

    row = Location(
        name=payload.name.strip(),
        address=payload.address,
        location_type=normalized_type,
        latitude=payload.latitude,
        longitude=payload.longitude,
        description=payload.description,
        group_id=payload.group_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    return LocationResponse(
        location_id=row.location_id,
        name=row.name,
        address=row.address,
        location_type=row.location_type,
        latitude=row.latitude,
        longitude=row.longitude,
        description=row.description,
        group_id=row.group_id,
        group_name=row.group.name if row.group else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.patch("/{location_id}", response_model=LocationResponse)
def update_location(
    location_id: int,
    payload: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    row = db.query(Location).filter(Location.location_id == location_id).first()
    if not row:
        raise HTTPException(status_code=404, detail=f"Location {location_id} not found")

    data = payload.model_dump(exclude_unset=True)
    if "location_type" in data:
        data["location_type"] = normalize_location_type(data["location_type"])

    next_type = data.get("location_type", row.location_type)
    next_group_id = data.get("group_id", row.group_id)
    validate_group_rule(next_type, next_group_id)

    if "group_id" in data and data["group_id"] is not None:
        group = (
            db.query(LocationGroup)
            .filter(LocationGroup.group_id == data["group_id"])
            .first()
        )
        if not group:
            raise HTTPException(
                status_code=404, detail=f"LocationGroup {data['group_id']} not found"
            )

    for f, v in data.items():
        setattr(row, f, v)

    db.commit()
    db.refresh(row)

    return LocationResponse(
        location_id=row.location_id,
        name=row.name,
        address=row.address,
        location_type=row.location_type,
        latitude=row.latitude,
        longitude=row.longitude,
        description=row.description,
        group_id=row.group_id,
        group_name=row.group.name if row.group else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.delete("/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_location(
    location_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    row = db.query(Location).filter(Location.location_id == location_id).first()
    if not row:
        raise HTTPException(status_code=404, detail=f"Location {location_id} not found")
    db.delete(row)
    db.commit()
    return None
