from typing import Any, Dict, List, Optional

from app.api.dependencies import (
    get_current_user,
    require_admin,
    require_technician_or_admin,
)
from app.core.database import get_db
from app.models import Alert, SwitchAlert, User
from app.notifications import websocket_endpoint
from app.schemas.alert import AlertResponse, AlertUpdate
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/alerts", tags=["Alerts"])


def _alert_to_response_dict(alert_obj: Any) -> Dict[str, Any]:
    """
    Convert Alert/SwitchAlert SQLAlchemy model into a dictionary that matches
    AlertResponse schema to avoid leaking SQLAlchemy internals
    """
    return {
        "alert_id": getattr(alert_obj, "alert_id", None),
        "device_id": getattr(alert_obj, "device_id", None),
        "switch_id": getattr(alert_obj, "switch_id", None),
        "librenms_alert_id": getattr(alert_obj, "librenms_alert_id", None),
        "category_id": getattr(alert_obj, "category_id", None),
        "alert_type": getattr(alert_obj, "alert_type", ""),
        "severity": getattr(alert_obj, "severity", ""),
        "message": getattr(alert_obj, "message", ""),
        "status": getattr(alert_obj, "status", ""),
        "assigned_to_user_id": getattr(alert_obj, "assigned_to_user_id", None),
        "created_at": getattr(alert_obj, "created_at", None),
        "cleared_at": getattr(alert_obj, "cleared_at", None),
    }


@router.get("/", response_model=List[AlertResponse])
def get_all_alerts(
    status_filter: Optional[str] = Query(None, description="Filter alerts by status"),
    severity: Optional[str] = Query(None, description="Filter by severity"),
    assigned_to: Optional[int] = Query(None, description="Filter by assigned user"),
    db: Session = Depends(get_db),
):
    """
    Return combined list of device and switch alerts
    """
    # Query device alerts
    device_query = db.query(Alert)
    if status_filter:
        device_query = device_query.filter(Alert.status == status_filter)
    if severity:
        device_query = device_query.filter(Alert.severity == severity)
    if assigned_to:
        device_query = device_query.filter(Alert.assigned_to_user_id == assigned_to)

    device_alerts = device_query.all()

    # Query switch alerts
    switch_query = db.query(SwitchAlert)
    if status_filter:
        switch_query = switch_query.filter(SwitchAlert.status == status_filter)
    if severity:
        switch_query = switch_query.filter(SwitchAlert.severity == severity)
    if assigned_to:
        switch_query = switch_query.filter(
            SwitchAlert.assigned_to_user_id == assigned_to
        )

    switch_alerts = switch_query.all()

    all_alerts = []

    # Normalize device alerts
    for a in device_alerts:
        all_alerts.append(_alert_to_response_dict(a))

    # Normalize switch alerts
    for a in switch_alerts:
        all_alerts.append(_alert_to_response_dict(a))

    # Sort by newest first (created_at may none)
    all_alerts.sort(key=lambda x: x.get("created_at") or "", reverse=True)

    return all_alerts


@router.get("/active", response_model=List[AlertResponse])
def get_active_alerts(db: Session = Depends(get_db)):
    """
    Get only active (unresolved) alerts
    """
    device_alerts = db.query(Alert).filter(Alert.status == "active").all()
    switch_alerts = db.query(SwitchAlert).filter(SwitchAlert.status == "active").all()

    results = [_alert_to_response_dict(a) for a in device_alerts + switch_alerts]
    # Keep newest first
    results.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    return results


@router.get("/{alert_id}", response_model=AlertResponse)
def get_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get single alert by ID (searches both device and switch alerts)
    """
    # Try device alerts first
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()
    if alert:
        return _alert_to_response_dict(alert)

    # Try switch alerts
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
    """
    Update fields on an alert (device or switch) for admin/teknisi
    """
    # Try device alerts
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()
    if not alert:
        # Try switch alerts
        alert = db.query(SwitchAlert).filter(SwitchAlert.alert_id == alert_id).first()

    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert with id {alert_id} not found",
        )

    # Update fields
    update_data = alert_data.model_dump(exclude_unset=True)

    # Auto-set cleared_at if status changed to a cleared-like state
    if (
        update_data.get("status")
        and update_data.get("status") == "cleared"
        and "cleared_at" not in update_data
    ):
        from datetime import datetime

        update_data["cleared_at"] = datetime.utcnow()

    for field, value in update_data.items():
        setattr(alert, field, value)

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
    """
    Delete an alert (device or switch) for admin only
    """
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


@router.websocket("/ws/alerts")
async def alerts_websocket(websocket: WebSocket):
    """
    WebSocket endpoint that forwards the connection to the shared notifications websocket handler.
    """
    await websocket_endpoint(websocket)
