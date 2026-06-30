from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..cache import Cache
from ..constants import VALID_BILL_TYPES
from ..db import Database
from ..deps import get_cache, get_db
from ..models import BillDetail, BillSummary
from ..queries import (
    BILL_COMMITTEE_CODES_SQL,
    BILL_DETAIL_ACTIONS_SQL,
    BILL_DETAIL_COMMITTEES_SQL,
    BILL_DETAIL_COSPONSORS_SQL,
    BILL_DETAIL_SQL,
    BILL_DETAIL_VOTES_SQL,
    BILL_FUZZY_SEARCH_EXPR,
    BILL_LIST_COLUMNS,
    COSPONSOR_COUNT_SQL,
    use_fuzzy_search,
)

router = APIRouter()

LATEST_BILLS_LIMIT = 500
SEARCH_RESULT_LIMIT = 30

# Edge can serve cached bill JSON for an hour, then revalidate in the background.
DETAIL_CACHE_CONTROL = "public, max-age=3600, stale-while-revalidate=86400"

# The latest-bills list changes once a day (scraper cron). `no-cache` lets the
# browser/edge store the response but forces a revalidation before every reuse,
# so a stale day-old copy is never served. Revalidations land on the api-cache
# Worker (edge), not the origin, so this stays cheap.
LIST_CACHE_CONTROL = "public, no-cache"


def _bill_list_select() -> str:
    return f"""
        SELECT
            {BILL_LIST_COLUMNS},
            {BILL_COMMITTEE_CODES_SQL},
            {COSPONSOR_COUNT_SQL}
        FROM bills AS b
    """


def _validate_billtype(billtype: str) -> None:
    if billtype != "all" and billtype not in VALID_BILL_TYPES:
        raise HTTPException(status_code=400, detail={"error": "Invalid bill type"})


# Optional, additive pagination. Defaults preserve the historical response
# (full first page), so existing clients are unaffected; limit is capped to
# bound payload size.
def _page(limit: int | None, offset: int | None, default_limit: int, max_limit: int) -> tuple[int, int]:
    resolved_limit = default_limit if limit is None else max(1, min(limit, max_limit))
    resolved_offset = max(0, offset or 0)
    return resolved_limit, resolved_offset


# date mode sorts by latest_action_date; relevance mode sorts by FTS rank.
def _search_order_clause(search_filter: str, fuzzy: bool) -> str:
    fuzzy_clause = f"similarity(lower({BILL_FUZZY_SEARCH_EXPR}), lower($3)) DESC," if fuzzy else ""

    if search_filter == "relevance":
        return f"""
            CASE WHEN b.search_document @@ websearch_to_tsquery('english', $2) THEN 1 ELSE 0 END DESC,
            ts_rank_cd(b.search_document, websearch_to_tsquery('english', $2)) DESC,
            {fuzzy_clause}
            b.statusat DESC NULLS LAST,
            b.billtype,
            b.billnumber
        """

    return f"""
        b.statusat DESC NULLS LAST,
        {fuzzy_clause}
        b.billtype,
        b.billnumber
    """


