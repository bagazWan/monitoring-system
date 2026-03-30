from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Optional

Severity = Literal["green", "yellow", "red"]


@dataclass(frozen=True)
class BandwidthThreshold:
    low_warning: Optional[float] = None
    low_critical: Optional[float] = None
    high_warning: Optional[float] = None
    high_critical: Optional[float] = None


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
        "throughput": BandwidthThreshold(
            low_warning=1.0,
            low_critical=0.1,
            high_warning=10.0,
            high_critical=12.0,
        ),
        "latency": LatencyThreshold(warning=30.0, critical=100.0),
    },
    "switch": {"utilization": UtilizationThreshold(warning=70.0, critical=90.0)},
    "router": {"utilization": UtilizationThreshold(warning=70.0, critical=90.0)},
    "access point": {"utilization": UtilizationThreshold(warning=50.0, critical=75.0)},
    # "pc": {"throughput_drop": 0.5}, #Server rule is workload-dependent; leave for now.#
}


def _normalize_device_type(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    key = value.strip().lower()
    return key.replace("_", " ")


def evaluate_throughput(
    inbound_mbps: float, outbound_mbps: float, threshold: BandwidthThreshold
) -> Severity:
    total = inbound_mbps + outbound_mbps

    if threshold.low_critical is not None and total < threshold.low_critical:
        return "red"
    if threshold.low_warning is not None and total < threshold.low_warning:
        return "yellow"
    if threshold.high_critical is not None and total > threshold.high_critical:
        return "red"
    if threshold.high_warning is not None and total > threshold.high_warning:
        return "yellow"
    return "green"


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


def evaluate_device_severity(
    device_type: Optional[str], inbound_mbps: float, outbound_mbps: float
) -> Severity:
    key = _normalize_device_type(device_type)
    if not key:
        return "green"

    thresholds = DEVICE_THRESHOLDS.get(key)
    if not thresholds:
        return "green"

    if "throughput" in thresholds:
        return evaluate_throughput(
            inbound_mbps, outbound_mbps, thresholds["throughput"]
        )

    return "green"


def evaluate_device_latency_severity(
    device_type: Optional[str], latency_ms: Optional[float]
) -> Severity:
    key = _normalize_device_type(device_type)
    if not key:
        return "green"

    thresholds = DEVICE_THRESHOLDS.get(key)
    if not thresholds or "latency" not in thresholds:
        return "green"

    return evaluate_latency(latency_ms, thresholds["latency"])


def evaluate_switch_severity(
    utilization_percent: Optional[float], device_type: Optional[str] = "switch"
) -> Severity:
    key = _normalize_device_type(device_type) or "switch"
    thresholds = DEVICE_THRESHOLDS.get(key)

    if not thresholds or "utilization" not in thresholds:
        return "green"

    return evaluate_utilization(utilization_percent, thresholds["utilization"])
