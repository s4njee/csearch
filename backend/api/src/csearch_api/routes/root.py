from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request, Response

logger = logging.getLogger("csearch-api")

router = APIRouter()


async def _safe_fetchrow(request: Request, query: str):
    """Run an optional diagnostic query, returning None if it fails.

    The semantic/ingest tables live in the ``nlp`` schema, which may be absent
    in a bills-only or local database. Freshness must still answer for the
    core data, so missing-schema errors degrade to nulls rather than 500s.
    """
    try:
        return await request.app.state.db.fetchrow(query)
    except Exception as e:
        logger.warning("freshness probe failed: %s", e)
        return None


@router.get("/")
async def root():
    return {"root": True}


@router.get("/health")
async def health(request: Request):
    try:
        await request.app.state.db.fetchval("SELECT 1")
        return {"status": "ok", "db": "connected"}
    except Exception:
        raise HTTPException(status_code=503, detail={"status": "error", "db": "disconnected"})


@router.get("/freshness")
async def freshness(request: Request, response: Response):
    """Drift signals for monitoring scrape → user pipeline. Always uncached."""
    response.headers["Cache-Control"] = "no-store"

    bills = await request.app.state.db.fetchrow(
        """
        SELECT
            MAX(latest_action_date) AS last_bill_action_at,
            MAX(update_date) AS last_bill_update_at,
            COUNT(*) FILTER (WHERE update_date >= now() - interval '24 hours') AS bills_updated_24h,
            COUNT(*) AS bills_total
        FROM bills
        """
    )
    votes = await request.app.state.db.fetchrow(
        "SELECT MAX(votedate) AS last_vote_at, COUNT(*) AS votes_total FROM votes"
    )

    # Semantic/vector coverage. Optional: null when the nlp schema is absent.
    chunks = await _safe_fetchrow(
        request,
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
        request,
        """
        SELECT started_at, finished_at, status, upserted_chunk_count
        FROM nlp.ingest_runs
        ORDER BY started_at DESC
        LIMIT 1
        """,
    )

    return {
        "now": datetime.now(timezone.utc).isoformat(),
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

