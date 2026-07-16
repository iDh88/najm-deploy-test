"""
Preference Profile Service
Reads/writes UserPreferenceProfile to Firestore.
Handles incremental updates and cold-start defaults.
"""
from __future__ import annotations
import logging
from datetime import datetime
from typing import Optional
import uuid

from .models import (
    UserPreferenceProfile, BehavioralEvent, TradeOutcome,
    RouteFrequencyEntry, DestinationPreference,
    SchedulePatternPreference, FatigueToleranceProfile,
)
from .profile_builder import ProfileBuilder

logger = logging.getLogger("cip.preference.profile_service")
_builder = ProfileBuilder()


class ProfileService:
    """
    Firestore-backed service for preference profiles.
    Collection: users/{userId}/preferenceProfile/main
    Events log: behaviorEvents/{eventId}
    """

    def __init__(self):
        try:
            from utils.firebase import get_firestore
            self._db = get_firestore()
        except Exception:
            self._db = None
            logger.warning("Firestore unavailable — using in-memory mode")
        self._memory: dict[str, UserPreferenceProfile] = {}

    # ── Public API ─────────────────────────────────────────────────────────────

    async def get_profile(self, user_id: str) -> UserPreferenceProfile:
        """Load profile from Firestore, or return cold-start default."""
        if self._db:
            try:
                doc = (self._db.collection("users")
                       .document(user_id)
                       .collection("preferenceProfile")
                       .document("main")
                       .get())
                if doc.exists:
                    return self._from_firestore(user_id, doc.to_dict())
            except Exception as e:
                logger.warning(f"Profile read failed for {user_id}: {e}")

        # In-memory fallback
        if user_id in self._memory:
            return self._memory[user_id]

        return UserPreferenceProfile(user_id=user_id, is_cold_start=True)

    async def record_event(
        self,
        user_id:    str,
        trade_id:   str,
        outcome:    TradeOutcome,
        trade_data: dict,
    ) -> None:
        """
        Record one behavioral event and update the preference profile.
        trade_data must contain: route_key, destinations, block_hours,
        duty_hours, fatigue_score, is_international, has_deadhead,
        signin_hour, layover_hours, rest_after_hours.
        """
        event = BehavioralEvent(
            event_id         = str(uuid.uuid4()),
            user_id          = user_id,
            trade_id         = trade_id,
            outcome          = outcome,
            route_key        = trade_data.get("route_key", ""),
            destinations     = trade_data.get("destinations", []),
            block_hours      = float(trade_data.get("block_hours", 0)),
            duty_hours       = float(trade_data.get("duty_hours", 0)),
            fatigue_score    = float(trade_data.get("fatigue_score", 0)),
            is_international = bool(trade_data.get("is_international", False)),
            has_deadhead     = bool(trade_data.get("has_deadhead", False)),
            signin_hour      = int(trade_data.get("signin_hour", 8)),
            layover_hours    = float(trade_data.get("layover_hours", 0)),
            rest_after_hours = float(trade_data.get("rest_after_hours", 0)),
        )

        # Write event to Firestore
        if self._db:
            try:
                self._db.collection("behaviorEvents").document(event.event_id).set(
                    event.model_dump(mode="json")
                )
            except Exception as e:
                logger.warning(f"Event write failed: {e}")

        # Incremental profile update
        profile = await self.get_profile(user_id)
        profile = _builder.apply_event(profile, event)
        await self._save_profile(profile)

    async def rebuild_profile(self, user_id: str) -> UserPreferenceProfile:
        """
        Full profile rebuild from all historical events.
        Called periodically (e.g. weekly) or after a bulk import.
        """
        events = await self._load_all_events(user_id)
        profile = _builder.build(user_id, events)
        await self._save_profile(profile)
        return profile

    # ── Private ────────────────────────────────────────────────────────────────

    async def _save_profile(self, profile: UserPreferenceProfile) -> None:
        data = profile.model_dump(mode="json")
        if self._db:
            try:
                (self._db.collection("users")
                 .document(profile.user_id)
                 .collection("preferenceProfile")
                 .document("main")
                 .set(data))
            except Exception as e:
                logger.warning(f"Profile write failed: {e}")
        self._memory[profile.user_id] = profile

    async def _load_all_events(
        self, user_id: str
    ) -> list[BehavioralEvent]:
        if not self._db:
            return []
        try:
            docs = (self._db.collection("behaviorEvents")
                    .where("user_id", "==", user_id)
                    .order_by("recorded_at")
                    .stream())
            result = []
            for doc in docs:
                try:
                    result.append(BehavioralEvent(**doc.to_dict()))
                except Exception:
                    pass
            return result
        except Exception as e:
            logger.warning(f"Events load failed for {user_id}: {e}")
            return []

    def _from_firestore(
        self, user_id: str, data: dict
    ) -> UserPreferenceProfile:
        """Reconstruct a UserPreferenceProfile from Firestore dict."""
        try:
            # Reconstruct nested dicts
            route_freq = {
                k: RouteFrequencyEntry(**v)
                for k, v in data.get("route_frequency", {}).items()
            }
            dest_prefs = {
                k: DestinationPreference(**v)
                for k, v in data.get("destination_preferences", {}).items()
            }
            sp  = SchedulePatternPreference(
                **data.get("schedule_pattern", {}))
            ft  = FatigueToleranceProfile(
                **data.get("fatigue_tolerance", {}))

            return UserPreferenceProfile(
                user_id                 = user_id,
                updated_at              = data.get("updated_at", datetime.utcnow()),
                total_events            = data.get("total_events", 0),
                route_frequency         = route_freq,
                destination_preferences = dest_prefs,
                schedule_pattern        = sp,
                fatigue_tolerance       = ft,
                top_routes              = data.get("top_routes", []),
                top_destinations        = data.get("top_destinations", []),
                preferred_timing_band   = data.get("preferred_timing_band", "morning"),
                is_cold_start           = data.get("is_cold_start", True),
            )
        except Exception as e:
            logger.warning(f"Profile parse error for {user_id}: {e}")
            return UserPreferenceProfile(user_id=user_id, is_cold_start=True)
