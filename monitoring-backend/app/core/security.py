from datetime import datetime, timedelta
from typing import Optional

import bcrypt
from authlib.jose import JoseError, jwt

from app.core.config import settings


def get_password_hash(password: str) -> str:
    salt = bcrypt.gensalt()
    password_hash = bcrypt.hashpw(password.encode("utf-8"), salt)
    return password_hash.decode("utf-8")


def verify_password(password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), hashed_password.encode("utf-8"))


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )

    to_encode.update({"exp": expire})

    # Encode JWT token
    header = {"alg": settings.ALGORITHM}
    encoded_jwt = jwt.encode(header, to_encode, settings.SECRET_KEY)

    return encoded_jwt.decode("utf-8")


def decode_access_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY)
        payload.validate()  # Validate expiration
        return payload
    except JoseError:
        return None
    except Exception:
        return None
