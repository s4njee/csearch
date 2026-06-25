from __future__ import annotations

import pytest

from csearch_api.routing import BillReference, classify_query, parse_bill_reference


@pytest.mark.parametrize(
    "query,expected",
    [
        ("HR 42", BillReference("hr", 42)),
        ("hr42", BillReference("hr", 42)),
        ("H.R. 42", BillReference("hr", 42)),
        ("s 100", BillReference("s", 100)),
        ("hjres5", BillReference("hjres", 5)),
        ("  sconres 12 ", BillReference("sconres", 12)),
    ],
)
def test_parse_bill_reference_matches_citations(query, expected):
    assert parse_bill_reference(query) == expected


@pytest.mark.parametrize(
    "query",
    [
        "",
        "bills about climate change",
        "what did HR 42 do",  # mentions a bill but is a question
        "xyz 5",  # not a real bill type
        "section 42",
    ],
)
def test_parse_bill_reference_rejects_non_citations(query):
    assert parse_bill_reference(query) is None


def test_classify_query_routes():
    assert classify_query("HR 42") == "exact"
    assert classify_query("climate") == "keyword"
    assert classify_query('"exact phrase here that is long"') == "keyword"
    assert classify_query("what are the recent bills addressing rural broadband access") == "semantic"
