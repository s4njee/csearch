from __future__ import annotations

import json

from redis.asyncio import Redis

TTL_SECONDS = 60 * 60 * 24
KEY_PREFIX = "csearch:"


class Cache:
    def __init__(self, redis: Redis):
        self.redis = redis

    @classmethod
    def connect(cls, redis_url: str) -> "Cache":
        return cls(
            Redis.from_url(
                redis_url,
                decode_responses=True,
                socket_connect_timeout=1,
                socket_timeout=1,
                retry_on_timeout=True,
            )
        )

    async def get(self, key: str):
        try:
            raw = await self.redis.get(f"{KEY_PREFIX}{key}")
        except Exception:
            return None
        if raw is None:
            return None
        try:
            return json.loads(raw)
        except Exception:
            return None

    async def set(self, key: str, value) -> None:
        try:
            await self.redis.set(f"{KEY_PREFIX}{key}", json.dumps(value, default=str), ex=TTL_SECONDS)
        except Exception:
            return None

    async def reset(self) -> None:
        try:
            async for key in self.redis.scan_iter(match=f"{KEY_PREFIX}*"):
                await self.redis.delete(key)
        except Exception:
            return None

    async def close(self) -> None:
        await self.redis.aclose()

