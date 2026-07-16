"""
Subscription Engine — Data Models
Designed to map cleanly onto RevenueCat's entitlement model so a future
RevenueCat integration requires no redesign — only a webhook handler that
writes into these same shapes.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class PlanTier(str, Enum):
    FREE = "FREE"
    PRO  = "PRO"


class FeatureAccessLevel(str, Enum):
    PUBLIC   = "PUBLIC"     # available to everyone, including Free plan
    PRO_ONLY = "PRO_ONLY"   # requires Pro plan or active trial


class SubscriptionStatus(str, Enum):
    NONE      = "NONE"        # never subscribed, on Free plan
    TRIAL     = "TRIAL"       # in free trial period
    ACTIVE    = "ACTIVE"      # paying Pro subscriber
    EXPIRED   = "EXPIRED"     # was Pro/trial, lapsed
    CANCELLED = "CANCELLED"   # user-cancelled, runs until period end
    GRANTED   = "GRANTED"     # admin/promo granted, not store-billed


class SubscriptionSource(str, Enum):
    """Mirrors RevenueCat's `store` field — ready for that integration."""
    NONE         = "NONE"
    APP_STORE    = "APP_STORE"
    PLAY_STORE   = "PLAY_STORE"
    ADMIN_GRANT  = "ADMIN_GRANT"
    PROMO        = "PROMO"
    REFERRAL     = "REFERRAL"
    TRIAL        = "TRIAL"


class EventType(str, Enum):
    TRIAL_STARTED        = "TRIAL_STARTED"
    TRIAL_EXTENDED       = "TRIAL_EXTENDED"
    TRIAL_EXPIRED        = "TRIAL_EXPIRED"
    SUBSCRIPTION_ACTIVATED   = "SUBSCRIPTION_ACTIVATED"
    SUBSCRIPTION_RENEWED     = "SUBSCRIPTION_RENEWED"
    SUBSCRIPTION_CANCELLED   = "SUBSCRIPTION_CANCELLED"
    SUBSCRIPTION_EXPIRED     = "SUBSCRIPTION_EXPIRED"
    ADMIN_GRANTED_DAYS       = "ADMIN_GRANTED_DAYS"
    ADMIN_REVOKED            = "ADMIN_REVOKED"
    PROMO_ACTIVATED          = "PROMO_ACTIVATED"
    REFERRAL_REWARD_GRANTED  = "REFERRAL_REWARD_GRANTED"


# ── Plan configuration ────────────────────────────────────────────────────────

@dataclass
class PlanDefinition:
    """Editable from Admin Panel — names, descriptions, benefits are all data."""
    tier:          PlanTier
    display_name:  str
    description:   str
    benefits:      list[str] = field(default_factory=list)
    price_label:    Optional[str] = None   # e.g. "$4.99/mo" — display only,
                                           # real price comes from store/RevenueCat
    is_active:     bool = True


@dataclass
class FeatureAccessConfig:
    """One row in the admin's feature-access grid."""
    feature_key:    str            # e.g. "rest_calculator"
    display_name:   str            # e.g. "Rest Calculator"
    access_level:   FeatureAccessLevel
    description:    str = ""


@dataclass
class UsageLimitConfig:
    """Configurable monthly cap for a feature, applied to Free plan only."""
    feature_key:      str
    monthly_limit:    int           # 0 = unlimited even on Free
    applies_to_tier:  PlanTier = PlanTier.FREE


@dataclass
class TrialConfig:
    enabled:           bool = True
    duration_days:     int = 14
    requires_no_prior_trial: bool = True   # one trial per account, ever


@dataclass
class SubscriptionConfig:
    """
    The master config document. subscriptions_enabled is the single
    global switch — while False, every feature resolves to accessible
    regardless of feature_access settings below.
    """
    subscriptions_enabled: bool = False
    plans:                 dict[str, PlanDefinition] = field(default_factory=dict)
    feature_access:        dict[str, FeatureAccessConfig] = field(default_factory=dict)
    usage_limits:          dict[str, UsageLimitConfig] = field(default_factory=dict)
    trial:                 TrialConfig = field(default_factory=TrialConfig)
    updated_at:            Optional[datetime] = None
    updated_by:            Optional[str] = None


