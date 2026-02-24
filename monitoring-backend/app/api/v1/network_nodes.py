from typing import Optional

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Location, NetworkNode, User
from app.schemas.network_map import (
    NetworkNodeCreate,
    NetworkNodePageResponse,
    NetworkNodeResponse,
    NetworkNodeUpdate,
)
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

router = APIRouter(prefix="/network-nodes", tags=["Network Nodes"])


@router.get("", response_model=NetworkNodePageResponse)
def list_network_nodes(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = Query(None),
    location_id: Optional[int] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    query = db.query(NetworkNode).outerjoin(Location)

    if location_id is not None:
        query = query.filter(NetworkNode.location_id == location_id)

    if search:
        term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                func.lower(NetworkNode.name).like(term),
                func.lower(NetworkNode.node_type).like(term),
                func.lower(Location.name).like(term),
            )
        )

    total = query.count()
    items = (
        query.order_by(NetworkNode.node_id.asc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    return {"items": items, "total": total, "page": page, "page_size": limit}


@router.get("/{node_id}", response_model=NetworkNodeResponse)
def get_network_node(node_id: int, db: Session = Depends(get_db)):
    network_node = db.query(NetworkNode).filter(NetworkNode.node_id == node_id).first()
    if not network_node:
        raise HTTPException(status_code=404, detail="Network node not found")
    return network_node


@router.post(
    "", response_model=NetworkNodeResponse, status_code=status.HTTP_201_CREATED
)
def create_network_node(
    payload: NetworkNodeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    loc = db.query(Location).filter(Location.location_id == payload.location_id).first()
    if not loc:
        raise HTTPException(status_code=404, detail="Location not found")

    new_node = NetworkNode(**payload.model_dump())
    db.add(new_node)
    db.commit()
    db.refresh(new_node)
    return new_node


@router.patch("/{node_id}", response_model=NetworkNodeResponse)
def update_network_node(
    node_id: int,
    payload: NetworkNodeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    network_node = db.query(NetworkNode).filter(NetworkNode.node_id == node_id).first()
    if not network_node:
        raise HTTPException(status_code=404, detail="Network node not found")

    data = payload.model_dump(exclude_unset=True)

    if "location_id" in data:
        loc = (
            db.query(Location)
            .filter(Location.location_id == data["location_id"])
            .first()
        )
        if not loc:
            raise HTTPException(status_code=404, detail="Location not found")

    for field, value in data.items():
        setattr(network_node, field, value)

    db.commit()
    db.refresh(network_node)
    return network_node


@router.delete("/{node_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_network_node(
    node_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    network_node = db.query(NetworkNode).filter(NetworkNode.node_id == node_id).first()
    if not network_node:
        raise HTTPException(status_code=404, detail="Network node not found")

    db.delete(network_node)
    db.commit()
