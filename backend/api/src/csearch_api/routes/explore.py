from __future__ import annotations

import logging
import time

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..cache import EXPLORE_TTL_SECONDS, Cache
from ..db import Database
from ..deps import get_cache, get_db
from ..explore import execute_explore_query, get_explore_queries
from ..models import ExploreListResponse, ExploreRunResponse

router = APIRouter()
logger = logging.getLogger("csearch-api")

# Edge can serve cached explore JSON for an hour, then revalidate in the
# background for up to a day. Pairs with the shorter Redis TTL below.
EXPLORE_CACHE_CONTROL = "public, max-age=3600, stale-while-revalidate=86400"


def _cache_key(query_id: str, request_query: dict[str, str]) -> str:
    query_params_string = "&".join(f"{key}={request_query[key]}" for key in sorted(request_query))
    return f"explore_{query_id}_{query_params_string}"


@router.get("/explore", response_model=ExploreListResponse)
async def list_explore_queries():
    return {"queries": get_explore_queries()}


@router.get("/explore/{query_id}", response_model=ExploreRunResponse)
async def run_explore_query(request: Request, response: Response, query_id: str, db: Database = Depends(get_db), cache: Cache = Depends(get_cache)):
    started_at = time.time()
    query_dict = dict(request.query_params)
    cache_key = _cache_key(query_id, query_dict)

    response.headers["Cache-Control"] = EXPLORE_CACHE_CONTROL

    cached = await cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    result = await execute_explore_query(db, query_id, query_dict)
    if not result:
        raise HTTPException(status_code=404, detail={"error": "Not Found", "message": f"Unknown explore query: {query_id}"})

    # NOTE: raw SQL + bindings are intentionally omitted (see execute_explore_query;
    # §10/§11 CRITICISMS2.md) to avoid leaking internal query structure.
    payload = {
        "query": result["query"],
        "results": result["rows"],
    }
    await cache.set(cache_key, payload, ttl=EXPLORE_TTL_SECONDS)
    request.state.cache_header = "MISS"

    response_time = (time.time() - started_at) * 1000
    if response_time > 500:
        logger.warning(
            "slow explore query",
            extra={"queryId": query_id, "responseTime": response_time},
        )

    return payload
