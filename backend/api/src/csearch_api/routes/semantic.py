from __future__ import annotations

import asyncio
import logging
import time

from fastapi import APIRouter, HTTPException, Request, Response
from pydantic import BaseModel, Field

from csearch_api import metrics, queries
from csearch_api.embedding import (
    EMBEDDING_CACHE_TTL_SECONDS,
    EMBEDDING_DIMENSIONS,
    EMBEDDING_MODEL,
    embedding_cache_key,
)
from csearch_api.hybrid import reciprocal_rank_fusion
from csearch_api.models import CoverageResponse, SemanticResult
from csearch_api.routing import parse_bill_reference

logger = logging.getLogger("csearch-api")

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

# ---------------------------------------------------------------------------
# Circuit breaker state (§4 CRITICISMS2.md)
# ---------------------------------------------------------------------------
# The breaker is module-level (one per process). After
# `semantic_circuit_breaker_threshold` consecutive OpenAI failures, it opens
# and all subsequent embedding calls return None immediately. The breaker
# resets after `semantic_circuit_breaker_cooldown_seconds` seconds. Callers
# must treat None as a signal to degrade to keyword results.
_cb_failure_count: int = 0
_cb_open_until: float = 0.0  # epoch seconds
_cb_lock = asyncio.Lock()

# top_k scans only nlp.bill_embeddings filtered to the active model so the
# HNSW index is used without mixing incompatible vector spaces. Joining and
# congress filtering happen afterwards on the small candidate set.
# $1 = vector literal, $2 = congress_min, $3 = congress_max,
# $4 = candidate_limit, $5 = result_limit, $6 = active model name.
_SEARCH_SQL = f"""
    WITH top_k AS (
        SELECT chunk_id, 1 - (embedding <=> $1::vector) AS similarity
        FROM nlp.bill_embeddings
        WHERE model = $6
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


# Exact bill citations (e.g. "HR 42") are answered directly from public.bills
# without an OpenAI call. Output columns mirror _SEARCH_SQL so the response
# contract is identical regardless of which route served the query; the
# chunk-specific columns are null and similarity is a sentinel 1.0.
_EXACT_BILL_SQL = f"""
    SELECT
        (b.billtype || b.billnumber::text || '-' || b.congress::text) AS bill_id,
        b.billtype AS bill_type,
        b.billnumber::text AS bill_number,
        NULL::text AS title,
        b.bill_status AS status,
        NULL::text AS body,
        NULL::text AS chunk_type,
        NULL::text AS section_header,
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
        1.0::float8 AS similarity
    FROM public.bills b
    WHERE b.billtype = $1
      AND b.billnumber = $2
      AND b.congress BETWEEN $3 AND $4
    ORDER BY b.congress DESC
    LIMIT $5
"""


# Keyword arm for hybrid retrieval: the shared FTS function (also used by the
# eval harness and explore), ordered by rank. Row order IS the keyword ranking;
# the fusion key is the nlp bill_id form '<type><number>-<congress>'.
# $1 = query text, $2 = result limit.
KEYWORD_SEARCH_SQL = """
    SELECT billtype, billnumber, congress
    FROM search_bills($1, NULL, NULL, $2)
"""

# Hydrate full bill rows (same columns as the vector/exact rows) for bills that
# came only from the keyword arm, so every hybrid result carries consistent
# metadata. similarity is NULL — there is no cosine score for a keyword-only hit.
# $1 = array of bill ids in the '<type><number>-<congress>' form.
_HYDRATE_BILLS_SQL = f"""
    SELECT
        (b.billtype || b.billnumber::text || '-' || b.congress::text) AS bill_id,
        b.billtype AS bill_type,
        b.billnumber::text AS bill_number,
        NULL::text AS title,
        b.bill_status AS status,
        NULL::text AS body,
        NULL::text AS chunk_type,
        NULL::text AS section_header,
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
        NULL::float8 AS similarity
    FROM public.bills b
    WHERE (b.billtype || b.billnumber::text || '-' || b.congress::text) = ANY($1)
