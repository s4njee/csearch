"""Hybrid rank fusion for search.

Combines a keyword (full-text) ranking with a vector (semantic) ranking using
Reciprocal Rank Fusion (RRF), which needs no score calibration between the two
very different scales (ts_rank vs cosine similarity). This is the ranking layer
the production search path should adopt once the eval harness
(backend/nlp/eval) shows it beats vector-only; see docs/PRODUCT.md.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence

DEFAULT_RRF_K = 60


def reciprocal_rank_fusion(
    rankings: Sequence[Iterable[str]],
    k: int = DEFAULT_RRF_K,
    weights: Sequence[float] | None = None,
) -> list[tuple[str, float]]:
    """Fuse several ranked id lists into one ranking by RRF.

    Each input is an iterable of ids ordered best-first. The fused score of an
    id is ``sum_lists weight * 1 / (k + rank)`` (rank is 0-based). Returns
    ``(id, score)`` pairs sorted by score descending, then id for stability.
    """
    if weights is None:
        weights = [1.0] * len(rankings)
    if len(weights) != len(rankings):
        raise ValueError("weights must match the number of rankings")

    scores: dict[str, float] = {}
    for ranking, weight in zip(rankings, weights, strict=True):
        for rank, item_id in enumerate(ranking):
            scores[item_id] = scores.get(item_id, 0.0) + weight * (1.0 / (k + rank))

    return sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))


def fuse_ids(
    keyword_ids: Iterable[str],
    vector_ids: Iterable[str],
    limit: int,
    keyword_weight: float = 1.0,
    vector_weight: float = 1.0,
    k: int = DEFAULT_RRF_K,
) -> list[str]:
    """Convenience wrapper: fuse a keyword and a vector ranking, return top ids."""
    fused = reciprocal_rank_fusion(
        [list(keyword_ids), list(vector_ids)],
        k=k,
        weights=[keyword_weight, vector_weight],
    )
    return [item_id for item_id, _ in fused[:limit]]
