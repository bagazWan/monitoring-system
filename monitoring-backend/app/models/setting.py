from sqlalchemy import Column, Float, Integer, String

from app.core.database import Base


class SystemConfig(Base):
    __tablename__ = "system_config"

    id = Column(Integer, primary_key=True, autoincrement=True)

    # Polling Settings
    ping_frequency = Column(Integer, default=5, nullable=False)
    ping_probe_count = Column(Integer, default=3, nullable=False)
    ping_timeout_ms = Column(Integer, default=1000, nullable=False)

    # Sensitivity & Hysteresis
    offline_fail_required = Column(Integer, default=3, nullable=False)
    recovery_success_required = Column(Integer, default=2, nullable=False)
    alert_raise_streak = Column(Integer, default=2, nullable=False)
    alert_clear_streak = Column(Integer, default=2, nullable=False)

    # Retention
    history_interval_seconds = Column(Integer, default=300, nullable=False)
    history_retention_days = Column(Integer, default=365, nullable=False)
    alert_retention_days = Column(Integer, default=90, nullable=False)

    def __repr__(self):
        return f"<SystemConfig(ping_freq={self.ping_frequency}, history_retention={self.history_retention_days})>"


class ThresholdRule(Base):
    __tablename__ = "threshold_rules"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_type = Column(String(100), nullable=False, index=True)
    metric_type = Column(String(50), nullable=False)
    condition = Column(String(20), default="above", nullable=False)
    warning_value = Column(Float, nullable=False)
    critical_value = Column(Float, nullable=False)

    def __repr__(self):
        return f"<ThresholdRule(type='{self.device_type}', metric='{self.metric_type}', warn={self.warning_value}, crit={self.critical_value})>"
