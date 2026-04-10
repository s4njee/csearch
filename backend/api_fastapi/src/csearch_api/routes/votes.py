from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from ..constants import CHAMBER_ABBREV, MIN_FUZZY_QUERY_LENGTH

VOTE_FUZZY_SEARCH_EXPR = (
    "concat_ws(' ', coalesce(v.question, ''), coalesce(v.result, ''), "
    "coalesce(v.votetype, ''), coalesce(v.chamber, ''))"
)

router = APIRouter()


def _normalize_chamber(chamber: str | None) -> str | None:
    if chamber is None:
        return None
    return CHAMBER_ABBREV.get(str(chamber).lower())


def _build_vote_search_query(search_query: str, chamber: str | None, fuzzy: bool) -> tuple[str, list[str]]:
    where_sql = "($1 IS NULL OR v.chamber = $1) AND (v.search_document @@ websearch_to_tsquery('english', $2)"
    bindings: list[str] = [chamber, search_query]
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
        LIMIT 20
    """
    return sql, bindings


@router.get("/votes/{chamber}")
async def latest_votes(request: Request, chamber: str):
    normalized = _normalize_chamber(chamber)
    if not normalized:
        raise HTTPException(status_code=400, detail={"error": "Invalid chamber; use 'house' or 'senate'"})

    cache_key = f"latest_votes_{chamber}"
    cached = await request.app.state.cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    rows = await request.app.state.db.fetch(
        """
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
        WHERE v.votedate::date BETWEEN current_date - 90 AND current_date
          AND v.chamber = $1
        GROUP BY
            v.voteid, v.congress, v.votenumber, v.votedate, v.question,
            v.votesession, v.result, v.chamber, v.votetype, v.source_url
        ORDER BY v.votedate DESC
        LIMIT 60
        """,
        normalized,
    )
    await request.app.state.cache.set(cache_key, rows)
    request.state.cache_header = "MISS"
    return rows


@router.get("/votes/search")
async def search_votes(request: Request, query: str | None = None, chamber: str | None = None):
    search_query = (query or "").strip()
    if not search_query:
        raise HTTPException(status_code=400, detail={"error": "Missing required query parameter"})

    normalized = _normalize_chamber(chamber)
    if chamber and not normalized:
        raise HTTPException(status_code=400, detail={"error": "Invalid chamber; use 'house' or 'senate'"})

    sql, bindings = _build_vote_search_query(search_query, normalized, len(search_query) >= MIN_FUZZY_QUERY_LENGTH)
    return await request.app.state.db.fetch(sql, *bindings)


@router.get("/votes/detail/{voteid}")
async def vote_detail(request: Request, voteid: str):
    vote = await request.app.state.db.fetchrow(
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

    members = await request.app.state.db.fetch(
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

