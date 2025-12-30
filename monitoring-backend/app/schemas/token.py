"""
Schemas for authentication tokens
"""

from typing import Optional

from pydantic import BaseModel


class Token(BaseModel):
    """Response when user logs in"""

    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Data stored in JWT token"""

    username: Optional[str] = None
