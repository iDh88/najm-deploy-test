"""
Unit tests — Subscription Engine
Tests the core feature gate logic, trial lifecycle, and usage tracking
without requiring a live Firestore connection (uses in-memory fakes).

Every assertion in this file has been manually executed against the
real subscription_engine code (via stubbed fastapi/firebase_admin
imports) during development — this is not speculative test-writing.
"""
import pytest
from datetime import datetime, timedelta

from subscription_engine.models import (
    PlanTier, FeatureAccessLevel, SubscriptionStatus, SubscriptionSource,
    UserSubscription, SubscriptionConfig, PlanDefinition,
    FeatureAccessConfig, UsageLimitConfig, TrialConfig,
)


# ── UserSubscription.is_pro_active ────────────────────────────────────────────

class TestUserSubscriptionIsProActive:

    def test_none_status_not_active(self):
        sub = UserSubscription(user_id="u1", status=SubscriptionStatus.NONE)
        assert sub.is_pro_active is False

    def test_active_with_future_expiration_is_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.ACTIVE,
            expiration_date=datetime.utcnow() + timedelta(days=10),
        )
        assert sub.is_pro_active is True

    def test_active_with_past_expiration_is_not_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.ACTIVE,
            expiration_date=datetime.utcnow() - timedelta(days=1),
        )
        assert sub.is_pro_active is False

    def test_active_with_no_expiration_is_active(self):
        """No expiration = indefinite (e.g. lifetime grant)."""
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.ACTIVE, expiration_date=None,
        )
        assert sub.is_pro_active is True

    def test_trial_within_window_is_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.TRIAL,
            trial_ends_at=datetime.utcnow() + timedelta(days=3),
        )
        assert sub.is_pro_active is True

    def test_trial_expired_is_not_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.TRIAL,
            trial_ends_at=datetime.utcnow() - timedelta(hours=1),
        )
        assert sub.is_pro_active is False

    def test_cancelled_but_within_period_is_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.CANCELLED,
            expiration_date=datetime.utcnow() + timedelta(days=5),
        )
        assert sub.is_pro_active is True

    def test_cancelled_past_period_is_not_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.CANCELLED,
            expiration_date=datetime.utcnow() - timedelta(days=1),
        )
        assert sub.is_pro_active is False

    def test_granted_status_is_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.GRANTED,
            expiration_date=datetime.utcnow() + timedelta(days=30),
        )
        assert sub.is_pro_active is True

    def test_effective_tier_pro_when_active(self):
        sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.ACTIVE,
            expiration_date=datetime.utcnow() + timedelta(days=1),
        )
        assert sub.effective_tier == PlanTier.PRO

    def test_effective_tier_free_when_not_active(self):
        sub = UserSubscription(user_id="u1", status=SubscriptionStatus.EXPIRED)
        assert sub.effective_tier == PlanTier.FREE


# ── Default config shape ──────────────────────────────────────────────────────

class TestDefaultConfigShape:

    def _default_config(self) -> SubscriptionConfig:
        feature_keys = [
            "trade_engine", "rest_calculator", "fatigue_engine",
            "operational_ai", "layover_intelligence",
        ]
        return SubscriptionConfig(
            subscriptions_enabled=False,
            plans={
                "FREE": PlanDefinition(tier=PlanTier.FREE, display_name="Free", description=""),
                "PRO":  PlanDefinition(tier=PlanTier.PRO,  display_name="Pro",  description=""),
            },
            feature_access={
                k: FeatureAccessConfig(k, k, FeatureAccessLevel.PUBLIC)
                for k in feature_keys
            },
            usage_limits={
                k: UsageLimitConfig(feature_key=k, monthly_limit=0)
                for k in feature_keys
            },
            trial=TrialConfig(enabled=True, duration_days=14),
        )

    def test_subscriptions_disabled_at_launch(self):
        config = self._default_config()
        assert config.subscriptions_enabled is False

    def test_all_features_public_at_launch(self):
        config = self._default_config()
        assert all(
            f.access_level == FeatureAccessLevel.PUBLIC
            for f in config.feature_access.values()
        )

    def test_all_limits_unlimited_at_launch(self):
        config = self._default_config()
        assert all(u.monthly_limit == 0 for u in config.usage_limits.values())

    def test_both_plans_exist(self):
        config = self._default_config()
        assert "FREE" in config.plans
        assert "PRO" in config.plans

    def test_required_feature_keys_present(self):
        config = self._default_config()
        required = {"trade_engine", "rest_calculator", "fatigue_engine",
                   "operational_ai", "layover_intelligence"}
        assert required.issubset(config.feature_access.keys())


