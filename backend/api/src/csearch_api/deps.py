"""FastAPI dependency providers.

Routes use ``Depends(get_db)`` / ``Depends(get_cache)`` instead of reaching into
``request.app.state`` directly. This keeps handler signatures explicit and lets
tests override a single dependency via ``app.dependency_overrides`` when needed.
The providers read from app state, which is populated in the lifespan / by
``create_app(db=..., cache=...)``.
"""

from __future__ import annotations

from fastapi import Request

from .cache import Cache
from .db import Database
from .settings import Settings


def get_db(request: Request) -> Database:
    return request.app.state.db


def get_cache(request: Request) -> Cache:
    return request.app.state.cache


def get_app_settings(request: Request) -> Settings:
    return request.app.state.settings
