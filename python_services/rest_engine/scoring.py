"""
Rest Engine — Composite Safety Scorer
Combines legality + fatigue + rest margins into a single safety score.
Used by the trade recommendation engine to rank safer trades higher.
"""
from __future__ import annotations
from dataclasses import dataclass

from .rules import RulesProfile, DEFAULT_PROFILE
from .calculator import DutyInput
from .legality import LegalityEngine, LegalityResult
from .fatigue import FatigueEngine, FatigueScore

_legality = LegalityEngine()
_fatigue  = FatigueEngine()


@dataclass
class SafetyReport:
    """Complete safety report for one duty — used in trade ranking."""
    is_legal:        bool
    is_safe:         bool           # legal AND fatigue LOW/MEDIUM
    safety_score:    float          # 0–100
    fatigue_score:   float          # 0–1
    fatigue_level:   str            # LOW / MEDIUM / HIGH
    legality_result: LegalityResult
    fatigue_result:  FatigueScore
    summary:         str            # one-line plain English

    # Breakdown (0–1 each)
    legality_component: float
    fatigue_component:  float
    rest_component:     float
    fdp_component:      float


class SafetyScorer:

    def score(
        self,
        inp: DutyInput,
        rest_before_mins: int = 660,
        tz_delta_hours:   float = 0.0,
        profile: RulesProfile = DEFAULT_PROFILE,
    ) -> SafetyReport:

        leg_result = _legality.validate(inp, profile)
        fat_result = _fatigue.score(inp, rest_before_mins, tz_delta_hours, profile)

        # Component scores (0–1, higher = safer)
        legality_comp = 1.0 if leg_result.is_legal else 0.0
        fatigue_comp  = 1.0 - fat_result.raw

        rest_comp = 0.5   # neutral default
        fdp_comp  = 0.5
        if leg_result.calculation:
            calc = leg_result.calculation
            if calc.rest:
                margin_ratio = calc.rest.margin_mins / max(calc.rest.minimum_mins, 1)
                rest_comp    = min(max(margin_ratio, 0.0), 1.0)
            fdp_margin_ratio = calc.fdp.margin_mins / max(calc.fdp.limit_mins, 1)
            fdp_comp         = min(max(fdp_margin_ratio, 0.0), 1.0)

        # Weighted composite (0–100)
        composite = (
            legality_comp * 35.0 +
            fatigue_comp  * 25.0 +
            rest_comp     * 25.0 +
            fdp_comp      * 15.0
        )
        composite = round(min(max(composite, 0.0), 100.0), 1)

        is_safe = leg_result.is_legal and fat_result.level.value != "HIGH"

        summary = self._summary(leg_result, fat_result, composite)

        return SafetyReport(
            is_legal           = leg_result.is_legal,
            is_safe            = is_safe,
            safety_score       = composite,
            fatigue_score      = fat_result.raw,
            fatigue_level      = fat_result.level.value,
            legality_result    = leg_result,
            fatigue_result     = fat_result,
            summary            = summary,
            legality_component = legality_comp,
            fatigue_component  = fatigue_comp,
            rest_component     = rest_comp,
            fdp_component      = fdp_comp,
        )

    def score_trade_pair(
        self,
        offered:          DutyInput,
        requested:        DutyInput,
        rest_before_mins: int = 660,
        profile:          RulesProfile = DEFAULT_PROFILE,
    ) -> dict:
        """Score both sides of a trade and return a trade-safety summary."""
        offered_report   = self.score(offered,   rest_before_mins, profile=profile)
        requested_report = self.score(requested, rest_before_mins, profile=profile)

        trade_safe = offered_report.is_legal and requested_report.is_legal
        avg_score  = (offered_report.safety_score + requested_report.safety_score) / 2

        return {
            "trade_is_safe":     trade_safe,
            "avg_safety_score":  round(avg_score, 1),
            "offered_report":    offered_report,
            "requested_report":  requested_report,
            "recommendation":    self._trade_recommendation(
                trade_safe, offered_report, requested_report),
        }

    def _summary(
        self,
        leg: LegalityResult,
        fat: FatigueScore,
        score: float,
    ) -> str:
        if not leg.is_legal:
            count = len(leg.violations)
            return (
                f"NOT LEGAL — {count} violation{'s' if count > 1 else ''}. "
                f"{leg.violations[0].description}"
            )
        if fat.level.value == "HIGH":
            return (
                f"Legal but HIGH fatigue risk ({fat.percentage}%). "
                f"{fat.recommendation}"
            )
        if leg.warnings:
            return (
                f"Legal with {len(leg.warnings)} warning(s). "
                f"Safety score: {score:.0f}/100."
            )
        return f"Legal and safe. Safety score: {score:.0f}/100. Fatigue: {fat.level.value}."

    def _trade_recommendation(
        self,
        safe: bool,
        offered: SafetyReport,
        requested: SafetyReport,
    ) -> str:
        if not safe:
            sides = []
            if not offered.is_legal:   sides.append("offered duty")
            if not requested.is_legal: sides.append("requested duty")
            return f"Trade is NOT LEGAL on the {' and '.join(sides)}."
        delta = offered.safety_score - requested.safety_score
        if abs(delta) < 5:
            return "Both sides of the trade are similarly safe."
        better = "offered" if delta > 0 else "requested"
        return (
            f"Trade is legal. The {better} duty has a higher safety score "
            f"({max(offered.safety_score, requested.safety_score):.0f} vs "
            f"{min(offered.safety_score, requested.safety_score):.0f})."
        )
