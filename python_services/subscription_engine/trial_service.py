"""
Subscription Engine — Trial Service
Handles trial start, extension, and expiration. Admin can extend trials
freely; the "one trial per account" rule only blocks self-service restart.
"""
from __future__ import annotations
import logging
from datetime import datetime, timedelta
from typing import Optional

from .models import UserSubscription, SubscriptionStatus, PlanTier, EventType
from .config_service import ConfigService
from .subscription_service import SubscriptionService

logger = logging.getLogger("cip.subscription.trial")


class TrialService:

    def __init__(self):
        self._config = ConfigService()
        self._subs   = SubscriptionService()

    async def start_trial(self, user_id: str) -> tuple[bool, str, Optional[UserSubscription]]:
        config = await self._config.get_config()

        if not config.trial.enabled:
            return False, "Free trials are not currently available.", None

        sub = await self._subs.get_subscription(user_id)

        if config.trial.requires_no_prior_trial and sub.has_used_trial:
            return False, "You've already used your free trial.", None

        if sub.is_pro_active:
            return False, "You already have active Pro access.", None

        now = datetime.utcnow()
        sub.status = SubscriptionStatus.TRIAL
        sub.tier = PlanTier.PRO
        sub.trial_started_at = now
        sub.trial_ends_at = now + timedelta(days=config.trial.duration_days)
        sub.has_used_trial = True
        sub.updated_at = now

        await self._subs._save(sub)
        await self._subs._log_event(
            user_id, EventType.TRIAL_STARTED,
            description=f"{config.trial.duration_days}-day free trial started.",
            metadata={"durationDays": config.trial.duration_days},
        )

        return True, f"Your {config.trial.duration_days}-day free trial has started.", sub

    async def extend_trial(
        self, user_id: str, additional_days: int, extended_by: str,
        reason: str = "",
    ) -> UserSubscription:
        """Admin-only — extends an existing trial (or starts one if none exists)."""
        sub = await self._subs.get_subscription(user_id)
        now = datetime.utcnow()

        if sub.trial_ends_at and sub.trial_ends_at > now:
            base = sub.trial_ends_at
        else:
            base = now

        sub.trial_ends_at = base + timedelta(days=additional_days)
        sub.status = SubscriptionStatus.TRIAL
        sub.tier = PlanTier.PRO
        if sub.trial_started_at is None:
            sub.trial_started_at = now
        sub.has_used_trial = True
        sub.updated_at = now

        await self._subs._save(sub)
        await self._subs._log_event(
            user_id, EventType.TRIAL_EXTENDED,
            description=(
                f"Trial extended by +{additional_days} day"
                f"{'s' if additional_days != 1 else ''} by admin."
                f"{f' {reason}' if reason else ''}"
            ),
            metadata={"days": additional_days, "extendedBy": extended_by, "reason": reason},
        )

        return sub

    async def days_remaining(self, user_id: str) -> Optional[int]:
        sub = await self._subs.get_subscription(user_id)
        if sub.status != SubscriptionStatus.TRIAL or not sub.trial_ends_at:
            return None
        delta = sub.trial_ends_at - datetime.utcnow()
        return max(0, delta.days)
