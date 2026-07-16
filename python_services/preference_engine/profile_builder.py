"""
Preference Profile Builder
Constructs and updates a UserPreferenceProfile from raw behavioral events.
All signals are derived from the user's own operational history only.
"""
from __future__ import annotations
import logging
from datetime import datetime, timedelta
from collections import defaultdict
from typing import Optional

from .models import (
    UserPreferenceProfile, BehavioralEvent, TradeOutcome,
    RouteFrequencyEntry, DestinationPreference,
    SchedulePatternPreference, FatigueToleranceProfile,
)

logger = logging.getLogger("cip.preference.profile_builder")

# Minimum events before we trust the profile
COLD_START_THRESHOLD  = 5
STRONG_SIGNAL_COUNT   = 10
ROUTE_TOP_N           = 5
DESTINATION_TOP_N     = 8
RECENCY_WINDOW_DAYS   = 120     # events older than this decay in weight
RECENCY_DECAY_FACTOR  = 0.6     # weight multiplier for old events


class ProfileBuilder:
    """
    Builds a UserPreferenceProfile from a list of BehavioralEvents.
    Called by the preference update service after each new event.
    """

    def build(
        self,
        user_id: str,
        events: list[BehavioralEvent],
    ) -> UserPreferenceProfile:
        """Full rebuild from all events. Used on first build or periodic refresh."""
        if not events:
            return UserPreferenceProfile(
                user_id=user_id,
                is_cold_start=True,
            )

        profile = UserPreferenceProfile(
            user_id=user_id,
            total_events=len(events),
            is_cold_start=len(events) < COLD_START_THRESHOLD,
        )

        profile.route_frequency         = self._build_route_frequency(events)
        profile.destination_preferences = self._build_destination_prefs(events)
        profile.schedule_pattern        = self._build_schedule_pattern(events)
        profile.fatigue_tolerance       = self._build_fatigue_tolerance(events)
        profile.top_routes              = self._top_routes(profile.route_frequency)
        profile.top_destinations        = self._top_destinations(profile.destination_preferences)
        profile.preferred_timing_band   = self._timing_band(profile.schedule_pattern)
        profile.updated_at              = datetime.utcnow()

        return profile

    def apply_event(
        self,
        profile: UserPreferenceProfile,
        event: BehavioralEvent,
    ) -> UserPreferenceProfile:
        """
        Incremental update — apply a single new event to an existing profile.
        Much cheaper than full rebuild; called after every trade interaction.
        """
        profile.total_events += 1
        profile.is_cold_start = profile.total_events < COLD_START_THRESHOLD
        weight = self._recency_weight(event.recorded_at)

        # Update route frequency
        key = event.route_key
        if key not in profile.route_frequency:
            profile.route_frequency[key] = RouteFrequencyEntry(route=key)
        entry = profile.route_frequency[key]

        if event.outcome == TradeOutcome.ACCEPTED:
            entry.accept_count  += 1
            entry.last_accepted_at = event.recorded_at
        elif event.outcome == TradeOutcome.REJECTED:
            entry.reject_count  += 1
        elif event.outcome == TradeOutcome.VIEWED:
            entry.view_count    += 1
        entry.last_seen_at = event.recorded_at

        # Update destination preferences
        for iata in event.destinations:
            if iata not in profile.destination_preferences:
                profile.destination_preferences[iata] = DestinationPreference(iata=iata)
            dp = profile.destination_preferences[iata]
            if event.outcome == TradeOutcome.ACCEPTED:
                dp.accept_count += 1
                dp.last_visited_at = event.recorded_at
                # Running average for layover hours
                if event.layover_hours > 0:
                    n = dp.accept_count
                    dp.layover_hours_avg = (
                        (dp.layover_hours_avg * (n - 1) + event.layover_hours) / n
                    )
            elif event.outcome == TradeOutcome.REJECTED:
                dp.reject_count += 1

        # Update fatigue tolerance
        if event.outcome == TradeOutcome.ACCEPTED:
            ft = profile.fatigue_tolerance
            ft.total_accepts += 1
            n = ft.total_accepts
            ft.avg_fatigue_of_accepted = (
                (ft.avg_fatigue_of_accepted * (n - 1) + event.fatigue_score) / n
            )
            ft.max_fatigue_accepted = max(ft.max_fatigue_accepted, event.fatigue_score)
            if event.fatigue_score >= 0.65:
                ft.high_fatigue_accepts += 1
            ft.tolerance_level = ft.compute_tolerance()

        # Refresh aggregates
        profile.top_routes       = self._top_routes(profile.route_frequency)
        profile.top_destinations = self._top_destinations(profile.destination_preferences)
        profile.updated_at       = datetime.utcnow()

        return profile

    # ── Private helpers ───────────────────────────────────────────────────────

    def _build_route_frequency(
        self, events: list[BehavioralEvent]
    ) -> dict[str, RouteFrequencyEntry]:
        freq: dict[str, RouteFrequencyEntry] = {}
        for ev in events:
            w = self._recency_weight(ev.recorded_at)
            key = ev.route_key
            if key not in freq:
                freq[key] = RouteFrequencyEntry(route=key)
            e = freq[key]
            if ev.outcome == TradeOutcome.ACCEPTED:
                e.accept_count      = int(e.accept_count + w)
                e.last_accepted_at  = max(
                    e.last_accepted_at or ev.recorded_at, ev.recorded_at
                )
            elif ev.outcome == TradeOutcome.REJECTED:
                e.reject_count = int(e.reject_count + w)
            elif ev.outcome == TradeOutcome.VIEWED:
                e.view_count   = int(e.view_count + w)
            e.last_seen_at = max(e.last_seen_at or ev.recorded_at, ev.recorded_at)
        return freq

    def _build_destination_prefs(
        self, events: list[BehavioralEvent]
    ) -> dict[str, DestinationPreference]:
        prefs: dict[str, DestinationPreference] = {}
        layover_sums:   dict[str, float] = defaultdict(float)
        layover_counts: dict[str, int]   = defaultdict(int)

        for ev in events:
            w = self._recency_weight(ev.recorded_at)
            for iata in ev.destinations:
                if iata not in prefs:
                    prefs[iata] = DestinationPreference(iata=iata)
                dp = prefs[iata]
                if ev.outcome == TradeOutcome.ACCEPTED:
                    dp.accept_count = int(dp.accept_count + w)
                    dp.last_visited_at = max(
                        dp.last_visited_at or ev.recorded_at, ev.recorded_at
                    )
                    if ev.layover_hours > 0:
                        layover_sums[iata]   += ev.layover_hours
                        layover_counts[iata] += 1
                elif ev.outcome == TradeOutcome.REJECTED:
                    dp.reject_count = int(dp.reject_count + w)

        for iata, dp in prefs.items():
            if layover_counts[iata] > 0:
                dp.layover_hours_avg = layover_sums[iata] / layover_counts[iata]

        return prefs

    def _build_schedule_pattern(
        self, events: list[BehavioralEvent]
    ) -> SchedulePatternPreference:
        accepted = [e for e in events if e.outcome == TradeOutcome.ACCEPTED]
        if not accepted:
            return SchedulePatternPreference()

        signin_hours     = [e.signin_hour for e in accepted]
        block_hours_list = [e.block_hours  for e in accepted]
        layover_list     = [e.layover_hours for e in accepted if e.layover_hours > 0]
        intl_count       = sum(1 for e in accepted if e.is_international)
        dh_count         = sum(1 for e in accepted if e.has_deadhead)
        n                = len(accepted)

        avg_signin   = sum(signin_hours) / n
        early_count  = sum(1 for h in signin_hours if h < 6)

        pref_signin_start = max(0,  int(min(signin_hours)))
        pref_signin_end   = min(23, int(max(signin_hours)))

        return SchedulePatternPreference(
            preferred_signin_hour_start = pref_signin_start,
            preferred_signin_hour_end   = pref_signin_end,
            preferred_layover_min_hours = min(layover_list) if layover_list else 10.0,
            preferred_layover_max_hours = max(layover_list) if layover_list else 72.0,
            preferred_block_min         = min(block_hours_list),
            preferred_block_max         = max(block_hours_list),
            prefers_international       = intl_count / n > 0.5,
            prefers_long_layovers       = (
                sum(h > 24 for h in layover_list) / max(len(layover_list), 1) > 0.5
            ),
            avoids_early_signin         = early_count / n < 0.2,
            avoids_deadhead             = dh_count / n < 0.2,
            confidence                  = min(n / STRONG_SIGNAL_COUNT, 1.0),
        )

    def _build_fatigue_tolerance(
        self, events: list[BehavioralEvent]
    ) -> FatigueToleranceProfile:
        accepted = [e for e in events if e.outcome == TradeOutcome.ACCEPTED]
        if not accepted:
            return FatigueToleranceProfile()

        scores     = [e.fatigue_score for e in accepted]
        high_count = sum(1 for s in scores if s >= 0.65)
        avg        = sum(scores) / len(scores)
        ft = FatigueToleranceProfile(
            avg_fatigue_of_accepted = avg,
            max_fatigue_accepted    = max(scores),
            high_fatigue_accepts    = high_count,
            total_accepts           = len(accepted),
        )
        ft.tolerance_level = ft.compute_tolerance()
        return ft

    def _top_routes(
        self, freq: dict[str, RouteFrequencyEntry]
    ) -> list[str]:
        scored = sorted(
            freq.items(),
            key=lambda kv: kv[1].engagement_score,
            reverse=True,
        )
        return [k for k, _ in scored[:ROUTE_TOP_N]]

    def _top_destinations(
        self, prefs: dict[str, DestinationPreference]
    ) -> list[str]:
        scored = sorted(
            prefs.items(),
            key=lambda kv: kv[1].preference_score,
            reverse=True,
        )
        return [k for k, _ in scored[:DESTINATION_TOP_N]]

    def _timing_band(self, sp: SchedulePatternPreference) -> str:
        avg = (sp.preferred_signin_hour_start + sp.preferred_signin_hour_end) / 2
        if avg < 6:    return "early"
        if avg < 12:   return "morning"
        if avg < 18:   return "afternoon"
        return "evening"

    def _recency_weight(self, recorded_at: datetime) -> float:
        """Events older than RECENCY_WINDOW_DAYS contribute less."""
        age_days = (datetime.utcnow() - recorded_at).days
        if age_days <= 30:
            return 1.0
        if age_days <= RECENCY_WINDOW_DAYS:
            return RECENCY_DECAY_FACTOR
        return RECENCY_DECAY_FACTOR * 0.3
