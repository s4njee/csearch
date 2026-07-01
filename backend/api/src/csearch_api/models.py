"""models.py — Pydantic response models for the CSearch API.

Wiring `response_model` onto routes makes the FastAPI-generated OpenAPI schema
accurate and enables typed client generation (§11 docs/CRITICISMS2.md).

Design for safety: these models are deliberately **non-destructive**. Every
model uses ``extra="allow"`` so columns not declared here still pass through to
the response unchanged, and every field is optional with permissive types. The
goal is accurate documentation of the *known* shape without ever dropping a
field or 500-ing on an unexpected type — the wire payload stays identical to the
hand-built dict the route returns.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

# IDs come back from Postgres as int or text depending on the column/cast.
Id = int | str | None
# Date-ish columns arrive as date/datetime objects (asyncpg) or ISO strings.
Dateish = datetime | date | str | None


class ApiModel(BaseModel):
    """Base for all response models: passes through undeclared fields."""

    model_config = ConfigDict(extra="allow")


# ---------------------------------------------------------------------------
# Bills
# ---------------------------------------------------------------------------

class BillSummary(ApiModel):
    """Minimal bill row returned by list and search endpoints."""

    billid: Id = None
    billtype: str | None = None
    congress: Id = None
    billnumber: Id = None
    shorttitle: str | None = None
    officialtitle: str | None = None
    introducedat: Dateish = None
    latest_action_date: Dateish = None
    statusat: Dateish = None
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


class BillAction(ApiModel):
    acted_at: Dateish = None
    action_text: str | None = None
    action_type: str | None = None
    action_code: str | None = None


class BillCosponsor(ApiModel):
    bioguide_id: str | None = None
    full_name: str | None = None
    state: str | None = None
    party: str | None = None
    sponsorship_date: Dateish = None
    is_original_cosponsor: bool | None = None


class BillVoteRef(ApiModel):
    voteid: str | None = None
    congress: Id = None
    chamber: str | None = None
    question: str | None = None
    result: str | None = None
    votedate: Dateish = None
    votetype: str | None = None


class BillCommittee(ApiModel):
    committee_code: str | None = None
    committee_name: str | None = None
    chamber: str | None = None


class BillDetail(BillSummary):
    """Full bill with nested relational data (actions, cosponsors, votes, committees)."""

    update_date: Dateish = None
    summary_date: Dateish = None
    actions: list[BillAction] = Field(default_factory=list)
    cosponsors: list[BillCosponsor] = Field(default_factory=list)
    votes: list[BillVoteRef] = Field(default_factory=list)
    committees: list[BillCommittee] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Votes
# ---------------------------------------------------------------------------

class VoteSummary(ApiModel):
    voteid: str | None = None
    congress: Id = None
    chamber: str | None = None
    question: str | None = None
    result: str | None = None
    votedate: Dateish = None
    votetype: str | None = None
    votenumber: Id = None
    votesession: str | None = None
    source_url: str | None = None
    bill_type: str | None = None
    bill_number: Id = None
    yea: int | None = None
    nay: int | None = None
    present: int | None = None
    notvoting: int | None = None
    # Present only on a member's recent-votes feed.
    position: str | None = None


class VoteMember(ApiModel):
    bioguide_id: str | None = None
    display_name: str | None = None
    party: str | None = None
    state: str | None = None
    position: str | None = None


class VoteDetail(VoteSummary):
    members: list[VoteMember] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Members
# ---------------------------------------------------------------------------

class MemberCounts(ApiModel):
    sponsored: int | None = None
    cosponsored: int | None = None


class MemberDetail(ApiModel):
    bioguide_id: str | None = None
    name: str | None = None
    party: str | None = None
    state: str | None = None
    counts: MemberCounts | None = None
    sponsoredBills: list[BillSummary] = Field(default_factory=list)
    recentVotes: list[VoteSummary] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Committees
# ---------------------------------------------------------------------------

class CommitteeSummary(ApiModel):
    committee_code: str | None = None
    committee_name: str | None = None
    chamber: str | None = None
    bill_count: Id = None


class CommitteeDetail(CommitteeSummary):
    bills: list[BillSummary] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Representatives
# ---------------------------------------------------------------------------

class DistrictRef(ApiModel):
    state: str | None = None
    district: int | None = None


class RepresentativeMember(ApiModel):
    bioguide_id: str | None = None
    name: str | None = None
    party: str | None = None
    state: str | None = None
    chamber: str | None = None
    district: int | None = None


class RepresentativesResponse(ApiModel):
    zip: str | None = None
    zipcode: str | None = None
    districts: list[DistrictRef] = Field(default_factory=list)
    senators: list[RepresentativeMember] = Field(default_factory=list)
    housemembers: list[RepresentativeMember] = Field(default_factory=list)
    representatives: list[RepresentativeMember] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Explore
# ---------------------------------------------------------------------------

class ExploreParameter(ApiModel):
    name: str | None = None
    type: str | None = None
    default: Any | None = None
    min: int | None = None
    max: int | None = None


class ExploreQueryMeta(ApiModel):
    id: str | None = None
    number: int | None = None
    title: str | None = None
    path: str | None = None
    parameters: list[ExploreParameter] = Field(default_factory=list)


class ExploreListResponse(ApiModel):
    queries: list[ExploreQueryMeta] = Field(default_factory=list)


class ExploreRunResponse(ApiModel):
    query: dict[str, Any] | None = None
    results: list[dict[str, Any]] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Semantic search
# ---------------------------------------------------------------------------

class SemanticResult(BillSummary):
    """Bill row enriched with semantic match metadata."""

    bill_id: str | None = None
    bill_type: str | None = None
    bill_number: Id = None
    title: str | None = None
    status: str | None = None
    body: str | None = None          # matched chunk text
    chunk_type: str | None = None
    section_header: str | None = None
    similarity: float | None = None


class SemanticDegradedResponse(ApiModel):
    """Returned when the circuit breaker is open — frontend degrades to keyword."""

    degraded: bool = True
    results: list[Any] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Coverage
# ---------------------------------------------------------------------------

class CoverageTotals(ApiModel):
    chunks_total: int | None = None
    embeddings_total: int | None = None
    bills_total: int | None = None
    last_chunk_at: datetime | None = None


class CoverageResponse(ApiModel):
    totals: CoverageTotals | None = None
    bills_missing_chunks: int | None = None
    chunks_orphaned: int | None = None
    chunks_by_congress: list[dict[str, Any]] = Field(default_factory=list)
    chunks_by_bill_type: list[dict[str, Any]] = Field(default_factory=list)
    embeddings_by_model: list[dict[str, Any]] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Freshness / health / misc
# ---------------------------------------------------------------------------

class FreshnessResponse(ApiModel):
    now: datetime
    last_bill_action_at: Dateish = None
    last_bill_update_at: Dateish = None
    last_vote_at: Dateish = None
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


class CacheVersionResponse(ApiModel):
    """Compact data-version contract used by the public API cache Worker."""

    now: datetime
    bills_version: Dateish = None
    votes_version: Dateish = None
    explore_version: Dateish = None
    semantic_version: Dateish = None


class HealthResponse(ApiModel):
    status: str
    db: str


class RootResponse(ApiModel):
    root: bool


class ErrorResponse(ApiModel):
    error: str
    message: str | None = None
