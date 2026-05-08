from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class UserNotificationSettingBase(BaseModel):
    enable_popups: bool = Field(default=True, description="Enable snackbar popups")
    notification_level: str = Field(
        default="all",
        pattern="^(all|warning_critical|critical)$",
        description="Filter level for notifications",
    )


class UserNotificationSettingUpdate(UserNotificationSettingBase):
    pass


class UserNotificationSettingResponse(UserNotificationSettingBase):
    user_id: int
    model_config = ConfigDict(from_attributes=True)


class ThresholdRuleBase(BaseModel):
    metric_type: str = Field(description="e.g., latency, bandwidth_in, bandwidth_out")
    condition: str = Field(
        pattern="^(above|below)$",
        description="Trigger if value goes above or below threshold",
    )
    warning_value: float = Field(ge=0)
    critical_value: float = Field(ge=0)


class ThresholdRuleCreate(ThresholdRuleBase):
    device_type: str


class ThresholdRuleResponse(ThresholdRuleCreate):
    id: int
    model_config = ConfigDict(from_attributes=True)


class SystemConfigBase(BaseModel):
    # Polling
    ping_frequency: int = Field(ge=1, description="Interval in seconds")
    ping_probe_count: int = Field(ge=1)
    ping_timeout_ms: int = Field(ge=100)

    # Sensitivity
    offline_fail_required: int = Field(ge=1)
    recovery_success_required: int = Field(ge=1)
    alert_raise_streak: int = Field(ge=1)
    alert_clear_streak: int = Field(ge=1)

    # Retention
    history_interval_seconds: int = Field(ge=60)
    history_retention_days: int = Field(ge=1)
    alert_retention_days: int = Field(ge=1)


class SystemConfigUpdate(SystemConfigBase):
    pass


class SystemConfigResponse(SystemConfigBase):
    id: int
    model_config = ConfigDict(from_attributes=True)


class BulkSettingsUpdateRequest(BaseModel):
    system_config: SystemConfigUpdate
    threshold_rules: Optional[List[ThresholdRuleCreate]] = None
