"""
Behavioral Learning — Profile Rebuild Job
Weekly background task: rebuilds all preference profiles from raw events.
Ensures profiles stay consistent even if incremental updates were missed.
Can be triggered by Cloud Scheduler or run as a standalone script.
"""
from __future__ import annotations
import asyncio
import logging
from datetime import datetime

logger = logging.getLogger("cip.behavioral_learning.rebuild_job")


async def rebuild_all_profiles(batch_size: int = 50) -> dict:
    """
    Rebuilds preference profiles for all crew who had behavioral events
    in the last 30 days. Runs in batches to avoid memory pressure.
    """
    try:
        from utils.firebase import get_firestore
        from preference_engine.profile_service import ProfileService

        db  = get_firestore()
        svc = ProfileService()

        # Find unique users with recent events
        from datetime import timedelta
        cutoff = datetime.utcnow() - timedelta(days=30)

        docs = (db.collection("behaviorEvents")
                  .where("recorded_at", ">=", cutoff.isoformat())
                  .stream())

        user_ids = list({d.to_dict().get("user_id") for d in docs
                         if d.to_dict().get("user_id")})

        logger.info(f"Rebuilding profiles for {len(user_ids)} users")
        rebuilt = 0
        failed  = 0

        # Process in batches
        for i in range(0, len(user_ids), batch_size):
            batch = user_ids[i:i + batch_size]
            tasks = [svc.rebuild_profile(uid) for uid in batch]
            results = await asyncio.gather(*tasks, return_exceptions=True)

            for uid, result in zip(batch, results):
                if isinstance(result, Exception):
                    logger.warning(f"Profile rebuild failed for {uid}: {result}")
                    failed += 1
                else:
                    rebuilt += 1

            # Small delay between batches to avoid Firestore quota spikes
            await asyncio.sleep(0.5)

        summary = {
            "rebuilt": rebuilt,
            "failed":  failed,
            "total":   len(user_ids),
            "run_at":  datetime.utcnow().isoformat(),
        }
        logger.info(f"Profile rebuild complete: {summary}")
        return summary

    except Exception as e:
        logger.exception(f"Profile rebuild job failed: {e}")
        return {"error": str(e)}


if __name__ == "__main__":
    asyncio.run(rebuild_all_profiles())
