from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, Text, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class FORoute(Base):
    __tablename__ = "fo_routes"

    routes_id = Column(Integer, primary_key=True, autoincrement=True)
    start_node_id = Column(Integer, ForeignKey("network_nodes.node_id"), nullable=False)
    end_node_id = Column(Integer, ForeignKey("network_nodes.node_id"), nullable=False)
    length_m = Column(Float)
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

    start_node = relationship(
        "NetworkNode", foreign_keys=[start_node_id], back_populates="outgoing_routes"
    )
    end_node = relationship(
        "NetworkNode", foreign_keys=[end_node_id], back_populates="incoming_routes"
    )

    def __repr__(self):
        return f"<FORoute(id={self.routes_id}, from_node={self.start_node_id} to_node={self.end_node_id}, length={self.length_m}m)>"
