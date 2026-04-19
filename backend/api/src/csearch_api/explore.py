from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

MAX_RESULT_LIMIT = 100
SEARCH_BILLS_QUERY_ID = "bill-search-example"
SEARCH_VOTES_QUERY_ID = "vote-search-example"

QUERY_IDS_BY_NUMBER = {
    1: "recent-bills",
    2: "largest-cosponsor-coalitions",
    3: "top-subject-areas",
    4: "active-committees",
    5: "deepest-action-history",
    6: "missing-descriptive-fields",
    7: "largest-vote-margins",
    8: "closest-votes",
    9: "most-not-voting-members",
    10: "broad-sponsorship-history",
    11: SEARCH_BILLS_QUERY_ID,
    12: SEARCH_VOTES_QUERY_ID,
    13: "most-prolific-sponsors",
    14: "bipartisan-bills",
    15: "policy-area-by-congress",
    16: "bills-with-floor-votes",
    17: "party-line-crossovers",
    18: "active-committees-recent",
    19: "closest-votes-recent",
}


@dataclass(frozen=True)
class ExploreQuery:
    id: str
    number: int
    title: str
    sql: str
    parameters: list[dict[str, Any]]


# Path is resolved relative to __file__ so it works both locally and inside the Docker container.
def _sql_path() -> Path:
    return Path(__file__).resolve().parents[3] / "api" / "sql" / "explore.sql"


def _slugify_title(title: str) -> str:
    slug = []
    for char in title.lower():
        slug.append(char if char.isalnum() else "-")
    return "-".join(filter(None, "".join(slug).split("-"))).strip("-")


def _normalize_optional_text(value: Any) -> str | None:
    if value in (None, ""):
        return None
    return str(value)


def _normalize_optional_integer(value: Any) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _normalize_limit(value: Any, default_value: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default_value
    if parsed < 1:
        return 1
    return min(parsed, MAX_RESULT_LIMIT)


def _parse_explore_queries(sql_text: str) -> list[ExploreQuery]:
    """Parse SQL blocks from explore.sql, delimited by '-- N. Title' comments.

    Each block starts when a line matching '-- <number>. <title>' is encountered
    and ends at the next such delimiter or end of file. The block's SQL is
    everything between those delimiters (whitespace-stripped).
    """
    queries: list[ExploreQuery] = []
    current_number: int | None = None
    current_title: str | None = None
    current_lines: list[str] = []

    def finalize() -> None:
        nonlocal current_number, current_title, current_lines
        if current_number is None or current_title is None:
            return
        sql = "\n".join(current_lines).strip()
        if not sql:
            return
        query_id = QUERY_IDS_BY_NUMBER.get(current_number, _slugify_title(current_title))
        queries.append(
            ExploreQuery(
                id=query_id,
                number=current_number,
                title=current_title,
                sql=sql,
                parameters=_search_query_params().get(query_id, []),
            )
        )

    for line in sql_text.splitlines():
        if line.startswith("-- "):
            parts = line[3:].split(".", 1)
            if len(parts) == 2 and parts[0].strip().isdigit():
                finalize()
                current_number = int(parts[0].strip())
                current_title = parts[1].strip()
                current_lines = []
                continue
        if current_number is not None:
            current_lines.append(line)

    finalize()
    return queries


@lru_cache(maxsize=1)
def load_explore_queries() -> list[ExploreQuery]:
    return _parse_explore_queries(_sql_path().read_text(encoding="utf-8"))


def _search_query_params() -> dict[str, list[dict[str, Any]]]:
    return {
        SEARCH_BILLS_QUERY_ID: [
            {"name": "q", "type": "string", "default": "clean energy tax credit"},
            {"name": "billType", "type": "string", "default": None},
            {"name": "congress", "type": "integer", "default": None},
            {"name": "limit", "type": "integer", "default": 20, "min": 1, "max": MAX_RESULT_LIMIT},
        ],
        SEARCH_VOTES_QUERY_ID: [
            {"name": "q", "type": "string", "default": "cloture nomination"},
            {"name": "congress", "type": "integer", "default": None},
            {"name": "chamber", "type": "string", "default": None},
            {"name": "limit", "type": "integer", "default": 20, "min": 1, "max": MAX_RESULT_LIMIT},
        ],
    }


def get_explore_queries() -> list[dict[str, Any]]:
    return [
        {
            "id": query.id,
            "number": query.number,
            "title": query.title,
            "path": f"/explore/{query.id}",
            "parameters": query.parameters,
        }
        for query in load_explore_queries()
    ]


def _get_explore_query(query_id: str) -> ExploreQuery | None:
    for query in load_explore_queries():
        if query.id == query_id:
            return query
    return None


def _build_execution(query: ExploreQuery, request_query: dict[str, Any]) -> tuple[str, list[Any]]:
    if query.id == SEARCH_BILLS_QUERY_ID:
        return (
            "SELECT * FROM search_bills($1, $2, $3, $4);",
            [
                request_query.get("q") or "clean energy tax credit",
                _normalize_optional_text(request_query.get("billType")),
                _normalize_optional_integer(request_query.get("congress")),
                _normalize_limit(request_query.get("limit"), 20),
            ],
        )

    if query.id == SEARCH_VOTES_QUERY_ID:
        return (
            "SELECT * FROM search_votes($1, $2, $3, $4);",
            [
                request_query.get("q") or "cloture nomination",
                _normalize_optional_integer(request_query.get("congress")),
                _normalize_optional_text(request_query.get("chamber")),
                _normalize_limit(request_query.get("limit"), 20),
            ],
        )

    return query.sql, []


async def execute_explore_query(db, query_id: str, request_query: dict[str, Any]):
    query = _get_explore_query(query_id)
    if query is None:
        return None

    sql, bindings = _build_execution(query, request_query)
    result = await db.raw(sql, *bindings)
    return {
        "query": {
            "id": query.id,
            "number": query.number,
            "title": query.title,
            "parameters": query.parameters,
        },
        "sql": sql,
        "bindings": bindings,
        "rows": result["rows"],
    }
