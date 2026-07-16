"""
Compatibility Scoring Engine
Calculates the composite trade match score for one candidate.
All factors are operational — route, schedule, legality, fatigue, behavior.
"""
from __future__ import annotations
import logging
from dataclasses import dataclass, field
from typing import Optional

from preference_engine.models import UserPreferenceProfile, TradeRecommendationScore
from route_familiarity_engine.analyzer import RouteFamiliarityAnalyzer

logger = logging.getLogger("cip.compatibility_scoring")
_familiarity = RouteFamiliarityAnalyzer()


@dataclass
class TradeCandidate:
    """One candidate crew member for a trade."""
    prn:              str
    user_id:          str
    rank:             str
    line_id:          str
    route_keys:       list[str]       # all routes in their current line
    block_hours:      float
    duty_hours:       float
    fdp_minutes:      int
    rest_after_mins:  int
    is_legal:         bool
    legality_margin:  float           # 0–1 (higher = more legal headroom)
    fatigue_score:    float           # 0–1
    carry_over_hrs:   float
    open_days:        list[int]       # open day numbers in month
    signin_hours:     list[int]       # typical report hours in this line


@dataclass
class TargetTrip:
    """The trip the user wants to trade."""
    route_key:        str
    block_hours:      float
    duty_hours:       float
    fdp_minutes:      int
    signin_hour:      int
    layover_hours:    float
    is_international: bool
    has_deadhead:     bool
    fatigue_score:    float
    dates:            list[int]       # day numbers in month


