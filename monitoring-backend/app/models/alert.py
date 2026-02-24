from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class SwitchAlert(Base):
    __tablename__ = "switch_alerts"

    alert_id = Column(Integer, primary_key=True, autoincrement=True)
    switch_id = Column(
        Integer,
        ForeignKey("switches.switch_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    librenms_alert_id = Column(Integer, nullable=True, index=True)
    category_id = Column(
        Integer, ForeignKey("problem_categories.category_id", ondelete="SET NULL")
    )
    alert_type = Column(String(255), nullable=False)
    severity = Column(String(255), index=True)
    message = Column(String(255))
    assigned_to_user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="SET NULL")
    )
    acknowledged_at = Column(DateTime(timezone=True), nullable=True)
    resolution_note = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
    cleared_at = Column(DateTime(timezone=True))
    status = Column(String(255), index=True)

    switch = relationship("Switch", back_populates="alerts")
    category = relationship("ProblemCategory", back_populates="switch_alerts")
    assigned_user = relationship("User")

    def __repr__(self):
        return f"<SwitchAlert(id={self.alert_id}, switch_id={self.switch_id}, type='{self.alert_type}', severity='{self.severity}')>"


class Alert(Base):
    __tablename__ = "alerts"

    alert_id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(
        Integer,
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    librenms_alert_id = Column(Integer, nullable=True, index=True)
    category_id = Column(
        Integer, ForeignKey("problem_categories.category_id", ondelete="SET NULL")
    )
    alert_type = Column(String(255), nullable=False)
    severity = Column(String(255), index=True)
    message = Column(String(255))
    assigned_to_user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="SET NULL")
    )
    acknowledged_at = Column(DateTime(timezone=True), nullable=True)
    resolution_note = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
    cleared_at = Column(DateTime(timezone=True))
    status = Column(String(255), index=True)

    device = relationship("Device", back_populates="alerts")
    category = relationship("ProblemCategory", back_populates="device_alerts")
    assigned_user = relationship("User")

    def __repr__(self):
        return f"<Alert(id={self.alert_id}, device_id={self.device_id}, type='{self.alert_type}', severity='{self.severity}')>"
