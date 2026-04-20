from __future__ import annotations

from dataclasses import dataclass, field
from types import SimpleNamespace

from fastapi.testclient import TestClient

from csearch_api.main import create_app
from csearch_api.routes import semantic
from csearch_api.settings import Settings


@dataclass
class FakeDB:
    rows: list[dict] = field(default_factory=list)
    single_value: int = 1
    row: dict | None = None
    last_query: str | None = None
    last_args: tuple = ()
    last_kwargs: dict = field(default_factory=dict)

    async def fetch(self, query: str, *args, **kwargs):
        self.last_query = query
        self.last_args = args
        self.last_kwargs = kwargs
        return self.rows

    async def fetchrow(self, query: str, *args, **kwargs):
        self.last_query = query
        self.last_args = args
        self.last_kwargs = kwargs
        return self.row

    async def fetchval(self, query: str, *args, **kwargs):
        self.last_query = query
        self.last_args = args
        self.last_kwargs = kwargs
        return self.single_value

    async def raw(self, query: str, *args, **kwargs):
        self.last_query = query
        self.last_args = args
        self.last_kwargs = kwargs
        return {"rows": self.rows}


class FakeCache:
    def __init__(self):
        self.values = {}

    async def get(self, key: str):
        return self.values.get(key)

    async def set(self, key: str, value):
        self.values[key] = value

    async def reset(self):
        self.values.clear()

    async def close(self):
        return None


class SequencedDB:
    def __init__(self, *, fetch_results=None, fetchrow_results=None, raw_results=None, fetchval_results=None):
        self.fetch_results = list(fetch_results or [])
        self.fetchrow_results = list(fetchrow_results or [])
        self.raw_results = list(raw_results or [])
        self.fetchval_results = list(fetchval_results or [])
        self.calls = []

    async def fetch(self, query: str, *args, **kwargs):
        self.calls.append(("fetch", query, args))
        return self.fetch_results.pop(0) if self.fetch_results else []

    async def fetchrow(self, query: str, *args, **kwargs):
        self.calls.append(("fetchrow", query, args))
        return self.fetchrow_results.pop(0) if self.fetchrow_results else None

    async def fetchval(self, query: str, *args, **kwargs):
        self.calls.append(("fetchval", query, args))
        return self.fetchval_results.pop(0) if self.fetchval_results else 1

    async def raw(self, query: str, *args, **kwargs):
        self.calls.append(("raw", query, args))
        return self.raw_results.pop(0) if self.raw_results else {"rows": []}


def build_client(db: FakeDB | None = None):
    app = create_app(db=db or FakeDB(), cache=FakeCache())
    return TestClient(app)


def build_client_with_settings(db: FakeDB | None = None, settings: Settings | None = None):
    app = create_app(settings=settings or Settings(openai_api_key="test-key"), db=db or FakeDB(), cache=FakeCache())
    return TestClient(app)


def test_root():
    client = build_client()
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"root": True}


def test_health():
    client = build_client(FakeDB(single_value=1))
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "connected"}


def test_latest_billtype_validation():
    client = build_client()
    response = client.get("/latest/invalid")
    assert response.status_code == 400
    assert response.json() == {"error": "Invalid bill type"}


def test_search_requires_query():
    client = build_client()
    response = client.get("/search/hr/relevance")
    assert response.status_code == 400
    assert response.json() == {"error": "Missing required query parameter"}


