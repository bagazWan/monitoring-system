from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from app.api.dependencies import (
    get_current_user,
    require_admin,
    require_technician_or_admin,
)
from app.core.database import get_db
from app.models import Alert, Device, Location, Switch, SwitchAlert, User
from app.schemas.alert import (
    AlertBulkDeleteResponse,
    AlertPageResponse,
    AlertResponse,
    AlertUpdate,
)
from app.services.locations_service import apply_location_name_filter
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import false, or_
from sqlalchemy.orm import Session

router = APIRouter(prefix="/alerts", tags=["Alerts"])


def _alert_to_response_dict(alert_obj: Any) -> Dict[str, Any]:
    dev_name = " - "
    loc_name = " - "

    if hasattr(alert_obj, "device") and alert_obj.device:
        dev_name = alert_obj.device.name
        if alert_obj.device.location:
            loc_name = alert_obj.device.location.name
    elif hasattr(alert_obj, "switch") and alert_obj.switch:
        dev_name = alert_obj.switch.name
        if alert_obj.switch.location:
            loc_name = alert_obj.switch.location.name

    raw_status = getattr(alert_obj, "status", "")
    final_status = "active" if str(raw_status) == "1" else raw_status

    resolved_by_full_name = None
    if getattr(alert_obj, "assigned_user", None):
        resolved_by_full_name = getattr(alert_obj.assigned_user, "full_name", None)

    return {
        "alert_id": getattr(alert_obj, "alert_id", None),
        "device_id": getattr(alert_obj, "device_id", None),
        "switch_id": getattr(alert_obj, "switch_id", None),
        "device_name": dev_name,
        "location_name": loc_name,
        "librenms_alert_id": getattr(alert_obj, "librenms_alert_id", None),
        "category_id": getattr(alert_obj, "category_id", None),
        "alert_type": getattr(alert_obj, "alert_type", ""),
        "severity": getattr(alert_obj, "severity", ""),
        "message": getattr(alert_obj, "message", ""),
        "status": final_status,
        "assigned_to_user_id": getattr(alert_obj, "assigned_to_user_id", None),
        "resolved_by_full_name": resolved_by_full_name,
        "acknowledged_at": getattr(alert_obj, "acknowledged_at", None),
        "resolution_note": getattr(alert_obj, "resolution_note", None),
        "created_at": getattr(alert_obj, "created_at", None),
        "cleared_at": getattr(alert_obj, "cleared_at", None),
    }


def _apply_alert_filters(
    device_query,
    switch_query,
    db: Session,
    *,
    status_filter: Optional[str],
    severity: Optional[str],
    start_date: Optional[datetime],
    end_date: Optional[datetime],
    location_name: Optional[str],
):
    if status_filter:
        if status_filter == "active":
            device_query = device_query.filter(
                or_(Alert.status == "active", Alert.status == "1")
            )
            switch_query = switch_query.filter(
                or_(SwitchAlert.status == "active", SwitchAlert.status == "1")
            )
        else:
            device_query = device_query.filter(Alert.status == status_filter)
            switch_query = switch_query.filter(SwitchAlert.status == status_filter)

    if severity:
        device_query = device_query.filter(Alert.severity == severity)
        switch_query = switch_query.filter(SwitchAlert.severity == severity)

    if start_date:
        device_query = device_query.filter(Alert.created_at >= start_date)
        switch_query = switch_query.filter(SwitchAlert.created_at >= start_date)

    if end_date:
        device_query = device_query.filter(Alert.created_at <= end_date)
        switch_query = switch_query.filter(SwitchAlert.created_at <= end_date)

    if location_name:
        loc_q = db.query(Location.location_id)
        loc_q = apply_location_name_filter(loc_q, location_name)
        location_ids = [row[0] for row in loc_q.distinct().all()]

        if location_ids:
            device_query = device_query.join(Device).filter(
                Device.location_id.in_(location_ids)
            )
            switch_query = switch_query.join(Switch).filter(
                Switch.location_id.in_(location_ids)
            )
        else:
            device_query = device_query.filter(false())
            switch_query = switch_query.filter(false())

    return device_query, switch_query


