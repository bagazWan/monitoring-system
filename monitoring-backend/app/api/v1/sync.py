from app.api.dependencies import require_admin
from app.core.database import get_db
from app.models import User
from app.services.alerts_service import sync_alerts_once
from app.services.librenms_service import LibreNMSService
from app.services.sync_service import SyncService
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

router = APIRouter(prefix="/sync", tags=["Sync"])


@router.post("/from-librenms", status_code=status.HTTP_200_OK)
async def sync_from_librenms(
    update_existing: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Unified Sync Endpoint:
    Fetches all devices from LibreNMS and updates switches and devices tables.
    """
    service = SyncService(db)
    results = await service.sync_all_from_librenms(update_existing=update_existing)

    return {
        "status": "success",
        "synced_stats": results["stats"],
        "logs": results["logs"],
    }


@router.post("/alerts", status_code=status.HTTP_200_OK)
async def sync_alerts_now(current_user: User = Depends(require_admin)):
    librenms = LibreNMSService()
    try:
        processed = await sync_alerts_once(librenms)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to sync alerts from LibreNMS: {str(exc)}",
        )
    return {"processed": processed}
