from __future__ import annotations

import logging
import time

from fastapi import APIRouter, Depends, HTTPException, Request, Response

from ..db import Database
from ..deps import get_db
from ..explore import execute_explore_query, get_explore_queries
from ..models import ExploreListResponse, ExploreRunResponse

router = APIRouter()
logger = logging.getLogger("csearch-api")

# Edge can serve cached explore JSON for an hour, then revalidate in the
# background for up to a day.
EXPLORE_CACHE_CONTROL = "public, max-age=3600, stale-while-revalidate=86400"


@router.get("/explore", response_model=ExploreListResponse)
async def list_explore_queries():
    return {"queries": get_explore_queries()}


@router.get("/explore/{query_id}", response_model=ExploreRunResponse)
async def run_explore_query(request: Request, response: Response, query_id: str, db: Database = Depends(get_db)):
    started_at = time.time()
    query_dict = dict(request.query_params)

    response.headers["Cache-Control"] = EXPLORE_CACHE_CONTROL

    result = await execute_explore_query(db, query_id, query_dict)
    if not result:
        raise HTTPException(status_code=404, detail={"error": "Not Found", "message": f"Unknown explore query: {query_id}"})

    # NOTE: raw SQL + bindings are intentionally omitted (see execute_explore_query;
    # §10/§11 CRITICISMS2.md) to avoid leaking internal query structure.
    payload = {
        "query": result["query"],
        "results": result["rows"],
    }

    response_time = (time.time() - started_at) * 1000
    if response_time > 500:
        logger.warning(
            "slow explore query",
            extra={"queryId": query_id, "responseTime": response_time},
        )

    return payload
