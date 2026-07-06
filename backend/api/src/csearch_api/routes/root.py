from __future__ import annotations

import logging
from datetime import UTC, date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response

from ..cache import Cache
from ..db import Database
from ..deps import get_app_settings, get_cache, get_db
from ..models import CacheVersionResponse, FreshnessResponse, HealthResponse, RootResponse
from ..settings import Settings

logger = logging.getLogger("csearch-api")

router = APIRouter()


async def _safe_read_fetchrow(db: Database, query: str):
    """Run an optional diagnostic query, returning None if it fails.

    The semantic/ops tables may be absent in local or partially migrated
    databases. Freshness must still answer for core data, so missing-schema
    errors degrade to nulls rather than 500s.
    """
    try:
        return await db.read_fetchrow(query)
    except Exception as e:
        logger.warning("freshness probe failed: %s", e)
        return None


def _max_version(*values):
    """Return the newest non-null date-ish value without assuming matching types."""
    present = [value for value in values if value is not None]
    if not present:
        return None
    return max(present, key=_version_sort_key)


def _version_sort_key(value) -> str:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def _has_any_version(row: dict | None) -> bool:
    return bool(row and any(value is not None for value in row.values()))


async def _ops_versions(db: Database) -> dict | None:
    row = await _safe_read_fetchrow(
        db,
        """
        SELECT
            MAX(version) FILTER (WHERE domain = 'bill_updates') AS bill_updates_version,
            MAX(version) FILTER (WHERE domain = 'bill_actions') AS bill_actions_version,
            MAX(version) FILTER (WHERE domain = 'bills') AS bills_version,
            MAX(version) FILTER (WHERE domain = 'votes') AS votes_version,
            MAX(version) FILTER (WHERE domain = 'explore') AS explore_version,
            MAX(version) FILTER (WHERE domain = 'semantic') AS semantic_version
        FROM ops.data_versions
        WHERE domain IN ('bill_updates', 'bill_actions', 'bills', 'votes', 'explore', 'semantic')
        """,
    )
    return row if _has_any_version(row) else None


async def _indexed_versions(db: Database, include_semantic: bool = True) -> dict:
    core = await db.read_fetchrow(
        """
        SELECT
            (
                SELECT update_date
                FROM bills
                WHERE update_date IS NOT NULL
                ORDER BY update_date DESC NULLS LAST
                LIMIT 1
            ) AS bill_updates_version,
            (
                SELECT latest_action_date
                FROM bills
                WHERE latest_action_date IS NOT NULL
                ORDER BY latest_action_date DESC NULLS LAST
                LIMIT 1
            ) AS bill_actions_version,
            (
                SELECT votedate
                FROM votes
                WHERE votedate IS NOT NULL
                ORDER BY votedate DESC NULLS LAST
                LIMIT 1
            ) AS votes_version
        """
    )
    semantic = None
    if include_semantic:
        semantic = await _safe_read_fetchrow(
            db,
            """
            SELECT created_at AS semantic_version
            FROM nlp.bill_chunks
            WHERE created_at IS NOT NULL
            ORDER BY created_at DESC NULLS LAST
            LIMIT 1
            """,
        )

    bill_updates_version = core["bill_updates_version"] if core else None
    bill_actions_version = core["bill_actions_version"] if core else None
    bills_version = _max_version(bill_updates_version, bill_actions_version)
    votes_version = core["votes_version"] if core else None
    semantic_version = semantic["semantic_version"] if semantic else None

    return {
        "bill_updates_version": bill_updates_version,
        "bill_actions_version": bill_actions_version,
        "bills_version": bills_version,
        "votes_version": votes_version,
        "explore_version": _max_version(bills_version, votes_version),
        "semantic_version": semantic_version,
    }


async def _cache_versions(db: Database, include_semantic: bool = True) -> dict:
    return await _ops_versions(db) or await _indexed_versions(db, include_semantic=include_semantic)


