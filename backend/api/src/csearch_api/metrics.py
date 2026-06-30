from __future__ import annotations

"""Prometheus instrumentation for the FastAPI app.

Kept dependency-light: if ``prometheus_client`` is not installed the helpers
degrade to no-ops and ``/metrics`` returns 501, so the package still imports and
the test suite still runs. In the built image the dependency is present and the
endpoint serves a standard exposition payload for scraping.
"""

try:  # pragma: no cover - exercised via integration, not unit tests
    from prometheus_client import (
        CONTENT_TYPE_LATEST,
        Counter,
        Gauge,
        Histogram,
        generate_latest,
    )

    AVAILABLE = True
except ImportError:  # pragma: no cover
    AVAILABLE = False
    CONTENT_TYPE_LATEST = "text/plain"

if AVAILABLE:
    REQUESTS = Counter(
        "csearch_requests_total",
        "API requests by route, method, and status class.",
        ["route", "method", "status"],
    )
    REQUEST_DURATION = Histogram(
        "csearch_request_duration_seconds",
        "API request duration in seconds by route and method.",
        ["route", "method"],
    )
    CACHE = Counter(
        "csearch_cache_total",
        "Cache outcomes recorded on responses.",
        ["result"],
    )
    SEMANTIC = Counter(
        "csearch_semantic_total",
        "Semantic search calls by routing decision and OpenAI status.",
        ["route", "openai_status"],
    )
    SEMANTIC_LATENCY = Histogram(
        "csearch_semantic_latency_seconds",
        "Semantic search latency in seconds by routing decision.",
        ["route"],
    )
    # Freshness gauges (unix timestamps / counts) refreshed on each /metrics
    # scrape so alerting rules can fire on stale data and missed jobs.
    FRESHNESS = Gauge(
        "csearch_freshness_timestamp_seconds",
        "Unix timestamp of the most recent signal, by kind.",
        ["kind"],
    )
    CORPUS = Gauge(
        "csearch_corpus_total",
        "Row counts for core corpora, by kind.",
        ["kind"],
    )


def observe_request(route: str, method: str, status_code: int, duration_seconds: float, cache_result: str) -> None:
    if not AVAILABLE:
        return
    status_class = f"{status_code // 100}xx"
    REQUESTS.labels(route=route, method=method, status=status_class).inc()
    REQUEST_DURATION.labels(route=route, method=method).observe(duration_seconds)
    CACHE.labels(result=cache_result or "NONE").inc()


def observe_semantic(route: str, openai_status: str, latency_seconds: float) -> None:
    if not AVAILABLE:
        return
    SEMANTIC.labels(route=route, openai_status=openai_status).inc()
    SEMANTIC_LATENCY.labels(route=route).observe(latency_seconds)


def set_freshness(kind: str, timestamp_seconds: float | None) -> None:
    if AVAILABLE and timestamp_seconds is not None:
        FRESHNESS.labels(kind=kind).set(timestamp_seconds)


def set_corpus(kind: str, count: int | None) -> None:
    if AVAILABLE and count is not None:
        CORPUS.labels(kind=kind).set(count)


def render() -> tuple[bytes, str] | None:
    """Return (payload, content_type) or None when metrics are unavailable."""
    if not AVAILABLE:
        return None
    return generate_latest(), CONTENT_TYPE_LATEST
