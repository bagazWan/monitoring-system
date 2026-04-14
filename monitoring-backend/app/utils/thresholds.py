from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Optional

Severity = Literal["green", "yellow", "red"]


@dataclass(frozen=True)
class DirectionalBandwidthThreshold:
    in_warning_low: Optional[float] = None
    in_critical_low: Optional[float] = None
    out_warning_low: Optional[float] = None
    out_critical_low: Optional[float] = None


@dataclass(frozen=True)
class UtilizationThreshold:
    warning: float
    critical: float


@dataclass(frozen=True)
class LatencyThreshold:
    warning: float
    critical: float


DEVICE_THRESHOLDS = {
    "cctv": {
        "throughput_directional": DirectionalBandwidthThreshold(
            in_warning_low=0.02,  # 20 Kbps
            in_critical_low=0.005,  # 5 Kbps
            out_warning_low=1.5,  # 1.5 Mbps
            out_critical_low=0.7,  # 0.7 Mbps
        ),
        "latency": LatencyThreshold(warning=30.0, critical=100.0),
    },
    "switch": {"utilization": UtilizationThreshold(warning=70.0, critical=90.0)},
    "router": {"utilization": UtilizationThreshold(warning=70.0, critical=90.0)},
    "access point": {"utilization": UtilizationThreshold(warning=50.0, critical=75.0)},
    "pc": {"latency": LatencyThreshold(warning=90.0, critical=150.0)},
    "hp": {"latency": LatencyThreshold(warning=90.0, critical=150.0)},
}


def _normalize_device_type(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    return value.strip().lower().replace("_", " ")


def _severity_rank(sev: Severity) -> int:
    return {"green": 0, "yellow": 1, "red": 2}[sev]


def evaluate_utilization(
    utilization_percent: Optional[float], threshold: UtilizationThreshold
) -> Severity:
    if utilization_percent is None:
        return "green"
    if utilization_percent >= threshold.critical:
        return "red"
    if utilization_percent >= threshold.warning:
        return "yellow"
    return "green"


def evaluate_latency(
    latency_ms: Optional[float], threshold: LatencyThreshold
) -> Severity:
    if latency_ms is None:
        return "green"
    if latency_ms >= threshold.critical:
        return "red"
    if latency_ms >= threshold.warning:
        return "yellow"
    return "green"


def evaluate_directional_bandwidth(
    in_mbps: Optional[float],
    out_mbps: Optional[float],
    threshold: DirectionalBandwidthThreshold,
) -> Severity:
    result: Severity = "green"

    if in_mbps is not None:
        if (
            threshold.in_critical_low is not None
            and in_mbps < threshold.in_critical_low
        ):
            result = "red"
        elif (
            threshold.in_warning_low is not None and in_mbps < threshold.in_warning_low
        ):
            result = "yellow"

    out_result: Severity = "green"
    if out_mbps is not None:
        if (
            threshold.out_critical_low is not None
            and out_mbps < threshold.out_critical_low
        ):
            out_result = "red"
        elif (
            threshold.out_warning_low is not None
            and out_mbps < threshold.out_warning_low
        ):
            out_result = "yellow"

    return out_result if _severity_rank(out_result) > _severity_rank(result) else result


def evaluate_device_severity(
    device_type: Optional[str],
    inbound_mbps: float,
    outbound_mbps: float,
) -> Severity:
    key = _normalize_device_type(device_type)
    if not key:
        return "green"

    conf = DEVICE_THRESHOLDS.get(key)
    if not conf:
        return "green"

    directional = conf.get("throughput_directional")
    if directional:
        return evaluate_directional_bandwidth(inbound_mbps, outbound_mbps, directional)

    return "green"


def evaluate_device_latency_severity(
    device_type: Optional[str], latency_ms: Optional[float]
) -> Severity:
    key = _normalize_device_type(device_type)
    if not key:
        return "green"

    conf = DEVICE_THRESHOLDS.get(key)
    if not conf or "latency" not in conf:
        return "green"

    return evaluate_latency(latency_ms, conf["latency"])


def evaluate_switch_severity(
    utilization_percent: Optional[float], device_type: Optional[str] = "switch"
) -> Severity:
    key = _normalize_device_type(device_type) or "switch"
    conf = DEVICE_THRESHOLDS.get(key)
    if not conf or "utilization" not in conf:
        return "green"

    return evaluate_utilization(utilization_percent, conf["utilization"])
