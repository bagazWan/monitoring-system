from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import Device, LibreNMSPort, Switch
from app.services.librenms_service import LibreNMSService


def should_enable_port(port: dict) -> bool:
    """
    Default port-selection rule
    - Only consider ports with operStatus up (if present)
    - Prefer ifType ethernetCsmacd
    - Fallback to ifName prefixes typical for physical ports
    - Exclude common logical interfaces (bridge/vlan/lo)
    """
    if_name = (port.get("ifName") or port.get("if_name") or "").lower()
    if_type = (port.get("ifType") or port.get("if_type") or "").lower()
    if_oper = (port.get("ifOperStatus") or port.get("if_oper_status") or "").lower()

    if if_oper and if_oper != "up":
        return False

    if if_type in {"bridge", "l2vlan", "softwareloopback"}:
        return False
    if if_name.startswith(("bridge", "vlan", "lo")):
        return False

    if if_type == "ethernetcsmacd":
        return True
    if if_name.startswith(("ether", "eth", "gi", "fa")):
        return True

    return False


async def discover_and_store_ports_for(
    *,
    db: Session,
    librenms: LibreNMSService,
    librenms_device_id: int,
    device: Device | None = None,
    switch: Switch | None = None,
) -> None:
    """
    Discover mapping to port_id and store in librenms_ports table.
    - /devices/{id}/ports -> only ifName list
    - /ports -> port_id + ifName list (might not include device_id)
    - /ports/{port_id} -> includes device_id + ifType + ifOperStatus + rates
    """
    if device is None and switch is None:
        return

    dev_ports_payload = await librenms.get_device_port_stats(int(librenms_device_id))
    if_names = [
        p.get("ifName") for p in dev_ports_payload.get("ports", []) if p.get("ifName")
    ]
    if not if_names:
        return

    ports_payload = await librenms.get_ports()
    global_ports = ports_payload.get("ports", [])

    if_name_set = set(if_names)

    candidates = []
    for gp in global_ports:
        if gp.get("ifName") in if_name_set and gp.get("port_id") is not None:
            candidates.append(
                {"port_id": int(gp["port_id"]), "ifName": gp.get("ifName")}
            )

    if not candidates:
        return

    stored: list[LibreNMSPort] = []

    for c in candidates:
        port_id = int(c["port_id"])

        port_detail = await librenms.get_port_by_id(port_id)
        port_list = port_detail.get("port", [])
        if not port_list:
            continue
        pd = port_list[0]

        # Ensure this port belongs to this device in LibreNMS
        if int(pd.get("device_id", -1)) != int(librenms_device_id):
            continue

        existing = (
            db.query(LibreNMSPort).filter(LibreNMSPort.port_id == port_id).first()
        )
        if existing:
            existing.device_id = device.device_id if device else None
            existing.switch_id = switch.switch_id if switch else None
            existing.librenms_device_id = int(librenms_device_id)
            existing.if_name = pd.get("ifName") or c["ifName"]
            existing.if_type = pd.get("ifType")
            existing.if_oper_status = pd.get("ifOperStatus")
            stored.append(existing)
        else:
            lp = LibreNMSPort(
                device_id=device.device_id if device else None,
                switch_id=switch.switch_id if switch else None,
                librenms_device_id=int(librenms_device_id),
                port_id=port_id,
                if_name=pd.get("ifName") or c["ifName"],
                if_type=pd.get("ifType"),
                if_oper_status=pd.get("ifOperStatus"),
                enabled=False,
                # is_uplink defaults to false at DB level
            )
            db.add(lp)
            stored.append(lp)

    db.flush()

    enabled_any = False
    for port_row in stored:
        port_like = {
            "ifName": port_row.if_name,
            "ifType": port_row.if_type,
            "ifOperStatus": port_row.if_oper_status,
        }
        port_row.enabled = bool(should_enable_port(port_like))
        if port_row.enabled:
            enabled_any = True

    # fallback: enable all "up" ports if none enabled
    if not enabled_any:
        for port_row in stored:
            if (port_row.if_oper_status or "").lower() == "up":
                port_row.enabled = True

    db.flush()
