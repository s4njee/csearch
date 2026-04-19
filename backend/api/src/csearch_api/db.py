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

    async def fetch(self, query: str, *args, timeout: float | None = None, hnsw_ef_search: int | None = None):
        if hnsw_ef_search is not None:
            async with self.pool.acquire() as conn:
                async with conn.transaction():
                    await conn.execute("SELECT set_config('hnsw.ef_search', $1, true)", str(hnsw_ef_search))
                    rows = await conn.fetch(query, *args, timeout=timeout)
        else:
            rows = await self.pool.fetch(query, *args, timeout=timeout)
        return [dict(row) for row in rows]

    async def fetchrow(self, query: str, *args, timeout: float | None = None):
        row = await self.pool.fetchrow(query, *args, timeout=timeout)
        return dict(row) if row is not None else None

    async def fetchval(self, query: str, *args, timeout: float | None = None):
        return await self.pool.fetchval(query, *args, timeout=timeout)

    async def raw(self, query: str, *args, timeout: float | None = None):
        rows = await self.pool.fetch(query, *args, timeout=timeout)
        return {"rows": [dict(row) for row in rows]}
