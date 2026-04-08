from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_service import LibreNMSService

VOLATILE_PREFIXES = ("veth", "br-", "virbr", "tun", "tap")


def is_volatile_ifname(if_name: str) -> bool:
    return (if_name or "").lower().startswith(VOLATILE_PREFIXES)


def should_enable_port(port: dict) -> bool:
    if_name = (port.get("ifName") or port.get("if_name") or "").lower()
    if_type = (port.get("ifType") or port.get("if_type") or "").lower()
    if_oper = (port.get("ifOperStatus") or port.get("if_oper_status") or "").lower()

    if if_oper and if_oper != "up":
        return False
    if if_type in {"bridge", "l2vlan", "softwareloopback"}:
        return False

    if is_volatile_ifname(if_name):
        return False

    if if_type == "ethernetcsmacd":
        return True

    if if_name.startswith(
        (
            "ether",
            "eth",
            "enp",
            "eno",
            "ens",
            "wl",
            "wlan",
            "wlp",
            "wifi",
            "gi",
            "fa",
            "lo",
            "tailscale",
            "docker",
        )
    ):
        return True

    return False


def _owner_rows(db: Session, device: Device | None, switch: Switch | None):
    q = db.query(LibreNMSPort)
    if device is not None:
        q = q.filter(LibreNMSPort.device_id == device.device_id)
    else:
        q = q.filter(LibreNMSPort.switch_id == switch.switch_id)
    return q


async def discover_and_store_ports_for(
    *,
    db: Session,
    librenms: LibreNMSService,
    librenms_device_id: int,
    device: Device | None = None,
    switch: Switch | None = None,
) -> None:
    if device is None and switch is None:
        return

    # Hard cleanup legacy volatile rows
    owner_existing = _owner_rows(db, device, switch).all()
    for row in owner_existing:
        if is_volatile_ifname(row.if_name):
            db.delete(row)
    db.flush()

    # Device-scoped source of truth
    dev_ports_payload = await librenms.get_device_port_stats(int(librenms_device_id))
    dev_ports = dev_ports_payload.get("ports", [])

    current_ifnames: list[str] = []
    for p in dev_ports:
        if_name = p.get("ifName")
        if not if_name:
            continue
        if is_volatile_ifname(if_name):
            continue
        current_ifnames.append(if_name)

    current_if_set = set(current_ifnames)

    # if no current non-volatile interfaces, remove owner rows to stay in sync
    owner_existing = _owner_rows(db, device, switch).all()
    if not current_if_set:
        for old in owner_existing:
            db.delete(old)
        db.flush()
        return

    # Build ifName->port_id map using global ports list
    ports_payload = await librenms.get_ports()
    global_ports = ports_payload.get("ports", [])

    if_to_port: dict[str, int] = {}
    for gp in global_ports:
        if_name = gp.get("ifName")
        port_id = gp.get("port_id")
        if if_name in current_if_set and port_id is not None:
            if_to_port[if_name] = int(port_id)

    owner_existing = _owner_rows(db, device, switch).all()
    existing_by_if = {r.if_name: r for r in owner_existing}
    seen_ifnames: set[str] = set()
    stored: list[LibreNMSPort] = []

    for if_name, port_id in if_to_port.items():
        try:
            detail = await librenms.get_port_by_id(port_id)
            p_list = detail.get("port", [])
            if not p_list:
                continue
            pd = p_list[0]

            if int(pd.get("device_id", -1)) != int(librenms_device_id):
                continue

            real_if = pd.get("ifName") or if_name
            if is_volatile_ifname(real_if):
                continue

            seen_ifnames.add(real_if)

            row = existing_by_if.get(real_if)
            if row:
                row.port_id = int(port_id)
                row.librenms_device_id = int(librenms_device_id)
                row.if_type = pd.get("ifType")
                row.if_oper_status = pd.get("ifOperStatus")
                stored.append(row)
            else:
                row = LibreNMSPort(
                    device_id=device.device_id if device else None,
                    switch_id=switch.switch_id if switch else None,
                    librenms_device_id=int(librenms_device_id),
                    port_id=int(port_id),
                    if_name=real_if,
                    if_type=pd.get("ifType"),
                    if_oper_status=pd.get("ifOperStatus"),
                    enabled=False,
                )
                db.add(row)
                stored.append(row)
        except Exception:
            continue

    # Remove stale rows not seen in current snapshot
    for old in owner_existing:
        if old.if_name not in seen_ifnames:
            db.delete(old)

    db.flush()

    enabled_any = False
    for row in stored:
        row.enabled = bool(
            should_enable_port(
                {
                    "ifName": row.if_name,
                    "ifType": row.if_type,
                    "ifOperStatus": row.if_oper_status,
                }
            )
        )
        if row.enabled:
            enabled_any = True

    if not enabled_any:
        for row in stored:
            if (row.if_oper_status or "").lower() == "up":
                row.enabled = True

    db.flush()
