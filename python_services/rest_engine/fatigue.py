"""
Rest Engine — Fatigue Scoring
FRMS-based fatigue model integrated with the legality engine.
Provides fatigue scores, predictions, and cumulative analysis.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum

from .rules import RulesProfile, DEFAULT_PROFILE
from .calculator import DutyInput
from .timezone_utils import (
    duration_minutes, wocl_minutes_in_window,
    is_early_signin, format_duration,
)


class FatigueLevel(str, Enum):
    LOW    = "LOW"
    MEDIUM = "MEDIUM"
    HIGH   = "HIGH"


@dataclass
class FatigueFactor:
    name:        str
    score:       float    # 0–1 contribution
    weight:      float
    description: str

    @property
    def weighted(self) -> float:
        return self.score * self.weight


@dataclass
class FatigueScore:
    raw:            float          # 0–1
    level:          FatigueLevel
    percentage:     int
    factors:        list[FatigueFactor]
    wocl_minutes:   int
    early_signin:   bool
    recommendation: str            # plain English advice

    @property
    def level_emoji(self) -> str:
        return {"LOW": "🟢", "MEDIUM": "🟡", "HIGH": "🔴"}[self.level.value]


# Factor weights (must sum to 1.0)
WEIGHTS = {
    "wocl":        0.25,
    "early_signin":0.20,
    "duty_length": 0.18,
    "leg_count":   0.12,
    "rest_quality":0.12,
    "tz_shift":    0.08,
    "deadheads":   0.05,
}


class FatigueEngine:

    def score(
        self,
        inp: DutyInput,
        rest_before_mins: int = 660,
        tz_delta_hours: float = 0.0,
        profile: RulesProfile = DEFAULT_PROFILE,
    ) -> FatigueScore:
        factors: list[FatigueFactor] = []

        # 1. WOCL penetration
        wocl = wocl_minutes_in_window(
            inp.duty_start_utc, inp.duty_end_utc, inp.local_tz)
        wocl_score = min(wocl / 240.0, 1.0)  # normalize to 4h max
        factors.append(FatigueFactor(
            name="WOCL Operations",
            score=wocl_score,
            weight=WEIGHTS["wocl"],
            description=f"{wocl}min operating within 02:00–05:59 local",
        ))

        # 2. Early sign-in
        early = is_early_signin(inp.report_local_hour)
        early_scores = {5: 0.2, 4: 0.5, 3: 0.7, 2: 0.9, 1: 1.0, 0: 1.0}
        early_score  = early_scores.get(inp.report_local_hour, 0.0) if early else 0.0
        factors.append(FatigueFactor(
            name="Early Sign-In",
            score=early_score,
            weight=WEIGHTS["early_signin"],
            description=(
                f"Report at {inp.report_local_hour:02d}:00 local"
                if early else "Standard report time"
            ),
        ))

        # 3. Duty length
        duty_mins  = duration_minutes(inp.duty_start_utc, inp.duty_end_utc)
        duty_score = min(duty_mins / (profile.max_duty_mins or 840), 1.0)
        factors.append(FatigueFactor(
            name="Duty Length",
            score=duty_score,
            weight=WEIGHTS["duty_length"],
            description=f"{format_duration(duty_mins)} duty",
        ))

        # 4. Leg count
        leg_score = min(inp.num_operating_legs / 6.0, 1.0)
        factors.append(FatigueFactor(
            name="Operating Legs",
            score=leg_score,
            weight=WEIGHTS["leg_count"],
            description=f"{inp.num_operating_legs} operating legs",
        ))

        # 5. Rest quality before this duty
        rest_score, rest_desc = self._rest_quality(rest_before_mins)
        factors.append(FatigueFactor(
            name="Rest Quality",
            score=rest_score,
            weight=WEIGHTS["rest_quality"],
            description=rest_desc,
        ))

        # 6. Timezone shift
        tz_score = min(abs(tz_delta_hours) / 12.0, 1.0)
        factors.append(FatigueFactor(
            name="Timezone Transitions",
            score=tz_score,
            weight=WEIGHTS["tz_shift"],
            description=f"{tz_delta_hours:+.1f}h timezone shift",
        ))

        # 7. Deadhead ratio
        total_legs = inp.num_operating_legs + inp.num_deadhead_legs
        dh_ratio   = (inp.num_deadhead_legs / total_legs
                      if total_legs > 0 else 0.0)
        factors.append(FatigueFactor(
            name="Deadhead Ratio",
            score=dh_ratio,
            weight=WEIGHTS["deadheads"],
            description=f"{inp.num_deadhead_legs} deadhead legs",
        ))

        raw   = sum(f.weighted for f in factors)
        raw   = round(min(raw, 1.0), 3)
        level = self._classify(raw, profile)
        pct   = int(raw * 100)

        return FatigueScore(
            raw           = raw,
            level         = level,
            percentage    = pct,
            factors       = factors,
            wocl_minutes  = wocl,
            early_signin  = early,
            recommendation= self._recommendation(level, factors),
        )

    def _rest_quality(self, rest_mins: int) -> tuple[float, str]:
        rest_h = rest_mins / 60
        if rest_h >= 12:  return 0.0, f"Excellent rest: {rest_h:.1f}h"
        if rest_h >= 10:  return 0.2, f"Good rest: {rest_h:.1f}h"
        if rest_h >= 8:   return 0.5, f"Adequate rest: {rest_h:.1f}h"
        return 0.9, f"Poor rest: {rest_h:.1f}h (below recommended)"

    def _classify(self, score: float, profile: RulesProfile) -> FatigueLevel:
        if score >= profile.fatigue_high_threshold:   return FatigueLevel.HIGH
        if score >= profile.fatigue_medium_threshold: return FatigueLevel.MEDIUM
        return FatigueLevel.LOW

    def _recommendation(
        self, level: FatigueLevel, factors: list[FatigueFactor]
    ) -> str:
        if level == FatigueLevel.LOW:
            return "Fatigue impact is low. Standard precautions apply."

        dominant = max(factors, key=lambda f: f.weighted)

        if level == FatigueLevel.HIGH:
            return (
                f"High fatigue risk. Dominant factor: {dominant.name}. "
                "Ensure maximum pre-duty rest and apply fatigue mitigation strategies."
            )

        return (
            f"Moderate fatigue risk. Main contributor: {dominant.name}. "
            "Monitor alertness during duty."
        )
