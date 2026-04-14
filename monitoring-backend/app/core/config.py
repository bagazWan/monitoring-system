from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 600
    LIBRENMS_URL: str
    LIBRENMS_API_TOKEN: str
    LIBRENMS_ALERTS_ENABLED: bool = False
    POLL_INTERVAL: int = 5

    PING_PROBE_ENABLED: bool = False
    PING_PROBE_PATH: str = "fping"
    PING_PROBE_COUNT: int = 3
    PING_PROBE_TIMEOUT_MS: int = 1000
    PING_PROBE_CACHE_SECONDS: int = 10

    PORT_RESYNC_TTL_SECONDS: int = 300

    PROJECT_NAME: str = "Device Monitoring System"
    VERSION: str = "1.0"
    API_V1_VERSION: str = "/api/v1"

    BACKEND_CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8000"]

    class Config:
        env_file = ".env"


settings = Settings()
