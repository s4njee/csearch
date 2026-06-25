from __future__ import annotations

import json
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from openai import AsyncOpenAI
from starlette.middleware.base import RequestResponseEndpoint
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from . import metrics
from .cache import Cache
from .db import Database
from .routes import bills_router, committees_router, explore_router, members_router, representatives_router, root_router, semantic_router, votes_router
from .settings import Settings, get_settings

logger = logging.getLogger("csearch-api")


# --- Logging ---

_LOG_RECORD_RESERVED = {
    "args", "asctime", "created", "exc_info", "exc_text", "filename", "funcName",
    "levelname", "levelno", "lineno", "message", "module", "msecs", "msg", "name",
    "pathname", "process", "processName", "relativeCreated", "stack_info",
    "taskName", "thread", "threadName",
}


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict = {"msg": record.getMessage(), "level": record.levelname.lower()}
        for key, value in record.__dict__.items():
            if key in _LOG_RECORD_RESERVED or key.startswith("_"):
                continue
            payload[key] = value
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def _install_logging() -> None:
    if logger.handlers:
        return
    handler = logging.StreamHandler()
    handler.setFormatter(_JsonFormatter())
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
    # A wildcard origin cannot be combined with credentials per the CORS spec,
    # and this is a public read API that needs no cookies, so credentials are
    # only enabled when the origin list is explicitly narrowed.
    cors_origins = resolved_settings.cors_origin_list()
    allow_credentials = cors_origins != ["*"]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=allow_credentials,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(GZipMiddleware, minimum_size=1000)

    @app.middleware("http")
    async def log_requests(request: Request, call_next: RequestResponseEndpoint):
        started = time.perf_counter()
        response = await call_next(request)
        duration = time.perf_counter() - started

        cache_header = getattr(request.state, "cache_header", None)
        if cache_header:
            response.headers["X-Cache"] = cache_header

        cache_header = response.headers.get("X-Cache", "NONE")
        # Use the matched route template (e.g. /bills/{billtype}/{congress}/...)
        # instead of the raw path so metric label cardinality stays bounded.
        matched_route = request.scope.get("route")
        route_label = getattr(matched_route, "path", None) or "unmatched"
        metrics.observe_request(route_label, request.method, response.status_code, duration, cache_header)
        logger.info(
            "request completed",
            extra={
                "responseTime": round(duration * 1000, 2),
                "statusCode": response.status_code,
                "cache": cache_header or "NONE",
                "clientIp": request.client.host if request.client else None,
                "route": request.url.path,
            },
        )
        return response

    async def _gauge(db, kind: str, query: str, setter) -> None:
        try:
            setter(kind, await db.fetchval(query))
        except Exception:
            # Optional signal (e.g. nlp/ops tables absent) — skip silently.
            pass

    @app.get("/metrics")
    async def prometheus_metrics(request: Request):
        # Refresh freshness/corpus gauges so staleness alerts have live data.
        db = getattr(request.app.state, "db", None)
        if db is not None and metrics.AVAILABLE:
            await _gauge(db, "bill_update", "SELECT extract(epoch FROM MAX(update_date)) FROM bills", metrics.set_freshness)
            await _gauge(db, "vote", "SELECT extract(epoch FROM MAX(votedate)) FROM votes", metrics.set_freshness)
            await _gauge(db, "nlp_run", "SELECT extract(epoch FROM MAX(finished_at)) FROM nlp.ingest_runs WHERE status = 'success'", metrics.set_freshness)
            await _gauge(db, "scraper_run", "SELECT extract(epoch FROM MAX(finished_at)) FROM ops.scraper_runs WHERE status = 'success'", metrics.set_freshness)
            await _gauge(db, "bills", "SELECT count(*) FROM bills", metrics.set_corpus)
            await _gauge(db, "semantic_chunks", "SELECT count(*) FROM nlp.bill_chunks", metrics.set_corpus)

        rendered = metrics.render()
        if rendered is None:
            return JSONResponse(status_code=501, content={"error": "Metrics not available: prometheus_client not installed"})
        payload, content_type = rendered
        return Response(content=payload, media_type=content_type)

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
    # Semantic routes use literal paths under /search/semantic/* and must be
    # registered before the bills catch-all GET /search/{table}/{filter}, which
    # would otherwise shadow GET /search/semantic/coverage.
    app.include_router(semantic_router)
    app.include_router(bills_router)
    app.include_router(votes_router)
    app.include_router(explore_router)
    app.include_router(members_router)
    app.include_router(committees_router)
    app.include_router(representatives_router)
    return app


app = create_app()
