from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime, String
from sqlalchemy.orm import relationship
from app.core.database import Base

class SwitchBandwidth(Base):
    __tablename__ = "switch_bandwidth"

    id = Column(Integer, primary_key=True, autoincrement=True)
    switch_id = Column(Integer, ForeignKey("switches.switch_id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime(timezone=True))
    in_usage_mbps = Column(Float, nullable=False)
    out_usage_mbps = Column(Float, nullable=False)
    total_usage_mbps = Column(Float, nullable=False)
    latency_ms = Column(Float)
    packet_loss = Column(Float)
    status = Column(String(255))

    switch = relationship("Switch", back_populates="bandwidth_records")

    def __repr__(self):
        return f"<SwitchBandwidth(switch_id={self.switch_id}, total={self.total_usage_mbps}Mbps, timestamp={self.timestamp})>"

class DeviceBandwidth(Base):
    __tablename__ = "device_bandwidth"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(Integer, ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime(timezone=True))
    in_usage_mbps = Column(Float, nullable=False)
    out_usage_mbps = Column(Float, nullable=False)
    total_usage_mbps = Column(Float, nullable=False)
    latency_ms = Column(Float)
    packet_loss = Column(Float)
    status = Column(String(255))

    device = relationship("Device", back_populates="bandwidth_records")

    def __repr__(self):
        return f"<DeviceBandwidth(device_id={self.device_id}, total={self.total_usage_mbps}Mbps, timestamp={self.timestamp})>"
