from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(255), unique=True, nullable=False, index=True)
    email = Column(String(255), nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False, index=True)
    role = Column(String(255), nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    device_replacements = relationship("DeviceReplacement", back_populates="user")
    switch_replacements = relationship("SwitchReplacement", back_populates="user")
    notification_setting = relationship(
        "UserNotificationSetting",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )

    def __repr__(self):
        return (
            f"<User(id={self.user_id}, username='{self.username}', role='{self.role}')>"
        )


class UserNotificationSetting(Base):
    __tablename__ = "user_notification_settings"

    user_id = Column(
        Integer, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True
    )
    enable_popups = Column(Boolean, default=True, nullable=False)
    notification_level = Column(String(50), default="all", nullable=False)

    user = relationship("User", back_populates="notification_setting")

    def __repr__(self):
        return f"<UserNotificationSetting(user_id={self.user_id}, popups={self.enable_popups}, level='{self.notification_level}')>"
