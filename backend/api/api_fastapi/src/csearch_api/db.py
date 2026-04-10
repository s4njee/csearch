from __future__ import annotations

import asyncpg

from .settings import Settings


class Database:
    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    @classmethod
    async def connect(cls, settings: Settings) -> "Database":
        pool = await asyncpg.create_pool(
            host=settings.postgresuri,
            port=settings.db_port,
            user=settings.db_user,
            password=settings.db_password,
            database=settings.db_name,
            min_size=2,
            max_size=20,
            statement_cache_size=0,
        )
        return cls(pool)

    async def close(self) -> None:
        await self.pool.close()

    async def fetch(self, query: str, *args):
        rows = await self.pool.fetch(query, *args)
        return [dict(row) for row in rows]

    async def fetchrow(self, query: str, *args):
        row = await self.pool.fetchrow(query, *args)
        return dict(row) if row is not None else None

    async def fetchval(self, query: str, *args):
        return await self.pool.fetchval(query, *args)

    async def raw(self, query: str, *args):
        rows = await self.pool.fetch(query, *args)
        return {"rows": [dict(row) for row in rows]}
