"""models.py — Pydantic response models for the CSearch API.

Defining response_model on each route makes the FastAPI-generated OpenAPI
schema accurate, enables typed client generation, and ensures shape changes
are caught before they reach production callers (§11 docs/CRITICISMS2.md).

These models represent the *outbound* wire shape; they do not own DB logic.
The intent is to make the contract explicit, not to add runtime validation
overhead on every row — use `response_model_exclude_none=True` on routes
that return optional fields to keep the wire payload clean.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Bills
# ---------------------------------------------------------------------------

class BillSummary(BaseModel):
    """Minimal bill row returned by list and search endpoints."""

    billid: str | None = None
    billtype: str
    congress: str
    billnumber: str
    shorttitle: str | None = None
    officialtitle: str | None = None
    introducedat: datetime | date | None = None
    latest_action_date: datetime | date | None = None
    statusat: datetime | date | None = None
    bill_status: str | None = None
    sponsor_name: str | None = None
    sponsor_party: str | None = None
    sponsor_state: str | None = None
    sponsor_bioguide_id: str | None = None
    policy_area: str | None = None
    summary_text: str | None = None
    origin_chamber: str | None = None
    committee_codes: list[str] | None = None
    cosponsor_count: int | None = None


class BillAction(BaseModel):
    acted_at: datetime | date | None = None
    action_text: str | None = None
    action_type: str | None = None
    action_code: str | None = None


class BillCosponsor(BaseModel):
    bioguide_id: str | None = None
    full_name: str | None = None
    state: str | None = None
    party: str | None = None
    sponsorship_date: datetime | date | None = None
    is_original_cosponsor: bool | None = None


class BillVoteRef(BaseModel):
    voteid: str | None = None
    congress: int | None = None
    chamber: str | None = None
    question: str | None = None
    result: str | None = None
    votedate: datetime | date | None = None
    votetype: str | None = None


class BillCommittee(BaseModel):
    committee_code: str | None = None
    committee_name: str | None = None
    chamber: str | None = None


class BillDetail(BillSummary):
    """Full bill with nested relational data (actions, cosponsors, votes, committees)."""

    update_date: datetime | date | None = None
    summary_date: datetime | date | None = None
    actions: list[BillAction] = Field(default_factory=list)
    cosponsors: list[BillCosponsor] = Field(default_factory=list)
    votes: list[BillVoteRef] = Field(default_factory=list)
    committees: list[BillCommittee] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Semantic search
# ---------------------------------------------------------------------------

class SemanticResult(BillSummary):
    """Bill row enriched with semantic match metadata."""

    bill_id: str | None = None
    bill_type: str | None = None
    bill_number: str | None = None
    title: str | None = None
    status: str | None = None
    body: str | None = None          # matched chunk text
    chunk_type: str | None = None
    section_header: str | None = None
    similarity: float | None = None


class SemanticDegradedResponse(BaseModel):
    """Returned when the circuit breaker is open — frontend degrades to keyword."""

    degraded: bool = True
    results: list[Any] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Coverage
# ---------------------------------------------------------------------------

class CoverageTotals(BaseModel):
    chunks_total: int | None = None
    embeddings_total: int | None = None
    bills_total: int | None = None
    last_chunk_at: datetime | None = None


class CoverageByDimension(BaseModel):
    label: str       # congress number, bill_type, or model name
    count: int


class CoverageResponse(BaseModel):
    totals: CoverageTotals | None = None
    bills_missing_chunks: int | None = None
    chunks_orphaned: int | None = None
    chunks_by_congress: list[dict[str, Any]] = Field(default_factory=list)
    chunks_by_bill_type: list[dict[str, Any]] = Field(default_factory=list)
    embeddings_by_model: list[dict[str, Any]] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Freshness
# ---------------------------------------------------------------------------

class FreshnessResponse(BaseModel):
    now: datetime
    last_bill_action_at: datetime | date | None = None
    last_bill_update_at: datetime | date | None = None
    last_vote_at: datetime | date | None = None
    bills_updated_24h: int | None = None
    bills_total: int | None = None
    votes_total: int | None = None
    last_semantic_chunk_at: datetime | None = None
    semantic_chunks_total: int | None = None
    semantic_bills_total: int | None = None
    last_nlp_run_started_at: datetime | None = None
    last_nlp_run_finished_at: datetime | None = None
    last_nlp_run_status: str | None = None
    last_nlp_run_upserted_chunks: int | None = None
