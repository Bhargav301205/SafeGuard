from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache

_ENV_FILE = Path(__file__).resolve().parent.parent.parent / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    database_url: str = "sqlite+aiosqlite:///./safeguard.db"

    # Google Maps / Places
    google_maps_api_key: str = ""

    # Twilio (optional — SMS/call via backend)
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""

    # Gmail SMTP (free — for emergency email alerts)
    gmail_sender: str = ""       # e.g. safeguard.demo@gmail.com
    gmail_app_password: str = "" # 16-char App Password from Google Account settings

    # Security
    api_key: str = "changeme-dev-key"

    # App
    app_name: str = "SafeGuard API"
    debug: bool = True
    cors_origins: list[str] = ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()


# Convenience singleton — import this directly in services
settings = get_settings()
