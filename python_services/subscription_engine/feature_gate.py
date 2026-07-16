"""
Subscription Engine — Feature Gate
THE single entry point every feature check goes through.
This is the file that makes "no code deployment required" true:
every decision is read from Firestore config, never hardcoded here.
"""
from __future__ import annotations
import logging
from dataclasses import dataclass
from typing import Optional

from .models import FeatureAccessLevel, PlanTier
from .config_service import ConfigService
from .subscription_service import SubscriptionService
from .usage_tracker import UsageTracker

logger = logging.getLogger("cip.subscription.feature_gate")


@dataclass
class AccessDecision:
    allowed:           bool
    reason:            str
    requires_upgrade:  bool
    usage_used:        Optional[int] = None
    usage_limit:       Optional[int] = None


class FeatureGate:

    def __init__(self):
        self._config = ConfigService()
        self._subs   = SubscriptionService()
        self._usage  = UsageTracker()

    async def can_access(
        self, user_id: str, feature_key: str, consume_usage: bool = False,
    ) -> AccessDecision:
        config = await self._config.get_config()

        # ── Master switch: free launch ──────────────────────────────────────
        if not config.subscriptions_enabled:
            if consume_usage:
                await self._usage.increment(user_id, feature_key)
            return AccessDecision(
                allowed=True, reason="free_launch", requires_upgrade=False)

        # ── Feature not configured (subscriptions ENABLED) → fail CLOSED ────
        # The free-launch open path is handled by the master switch above. Once
        # subscriptions are on, an unconfigured key is almost always a config
        # typo; failing open would silently grant a paid feature to everyone, so
        # we deny and log loudly instead.
        feature_cfg = config.feature_access.get(feature_key)
        if feature_cfg is None:
            logger.error(
                f"Unconfigured feature_key '{feature_key}' with subscriptions "
                f"enabled — denying (fail closed). Add it to subscription config."
            )
            return AccessDecision(
                allowed=False, reason="unconfigured_feature", requires_upgrade=True)

        # ── Public features: always allowed, but usage limits still apply ──
        if feature_cfg.access_level == FeatureAccessLevel.PUBLIC:
            return await self._check_usage_then_allow(
                user_id, feature_key, config, consume_usage, reason="public_feature")

        # ── Pro-only feature: check the user's actual entitlement ──────────
        sub = await self._subs.get_subscription(user_id)

        if sub.is_pro_active:
            reason = "trial_active" if sub.status.value == "TRIAL" else "pro_active"
            if consume_usage:
                await self._usage.increment(user_id, feature_key)
            return AccessDecision(allowed=True, reason=reason, requires_upgrade=False)

        return AccessDecision(
            allowed=False, reason="pro_required", requires_upgrade=True)

    async def _check_usage_then_allow(
        self, user_id: str, feature_key: str, config, consume_usage: bool, reason: str,
    ) -> AccessDecision:
        limit_cfg = config.usage_limits.get(feature_key)
        monthly_limit = limit_cfg.monthly_limit if limit_cfg else 0

        sub = await self._subs.get_subscription(user_id)
        if sub.is_pro_active:
            if consume_usage:
                await self._usage.increment(user_id, feature_key)
            return AccessDecision(allowed=True, reason="pro_active", requires_upgrade=False)

        if monthly_limit <= 0:
            if consume_usage:
                await self._usage.increment(user_id, feature_key)
            return AccessDecision(allowed=True, reason=reason, requires_upgrade=False)

        used = await self._usage.get_usage(user_id, feature_key)
        if used >= monthly_limit:
            return AccessDecision(
                allowed=False, reason="limit_reached", requires_upgrade=True,
                usage_used=used, usage_limit=monthly_limit,
            )

        if consume_usage:
            used = await self._usage.increment(user_id, feature_key)

        return AccessDecision(
            allowed=True, reason=reason, requires_upgrade=False,
            usage_used=used, usage_limit=monthly_limit,
        )
