"""
Subscription Engine — Usage Tracker
Monthly per-feature usage counters. Resetting is implicit via the
month_key — no cron job needed.
"""
from __future__ import annotations
import logging
from datetime import datetime
from typing import Optional

from .models import UsageCounter, UsageStatusResponse

logger = logging.getLogger("cip.subscription.usage")


def _current_month_key() -> str:
    now = datetime.utcnow()
    return f"{now.year}-{now.month:02d}"


def _next_month_first_day_iso() -> str:
    now = datetime.utcnow()
    year, month = (now.year, now.month + 1) if now.month < 12 else (now.year + 1, 1)
    return datetime(year, month, 1).isoformat()


class UsageTracker:

    async def get_usage(self, user_id: str, feature_key: str) -> int:
        db = self._get_db()
        doc_id = f"{user_id}_{feature_key}_{_current_month_key()}"
        doc = db.collection("usageCounters").document(doc_id).get()
        if not doc.exists:
            return 0
        return doc.to_dict().get("count", 0)

    async def increment(self, user_id: str, feature_key: str) -> int:
        """Atomically increments and returns the new count."""
        db = self._get_db()
        doc_id = f"{user_id}_{feature_key}_{_current_month_key()}"
        ref = db.collection("usageCounters").document(doc_id)

        from google.cloud.firestore_v1 import Increment
        ref.set({
            "userId": user_id,
            "featureKey": feature_key,
            "monthKey": _current_month_key(),
            "count": Increment(1),
            "updatedAt": datetime.utcnow().isoformat(),
        }, merge=True)

        doc = ref.get()
        return doc.to_dict().get("count", 1) if doc.exists else 1

    async def get_status(
        self, user_id: str, feature_key: str, monthly_limit: int,
    ) -> UsageStatusResponse:
        used = await self.get_usage(user_id, feature_key)
        is_unlimited = monthly_limit <= 0
        remaining = -1 if is_unlimited else max(0, monthly_limit - used)

        return UsageStatusResponse(
            feature_key=feature_key,
            used=used,
            limit=monthly_limit,
            remaining=remaining,
            is_unlimited=is_unlimited,
            resets_at=_next_month_first_day_iso(),
        )

    async def has_remaining(self, user_id: str, feature_key: str, monthly_limit: int) -> bool:
        if monthly_limit <= 0:
            return True
        used = await self.get_usage(user_id, feature_key)
        return used < monthly_limit

    def _get_db(self):
        from utils.firebase import get_firestore
        return get_firestore()
