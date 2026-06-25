from __future__ import annotations

import json
import logging

from redis.asyncio import Redis

logger = logging.getLogger(__name__)

TTL_SECONDS = 60 * 60 * 24
EXPLORE_TTL_SECONDS = 60 * 60 * 12
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

    # Cache failures are non-fatal — the route still serves uncached data.

    async def get(self, key: str):
        try:
            raw = await self.redis.get(f"{KEY_PREFIX}{key}")
        except Exception as e:
            logger.warning("cache error: %s", e)
            return None
        if raw is None:
            return None
        try:
            return json.loads(raw)
        except Exception as e:
            logger.warning("cache error: %s", e)
            return None

    async def set(self, key: str, value, ttl: int | None = None) -> None:
        try:
            await self.redis.set(f"{KEY_PREFIX}{key}", json.dumps(value, default=str), ex=ttl or TTL_SECONDS)
        except Exception as e:
            logger.warning("cache error: %s", e)
            return None

    async def rate_limit_allow(self, key: str, limit: int, window_seconds: int) -> bool:
        """Fixed-window per-key rate limiter shared across API pods via Redis.

        Returns True if the call is within budget. Fails open: if Redis is
        unreachable the request is allowed rather than dropped, so a cache
        outage never takes the API down.
        """
        if limit <= 0:
            return True
        redis_key = f"{KEY_PREFIX}ratelimit:{key}"
        try:
            count = await self.redis.incr(redis_key)
            if count == 1:
                await self.redis.expire(redis_key, window_seconds)
            return count <= limit
        except Exception as e:
            logger.warning("rate limit error: %s", e)
            return True

    async def reset(self) -> None:
        try:
            async for key in self.redis.scan_iter(match=f"{KEY_PREFIX}*"):
                await self.redis.delete(key)
        except Exception as e:
            logger.warning("cache error: %s", e)
            return None

    async def close(self) -> None:
        await self.redis.aclose()
