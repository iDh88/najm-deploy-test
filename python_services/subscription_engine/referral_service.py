"""
Subscription Engine — Referral Service
Generates referral codes, tracks successful invites, and grants
admin-configured reward tiers.
"""
from __future__ import annotations
import logging
import random
import string
from datetime import datetime
from typing import Optional

from .models import (
    ReferralCampaign, ReferralTier, UserReferralStatus,
    SubscriptionSource, EventType,
)
from .subscription_service import SubscriptionService

logger = logging.getLogger("cip.subscription.referral")

CODE_LENGTH = 7
CODE_ALPHABET = string.ascii_uppercase + string.digits


class ReferralService:

    def __init__(self):
        self._subs = SubscriptionService()

    async def get_or_create_code(self, user_id: str) -> UserReferralStatus:
        db = self._get_db()
        doc = db.collection("userReferralStatus").document(user_id).get()
        if doc.exists:
            return self._status_from_dict(user_id, doc.to_dict())

        code = await self._generate_unique_code()
        status = UserReferralStatus(user_id=user_id, referral_code=code)
        await self._save_status(status)
        return status

    async def apply_referral_code(self, new_user_id: str, code: str) -> tuple[bool, str]:
        db = self._get_db()

        referrer_query = (db.collection("userReferralStatus")
                         .where("referralCode", "==", code.upper())
                         .limit(1)
                         .stream())
        referrer_docs = list(referrer_query)
        if not referrer_docs:
            return False, "Invalid referral code."

        referrer_doc = referrer_docs[0]
        referrer_id = referrer_doc.id

        if referrer_id == new_user_id:
            return False, "You cannot refer yourself."

        already_invited = db.collection("referralInvites").document(new_user_id).get()
        if already_invited.exists:
            return False, "This account has already used a referral code."

        db.collection("referralInvites").document(new_user_id).set({
            "referrerId": referrer_id,
            "invitedAt": datetime.utcnow().isoformat(),
        })

        status = self._status_from_dict(referrer_id, referrer_doc.to_dict())
        status.successful_invites += 1
        await self._save_status(status)

        await self._check_and_grant_rewards(referrer_id, status)

        return True, "Referral applied successfully."

    async def _check_and_grant_rewards(
        self, referrer_id: str, status: UserReferralStatus,
    ) -> None:
        campaign = await self.get_active_campaign()
        if not campaign or not campaign.is_active:
            return

        for tier in campaign.tiers:
            if (status.successful_invites >= tier.invites_required
                    and tier.invites_required not in status.rewards_claimed):
                await self._subs.grant_bonus_days(
                    referrer_id, tier.reward_days,
                    granted_by="referral_system",
                    reason=f"Referral reward: {tier.label}",
                    source=SubscriptionSource.REFERRAL,
                )
                status.rewards_claimed.append(tier.invites_required)

        await self._save_status(status)

    async def get_active_campaign(self) -> Optional[ReferralCampaign]:
        db = self._get_db()
        doc = db.collection("referralCampaigns").document("main").get()
        if not doc.exists:
            return None
        return self._campaign_from_dict(doc.to_dict())

    async def update_campaign(self, campaign: ReferralCampaign, updated_by: str) -> None:
        db = self._get_db()
        db.collection("referralCampaigns").document("main").set({
            "isActive": campaign.is_active,
            "tiers": [
                {"invitesRequired": t.invites_required,
                 "rewardDays": t.reward_days, "label": t.label}
                for t in campaign.tiers
            ],
            "updatedAt": datetime.utcnow().isoformat(),
            "updatedBy": updated_by,
        })

    async def _generate_unique_code(self) -> str:
        db = self._get_db()
        for _ in range(10):
            code = "".join(random.choices(CODE_ALPHABET, k=CODE_LENGTH))
            existing = (db.collection("userReferralStatus")
                       .where("referralCode", "==", code)
                       .limit(1)
                       .get())
            if not list(existing):
                return code
        raise RuntimeError("Could not generate unique referral code")

    async def _save_status(self, status: UserReferralStatus) -> None:
        db = self._get_db()
        db.collection("userReferralStatus").document(status.user_id).set({
            "referralCode": status.referral_code,
            "successfulInvites": status.successful_invites,
            "rewardsClaimed": status.rewards_claimed,
        })

    def _status_from_dict(self, user_id: str, data: dict) -> UserReferralStatus:
        return UserReferralStatus(
            user_id=user_id,
            referral_code=data.get("referralCode", ""),
            successful_invites=data.get("successfulInvites", 0),
            rewards_claimed=data.get("rewardsClaimed", []),
        )

    def _campaign_from_dict(self, data: dict) -> ReferralCampaign:
        return ReferralCampaign(
            id="main",
            is_active=data.get("isActive", True),
            tiers=[
                ReferralTier(
                    invites_required=t.get("invitesRequired", 1),
                    reward_days=t.get("rewardDays", 7),
                    label=t.get("label", ""),
                )
                for t in data.get("tiers", [])
            ],
        )

    def _get_db(self):
        from utils.firebase import get_firestore
        return get_firestore()
