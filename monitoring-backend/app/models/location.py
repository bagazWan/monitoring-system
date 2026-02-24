from sqlalchemy import Column, DateTime, Float, Integer, String, Text, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class Location(Base):
    __tablename__ = "locations"

    location_id = Column(Integer, primary_key=True, autoincrement=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(String(255))
    location_type = Column(String(255), nullable=False, index=True)
    name = Column(String(255), index=True)
    description = Column(Text)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    devices = relationship("Device", back_populates="location")
    switches = relationship("Switch", back_populates="location")
    network_nodes = relationship("NetworkNode", back_populates="location")

    def __repr__(self):
        return f"<Location(id={self.location_id}, name='{self.name}', type='{self.location_type}')>"
