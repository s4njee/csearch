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

    redis_url: str = "redis://localhost:6379"

    openai_api_key: str = ""

    cache_ttl_seconds: int = 86400

    @classmethod
    def load(cls) -> Self:
        return cls()


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings.load()

