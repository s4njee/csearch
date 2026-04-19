from __future__ import annotations

import asyncio

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from csearch_api import queries

router = APIRouter()

DEFAULT_RESULT_LIMIT = 50
MAX_RESULT_LIMIT = 500
MIN_CANDIDATE_LIMIT = 500
MAX_CANDIDATE_LIMIT = 2000
CANDIDATE_MULTIPLIER = 10
SEMANTIC_DB_TIMEOUT_SECONDS = 10.0
SEMANTIC_HNSW_EF_SEARCH = 500
SEMANTIC_WARMUP_QUERY = "bills about climate"
SEMANTIC_WARMUP_RESULT_LIMIT = 1

_warmup_vector_str: str | None = None
_warmup_vector_lock = asyncio.Lock()

# top_k scans only nlp.bill_embeddings with no joins or filters so the
# HNSW index is used. Joining and congress filtering happen afterwards on
# the small result set.
_SEARCH_SQL = f"""
    WITH top_k AS (
        SELECT chunk_id, 1 - (embedding <=> $1::vector) AS similarity
        FROM nlp.bill_embeddings
        ORDER BY embedding <=> $1::vector
        LIMIT $4
    ),
    ranked AS (
        SELECT DISTINCT ON (c.bill_id)
            c.bill_id,
            c.congress,
            c.bill_type,
            c.bill_number,
            c.title,
            c.status,
            c.body,
            c.chunk_type,
            c.section_header,
            tk.similarity
        FROM top_k tk
        JOIN nlp.bill_chunks c ON c.id = tk.chunk_id
        WHERE c.congress BETWEEN $2 AND $3
        ORDER BY c.bill_id, tk.similarity DESC
    )
    SELECT
        r.bill_id AS bill_id,
        r.bill_type AS bill_type,
        r.bill_number AS bill_number,
        r.title AS title,
        r.status AS status,
        r.body AS body,
        r.chunk_type AS chunk_type,
        r.section_header AS section_header,
        b.billid,
        b.shorttitle,
        b.officialtitle,
        b.introducedat,
        b.summary_text,
        b.billtype,
        b.congress::text AS congress,
        b.billnumber::text AS billnumber,
        b.sponsor_name,
        b.sponsor_party,
        b.sponsor_state,
        b.sponsor_bioguide_id,
        b.bill_status,
        b.statusat,
        b.policy_area,
        b.latest_action_date,
        b.origin_chamber,
        {queries.BILL_COMMITTEE_CODES_SQL},
        {queries.COSPONSOR_COUNT_SQL},
        r.similarity
    FROM ranked r
    LEFT JOIN public.bills b
      ON b.billtype = r.bill_type
     AND b.billnumber::text = r.bill_number
     AND b.congress = r.congress
    ORDER BY r.similarity DESC
    LIMIT $5
"""


class SemanticSearchRequest(BaseModel):
    query: str
    congress_min: int | None = None
    congress_max: int | None = None
    limit: int | None = Field(default=None, ge=1, le=MAX_RESULT_LIMIT)


def _normalize_limit(limit: int | None) -> int:
    if limit is None:
        return DEFAULT_RESULT_LIMIT
    return min(limit, MAX_RESULT_LIMIT)


def _candidate_limit(result_limit: int) -> int:
    return min(
        max(MIN_CANDIDATE_LIMIT, result_limit * CANDIDATE_MULTIPLIER),
        MAX_CANDIDATE_LIMIT,
    )


async def _embed_query(request: Request, query: str) -> str:
    resp = await request.app.state.openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=[query],
        dimensions=1536,
    )
    vector = resp.data[0].embedding
    return "[" + ",".join(f"{v:.17g}" for v in vector) + "]"


async def _warmup_vector(request: Request) -> tuple[str, bool]:
    global _warmup_vector_str

    if _warmup_vector_str is not None:
        return _warmup_vector_str, True

    async with _warmup_vector_lock:
        if _warmup_vector_str is None:
            _warmup_vector_str = await _embed_query(request, SEMANTIC_WARMUP_QUERY)
            return _warmup_vector_str, False

    return _warmup_vector_str, True


async def _semantic_rows(
    request: Request,
    vector_str: str,
    congress_min: int,
    congress_max: int,
    result_limit: int,
):
    candidate_limit = _candidate_limit(result_limit)
    return await request.app.state.db.fetch(
        _SEARCH_SQL,
        vector_str,
        congress_min,
        congress_max,
        candidate_limit,
        result_limit,
        timeout=SEMANTIC_DB_TIMEOUT_SECONDS,
        hnsw_ef_search=SEMANTIC_HNSW_EF_SEARCH,
    )


def _require_semantic_configured(request: Request) -> None:
    settings = request.app.state.settings
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail={"error": "Semantic search not configured: OPENAI_API_KEY not set"})


@router.post("/search/semantic")
async def semantic_search(request: Request, body: SemanticSearchRequest):
    _require_semantic_configured(request)

    query = body.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail={"error": "Missing required query"})

    vector_str = await _embed_query(request, query)
    congress_min = body.congress_min if body.congress_min is not None else 0
    congress_max = body.congress_max if body.congress_max is not None else 999
    result_limit = _normalize_limit(body.limit)

    return await _semantic_rows(
        request,
        vector_str,
        congress_min,
        congress_max,
        result_limit,
    )


@router.post("/search/semantic/warmup")
async def semantic_search_warmup(request: Request):
    _require_semantic_configured(request)

    vector_str, cache_hit = await _warmup_vector(request)
    rows = await _semantic_rows(
        request,
        vector_str,
        0,
        999,
        SEMANTIC_WARMUP_RESULT_LIMIT,
    )

    return {
        "ok": True,
        "cache_hit": cache_hit,
        "query": SEMANTIC_WARMUP_QUERY,
        "rows": len(rows),
    }
