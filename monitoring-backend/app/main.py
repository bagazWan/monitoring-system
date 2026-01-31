import asyncio
import logging
from typing import Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import (
    alerts,
    auth,
    dashboard,
    devices,
    librenms_ports,
    locations,
    register,
    switches,
    sync,
    users,
    websocket,
)
from app.core.config import settings
from app.services.alerts_service import (
    start_alerts_poller_task,
    stop_alerts_poller_task,
)
from app.services.librenms_service import LibreNMSService
from app.services.status_poller import (
    start_status_poller_task,
    stop_status_poller_task,
)

logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Monitoring System Gateway API",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Singleton LibreNMS service instance that other modules can import
libre_service: LibreNMSService = LibreNMSService()

# Background poller task handle
_alerts_poller_task: Optional[asyncio.Task] = None
_status_poller_task: Optional[asyncio.Task] = None


@app.on_event("startup")
async def on_startup():
    """
    Application startup: start LibreNMS alerts poller as a background asyncio Task
    """
    global _alerts_poller_task, _status_poller_task
    # alerts poller
    _alerts_poller_task = start_alerts_poller_task(
        libre_service, interval_seconds=getattr(settings, "POLL_INTERVAL", 5)
    )
    logger.info("Started alerts poller task")

    # status poller
    _status_poller_task = start_status_poller_task(
        libre_service, interval_seconds=getattr(settings, "POLL_INTERVAL", 5)
    )
    logger.info("Started status poller task for WebSocket")


@app.on_event("shutdown")
async def on_shutdown():
    """
    Application shutdown:  stop all background tasks
    """
    await stop_alerts_poller_task()
    await stop_status_poller_task()
    logger.info("Stopped all background poller tasks")


@app.get("/")
def root():
    return {"message": "Monitoring System API", "docs": "/docs"}


app.include_router(devices.router, prefix="/api/v1")
app.include_router(switches.router, prefix="/api/v1")
app.include_router(locations.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(alerts.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")
app.include_router(dashboard.router, prefix="/api/v1")
app.include_router(websocket.router, prefix="/api/v1")
app.include_router(librenms_ports.router, prefix="/api/v1")
app.include_router(register.router, prefix="/api/v1")
