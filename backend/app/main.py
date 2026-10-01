from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .core.config import get_settings
from .db.database import init_db
from .api import incidents, contacts, services, user


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: initialise database tables."""
    await init_db()
    yield


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        description=(
            "SafeGuard backend API — logs accident incidents, manages emergency "
            "contacts, and proxies Google Places for nearest-services lookup."
        ),
        docs_url="/docs",
        redoc_url="/redoc",
        lifespan=lifespan,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Routers
    app.include_router(incidents.router)
    app.include_router(contacts.router)
    app.include_router(services.router)
    app.include_router(user.router)

    @app.get("/health", tags=["meta"])
    async def health_check():
        return {"status": "ok", "service": settings.app_name}

    return app


app = create_app()
