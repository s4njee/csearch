from __future__ import annotations

import asyncio

from fastapi import APIRouter, HTTPException, Request

from ..constants import VALID_BILL_TYPES
from ..queries import (
    BILL_COMMITTEE_CODES_SQL,
    BILL_FUZZY_SEARCH_EXPR,
    BILL_LIST_COLUMNS,
    COSPONSOR_COUNT_SQL,
    use_fuzzy_search,
)

router = APIRouter()

LATEST_BILLS_LIMIT = 500
SEARCH_RESULT_LIMIT = 30


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


@router.get("/latest/{billtype}")
async def latest_bills(request: Request, billtype: str):
    """Return the 500 most recently active bills of this type."""
    _validate_billtype(billtype)

    cache_key = f"latest_bills_{billtype}"
    cached = await request.app.state.cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    sql = _bill_list_select()
    args = []
    if billtype != "all":
        sql += " WHERE b.billtype = $1"
        args.append(billtype)
    sql += f" ORDER BY b.latest_action_date DESC NULLS LAST, b.billid DESC LIMIT {LATEST_BILLS_LIMIT}"

    rows = await request.app.state.db.fetch(sql, *args)
    await request.app.state.cache.set(cache_key, rows)
    request.state.cache_header = "MISS"
    return rows


@router.get("/search/{table}/{filter}")
async def search_bills(request: Request, table: str, filter: str, query: str | None = None):
    """Full-text and fuzzy search bills, ordered by relevance or date."""
    _validate_billtype(table)

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

    sql += f" ORDER BY {order_sql} LIMIT {SEARCH_RESULT_LIMIT}"
    rows = await request.app.state.db.fetch(sql, *args)
    return rows


@router.get("/bills/{billtype}/{congress}/{billnumber}")
async def bill_detail(request: Request, billtype: str, congress: str, billnumber: str):
    """Return a single bill with its actions, cosponsors, votes, and committees."""
    _validate_billtype(billtype)

    if not congress.isdigit():
        raise HTTPException(status_code=400, detail={"error": "Invalid congress; must be a number"})

    if not billnumber.isdigit():
        raise HTTPException(status_code=400, detail={"error": "Invalid bill number; must be a number"})

    congress_int = int(congress)
    billnumber_int = int(billnumber)

    bill_task = request.app.state.db.fetchrow(
        """
        SELECT
            billid,
            billnumber::text AS billnumber,
            billtype,
            congress::text AS congress,
            shorttitle,
            officialtitle,
            introducedat,
            statusat,
            bill_status,
            summary_text,
            summary_date,
            sponsor_name,
            sponsor_party,
            sponsor_state,
            sponsor_bioguide_id,
            origin_chamber,
            policy_area,
            update_date,
            latest_action_date
        FROM bills
        WHERE billtype = $1 AND congress = $2 AND billnumber = $3
        """,
        billtype,
        congress_int,
        billnumber_int,
    )
    actions_task = request.app.state.db.fetch(
        """
        SELECT acted_at, action_text, action_type, action_code
        FROM bill_actions
        WHERE billtype = $1 AND congress = $2 AND billnumber = $3
        ORDER BY acted_at ASC
        """,
        billtype,
        congress_int,
        billnumber_int,
    )
    cosponsors_task = request.app.state.db.fetch(
        """
        SELECT bioguide_id, full_name, state, party, sponsorship_date, is_original_cosponsor
        FROM bill_cosponsors
        WHERE billtype = $1 AND congress = $2 AND billnumber = $3
        ORDER BY sponsorship_date ASC
        """,
        billtype,
        congress_int,
        billnumber_int,
    )
    votes_task = request.app.state.db.fetch(
        """
        SELECT voteid, congress, chamber, question, result, votedate, votetype
        FROM votes
        WHERE bill_type = $1 AND bill_number = $2 AND congress = $3
        ORDER BY votedate DESC
        """,
        billtype,
        billnumber_int,
        congress_int,
    )
    committees_task = request.app.state.db.fetch(
        """
        SELECT bc.committee_code, c.committee_name, c.chamber
        FROM bill_committees bc
        JOIN committees c ON bc.committee_code = c.committee_code
        WHERE bc.billtype = $1 AND bc.congress = $2 AND bc.billnumber = $3
        """,
        billtype,
        congress_int,
        billnumber_int,
    )

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


@router.get("/bills/bynumber/{number}")
async def bills_by_number(request: Request, number: str):
    """Return all bills matching a given bill number across all types and congresses."""
    if not number.isdigit():
        raise HTTPException(status_code=400, detail={"error": "Invalid bill number; must be an integer"})

    return await request.app.state.db.fetch(
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