def test_bill_detail():
    db = SequencedDB(
        fetchrow_results=[{
            "billid": 1001,
            "billnumber": "42",
            "billtype": "hr",
            "congress": "119",
            "shorttitle": "Test Infrastructure Act",
            "officialtitle": "A bill to invest in test infrastructure",
            "introducedat": "2025-01-15",
            "statusat": "2025-03-01",
            "bill_status": "passed",
            "summary_text": "Provides funding for automated testing infrastructure.",
            "summary_date": "2025-01-20",
            "sponsor_name": "Jane Doe",
            "sponsor_party": "D",
            "sponsor_state": "CA",
            "sponsor_bioguide_id": "D000001",
            "origin_chamber": "House",
            "policy_area": "Science, Technology, Communications",
            "update_date": "2025-03-01",
            "latest_action_date": "2025-03-01",
        }],
        fetch_results=[
            [{"acted_at": "2025-01-15", "action_text": "Introduced in House"}],
            [{"bioguide_id": "S000001", "full_name": "John Smith"}],
            [{"voteid": "h42-119.2025"}],
            [{"committee_code": "HSAG"}],
        ],
    )
    client = build_client(db)
    response = client.get("/bills/hr/119/42")
    assert response.status_code == 200
    body = response.json()
    assert body["billid"] == 1001
    assert len(body["actions"]) == 1
    assert len(body["cosponsors"]) == 1
    assert len(body["votes"]) == 1
    assert len(body["committees"]) == 1


def test_representatives_by_zip_returns_current_members_for_zip_districts():
    db = SequencedDB(
        fetch_results=[
            [
                {"state_abbr": "CA", "cd": 30},
                {"state_abbr": "CA", "cd": 32},
                {"state_abbr": "CA", "cd": 36},
            ],
            [
                {
                    "bioguide_id": "P000145",
                    "name": "Sen. Padilla, Alex [D-CA]",
                    "party": "D",
                    "state": "CA",
                    "chamber": "senate",
                    "district": None,
                },
                {
                    "bioguide_id": "S001150",
                    "name": "Sen. Schiff, Adam B. [D-CA]",
                    "party": "D",
                    "state": "CA",
                    "chamber": "senate",
                    "district": None,
                },
            ],
            [
                {
                    "bioguide_id": "F000483",
                    "name": "Rep. Friedman, Laura [D-CA-30]",
                    "party": "D",
                    "state": "CA",
                    "chamber": "house",
                    "district": 30,
                },
                {
                    "bioguide_id": "S000344",
                    "name": "Rep. Sherman, Brad [D-CA-32]",
                    "party": "D",
                    "state": "CA",
                    "chamber": "house",
                    "district": 32,
                },
                {
                    "bioguide_id": "L000582",
                    "name": "Rep. Lieu, Ted [D-CA-36]",
                    "party": "D",
                    "state": "CA",
                    "chamber": "house",
                    "district": 36,
                },
            ],
        ],
        fetchval_results=[119],
    )
    client = build_client(db)

    response = client.get("/representatives/90210")

    assert response.status_code == 200
    body = response.json()
    assert body["zipcode"] == "90210"
    assert body["districts"] == [
        {"state": "CA", "district": 30},
        {"state": "CA", "district": 32},
        {"state": "CA", "district": 36},
    ]
    assert [senator["name"] for senator in body["senators"]] == ["Alex Padilla", "Adam B. Schiff"]
    assert [rep["name"] for rep in body["representatives"]] == ["Laura Friedman", "Brad Sherman", "Ted Lieu"]
    assert body["housemembers"] == body["representatives"]
    assert [rep["district"] for rep in body["representatives"]] == [30, 32, 36]
    assert [call[0] for call in db.calls] == ["fetch", "fetchval", "fetch", "fetch"]
    assert db.calls[0][2] == ("90210",)
    assert db.calls[2][2] == ("90210", 119)
    assert db.calls[3][2] == ("90210", 119)


def test_representatives_query_param_matches_zip_route():
    db = SequencedDB(
        fetch_results=[
            [{"state_abbr": "CA", "cd": 30}],
            [],
            [
                {
                    "bioguide_id": "F000483",
                    "name": "Rep. Friedman, Laura [D-CA-30]",
                    "party": "D",
                    "state": "CA",
                    "chamber": "house",
                    "district": 30,
                }
            ],
        ],
        fetchval_results=[119],
    )
    client = build_client(db)

    response = client.get("/representatives?zip=90210")

    assert response.status_code == 200
    assert response.json()["representatives"][0]["name"] == "Laura Friedman"
    assert db.calls[0][2] == ("90210",)


