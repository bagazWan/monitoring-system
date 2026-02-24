from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class Device(Base):
    __tablename__ = "devices"

    device_id = Column(Integer, primary_key=True, autoincrement=True)
    librenms_device_id = Column(Integer, nullable=True, unique=True, index=True)
    librenms_hostname = Column(String(255), nullable=True, unique=True, index=True)
    librenms_last_synced = Column(DateTime(timezone=True), nullable=True)
    switch_id = Column(
        Integer, ForeignKey("switches.switch_id", ondelete="SET NULL"), index=True
    )
    name = Column(String(255), nullable=False, index=True)
    ip_address = Column(String(255), unique=True, nullable=False)
    mac_address = Column(String(255), unique=True, nullable=True)
    device_type = Column(String(255), nullable=True, index=True)
    location_id = Column(
        Integer, ForeignKey("locations.location_id"), nullable=True, index=True
    )
    status = Column(String(255), index=True)
    description = Column(String(255))
    last_replaced_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    location = relationship("Location", back_populates="devices")
    switch = relationship("Switch", back_populates="devices")
    replacements = relationship("DeviceReplacement", back_populates="device")
    bandwidth_records = relationship(
        "DeviceBandwidth", back_populates="device", cascade="all, delete-orphan"
    )
    alerts = relationship(
        "Alert", back_populates="device", cascade="all, delete-orphan"
    )
    librenms_ports = relationship(
        "LibreNMSPort", back_populates="device", cascade="all, delete-orphan"
    )

    def __repr__(self):
        return f"<Device(id={self.device_id}, name='{self.name}', type='{self.device_type}', status='{self.status}')>"