@router.get("/latest/{billtype}", response_model=list[BillSummary])
async def latest_bills(request: Request, response: Response, billtype: str, limit: int | None = None, offset: int | None = None, db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    """Return the most recently active bills of this type (default 500)."""
    _validate_billtype(billtype)
    response.headers["Cache-Control"] = LIST_CACHE_CONTROL
    resolved_limit, resolved_offset = _page(limit, offset, LATEST_BILLS_LIMIT, LATEST_BILLS_LIMIT)

    # Page params are part of the cache key so each page caches independently;
    # the default request keeps the original key shape and hit rate.
    cache_key = f"latest_bills_{billtype}_{resolved_limit}_{resolved_offset}"
    cached = await cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    sql = _bill_list_select()
    args = []
    if billtype != "all":
        sql += " WHERE b.billtype = $1"
        args.append(billtype)
    sql += f" ORDER BY b.latest_action_date DESC NULLS LAST, b.billid DESC LIMIT {resolved_limit} OFFSET {resolved_offset}"

    rows = await db.read_fetch(sql, *args)
    await cache.set(cache_key, rows)
    request.state.cache_header = "MISS"
    return rows


@router.get("/search/{table}/{filter}", response_model=list[BillSummary])
async def search_bills(table: str, filter: str, query: str | None = None, limit: int | None = None, offset: int | None = None, db: Database = Depends(get_db)):
    """Full-text and fuzzy search bills, ordered by relevance or date.

    Not Redis-cached: query text is high-cardinality so the hit rate would be
    low and Redis would bloat. Edge/CDN caching covers repeat queries.
    """
    _validate_billtype(table)
    resolved_limit, resolved_offset = _page(limit, offset, SEARCH_RESULT_LIMIT, LATEST_BILLS_LIMIT)

    search_query = (query or "").strip()
    if not search_query:
        raise HTTPException(status_code=400, detail={"error": "Missing required query parameter"})

    if filter not in {"relevance", "date"}:
        raise HTTPException(status_code=400, detail={"error": "Invalid filter; use 'relevance' or 'date'"})

    fuzzy = use_fuzzy_search(search_query)
    args = [table, search_query]

    where_sql = "($1 = 'all' OR b.billtype = $1) AND (b.search_document @@ websearch_to_tsquery('english', $2)"
    if fuzzy:
        args.append(search_query)
        where_sql += f" OR lower({BILL_FUZZY_SEARCH_EXPR}) % lower($3)"
    where_sql += ")"

    sql = f"""
        {_bill_list_select()}
        WHERE {where_sql}
    """

    order_sql = _search_order_clause(filter, fuzzy)

    sql += f" ORDER BY {order_sql} LIMIT {resolved_limit} OFFSET {resolved_offset}"
    rows = await db.read_fetch(sql, *args)
    return rows


@router.get("/bills/{billtype}/{congress}/{billnumber}", response_model=BillDetail)
async def bill_detail(response: Response, billtype: str, congress: str, billnumber: str, db: Database = Depends(get_db)):
    """Return a single bill with its actions, cosponsors, votes, and committees."""
    _validate_billtype(billtype)
    response.headers["Cache-Control"] = DETAIL_CACHE_CONTROL

    if not congress.isdigit():
        raise HTTPException(status_code=400, detail={"error": "Invalid congress; must be a number"})

    if not billnumber.isdigit():
        raise HTTPException(status_code=400, detail={"error": "Invalid bill number; must be a number"})

    congress_int = int(congress)
    billnumber_int = int(billnumber)

    bill_task = db.read_fetchrow(BILL_DETAIL_SQL, billtype, congress_int, billnumber_int)
    actions_task = db.read_fetch(BILL_DETAIL_ACTIONS_SQL, billtype, congress_int, billnumber_int)
    cosponsors_task = db.read_fetch(BILL_DETAIL_COSPONSORS_SQL, billtype, congress_int, billnumber_int)
    # NB: votes uses (billtype, billnumber, congress) bind order.
    votes_task = db.read_fetch(BILL_DETAIL_VOTES_SQL, billtype, billnumber_int, congress_int)
    committees_task = db.read_fetch(BILL_DETAIL_COMMITTEES_SQL, billtype, congress_int, billnumber_int)

    bill, actions, cosponsors, votes, committees = await asyncio.gather(
        bill_task,
        actions_task,
        cosponsors_task,
        votes_task,
        committees_task,
    )

    if not bill:
        raise HTTPException(status_code=404, detail={"error": "Bill not found"})

    bill["actions"] = actions
    bill["cosponsors"] = cosponsors
    bill["votes"] = votes
    bill["committees"] = committees
    return bill


@router.get("/bills/bynumber/{number}", response_model=list[BillSummary])
async def bills_by_number(request: Request, number: str, db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    """Return all bills matching a given bill number across all types and congresses."""
    if not number.isdigit():
        raise HTTPException(status_code=400, detail={"error": "Invalid bill number; must be an integer"})

    cache_key = f"bills_bynumber_{number}"
    cached = await cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    rows = await db.read_fetch(
        """
        SELECT
            b.billid,
            b.billtype,
            b.congress::text AS congress,
            b.billnumber::text AS billnumber,
            b.shorttitle,
            b.officialtitle,
            b.introducedat,
            b.latest_action_date,
            b.sponsor_name,
            b.sponsor_party,
            b.sponsor_state,
            b.policy_area,
            b.statusat,
            b.bill_status
        FROM bills AS b
        WHERE b.billnumber = $1
        ORDER BY b.latest_action_date DESC NULLS LAST, b.congress DESC
        """,
        int(number),
    )
    await cache.set(cache_key, rows)
    request.state.cache_header = "MISS"
    return rows
