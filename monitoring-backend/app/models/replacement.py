from sqlalchemy import Column, Integer, ForeignKey, DateTime, String
from sqlalchemy.orm import relationship
from app.core.database import Base

class SwitchReplacement(Base):
    __tablename__ = "switch_replacement"

    id = Column(Integer, primary_key=True, autoincrement=True)
    switch_id = Column(Integer, ForeignKey("switches.switch_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    replaced_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(255))
    message = Column(String(255))

    switch = relationship("Switch", back_populates="replacements")
    user = relationship("User", back_populates="switch_replacements")

    def __repr__(self):
        return f"<SwitchReplacement(id={self.id}, switch_id={self.switch_id}, date={self.replaced_at})>"

class DeviceReplacement(Base):
    __tablename__ = "device_replacement"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(Integer, ForeignKey("devices.device_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False)
    replaced_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(255))
    message = Column(String(255))

    device = relationship("Device", back_populates="replacements")
    user = relationship("User", back_populates="device_replacements")

    def __repr__(self):
        return f"<DeviceReplacement(id={self.id}, device_id={self.device_id}, date={self.replaced_at})>"
