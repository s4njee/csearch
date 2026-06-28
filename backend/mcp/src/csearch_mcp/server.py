"""CSearch MCP server.

A thin Model Context Protocol server that exposes U.S. congressional legislation
(bills + roll-call votes) as tools for LLM agents. It wraps the public CSearch
HTTP API (https://api.csearch.org) rather than touching the database directly, so
it reuses the API's hybrid retrieval, caching, and rate limiting and can run
anywhere.

Configuration (environment variables):
  CSEARCH_API_BASE     Base URL of the CSearch API (default https://api.csearch.org)
  CSEARCH_API_TIMEOUT  Per-request timeout in seconds (default 30)
  CSEARCH_SITE_BASE    Public site base for human-readable URLs (default https://csearch.org)
"""

from __future__ import annotations

import os
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

API_BASE = os.environ.get("CSEARCH_API_BASE", "https://api.csearch.org").rstrip("/")
SITE_BASE = os.environ.get("CSEARCH_SITE_BASE", "https://csearch.org").rstrip("/")
TIMEOUT = float(os.environ.get("CSEARCH_API_TIMEOUT", "30"))

mcp = FastMCP(
    "csearch",
    instructions=(
        "Search and read U.S. congressional legislation: bills and roll-call votes "
        "from 1973 to today. Use `semantic_search` for natural-language questions "
        "about what Congress has done on a topic; use `get_bill` / `get_vote` to read "
        "a specific item in full. All results include csearch.org links for citation."
    ),
)

_client: httpx.AsyncClient | None = None


def _http() -> httpx.AsyncClient:
    """Lazily create a shared async HTTP client bound to the API base URL."""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=API_BASE,
            timeout=TIMEOUT,
            headers={"User-Agent": "csearch-mcp/0.1", "Accept": "application/json"},
            follow_redirects=True,
        )
    return _client


async def _request(method: str, path: str, **kw: Any) -> Any:
    """Call the CSearch API and return parsed JSON, or a clean error dict.

    Errors are returned (not raised) as ``{"error": ..., "detail": ...}`` so the
    calling model receives an actionable message instead of a transport stack trace.
    """
    try:
        resp = await _http().request(method, path, **kw)
    except httpx.HTTPError as exc:
        return {"error": "request_failed", "detail": str(exc)}
    if resp.status_code >= 400:
        detail: Any
        try:
            payload = resp.json()
            detail = payload.get("detail", payload) if isinstance(payload, dict) else payload
        except ValueError:
            detail = resp.text[:300]
        return {"error": f"http_{resp.status_code}", "detail": detail}
    try:
        return resp.json()
    except ValueError:
        return {"error": "invalid_json", "detail": resp.text[:300]}


# --- projections (keep tool output compact + citation-friendly) --------------

def _truncate(text: str | None, limit: int) -> str | None:
    if not text:
        return None
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def _bill_url(billtype: Any, congress: Any, billnumber: Any) -> str | None:
    if billtype and congress and billnumber:
        return f"{SITE_BASE}/bills/{str(billtype).lower()}/{congress}/{billnumber}"
    return None


def _sponsor(b: dict[str, Any]) -> str | None:
    name = b.get("sponsor_name")
    if not name:
        return None
    party, state = b.get("sponsor_party"), b.get("sponsor_state")
    suffix = "-".join(x for x in (party, state) if x)
    return f"{name} ({suffix})" if suffix else name


def _project_bill(b: dict[str, Any]) -> dict[str, Any]:
    billtype = b.get("billtype") or b.get("bill_type")
    billnumber = b.get("billnumber") or b.get("bill_number")
    out = {
        "bill_id": b.get("billid") or b.get("bill_id"),
        "billtype": billtype,
        "congress": b.get("congress"),
        "billnumber": billnumber,
        "title": b.get("shorttitle") or b.get("officialtitle") or b.get("title"),
        "status": b.get("bill_status") or b.get("status"),
        "sponsor": _sponsor(b),
        "policy_area": b.get("policy_area"),
        "introduced": b.get("introducedat"),
        "latest_action_date": b.get("latest_action_date"),
        "cosponsor_count": b.get("cosponsor_count"),
        "summary": _truncate(b.get("summary_text"), 600),
        "url": _bill_url(billtype, b.get("congress"), billnumber),
    }
    if b.get("similarity") is not None:
        out["similarity"] = round(float(b["similarity"]), 4)
    if b.get("body"):
        out["matched_text"] = _truncate(b.get("body"), 400)
    return {k: v for k, v in out.items() if v is not None}


