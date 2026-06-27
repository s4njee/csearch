from __future__ import annotations

from functools import lru_cache
from typing import Self

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    host: str = "0.0.0.0"
    port: int = 3000
    log_level: str = "info"

    postgresuri: str = "localhost"
    db_port: int = 5432
    db_user: str = "postgres"
    db_password: str = "postgres"
    db_name: str = "csearch"

    # Optional read-replica DSN (§1 docs/CRITICISMS2.md).
    # When non-empty, db.py opens a second asyncpg pool pointing at the
    # read-only replica (e.g. the CNPG cnpg-pooler-ro service).  All GET
    # route handlers should call db.read_fetch() instead of db.fetch() to
    # route reads to the replica.  Writes (scraper, NLP ingest) always use
    # the primary pool regardless of this setting.
    # Leave empty (default) to route all queries to the write pool, which is
    # the safe fallback and the current production behaviour.
    read_postgresuri: str = ""

    redis_url: str = "redis://localhost:6379"

    openai_api_key: str = ""

    cache_ttl_seconds: int = 86400

    # Bearer token for POST /admin/cache/reset (cache invalidation hook). Empty
    # disables the endpoint (returns 503). Set it and have the scraper/NLP
    # pipeline call the endpoint after an ingest so cached lists refresh.
    admin_token: str = ""

    # Comma-separated allowlist of CORS origins. "*" keeps the API fully open
    # (credentials are then disabled, per the CORS spec). Narrow this to known
    # origins in production to reduce the blast radius of abuse.
    cors_allow_origins: str = "*"

    # Guardrails for the OpenAI-backed semantic endpoint (denial-of-wallet
    # protection). Length cap is enforced before any embedding call; the rate
    # limit is per client IP over a rolling window and fails open if Redis is
    # unavailable.
    semantic_max_query_chars: int = 1000
    semantic_rate_limit_per_minute: int = 30

    # Coarse per-IP rate limit applied to all routes (health/readiness/metrics
    # excepted). 0 (default) disables it entirely — zero overhead. Fails open if
    # Redis is unavailable, like the semantic limiter.
    global_rate_limit_per_minute: int = 0

    # Circuit breaker for the OpenAI embedding call (§4 CRITICISMS2.md).
    # After `semantic_circuit_breaker_threshold` consecutive failures the
    # breaker opens and the endpoint returns keyword-degraded results instead
    # of a 5xx, so an OpenAI outage does not take semantic search down.
    # The breaker resets after `semantic_circuit_breaker_cooldown_seconds`.
    semantic_openai_timeout_seconds: float = 2.0
    semantic_circuit_breaker_threshold: int = 5
    semantic_circuit_breaker_cooldown_seconds: int = 60

    @classmethod
    def load(cls) -> Self:
        return cls()

    def cors_origin_list(self) -> list[str]:
        origins = [origin.strip() for origin in self.cors_allow_origins.split(",")]
        return [origin for origin in origins if origin]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings.load()

