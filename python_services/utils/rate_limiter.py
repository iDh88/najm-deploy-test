"""
Rate Limiter — Crew Intelligence Platform
Enforces per-user, per-tier daily AI query limits using Firestore counters.
Free tier: 5 queries/day
Pro tier: unlimited
Elite/Enterprise: unlimited
"""

from fastapi import Request, HTTPException
from functools import wraps
from datetime import datetime, date
import logging

logger = logging.getLogger("cip.rate_limiter")

# ─── Tier limits ─────────────────────────────────────────────────────────────
DAILY_LIMITS: dict[str, int | None] = {
    "free":       5,
    "pro":        None,   # unlimited
    "elite":      None,
    "enterprise": None,
}

UPLOAD_LIMITS: dict[str, int | None] = {
    "free":       5,
    "pro":        None,
    "elite":      None,
    "enterprise": None,
}


class RateLimiter:
    """
    Firestore-backed rate limiter.
    Counter document path: rateLimits/{userId}_{date}_{action}
    """

    def __init__(self):
        self._db = None

    def _get_db(self):
        if self._db is None:
            from utils.firebase import get_firestore
            self._db = get_firestore()
        return self._db

    def _counter_key(self, user_id: str, action: str) -> str:
        today = date.today().isoformat()
        return f"{user_id}_{today}_{action}"

    async def check_and_increment(
        self,
        user_id: str,
        tier: str,
        action: str = "ai_query",
    ) -> tuple[bool, int, int | None]:
        """
        Check if the user is within their rate limit, then increment counter.

        Returns:
            (allowed: bool, current_count: int, limit: int | None)
        """
        limit_map = DAILY_LIMITS if action == "ai_query" else UPLOAD_LIMITS
        limit = limit_map.get(tier)

        # Unlimited tiers — always allow, still track for analytics
        if limit is None:
            await self._increment_counter(user_id, action)
            count = await self._get_count(user_id, action)
            return True, count, None

        # Check current count
        count = await self._get_count(user_id, action)

        if count >= limit:
            logger.info(f"Rate limit hit: user={user_id}, tier={tier}, action={action}, count={count}/{limit}")
            return False, count, limit

        # Within limit — increment
        new_count = await self._increment_counter(user_id, action)
        return True, new_count, limit

    async def _get_count(self, user_id: str, action: str) -> int:
        try:
            db = self._get_db()
            key = self._counter_key(user_id, action)
            doc = db.collection("rateLimits").document(key).get()
            if doc.exists:
                return doc.to_dict().get("count", 0)
            return 0
        except Exception as e:
            logger.warning(f"Rate limit read failed (permitting): {e}")
            return 0  # Fail open — don't block on infrastructure errors

    async def _increment_counter(self, user_id: str, action: str) -> int:
        try:
            from google.cloud.firestore import Increment
            db = self._get_db()
            key = self._counter_key(user_id, action)
            ref = db.collection("rateLimits").document(key)
            ref.set(
                {
                    "userId": user_id,
                    "action": action,
                    "date": date.today().isoformat(),
                    "count": Increment(1),
                    "lastUpdated": datetime.utcnow(),
                },
                merge=True,
            )
            doc = ref.get()
            return doc.to_dict().get("count", 1) if doc.exists else 1
        except Exception as e:
            logger.warning(f"Rate limit increment failed: {e}")
            return 0

    async def get_usage(self, user_id: str, action: str = "ai_query") -> dict:
        """Return current usage stats for a user."""
        count = await self._get_count(user_id, action)
        return {
            "userId": user_id,
            "action": action,
            "date": date.today().isoformat(),
            "count": count,
        }

    async def reset_user(self, user_id: str, action: str = "ai_query") -> None:
        """Admin-only: reset a user's counter (e.g. after tier upgrade)."""
        try:
            db = self._get_db()
            key = self._counter_key(user_id, action)
            db.collection("rateLimits").document(key).delete()
            logger.info(f"Rate limit reset for user={user_id}, action={action}")
        except Exception as e:
            logger.error(f"Rate limit reset failed: {e}")


# ─── Singleton ────────────────────────────────────────────────────────────────
rate_limiter = RateLimiter()


# ─── FastAPI Dependency ───────────────────────────────────────────────────────
async def check_ai_rate_limit(request: Request) -> dict:
    """
    FastAPI dependency that enforces AI query rate limits.
    Reads user_id and tier from request.state (set by auth middleware).
    Raises HTTP 429 if limit exceeded.
    """
    user_id: str = getattr(request.state, "user_id", None)
    tier: str = getattr(request.state, "tier", "free")

    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    allowed, count, limit = await rate_limiter.check_and_increment(
        user_id=user_id,
        tier=tier,
        action="ai_query",
    )

    if not allowed:
        limit_str = str(limit) if limit else "unlimited"
        raise HTTPException(
            status_code=429,
            detail={
                "error": "rate_limit_exceeded",
                "message": f"Daily AI query limit reached ({count}/{limit_str}). Upgrade to Pro for unlimited queries.",
                "messageAr": f"تم الوصول إلى الحد اليومي لاستفسارات الذكاء الاصطناعي ({count}/{limit_str}). قم بالترقية إلى Pro للحصول على استفسارات غير محدودة.",
                "currentCount": count,
                "dailyLimit": limit,
                "upgradeUrl": "https://cip.app/subscription",
            },
        )

    # Attach usage info to request state for response headers
    request.state.ai_query_count = count
    request.state.ai_query_limit = limit

    return {"user_id": user_id, "tier": tier, "count": count, "limit": limit}


async def check_upload_rate_limit(request: Request) -> dict:
    """FastAPI dependency for file upload rate limiting."""
    user_id: str = getattr(request.state, "user_id", None)
    tier: str = getattr(request.state, "tier", "free")

    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    allowed, count, limit = await rate_limiter.check_and_increment(
        user_id=user_id,
        tier=tier,
        action="file_upload",
    )

    if not allowed:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "upload_limit_exceeded",
                "message": f"Daily upload limit reached ({count}/{limit}). Upgrade to Pro for unlimited uploads.",
                "messageAr": f"تم الوصول إلى حد الرفع اليومي ({count}/{limit}). قم بالترقية للحصول على رفع غير محدود.",
                "currentCount": count,
                "dailyLimit": limit,
            },
        )

    return {"user_id": user_id, "tier": tier, "count": count, "limit": limit}