def _tally(v: dict[str, Any]) -> dict[str, Any] | None:
    keys = ("yea", "nay", "present", "notvoting")
    tally = {k: v[k] for k in keys if v.get(k) is not None}
    return tally or None


def _project_vote(v: dict[str, Any], *, with_members: bool = False) -> dict[str, Any]:
    voteid = v.get("voteid")
    bill = None
    if v.get("bill_type") and v.get("bill_number"):
        bill = f"{str(v['bill_type']).lower()}{v['bill_number']}"
    out = {
        "vote_id": voteid,
        "congress": v.get("congress"),
        "chamber": v.get("chamber"),
        "question": v.get("question"),
        "result": v.get("result"),
        "date": v.get("votedate"),
        "tally": _tally(v),
        "bill": bill,
        "url": f"{SITE_BASE}/votes/{voteid}" if voteid else None,
    }
    out = {k: val for k, val in out.items() if val is not None}
    if with_members and isinstance(v.get("members"), list):
        out["members"] = [
            {
                "name": m.get("display_name"),
                "party": m.get("party"),
                "state": m.get("state"),
                "position": m.get("position"),
            }
            for m in v["members"]
        ]
    return out


def _as_list(data: Any) -> list[dict[str, Any]]:
    return [x for x in data if isinstance(x, dict)] if isinstance(data, list) else []


# --- tools -------------------------------------------------------------------

@mcp.tool()
async def semantic_search(
    query: str,
    limit: int = 10,
    congress_min: int | None = None,
    congress_max: int | None = None,
) -> dict[str, Any]:
    """Search bills by natural-language meaning (hybrid keyword + vector retrieval).

    This is the best tool for open-ended questions like "bills about offshore wind
    permitting" or "legislation addressing PFAS contamination". Returns the most
    relevant bills with a similarity score and the matched passage.

    Args:
        query: A natural-language question or topic.
        limit: Max results (default 10).
        congress_min: Optional earliest congress number to include (e.g. 117).
        congress_max: Optional latest congress number to include (e.g. 119).
    """
    body: dict[str, Any] = {"query": query, "limit": limit}
    if congress_min is not None:
        body["congress_min"] = congress_min
    if congress_max is not None:
        body["congress_max"] = congress_max
    data = await _request("POST", "/v1/search/semantic", json=body)
    if isinstance(data, dict) and "error" in data:
        return data
    degraded = isinstance(data, dict) and data.get("degraded")
    rows = data.get("results", []) if isinstance(data, dict) else data
    results = [_project_bill(b) for b in _as_list(rows)]
    out: dict[str, Any] = {"count": len(results), "results": results}
    if degraded:
        out["note"] = "Query embedding unavailable; results are keyword-only."
    return out


@mcp.tool()
async def keyword_search_bills(
    query: str,
    billtype: str = "hr",
    sort: str = "relevance",
    limit: int = 20,
) -> dict[str, Any]:
    """Keyword (full-text) search within a single bill type.

    Use when you want exact-term matching within a chamber/type rather than
    semantic meaning. For cross-type, meaning-based search prefer `semantic_search`.

    Args:
        query: Search terms.
        billtype: One of hr, s, hres, sres, hjres, sjres, hconres, sconres (default hr).
        sort: "relevance" or "date" (default relevance).
        limit: Max results (default 20).
    """
    data = await _request(
        "GET", f"/v1/search/{billtype.lower()}/{sort}", params={"query": query, "limit": limit}
    )
    if isinstance(data, dict) and "error" in data:
        return data
    results = [_project_bill(b) for b in _as_list(data)]
    return {"count": len(results), "results": results}


