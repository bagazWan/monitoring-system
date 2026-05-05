import asyncio
import logging
from typing import Optional

from app.services.librenms.client import LibreNMSService
from app.services.monitoring.alerts_processor import process_librenms_alerts

logger = logging.getLogger(__name__)

# Module-level poller control variables
_poller_task: Optional[asyncio.Task] = None
_poller_stop_event: Optional[asyncio.Event] = None


async def sync_alerts_once(libre_service: LibreNMSService) -> int:
    try:
        lib_alerts = await libre_service.get_alerts()
    except Exception as exc:
        logger.exception("Failed to fetch alerts from LibreNMS: %s", exc)
        raise

    processed = await process_librenms_alerts(lib_alerts)
    logger.info("Processed %d alerts from LibreNMS", processed)
    return processed


async def _run_poller(libre_service: LibreNMSService, interval_seconds: int) -> None:
    global _poller_stop_event
    if _poller_stop_event is None:
        _poller_stop_event = asyncio.Event()

    logger.info("Alerts poller starting (interval=%s seconds)", interval_seconds)
    try:
        while not _poller_stop_event.is_set():
            try:
                await sync_alerts_once(libre_service)
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Error occurred while polling/processing alerts")

            try:
                await asyncio.wait_for(
                    _poller_stop_event.wait(), timeout=interval_seconds
                )
            except asyncio.TimeoutError:
                continue
    except asyncio.CancelledError:
        logger.info("Alerts poller task cancelled")
    finally:
        logger.info("Alerts poller stopped")


def start_alerts_poller_task(
    libre_service: LibreNMSService, interval_seconds: int = 30
) -> asyncio.Task:
    global _poller_task, _poller_stop_event

    if _poller_task and not _poller_task.done():
        return _poller_task

    _poller_stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    _poller_task = loop.create_task(_run_poller(libre_service, interval_seconds))
    return _poller_task


async def stop_alerts_poller_task() -> None:
    global _poller_task, _poller_stop_event
    if _poller_stop_event:
        _poller_stop_event.set()

    if _poller_task:
        _poller_task.cancel()
        try:
            await _poller_task
        except asyncio.CancelledError:
            pass
        _poller_task = None
        _poller_stop_event = None
