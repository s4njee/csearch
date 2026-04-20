from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from openai import AsyncOpenAI
from starlette.middleware.base import RequestResponseEndpoint
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from .cache import Cache
from .db import Database
from .routes import bills_router, committees_router, explore_router, members_router, root_router, semantic_router, votes_router
from .settings import Settings, get_settings

logger = logging.getLogger("csearch-api")


# --- Logging ---

def _install_logging() -> None:
    if logger.handlers:
        return
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False


# --- Lifespan (pool setup/teardown) ---

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings: Settings = app.state.settings
    db = app.state.db
    cache = app.state.cache
    created_db = False
    created_cache = False

    if db is None:
        db = await Database.connect(settings)
        app.state.db = db
        created_db = True

    if cache is None:
        cache = Cache.connect(settings.redis_url)
        app.state.cache = cache
        created_cache = True

    try:
        yield
    finally:
        if created_cache and cache is not None:
            await cache.close()
        if created_db and db is not None:
            await db.close()


def create_app(settings: Settings | None = None, db: Database | None = None, cache: Cache | None = None) -> FastAPI:
    _install_logging()
    app = FastAPI(lifespan=lifespan)
    resolved_settings = settings or get_settings()
    app.state.settings = resolved_settings
    app.state.db = db
    app.state.cache = cache
    app.state.openai_client = AsyncOpenAI(api_key=resolved_settings.openai_api_key) if resolved_settings.openai_api_key else None

    # --- Middleware ---

    app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
    app.add_middleware(GZipMiddleware, minimum_size=1000)

    @app.middleware("http")
    async def log_requests(request: Request, call_next: RequestResponseEndpoint):
        started = time.perf_counter()
        response = await call_next(request)

        cache_header = getattr(request.state, "cache_header", None)
        if cache_header:
            response.headers["X-Cache"] = cache_header

        cache_header = response.headers.get("X-Cache", "NONE")
        logger.info(
            {
                "responseTime": round((time.perf_counter() - started) * 1000, 2),
                "statusCode": response.status_code,
                "cache": cache_header or "NONE",
                "clientIp": request.client.host if request.client else None,
                "route": request.url.path,
            }
        )
        return response

    # --- Exception handlers ---

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException):
        content = exc.detail if isinstance(exc.detail, dict) else {"error": exc.detail}
        return JSONResponse(status_code=exc.status_code, content=content, headers=exc.headers or None)

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception(
            "request failed",
            extra={
                "route": request.url.path,
                "clientIp": request.client.host if request.client else None,
            },
        )
        return JSONResponse(status_code=500, content={"error": "Internal Server Error"})

    app.include_router(root_router)
    app.include_router(bills_router)
    app.include_router(votes_router)
    app.include_router(explore_router)
    app.include_router(members_router)
    app.include_router(committees_router)
    app.include_router(semantic_router)
    return app


app = create_app()
