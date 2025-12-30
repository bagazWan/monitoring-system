from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field
from pydantic.networks import EmailStr


class UserRegister(BaseModel):
    username: str = Field(..., min_length=1, max_length=255, description="User name")
    email: EmailStr
    password: str = Field(
        ..., min_length=6, max_length=100, description="User password"
    )
    full_name: str = Field(
        ..., min_length=1, max_length=255, description="User full name"
    )


# User create by admin
class UserCreate(BaseModel):
    username: str = Field(..., min_length=1, max_length=255, description="User name")
    email: EmailStr
    password: str = Field(
        ..., min_length=6, max_length=100, description="User password"
    )
    full_name: str = Field(
        ..., min_length=1, max_length=255, description="User full name"
    )
    role: str = Field(
        default="viewer", min_length=1, max_length=255, description="User role"
    )


# User update by admin
class UserUpdate(BaseModel):
    username: Optional[str] = Field(
        None, min_length=1, max_length=255, description="User name"
    )
    password: Optional[str] = Field(
        None, min_length=6, max_length=100, description="User password"
    )
    full_name: Optional[str] = Field(
        None, min_length=1, max_length=255, description="User full name"
    )
    role: Optional[str] = Field(None, description="User role")


# Updating own user profile
class UserUpdateSelf(BaseModel):
    username: Optional[str] = Field(None, min_length=1, max_length=255)
    full_name: Optional[str] = Field(None, min_length=1, max_length=255)
    email: Optional[EmailStr] = None


class UserChangePassword(BaseModel):
    old_password: str = Field(..., description="Current password for verification")
    new_password: str = Field(
        ..., min_length=6, max_length=100, description="New password"
    )
    confirm_password: str = Field(..., description="Confirm new password")


class UserResponse(BaseModel):
    user_id: int
    username: str
    full_name: str
    email: str
    role: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
