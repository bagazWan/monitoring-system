from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Query, Session, aliased

from app.models import Location, LocationGroup
from app.utils.constant import LOCATION_TYPE_ALIASES, LOCATION_TYPE_LABELS


def resolve_location_ids(
    db: Session,
    location_id: Optional[int],
    location_name: Optional[str],
) -> Optional[List[int]]:
    if location_id is not None:
        return [location_id]

    if location_name and location_name.strip():
        q = db.query(Location.location_id)
        q = apply_location_name_filter(q, location_name)
        rows = q.distinct().all()
        if rows:
            return [row[0] for row in rows]
        return [-1]

    return None


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


def is_toll_gate_type(raw: Optional[str]) -> bool:
    normalized = normalize_location_type(raw)
    return normalized == "gerbang_tol"


def apply_location_name_filter(query: Query, location_name: Optional[str]) -> Query:
    if not location_name or not location_name.strip():
        return query

    needle = location_name.strip().lower()
    ParentGroup = aliased(LocationGroup)

    query = query.outerjoin(LocationGroup, Location.group_id == LocationGroup.group_id)
    query = query.outerjoin(
        ParentGroup, LocationGroup.parent_id == ParentGroup.group_id
    )

    return query.filter(
        or_(
            func.lower(func.coalesce(ParentGroup.name, "")) == needle,
            func.lower(func.coalesce(LocationGroup.name, "")) == needle,
            (
                (func.lower(Location.name) == needle)
                & (
                    func.lower(func.coalesce(Location.location_type, ""))
                    == "gerbang_tol"
                )
            ),
        )
    )