def test_representatives_rejects_invalid_zip():
    client = build_client()

    response = client.get("/representatives/abc")

    assert response.status_code == 400
    assert response.json() == {"error": "ZIP code must be exactly 5 digits"}


def test_semantic_search_returns_bill_metadata():
    class FakeEmbeddings:
        async def create(self, model: str, input: list[str], dimensions: int):
            assert model == "text-embedding-3-small"
            assert input == ["testing infrastructure"]
            assert dimensions == 1536
            return SimpleNamespace(data=[SimpleNamespace(embedding=[0.1, 0.2, 0.3])])

    class FakeOpenAI:
        def __init__(self, api_key: str):
            self.embeddings = FakeEmbeddings()

    db = FakeDB(rows=[{
        "bill_id": "hr42-119",
        "congress": 119,
        "bill_type": "hr",
        "bill_number": "42",
        "title": "Test Infrastructure Act",
        "status": "active",
        "body": "Build test infrastructure",
        "chunk_type": "section",
        "section_header": "Summary",
        "billid": 1001,
        "shorttitle": "Test Infrastructure Act",
        "officialtitle": "A bill to invest in test infrastructure",
        "introducedat": "2025-01-15",
        "summary_text": "Provides funding for automated testing infrastructure.",
        "sponsor_name": "Jane Doe",
        "sponsor_party": "D",
        "sponsor_state": "CA",
        "sponsor_bioguide_id": "D000001",
        "bill_status": "passed",
        "statusat": "2025-03-01",
        "policy_area": "Science, Technology, Communications",
        "latest_action_date": "2025-03-01",
        "origin_chamber": "House",
        "cosponsor_count": 12,
        "similarity": 0.98,
    }])
    app = create_app(settings=Settings(openai_api_key="test-key"), db=db, cache=FakeCache())
    app.state.openai_client = FakeOpenAI(api_key="test-key")
    client = TestClient(app)

    response = client.post("/search/semantic", json={"query": "testing infrastructure"})
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["sponsor_name"] == "Jane Doe"
    assert body[0]["cosponsor_count"] == 12
    assert body[0]["policy_area"] == "Science, Technology, Communications"
    assert "JOIN public.bills" in db.last_query
    assert db.last_args[3] == 500
    assert db.last_args[4] == 50
    assert db.last_kwargs["timeout"] == 10.0
    assert db.last_kwargs["hnsw_ef_search"] == 500


def test_semantic_warmup_reuses_cached_embedding():
    semantic._warmup_vector_str = None

    class FakeEmbeddings:
        def __init__(self):
            self.calls = 0

        async def create(self, model: str, input: list[str], dimensions: int):
            self.calls += 1
            assert model == "text-embedding-3-small"
            assert input == ["bills about climate"]
            assert dimensions == 1536
            return SimpleNamespace(data=[SimpleNamespace(embedding=[0.1, 0.2, 0.3])])

    class FakeOpenAI:
        def __init__(self, api_key: str):
            self.embeddings = FakeEmbeddings()

    db = FakeDB(rows=[{"bill_id": "hr42-119", "similarity": 0.98}])
    app = create_app(settings=Settings(openai_api_key="test-key"), db=db, cache=FakeCache())
    app.state.openai_client = FakeOpenAI(api_key="test-key")
    client = TestClient(app)

    first = client.post("/search/semantic/warmup")
    second = client.post("/search/semantic/warmup")

    assert first.status_code == 200
    assert first.json()["cache_hit"] is False
    assert first.json()["rows"] == 1
    assert second.status_code == 200
    assert second.json()["cache_hit"] is True
    assert app.state.openai_client.embeddings.calls == 1
    assert db.last_args[3] == 500
    assert db.last_args[4] == 1


