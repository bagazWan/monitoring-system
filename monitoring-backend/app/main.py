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
    locations,
    switches,
    sync,
    users,
)
from app.core.config import settings
from app.services.alerts_service import (
    start_alerts_poller_task,
    stop_alerts_poller_task,
)
from app.services.librenms_service import LibreNMSService

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


@app.on_event("startup")
async def on_startup():
    """
    Application startup: start LibreNMS alerts poller as a background asyncio Task
    """
    global _alerts_poller_task
    try:
        # configured in settings, fallback to 30s
        interval = getattr(settings, "ALERT_POLL_INTERVAL", 30)
        # create and store the background task that polls LibreNMS for alerts
        _alerts_poller_task = start_alerts_poller_task(
            libre_service, interval_seconds=interval
        )
        logger.info("Started LibreNMS alerts poller (interval=%s)", interval)
    except Exception:
        logger.exception("Failed to start alerts poller on startup")


@app.on_event("shutdown")
async def on_shutdown():
    """
    Application shutdown:
    - stop the alerts poller and allow it to cleanup
    - if the LibreNMSService exposes an async close method, call it
    """
    try:
        await stop_alerts_poller_task()
    except Exception:
        logger.exception("Error while stopping alerts poller")

    # If LibreNMSService has an async close/cleanup method, attempt to call it
    close_coro = getattr(libre_service, "close", None)
    if close_coro:
        try:
            result = close_coro()
            if asyncio.iscoroutine(result):
                await result
        except Exception:
            logger.exception("Error while closing LibreNMSService client")


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
