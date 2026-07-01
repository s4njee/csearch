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

    # Read-replica variants delegate to the primary methods so call capture and
    # behaviour are identical in tests (no replica configured).
    async def read_fetch(self, query: str, *args, **kwargs):
        return await self.fetch(query, *args, **kwargs)

    async def read_fetchrow(self, query: str, *args, **kwargs):
        return await self.fetchrow(query, *args, **kwargs)

    async def read_fetchval(self, query: str, *args, **kwargs):
        return await self.fetchval(query, *args, **kwargs)

    async def read_raw(self, query: str, *args, **kwargs):
        return await self.raw(query, *args, **kwargs)


class FakeCache:
    def __init__(self, allow_rate_limit: bool = True):
        self.values = {}
        self.allow_rate_limit = allow_rate_limit
        self.rate_limit_calls = []

    async def get(self, key: str):
        return self.values.get(key)

    async def set(self, key: str, value, ttl: int | None = None):
        self.values[key] = value

    async def rate_limit_allow(self, key: str, limit: int, window_seconds: int):
        self.rate_limit_calls.append((key, limit, window_seconds))
        return self.allow_rate_limit

    async def ping(self):
        return True

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

    # Read-replica variants delegate to the primary methods so call sequencing
    # and result sequencing are identical in tests (no replica configured).
    async def read_fetch(self, query: str, *args, **kwargs):
        return await self.fetch(query, *args, **kwargs)

    async def read_fetchrow(self, query: str, *args, **kwargs):
        return await self.fetchrow(query, *args, **kwargs)

    async def read_fetchval(self, query: str, *args, **kwargs):
        return await self.fetchval(query, *args, **kwargs)

    async def read_raw(self, query: str, *args, **kwargs):
        return await self.raw(query, *args, **kwargs)


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


def test_freshness():
    db = SequencedDB(
        fetchrow_results=[
            {
                "last_bill_action_at": "2026-05-06",
                "last_bill_update_at": "2026-05-07T10:00:00+00:00",
                "bills_updated_24h": 17,
                "bills_total": 60123,
            },
            {"last_vote_at": "2026-05-06T18:30:00+00:00", "votes_total": 1492},
        ]
    )
    client = build_client(db)
    response = client.get("/freshness")
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    body = response.json()
    assert body["bills_updated_24h"] == 17
    assert body["bills_total"] == 60123
    assert body["votes_total"] == 1492
    assert body["last_bill_action_at"] == "2026-05-06"
    assert body["last_vote_at"] == "2026-05-06T18:30:00+00:00"
    assert "now" in body


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
    # Pin vector-only mode so the assertions below target the vector SQL path.
    app = create_app(settings=Settings(openai_api_key="test-key", semantic_hybrid_enabled=False), db=db, cache=FakeCache())
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


def test_semantic_search_hybrid_fuses_keyword_and_vector():
    semantic._cb_failure_count = 0
    semantic._cb_open_until = 0.0

    class FakeEmbeddings:
        async def create(self, model, input, dimensions):
            return SimpleNamespace(data=[SimpleNamespace(embedding=[0.1, 0.2, 0.3])])

    class FakeOpenAI:
        def __init__(self, api_key: str):
            self.embeddings = FakeEmbeddings()

    # Vector arm returns hr1-119; keyword arm returns hr1-119 (overlap) + s2-119
    # (keyword-only). s2-119 is then hydrated. RRF should rank hr1-119 first.
    db = SequencedDB(
        fetch_results=[
            [{"bill_id": "hr1-119", "billtype": "hr", "billnumber": "1", "congress": "119",
              "sponsor_name": "Alice", "similarity": 0.9}],
            [{"billtype": "hr", "billnumber": "1", "congress": "119"},
             {"billtype": "s", "billnumber": "2", "congress": "119"}],
            [{"bill_id": "s2-119", "billtype": "s", "billnumber": "2", "congress": "119",
              "sponsor_name": "Bob", "similarity": None}],
        ],
    )
    app = create_app(settings=Settings(openai_api_key="test-key"), db=db, cache=FakeCache())
    app.state.openai_client = FakeOpenAI(api_key="test-key")
    client = TestClient(app)

    response = client.post("/search/semantic", json={"query": "clean drinking water"})
    assert response.status_code == 200
    body = response.json()
    assert [b["bill_id"] for b in body] == ["hr1-119", "s2-119"]
    assert body[0]["similarity"] == 0.9
    assert body[0]["sponsor_name"] == "Alice"
    assert body[1]["sponsor_name"] == "Bob"  # keyword-only bill was hydrated
    assert body[1]["similarity"] is None