class CompatibilityScorer:
    """
    Computes a TradeRecommendationScore for one candidate against one target trip.
    Weights are tuned for aviation operational reality.
    """

    WEIGHTS = {
        "legality":   0.25,
        "fatigue":    0.15,
        "route":      0.20,
        "schedule":   0.15,
        "preference": 0.15,
        "behavioral": 0.08,
        "collab":     0.02,
    }

    def score(
        self,
        candidate:    TradeCandidate,
        target:       TargetTrip,
        profile:      Optional[UserPreferenceProfile],
        collab_boost: float = 0.0,  # from collaborative filter
    ) -> TradeRecommendationScore:

        rec = TradeRecommendationScore(
            trade_id      = f"{candidate.prn}_{target.route_key}",
            candidate_prn = candidate.prn,
        )

        # ── 1. Legality ───────────────────────────────────────────────────────
        rec.legality_score = self._legality_score(candidate)
        if not candidate.is_legal:
            rec.is_legal = False

        # ── 2. Fatigue ────────────────────────────────────────────────────────
        rec.fatigue_score  = self._fatigue_score(candidate, target, profile)
        rec.fatigue_level  = self._fatigue_label(rec.fatigue_score)

        # ── 3. Route similarity ───────────────────────────────────────────────
        familiarity = _familiarity.analyze(
            target_route           = target.route_key,
            candidate_line_routes  = candidate.route_keys,
            candidate_prn          = candidate.prn,
        )
        rec.route_similarity_score = familiarity.familiarity_score
        rec.route_match_label      = familiarity.familiarity_label

        # ── 4. Schedule compatibility ─────────────────────────────────────────
        rec.schedule_compat_score = self._schedule_score(candidate, target)

        # ── 5. Preference match ───────────────────────────────────────────────
        rec.preference_match_score = (
            self._preference_score(profile, target)
            if profile and not profile.is_cold_start
            else 0.5   # neutral when no data
        )

        # ── 6. Behavioral score ───────────────────────────────────────────────
        rec.behavioral_score = (
            self._behavioral_score(profile, target)
            if profile and not profile.is_cold_start
            else 0.5
        )

        # ── 7. Collaborative ──────────────────────────────────────────────────
        rec.collaborative_score = min(collab_boost, 1.0)

        # ── Composite ─────────────────────────────────────────────────────────
        rec.compute_total()
        rec.match_reasons = self._build_reasons(rec, familiarity, target)

        return rec

    # ── Component scorers ─────────────────────────────────────────────────────

    def _legality_score(self, c: TradeCandidate) -> float:
        if not c.is_legal:
            return 0.0
        # Margin: 1.0 = lots of headroom, 0.5 = tight
        return 0.5 + c.legality_margin * 0.5

    def _fatigue_score(
        self,
        c: TradeCandidate,
        t: TargetTrip,
        profile: Optional[UserPreferenceProfile],
    ) -> float:
        """
        Higher score = BETTER for the user.
        Low combined fatigue → high score.
        """
        combined = (c.fatigue_score + t.fatigue_score) / 2.0
        raw = 1.0 - combined

        # If the user historically accepts high-fatigue trades, penalize less
        if profile and profile.fatigue_tolerance.tolerance_level == "high":
            raw = min(raw + 0.10, 1.0)

        return round(raw, 3)

    def _schedule_score(
        self, c: TradeCandidate, t: TargetTrip
    ) -> float:
        """
        Overlap between the candidate's open days and the target trip's dates.
        """
        if not c.open_days or not t.dates:
            return 0.5   # neutral when data missing

        overlap = len(set(c.open_days) & set(t.dates))
        required = len(t.dates)
        day_compat = overlap / required if required > 0 else 0.0

        # Carry-over impact: large carry-over = harder to fit
        carry_penalty = min(c.carry_over_hrs / 10.0, 0.3)

        # FDP compatibility
        fdp_diff = abs(c.fdp_minutes - t.fdp_minutes)
        fdp_compat = max(0.0, 1.0 - fdp_diff / 120)   # penalize >2h difference

        score = (day_compat * 0.5) + (fdp_compat * 0.3) + ((1 - carry_penalty) * 0.2)
        return round(min(score, 1.0), 3)

    def _preference_score(
        self,
        profile: UserPreferenceProfile,
        target:  TargetTrip,
    ) -> float:
        """How well does this target trip match the user's learned preferences?"""
        score = 0.5
        sp = profile.schedule_pattern

        # Sign-in time preference
        if sp.preferred_signin_hour_start <= target.signin_hour <= sp.preferred_signin_hour_end:
            score += 0.15
        elif sp.avoids_early_signin and target.signin_hour < 6:
            score -= 0.20

        # Layover preference
        if target.layover_hours > 0:
            if sp.preferred_layover_min_hours <= target.layover_hours <= sp.preferred_layover_max_hours:
                score += 0.10
            if sp.prefers_long_layovers and target.layover_hours > 24:
                score += 0.10

        # International preference
        if sp.prefers_international and target.is_international:
            score += 0.10
        if sp.avoids_deadhead and target.has_deadhead:
            score -= 0.10

        # Block hours preference
        if sp.preferred_block_min <= target.block_hours <= sp.preferred_block_max:
            score += 0.05

        return round(min(max(score, 0.0), 1.0), 3)

    def _behavioral_score(
        self,
        profile: UserPreferenceProfile,
        target:  TargetTrip,
    ) -> float:
        """
        How often has the user accepted trades with this route?
        Pure behavioral signal from their own history.
        """
        route_entry = profile.route_frequency.get(target.route_key)
        if route_entry:
            # Direct route match — strongest signal
            return min(route_entry.acceptance_rate * 0.8 + route_entry.engagement_score * 0.2, 1.0)

        # Check if any destination in the target is in their top destinations
        target_airports = target.route_key.replace("→", "-").split("-")
        non_base = [a for a in target_airports if a not in ("JED", "RUH", "DMM")]
        dest_scores = []
        for iata in non_base:
            dp = profile.destination_preferences.get(iata)
            if dp:
                dest_scores.append(dp.preference_score)

        if dest_scores:
            return round(sum(dest_scores) / len(dest_scores), 3)

        return 0.3   # neutral — no prior data for this route

    # ── Reason generation ─────────────────────────────────────────────────────

    def _build_reasons(
        self, rec: TradeRecommendationScore,
        familiarity, target: TargetTrip
    ) -> list[str]:
        reasons = []

        if rec.legality_score >= 0.85:
            reasons.append("Strong legality headroom")
        elif rec.legality_score >= 0.60:
            reasons.append("Passes legality check")

        if rec.fatigue_score >= 0.75:
            reasons.append("Low fatigue impact")
        elif rec.fatigue_score >= 0.50:
            reasons.append("Moderate fatigue impact")

        if rec.route_similarity_score >= 0.85:
            reasons.append("Frequent flyer on this route")
        elif rec.route_similarity_score >= 0.50:
            reasons.append("Familiar with similar routes")
        elif rec.route_similarity_score >= 0.30:
            reasons.append("Some regional route overlap")

        if rec.schedule_compat_score >= 0.75:
            reasons.append("Compatible schedule structure")
        elif rec.schedule_compat_score >= 0.50:
            reasons.append("Schedule overlap available")

        if rec.preference_match_score >= 0.70:
            reasons.append("Matches preferred trip pattern")

        if rec.behavioral_score >= 0.70:
            reasons.append("High historical acceptance on similar routes")
        elif rec.behavioral_score >= 0.50:
            reasons.append("Active on similar route types")

        if not reasons:
            reasons.append("Legal and within duty limits")

        return reasons[:4]   # cap at 4 reasons in UI

    def _fatigue_label(self, score: float) -> str:
        if score >= 0.70: return "Low"
        if score >= 0.45: return "Medium"
        return "High"
