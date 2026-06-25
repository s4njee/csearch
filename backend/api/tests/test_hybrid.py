from __future__ import annotations

from csearch_api.hybrid import fuse_ids, reciprocal_rank_fusion


def test_rrf_rewards_agreement_across_rankings():
    keyword = ["a", "b", "c"]
    vector = ["b", "a", "d"]
    fused = reciprocal_rank_fusion([keyword, vector])
    order = [item_id for item_id, _ in fused]
    # "a" and "b" both rank highly in both lists and should lead.
    assert set(order[:2]) == {"a", "b"}
    assert order[-1] in {"c", "d"}


def test_rrf_single_list_preserves_order():
    fused = reciprocal_rank_fusion([["x", "y", "z"]])
    assert [item_id for item_id, _ in fused] == ["x", "y", "z"]


def test_fuse_ids_respects_limit_and_weights():
    # Heavily weight the vector ranking; with disjoint lists its top item wins.
    result = fuse_ids(["a", "b"], ["c", "d"], limit=2, keyword_weight=0.1, vector_weight=1.0)
    assert result[0] == "c"
    assert len(result) == 2


def test_rrf_weight_validation():
    try:
        reciprocal_rank_fusion([["a"], ["b"]], weights=[1.0])
        assert False, "expected ValueError"
    except ValueError:
        pass
