from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from openai import AsyncOpenAI
from pydantic import BaseModel

router = APIRouter()

_SEARCH_SQL = """
    SELECT
        c.bill_id,
        c.congress,
        c.title,
        c.status,
        c.body,
        c.chunk_type,
        c.section_header,
        1 - (e.embedding <=> $1::vector) AS similarity
    FROM nlp.bill_embeddings e
    JOIN nlp.bill_chunks c ON c.id = e.chunk_id
    WHERE c.congress BETWEEN $2 AND $3
    ORDER BY e.embedding <=> $1::vector
    LIMIT 40
"""


class SemanticSearchRequest(BaseModel):
    query: str
    congress_min: int | None = None
    congress_max: int | None = None


@router.post("/search/semantic")
async def semantic_search(request: Request, body: SemanticSearchRequest):
    settings = request.app.state.settings
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail={"error": "Semantic search not configured: OPENAI_API_KEY not set"})

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    resp = await client.embeddings.create(
        model="text-embedding-3-small",
        input=body.query,
    )
    vector = resp.data[0].embedding
    vector_str = "[" + ",".join(f"{v:.17g}" for v in vector) + "]"

    congress_min = body.congress_min if body.congress_min is not None else 0
    congress_max = body.congress_max if body.congress_max is not None else 999

    rows = await request.app.state.db.fetch(
        _SEARCH_SQL, vector_str, congress_min, congress_max
    )

    # Deduplicate: keep highest-scoring chunk per bill, return up to 20 bills
    seen: dict[str, dict] = {}
    for row in rows:
        bill_id = row["bill_id"]
        if bill_id not in seen:
            seen[bill_id] = row
        if len(seen) == 20:
            break

    return list(seen.values())