# ── Per-user subscription state ───────────────────────────────────────────────

@dataclass
class UserSubscription:
    """
    One per user. Field names deliberately mirror RevenueCat's
    CustomerInfo/EntitlementInfo shape:
    https://www.revenuecat.com/docs/customers/customer-info
    """
    user_id:            str
    status:             SubscriptionStatus = SubscriptionStatus.NONE
    tier:               PlanTier = PlanTier.FREE
    source:             SubscriptionSource = SubscriptionSource.NONE

    # RevenueCat-shaped fields (unused until that integration, but present
    # so the webhook handler just fills them in — no schema migration later)
    product_id:         Optional[str] = None
    store:               Optional[str] = None    # "app_store" | "play_store"
    original_purchase_date: Optional[datetime] = None
    expiration_date:     Optional[datetime] = None
    will_renew:          bool = False

    # Trial
    trial_started_at:    Optional[datetime] = None
    trial_ends_at:        Optional[datetime] = None
    has_used_trial:       bool = False

    # Admin/promo grants — additive bonus days stack onto expiration_date
    bonus_days_granted:   int = 0

    created_at:           datetime = field(default_factory=datetime.utcnow)
    updated_at:            datetime = field(default_factory=datetime.utcnow)

    @property
    def is_pro_active(self) -> bool:
        if self.status in (SubscriptionStatus.ACTIVE, SubscriptionStatus.GRANTED):
            if self.expiration_date is None:
                return True
            return datetime.utcnow() < self.expiration_date
        if self.status == SubscriptionStatus.TRIAL:
            return self.trial_ends_at is not None and datetime.utcnow() < self.trial_ends_at
        if self.status == SubscriptionStatus.CANCELLED:
            # Cancelled but still within paid period
            return self.expiration_date is not None and datetime.utcnow() < self.expiration_date
        return False

    @property
    def effective_tier(self) -> PlanTier:
        return PlanTier.PRO if self.is_pro_active else PlanTier.FREE


@dataclass
class UsageCounter:
    """
    One per user+feature+month. month_key format: 'YYYY-MM'.
    Resetting is implicit — a new month_key just starts a fresh counter,
    no cron job required.
    """
    user_id:      str
    feature_key:  str
    month_key:    str
    count:        int = 0
    updated_at:    datetime = field(default_factory=datetime.utcnow)


@dataclass
class SubscriptionEvent:
    """Append-only history entry — shown to the user as their account timeline."""
    id:            str
    user_id:       str
    event_type:    EventType
    description:   str           # plain-English, user-facing
    metadata:      dict = field(default_factory=dict)   # e.g. {"days": 7, "grantedBy": "admin_uid"}
    created_at:     datetime = field(default_factory=datetime.utcnow)


# ── Referral ──────────────────────────────────────────────────────────────────

@dataclass
class ReferralTier:
    invites_required: int
    reward_days:      int
    label:            str   # e.g. "Invite 5 crew members"


@dataclass
class ReferralCampaign:
    id:            str
    is_active:     bool = True
    tiers:         list[ReferralTier] = field(default_factory=list)
    updated_at:     Optional[datetime] = None


@dataclass
class UserReferralStatus:
    user_id:           str
    referral_code:     str
    successful_invites: int = 0
    rewards_claimed:    list[int] = field(default_factory=list)  # invites_required values already paid out


# ── API response shapes ───────────────────────────────────────────────────────

@dataclass
class EntitlementResponse:
    """What the Flutter app actually receives — never raw config internals."""
    subscriptions_enabled: bool
    tier:                  PlanTier
    status:                SubscriptionStatus
    is_pro_active:         bool
    trial_active:          bool
    trial_days_remaining:  Optional[int]
    expiration_date:        Optional[str]
    feature_access:         dict[str, str]   # feature_key -> "PUBLIC" | "PRO_ONLY" | resolved bool as needed


@dataclass
class UsageStatusResponse:
    feature_key:     str
    used:            int
    limit:           int          # 0 = unlimited
    remaining:       int
    is_unlimited:    bool
    resets_at:        str         # first of next month, ISO date
