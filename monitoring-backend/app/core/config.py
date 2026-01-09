from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 600
    LIBRENMS_URL: str
    LIBRENMS_API_TOKEN: str
    ALERT_POLL_INTERVAL: int = 30

    PROJECT_NAME: str = "Device Monitoring System"
    VERSION: str = "1.0"
    API_V1_VERSION: str = "/api/v1"

    BACKEND_CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8000"]

    class Config:
        env_file = ".env"


settings = Settings()
