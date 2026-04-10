from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

router = APIRouter()

# top_k scans only nlp.bill_embeddings with no joins or filters so the
# HNSW index is used. Joining and congress filtering happen afterwards on
# the small result set.
_SEARCH_SQL = """
    WITH top_k AS (
        SELECT chunk_id, 1 - (embedding <=> $1::vector) AS similarity
        FROM nlp.bill_embeddings
        ORDER BY embedding <=> $1::vector
        LIMIT 200
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
        (
            SELECT COALESCE(array_agg(DISTINCT bc.committee_code ORDER BY bc.committee_code), '{}')
            FROM bill_committees bc
            WHERE bc.billtype = b.billtype
              AND bc.billnumber = b.billnumber
              AND bc.congress = b.congress
        ) AS committee_codes,
        (
            SELECT COUNT(*)::int
            FROM bill_cosponsors bc
            WHERE bc.billtype = b.billtype
              AND bc.billnumber = b.billnumber
              AND bc.congress = b.congress
        ) AS cosponsor_count,
        r.similarity
    FROM ranked r
    LEFT JOIN public.bills b
      ON b.billtype = r.bill_type
     AND b.billnumber::text = r.bill_number
     AND b.congress = r.congress
    ORDER BY r.similarity DESC
    LIMIT 20
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

    resp = await request.app.state.openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=body.query,
    )
    vector = resp.data[0].embedding
    vector_str = "[" + ",".join(f"{v:.17g}" for v in vector) + "]"

    congress_min = body.congress_min if body.congress_min is not None else 0
    congress_max = body.congress_max if body.congress_max is not None else 999

    return await request.app.state.db.fetch(
        _SEARCH_SQL, vector_str, congress_min, congress_max
    )