def test_semantic_hybrid_degrades_to_keyword_when_embedding_fails():
    semantic._cb_failure_count = 0
    semantic._cb_open_until = 0.0

    class ExplodingEmbeddings:
        async def create(self, *args, **kwargs):
            raise RuntimeError("openai down")

    class FakeOpenAI:
        def __init__(self, api_key: str):
            self.embeddings = ExplodingEmbeddings()

    # Embedding fails → no vector arm. Keyword arm returns hr1-119, then hydrate.
    db = SequencedDB(
        fetch_results=[
            [{"billtype": "hr", "billnumber": "1", "congress": "119"}],
            [{"bill_id": "hr1-119", "billtype": "hr", "billnumber": "1", "congress": "119",
              "sponsor_name": "Alice", "similarity": None}],
        ],
    )
    app = create_app(settings=Settings(openai_api_key="test-key"), db=db, cache=FakeCache())
    app.state.openai_client = FakeOpenAI(api_key="test-key")
    client = TestClient(app)

    response = client.post("/search/semantic", json={"query": "clean drinking water"})
    assert response.status_code == 200
    body = response.json()
    # A list of keyword results, not the {degraded: true} object.
    assert isinstance(body, list)
    assert [b["bill_id"] for b in body] == ["hr1-119"]


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


def test_semantic_exact_bill_reference_skips_openai():
    class ExplodingEmbeddings:
        async def create(self, *args, **kwargs):
            raise AssertionError("OpenAI must not be called for an exact bill reference")

    class FakeOpenAI:
        def __init__(self, api_key: str):
            self.embeddings = ExplodingEmbeddings()

    db = FakeDB(rows=[{"billid": 1001, "bill_type": "hr", "bill_number": "42", "similarity": 1.0}])
    app = create_app(settings=Settings(openai_api_key="test-key"), db=db, cache=FakeCache())
    app.state.openai_client = FakeOpenAI(api_key="test-key")
    client = TestClient(app)

    response = client.post("/search/semantic", json={"query": "HR 42"})
    assert response.status_code == 200
    body = response.json()
    assert body[0]["bill_number"] == "42"
    # Direct lookup binds billtype/billnumber, not a vector string.
    assert db.last_args[0] == "hr"
    assert db.last_args[1] == 42
    assert "public.bills" in db.last_query


def test_semantic_query_too_long_is_rejected():
    db = FakeDB(rows=[])
    app = create_app(settings=Settings(openai_api_key="test-key", semantic_max_query_chars=20), db=db, cache=FakeCache())
    client = TestClient(app)
    response = client.post("/search/semantic", json={"query": "x" * 21})
    assert response.status_code == 413
    assert "too long" in response.json()["error"]


def test_semantic_rate_limit_returns_429():
    class FakeEmbeddings:
        async def create(self, model, input, dimensions):
            return SimpleNamespace(data=[SimpleNamespace(embedding=[0.1, 0.2, 0.3])])

    class FakeOpenAI:
        def __init__(self, api_key: str):
            self.embeddings = FakeEmbeddings()

    db = FakeDB(rows=[])
    app = create_app(
        settings=Settings(openai_api_key="test-key", semantic_rate_limit_per_minute=1),
        db=db,
        cache=FakeCache(allow_rate_limit=False),
    )
    app.state.openai_client = FakeOpenAI(api_key="test-key")
    client = TestClient(app)
    response = client.post("/search/semantic", json={"query": "a natural language policy question about climate"})
    assert response.status_code == 429
    assert response.headers["Retry-After"] == "60"


def test_semantic_coverage_reports_breakdowns():
    db = SequencedDB(
        fetchrow_results=[{"chunks_total": 100, "embeddings_total": 100, "bills_total": 40, "last_chunk_at": "2026-05-29T00:00:00+00:00"}],
        fetch_results=[
            [{"congress": 119, "chunks": 60}],
            [{"bill_type": "hr", "chunks": 80}],
            [{"model": "text-embedding-3-small", "embeddings": 100}],
        ],
        fetchval_results=[7],
    )
    client = build_client(db)
    response = client.get("/search/semantic/coverage")
    assert response.status_code == 200
    body = response.json()
    assert body["bills_missing_chunks"] == 7
    assert body["totals"]["chunks_total"] == 100
    assert body["chunks_by_congress"][0]["congress"] == 119


def test_metrics_endpoint_exposes_prometheus_text():
    client = build_client()
    client.get("/health")
    response = client.get("/metrics")
    # 200 when prometheus_client is installed, 501 when it is not.
    assert response.status_code in (200, 501)
    if response.status_code == 200:
        assert "csearch_requests_total" in response.text


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
    assert latest.headers.get("X-Cache") is None

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
