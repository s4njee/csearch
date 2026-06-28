import respx
from httpx import Response

from csearch_mcp import server

API = "https://api.csearch.org"


def _reset_client() -> None:
    """Drop the cached httpx client so respx intercepts a fresh one."""
    server._client = None


# --- pure projections --------------------------------------------------------

def test_truncate() -> None:
    assert server._truncate(None, 10) is None
    assert server._truncate("hello world", 100) == "hello world"
    out = server._truncate("a" * 50, 10)
    assert out is not None and out.endswith("…") and len(out) == 10


def test_project_bill() -> None:
    p = server._project_bill(
        {
            "billid": "119-HR-1",
            "billtype": "hr",
            "congress": "119",
            "billnumber": "1",
            "shorttitle": "Test Act",
            "sponsor_name": "Doe",
            "sponsor_party": "D",
            "sponsor_state": "CA",
            "summary_text": "x " * 600,
            "similarity": 0.123456,
            "body": "matched passage",
        }
    )
    assert p["bill_id"] == "119-HR-1"
    assert p["title"] == "Test Act"
    assert p["sponsor"] == "Doe (D-CA)"
    assert p["url"] == "https://csearch.org/bills/hr/119/1"
    assert p["similarity"] == 0.1235
    assert p["matched_text"] == "matched passage"
    assert len(p["summary"]) <= 601


def test_project_vote_with_members() -> None:
    v = server._project_vote(
        {
            "voteid": "s191-119.2026",
            "congress": "119",
            "chamber": "s",
            "question": "On Cloture",
            "result": "Agreed to",
            "yea": 60,
            "nay": 40,
            "bill_type": "hr",
            "bill_number": "1",
            "members": [{"display_name": "Doe", "party": "D", "state": "CA", "position": "Yea"}],
        },
        with_members=True,
    )
    assert v["vote_id"] == "s191-119.2026"
    assert v["tally"] == {"yea": 60, "nay": 40}
    assert v["bill"] == "hr1"
    assert v["url"] == "https://csearch.org/votes/s191-119.2026"
    assert v["members"][0]["position"] == "Yea"


# --- tools (mocked API) ------------------------------------------------------

@respx.mock
async def test_semantic_search_fuses_results() -> None:
    respx.post(f"{API}/v1/search/semantic").mock(
        return_value=Response(
            200,
            json=[
                {"billid": "118-S-5441", "billtype": "s", "congress": "118",
                 "billnumber": "5441", "shorttitle": "COLLABORATE Act", "similarity": 0.65},
                {"billid": "105-HR-4328", "billtype": "hr", "congress": "105",
                 "billnumber": "4328", "shorttitle": "Omnibus Act"},
            ],
        )
    )
    _reset_client()
    r = await server.semantic_search("offshore wind", limit=2)
    assert r["count"] == 2
    assert r["results"][0]["similarity"] == 0.65
    assert "note" not in r


@respx.mock
async def test_semantic_search_degraded_note() -> None:
    respx.post(f"{API}/v1/search/semantic").mock(
        return_value=Response(200, json={"degraded": True, "results": []})
    )
    _reset_client()
    r = await server.semantic_search("x")
    assert r["count"] == 0
    assert "note" in r


@respx.mock
async def test_http_error_is_returned_not_raised() -> None:
    respx.get(f"{API}/v1/latest/hr").mock(
        return_value=Response(503, json={"detail": {"error": "OPENAI_API_KEY not set"}})
    )
    _reset_client()
    r = await server.latest_bills("hr")
    assert r["error"] == "http_503"
    assert "OPENAI_API_KEY" in str(r["detail"])


@respx.mock
async def test_get_vote_includes_members() -> None:
    respx.get(f"{API}/v1/votes/detail/s191-119.2026").mock(
        return_value=Response(
            200,
            json={
                "voteid": "s191-119.2026", "chamber": "s", "result": "Agreed to",
                "yea": 60, "nay": 40,
                "members": [
                    {"display_name": "Roe", "party": "R", "state": "TX", "position": "Nay"}
                ],
            },
        )
    )
    _reset_client()
    r = await server.get_vote("s191-119.2026")
    assert r["result"] == "Agreed to"
    assert r["members"][0]["name"] == "Roe"
