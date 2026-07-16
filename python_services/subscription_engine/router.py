"""
Subscription Engine — FastAPI Router
Mounts at /v1/subscription/* in main.py.
"""
from __future__ import annotations
import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException, Header, Query, Depends
from pydantic import BaseModel
from typing import Optional

from utils.auth import verify_service_token
from .models import (
    PlanTier, FeatureAccessLevel, SubscriptionSource,
    PlanDefinition, FeatureAccessConfig, UsageLimitConfig, TrialConfig,
    SubscriptionConfig, ReferralCampaign, ReferralTier,
)
from .config_service import ConfigService
from .subscription_service import SubscriptionService
from .feature_gate import FeatureGate
from .usage_tracker import UsageTracker
from .trial_service import TrialService
from .referral_service import ReferralService

logger = logging.getLogger("cip.subscription")
router = APIRouter()

_config   = ConfigService()
_subs     = SubscriptionService()
_gate     = FeatureGate()
_usage    = UsageTracker()
_trial    = TrialService()
_referral = ReferralService()


def _require_admin(authorization: Optional[str]) -> dict:
    """Delegates to the shared revocation-checked helper (P1-1 closure):
    check_revoked=True, approved account, superAdmin or manage_subscriptions."""
    from utils.auth import require_admin_claims
    return require_admin_claims(authorization, "manage_subscriptions")


def _require_user(authorization: Optional[str]) -> str:
    """Delegates to the shared revocation-checked helper (P1-1 closure) and
    additionally requires accountStatus == approved (previously missing)."""
    from utils.auth import require_approved_user_claims
    return require_approved_user_claims(authorization)["uid"]


class UpdateMasterSwitchRequest(BaseModel):
    enabled: bool


class UpdateFeatureAccessRequest(BaseModel):
    feature_key: str
    access_level: str


class UpdateUsageLimitRequest(BaseModel):
    feature_key: str
    monthly_limit: int


class UpdatePlanRequest(BaseModel):
    tier: str
    display_name: str
    description: str
    benefits: list[str]
    price_label: Optional[str] = None
    is_active: bool = True


class UpdateTrialConfigRequest(BaseModel):
    enabled: bool
    duration_days: int
    requires_no_prior_trial: bool = True


class AdminGrantRequest(BaseModel):
    user_id: str
    days: int
    reason: str = ""


class AdminActivateRequest(BaseModel):
    user_id: str
    duration_days: Optional[int] = None


class AdminRevokeRequest(BaseModel):
    user_id: str
    reason: str = ""


class ReferralCampaignTierRequest(BaseModel):
    invites_required: int
    reward_days: int
    label: str


class UpdateReferralCampaignRequest(BaseModel):
    is_active: bool
    tiers: list[ReferralCampaignTierRequest]


class ApplyReferralCodeRequest(BaseModel):
    code: str


class CheckFeatureRequest(BaseModel):
    feature_key: str
    consume_usage: bool = False


# ══════════════════════════════════════════════════════════════════════════════
# ADMIN — Master config
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/admin/config")
async def get_full_config(authorization: Optional[str] = Header(None)):
    _require_admin(authorization)
    config = await _config.get_config(force_refresh=True)
    return _config_service_to_response(config)


