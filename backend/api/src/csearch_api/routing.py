from __future__ import annotations

import re
from dataclasses import dataclass

from .constants import VALID_BILL_TYPES

# Query routing for the search surface. Not every query should pay for an
# OpenAI embedding: an exact bill reference ("HR 42") is answered far better by
# a direct lookup, and a short keyword query is usually better served by
# full-text search. Classifying the query up front saves money on the semantic
# endpoint and improves exactness. See docs/PRODUCT.md for the product model.

# Bill type tokens as users tend to type them, mapped to canonical types.
# Longer tokens must be tried before their prefixes (e.g. "hres" before "hr").
_BILL_TYPE_ALIASES: list[tuple[str, str]] = [
    ("hconres", "hconres"),
    ("hjres", "hjres"),
    ("hres", "hres"),
    ("hr", "hr"),
    ("sconres", "sconres"),
    ("sjres", "sjres"),
    ("sres", "sres"),
    ("s", "s"),
]

# Match an optional leading bill type (allowing dots/spaces like "h.r.") then a
# number, optionally with a congress suffix like "118" via "118 hr 42" handled
# by the caller. Whole-string match keeps this conservative: a sentence that
# merely mentions a bill is left to semantic search.
_BILL_REF_RE = re.compile(
    r"""^\s*
        (?P<type>[a-z]{1,3}(?:\.?\s?[a-z]{1,4}\.?)?)   # hr, h.r., hjres, s
        \s*\.?\s*
        (?P<number>\d{1,6})
        \s*$""",
    re.IGNORECASE | re.VERBOSE,
)

QueryRoute = str  # one of: "exact", "keyword", "semantic"

# Below this length a natural-language embedding rarely beats keyword search.
KEYWORD_MAX_QUERY_CHARS = 24


@dataclass(frozen=True)
class BillReference:
    billtype: str
    billnumber: int


def _normalize_type(raw: str) -> str | None:
    token = re.sub(r"[^a-z]", "", raw.lower())
    for alias, canonical in _BILL_TYPE_ALIASES:
        if token == alias:
            return canonical
    return token if token in VALID_BILL_TYPES else None


def parse_bill_reference(query: str) -> BillReference | None:
    """Return a BillReference when the query is an exact bill citation.

    Recognizes forms like "HR 42", "hr42", "H.R. 42", "s 100", "hjres5".
    Returns None for anything that looks like a phrase or policy question.
    """
    match = _BILL_REF_RE.match(query or "")
    if not match:
        return None
    billtype = _normalize_type(match.group("type"))
    if billtype is None:
        return None
    return BillReference(billtype=billtype, billnumber=int(match.group("number")))


def classify_query(query: str) -> QueryRoute:
    """Route a search query to the cheapest surface that serves it well."""
    text = (query or "").strip()
    if not text:
        return "keyword"
    if parse_bill_reference(text) is not None:
        return "exact"
    # A short, unquoted query is usually a keyword/title lookup; quoted text is
    # an exact phrase that full-text search handles literally.
    if len(text) <= KEYWORD_MAX_QUERY_CHARS or (text.startswith('"') and text.endswith('"')):
        return "keyword"
    return "semantic"
