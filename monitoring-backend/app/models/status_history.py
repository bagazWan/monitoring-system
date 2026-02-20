from sqlalchemy import Column, DateTime, Integer, String, func

from app.core.database import Base


class StatusHistory(Base):
    __tablename__ = "status_history"

    history_id = Column(Integer, primary_key=True, autoincrement=True)
    node_type = Column(String(32), nullable=False)
    node_id = Column(Integer, nullable=False)
    status = Column(String(32), nullable=False)
    changed_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    def __repr__(self):
        return (
            f"<StatusHistory(node_type='{self.node_type}', node_id={self.node_id}, "
            f"status='{self.status}', changed_at='{self.changed_at}')>"
        )
