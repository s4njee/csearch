from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..cache import Cache
from ..constants import CHAMBER_ABBREV, MIN_FUZZY_QUERY_LENGTH
from ..db import Database
from ..deps import get_cache, get_db
from ..models import VoteDetail, VoteSummary

VOTE_FUZZY_SEARCH_EXPR = (
    "concat_ws(' ', coalesce(v.question, ''), coalesce(v.result, ''), "
    "coalesce(v.votetype, ''), coalesce(v.chamber, ''))"
)

router = APIRouter()

LATEST_VOTES_LIMIT = 60
VOTE_SEARCH_LIMIT = 20

# The latest-votes list changes once a day (scraper cron). `no-cache` lets the
# browser/edge store the response but forces a revalidation before every reuse,
# so a stale day-old copy is never served. Revalidations land on the api-cache
# Worker (edge), not the origin, so this stays cheap.
LIST_CACHE_CONTROL = "public, no-cache"


def _normalize_chamber(chamber: str | None) -> str | None:
    if chamber is None:
        return None
    return CHAMBER_ABBREV.get(str(chamber).lower())


def _build_vote_search_query(search_query: str, chamber: str | None, fuzzy: bool) -> tuple[str, list[str | None]]:
    where_sql = "($1::text IS NULL OR v.chamber = $1) AND (v.search_document @@ websearch_to_tsquery('english', $2)"
    bindings: list[str | None] = [chamber, search_query]
    if fuzzy:
        where_sql += f" OR lower({VOTE_FUZZY_SEARCH_EXPR}) % lower($3)"
        bindings.append(search_query)
    where_sql += ")"

    order_sql = [
        "CASE WHEN v.search_document @@ websearch_to_tsquery('english', $2) THEN 1 ELSE 0 END DESC",
        "ts_rank_cd(v.search_document, websearch_to_tsquery('english', $2)) DESC",
    ]
    if fuzzy:
        order_sql.append(f"similarity(lower({VOTE_FUZZY_SEARCH_EXPR}), lower($3)) DESC")
    order_sql.extend(["v.votedate DESC NULLS LAST", "v.voteid DESC"])

    sql = f"""
        SELECT
            v.voteid,
            v.congress::text AS congress,
            v.chamber,
            v.question,
            v.result,
            v.votedate,
            v.votetype
        FROM votes v
        WHERE {where_sql}
        ORDER BY {", ".join(order_sql)}
        LIMIT {VOTE_SEARCH_LIMIT}
    """
    return sql, bindings


@router.get("/votes/search", response_model=list[VoteSummary])
async def search_votes(query: str | None = None, chamber: str | None = None, db: Database = Depends(get_db)):
    """Full-text and fuzzy search votes, optionally filtered by chamber."""
    search_query = (query or "").strip()
    if not search_query:
        raise HTTPException(status_code=400, detail={"error": "Missing required query parameter"})

    normalized = _normalize_chamber(chamber)
    if chamber and not normalized:
        raise HTTPException(status_code=400, detail={"error": "Invalid chamber; use 'house' or 'senate'"})

    sql, bindings = _build_vote_search_query(search_query, normalized, len(search_query) >= MIN_FUZZY_QUERY_LENGTH)
    return await db.read_fetch(sql, *bindings)


@router.get("/votes/detail/{voteid}", response_model=VoteDetail)
async def vote_detail(voteid: str, db: Database = Depends(get_db)):
    """Return a single vote with its full member position breakdown."""
    vote = await db.read_fetchrow(
        """
        SELECT
            voteid,
            bill_type,
            bill_number::text AS bill_number,
            congress::text AS congress,
            votenumber::text AS votenumber,
            votedate,
            question,
            result,
            votesession,
            chamber,
            source_url,
            votetype
        FROM votes
        WHERE voteid = $1
        """,
        voteid,
    )

    if not vote:
        raise HTTPException(status_code=404, detail={"error": "Vote not found"})

    members = await db.read_fetch(
        """
        SELECT bioguide_id, display_name, party, state, position
        FROM vote_members
        WHERE voteid = $1
        ORDER BY display_name ASC
        """,
        voteid,
    )

    vote["members"] = members
    return vote


@router.get("/votes/{chamber}", response_model=list[VoteSummary])
async def latest_votes(request: Request, response: Response, chamber: str, limit: int | None = None, offset: int | None = None, db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    """Return the most recent votes for the given chamber (default 60)."""
    normalized = _normalize_chamber(chamber)
    if not normalized:
        raise HTTPException(status_code=400, detail={"error": "Invalid chamber; use 'house' or 'senate'"})
    response.headers["Cache-Control"] = LIST_CACHE_CONTROL

    # Optional, additive pagination; defaults preserve the historical response.
    resolved_limit = LATEST_VOTES_LIMIT if limit is None else max(1, min(limit, LATEST_VOTES_LIMIT))
    resolved_offset = max(0, offset or 0)

    cache_key = f"latest_votes_v2_{chamber}_{resolved_limit}_{resolved_offset}"
    cached = await cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    rows = await db.read_fetch(
        f"""
        SELECT
            v.congress::text AS congress,
            v.votenumber::text AS votenumber,
            v.votedate,
            v.question,
            v.votesession,
            v.result,
            v.chamber,
            v.votetype,
            v.voteid,
            v.source_url,
            COUNT(CASE WHEN vm.position = 'yea' THEN 1 END)::int AS yea,
            COUNT(CASE WHEN vm.position = 'nay' THEN 1 END)::int AS nay,
            COUNT(CASE WHEN vm.position = 'present' THEN 1 END)::int AS present,
            COUNT(CASE WHEN vm.position = 'notvoting' THEN 1 END)::int AS notvoting
        FROM votes v
        LEFT JOIN vote_members vm ON vm.voteid = v.voteid
        WHERE v.chamber = $1
        GROUP BY
            v.voteid, v.congress, v.votenumber, v.votedate, v.question,
            v.votesession, v.result, v.chamber, v.votetype, v.source_url
        ORDER BY v.votedate DESC
        LIMIT {resolved_limit} OFFSET {resolved_offset}
        """,
        normalized,
    )
    await cache.set(cache_key, rows)
    request.state.cache_header = "MISS"
    return rows
