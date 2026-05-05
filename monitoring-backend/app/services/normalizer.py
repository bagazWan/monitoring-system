from typing import Any, Optional

from app.utils.constant import LOCATION_TYPE_ALIASES


def normalize_node_type(node_type: str | None) -> str | None:
    if node_type is None:
        return None
    nt = node_type.strip().lower()
    if nt in {"device", "switch"}:
        return nt
    return None


def normalize_device_type(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    return value.strip().lower().replace("_", " ")


def normalize_location_type(raw: Optional[str]) -> str:
    v = (raw or "").strip().lower()
    v = " ".join(v.split())
    if v in LOCATION_TYPE_ALIASES:
        return LOCATION_TYPE_ALIASES[v]
    return v.replace(" ", "_")


def normalize_status(raw_status: Any) -> str:
    if raw_status is None:
        return "active"
    s = str(raw_status).strip().lower()
    if s in ("1", "active", "open", "alert", "triggered"):
        return "active"
    if s in ("0", "cleared", "resolved", "closed", "ok", "recovered"):
        return "cleared"
    return s


def status_to_severity(status: str | None) -> str:
    s = (status or "").lower()
    if s == "offline":
        return "red"
    if s == "warning":
        return "yellow"
    return "green"
