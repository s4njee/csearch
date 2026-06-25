from __future__ import annotations

import asyncpg

from .settings import Settings


class Database:
    def __init__(self, pool: asyncpg.Pool, read_pool: asyncpg.Pool | None = None):
        self.pool = pool
        # read_pool points at the read-only replica when READ_POSTGRESURI is set.
        # Falls back to the primary pool when None so callers need no special-casing.
        self._read_pool = read_pool or pool

    # --- Connection lifecycle ---

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

        # Open a separate read pool when a replica DSN is configured (§1 CRITICISMS2.md).
        read_pool: asyncpg.Pool | None = None
        if settings.read_postgresuri:
            read_pool = await asyncpg.create_pool(
                host=settings.read_postgresuri,
                port=settings.db_port,
                user=settings.db_user,
                password=settings.db_password,
                database=settings.db_name,
                min_size=1,
                max_size=10,
                statement_cache_size=0,
            )

        return cls(pool, read_pool)

    async def close(self) -> None:
        await self.pool.close()
        if self._read_pool is not self.pool:
            await self._read_pool.close()

    # --- Query helpers ---

    async def fetch(self, query: str, *args, timeout: float | None = None, hnsw_ef_search: int | None = None):
        # Only set by semantic search routes to tune pgvector HNSW recall.
        if hnsw_ef_search is not None:
            async with self.pool.acquire() as conn:
                async with conn.transaction():
                    await conn.execute("SELECT set_config('hnsw.ef_search', $1, true)", str(hnsw_ef_search))
                    rows = await conn.fetch(query, *args, timeout=timeout)
        else:
            rows = await self.pool.fetch(query, *args, timeout=timeout)
        return [dict(row) for row in rows]

    async def read_fetch(self, query: str, *args, timeout: float | None = None, hnsw_ef_search: int | None = None):
        """Route a read query to the replica pool when one is configured.

        Drop-in replacement for fetch() in GET route handlers. When no
        READ_POSTGRESURI is set, _read_pool is the primary pool, so behaviour
        is identical to fetch() and no code path diverges (\u00a71 CRITICISMS2.md).
        """
        if hnsw_ef_search is not None:
            async with self._read_pool.acquire() as conn:
                async with conn.transaction():
                    await conn.execute("SELECT set_config('hnsw.ef_search', $1, true)", str(hnsw_ef_search))
                    rows = await conn.fetch(query, *args, timeout=timeout)
        else:
            rows = await self._read_pool.fetch(query, *args, timeout=timeout)
        return [dict(row) for row in rows]

    async def fetchrow(self, query: str, *args, timeout: float | None = None):
        row = await self.pool.fetchrow(query, *args, timeout=timeout)
        return dict(row) if row is not None else None

    async def fetchval(self, query: str, *args, timeout: float | None = None):
        return await self.pool.fetchval(query, *args, timeout=timeout)

    async def raw(self, query: str, *args, timeout: float | None = None):
        rows = await self.pool.fetch(query, *args, timeout=timeout)
        return {"rows": [dict(row) for row in rows]}
