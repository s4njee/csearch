from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..cache import Cache
from ..db import Database
from ..deps import get_app_settings, get_cache, get_db
from ..models import FreshnessResponse, HealthResponse, RootResponse
from ..settings import Settings

logger = logging.getLogger("csearch-api")

router = APIRouter()


async def _safe_fetchrow(db: Database, query: str):
    """Run an optional diagnostic query, returning None if it fails.

    The semantic/ingest tables live in the ``nlp`` schema, which may be absent
    in a bills-only or local database. Freshness must still answer for the
    core data, so missing-schema errors degrade to nulls rather than 500s.
    """
    try:
        return await db.fetchrow(query)
    except Exception as e:
        logger.warning("freshness probe failed: %s", e)
        return None


@router.get("/", response_model=RootResponse)
async def root():
    return {"root": True}


@router.get("/health", response_model=HealthResponse)
async def health(db: Database = Depends(get_db)):
    """DB connectivity check (kept for back-compat; see /livez and /readyz)."""
    try:
        await db.fetchval("SELECT 1")
        return {"status": "ok", "db": "connected"}
    except Exception:
        raise HTTPException(status_code=503, detail={"status": "error", "db": "disconnected"}) from None


@router.get("/livez")
async def livez():
    """Liveness: the process is up. No dependencies are probed."""
    return {"status": "ok"}


@router.get("/readyz")
async def readyz(db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    """Readiness: the app can serve traffic (DB + Redis reachable)."""
    db_ok = True
    try:
        await db.fetchval("SELECT 1")
    except Exception:
        db_ok = False

    cache_ok = await cache.ping() if cache is not None else False

    status = {
        "status": "ok" if (db_ok and cache_ok) else "error",
        "db": "connected" if db_ok else "disconnected",
        "cache": "connected" if cache_ok else "disconnected",
    }
    if not (db_ok and cache_ok):
        raise HTTPException(status_code=503, detail=status)
    return status


@router.post("/admin/cache/reset")
async def reset_cache(request: Request, cache: Cache = Depends(get_cache), settings: Settings = Depends(get_app_settings)):
    """Flush the Redis cache (invalidation hook for the scrape→serve pipeline).

    Guarded by the ``X-Admin-Token`` header; returns 503 when ``ADMIN_TOKEN`` is
    unset (the default), so the endpoint is inert unless explicitly enabled.
    Intended to be called after an ingest so cached lists reflect new data
    without waiting for the TTL.
    """
    token = settings.admin_token
    if not token:
        raise HTTPException(status_code=503, detail={"error": "Cache reset disabled: ADMIN_TOKEN not set"})
    if request.headers.get("X-Admin-Token") != token:
        raise HTTPException(status_code=403, detail={"error": "Forbidden"})
    await cache.reset()
    return {"reset": True}


@router.get("/freshness", response_model=FreshnessResponse)
async def freshness(response: Response, db: Database = Depends(get_db)):
    """Drift signals for monitoring scrape → user pipeline. Always uncached."""
    response.headers["Cache-Control"] = "no-store"

    bills = await db.fetchrow(
        """
        SELECT
            MAX(latest_action_date) AS last_bill_action_at,
            MAX(update_date) AS last_bill_update_at,
            COUNT(*) FILTER (WHERE update_date >= now() - interval '24 hours') AS bills_updated_24h,
            COUNT(*) AS bills_total
        FROM bills
        """
    )
    votes = await db.fetchrow(
        "SELECT MAX(votedate) AS last_vote_at, COUNT(*) AS votes_total FROM votes"
    )

    # Semantic/vector coverage. Optional: null when the nlp schema is absent.
    chunks = await _safe_fetchrow(
        db,
        """
        SELECT
            MAX(created_at) AS last_semantic_chunk_at,
            COUNT(*) AS semantic_chunks_total,
            COUNT(DISTINCT bill_id) AS semantic_bills_total
        FROM nlp.bill_chunks
        """,
    )
    # Last pipeline run from the ingest audit table (see migration 0004).
    last_run = await _safe_fetchrow(
        db,
        """
        SELECT started_at, finished_at, status, upserted_chunk_count
        FROM nlp.ingest_runs
        ORDER BY started_at DESC
        LIMIT 1
        """,
    )

    return {
        "now": datetime.now(UTC).isoformat(),
        "last_bill_action_at": bills["last_bill_action_at"],
        "last_bill_update_at": bills["last_bill_update_at"],
        "last_vote_at": votes["last_vote_at"],
        "bills_updated_24h": bills["bills_updated_24h"],
        "bills_total": bills["bills_total"],
        "votes_total": votes["votes_total"],
        "last_semantic_chunk_at": chunks["last_semantic_chunk_at"] if chunks else None,
        "semantic_chunks_total": chunks["semantic_chunks_total"] if chunks else None,
        "semantic_bills_total": chunks["semantic_bills_total"] if chunks else None,
        "last_nlp_run_started_at": last_run["started_at"] if last_run else None,
        "last_nlp_run_finished_at": last_run["finished_at"] if last_run else None,
        "last_nlp_run_status": last_run["status"] if last_run else None,
        "last_nlp_run_upserted_chunks": last_run["upserted_chunk_count"] if last_run else None,
    }

