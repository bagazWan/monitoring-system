import asyncio
import logging
from datetime import datetime, timedelta, timezone

from app.core.database import SessionLocal
from app.models import Device, Switch
from app.models.bandwidth import DeviceBandwidth, SwitchBandwidth
from app.services.librenms.client import LibreNMSService
from app.services.metrics.metrics_calculators import (
    calculate_device_metrics,
    calculate_switch_metrics,
)
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


async def _cleanup_old_data(db: Session):
    cutoff = datetime.now(timezone.utc) - timedelta(days=365)
    db.query(DeviceBandwidth).filter(DeviceBandwidth.timestamp < cutoff).delete(
        synchronize_session=False
    )
    db.query(SwitchBandwidth).filter(SwitchBandwidth.timestamp < cutoff).delete(
        synchronize_session=False
    )
    db.commit()
    logger.info("Executed 1-year data retention cleanup.")


async def run_metrics_history_poller(
    librenms: LibreNMSService, interval_seconds: int = 300
):
    last_cleanup = None

    while True:
        try:
            db = SessionLocal()
            now = datetime.now(timezone.utc)

            if last_cleanup is None or (now - last_cleanup).days >= 1:
                await _cleanup_old_data(db)
                last_cleanup = now

            devices = db.query(Device).all()
            switches = db.query(Switch).all()

            new_device_records = []
            for dev in devices:
                metrics = await calculate_device_metrics(dev, db, librenms)
                new_device_records.append(
                    DeviceBandwidth(
                        device_id=dev.device_id,
                        timestamp=now,
                        in_usage_mbps=metrics.get("in_mbps", 0.0),
                        out_usage_mbps=metrics.get("out_mbps", 0.0),
                        total_usage_mbps=metrics.get("in_mbps", 0.0)
                        + metrics.get("out_mbps", 0.0),
                        latency_ms=metrics.get("latency_ms"),
                        packet_loss=0.0,
                        status=metrics.get("status"),
                    )
                )

            new_switch_records = []
            for sw in switches:
                metrics = await calculate_switch_metrics(sw, db, librenms)
                new_switch_records.append(
                    SwitchBandwidth(
                        switch_id=sw.switch_id,
                        timestamp=now,
                        in_usage_mbps=metrics.get("in_mbps", 0.0),
                        out_usage_mbps=metrics.get("out_mbps", 0.0),
                        total_usage_mbps=metrics.get("in_mbps", 0.0)
                        + metrics.get("out_mbps", 0.0),
                        latency_ms=0.0,
                        packet_loss=0.0,
                        status=metrics.get("status"),
                    )
                )

            if new_device_records:
                db.add_all(new_device_records)
            if new_switch_records:
                db.add_all(new_switch_records)

            db.commit()
            db.close()
            logger.info(
                f"Saved historical metrics for {len(new_device_records)} devices and {len(new_switch_records)} switches."
            )

        except Exception as e:
            logger.error(f"Error in metrics history poller: {e}")

        await asyncio.sleep(interval_seconds)


_history_poller_task = None


def start_metrics_history_poller(
    librenms: LibreNMSService, interval_seconds: int = 300
):
    global _history_poller_task
    if _history_poller_task is None:
        _history_poller_task = asyncio.create_task(
            run_metrics_history_poller(librenms, interval_seconds)
        )
    return _history_poller_task


async def stop_metrics_history_poller():
    global _history_poller_task
    if _history_poller_task:
        _history_poller_task.cancel()
        try:
            await _history_poller_task
        except asyncio.CancelledError:
            pass
        _history_poller_task = None
