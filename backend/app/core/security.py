from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader
from .config import get_settings

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def verify_api_key(key: str | None = Security(_api_key_header)) -> str:
    """
    Simple API-key auth for MVP.
    Pass the key in the X-API-Key header.
    Disabled when settings.debug is True — all requests pass through.
    """
    settings = get_settings()
    if settings.debug:
        return "dev"
    if key is None or key != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )
    return key
