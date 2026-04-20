from typing import List

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Location, LocationGroup, User
from app.schemas.location import (
    LocationGroupCreate,
    LocationGroupResponse,
    LocationGroupUpdate,
)
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

router = APIRouter(prefix="/location-groups", tags=["Location Groups"])


@router.get("", response_model=List[LocationGroupResponse])
def get_groups(db: Session = Depends(get_db)):
    return db.query(LocationGroup).order_by(LocationGroup.name.asc()).all()


@router.post(
    "", response_model=LocationGroupResponse, status_code=status.HTTP_201_CREATED
)
def create_group(
    payload: LocationGroupCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    name = payload.name.strip()
    existing = (
        db.query(LocationGroup)
        .filter(func.lower(LocationGroup.name) == name.lower())
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Group name already exist")

    row = LocationGroup(name=name, description=payload.description)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.patch("/{group_id}", response_model=LocationGroupResponse)
def update_group(
    group_id: int,
    payload: LocationGroupUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    row = db.query(LocationGroup).filter(LocationGroup.group_id == group_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Group not found")

    data = payload.model_dump(exclude_unset=True)
    if "name" in data and data["name"]:
        new_name = data["name"].strip()
        dup = (
            db.query(LocationGroup)
            .filter(
                func.lower(LocationGroup.name) == new_name.lower(),
                LocationGroup.group_id != group_id,
            )
            .first()
        )
        if dup:
            raise HTTPException(status_code=400, detail="Group name already exist")
        data["name"] = new_name

    for f, v in data.items():
        setattr(row, f, v)

    db.commit()
    db.refresh(row)
    return row


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    row = db.query(LocationGroup).filter(LocationGroup.group_id == group_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Group not found")

    in_use = db.query(Location).filter(Location.group_id == group_id).first()
    if in_use:
        raise HTTPException(status_code=409, detail="Group still used by location")

    db.delete(row)
    db.commit()
    return None