async def _last_refreshed_at(db: Database):
    """When the refresh pipeline last ran, from ops.data_versions.refreshed_at.

    This is the "data was checked today" signal, distinct from the content
    version dates: it advances whenever the scraper runs, even on quiet days.
    Degrades to null when the ops schema is absent (local/partial DBs).
    """
    row = await _safe_read_fetchrow(
        db,
        "SELECT MAX(refreshed_at) AS last_refreshed_at FROM ops.data_versions",
    )
    return row["last_refreshed_at"] if row else None


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
    """Flush Redis helper caches.

    Guarded by the ``X-Admin-Token`` header; returns 503 when ``ADMIN_TOKEN`` is
    unset (the default), so the endpoint is inert unless explicitly enabled.
    Public GET freshness is owned by the Cloudflare API cache Worker and the
    ``/cache-version`` contract, not this Redis reset hook.
    """
    token = settings.admin_token
    if not token:
        raise HTTPException(status_code=503, detail={"error": "Cache reset disabled: ADMIN_TOKEN not set"})
    if request.headers.get("X-Admin-Token") != token:
        raise HTTPException(status_code=403, detail={"error": "Forbidden"})
    await cache.reset()
    return {"reset": True}


@router.get("/cache-version", response_model=CacheVersionResponse)
async def cache_version(response: Response, db: Database = Depends(get_db)):
    """Compact data versions for the Cloudflare API cache Worker.

    Versions are derived from Postgres, the source of truth, so public edge
    cache invalidation does not depend on in-cluster Redis state.
    """
    response.headers["Cache-Control"] = "no-store"
    versions = await _cache_versions(db)

    return {
        "now": datetime.now(UTC).isoformat(),
        "bills_version": versions["bills_version"],
        "votes_version": versions["votes_version"],
        "explore_version": versions["explore_version"],
        "semantic_version": versions["semantic_version"],
    }


@router.get("/freshness", response_model=FreshnessResponse)
async def freshness(
    response: Response,
    detail: bool = Query(False, description="Include expensive exact corpus counts."),
    db: Database = Depends(get_db),
):
    """Drift signals for monitoring scrape → user pipeline. Always uncached.

    The default response is intentionally cheap for page chrome. Use
    ``?detail=true`` for exact counts and NLP pipeline diagnostics.
    """
    response.headers["Cache-Control"] = "no-store"

    versions = await _cache_versions(db, include_semantic=detail)
    last_refreshed_at = await _last_refreshed_at(db)

    if not detail:
        return {
            "now": datetime.now(UTC).isoformat(),
            "last_refreshed_at": last_refreshed_at,
            "last_bill_action_at": versions["bill_actions_version"],
            "last_bill_update_at": versions["bill_updates_version"] or versions["bills_version"],
            "last_vote_at": versions["votes_version"],
        }

    bills = await db.read_fetchrow(
        """
        SELECT
            COUNT(*) FILTER (WHERE update_date >= now() - interval '24 hours') AS bills_updated_24h,
            COUNT(*) AS bills_total
        FROM bills
        """
    )
    votes = await db.read_fetchrow("SELECT COUNT(*) AS votes_total FROM votes")

    # Semantic/vector coverage. Optional: null when the nlp schema is absent.
    chunks = await _safe_read_fetchrow(
        db,
        """
        SELECT
            COUNT(*) AS semantic_chunks_total,
            COUNT(DISTINCT bill_id) AS semantic_bills_total
        FROM nlp.bill_chunks
        """,
    )
    # Last pipeline run from the ingest audit table (see migration 0004).
    last_run = await _safe_read_fetchrow(
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
        "last_refreshed_at": last_refreshed_at,
        "last_bill_action_at": versions["bill_actions_version"],
        "last_bill_update_at": versions["bill_updates_version"] or versions["bills_version"],
        "last_vote_at": versions["votes_version"],
        "bills_updated_24h": bills["bills_updated_24h"],
        "bills_total": bills["bills_total"],
        "votes_total": votes["votes_total"],
        "last_semantic_chunk_at": versions["semantic_version"],
        "semantic_chunks_total": chunks["semantic_chunks_total"] if chunks else None,
        "semantic_bills_total": chunks["semantic_bills_total"] if chunks else None,
        "last_nlp_run_started_at": last_run["started_at"] if last_run else None,
        "last_nlp_run_finished_at": last_run["finished_at"] if last_run else None,
        "last_nlp_run_status": last_run["status"] if last_run else None,
        "last_nlp_run_upserted_chunks": last_run["upserted_chunk_count"] if last_run else None,
    }
