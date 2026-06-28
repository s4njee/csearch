from __future__ import annotations

import json
import logging
import time
import uuid
from contextlib import asynccontextmanager
from typing import Any

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
from .models import ErrorResponse
from .routes import (
    bills_router,
    committees_router,
    explore_router,
    members_router,
    representatives_router,
    root_router,
    semantic_router,
    votes_router,
)
from .settings import Settings, get_settings

logger = logging.getLogger("csearch-api")

# How long the /metrics freshness/corpus gauges are cached between refreshes.
METRICS_GAUGE_TTL_SECONDS = 60

API_DESCRIPTION = (
    "Public read API for CSearch — U.S. Congress bills, votes, members, committees, "
    "representatives, prebuilt explore queries, and pgvector-backed hybrid semantic "
    "search.\n\n"
    "Open and CORS-enabled; no API key required. Endpoints are versioned under `/v1`. "
    "Semantic search is rate-limited per client IP. An MCP server that wraps this API "
    "for LLM agents lives in `backend/mcp`."
)

# Documented error shape, applied to every router so 4xx/5xx responses carry a
# consistent, typed body in the OpenAPI schema.
ERROR_RESPONSES: dict[int | str, dict[str, Any]] = {
    400: {"model": ErrorResponse, "description": "Invalid request"},
    404: {"model": ErrorResponse, "description": "Not found"},
    503: {"model": ErrorResponse, "description": "Service unavailable"},
}


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
    app = FastAPI(
        title="CSearch API",
        version="0.1.0",
        description=API_DESCRIPTION,
        servers=[{"url": "https://api.csearch.org", "description": "Production"}],
        contact={"name": "CSearch", "url": "https://csearch.org"},
        lifespan=lifespan,
        openapi_tags=[
            {"name": "meta", "description": "Root, health, and data-freshness checks."},
            {"name": "bills", "description": "Bill lists, search, and detail."},
            {"name": "votes", "description": "Roll-call vote lists, search, and detail."},
            {"name": "members", "description": "Member profiles."},
            {"name": "committees", "description": "Committees and referred bills."},
            {"name": "representatives", "description": "Representatives by ZIP code."},
            {"name": "explore", "description": "Prebuilt exploratory queries."},
            {"name": "semantic", "description": "pgvector semantic search + coverage."},
        ],
    )
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
        # Accept an inbound correlation id or mint one; echo it back and log it
        # so a request can be traced across the proxy, app, and aggregated logs.
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
        request.state.request_id = request_id
        response = await call_next(request)
        duration = time.perf_counter() - started

        response.headers["X-Request-ID"] = request_id

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
                "requestId": request_id,
            },
        )
        return response

    # Coarse per-IP rate limit, opt-in via GLOBAL_RATE_LIMIT_PER_MINUTE. When 0
    # (default) this is a no-op with zero overhead. Probe endpoints are exempt.
    _rate_limit_exempt = {"/health", "/livez", "/readyz", "/metrics"}

    @app.middleware("http")
    async def global_rate_limit(request: Request, call_next: RequestResponseEndpoint):
        limit = resolved_settings.global_rate_limit_per_minute
        if limit > 0 and request.url.path not in _rate_limit_exempt:
            cache = getattr(request.app.state, "cache", None)
            if cache is not None:
                client_ip = request.client.host if request.client else "unknown"
                allowed = await cache.rate_limit_allow(f"global:{client_ip}", limit, 60)
                if not allowed:
                    return JSONResponse(
                        status_code=429,
                        content={"error": "Rate limit exceeded"},
                        headers={"Retry-After": "60"},
                    )
        return await call_next(request)

    async def _gauge(db, kind: str, query: str, setter) -> None:
        try:
            setter(kind, await db.fetchval(query))
        except Exception:
            # Optional signal (e.g. nlp/ops tables absent) — skip silently.
            pass

    @app.get("/metrics")
    async def prometheus_metrics(request: Request):
        # Refresh freshness/corpus gauges so staleness alerts have live data.
        # These are COUNT(*)/MAX() aggregates, so they're throttled to at most
        # once per METRICS_GAUGE_TTL_SECONDS to avoid hammering the DB when
        # Prometheus scrapes frequently. Request counters/histograms always
        # reflect live data (they update per-request, not here).
        db = getattr(request.app.state, "db", None)
        now = time.monotonic()
        last_refresh = getattr(request.app.state, "_metrics_gauges_at", 0.0)
        if db is not None and metrics.AVAILABLE and (now - last_refresh) >= METRICS_GAUGE_TTL_SECONDS:
            request.app.state._metrics_gauges_at = now
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
                "requestId": getattr(request.state, "request_id", None),
            },
        )
        return JSONResponse(status_code=500, content={"error": "Internal Server Error"})

    # Meta / probe endpoints stay unversioned (k8s probes, monitoring).
    app.include_router(root_router, tags=["meta"], responses=ERROR_RESPONSES)

    # Data routers. Order matters: semantic uses literal paths under
    # /search/semantic/* and must register before the bills catch-all
    # GET /search/{table}/{filter}, which would otherwise shadow
    # GET /search/semantic/coverage.
    data_routers = [
        (semantic_router, "semantic"),
        (bills_router, "bills"),
        (votes_router, "votes"),
        (explore_router, "explore"),
        (members_router, "members"),
        (committees_router, "committees"),
        (representatives_router, "representatives"),
    ]

    # Versioned surface (documented): /v1/...
    for data_router, tag in data_routers:
        app.include_router(data_router, prefix="/v1", tags=[tag], responses=ERROR_RESPONSES)

    # Unversioned aliases kept for backward compatibility (existing clients use
    # these), hidden from the OpenAPI schema so /v1 is the documented contract.
    for data_router, tag in data_routers:
        app.include_router(data_router, tags=[tag], responses=ERROR_RESPONSES, include_in_schema=False)

    return app


app = create_app()
