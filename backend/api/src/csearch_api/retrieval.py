"""retrieval.py — Unified retrieval service for CSearch.

Owns the query pipeline: classify → engine selection → fetch → fuse → result.
Route handlers are thin callers; the frontend stops reimplementing fallback logic.

Pipeline:
    1. classify_query()        — exact / keyword / semantic (routing.py)
    2. engine selection        — which corpora to query based on route
    3. fetch from each engine  — keyword SQL and/or semantic ANN
    4. fuse                    — Reciprocal Rank Fusion when both engines run
    5. return RetrievalResult  — uniform contract regardless of path

This is the natural home for routing.py and hybrid.py, and the place the eval
harness (backend/nlp/eval/run_eval.py) should target once vote search is wired
in as a second corpus.

See docs/CRITICISMS2.md §9 and docs/PRODUCT.md for the product model.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from typing import Any

from .hybrid import fuse_ids
from .routing import BillReference, QueryRoute, classify_query, parse_bill_reference

logger = logging.getLogger("csearch-api")


# ---------------------------------------------------------------------------
# Result contract
# ---------------------------------------------------------------------------

@dataclass
class RetrievalResult:
    """Uniform result from the retrieval service regardless of which engines ran."""

    route: QueryRoute          # "exact", "keyword", or "semantic"
    rows: list[dict[str, Any]]
    degraded: bool = False     # True when semantic was requested but unavailable
    latency_ms: float = 0.0
    engines_used: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Service entry point
# ---------------------------------------------------------------------------

async def retrieve(
    *,
    query: str,
    db,
    embed_fn,                  # async callable(query: str) -> str | None
    keyword_fetch_fn,          # async callable(query: str, congress_min, congress_max, limit) -> list[dict]
    semantic_fetch_fn,         # async callable(vector_str, congress_min, congress_max, limit) -> list[dict]
    congress_min: int = 0,
    congress_max: int = 999,
    result_limit: int = 50,
    enable_hybrid: bool = False,
    keyword_weight: float = 1.0,
    vector_weight: float = 1.0,
) -> RetrievalResult:
    """Retrieve bills for a query using the appropriate engine(s).

    Args:
        query:             Raw user query string.
        db:                Database handle (for exact-lookup fallback).
        embed_fn:          Async function that returns a vector string or None
                           (None signals circuit breaker open / degraded).
        keyword_fetch_fn:  Async function returning keyword search rows.
        semantic_fetch_fn: Async function returning semantic (ANN) rows.
        congress_min/max:  Congress range filter.
        result_limit:      Maximum rows to return.
        enable_hybrid:     When True, run both engines and fuse with RRF.
                           When False (default), each route uses one engine.
        keyword_weight:    RRF weight for the keyword ranking.
        vector_weight:     RRF weight for the vector ranking.

    Returns:
        RetrievalResult with rows, route taken, and degradation flag.
    """
    started = time.perf_counter()
    text = (query or "").strip()

    # 1. Classify
    ref: BillReference | None = parse_bill_reference(text)
    if ref is not None:
        route: QueryRoute = "exact"
    else:
        route = classify_query(text)

    # 2. Fetch
    if route == "exact" and ref is not None:
        rows = await _exact_rows(db, ref, congress_min, congress_max, result_limit)
        engines = ["exact"]
        degraded = False

    elif route == "keyword" or (route == "semantic" and not enable_hybrid):
        # Single-engine path (current production default).
        if route == "semantic":
            vector_str = await embed_fn(text)
            if vector_str is None:
                # Degrade: embed_fn signals circuit breaker open.
                rows = []
                engines = []
                degraded = True
            else:
                rows = await semantic_fetch_fn(vector_str, congress_min, congress_max, result_limit)
                engines = ["semantic"]
                degraded = False
        else:
            rows = await keyword_fetch_fn(text, congress_min, congress_max, result_limit)
            engines = ["keyword"]
            degraded = False

    else:
        # Hybrid path (enable_hybrid=True, route="semantic").
        vector_str = await embed_fn(text)
        if vector_str is None:
            # Degrade to keyword only.
            rows = await keyword_fetch_fn(text, congress_min, congress_max, result_limit)
            engines = ["keyword"]
            degraded = True
        else:
            kw_rows, sem_rows = await _fetch_both(
                keyword_fetch_fn, semantic_fetch_fn,
                text, vector_str, congress_min, congress_max, result_limit,
            )
            rows = _fuse(kw_rows, sem_rows, result_limit, keyword_weight, vector_weight)
            engines = ["keyword", "semantic"]
            degraded = False

    latency_ms = round((time.perf_counter() - started) * 1000, 2)
    return RetrievalResult(
        route=route,
        rows=rows,
        degraded=degraded,
        latency_ms=latency_ms,
        engines_used=engines,
    )


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

async def _exact_rows(db, ref: BillReference, congress_min: int, congress_max: int, limit: int) -> list[dict]:
    """Direct bill lookup by type + number, no OpenAI call."""
    from .semantic import _EXACT_BILL_SQL, SEMANTIC_DB_TIMEOUT_SECONDS
    return await db.fetch(
        _EXACT_BILL_SQL,
        ref.billtype,
        ref.billnumber,
        congress_min,
        congress_max,
        limit,
        timeout=SEMANTIC_DB_TIMEOUT_SECONDS,
    )


async def _fetch_both(keyword_fn, semantic_fn, text, vector_str, cmin, cmax, limit):
    """Run keyword and semantic fetches concurrently."""
    import asyncio
    kw_task = asyncio.create_task(keyword_fn(text, cmin, cmax, limit))
    sem_task = asyncio.create_task(semantic_fn(vector_str, cmin, cmax, limit))
    return await asyncio.gather(kw_task, sem_task)


def _row_id(row: dict) -> str:
    """Extract a stable bill identity string from a row dict."""
    # Works for both semantic rows (bill_id) and keyword rows (billid or computed).
    return (
        row.get("bill_id")
        or row.get("billid")
        or f"{row.get('billtype','')}{row.get('billnumber','')}-{row.get('congress','')}"
    )


def _fuse(
    kw_rows: list[dict],
    sem_rows: list[dict],
    limit: int,
    keyword_weight: float,
    vector_weight: float,
) -> list[dict]:
    """Fuse keyword + semantic rows with RRF, returning the top `limit` rows."""
    kw_ids = [_row_id(r) for r in kw_rows]
    sem_ids = [_row_id(r) for r in sem_rows]

    fused_ids = fuse_ids(kw_ids, sem_ids, limit=limit,
                         keyword_weight=keyword_weight,
                         vector_weight=vector_weight)

    # Build an id→row lookup, preferring semantic rows (richer metadata).
    by_id: dict[str, dict] = {}
    for row in kw_rows:
        by_id[_row_id(row)] = row
    for row in sem_rows:
        by_id[_row_id(row)] = row  # semantic rows overwrite

    return [by_id[rid] for rid in fused_ids if rid in by_id]
