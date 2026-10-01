from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from ..core.config import get_settings


class Base(DeclarativeBase):
    pass


from pathlib import Path


def _get_engine():
    settings = get_settings()
    db_url = settings.database_url
    if "sqlite" in db_url and "///." in db_url:
        db_path = (Path(__file__).resolve().parent.parent.parent / "safeguard.db").as_posix()
        db_url = f"sqlite+aiosqlite:///{db_path}"
    return create_async_engine(
        db_url,
        echo=settings.debug,
        connect_args={"check_same_thread": False} if "sqlite" in db_url else {},
    )


engine = _get_engine()

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    """Create all tables. Called on app startup."""
    from ..models import contact, incident, user  # noqa: F401
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
