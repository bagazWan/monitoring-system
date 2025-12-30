from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Text, func
from sqlalchemy.orm import relationship
from app.core.database import Base

class NetworkNode(Base):
    __tablename__ = "network_nodes"

    node_id = Column(Integer, primary_key=True, autoincrement=True)
    location_id = Column(Integer, ForeignKey("locations.location_id"), nullable=False)
    node_type = Column(String(255), nullable=False)
    description = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    location = relationship("Location", back_populates="network_nodes")
    outgoing_routes = relationship(
        "FORoute",
        foreign_keys="FORoute.start_node_id",
        back_populates="start_node"
    )
    incoming_routes = relationship(
        "FORoute",
        foreign_keys="FORoute.end_node_id",
        back_populates="end_node"
    )
    switches = relationship("Switch", back_populates="network_node")

    def __repr__(self):
        return f"<NetworkNode(id={self.node_id}, type='{self.node_type}')>"