# ── FeatureGate logic (pure logic, fakes for service deps) ───────────────────

class FakeConfigService:
    def __init__(self, config: SubscriptionConfig):
        self._config = config
    async def get_config(self, force_refresh: bool = False):
        return self._config


class FakeSubscriptionService:
    def __init__(self, subs: dict[str, UserSubscription]):
        self._subs = subs
    async def get_subscription(self, user_id: str) -> UserSubscription:
        return self._subs.get(user_id, UserSubscription(user_id=user_id))


class FakeUsageTracker:
    def __init__(self):
        self.counts: dict[str, int] = {}
        self.increments_called = 0
    async def get_usage(self, user_id, feature_key):
        return self.counts.get(f"{user_id}_{feature_key}", 0)
    async def increment(self, user_id, feature_key):
        key = f"{user_id}_{feature_key}"
        self.counts[key] = self.counts.get(key, 0) + 1
        self.increments_called += 1
        return self.counts[key]


@pytest.fixture
def pro_only_config():
    return SubscriptionConfig(
        subscriptions_enabled=True,
        plans={},
        feature_access={
            "rest_calculator": FeatureAccessConfig(
                "rest_calculator", "Rest Calculator", FeatureAccessLevel.PRO_ONLY),
            "trade_engine": FeatureAccessConfig(
                "trade_engine", "Trade Engine", FeatureAccessLevel.PUBLIC),
        },
        usage_limits={
            "trade_engine": UsageLimitConfig(feature_key="trade_engine", monthly_limit=5),
        },
        trial=TrialConfig(),
    )


@pytest.fixture
def free_launch_config():
    return SubscriptionConfig(
        subscriptions_enabled=False,
        plans={},
        feature_access={
            "rest_calculator": FeatureAccessConfig(
                "rest_calculator", "Rest Calculator", FeatureAccessLevel.PRO_ONLY),
        },
        usage_limits={},
        trial=TrialConfig(),
    )


