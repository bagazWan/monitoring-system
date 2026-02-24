from typing import Optional

from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import FORoute, NetworkNode, User
from app.schemas.network_map import (
    FORouteCreate,
    FORoutePageResponse,
    FORouteResponse,
    FORouteUpdate,
)
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, aliased

router = APIRouter(prefix="/fo-routes", tags=["FO Routes"])


@router.get("", response_model=FORoutePageResponse)
def list_fo_routes(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = Query(None),
    start_node_id: Optional[int] = Query(None, gt=0),
    end_node_id: Optional[int] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    start_node = aliased(NetworkNode)
    end_node = aliased(NetworkNode)

    query = (
        db.query(FORoute)
        .join(start_node, FORoute.start_node_id == start_node.node_id)
        .join(end_node, FORoute.end_node_id == end_node.node_id)
    )

    if start_node_id is not None:
        query = query.filter(FORoute.start_node_id == start_node_id)
    if end_node_id is not None:
        query = query.filter(FORoute.end_node_id == end_node_id)

    if search:
        term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                func.lower(start_node.name).like(term),
                func.lower(end_node.name).like(term),
                func.lower(FORoute.description).like(term),
            )
        )

    total = query.count()
    items = (
        query.order_by(FORoute.routes_id.asc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )

    return {"items": items, "total": total, "page": page, "page_size": limit}


@router.get("/{route_id}", response_model=FORouteResponse)
def get_fo_route(route_id: int, db: Session = Depends(get_db)):
    fo_route = db.query(FORoute).filter(FORoute.routes_id == route_id).first()
    if not fo_route:
        raise HTTPException(status_code=404, detail="FO route not found")
    return fo_route


@router.post("", response_model=FORouteResponse, status_code=status.HTTP_201_CREATED)
def create_fo_route(
    payload: FORouteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    if payload.start_node_id == payload.end_node_id:
        raise HTTPException(
            status_code=400, detail="start_node_id and end_node_id must differ"
        )

    start = (
        db.query(NetworkNode)
        .filter(NetworkNode.node_id == payload.start_node_id)
        .first()
    )
    end = (
        db.query(NetworkNode).filter(NetworkNode.node_id == payload.end_node_id).first()
    )
    if not start or not end:
        raise HTTPException(status_code=404, detail="Start or end node not found")

    new_route = FORoute(**payload.model_dump())
    db.add(new_route)
    db.commit()
    db.refresh(new_route)
    return new_route


@router.patch("/{route_id}", response_model=FORouteResponse)
def update_fo_route(
    route_id: int,
    payload: FORouteUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    fo_route = db.query(FORoute).filter(FORoute.routes_id == route_id).first()
    if not fo_route:
        raise HTTPException(status_code=404, detail="FO route not found")

    data = payload.model_dump(exclude_unset=True)

    start_node_id = data.get("start_node_id", fo_route.start_node_id)
    end_node_id = data.get("end_node_id", fo_route.end_node_id)
    if start_node_id == end_node_id:
        raise HTTPException(
            status_code=400, detail="start_node_id and end_node_id must differ"
        )

    if "start_node_id" in data:
        start = (
            db.query(NetworkNode)
            .filter(NetworkNode.node_id == data["start_node_id"])
            .first()
        )
        if not start:
            raise HTTPException(status_code=404, detail="Start node not found")
    if "end_node_id" in data:
        end = (
            db.query(NetworkNode)
            .filter(NetworkNode.node_id == data["end_node_id"])
            .first()
        )
        if not end:
            raise HTTPException(status_code=404, detail="End node not found")

    for field, value in data.items():
        setattr(fo_route, field, value)

    db.commit()
    db.refresh(fo_route)
    return fo_route


@router.delete("/{route_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_fo_route(
    route_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    fo_route = db.query(FORoute).filter(FORoute.routes_id == route_id).first()
    if not fo_route:
        raise HTTPException(status_code=404, detail="FO route not found")

    db.delete(fo_route)
    db.commit()
