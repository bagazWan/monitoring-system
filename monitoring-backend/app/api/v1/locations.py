from typing import List, Optional

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Location, User
from app.schemas.location import LocationCreate, LocationResponse, LocationUpdate
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/locations", tags=["Locations"])


# Get all locations
@router.get("", response_model=List[LocationResponse])
def get_all_locations(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=1000, description="Max records to return"),
    location_type: Optional[str] = Query(None, description="Filter by location type"),
    db: Session = Depends(get_db),
):
    query = db.query(Location)

    # Apply filters if provided
    if location_type:
        query = query.filter(Location.location_type == location_type)

    # Get locations with pagination
    locations = query.offset(skip).limit(limit).all()

    return locations


# Get single location
@router.get("/{location_id}", response_model=LocationResponse)
def get_location(location_id: int, db: Session = Depends(get_db)):
    location = db.query(Location).filter(Location.location_id == location_id).first()

    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Location with id {location_id} not found",
        )

    return location


# Create new location
@router.post("", response_model=LocationResponse, status_code=status.HTTP_201_CREATED)
def create_location(
    location_data: LocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    # Check if latitude and longitude already exists
    existing_location = (
        db.query(Location).filter(Location.name == location_data.name).first()
    )

    if existing_location:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Location with name {location_data.name} already exists",
        )

    new_location = Location(**location_data.model_dump())

    db.add(new_location)
    db.commit()
    db.refresh(new_location)

    return new_location


# Update location
@router.patch("/{location_id}", response_model=LocationResponse)
def update_location(
    location_id: int,
    location_data: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    # Find location
    location = db.query(Location).filter(Location.location_id == location_id).first()

    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Location with id {location_id} not found",
        )

    # Update only provided fields
    update_data = location_data.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(location, field, value)

    db.commit()
    db.refresh(location)

    return location


# Delete location
@router.delete("/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_location(
    location_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    location = db.query(Location).filter(Location.location_id == location_id).first()

    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Location with id {location_id} not found",
        )

    db.delete(location)
    db.commit()

    return None
