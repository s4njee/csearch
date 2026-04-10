from __future__ import annotations

from dataclasses import dataclass, field

from fastapi.testclient import TestClient

from csearch_api.main import create_app


@dataclass
class FakeDB:
    rows: list[dict] = field(default_factory=list)
    single_value: int = 1
    row: dict | None = None
    last_query: str | None = None
    last_args: tuple = ()

    async def fetch(self, query: str, *args):
        self.last_query = query
        self.last_args = args
        return self.rows

    async def fetchrow(self, query: str, *args):
        self.last_query = query
        self.last_args = args
        return self.row

    async def fetchval(self, query: str, *args):
        self.last_query = query
        self.last_args = args
        return self.single_value

    async def raw(self, query: str, *args):
        self.last_query = query
        self.last_args = args
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

    async def fetch(self, query: str, *args):
        self.calls.append(("fetch", query, args))
        return self.fetch_results.pop(0) if self.fetch_results else []

    async def fetchrow(self, query: str, *args):
        self.calls.append(("fetchrow", query, args))
        return self.fetchrow_results.pop(0) if self.fetchrow_results else None

    async def fetchval(self, query: str, *args):
        self.calls.append(("fetchval", query, args))
        return self.fetchval_results.pop(0) if self.fetchval_results else 1

    async def raw(self, query: str, *args):
        self.calls.append(("raw", query, args))
        return self.raw_results.pop(0) if self.raw_results else {"rows": []}


def build_client(db: FakeDB | None = None):
    app = create_app(db=db or FakeDB(), cache=FakeCache())
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
