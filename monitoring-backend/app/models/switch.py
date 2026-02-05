from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class Switch(Base):
    __tablename__ = "switches"

    switch_id = Column(Integer, primary_key=True, autoincrement=True)
    librenms_device_id = Column(Integer, nullable=True, unique=True, index=True)
    librenms_hostname = Column(String(255), nullable=True, unique=True, index=True)
    librenms_last_synced = Column(DateTime(timezone=True), nullable=True)
    name = Column(String(255), nullable=False)
    ip_address = Column(String(255), nullable=False)
    location_id = Column(Integer, ForeignKey("locations.location_id"), nullable=True)
    node_id = Column(Integer, ForeignKey("network_nodes.node_id", ondelete="SET NULL"))
    status = Column(String(255))
    description = Column(String(255))
    last_replaced_at = Column(DateTime(timezone=True))
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    location = relationship("Location", back_populates="switches")
    network_node = relationship("NetworkNode", back_populates="switches")
    devices = relationship("Device", back_populates="switch")
    replacements = relationship("SwitchReplacement", back_populates="switch")
    bandwidth_records = relationship(
        "SwitchBandwidth", back_populates="switch", cascade="all, delete-orphan"
    )
    alerts = relationship(
        "SwitchAlert", back_populates="switch", cascade="all, delete-orphan"
    )
    librenms_ports = relationship(
        "LibreNMSPort", back_populates="switch", cascade="all, delete-orphan"
    )

    def __repr__(self):
        return f"<Switch(id={self.switch_id}, name='{self.name}', ip='{self.ip_address}', status='{self.status}')>"
