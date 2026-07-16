"""
Subscription Engine — Subscription Service
Manages per-user UserSubscription records: activation, cancellation,
admin grants, expiration checks.
"""
from __future__ import annotations
import logging
import uuid
from datetime import datetime, timedelta
from typing import Optional

from .models import (
    UserSubscription, SubscriptionStatus, SubscriptionSource, PlanTier,
    SubscriptionEvent, EventType,
)

logger = logging.getLogger("cip.subscription.service")


class SubscriptionService:

    async def get_subscription(self, user_id: str) -> UserSubscription:
        db = self._get_db()
        doc = db.collection("userSubscriptions").document(user_id).get()

        if not doc.exists:
            sub = UserSubscription(user_id=user_id)
            await self._save(sub)
            return sub

        sub = self._from_dict(user_id, doc.to_dict())
        sub = self._resolve_expiry(sub)
        return sub

    async def activate_pro(
        self,
        user_id: str,
        source: SubscriptionSource,
        duration_days: Optional[int] = None,
        product_id: Optional[str] = None,
        granted_by: Optional[str] = None,
    ) -> UserSubscription:
        """
        Activates Pro access. Used for: admin manual activation, promo
        codes, referral rewards, and (later) RevenueCat webhook events.
        """
        sub = await self.get_subscription(user_id)

        sub.status = SubscriptionStatus.ACTIVE if source in (
            SubscriptionSource.APP_STORE, SubscriptionSource.PLAY_STORE
        ) else SubscriptionStatus.GRANTED
        sub.tier = PlanTier.PRO
        sub.source = source
        sub.product_id = product_id

        if duration_days is not None:
            base = sub.expiration_date if (
                sub.expiration_date and sub.expiration_date > datetime.utcnow()
            ) else datetime.utcnow()
            sub.expiration_date = base + timedelta(days=duration_days)

        sub.updated_at = datetime.utcnow()
        await self._save(sub)

        await self._log_event(
            user_id, EventType.SUBSCRIPTION_ACTIVATED,
            description=self._activation_description(source, duration_days),
            metadata={"source": source.value, "grantedBy": granted_by,
                     "durationDays": duration_days},
        )
        return sub

    async def cancel(self, user_id: str, immediate: bool = False) -> UserSubscription:
        sub = await self.get_subscription(user_id)

        if immediate:
            sub.status = SubscriptionStatus.EXPIRED
            sub.tier = PlanTier.FREE
            sub.expiration_date = datetime.utcnow()
        else:
            sub.status = SubscriptionStatus.CANCELLED
            sub.will_renew = False

        sub.updated_at = datetime.utcnow()
        await self._save(sub)

        await self._log_event(
            user_id, EventType.SUBSCRIPTION_CANCELLED,
            description=(
                "Subscription cancelled immediately."
                if immediate else
                "Subscription cancelled — access continues until period end."
            ),
        )
        return sub

    async def admin_revoke(self, user_id: str, revoked_by: str, reason: str = "") -> UserSubscription:
        """Hard admin deactivation — immediate, regardless of remaining time."""
        sub = await self.get_subscription(user_id)
        sub.status = SubscriptionStatus.EXPIRED
        sub.tier = PlanTier.FREE
        sub.expiration_date = datetime.utcnow()
        sub.updated_at = datetime.utcnow()
        await self._save(sub)

        await self._log_event(
            user_id, EventType.ADMIN_REVOKED,
            description=f"Pro access revoked by admin.{f' Reason: {reason}' if reason else ''}",
            metadata={"revokedBy": revoked_by, "reason": reason},
        )
        return sub

    async def grant_bonus_days(
        self, user_id: str, days: int, granted_by: str, reason: str = "",
        source: SubscriptionSource = SubscriptionSource.ADMIN_GRANT,
    ) -> UserSubscription:
        """Stacks bonus days onto current expiration (or starts fresh from now)."""
        sub = await self.get_subscription(user_id)

        base = sub.expiration_date if (
            sub.expiration_date and sub.expiration_date > datetime.utcnow()
        ) else datetime.utcnow()
        sub.expiration_date = base + timedelta(days=days)
        sub.bonus_days_granted += days

        if sub.tier != PlanTier.PRO or not sub.is_pro_active:
            sub.tier = PlanTier.PRO
            sub.status = SubscriptionStatus.GRANTED
            sub.source = source

        sub.updated_at = datetime.utcnow()
        await self._save(sub)

        event_type = (EventType.REFERRAL_REWARD_GRANTED
                     if source == SubscriptionSource.REFERRAL
                     else EventType.ADMIN_GRANTED_DAYS)

        await self._log_event(
            user_id, event_type,
            description=f"+{days} Pro day{'s' if days != 1 else ''} granted.{f' {reason}' if reason else ''}",
            metadata={"days": days, "grantedBy": granted_by, "reason": reason},
        )
        return sub

    async def get_history(self, user_id: str, limit: int = 50) -> list[SubscriptionEvent]:
        db = self._get_db()
        docs = (db.collection("subscriptionEvents")
                .where("userId", "==", user_id)
                .order_by("createdAt", direction="DESCENDING")
                .limit(limit)
                .stream())
        return [self._event_from_dict(d.id, d.to_dict()) for d in docs]

    # ── Private ────────────────────────────────────────────────────────────────

    def _resolve_expiry(self, sub: UserSubscription) -> UserSubscription:
        """If a Pro/trial period has lapsed, flip status without a background job."""
        now = datetime.utcnow()

        if sub.status == SubscriptionStatus.TRIAL and sub.trial_ends_at and now >= sub.trial_ends_at:
            sub.status = SubscriptionStatus.EXPIRED
            sub.tier = PlanTier.FREE

        elif sub.status in (SubscriptionStatus.ACTIVE, SubscriptionStatus.GRANTED, SubscriptionStatus.CANCELLED):
            if sub.expiration_date and now >= sub.expiration_date:
                sub.status = SubscriptionStatus.EXPIRED
                sub.tier = PlanTier.FREE

        return sub

    def _activation_description(
        self, source: SubscriptionSource, duration_days: Optional[int]
    ) -> str:
        if source == SubscriptionSource.APP_STORE:
            return "Pro subscription activated via App Store."
        if source == SubscriptionSource.PLAY_STORE:
            return "Pro subscription activated via Google Play."
        if source == SubscriptionSource.PROMO:
            return f"Promotional Pro access activated{f' ({duration_days} days)' if duration_days else ''}."
        if source == SubscriptionSource.REFERRAL:
            return f"Pro access granted from referral reward ({duration_days} days)."
        return f"Pro access manually activated by admin{f' ({duration_days} days)' if duration_days else ''}."

    async def _log_event(
        self, user_id: str, event_type: EventType,
        description: str, metadata: Optional[dict] = None,
    ) -> None:
        db = self._get_db()
        event_id = str(uuid.uuid4())
        db.collection("subscriptionEvents").document(event_id).set({
            "userId": user_id,
            "eventType": event_type.value,
            "description": description,
            "metadata": metadata or {},
            "createdAt": datetime.utcnow().isoformat(),
        })

    async def _save(self, sub: UserSubscription) -> None:
        db = self._get_db()
        db.collection("userSubscriptions").document(sub.user_id).set(
            self._to_dict(sub))

    def _to_dict(self, sub: UserSubscription) -> dict:
        return {
            "status": sub.status.value,
            "tier": sub.tier.value,
            "source": sub.source.value,
            "productId": sub.product_id,
            "store": sub.store,
            "originalPurchaseDate": (
                sub.original_purchase_date.isoformat()
                if sub.original_purchase_date else None),
            "expirationDate": (
                sub.expiration_date.isoformat() if sub.expiration_date else None),
            "willRenew": sub.will_renew,
            "trialStartedAt": (
                sub.trial_started_at.isoformat() if sub.trial_started_at else None),
            "trialEndsAt": (
                sub.trial_ends_at.isoformat() if sub.trial_ends_at else None),
            "hasUsedTrial": sub.has_used_trial,
            "bonusDaysGranted": sub.bonus_days_granted,
            "createdAt": sub.created_at.isoformat(),
            "updatedAt": sub.updated_at.isoformat(),
        }

    def _from_dict(self, user_id: str, data: dict) -> UserSubscription:
        def _dt(key: str) -> Optional[datetime]:
            v = data.get(key)
            return datetime.fromisoformat(v) if v else None

        return UserSubscription(
            user_id=user_id,
            status=SubscriptionStatus(data.get("status", "NONE")),
            tier=PlanTier(data.get("tier", "FREE")),
            source=SubscriptionSource(data.get("source", "NONE")),
            product_id=data.get("productId"),
            store=data.get("store"),
            original_purchase_date=_dt("originalPurchaseDate"),
            expiration_date=_dt("expirationDate"),
            will_renew=data.get("willRenew", False),
            trial_started_at=_dt("trialStartedAt"),
            trial_ends_at=_dt("trialEndsAt"),
            has_used_trial=data.get("hasUsedTrial", False),
            bonus_days_granted=data.get("bonusDaysGranted", 0),
            created_at=_dt("createdAt") or datetime.utcnow(),
            updated_at=_dt("updatedAt") or datetime.utcnow(),
        )

    def _event_from_dict(self, event_id: str, data: dict) -> SubscriptionEvent:
        return SubscriptionEvent(
            id=event_id,
            user_id=data.get("userId", ""),
            event_type=EventType(data.get("eventType", "ADMIN_GRANTED_DAYS")),
            description=data.get("description", ""),
            metadata=data.get("metadata", {}),
            created_at=datetime.fromisoformat(data["createdAt"]) if data.get("createdAt") else datetime.utcnow(),
        )

    def _get_db(self):
        from utils.firebase import get_firestore
        return get_firestore()
