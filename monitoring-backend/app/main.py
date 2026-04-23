import asyncio
import logging
from sys import prefix
from typing import Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import (
    alerts,
    analytics,
    auth,
    dashboard,
    devices,
    fo_routes,
    librenms_ports,
    location_groups,
    locations,
    map,
    network_nodes,
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
from app.services.metrics_history_poller import (
    start_metrics_history_poller,
    stop_metrics_history_poller,
)
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

libre_service: LibreNMSService = LibreNMSService()

# Background poller task handle
_alerts_poller_task: Optional[asyncio.Task] = None
_status_poller_task: Optional[asyncio.Task] = None
_status_tracking_task: Optional[asyncio.Task] = None


@app.on_event("startup")
async def on_startup():
    global _alerts_poller_task, _status_tracking_task
    if settings.LIBRENMS_ALERTS_ENABLED:
        _alerts_poller_task = start_alerts_poller_task(
            libre_service, interval_seconds=getattr(settings, "POLL_INTERVAL", 5)
        )
        logger.info("Started LibreNMS alerts poller task")
    else:
        logger.info("LibreNMS alerts poller disabled (backend-only alerts)")

    _status_poller_task = start_status_poller_task(
        libre_service, interval_seconds=getattr(settings, "POLL_INTERVAL", 5)
    )
    logger.info("Started status tracking loop")

    start_metrics_history_poller(libre_service, interval_seconds=300)
    logger.info("Started 5-minute metrics history poller")


@app.on_event("shutdown")
async def on_shutdown():
    """
    Application shutdown:  stop all background tasks
    """
    global _status_tracking_task
    await stop_alerts_poller_task()
    await stop_status_poller_task()
    await stop_metrics_history_poller()
    logger.info("Stopped all background poller tasks")


@app.get("/")
def root():
    return {"message": "Monitoring System API", "docs": "/docs"}


app.include_router(devices.router, prefix="/api/v1")
app.include_router(switches.router, prefix="/api/v1")
app.include_router(locations.router, prefix="/api/v1")
app.include_router(location_groups.router, prefix="/api/v1")
app.include_router(map.router, prefix="/api/v1")
app.include_router(network_nodes.router, prefix="/api/v1")
app.include_router(fo_routes.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(alerts.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")
app.include_router(dashboard.router, prefix="/api/v1")
app.include_router(websocket.router, prefix="/api/v1")
app.include_router(librenms_ports.router, prefix="/api/v1")
app.include_router(register.router, prefix="/api/v1")
app.include_router(analytics.router, prefix="/api/v1")
