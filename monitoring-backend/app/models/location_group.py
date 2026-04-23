from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class LocationGroup(Base):
    __tablename__ = "location_groups"

    group_id = Column(Integer, primary_key=True, autoincrement=True)
    parent_id = Column(
        Integer, ForeignKey("location_groups.group_id"), nullable=True, index=True
    )
    name = Column(String(255), nullable=False, unique=True, index=True)
    description = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    locations = relationship("Location", back_populates="group")
    parent = relationship("LocationGroup", remote_side=[group_id], backref="children")

    def __repr__(self):
        return f"<LocationGroup(id={self.group_id}, name='{self.name}', parent_id={self.parent_id})>"
