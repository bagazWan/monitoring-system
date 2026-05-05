import asyncio

from app.services.librenms.client import LibreNMSService

from . import state
from .poller import run_librenms_sync_loop, run_status_poller


def start_status_poller_task(
    libre_service: LibreNMSService, interval_seconds: int = 5
) -> asyncio.Task:
    if state.status_poller_task and not state.status_poller_task.done():
        return state.status_poller_task

    state.status_poller_stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()

    state.librenms_sync_task = loop.create_task(run_librenms_sync_loop(libre_service))
    state.status_poller_task = loop.create_task(run_status_poller(interval_seconds))
    return state.status_poller_task


async def stop_status_poller_task() -> None:
    if state.status_poller_stop_event:
        state.status_poller_stop_event.set()

    tasks = []
    if state.status_poller_task:
        tasks.append(state.status_poller_task)
    if state.librenms_sync_task:
        tasks.append(state.librenms_sync_task)

    for task in tasks:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

    state.status_poller_task = None
    state.librenms_sync_task = None
    state.status_poller_stop_event = None
