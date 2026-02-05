from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class LibreNMSPort(Base):
    __tablename__ = "librenms_ports"

    id = Column(Integer, primary_key=True, autoincrement=True)

    device_id = Column(
        Integer,
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    switch_id = Column(
        Integer,
        ForeignKey("switches.switch_id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    librenms_device_id = Column(Integer, nullable=False, index=True)
    port_id = Column(Integer, nullable=False, index=True)
    if_name = Column(String(255), nullable=False)
    if_type = Column(String(255), nullable=True)
    if_oper_status = Column(String(64), nullable=True)
    enabled = Column(Boolean, nullable=False, server_default="0")
    is_uplink = Column(Boolean, nullable=False, server_default="0")
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    device = relationship("Device", back_populates="librenms_ports")
    switch = relationship("Switch", back_populates="librenms_ports")

    __table_args__ = (UniqueConstraint("port_id", name="uq_librenms_ports_port_id"),)

    def __repr__(self):
        owner = (
            f"device_id={self.device_id}"
            if self.device_id
            else f"switch_id={self.switch_id}"
        )
        return f"<LibreNMSPort({owner}, lnms_device_id={self.librenms_device_id}, port_id={self.port_id}, if={self.if_name}, enabled={self.enabled})>"
