from enum import Enum


class DeviceStatus(str, Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    UNKNOWN = "unknown"


class DeviceType(str, Enum):
    CCTV = "CCTV"
    SWITCH = "Switch"
    ROUTER = "Router"
    ACCESS_POINT = "AccessPoint"
    UNKNOWN = "unknown"
