from typing import List, Optional

from app.api.dependencies import (
    get_current_user,
    require_admin,
    require_technician_or_admin,
)
from app.core.database import get_db
from app.models import Alert, SwitchAlert, User
from app.schemas.alert import AlertResponse, AlertUpdate
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/alerts", tags=["Alerts"])


@router.get("/", response_model=List[AlertResponse])
def get_all_alerts(
    status_filter: Optional[str] = Query(None, description="Filter alerts by status"),
    severity: Optional[str] = Query(None, description="Filter by severity"),
    assigned_to: Optional[int] = Query(None, description="Filter by assigned user"),
    db: Session = Depends(get_db),
):
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

    # Add device alerts
    for alert in device_alerts:
        all_alerts.append(
            {
                **alert.__dict__,
                "switch_id": None,  # Device alerts don't have switch_id
            }
        )

    # Add switch alerts
    for alert in switch_alerts:
        all_alerts.append(
            {
                **alert.__dict__,
                "device_id": None,  # Switch alerts don't have device_id
            }
        )

    # Sort by newest first
    all_alerts.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    return all_alerts


@router.get("/active", response_model=List[AlertResponse])
def get_active_alerts(db: Session = Depends(get_db)):
    """
    Get only active (unresolved) alerts
    """
    device_alerts = db.query(Alert).filter(Alert.status == "active").all()
    switch_alerts = db.query(SwitchAlert).filter(SwitchAlert.status == "active").all()

    # Combine and return
    return device_alerts + switch_alerts


@router.get("/{alert_id}", response_model=AlertResponse)
def get_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Get single alert by ID
    Checks both device and switch alerts
    """
    # Try device alerts first
    alert = db.query(Alert).filter(Alert.alert_id == alert_id).first()
    if alert:
        return alert

    # Try switch alerts
    alert = db.query(SwitchAlert).filter(SwitchAlert.alert_id == alert_id).first()
    if alert:
        return alert

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

    # Auto-set cleared_at if status changed to "cleared"
    if update_data.get("status") == "cleared" and "cleared_at" not in update_data:
        from datetime import datetime

        update_data["cleared_at"] = datetime.utcnow()

    for field, value in update_data.items():
        setattr(alert, field, value)

    db.commit()
    db.refresh(alert)

    return alert


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
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

    db.delete(alert)
    db.commit()

    return None
