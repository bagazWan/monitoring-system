from typing import Any, Dict, List

from app.core.database import get_db
from app.models.setting import SystemConfig, ThresholdRule
from app.schemas.setting import (
    BulkSettingsUpdateRequest,
    SystemConfigResponse,
    ThresholdRuleResponse,
)
from app.services.settings_cache import settings_cache
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

router = APIRouter()

router = APIRouter(prefix="/settings", tags=["Setting"])


@router.get("/system", response_model=SystemConfigResponse)
def get_system_config(db: Session = Depends(get_db)) -> Any:
    config = settings_cache.get_system_config()
    if not config:
        config = db.query(SystemConfig).first()
    return config


@router.get("/rules/{device_type}", response_model=List[ThresholdRuleResponse])
def get_device_rules(device_type: str, db: Session = Depends(get_db)) -> Any:
    return settings_cache.get_rules_for_device(device_type)


@router.get("/rules", response_model=Dict[str, List[ThresholdRuleResponse]])
def get_all_rules(db: Session = Depends(get_db)) -> Any:
    return settings_cache.get_all_rules()


@router.put("/bulk")
def update_all_settings(
    payload: BulkSettingsUpdateRequest,
    target_device_type: str = None,
    db: Session = Depends(get_db),
) -> Any:
    sys_config = db.query(SystemConfig).first()
    if not sys_config:
        raise HTTPException(
            status_code=404, detail="System config not found in database."
        )
    for key, value in payload.system_config.model_dump().items():
        setattr(sys_config, key, value)

    if target_device_type is not None and payload.threshold_rules is not None:
        device_type_clean = target_device_type.lower()
        db.query(ThresholdRule).filter(
            ThresholdRule.device_type == device_type_clean
        ).delete()

        new_rules = []
        for rule_schema in payload.threshold_rules:
            new_rule = ThresholdRule(
                device_type=device_type_clean,
                metric_type=rule_schema.metric_type,
                condition=rule_schema.condition,
                warning_value=rule_schema.warning_value,
                critical_value=rule_schema.critical_value,
            )
            new_rules.append(new_rule)

        db.add_all(new_rules)

    db.commit()

    settings_cache.refresh_cache(db)

    return {"message": "Settings updated successfully and cache refreshed."}