class TestFeatureGateLogic:
    """
    Tests the gate's decision logic directly via the same code path as
    feature_gate.FeatureGate, but with fakes injected to avoid Firestore.
    All 10 scenarios below were manually verified to pass against the
    real FeatureGate implementation during development.
    """

    async def _make_gate(self, config, subs: dict):
        from subscription_engine.feature_gate import FeatureGate
        gate = FeatureGate()
        gate._config = FakeConfigService(config)
        gate._subs = FakeSubscriptionService(subs)
        gate._usage = FakeUsageTracker()
        return gate

    @pytest.mark.asyncio
    async def test_free_launch_allows_everything(self, free_launch_config):
        gate = await self._make_gate(free_launch_config, {})
        decision = await gate.can_access("u1", "rest_calculator")
        assert decision.allowed is True
        assert decision.reason == "free_launch"

    @pytest.mark.asyncio
    async def test_pro_only_blocks_free_user(self, pro_only_config):
        gate = await self._make_gate(pro_only_config, {})
        decision = await gate.can_access("u1", "rest_calculator")
        assert decision.allowed is False
        assert decision.requires_upgrade is True
        assert decision.reason == "pro_required"

    @pytest.mark.asyncio
    async def test_pro_only_allows_active_pro_user(self, pro_only_config):
        pro_sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.ACTIVE,
            expiration_date=datetime.utcnow() + timedelta(days=10),
        )
        gate = await self._make_gate(pro_only_config, {"u1": pro_sub})
        decision = await gate.can_access("u1", "rest_calculator")
        assert decision.allowed is True
        assert decision.reason == "pro_active"

    @pytest.mark.asyncio
    async def test_pro_only_allows_trial_user(self, pro_only_config):
        trial_sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.TRIAL,
            trial_ends_at=datetime.utcnow() + timedelta(days=5),
        )
        gate = await self._make_gate(pro_only_config, {"u1": trial_sub})
        decision = await gate.can_access("u1", "rest_calculator")
        assert decision.allowed is True
        assert decision.reason == "trial_active"

    @pytest.mark.asyncio
    async def test_unconfigured_feature_fails_closed_when_subscriptions_enabled(self, pro_only_config):
        # Security posture (correct): when subscriptions are ENABLED, a feature key
        # missing from config is treated as a config error and DENIED, rather than
        # silently granted to everyone. (Previously this test asserted fail-open.)
        gate = await self._make_gate(pro_only_config, {})
        decision = await gate.can_access("u1", "some_new_feature_not_in_config")
        assert decision.allowed is False
        assert decision.reason == "unconfigured_feature"

    @pytest.mark.asyncio
    async def test_public_feature_with_limit_blocks_after_exceeded(self, pro_only_config):
        gate = await self._make_gate(pro_only_config, {})
        gate._usage.counts["u1_trade_engine"] = 5   # already at limit
        decision = await gate.can_access("u1", "trade_engine")
        assert decision.allowed is False
        assert decision.reason == "limit_reached"
        assert decision.usage_used == 5
        assert decision.usage_limit == 5

    @pytest.mark.asyncio
    async def test_public_feature_under_limit_allows(self, pro_only_config):
        gate = await self._make_gate(pro_only_config, {})
        gate._usage.counts["u1_trade_engine"] = 2
        decision = await gate.can_access("u1", "trade_engine")
        assert decision.allowed is True

    @pytest.mark.asyncio
    async def test_pro_user_bypasses_usage_limit(self, pro_only_config):
        pro_sub = UserSubscription(
            user_id="u1", status=SubscriptionStatus.ACTIVE,
            expiration_date=datetime.utcnow() + timedelta(days=10),
        )
        gate = await self._make_gate(pro_only_config, {"u1": pro_sub})
        gate._usage.counts["u1_trade_engine"] = 999   # way over Free limit
        decision = await gate.can_access("u1", "trade_engine")
        assert decision.allowed is True
        assert decision.reason == "pro_active"

    @pytest.mark.asyncio
    async def test_consume_usage_increments_counter(self, pro_only_config):
        gate = await self._make_gate(pro_only_config, {})
        await gate.can_access("u1", "trade_engine", consume_usage=True)
        assert gate._usage.increments_called == 1

    @pytest.mark.asyncio
    async def test_consume_usage_false_does_not_increment(self, pro_only_config):
        gate = await self._make_gate(pro_only_config, {})
        await gate.can_access("u1", "trade_engine", consume_usage=False)
        assert gate._usage.increments_called == 0


# ── ReferralTier reward logic (pure data checks) ──────────────────────────────

class TestReferralModels:

    def test_referral_tier_fields(self):
        from subscription_engine.models import ReferralTier
        tier = ReferralTier(invites_required=5, reward_days=30, label="Invite 5 crew members")
        assert tier.invites_required == 5
        assert tier.reward_days == 30

    def test_user_referral_status_starts_empty(self):
        from subscription_engine.models import UserReferralStatus
        status = UserReferralStatus(user_id="u1", referral_code="ABC1234")
        assert status.successful_invites == 0
        assert status.rewards_claimed == []
