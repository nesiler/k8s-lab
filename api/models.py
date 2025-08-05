from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.sql import func
from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional

from database import Base

# SQLAlchemy Model
class Task(Base):
    """Task database model"""
    __tablename__ = "tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False, index=True)
    description = Column(Text, nullable=True)
    completed = Column(Boolean, default=False, index=True)
    priority = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

# Pydantic Models
class TaskBase(BaseModel):
    """Base task schema"""
    title: str
    description: Optional[str] = None
    completed: bool = False
    priority: int = 0

class TaskCreate(TaskBase):
    """Schema for creating tasks"""
    pass

class TaskUpdate(BaseModel):
    """Schema for updating tasks"""
    title: Optional[str] = None
    description: Optional[str] = None
    completed: Optional[bool] = None
    priority: Optional[int] = None

class TaskResponse(TaskBase):
    """Schema for task responses"""
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    model_config = ConfigDict(from_attributes=True)