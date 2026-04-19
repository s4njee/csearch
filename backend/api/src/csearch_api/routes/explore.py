from __future__ import annotations

import logging
import time

from fastapi import APIRouter, HTTPException, Request

from ..explore import execute_explore_query, get_explore_queries

router = APIRouter()
logger = logging.getLogger("csearch-api")


def _cache_key(query_id: str, request_query: dict[str, object]) -> str:
    query_params_string = "&".join(f"{key}={request_query[key]}" for key in sorted(request_query))
    return f"explore_{query_id}_{query_params_string}"


@router.get("/explore")
async def list_explore_queries():
    return {"queries": get_explore_queries()}


@router.get("/explore/{query_id}")
async def run_explore_query(request: Request, query_id: str):
    started_at = time.time()
    query_dict = dict(request.query_params)
    cache_key = _cache_key(query_id, query_dict)

    cached = await request.app.state.cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    result = await execute_explore_query(request.app.state.db, query_id, query_dict)
    if not result:
        raise HTTPException(status_code=404, detail={"error": "Not Found", "message": f"Unknown explore query: {query_id}"})

    response = {
        "query": result["query"],
        "sql": result["sql"],
        "bindings": result["bindings"],
        "results": result["rows"],
    }
    await request.app.state.cache.set(cache_key, response)
    request.state.cache_header = "MISS"

    response_time = (time.time() - started_at) * 1000
    if response_time > 500:
        logger.warning({"queryId": query_id, "responseTime": response_time})

    return response
