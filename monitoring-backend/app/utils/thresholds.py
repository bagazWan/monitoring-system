from typing import Literal, Optional

from app.services.normalizer import normalize_device_type
from app.services.settings_cache import settings_cache

Severity = Literal["green", "yellow", "red"]


def _severity_rank(sev: Severity) -> int:
    return {"green": 0, "yellow": 1, "red": 2}[sev]


def evaluate_dynamic_metric(
    value: Optional[float], metric_type: str, device_type: str
) -> Severity:
    if value is None:
        return "green"

    key = normalize_device_type(device_type)
    if not key:
        return "green"

    rules = settings_cache.get_rules_for_device(key)
    highest_severity: Severity = "green"

    for rule in rules:
        if rule.metric_type == metric_type:
            is_warning = False
            is_critical = False

            if rule.condition == "above":
                is_critical = value >= rule.critical_value
                is_warning = value >= rule.warning_value
            elif rule.condition == "below":
                is_critical = value <= rule.critical_value
                is_warning = value <= rule.warning_value

            current_sev = "red" if is_critical else "yellow" if is_warning else "green"

            if _severity_rank(current_sev) > _severity_rank(highest_severity):
                highest_severity = current_sev

    return highest_severity


def evaluate_device_severity(
    device_type: Optional[str],
    inbound_mbps: float,
    outbound_mbps: float,
) -> Severity:
    sev_in = evaluate_dynamic_metric(inbound_mbps, "bandwidth_in", device_type)
    sev_out = evaluate_dynamic_metric(outbound_mbps, "bandwidth_out", device_type)

    if "red" in (sev_in, sev_out):
        return "red"
    if "yellow" in (sev_in, sev_out):
        return "yellow"
    return "green"


def evaluate_device_latency_severity(
    device_type: Optional[str], latency_ms: Optional[float]
) -> Severity:
    return evaluate_dynamic_metric(latency_ms, "latency", device_type)


def evaluate_switch_severity(
    utilization_percent: Optional[float], device_type: Optional[str] = "switch"
) -> Severity:
    return "green"
