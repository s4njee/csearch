from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request, Response

router = APIRouter()


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

    return {
        "now": datetime.now(timezone.utc).isoformat(),
        "last_bill_action_at": bills["last_bill_action_at"],
        "last_bill_update_at": bills["last_bill_update_at"],
        "last_vote_at": votes["last_vote_at"],
        "bills_updated_24h": bills["bills_updated_24h"],
        "bills_total": bills["bills_total"],
        "votes_total": votes["votes_total"],
    }

