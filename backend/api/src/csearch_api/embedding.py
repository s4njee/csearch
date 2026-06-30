"""embedding.py — Single source of truth for embedding model constants.

The model name and dimension are referenced in three places:
  - routes/semantic.py  (query-time embedding and SQL)
  - backend/nlp/project-tarp/upserter.py  (load-time default model)
  - db/migrations/0002_nlp_bill_vectors.sql  (table definition)

All three MUST agree. Centralising the constants here and importing them
prevents the retrieval query from silently mixing incompatible vector spaces
when a model upgrade is staged — the sharpest correctness risk in §3 of
docs/CRITICISMS2.md.

Model upgrade procedure (blue/green):
  1. Build a new table/partition for the next model (e.g. nlp.bill_embeddings_v2).
  2. Backfill using upserter.py --embedding-table bill_embeddings_v2 --model <new>.
  3. Evaluate recall/MRR with backend/nlp/eval/run_eval.py --mode vector.
  4. Flip ACTIVE_EMBEDDING_MODEL here and update _SEARCH_SQL to read the new table.
  5. Keep the old table for rollback until the next routine maintenance window.
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Active model — the retrieval query reads ONLY rows produced by this model.
# Changing this value without a corresponding table/partition migration is
# unsafe: see the upgrade procedure above.
# ---------------------------------------------------------------------------

EMBEDDING_MODEL: str = "text-embedding-3-small"
EMBEDDING_DIMENSIONS: int = 1536

# Cache embeddings for 24 hours by default (query-side, not corpus-side).
EMBEDDING_CACHE_TTL_SECONDS: int = 60 * 60 * 24


def embedding_cache_key(model: str, query_normalized: str) -> str:
    """Return a Redis key scoped to the model so keys from different models
    never collide.  Normalized query = lowercased, whitespace-collapsed text.
    """
    import hashlib
    digest = hashlib.sha256(query_normalized.encode("utf-8")).hexdigest()
    return f"emb:{model}:{digest}"