def test_votes_latest_and_detail_and_explore():
    db = SequencedDB(
        fetch_results=[
            [{"voteid": "h1-119.2025", "congress": "119"}],
            [{"bioguide_id": "A000001", "display_name": "Alex Example"}],
        ],
        fetchrow_results=[
            {
                "voteid": "h1-119.2025",
                "bill_type": "hr",
                "bill_number": "42",
                "congress": "119",
                "votenumber": "1",
                "votedate": "2025-02-15",
                "question": "On Passage",
                "result": "Passed",
                "votesession": "2025",
                "chamber": "h",
                "source_url": "https://example.invalid",
                "votetype": "YEA-AND-NAY",
            },
        ],
        raw_results=[
            {"rows": [{"count": 42}]},
        ],
    )
    client = build_client(db)

    latest = client.get("/votes/house")
    assert latest.status_code == 200
    assert latest.headers.get("X-Cache") == "MISS"

    detail = client.get("/votes/detail/h1-119.2025")
    assert detail.status_code == 200
    assert detail.json()["members"][0]["display_name"] == "Alex Example"

    explore_list = client.get("/explore")
    assert explore_list.status_code == 200
    assert len(explore_list.json()["queries"]) == 19

    explore_run = client.get("/explore/recent-bills")
    assert explore_run.status_code == 200
    assert explore_run.json()["results"][0]["count"] == 42


def test_bills_by_number():
    db = SequencedDB(
        fetch_results=[
            [{"billid": 1, "billtype": "hr", "congress": "119", "billnumber": "42"}],
        ],
    )
    client = build_client(db)
    response = client.get("/bills/bynumber/42")
    assert response.status_code == 200
    assert response.json()[0]["billnumber"] == "42"


def test_member_detail():
    db = SequencedDB(
        fetchrow_results=[
            {"name": "Alex Example", "party": "D", "state": "CA"},
            {"total": 2},
            {"total": 3},
        ],
        fetch_results=[
            [{"billid": 1, "billnumber": "42", "billtype": "hr", "congress": "119"}],
            [{"voteid": "h1-119.2025"}],
        ],
    )
    client = build_client(db)
    response = client.get("/members/abc123")
    assert response.status_code == 200
    body = response.json()
    assert body["bioguide_id"] == "ABC123"
    assert body["counts"] == {"sponsored": 2, "cosponsored": 3}
    assert len(body["sponsoredBills"]) == 1
    assert len(body["recentVotes"]) == 1


def test_member_lookup_fallback_and_validation():
    db = SequencedDB(
        fetchrow_results=[
            None,
            None,
            {"name": "Committee Sponsor", "party": "R", "state": "TX"},
            {"total": 0},
            {"total": 0},
        ],
        fetch_results=[[], []],
    )
    client = build_client(db)

    response = client.get("/members/xy99")
    assert response.status_code == 200
    assert response.json()["name"] == "Committee Sponsor"

    invalid = client.get("/members/!!bad")
    assert invalid.status_code == 400
    assert invalid.json() == {"error": "Invalid bioguide ID format"}


def test_committees_and_committee_detail():
    db = SequencedDB(
        fetch_results=[
            [{"committee_code": "HSAG", "committee_name": "Agriculture", "chamber": "house", "bill_count": 1}],
            [{"billid": 1, "billnumber": "42", "billtype": "hr", "congress": "119"}],
        ],
        fetchrow_results=[
            {"committee_code": "HSAG", "committee_name": "Agriculture", "chamber": "house"},
        ],
    )
    client = build_client(db)

    committees = client.get("/committees")
    assert committees.status_code == 200
    assert committees.json()[0]["committee_code"] == "HSAG"

    detail = client.get("/committees/HSAG")
    assert detail.status_code == 200
    assert detail.json()["bills"][0]["billid"] == 1


def test_committee_detail_missing():
    db = SequencedDB(fetchrow_results=[None])
    client = build_client(db)
    response = client.get("/committees/XXXX")
    assert response.status_code == 404
    assert response.json() == {"error": "Committee not found"}
