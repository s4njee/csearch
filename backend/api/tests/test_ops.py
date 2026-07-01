from __future__ import annotations

from datetime import date, datetime

from fastapi.testclient import TestClient

from csearch_api.main import create_app
from csearch_api.settings import Settings
from test_routes import FakeCache, FakeDB, SequencedDB, build_client


def test_livez_has_no_dependencies():
    client = build_client()
    response = client.get("/livez")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readyz_ok_when_db_and_cache_up():
    client = build_client(FakeDB(single_value=1))
    response = client.get("/readyz")
    assert response.status_code == 200
    body = response.json()
    assert body["db"] == "connected"
    assert body["cache"] == "connected"


def test_readyz_503_when_db_down():
    class BrokenDB(FakeDB):
        async def fetchval(self, query: str, *args, **kwargs):
            raise RuntimeError("db down")

    client = build_client(BrokenDB())
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json()["db"] == "disconnected"


def test_request_id_minted_and_echoed():
    client = build_client()
    # Minted when absent.
    minted = client.get("/livez")
    assert minted.headers.get("x-request-id")
    # Echoed when provided.
    echoed = client.get("/livez", headers={"X-Request-ID": "trace-123"})
    assert echoed.headers["x-request-id"] == "trace-123"


def test_admin_cache_reset_disabled_by_default():
    client = build_client()
    assert client.post("/admin/cache/reset").status_code == 503


def test_admin_cache_reset_requires_matching_token():
    app = create_app(settings=Settings(admin_token="sekret"), db=FakeDB(), cache=FakeCache())
    client = TestClient(app)
    assert client.post("/admin/cache/reset", headers={"X-Admin-Token": "wrong"}).status_code == 403
    ok = client.post("/admin/cache/reset", headers={"X-Admin-Token": "sekret"})
    assert ok.status_code == 200
    assert ok.json() == {"reset": True}


def test_cache_version_is_uncached_and_db_derived():
    db = SequencedDB(
        fetchrow_results=[
            {"bills_version": date(2026, 7, 1), "bill_actions_version": date(2026, 6, 29)},
            {"votes_version": date(2026, 6, 30)},
            {"semantic_version": datetime(2026, 7, 1, 12, 30, 0)},
        ]
    )
    app = create_app(db=db, cache=FakeCache())
    client = TestClient(app)

    response = client.get("/cache-version")

    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    body = response.json()
    assert body["bills_version"] == "2026-07-01"
    assert body["votes_version"] == "2026-06-30"
    assert body["explore_version"] == "2026-07-01"
    assert body["semantic_version"] == "2026-07-01T12:30:00"


def test_cache_version_tolerates_missing_semantic_schema():
    class MissingSemanticDB(SequencedDB):
        async def fetchrow(self, query: str, *args, **kwargs):
            if "nlp.bill_chunks" in query:
                raise RuntimeError("schema missing")
            return await super().fetchrow(query, *args, **kwargs)

    db = MissingSemanticDB(
        fetchrow_results=[
            {"bills_version": date(2026, 7, 1), "bill_actions_version": None},
            {"votes_version": date(2026, 6, 30)},
        ]
    )
    app = create_app(db=db, cache=FakeCache())
    client = TestClient(app)

    response = client.get("/cache-version")

    assert response.status_code == 200
    assert response.json()["semantic_version"] is None


def test_latest_bills_pagination_applies_limit_and_offset():
    db = FakeDB(rows=[])
    client = build_client(db)
    response = client.get("/latest/hr?limit=10&offset=5")
    assert response.status_code == 200
    assert "LIMIT 10 OFFSET 5" in db.last_query


def test_latest_bills_limit_is_clamped_to_max():
    db = FakeDB(rows=[])
    client = build_client(db)
    client.get("/latest/hr?limit=99999")
    assert "LIMIT 500 OFFSET 0" in db.last_query


def test_bills_by_number_is_not_redis_cached():
    class CountingDB(FakeDB):
        calls = 0

        async def fetch(self, query: str, *args, **kwargs):
            self.calls += 1
            return await super().fetch(query, *args, **kwargs)

    db = CountingDB(rows=[{"billid": 1, "billtype": "hr", "congress": "119", "billnumber": "42"}])
    client = build_client(db)
    first = client.get("/bills/bynumber/42")
    assert first.headers.get("X-Cache") is None
    second = client.get("/bills/bynumber/42")
    assert second.headers.get("X-Cache") is None
    assert db.calls == 2


def test_global_rate_limit_returns_429_when_enabled():
    app = create_app(
        settings=Settings(global_rate_limit_per_minute=1),
        db=FakeDB(),
        cache=FakeCache(allow_rate_limit=False),
    )
    client = TestClient(app)
    response = client.get("/committees")
    assert response.status_code == 429
    assert response.headers["Retry-After"] == "60"


def test_global_rate_limit_exempts_probes():
    app = create_app(
        settings=Settings(global_rate_limit_per_minute=1),
        db=FakeDB(single_value=1),
        cache=FakeCache(allow_rate_limit=False),
    )
    client = TestClient(app)
    # Probe endpoints must never be rate limited.
    assert client.get("/livez").status_code == 200
    assert client.get("/health").status_code == 200
