"""
Subscription Engine
Launches in free mode (subscriptions_enabled=False) but is fully
subscription-ready: every feature check, usage limit, trial, and
referral reward flows through config stored in Firestore — never
hardcoded — so enabling monetization later requires zero deploys.
"""
from .models import (
    PlanTier, FeatureAccessLevel, SubscriptionStatus, SubscriptionSource,
    EventType, PlanDefinition, FeatureAccessConfig, UsageLimitConfig,
    TrialConfig, SubscriptionConfig, UserSubscription, UsageCounter,
    SubscriptionEvent, ReferralTier, ReferralCampaign, UserReferralStatus,
    EntitlementResponse, UsageStatusResponse,
)
from .config_service       import ConfigService
from .subscription_service import SubscriptionService
from .feature_gate          import FeatureGate, AccessDecision
from .usage_tracker         import UsageTracker
from .trial_service         import TrialService
from .referral_service      import ReferralService
from .router                import router

__all__ = [
    "PlanTier", "FeatureAccessLevel", "SubscriptionStatus", "SubscriptionSource",
    "EventType", "PlanDefinition", "FeatureAccessConfig", "UsageLimitConfig",
    "TrialConfig", "SubscriptionConfig", "UserSubscription", "UsageCounter",
    "SubscriptionEvent", "ReferralTier", "ReferralCampaign", "UserReferralStatus",
    "EntitlementResponse", "UsageStatusResponse",
    "ConfigService", "SubscriptionService", "FeatureGate", "AccessDecision",
    "UsageTracker", "TrialService", "ReferralService", "router",
]
