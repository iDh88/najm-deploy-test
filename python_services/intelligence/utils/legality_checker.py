"""
Legality checker for the PDF-Intelligence pipeline.

P0-1 REMEDIATION: this module previously carried its own uncited FTL numbers
(10h/11h rest, 8:30 block, 1000h annual) that contradicted /v1/legality. All
limits are now delegated to legality/rules_source.py — the single source of
truth (canonical GOM 7.5.3 Table F defaults + live admin overrides). The
FDPLimits / RestLimits / BlockLimits class facades are retained so the
pipeline's call sites are unchanged.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from .time_utils import format_duration

from legality.rules_source import (
    get_effective_rules,
    min_rest_minutes as _canonical_min_rest_minutes,
    fdp_limit_minutes as _canonical_fdp_limit_minutes,
)


# ── Limits — thin facades over legality.rules_source ─────────────────────────

class FDPLimits:
    """Flight Duty Period limits (delegates to the canonical source)."""

    @classmethod
    def get_limit(cls, num_legs: int, report_hour: int,
                  wocl_penetration: bool = False,
                  is_international: bool = False,
                  is_augmented: bool = False) -> int:
        return _canonical_fdp_limit_minutes(
            num_sectors=num_legs,
            report_local_hour=report_hour,
            wocl_penetration=wocl_penetration,
            is_international=is_international,
            is_augmented=is_augmented,
        )


class RestLimits:
    """Rest minimums (delegates to the canonical source)."""

    @classmethod
    def get_minimum(cls, is_international: bool,
                    is_split_duty: bool = False) -> int:
        # NOTE: "split duty" reduced rest existed only in this module's old
        # uncited table; the canonical GOM set has no split-duty discount, so
        # the flag is accepted for call-site compatibility but the CANONICAL
        # minimum applies (fail-safe). See OWNER_DECISION_REQUEST.md ODR-003.
        return _canonical_min_rest_minutes(is_international, is_augmented=False)


class _BlockLimitsMeta(type):
    """Metaclass exposing the legacy constant names as LIVE properties so
    existing call sites (`BlockLimits.MAX_DAILY_BLOCK_MINS`) always see the
    current effective canonical values (admin overrides included)."""

    @property
    def MAX_DAILY_BLOCK_MINS(cls) -> int:      # noqa: N802 — legacy name
        return get_effective_rules().minutes("max_daily_block_hours")

    @property
    def MAX_MONTHLY_BLOCK_HRS(cls) -> int:     # noqa: N802
        return int(get_effective_rules().get("max_28day_flight_hours"))

    @property
    def MAX_ANNUAL_BLOCK_HRS(cls) -> int:      # noqa: N802
        return int(get_effective_rules().get("max_annual_flight_hours"))

    @property
    def MIN_WEEKLY_REST_HRS(cls) -> int:       # noqa: N802
        return int(get_effective_rules().get("min_layover_away_from_base_hours"))


class BlockLimits(metaclass=_BlockLimitsMeta):
    """Block caps — live facade over legality.rules_source."""
    MAX_CONSECUTIVE_DUTY_DAYS: int = 7


# ── Legality Checker ─────────────────────────────────────────────────────────

@dataclass
class LegalityViolation:
    rule:        str
    actual_str:  str
    limit_str:   str
    severity:    str   # "VIOLATION" | "WARNING" | "MARGINAL"
    description: str


@dataclass
class PairingLegalityResult:
    is_legal:         bool
    violations:       list[LegalityViolation] = field(default_factory=list)
    warnings:         list[LegalityViolation] = field(default_factory=list)
    fdp_limit_mins:   int = 0
    fdp_actual_mins:  int = 0
    rest_min_mins:    int = 0
    rest_actual_mins: int = 0
    block_limit_mins: int = 0  # populated from BlockLimits at check time
    block_actual_mins:int = 0

    @property
    def fdp_margin_mins(self) -> int:
        return self.fdp_limit_mins - self.fdp_actual_mins

    @property
    def rest_margin_mins(self) -> int:
        return self.rest_actual_mins - self.rest_min_mins

    @property
    def block_margin_mins(self) -> int:
        return self.block_limit_mins - self.block_actual_mins

    @property
    def tightest_margin_label(self) -> str:
        margins = {
            "FDP":   self.fdp_margin_mins,
            "REST":  self.rest_margin_mins,
            "BLOCK": self.block_margin_mins,
        }
        return min(margins, key=lambda k: margins[k])


class LegalityChecker:

    def check_duty_period(
        self,
        fdp_minutes: int,
        block_minutes: int,
        rest_after_minutes: int,
        num_legs: int,
        report_hour: int,
        is_international: bool,
        wocl_penetration: bool = False,
    ) -> PairingLegalityResult:

        result = PairingLegalityResult(
            is_legal=True,
            fdp_actual_mins=fdp_minutes,
            block_actual_mins=block_minutes,
            rest_actual_mins=rest_after_minutes,
        )

        # FDP check
        fdp_limit = FDPLimits.get_limit(num_legs, report_hour, wocl_penetration)
        result.fdp_limit_mins = fdp_limit

        if fdp_minutes > fdp_limit:
            result.is_legal = False
            result.violations.append(LegalityViolation(
                rule="GACAR 121 — FDP Limit",
                actual_str=format_duration(fdp_minutes),
                limit_str=format_duration(fdp_limit),
                severity="VIOLATION",
                description=f"FDP exceeds limit by {format_duration(fdp_minutes - fdp_limit)}",
            ))
        elif fdp_minutes > fdp_limit - 30:
            result.warnings.append(LegalityViolation(
                rule="GACAR 121 — FDP Marginal",
                actual_str=format_duration(fdp_minutes),
                limit_str=format_duration(fdp_limit),
                severity="MARGINAL",
                description=f"FDP within 30 min of limit",
            ))

        # Rest check
        rest_min = RestLimits.get_minimum(is_international)
        result.rest_min_mins = rest_min

        if rest_after_minutes > 0 and rest_after_minutes < rest_min:
            result.is_legal = False
            result.violations.append(LegalityViolation(
                rule="GACAR 121 — Minimum Rest",
                actual_str=format_duration(rest_after_minutes),
                limit_str=format_duration(rest_min),
                severity="VIOLATION",
                description=f"Rest below minimum by {format_duration(rest_min - rest_after_minutes)}",
            ))
        elif rest_after_minutes > 0 and rest_after_minutes < rest_min + 30:
            result.warnings.append(LegalityViolation(
                rule="GACAR 121 — Rest Marginal",
                actual_str=format_duration(rest_after_minutes),
                limit_str=format_duration(rest_min),
                severity="MARGINAL",
                description="Rest within 30 min of minimum",
            ))

        # Block check
        daily_block_limit = BlockLimits.MAX_DAILY_BLOCK_MINS
        result.block_limit_mins = daily_block_limit
        if block_minutes > daily_block_limit:
            result.is_legal = False
            result.violations.append(LegalityViolation(
                rule="GACAR 121 — Daily Block Limit",
                actual_str=format_duration(block_minutes),
                limit_str=format_duration(daily_block_limit),
                severity="VIOLATION",
                description=f"Daily block hours exceed {format_duration(daily_block_limit)}",
            ))

        return result