@router.get("/", response_model=AlertPageResponse)
def get_all_alerts(
    status_filter: Optional[str] = Query(None, description="Filter alerts by status"),
    severity: Optional[str] = Query(None, description="Filter by severity"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    location_name: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
):
    device_query = db.query(Alert)
    switch_query = db.query(SwitchAlert)

    device_query, switch_query = _apply_alert_filters(
        device_query,
        switch_query,
        db,
        status_filter=status_filter,
        severity=severity,
        start_date=start_date,
        end_date=end_date,
        location_name=location_name,
    )

    all_alerts = []
    for a in device_query:
        all_alerts.append(_alert_to_response_dict(a))
    for a in switch_query:
        all_alerts.append(_alert_to_response_dict(a))

    all_alerts.sort(key=lambda x: x.get("created_at") or "", reverse=True)

    total = len(all_alerts)
    start = (page - 1) * limit
    end = start + limit
    items = all_alerts[start:end]

    return {
        "items": items,
        "total": total,
        "page": page,
        "page_size": limit,
    }


@router.get("/active", response_model=List[AlertResponse])
def get_active_alerts(db: Session = Depends(get_db)):
    device_alerts = (
        db.query(Alert).filter(or_(Alert.status == "active", Alert.status == "1")).all()
    )

    switch_alerts = (
        db.query(SwitchAlert)
        .filter(or_(SwitchAlert.status == "active", SwitchAlert.status == "1"))
        .all()
    )

    results = [_alert_to_response_dict(a) for a in device_alerts + switch_alerts]
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


@router.get("/locations", response_model=List[str])
def get_alert_locations(
    status_filter: Optional[str] = Query(None, description="Filter by status"),
    db: Session = Depends(get_db),
):
    device_query = db.query(Alert)
    switch_query = db.query(SwitchAlert)

    device_query, switch_query = _apply_alert_filters(
        device_query,
        switch_query,
        db,
        status_filter=status_filter,
        severity=None,
        start_date=None,
        end_date=None,
        location_name=None,
    )

    device_locations = (
        device_query.join(Device)
        .join(Location)
        .with_entities(Location.name)
        .distinct()
        .all()
    )

    switch_locations = (
        switch_query.join(Switch)
        .join(Location)
        .with_entities(Location.name)
        .distinct()
        .all()
    )

    names = {name for (name,) in device_locations + switch_locations if name}
    return sorted(names)


@router.get("/{alert_id}", response_model=AlertResponse)
def get_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()
    if alert:
        return _alert_to_response_dict(alert)

    alert = db.query(SwitchAlert).filter(SwitchAlert.alert_id == alert_id).first()
    if alert:
        return _alert_to_response_dict(alert)

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Alert with id {alert_id} not found",
    )


@router.patch("/{alert_id}", response_model=AlertResponse)
def update_alert(
    alert_id: int,
    alert_data: AlertUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()
    if not alert:
        alert = db.query(SwitchAlert).filter(SwitchAlert.alert_id == alert_id).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert with id {alert_id} not found",
        )

    update_data = alert_data.model_dump(exclude_unset=True)
    alert.assigned_to_user_id = current_user.user_id
    alert.acknowledged_at = datetime.now(timezone.utc)

    if "resolution_note" in update_data:
        alert.resolution_note = update_data["resolution_note"]
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return _alert_to_response_dict(alert)


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()
    if not alert:
        alert = db.query(SwitchAlert).filter(SwitchAlert.alert_id == alert_id).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert with id {alert_id} not found",
        )

    db.delete(alert)
    db.commit()

    return None


@router.delete(
    "/", response_model=AlertBulkDeleteResponse, status_code=status.HTTP_200_OK
)
def delete_alerts_bulk(
    status_filter: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    location_name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    device_query = db.query(Alert.alert_id)
    switch_query = db.query(SwitchAlert.alert_id)

    device_query, switch_query = _apply_alert_filters(
        device_query,
        switch_query,
        db,
        status_filter=status_filter,
        severity=severity,
        start_date=start_date,
        end_date=end_date,
        location_name=location_name,
    )

    device_ids = [row.alert_id for row in device_query.all()]
    switch_ids = [row.alert_id for row in switch_query.all()]

    deleted = 0
    if device_ids:
        deleted += (
            db.query(Alert)
            .filter(Alert.alert_id.in_(device_ids))
            .delete(synchronize_session=False)
        )
    if switch_ids:
        deleted += (
            db.query(SwitchAlert)
            .filter(SwitchAlert.alert_id.in_(switch_ids))
            .delete(synchronize_session=False)
        )

    db.commit()
    return {"deleted": deleted}