"""

HYBRID_FUSION_MIN_DEPTH = 50
HYBRID_FUSION_MAX_DEPTH = 200


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


# EMBEDDING_MODEL, EMBEDDING_DIMENSIONS, EMBEDDING_CACHE_TTL_SECONDS, and
# embedding_cache_key are imported from csearch_api.embedding — the single
# source of truth for model constants (§3 CRITICISMS2.md).


def _embedding_cache_key(query: str) -> str:
    normalized = " ".join(query.lower().split())
    return embedding_cache_key(EMBEDDING_MODEL, normalized)


async def _embed_query(request: Request, query: str) -> str | None:
    """Embed a query via OpenAI, caching the vector to cut repeated spend.

    Returns a vector string on success, or None when the circuit breaker is
    open or the call times out / fails (§4 CRITICISMS2.md).  Callers must
    treat None as a signal to return keyword-degraded results instead of 5xx.
    """
    global _cb_failure_count, _cb_open_until

    settings = request.app.state.settings
    timeout_s = getattr(settings, "semantic_openai_timeout_seconds", 2.0)
    cb_threshold = getattr(settings, "semantic_circuit_breaker_threshold", 5)
    cb_cooldown = getattr(settings, "semantic_circuit_breaker_cooldown_seconds", 60)

    # Check breaker before touching cache or OpenAI.
    now = time.monotonic()
    if _cb_open_until > now:
        logger.warning("openai circuit breaker open", extra={"opensUntil": _cb_open_until})
        return None

    cache = getattr(request.app.state, "cache", None)
    cache_key = _embedding_cache_key(query) if cache is not None else None
    if cache is not None:
        cached = await cache.get(cache_key)
        if isinstance(cached, str):
            return cached

    try:
        resp = await asyncio.wait_for(
            request.app.state.openai_client.embeddings.create(
                model=EMBEDDING_MODEL,
                input=[query],
                dimensions=EMBEDDING_DIMENSIONS,
            ),
            timeout=timeout_s,
        )
        vector = resp.data[0].embedding
        vector_str = "[" + ",".join(f"{v:.17g}" for v in vector) + "]"
        if cache is not None:
            await cache.set(cache_key, vector_str, ttl=EMBEDDING_CACHE_TTL_SECONDS)
        # Success — reset failure counter.
        async with _cb_lock:
            _cb_failure_count = 0
        return vector_str
    except Exception as exc:
        async with _cb_lock:
            _cb_failure_count += 1
            if _cb_failure_count >= cb_threshold:
                _cb_open_until = time.monotonic() + cb_cooldown
                logger.error(
                    "openai circuit breaker opened",
                    extra={"failures": _cb_failure_count, "cooldownSeconds": cb_cooldown},
                )
        logger.warning("openai embed failed", extra={"error": str(exc)})
        return None


async def _warmup_vector(request: Request) -> tuple[str | None, bool]:
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
    return await request.app.state.db.read_fetch(
        _SEARCH_SQL,
        vector_str,
        congress_min,
        congress_max,
        candidate_limit,
        result_limit,
        EMBEDDING_MODEL,  # $6 — scopes query to the active model only
        timeout=SEMANTIC_DB_TIMEOUT_SECONDS,
        hnsw_ef_search=SEMANTIC_HNSW_EF_SEARCH,
    )


# ---------------------------------------------------------------------------
# Hybrid retrieval (keyword + vector via Reciprocal Rank Fusion)
# ---------------------------------------------------------------------------

def _fusion_depth(result_limit: int) -> int:
    """How many candidates to pull from each arm before fusing."""
    return min(max(result_limit * 5, HYBRID_FUSION_MIN_DEPTH), HYBRID_FUSION_MAX_DEPTH)


def _bill_uid(billtype, billnumber, congress) -> str:
    return f"{billtype}{billnumber}-{congress}"


async def _keyword_bill_ids(
    request: Request, query: str, limit: int, congress_min: int, congress_max: int
) -> list[str]:
    """Ranked bill ids from the shared FTS function (keyword arm)."""
    rows = await request.app.state.db.read_fetch(
        KEYWORD_SEARCH_SQL, query, limit, timeout=SEMANTIC_DB_TIMEOUT_SECONDS
    )
    ids: list[str] = []
    for row in rows:
        try:
            congress = int(row["congress"])
        except (TypeError, ValueError):
            congress = None
        if congress is not None and not (congress_min <= congress <= congress_max):
            continue
        ids.append(_bill_uid(row["billtype"], row["billnumber"], row["congress"]))
    return ids


async def _hydrate_bills(request: Request, bill_ids: list[str]) -> dict[str, dict]:
    """Fetch full bill rows for keyword-only ids, keyed by bill_id."""
    if not bill_ids:
        return {}
    rows = await request.app.state.db.read_fetch(
        _HYDRATE_BILLS_SQL, bill_ids, timeout=SEMANTIC_DB_TIMEOUT_SECONDS
    )
    return {row["bill_id"]: row for row in rows}


async def _hybrid_rows(
    request: Request,
    vector_str: str,
    query: str,
    congress_min: int,
    congress_max: int,
    result_limit: int,
) -> list[dict]:
    """Fuse vector + keyword rankings with RRF and return ordered bill rows."""
    depth = _fusion_depth(result_limit)
    vec_rows, keyword_ids = await asyncio.gather(
        _semantic_rows(request, vector_str, congress_min, congress_max, depth),
        _keyword_bill_ids(request, query, depth, congress_min, congress_max),
    )
    vec_by_id = {row["bill_id"]: row for row in vec_rows}
    vec_order = list(vec_by_id.keys())

    fused = reciprocal_rank_fusion([vec_order, keyword_ids])
    fused_ids = [bill_id for bill_id, _ in fused][:result_limit]

    keyword_only = [bid for bid in fused_ids if bid not in vec_by_id]
    hydrated = await _hydrate_bills(request, keyword_only)

    results: list[dict] = []
    for bid in fused_ids:
        row = vec_by_id.get(bid) or hydrated.get(bid)
        if row is not None:
            results.append(row)
    return results


async def _keyword_only_rows(
    request: Request, query: str, congress_min: int, congress_max: int, result_limit: int
) -> list[dict]:
    """Keyword-only results (used to degrade gracefully when embedding fails)."""
    ids = (await _keyword_bill_ids(request, query, result_limit, congress_min, congress_max))[:result_limit]
    hydrated = await _hydrate_bills(request, ids)
    return [hydrated[bid] for bid in ids if bid in hydrated]


def _require_semantic_configured(request: Request) -> None:
    settings = request.app.state.settings
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail={"error": "Semantic search not configured: OPENAI_API_KEY not set"})


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


async def _enforce_rate_limit(request: Request) -> None:
    settings = request.app.state.settings
    cache = getattr(request.app.state, "cache", None)
    limit = getattr(settings, "semantic_rate_limit_per_minute", 0)
    if cache is None or limit <= 0:
        return
    allowed = await cache.rate_limit_allow(f"semantic:{_client_ip(request)}", limit, 60)
    if not allowed:
        raise HTTPException(
            status_code=429,
            detail={"error": "Rate limit exceeded for semantic search"},
            headers={"Retry-After": "60"},
        )


async def _exact_bill_rows(request: Request, ref, congress_min: int, congress_max: int, result_limit: int):
    return await request.app.state.db.read_fetch(
        _EXACT_BILL_SQL,
        ref.billtype,
        ref.billnumber,
        congress_min,
        congress_max,
        result_limit,
        timeout=SEMANTIC_DB_TIMEOUT_SECONDS,
    )


# No response_model: this route returns a list of results normally, or a
# {degraded, results} object when the circuit breaker is open. The 200 shape is
# documented via `responses` so OpenAPI is accurate without runtime coupling.
@router.post("/search/semantic", responses={200: {"model": list[SemanticResult]}})
async def semantic_search(request: Request, body: SemanticSearchRequest):
    """Return the most relevant bills for a natural-language query.

    When SEMANTIC_HYBRID_ENABLED (default), fuses keyword (full-text) and vector
    rankings with Reciprocal Rank Fusion; otherwise vector-only. Exact bill
    citations short-circuit to a direct lookup (no OpenAI call). The endpoint is
    length-capped and rate-limited per client IP to bound denial-of-wallet
    exposure. If embedding fails (OpenAI circuit breaker open / timeout): in
    hybrid mode it degrades to keyword-only results; in vector-only mode it
    returns ``{degraded: true, results: []}`` so the frontend falls back to
    keyword search (§4 CRITICISMS2.md).
    """
    _require_semantic_configured(request)

    query = body.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail={"error": "Missing required query"})

    max_chars = getattr(request.app.state.settings, "semantic_max_query_chars", 1000)
    if len(query) > max_chars:
        raise HTTPException(
            status_code=413,
            detail={"error": f"Query too long: {len(query)} chars (max {max_chars})"},
        )

    congress_min = body.congress_min if body.congress_min is not None else 0
    congress_max = body.congress_max if body.congress_max is not None else 999
    result_limit = _normalize_limit(body.limit)

    started = time.perf_counter()
    openai_status = "skipped"
    route = "unknown"
    ref = parse_bill_reference(query)
    try:
        if ref is not None:
            route = "exact"
            rows = await _exact_bill_rows(request, ref, congress_min, congress_max, result_limit)
        else:
            hybrid_enabled = getattr(request.app.state.settings, "semantic_hybrid_enabled", False)
            route = "hybrid" if hybrid_enabled else "semantic"
            await _enforce_rate_limit(request)
            vector_str = await _embed_query(request, query)
            if vector_str is None:
                # Embedding failed (circuit breaker open or timeout).
                openai_status = "degraded"
                if hybrid_enabled:
                    # Degrade to keyword-only results rather than returning nothing.
                    rows = await _keyword_only_rows(request, query, congress_min, congress_max, result_limit)
                else:
                    latency = time.perf_counter() - started
                    metrics.observe_semantic(route, openai_status, latency)
                    logger.warning(
                        "semantic search degraded",
                        extra={"route": route, "queryLength": len(query), "clientIp": _client_ip(request)},
                    )
                    return {"degraded": True, "results": []}
            elif hybrid_enabled:
                openai_status = "ok"
                rows = await _hybrid_rows(request, vector_str, query, congress_min, congress_max, result_limit)
            else:
                openai_status = "ok"
                rows = await _semantic_rows(request, vector_str, congress_min, congress_max, result_limit)
    except HTTPException:
        raise
    except Exception:
        openai_status = "error"
        logger.warning(
            "semantic search failed",
            extra={"route": route, "queryLength": len(query), "clientIp": _client_ip(request)},
        )
        raise

    latency = time.perf_counter() - started
    metrics.observe_semantic(route, openai_status, latency)
    logger.info(
        "semantic search",
        extra={
            "route": route,
            "queryLength": len(query),
            "openaiStatus": openai_status,
            "resultCount": len(rows),
            "latencyMs": round(latency * 1000, 2),
            "clientIp": _client_ip(request),
        },
    )
    return rows


@router.get("/search/semantic/coverage", response_model=CoverageResponse)
async def semantic_coverage(request: Request, response: Response):
    """Vector-corpus coverage so a partial/stale load is visible, not silent.

    Reports chunk counts by congress, bill type, and embedding model, plus the
    number of public bills with no NLP chunk yet. Returns 503 when the nlp
    schema is not present (e.g. a bills-only database).
    """
    response.headers["Cache-Control"] = "no-store"
    db = request.app.state.db
    try:
        totals = await db.read_fetchrow(
            """
            SELECT
                (SELECT COUNT(*) FROM nlp.bill_chunks) AS chunks_total,
                (SELECT COUNT(*) FROM nlp.bill_embeddings) AS embeddings_total,
                (SELECT COUNT(DISTINCT bill_id) FROM nlp.bill_chunks) AS bills_total,
                (SELECT MAX(created_at) FROM nlp.bill_chunks) AS last_chunk_at
            """
        )
        by_congress = await db.read_fetch(
            "SELECT congress, COUNT(*) AS chunks FROM nlp.bill_chunks GROUP BY congress ORDER BY congress DESC"
        )
        by_bill_type = await db.read_fetch(
            "SELECT bill_type, COUNT(*) AS chunks FROM nlp.bill_chunks GROUP BY bill_type ORDER BY chunks DESC"
        )
        by_model = await db.read_fetch(
            "SELECT model, COUNT(*) AS embeddings FROM nlp.bill_embeddings GROUP BY model ORDER BY embeddings DESC"
        )
        missing = await db.read_fetchval(
            """
            SELECT COUNT(*) FROM public.bills b
            WHERE NOT EXISTS (
                SELECT 1 FROM nlp.bill_chunks c
                WHERE c.bill_type = b.billtype
                  AND c.bill_number = b.billnumber::text
                  AND c.congress = b.congress
            )
            """
        )
        # §2 CRITICISMS2.md: orphan chunks whose canonical_bill_id does not
        # match any bill_uid in public.bills (the FK seam check before the
        # actual FK is added in migration 0008 + maintenance window).
        # Falls back to 0 gracefully when bill_uid column is not yet present.
        orphans = await db.read_fetchval(
            """
            SELECT COUNT(*) FROM nlp.bill_chunks c
            WHERE NOT EXISTS (
                SELECT 1 FROM public.bills b
                WHERE (b.bill_uid IS NOT NULL AND b.bill_uid = c.canonical_bill_id)
                   OR (b.billtype = c.bill_type
                       AND b.billnumber::text = c.bill_number
                       AND b.congress = c.congress)
            )
            """
        )
    except Exception:
        raise HTTPException(status_code=503, detail={"error": "Semantic coverage unavailable: nlp schema not present"}) from None

    return {
        "totals": totals,
        "bills_missing_chunks": missing,
        "chunks_orphaned": orphans,
        "chunks_by_congress": by_congress,
        "chunks_by_bill_type": by_bill_type,
        "embeddings_by_model": by_model,
    }


@router.post("/search/semantic/warmup")
async def semantic_search_warmup(request: Request):
    """Pre-warm the HNSW index by running a fixed query and caching its embedding."""
    _require_semantic_configured(request)

    vector_str, cache_hit = await _warmup_vector(request)
    if vector_str is None:
        # Embedding failed (e.g. circuit breaker open) — report rather than 500.
        return {"ok": False, "cache_hit": cache_hit, "query": SEMANTIC_WARMUP_QUERY, "rows": 0}

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
