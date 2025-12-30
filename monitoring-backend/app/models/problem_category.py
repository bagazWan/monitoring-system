from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.orm import relationship
from app.core.database import Base

class ProblemCategory(Base):
    __tablename__ = "problem_categories"

    category_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)

    device_alerts = relationship("Alert", back_populates="category")
    switch_alerts = relationship("SwitchAlert", back_populates="category")

    def __repr__(self):
        return f"<ProblemCategory(id={self.category_id}, name='{self.name}')>"
