"""
Subscription Engine — Notification Triggers
Invoked by Cloud Scheduler. Scans for users whose trial/subscription is
ending soon and queues notifications for the existing FCM dispatcher.
"""
from __future__ import annotations
import asyncio
import logging
from datetime import datetime, timedelta

logger = logging.getLogger("cip.subscription.notifications")

TRIAL_WARNING_DAYS = [3, 1]
SUBSCRIPTION_WARNING_DAYS = [7, 1]


async def check_trial_ending_soon() -> dict:
    from utils.firebase import get_firestore
    db = get_firestore()

    now = datetime.utcnow()
    notified = 0

    for days_before in TRIAL_WARNING_DAYS:
        window_start = now + timedelta(days=days_before - 0.5)
        window_end   = now + timedelta(days=days_before + 0.5)

        docs = (db.collection("userSubscriptions")
                .where("status", "==", "TRIAL")
                .stream())

        for doc in docs:
            data = doc.to_dict()
            trial_ends_at = data.get("trialEndsAt")
            if not trial_ends_at:
                continue
            ends_dt = datetime.fromisoformat(trial_ends_at)
            if window_start <= ends_dt <= window_end:
                await _queue_notification(
                    db, doc.id, "TRIAL_ENDING_SOON",
                    title="Your free trial is ending soon",
                    body=f"Your Pro trial ends in {days_before} day"
                         f"{'s' if days_before != 1 else ''}. Subscribe to keep your access.",
                    metadata={"daysRemaining": days_before},
                )
                notified += 1

    logger.info(f"Trial-ending notifications queued: {notified}")
    return {"notified": notified}


async def check_subscription_expiring_soon() -> dict:
    from utils.firebase import get_firestore
    db = get_firestore()

    now = datetime.utcnow()
    notified = 0

    for days_before in SUBSCRIPTION_WARNING_DAYS:
        window_start = now + timedelta(days=days_before - 0.5)
        window_end   = now + timedelta(days=days_before + 0.5)

        docs = (db.collection("userSubscriptions")
                .where("status", "in", ["ACTIVE", "CANCELLED"])
                .stream())

        for doc in docs:
            data = doc.to_dict()
            expiration = data.get("expirationDate")
            if not expiration:
                continue
            exp_dt = datetime.fromisoformat(expiration)
            if window_start <= exp_dt <= window_end:
                will_renew = data.get("willRenew", False)
                title = "Your subscription renews soon" if will_renew else "Your subscription is ending soon"
                body = (
                    f"Your Pro subscription renews in {days_before} day"
                    f"{'s' if days_before != 1 else ''}."
                    if will_renew else
                    f"Your Pro access ends in {days_before} day"
                    f"{'s' if days_before != 1 else ''}. Resubscribe to keep your access."
                )
                await _queue_notification(
                    db, doc.id, "SUBSCRIPTION_EXPIRING_SOON",
                    title=title, body=body,
                    metadata={"daysRemaining": days_before, "willRenew": will_renew},
                )
                notified += 1

    logger.info(f"Subscription-expiring notifications queued: {notified}")
    return {"notified": notified}


async def _queue_notification(
    db, user_id: str, notif_type: str, title: str, body: str, metadata: dict,
) -> None:
    dedup_key = f"{user_id}_{notif_type}_{datetime.utcnow().date().isoformat()}"
    existing = db.collection("notifications").document(dedup_key).get()
    if existing.exists:
        return

    db.collection("notifications").document(dedup_key).set({
        "userId": user_id,
        "type": notif_type,
        "title": title,
        "body": body,
        "metadata": metadata,
        "read": False,
        "createdAt": datetime.utcnow().isoformat(),
    })


async def run_all_checks() -> dict:
    trial_result = await check_trial_ending_soon()
    sub_result = await check_subscription_expiring_soon()
    return {"trial": trial_result, "subscription": sub_result}


if __name__ == "__main__":
    asyncio.run(run_all_checks())
