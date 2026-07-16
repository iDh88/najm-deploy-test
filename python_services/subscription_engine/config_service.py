"""
Subscription Engine — Config Service
Single source of truth for subscription configuration.
Cached in-process with a short TTL since this is read on every feature check.
"""
from __future__ import annotations
import logging
import time
from datetime import datetime
from typing import Optional

from .models import (
    SubscriptionConfig, PlanDefinition, FeatureAccessConfig,
    UsageLimitConfig, TrialConfig, PlanTier, FeatureAccessLevel,
)

logger = logging.getLogger("cip.subscription.config")

CACHE_TTL_SECONDS = 30

DEFAULT_FEATURE_KEYS = [
    ("trade_engine",          "Trade Engine"),
    ("rest_calculator",       "Rest Calculator"),
    ("fatigue_engine",        "Fatigue Engine"),
    ("operational_ai",        "Operational Knowledge AI"),
    ("layover_intelligence",  "Layover Intelligence"),
]


class ConfigService:

    def __init__(self):
        self._cache: Optional[SubscriptionConfig] = None
        self._cache_at: float = 0.0

    async def get_config(self, force_refresh: bool = False) -> SubscriptionConfig:
        now = time.time()
        if (not force_refresh and self._cache is not None
                and now - self._cache_at < CACHE_TTL_SECONDS):
            return self._cache

        config = await self._load_from_firestore()
        self._cache = config
        self._cache_at = now
        return config

    def invalidate_cache(self) -> None:
        self._cache = None

    async def _load_from_firestore(self) -> SubscriptionConfig:
        db = self._get_db()
        doc = db.collection("subscriptionConfig").document("main").get()

        if not doc.exists:
            default = self._build_default_config()
            await self._save(default)
            return default

        data = doc.to_dict()
        return self._from_firestore_dict(data)

    async def update_config(self, config: SubscriptionConfig, updated_by: str) -> None:
        config.updated_at = datetime.utcnow()
        config.updated_by = updated_by
        await self._save(config)
        self.invalidate_cache()

    async def _save(self, config: SubscriptionConfig) -> None:
        db = self._get_db()
        db.collection("subscriptionConfig").document("main").set(
            self._to_firestore_dict(config))

    def _build_default_config(self) -> SubscriptionConfig:
        plans = {
            PlanTier.FREE.value: PlanDefinition(
                tier=PlanTier.FREE,
                display_name="Free",
                description="Get started with Najm at no cost.",
                benefits=["Core scheduling tools", "Limited monthly usage"],
            ),
            PlanTier.PRO.value: PlanDefinition(
                tier=PlanTier.PRO,
                display_name="Pro",
                description="Unlock unlimited access to every Najm tool.",
                benefits=[
                    "Unlimited trade searches",
                    "Unlimited AI assistant queries",
                    "Unlimited legality & fatigue checks",
                    "Priority support",
                ],
                price_label=None,
            ),
        }

        feature_access = {
            key: FeatureAccessConfig(
                feature_key=key,
                display_name=label,
                access_level=FeatureAccessLevel.PUBLIC,
            )
            for key, label in DEFAULT_FEATURE_KEYS
        }

        usage_limits = {
            key: UsageLimitConfig(feature_key=key, monthly_limit=0)
            for key, _ in DEFAULT_FEATURE_KEYS
        }

        return SubscriptionConfig(
            subscriptions_enabled=False,
            plans=plans,
            feature_access=feature_access,
            usage_limits=usage_limits,
            trial=TrialConfig(enabled=True, duration_days=14),
        )

    def _to_firestore_dict(self, config: SubscriptionConfig) -> dict:
        return {
            "subscriptionsEnabled": config.subscriptions_enabled,
            "plans": {
                k: {
                    "tier": p.tier.value,
                    "displayName": p.display_name,
                    "description": p.description,
                    "benefits": p.benefits,
                    "priceLabel": p.price_label,
                    "isActive": p.is_active,
                }
                for k, p in config.plans.items()
            },
            "featureAccess": {
                k: {
                    "featureKey": f.feature_key,
                    "displayName": f.display_name,
                    "accessLevel": f.access_level.value,
                    "description": f.description,
                }
                for k, f in config.feature_access.items()
            },
            "usageLimits": {
                k: {
                    "featureKey": u.feature_key,
                    "monthlyLimit": u.monthly_limit,
                    "appliesToTier": u.applies_to_tier.value,
                }
                for k, u in config.usage_limits.items()
            },
            "trial": {
                "enabled": config.trial.enabled,
                "durationDays": config.trial.duration_days,
                "requiresNoPriorTrial": config.trial.requires_no_prior_trial,
            },
            "updatedAt": (config.updated_at or datetime.utcnow()).isoformat(),
            "updatedBy": config.updated_by,
        }

    def _from_firestore_dict(self, data: dict) -> SubscriptionConfig:
        plans = {
            k: PlanDefinition(
                tier=PlanTier(v.get("tier", "FREE")),
                display_name=v.get("displayName", k),
                description=v.get("description", ""),
                benefits=v.get("benefits", []),
                price_label=v.get("priceLabel"),
                is_active=v.get("isActive", True),
            )
            for k, v in data.get("plans", {}).items()
        }

        feature_access = {
            k: FeatureAccessConfig(
                feature_key=v.get("featureKey", k),
                display_name=v.get("displayName", k),
                access_level=FeatureAccessLevel(v.get("accessLevel", "PUBLIC")),
                description=v.get("description", ""),
            )
            for k, v in data.get("featureAccess", {}).items()
        }

        usage_limits = {
            k: UsageLimitConfig(
                feature_key=v.get("featureKey", k),
                monthly_limit=v.get("monthlyLimit", 0),
                applies_to_tier=PlanTier(v.get("appliesToTier", "FREE")),
            )
            for k, v in data.get("usageLimits", {}).items()
        }

        trial_data = data.get("trial", {})
        trial = TrialConfig(
            enabled=trial_data.get("enabled", True),
            duration_days=trial_data.get("durationDays", 14),
            requires_no_prior_trial=trial_data.get("requiresNoPriorTrial", True),
        )

        return SubscriptionConfig(
            subscriptions_enabled=data.get("subscriptionsEnabled", False),
            plans=plans,
            feature_access=feature_access,
            usage_limits=usage_limits,
            trial=trial,
            updated_by=data.get("updatedBy"),
        )

    def _get_db(self):
        from utils.firebase import get_firestore
        return get_firestore()
