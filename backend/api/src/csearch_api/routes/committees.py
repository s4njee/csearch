from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from csearch_api import queries
from csearch_api.cache import Cache
from csearch_api.db import Database
from csearch_api.deps import get_cache, get_db
from csearch_api.models import CommitteeDetail, CommitteeSummary

router = APIRouter()

COMMITTEE_BILLS_LIMIT = 100


@router.get("/committees", response_model=list[CommitteeSummary])
async def committees(request: Request, db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    """Return all committees with their bill counts, ordered by name."""
    cache_key = "committees_all"
    cached = await cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    rows = await db.read_fetch(
        """
        SELECT
            c.committee_code,
            c.committee_name,
            c.chamber,
            COUNT(*) AS bill_count
        FROM committees AS c
        JOIN bill_committees AS bc ON bc.committee_code = c.committee_code
        GROUP BY c.committee_code, c.committee_name, c.chamber
        ORDER BY c.committee_name ASC
        """
    )
    await cache.set(cache_key, rows)
    request.state.cache_header = "MISS"
    return rows


@router.get("/committees/{committee_code}", response_model=CommitteeDetail)
async def committee_detail(request: Request, committee_code: str, db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    """Return a committee's metadata and its most recently active bills."""
    cache_key = f"committee_{committee_code}"
    cached = await cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    committee = await db.read_fetchrow(
        """
        SELECT committee_code, committee_name, chamber
        FROM committees
        WHERE committee_code = $1
        LIMIT 1
        """,
        committee_code,
    )

    if not committee:
        raise HTTPException(status_code=404, detail={"error": "Committee not found"})

    bills = await db.read_fetch(
        f"""
        SELECT
            b.billid,
            b.billnumber::text AS billnumber,
            b.billtype,
            b.congress::text AS congress,
            b.shorttitle,
            b.officialtitle,
            b.introducedat,
            b.statusat,
            b.bill_status,
            b.summary_text,
            b.policy_area,
            b.latest_action_date,
            {queries.COSPONSOR_COUNT_SQL}
        FROM bill_committees AS bc
        JOIN bills AS b
          ON bc.billtype = b.billtype
         AND bc.billnumber = b.billnumber
         AND bc.congress = b.congress
        WHERE bc.committee_code = $1
        ORDER BY b.latest_action_date DESC NULLS LAST
        LIMIT {COMMITTEE_BILLS_LIMIT}
        """,
        committee_code,
    )

    committee["bills"] = bills
    await cache.set(cache_key, committee)
    request.state.cache_header = "MISS"
    return committee
