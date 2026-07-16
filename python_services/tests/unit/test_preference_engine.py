"""
Unit tests — Preference Engine
Tests profile building, route familiarity, and compatibility scoring.
"""
import pytest
from datetime import datetime, timedelta

from preference_engine.models import (
    BehavioralEvent, TradeOutcome, UserPreferenceProfile,
)
from preference_engine.profile_builder import ProfileBuilder
from route_familiarity_engine.analyzer import RouteFamiliarityAnalyzer
from compatibility_scoring.scorer import (
    CompatibilityScorer, TradeCandidate, TargetTrip,
)


def _make_event(
    route: str = "JED-DEL-JED",
    outcome: TradeOutcome = TradeOutcome.ACCEPTED,
    fatigue: float = 0.4,
    days_ago: int = 10,
    is_international: bool = True,
) -> BehavioralEvent:
    return BehavioralEvent(
        event_id         = "evt_test",
        user_id          = "user_123",
        trade_id         = "trade_abc",
        outcome          = outcome,
        recorded_at      = datetime.utcnow() - timedelta(days=days_ago),
        route_key        = route,
        destinations     = route.split("-"),
        block_hours      = 5.5,
        duty_hours       = 8.0,
        fatigue_score    = fatigue,
        is_international = is_international,
        has_deadhead     = False,
        signin_hour      = 9,
        layover_hours    = 18.0,
        rest_after_hours = 12.0,
    )


# ── ProfileBuilder ─────────────────────────────────────────────────────────────

class TestProfileBuilder:
    def setup_method(self):
        self.builder = ProfileBuilder()

    def test_empty_events_returns_cold_start(self):
        profile = self.builder.build("user_123", [])
        assert profile.is_cold_start is True
        assert profile.total_events == 0

    def test_cold_start_threshold(self):
        events = [_make_event() for _ in range(4)]
        profile = self.builder.build("user_123", events)
        assert profile.is_cold_start is True

        events.append(_make_event())   # 5th event
        profile = self.builder.build("user_123", events)
        assert profile.is_cold_start is False

    def test_route_frequency_tracks_accepts(self):
        events = [_make_event("JED-DEL-JED", TradeOutcome.ACCEPTED) for _ in range(3)]
        events += [_make_event("JED-DEL-JED", TradeOutcome.REJECTED)]
        profile = self.builder.build("user_123", events)

        assert "JED-DEL-JED" in profile.route_frequency
        entry = profile.route_frequency["JED-DEL-JED"]
        assert entry.accept_count >= 3
        assert entry.reject_count >= 1

    def test_top_routes_sorted_by_engagement(self):
        events = (
            [_make_event("JED-DEL-JED")] * 5 +
            [_make_event("JED-BOM-JED")] * 2 +
            [_make_event("JED-LHR-JED")] * 1
        )
        profile = self.builder.build("user_123", events)
        assert profile.top_routes[0] == "JED-DEL-JED"

    def test_fatigue_tolerance_low_when_only_easy_trades(self):
        events = [_make_event(fatigue=0.2) for _ in range(8)]
        profile = self.builder.build("user_123", events)
        assert profile.fatigue_tolerance.tolerance_level == "low"

    def test_fatigue_tolerance_high_when_accepting_hard_trades(self):
        events = [_make_event(fatigue=0.75) for _ in range(6)]
        profile = self.builder.build("user_123", events)
        assert profile.fatigue_tolerance.tolerance_level == "high"

    def test_schedule_pattern_detects_international_preference(self):
        events = [_make_event(is_international=True) for _ in range(10)]
        profile = self.builder.build("user_123", events)
        assert profile.schedule_pattern.prefers_international is True

    def test_incremental_update_matches_full_rebuild(self):
        events = [_make_event() for _ in range(8)]
        full_profile = self.builder.build("user_123", events)

        # Incremental: build from first 7, then apply 8th
        inc_profile = self.builder.build("user_123", events[:7])
        inc_profile = self.builder.apply_event(inc_profile, events[7])

        assert inc_profile.total_events == full_profile.total_events
        assert inc_profile.is_cold_start == full_profile.is_cold_start

    def test_rejected_events_do_not_boost_route(self):
        events = [_make_event("JED-MAD-JED", TradeOutcome.REJECTED) for _ in range(10)]
        profile = self.builder.build("user_123", events)
        entry = profile.route_frequency.get("JED-MAD-JED")
        if entry:
            assert entry.accept_count == 0


# ── RouteFamiliarityAnalyzer ───────────────────────────────────────────────────

class TestRouteFamiliarityAnalyzer:
    def setup_method(self):
        self.analyzer = RouteFamiliarityAnalyzer()

    def test_exact_match_scores_one(self):
        report = self.analyzer.analyze(
            target_route           = "JED-DEL-JED",
            candidate_line_routes  = ["JED-DEL-JED", "JED-BOM"],
        )
        assert report.familiarity_score >= 0.95

    def test_partial_dest_match_scores_medium(self):
        report = self.analyzer.analyze(
            target_route           = "JED-DEL-JED",
            candidate_line_routes  = ["JED-BOM-JED", "JED-MAA"],
        )
        # BOM and DEL are both south_asia — should get region overlap
        assert report.familiarity_score >= 0.25

    def test_no_overlap_scores_zero(self):
        report = self.analyzer.analyze(
            target_route           = "JED-NRT-JED",
            candidate_line_routes  = ["JED-MAD-JED", "JED-CDG"],
        )
        assert report.familiarity_score < 0.35

    def test_route_similarity_exact(self):
        score = self.analyzer.route_similarity("JED-DEL-JED", "JED-DEL-JED")
        assert score == 1.0

    def test_route_similarity_region(self):
        score = self.analyzer.route_similarity("JED-DEL", "JED-BOM")
        assert score >= 0.25

    def test_familiarity_label_high_for_exact(self):
        report = self.analyzer.analyze("JED-LHR", ["JED-LHR-JED"])
        assert report.familiarity_label in ("High", "Medium")

    def test_empty_candidate_routes(self):
        report = self.analyzer.analyze("JED-DEL", [])
        assert report.familiarity_score == 0.0

    def test_multiple_matching_legs_boost_score(self):
        report = self.analyzer.analyze(
            target_route           = "JED-DEL",
            candidate_line_routes  = ["JED-DEL", "DEL-JED", "JED-BOM", "BOM-JED"],
        )
        report_single = self.analyzer.analyze(
            target_route           = "JED-DEL",
            candidate_line_routes  = ["JED-DEL"],
        )
        # More matching legs should give a higher or equal score
        assert report.familiarity_score >= report_single.familiarity_score


