from typing import Optional

from fastapi import HTTPException, status

from app.utils.constant import LOCATION_TYPE_ALIASES, LOCATION_TYPE_LABELS


def normalize_location_type(raw: Optional[str]) -> str:
    v = (raw or "").strip().lower()
    v = " ".join(v.split())
    if v in LOCATION_TYPE_ALIASES:
        return LOCATION_TYPE_ALIASES[v]
    return v.replace(" ", "_")


def type_label(v: Optional[str]) -> str:
    key = (v or "").strip().lower()
    return LOCATION_TYPE_LABELS.get(key, (v or "").replace("_", " ").title())


def validate_group_rule(location_type: str, group_id: Optional[int]) -> None:
    if location_type != "gerbang_tol" and group_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="group_id is mandatory for non-Toll Gate locations",
        )
