from typing import List, Optional

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import Location, NetworkNode, User
from app.schemas.network_map import (
    NetworkNodeCreate,
    NetworkNodeResponse,
    NetworkNodeUpdate,
)
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/network-nodes", tags=["Network Nodes"])


@router.get("", response_model=List[NetworkNodeResponse])
def list_network_nodes(
    location_id: Optional[int] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    query = db.query(NetworkNode)
    if location_id is not None:
        query = query.filter(NetworkNode.location_id == location_id)
    return query.order_by(NetworkNode.node_id.asc()).all()


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
