from typing import Optional

from app.core.database import get_db
from app.services.dashboard_service import (
    build_dashboard_stats,
    build_dashboard_traffic,
    build_uptime_trend,
)
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats")
async def get_dashboard_summary(
    location_id: Optional[int] = Query(None),
    top_down_window: int = Query(7, ge=1, le=30),
    db: Session = Depends(get_db),
):
    return await build_dashboard_stats(
        db=db, location_id=location_id, top_down_window=top_down_window
    )


@router.get("/traffic")
async def get_dashboard_traffic(
    location_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    return await build_dashboard_traffic(db=db, location_id=location_id)


@router.get("/uptime-trend")
def get_uptime_trend(
    days: int = Query(7, ge=1, le=30),
    location_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    return build_uptime_trend(db, days, location_id=location_id)