@router.patch("/admin/config/master-switch")
async def update_master_switch(
    req: UpdateMasterSwitchRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    config = await _config.get_config(force_refresh=True)
    config.subscriptions_enabled = req.enabled
    await _config.update_config(config, updated_by=decoded["uid"])
    return {"subscriptionsEnabled": req.enabled}


@router.patch("/admin/config/feature-access")
async def update_feature_access(
    req: UpdateFeatureAccessRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    config = await _config.get_config(force_refresh=True)

    try:
        level = FeatureAccessLevel(req.access_level)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid access_level")

    existing = config.feature_access.get(req.feature_key)
    config.feature_access[req.feature_key] = FeatureAccessConfig(
        feature_key=req.feature_key,
        display_name=existing.display_name if existing else req.feature_key,
        access_level=level,
        description=existing.description if existing else "",
    )
    await _config.update_config(config, updated_by=decoded["uid"])
    return {"featureKey": req.feature_key, "accessLevel": req.access_level}


@router.patch("/admin/config/usage-limit")
async def update_usage_limit(
    req: UpdateUsageLimitRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    config = await _config.get_config(force_refresh=True)
    config.usage_limits[req.feature_key] = UsageLimitConfig(
        feature_key=req.feature_key, monthly_limit=req.monthly_limit,
    )
    await _config.update_config(config, updated_by=decoded["uid"])
    return {"featureKey": req.feature_key, "monthlyLimit": req.monthly_limit}


@router.patch("/admin/config/plan")
async def update_plan(
    req: UpdatePlanRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    config = await _config.get_config(force_refresh=True)

    try:
        tier = PlanTier(req.tier)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid tier")

    config.plans[tier.value] = PlanDefinition(
        tier=tier,
        display_name=req.display_name,
        description=req.description,
        benefits=req.benefits,
        price_label=req.price_label,
        is_active=req.is_active,
    )
    await _config.update_config(config, updated_by=decoded["uid"])
    return {"tier": req.tier, "updated": True}


@router.patch("/admin/config/trial")
async def update_trial_config(
    req: UpdateTrialConfigRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    config = await _config.get_config(force_refresh=True)
    config.trial = TrialConfig(
        enabled=req.enabled,
        duration_days=req.duration_days,
        requires_no_prior_trial=req.requires_no_prior_trial,
    )
    await _config.update_config(config, updated_by=decoded["uid"])
    return {"trial": req.dict()}


# ══════════════════════════════════════════════════════════════════════════════
# ADMIN — Per-user subscription management
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/admin/run-expiry-checks")
async def run_expiry_checks(_: bool = Depends(verify_service_token)):
    """
    Internal-only endpoint invoked by the daily Cloud Scheduler job
    (see firebase/functions dailySubscriptionExpiryCheck via callPythonService,
    which sends X-Service-Token on every internal call). Not for
    admin-panel use — no Firebase user token exists for this server-to-server call.
    Reuses utils.auth.verify_service_token, the existing shared-secret
    dependency already used for Cloud Functions → Python service calls.
    """
    from .notification_triggers import run_all_checks
    result = await run_all_checks()
    return result


@router.post("/admin/users/activate")
async def admin_activate_user(
    req: AdminActivateRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    sub = await _subs.activate_pro(
        user_id=req.user_id,
        source=SubscriptionSource.ADMIN_GRANT,
        duration_days=req.duration_days,
        granted_by=decoded["uid"],
    )
    return _sub_to_dict(sub)


@router.post("/admin/users/revoke")
async def admin_revoke_user(
    req: AdminRevokeRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    sub = await _subs.admin_revoke(req.user_id, revoked_by=decoded["uid"], reason=req.reason)
    return _sub_to_dict(sub)


@router.post("/admin/users/grant-days")
async def admin_grant_days(
    req: AdminGrantRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    sub = await _subs.grant_bonus_days(
        req.user_id, req.days, granted_by=decoded["uid"], reason=req.reason,
    )
    return _sub_to_dict(sub)


@router.get("/admin/users/{user_id}/subscription")
async def admin_get_user_subscription(
    user_id: str, authorization: Optional[str] = Header(None),
):
    _require_admin(authorization)
    sub = await _subs.get_subscription(user_id)
    return _sub_to_dict(sub)


@router.get("/admin/users/{user_id}/history")
async def admin_get_user_history(
    user_id: str, authorization: Optional[str] = Header(None),
):
    _require_admin(authorization)
    events = await _subs.get_history(user_id)
    return [_event_to_dict(e) for e in events]


@router.post("/admin/trial/extend")
async def admin_extend_trial(
    user_id: str = Query(...), days: int = Query(...), reason: str = Query(""),
    authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    sub = await _trial.extend_trial(user_id, days, extended_by=decoded["uid"], reason=reason)
    return _sub_to_dict(sub)


# ══════════════════════════════════════════════════════════════════════════════
# ADMIN — Referral campaign
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/admin/referral/campaign")
async def admin_get_referral_campaign(authorization: Optional[str] = Header(None)):
    _require_admin(authorization)
    campaign = await _referral.get_active_campaign()
    if not campaign:
        return {"isActive": False, "tiers": []}
    return {
        "isActive": campaign.is_active,
        "tiers": [
            {"invitesRequired": t.invites_required, "rewardDays": t.reward_days, "label": t.label}
            for t in campaign.tiers
        ],
    }


@router.patch("/admin/referral/campaign")
async def admin_update_referral_campaign(
    req: UpdateReferralCampaignRequest, authorization: Optional[str] = Header(None),
):
    decoded = _require_admin(authorization)
    campaign = ReferralCampaign(
        id="main",
        is_active=req.is_active,
        tiers=[
            ReferralTier(invites_required=t.invites_required,
                        reward_days=t.reward_days, label=t.label)
            for t in req.tiers
        ],
    )
    await _referral.update_campaign(campaign, updated_by=decoded["uid"])
    return {"updated": True}


# ══════════════════════════════════════════════════════════════════════════════
# USER-FACING — Entitlements, usage, history
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/me/entitlement")
async def get_my_entitlement(authorization: Optional[str] = Header(None)):
    user_id = _require_user(authorization)
    config = await _config.get_config()
    sub = await _subs.get_subscription(user_id)

    trial_days_remaining = await _trial.days_remaining(user_id)

    return {
        "subscriptionsEnabled": config.subscriptions_enabled,
        "tier": sub.effective_tier.value,
        "status": sub.status.value,
        "isProActive": sub.is_pro_active,
        "trialActive": sub.status.value == "TRIAL" and sub.is_pro_active,
        "trialDaysRemaining": trial_days_remaining,
        # Real start date for trials (Profile "Start" row). Paid plans carry no
        # start date on the subscription document, so this is null for them and
        # the app renders "—" rather than inventing one.
        "trialStartedAt": (
            sub.trial_started_at.isoformat() if sub.trial_started_at else None),
        "expirationDate": sub.expiration_date.isoformat() if sub.expiration_date else None,
        "featureAccess": {
            k: v.access_level.value for k, v in config.feature_access.items()
        },
    }


@router.post("/me/check-feature")
async def check_feature_access(
    req: CheckFeatureRequest, authorization: Optional[str] = Header(None),
):
    user_id = _require_user(authorization)
    decision = await _gate.can_access(user_id, req.feature_key, req.consume_usage)
    return {
        "allowed": decision.allowed,
        "reason": decision.reason,
        "requiresUpgrade": decision.requires_upgrade,
        "usageUsed": decision.usage_used,
        "usageLimit": decision.usage_limit,
    }


@router.get("/me/usage/{feature_key}")
async def get_my_usage(feature_key: str, authorization: Optional[str] = Header(None)):
    user_id = _require_user(authorization)
    config = await _config.get_config()
    limit_cfg = config.usage_limits.get(feature_key)
    monthly_limit = limit_cfg.monthly_limit if limit_cfg else 0
    status = await _usage.get_status(user_id, feature_key, monthly_limit)
    return {
        "featureKey": status.feature_key,
        "used": status.used,
        "limit": status.limit,
        "remaining": status.remaining,
        "isUnlimited": status.is_unlimited,
        "resetsAt": status.resets_at,
    }


@router.get("/me/history")
async def get_my_history(authorization: Optional[str] = Header(None)):
    user_id = _require_user(authorization)
    events = await _subs.get_history(user_id)
    return [_event_to_dict(e) for e in events]


@router.get("/plans")
async def get_plans():
    config = await _config.get_config()
    return {
        k: {
            "tier": p.tier.value,
            "displayName": p.display_name,
            "description": p.description,
            "benefits": p.benefits,
            "priceLabel": p.price_label,
            "isActive": p.is_active,
        }
        for k, p in config.plans.items()
    }


# ══════════════════════════════════════════════════════════════════════════════
# USER-FACING — Trial
# ══════════════════════════════════════════════════════════════════════════════

@router.post("/me/trial/start")
async def start_my_trial(authorization: Optional[str] = Header(None)):
    user_id = _require_user(authorization)
    success, message, sub = await _trial.start_trial(user_id)
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {"success": True, "message": message, "subscription": _sub_to_dict(sub)}


# ══════════════════════════════════════════════════════════════════════════════
# USER-FACING — Referral
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/me/referral")
async def get_my_referral_status(authorization: Optional[str] = Header(None)):
    user_id = _require_user(authorization)
    status = await _referral.get_or_create_code(user_id)
    campaign = await _referral.get_active_campaign()
    return {
        "referralCode": status.referral_code,
        "successfulInvites": status.successful_invites,
        "rewardsClaimed": status.rewards_claimed,
        "campaign": {
            "isActive": campaign.is_active,
            "tiers": [
                {"invitesRequired": t.invites_required, "rewardDays": t.reward_days, "label": t.label}
                for t in campaign.tiers
            ],
        } if campaign else None,
    }


@router.post("/me/referral/apply")
async def apply_referral_code(
    req: ApplyReferralCodeRequest, authorization: Optional[str] = Header(None),
):
    user_id = _require_user(authorization)
    success, message = await _referral.apply_referral_code(user_id, req.code)
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {"success": True, "message": message}


# ── Serialization helpers ─────────────────────────────────────────────────────

def _config_service_to_response(config: SubscriptionConfig) -> dict:
    return {
        "subscriptionsEnabled": config.subscriptions_enabled,
        "plans": {
            k: {"tier": p.tier.value, "displayName": p.display_name,
                "description": p.description, "benefits": p.benefits,
                "priceLabel": p.price_label, "isActive": p.is_active}
            for k, p in config.plans.items()
        },
        "featureAccess": {
            k: {"featureKey": f.feature_key, "displayName": f.display_name,
                "accessLevel": f.access_level.value, "description": f.description}
            for k, f in config.feature_access.items()
        },
        "usageLimits": {
            k: {"featureKey": u.feature_key, "monthlyLimit": u.monthly_limit}
            for k, u in config.usage_limits.items()
        },
        "trial": {
            "enabled": config.trial.enabled,
            "durationDays": config.trial.duration_days,
            "requiresNoPriorTrial": config.trial.requires_no_prior_trial,
        },
    }


def _sub_to_dict(sub) -> dict:
    return {
        "userId": sub.user_id,
        "status": sub.status.value,
        "tier": sub.tier.value,
        "source": sub.source.value,
        "isProActive": sub.is_pro_active,
        "expirationDate": sub.expiration_date.isoformat() if sub.expiration_date else None,
        "trialEndsAt": sub.trial_ends_at.isoformat() if sub.trial_ends_at else None,
        "bonusDaysGranted": sub.bonus_days_granted,
    }


def _event_to_dict(event) -> dict:
    return {
        "id": event.id,
        "eventType": event.event_type.value,
        "description": event.description,
        "metadata": event.metadata,
        "createdAt": event.created_at.isoformat(),
    }