@mcp.tool()
async def latest_bills(billtype: str = "hr", limit: int = 20) -> dict[str, Any]:
    """List the most recently updated bills of a given type.

    Args:
        billtype: One of hr, s, hres, sres, hjres, sjres, hconres, sconres (default hr).
        limit: Max results (default 20).
    """
    data = await _request("GET", f"/v1/latest/{billtype.lower()}", params={"limit": limit})
    if isinstance(data, dict) and "error" in data:
        return data
    results = [_project_bill(b) for b in _as_list(data)]
    return {"count": len(results), "results": results}


@mcp.tool()
async def get_bill(billtype: str, congress: int, billnumber: int) -> dict[str, Any]:
    """Read one bill in full: metadata, summary, actions, cosponsors, committees, and votes.

    Args:
        billtype: e.g. hr, s, hjres.
        congress: Congress number, e.g. 119.
        billnumber: The bill's number, e.g. 9495.
    """
    data = await _request("GET", f"/v1/bills/{billtype.lower()}/{congress}/{billnumber}")
    if isinstance(data, dict) and "error" in data:
        return data
    if not isinstance(data, dict):
        return {"error": "unexpected_response", "detail": "expected a bill object"}
    out = _project_bill(data)
    out["summary"] = _truncate(data.get("summary_text"), 2000)
    actions = data.get("actions") or []
    out["recent_actions"] = [
        {"date": a.get("acted_at"), "action": _truncate(a.get("action_text"), 200)}
        for a in actions[:10]
        if isinstance(a, dict)
    ]
    out["committees"] = [
        c.get("committee_name") for c in (data.get("committees") or []) if isinstance(c, dict)
    ]
    out["related_votes"] = [
        {"vote_id": vr.get("voteid"), "question": vr.get("question"), "result": vr.get("result")}
        for vr in (data.get("votes") or [])
        if isinstance(vr, dict)
    ]
    return {k: v for k, v in out.items() if v not in (None, [], {})}


@mcp.tool()
async def search_votes(query: str, chamber: str | None = None) -> dict[str, Any]:
    """Search roll-call votes by question text, optionally filtered by chamber.

    Args:
        query: Search terms (e.g. "cloture", "appropriations").
        chamber: Optional "house" or "senate".
    """
    params: dict[str, Any] = {"query": query}
    if chamber:
        params["chamber"] = chamber
    data = await _request("GET", "/v1/votes/search", params=params)
    if isinstance(data, dict) and "error" in data:
        return data
    results = [_project_vote(v) for v in _as_list(data)]
    return {"count": len(results), "results": results}


@mcp.tool()
async def latest_votes(chamber: str, limit: int = 20) -> dict[str, Any]:
    """List the most recent roll-call votes for a chamber.

    Args:
        chamber: "house" or "senate".
        limit: Max results (default 20).
    """
    data = await _request("GET", f"/v1/votes/{chamber}", params={"limit": limit})
    if isinstance(data, dict) and "error" in data:
        return data
    results = [_project_vote(v) for v in _as_list(data)]
    return {"count": len(results), "results": results}


@mcp.tool()
async def get_vote(voteid: str) -> dict[str, Any]:
    """Read one roll-call vote in full, including each member's position.

    Args:
        voteid: The vote identifier, e.g. "s191-119.2026".
    """
    data = await _request("GET", f"/v1/votes/detail/{voteid}")
    if isinstance(data, dict) and "error" in data:
        return data
    if not isinstance(data, dict):
        return {"error": "unexpected_response", "detail": "expected a vote object"}
    return _project_vote(data, with_members=True)


@mcp.tool()
async def data_freshness() -> dict[str, Any]:
    """Report how current the CSearch data is (last bill action, last vote, etc.)."""
    data = await _request("GET", "/freshness")
    if isinstance(data, dict):
        return data
    return {"error": "unexpected_response", "detail": data}