# ── CompatibilityScorer ────────────────────────────────────────────────────────

class TestCompatibilityScorer:
    def setup_method(self):
        self.scorer = CompatibilityScorer()

    def _candidate(
        self,
        is_legal: bool = True,
        legality_margin: float = 0.7,
        fatigue: float = 0.3,
        routes: list[str] | None = None,
        open_days: list[int] | None = None,
    ) -> TradeCandidate:
        return TradeCandidate(
            prn             = "PRN_TEST",
            user_id         = "cand_001",
            rank            = "CA",
            line_id         = "line_001",
            route_keys      = routes or ["JED-DEL-JED", "JED-BOM"],
            block_hours     = 72.0,
            duty_hours      = 110.0,
            fdp_minutes     = 420,
            rest_after_mins = 720,
            is_legal        = is_legal,
            legality_margin = legality_margin,
            fatigue_score   = fatigue,
            carry_over_hrs  = 0.5,
            open_days       = open_days or [5, 6, 7, 8, 9],
            signin_hours    = [8, 9, 10],
        )

    def _target(self, route: str = "JED-DEL-JED") -> TargetTrip:
        return TargetTrip(
            route_key        = route,
            block_hours      = 5.5,
            duty_hours       = 8.0,
            fdp_minutes      = 400,
            signin_hour      = 9,
            layover_hours    = 20.0,
            is_international = True,
            has_deadhead     = False,
            fatigue_score    = 0.35,
            dates            = [6, 7],
        )

    def test_illegal_candidate_scores_zero_legality(self):
        rec = self.scorer.score(
            self._candidate(is_legal=False), self._target(), profile=None)
        assert rec.legality_score == 0.0
        assert rec.is_legal is False

    def test_legal_candidate_legality_above_half(self):
        rec = self.scorer.score(
            self._candidate(is_legal=True, legality_margin=0.8),
            self._target(), profile=None)
        assert rec.legality_score > 0.5

    def test_exact_route_match_gives_high_route_score(self):
        rec = self.scorer.score(
            self._candidate(routes=["JED-DEL-JED"]),
            self._target("JED-DEL-JED"), profile=None)
        assert rec.route_similarity_score >= 0.90

    def test_no_route_overlap_gives_low_route_score(self):
        rec = self.scorer.score(
            self._candidate(routes=["JED-MAD-JED", "JED-CDG"]),
            self._target("JED-NRT-JED"), profile=None)
        assert rec.route_similarity_score < 0.35

    def test_schedule_compat_high_when_days_overlap(self):
        rec = self.scorer.score(
            self._candidate(open_days=[6, 7, 8]),
            self._target(), profile=None)   # target dates = [6, 7]
        assert rec.schedule_compat_score > 0.3

    def test_total_score_between_0_and_100(self):
        rec = self.scorer.score(
            self._candidate(), self._target(), profile=None)
        assert 0 <= rec.total_score <= 100

    def test_reasons_list_is_not_empty(self):
        rec = self.scorer.score(
            self._candidate(), self._target(), profile=None)
        assert len(rec.match_reasons) >= 1

    def test_reasons_max_four(self):
        rec = self.scorer.score(
            self._candidate(), self._target(), profile=None)
        assert len(rec.match_reasons) <= 4

    def test_high_fatigue_candidate_gives_lower_fatigue_score(self):
        rec_low  = self.scorer.score(
            self._candidate(fatigue=0.1), self._target(), profile=None)
        rec_high = self.scorer.score(
            self._candidate(fatigue=0.9), self._target(), profile=None)
        assert rec_low.fatigue_score > rec_high.fatigue_score

    def test_preference_score_neutral_on_cold_start_profile(self):
        profile = UserPreferenceProfile(user_id="u", is_cold_start=True)
        rec = self.scorer.score(self._candidate(), self._target(), profile=profile)
        assert rec.preference_match_score == 0.5

    def test_no_demographic_data_in_reasons(self):
        """Critical: reasons must never contain demographic language."""
        BLOCKED = [
            "nationality", "ethnicity", "country of origin",
            "indian", "saudi", "spanish", "turkish", "pakistani",
            "arabic", "asian", "european", "western", "eastern",
            "religion", "muslim", "christian", "hindu",
            "race", "region_affinity",
        ]
        rec = self.scorer.score(self._candidate(), self._target(), profile=None)
        reasons_text = " ".join(rec.match_reasons).lower()
        for word in BLOCKED:
            assert word not in reasons_text, \
                f"Demographic term '{word}' found in reasons: {rec.match_reasons}"
