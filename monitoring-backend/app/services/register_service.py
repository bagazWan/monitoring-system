import asyncio
import logging

import httpx
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models import Device, Switch
from app.schemas.device import LibreNMSRegisterRequest
from app.services.librenms_ports_service import discover_and_store_ports_for
from app.services.librenms_service import LibreNMSService

logger = logging.getLogger(__name__)


def infer_node_type_from_sysdescr(sys_descr: str) -> str:
    sys_descr_l = (sys_descr or "").lower()
    is_switch = ("switch" in sys_descr_l) and ("routeros" not in sys_descr_l)
    return "switch" if is_switch else "device"


def normalize_node_type(node_type: str | None) -> str | None:
    if node_type is None:
        return None
    nt = node_type.strip().lower()
    if nt in {"device", "switch"}:
        return nt
    return None


async def safe_discover_ports(
    *,
    db: Session,
    librenms: LibreNMSService,
    librenms_device_id: int,
    device: Device | None = None,
    switch: Switch | None = None,
) -> tuple[bool, str | None]:
    """
    Try to discover ports immediately in request lifecycle.
    """
    try:
        await discover_and_store_ports_for(
            db=db,
            librenms=librenms,
            librenms_device_id=librenms_device_id,
            device=device,
            switch=switch,
        )
        db.commit()
        return True, None

    except httpx.HTTPStatusError as exc:
        code = exc.response.status_code if exc.response else None
        db.rollback()

        if code == 404:
            warning = (
                "Device registered successfully, but LibreNMS ports not ready yet. "
                "Background retry is scheduled."
            )
            logger.warning(
                "Port discovery 404 for librenms_device_id=%s (%s)",
                librenms_device_id,
                "device" if device else "switch",
            )
            return False, warning

        warning = (
            "Device registered successfully, but initial port discovery failed "
            f"(HTTP {code}). Background retry is scheduled."
        )
        logger.exception(
            "Port discovery HTTP error for librenms_device_id=%s", librenms_device_id
        )
        return False, warning

    except Exception:
        db.rollback()
        warning = (
            "Device registered successfully, but initial port discovery failed. "
            "Background retry is scheduled."
        )
        logger.exception(
            "Port discovery unexpected error for librenms_device_id=%s",
            librenms_device_id,
        )
        return False, warning


async def retry_discover_ports_background(
    *,
    node_type: str,  # "device" | "switch"
    local_id: int,
    librenms_device_id: int,
    delays_seconds: tuple[int, ...] = (5, 15, 30, 60),
) -> None:
    """
    Background retry for port discovery after registration.
    """
    for attempt, delay in enumerate(delays_seconds, start=1):
        await asyncio.sleep(delay)

        db = SessionLocal()
        try:
            librenms = LibreNMSService()

            if node_type == "device":
                node = db.query(Device).filter(Device.device_id == local_id).first()
                if not node:
                    logger.warning(
                        "[PORT-RETRY] device_id=%s not found, stop retry", local_id
                    )
                    return

                await discover_and_store_ports_for(
                    db=db,
                    librenms=librenms,
                    librenms_device_id=librenms_device_id,
                    device=node,
                )
            else:
                node = db.query(Switch).filter(Switch.switch_id == local_id).first()
                if not node:
                    logger.warning(
                        "[PORT-RETRY] switch_id=%s not found, stop retry", local_id
                    )
                    return

                await discover_and_store_ports_for(
                    db=db,
                    librenms=librenms,
                    librenms_device_id=librenms_device_id,
                    switch=node,
                )

            db.commit()
            logger.info(
                "[PORT-RETRY] success node_type=%s local_id=%s librenms_device_id=%s attempt=%s",
                node_type,
                local_id,
                librenms_device_id,
                attempt,
            )
            return

        except httpx.HTTPStatusError as exc:
            db.rollback()
            code = exc.response.status_code if exc.response else None
            logger.warning(
                "[PORT-RETRY] HTTP error node_type=%s local_id=%s lnms_id=%s attempt=%s code=%s",
                node_type,
                local_id,
                librenms_device_id,
                attempt,
                code,
            )
        except Exception:
            db.rollback()
            logger.exception(
                "[PORT-RETRY] unexpected error node_type=%s local_id=%s lnms_id=%s attempt=%s",
                node_type,
                local_id,
                librenms_device_id,
                attempt,
            )
        finally:
            db.close()

    logger.warning(
        "[PORT-RETRY] exhausted node_type=%s local_id=%s librenms_device_id=%s",
        node_type,
        local_id,
        librenms_device_id,
    )


def schedule_port_retry_if_needed(
    *,
    payload: LibreNMSRegisterRequest,
    ports_discovered: bool,
    node_type: str,
    local_id: int,
    librenms_device_id: int,
) -> None:
    if not payload.snmp_enabled:
        return
    if ports_discovered:
        return

    try:
        loop = asyncio.get_running_loop()
        loop.create_task(
            retry_discover_ports_background(
                node_type=node_type,
                local_id=local_id,
                librenms_device_id=librenms_device_id,
            )
        )
    except RuntimeError:
        logger.warning(
            "No running loop to schedule port retry for node_type=%s local_id=%s",
            node_type,
            local_id,
        )
