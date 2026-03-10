from typing import List, Optional

from app.api.dependencies import require_technician_or_admin
from app.core.database import get_db
from app.models import Device, LibreNMSPort, Switch, User
from app.schemas.librenms_port import LibreNMSPortResponse, LibreNMSPortUpdate
from app.services.librenms_ports_service import discover_and_store_ports_for
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/librenms-ports", tags=["LibreNMS Ports"])


@router.get("", response_model=List[LibreNMSPortResponse])
def list_ports(
    device_id: Optional[int] = Query(None),
    switch_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    if device_id is None and switch_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide device_id or switch_id",
        )
    if device_id is not None and switch_id is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide only one: device_id or switch_id",
        )

    q = db.query(LibreNMSPort)
    if device_id is not None:
        q = q.filter(LibreNMSPort.device_id == device_id)
    else:
        q = q.filter(LibreNMSPort.switch_id == switch_id)

    return q.order_by(LibreNMSPort.if_name.asc()).all()


@router.post("/resync", status_code=status.HTTP_202_ACCEPTED)
async def resync_ports(
    device_id: Optional[int] = Query(None),
    switch_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    if device_id is None and switch_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide device_id or switch_id",
        )
    if device_id is not None and switch_id is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide only one: device_id or switch_id",
        )

    librenms = LibreNMSService()

    if device_id is not None:
        device = db.query(Device).filter(Device.device_id == device_id).first()
        if not device or not device.librenms_device_id:
            raise HTTPException(status_code=404, detail="Device not found")
        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=int(device.librenms_device_id),
            device=device,
        )
    else:
        switch = db.query(Switch).filter(Switch.switch_id == switch_id).first()
        if not switch or not switch.librenms_device_id:
            raise HTTPException(status_code=404, detail="Switch not found")
        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=int(switch.librenms_device_id),
            switch=switch,
        )

    db.commit()
    return {"status": "ok"}


@router.patch("/{port_row_id}", response_model=LibreNMSPortResponse)
def update_port(
    port_row_id: int,
    payload: LibreNMSPortUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_technician_or_admin),
):
    port = db.query(LibreNMSPort).filter(LibreNMSPort.id == port_row_id).first()
    if not port:
        raise HTTPException(status_code=404, detail="Port not found")

    data = payload.model_dump(exclude_unset=True)

    if "enabled" in data:
        port.enabled = bool(data["enabled"])
        # if disabling the port, also unset uplink to keep invariants clean
        if port.enabled is False:
            port.is_uplink = False

    if "is_uplink" in data:
        new_uplink = bool(data["is_uplink"])
        port.is_uplink = new_uplink
        # uplink ports must be enabled
        if new_uplink:
            port.enabled = True

    db.commit()
    db.refresh(port)
    return port
