"""
Rest Engine — Legality Validator
Detects all violations, warnings, and safety issues for a duty period.
Returns structured LegalityResult with clear violation messages.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

from .rules import RulesProfile, DEFAULT_PROFILE
from .calculator import RestCalculator, DutyInput, DutyCalculation
from .timezone_utils import format_duration


class ViolationSeverity(str, Enum):
    VIOLATION = "VIOLATION"   # hard legal breach
    WARNING   = "WARNING"     # marginal / close to limit
    ADVISORY  = "ADVISORY"    # informational safety note


@dataclass
class Violation:
    severity:    ViolationSeverity
    rule:        str            # rule reference e.g. "GACA 121 — FDP Limit"
    description: str            # plain English
    actual:      str            # e.g. "14:35"
    limit:       str            # e.g. "14:00"
    excess:      Optional[str]  # e.g. "+0:35" if over limit


@dataclass
class LegalityResult:
    """Complete legality analysis for one duty period."""
    is_legal:       bool
    safety_score:   float          # 0–100 (100 = fully legal, ample margins)
    violations:     list[Violation] = field(default_factory=list)
    warnings:       list[Violation] = field(default_factory=list)
    advisories:     list[Violation] = field(default_factory=list)
    calculation:    Optional[DutyCalculation] = None

    @property
    def status_label(self) -> str:
        if not self.is_legal:        return "NOT LEGAL"
        if self.warnings:            return "LEGAL — MARGINAL"
        return "LEGAL"

    @property
    def status_emoji(self) -> str:
        if not self.is_legal:        return "❌"
        if self.warnings:            return "⚠️"
        return "✅"

    @property
    def has_issues(self) -> bool:
        return bool(self.violations or self.warnings)

    @property
    def all_issues(self) -> list[Violation]:
        return self.violations + self.warnings + self.advisories


class LegalityEngine:
    """
    Full legality validator.
    Checks FDP, rest, block, carry-over, and consecutive duties.
    """

    def __init__(self):
        self._calc = RestCalculator()

    def validate(
        self,
        inp: DutyInput,
        profile: RulesProfile = DEFAULT_PROFILE,
    ) -> LegalityResult:
        calc       = self._calc.calculate(inp, profile)
        violations: list[Violation] = []
        warnings:   list[Violation] = []
        advisories: list[Violation] = []

        # ── FDP check ────────────────────────────────────────────────────────
        fdp = calc.fdp
        if not fdp.is_within_limit:
            excess = format_duration(abs(fdp.margin_mins))
            violations.append(Violation(
                severity    = ViolationSeverity.VIOLATION,
                rule        = "GACA 121 — FDP Limit",
                description = (
                    f"Flight Duty Period of {fdp.actual_label} exceeds the "
                    f"limit of {fdp.limit_label} for {inp.num_operating_legs} "
                    f"operating legs."
                ),
                actual  = fdp.actual_label,
                limit   = fdp.limit_label,
                excess  = f"+{excess}",
            ))
        elif fdp.is_marginal:
            warnings.append(Violation(
                severity    = ViolationSeverity.WARNING,
                rule        = "GACA 121 — FDP Marginal",
                description = (
                    f"FDP of {fdp.actual_label} is within "
                    f"{format_duration(profile.fdp_warning_buffer_mins)} "
                    f"of the limit ({fdp.limit_label})."
                ),
                actual  = fdp.actual_label,
                limit   = fdp.limit_label,
                excess  = None,
            ))

        # ── Rest check ────────────────────────────────────────────────────────
        if calc.rest is not None:
            rest = calc.rest
            if not rest.is_sufficient:
                short = format_duration(abs(rest.margin_mins))
                violations.append(Violation(
                    severity    = ViolationSeverity.VIOLATION,
                    rule        = "GACA 121 — Minimum Rest",
                    description = (
                        f"Rest period of {rest.duration_label} is "
                        f"{short} below the minimum of {rest.minimum_label}."
                    ),
                    actual  = rest.duration_label,
                    limit   = rest.minimum_label,
                    excess  = f"-{short}",
                ))
            elif rest.is_marginal:
                warnings.append(Violation(
                    severity    = ViolationSeverity.WARNING,
                    rule        = "GACA 121 — Rest Marginal",
                    description = (
                        f"Rest of {rest.duration_label} is within "
                        f"{format_duration(profile.rest_warning_buffer_mins)} "
                        f"of the minimum ({rest.minimum_label})."
                    ),
                    actual  = rest.duration_label,
                    limit   = rest.minimum_label,
                    excess  = None,
                ))

        # ── Block check ───────────────────────────────────────────────────────
        block_margin = profile.max_daily_block_mins - inp.block_minutes
        if inp.block_minutes > 0:
            if block_margin < 0:
                violations.append(Violation(
                    severity    = ViolationSeverity.VIOLATION,
                    rule        = "GACA 121 — Daily Block Limit",
                    description = (
                        f"Daily block of {format_duration(inp.block_minutes)} "
                        f"exceeds limit of "
                        f"{format_duration(profile.max_daily_block_mins)}."
                    ),
                    actual  = format_duration(inp.block_minutes),
                    limit   = format_duration(profile.max_daily_block_mins),
                    excess  = f"+{format_duration(abs(block_margin))}",
                ))
            elif block_margin <= profile.block_warning_buffer_mins:
                warnings.append(Violation(
                    severity    = ViolationSeverity.WARNING,
                    rule        = "GACA 121 — Block Marginal",
                    description = (
                        f"Block of {format_duration(inp.block_minutes)} is "
                        f"within {format_duration(profile.block_warning_buffer_mins)} "
                        f"of the daily limit."
                    ),
                    actual  = format_duration(inp.block_minutes),
                    limit   = format_duration(profile.max_daily_block_mins),
                    excess  = None,
                ))

        # ── Carry-over ────────────────────────────────────────────────────────
        co = calc.carry_over
        if not co.is_within_limit:
            violations.append(Violation(
                severity    = ViolationSeverity.VIOLATION,
                rule        = "Carry-Over Limit",
                description = (
                    f"Carry-over of {co.carry_over_hours:.1f}h exceeds "
                    f"the maximum of {co.max_allowed_hours:.0f}h."
                ),
                actual  = f"{co.carry_over_hours:.1f}h",
                limit   = f"{co.max_allowed_hours:.0f}h",
                excess  = f"+{co.carry_over_hours - co.max_allowed_hours:.1f}h",
            ))
        elif co.percentage_used > 80:
            advisories.append(Violation(
                severity    = ViolationSeverity.ADVISORY,
                rule        = "Carry-Over Advisory",
                description = (
                    f"Carry-over at {co.percentage_used:.0f}% of limit "
                    f"({co.carry_over_hours:.1f}h / {co.max_allowed_hours:.0f}h). "
                    f"{co.remaining_hours:.1f}h remaining."
                ),
                actual  = f"{co.carry_over_hours:.1f}h",
                limit   = f"{co.max_allowed_hours:.0f}h",
                excess  = None,
            ))

        # ── WOCL advisory ─────────────────────────────────────────────────────
        if fdp.wocl_minutes >= 60:
            advisories.append(Violation(
                severity    = ViolationSeverity.ADVISORY,
                rule        = "WOCL Operations",
                description = (
                    f"{fdp.wocl_minutes} minutes of operations fall within "
                    f"the Window of Circadian Low (02:00–05:59). "
                    f"Alertness may be significantly reduced."
                ),
                actual  = f"{fdp.wocl_minutes}min",
                limit   = "0min (advisory)",
                excess  = None,
            ))

        # ── Early sign-in advisory ────────────────────────────────────────────
        if fdp.early_signin:
            advisories.append(Violation(
                severity    = ViolationSeverity.ADVISORY,
                rule        = "Early Sign-In",
                description = (
                    f"Report time before 06:00 local reduces FDP limit "
                    f"by {format_duration(profile.fdp_early_signin_reduction_mins)}. "
                    f"FDP limit was already adjusted in calculation."
                ),
                actual  = f"{inp.report_local_hour:02d}:xx local",
                limit   = "06:00+ preferred",
                excess  = None,
            ))

        is_legal     = len(violations) == 0
        safety_score = self._compute_safety_score(calc, violations, warnings,
                                                   inp, profile)

        return LegalityResult(
            is_legal      = is_legal,
            safety_score  = safety_score,
            violations    = violations,
            warnings      = warnings,
            advisories    = advisories,
            calculation   = calc,
        )

    # ── Trade legality check ──────────────────────────────────────────────────

    def validate_trade(
        self,
        offered_duty:    DutyInput,
        requested_duty:  DutyInput,
        profile:         RulesProfile = DEFAULT_PROFILE,
    ) -> dict:
        """
        Check legality of both sides of a trade.
        Returns a summary with a trade_is_safe flag.
        """
        offered_result   = self.validate(offered_duty,   profile)
        requested_result = self.validate(requested_duty, profile)

        return {
            "trade_is_safe":     offered_result.is_legal and requested_result.is_legal,
            "offered_result":    offered_result,
            "requested_result":  requested_result,
            "offered_score":     offered_result.safety_score,
            "requested_score":   requested_result.safety_score,
        }

    # ── Safety score ──────────────────────────────────────────────────────────

    def _compute_safety_score(
        self,
        calc:       DutyCalculation,
        violations: list[Violation],
        warnings:   list[Violation],
        inp:        DutyInput,
        profile:    RulesProfile,
    ) -> float:
        if violations:
            # Each violation deducts 25 points from 100
            score = max(0.0, 100.0 - len(violations) * 25.0)
            return round(score, 1)

        score = 100.0

        # Deduct for marginal FDP
        fdp = calc.fdp
        if fdp.margin_mins >= 0:
            fdp_ratio  = fdp.margin_mins / max(fdp.limit_mins, 1)
            score     -= max(0.0, (0.15 - fdp_ratio) * 100)

        # Deduct for marginal rest
        if calc.rest:
            rest = calc.rest
            if rest.margin_mins >= 0:
                rest_ratio = rest.margin_mins / max(rest.minimum_mins, 1)
                score     -= max(0.0, (0.20 - rest_ratio) * 80)

        # Deduct for each warning
        score -= len(warnings) * 5.0

        # Deduct for WOCL
        score -= min(calc.fdp.wocl_minutes / 60 * 3.0, 10.0)

        # Deduct for carry-over usage
        score -= calc.carry_over.percentage_used * 0.05

        return round(max(0.0, min(score, 100.0)), 1)
