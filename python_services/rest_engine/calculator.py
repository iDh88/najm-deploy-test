"""
Rest Engine — Calculator
Core rest window, FDP, carry-over, and briefing calculations.
Pure functions — no side effects, fully testable.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

from .rules import RulesProfile, DEFAULT_PROFILE
from .timezone_utils import (
    duration_minutes, wocl_minutes_in_window,
    penetrates_wocl, is_early_signin, format_duration,
    local_time_label, to_utc, to_local,
)


@dataclass
class DutyInput:
    """
    All inputs needed to calculate rest and FDP for one duty period.
    Times are UTC datetimes. local_tz is the IANA timezone of the base/layover.
    """
    duty_start_utc:      datetime
    duty_end_utc:        datetime          # = release time (with debrief)
    report_local_hour:   int               # local hour of report (for WOCL/early check)
    num_operating_legs:  int
    num_deadhead_legs:   int  = 0
    block_minutes:       int  = 0
    is_international:    bool = False
    is_augmented:        bool = False
    local_tz:            str  = "Asia/Riyadh"
    carry_over_hours:    float = 0.0

    # Optional next duty for consecutive analysis
    next_duty_start_utc: Optional[datetime] = None


@dataclass
class RestWindow:
    """Calculated rest window between two duties."""
    start_utc:         datetime
    end_utc:           datetime
    duration_mins:     int
    minimum_mins:      int
    margin_mins:       int
    is_sufficient:     bool
    is_marginal:       bool       # within warning buffer
    local_start_label: str        # "22:30 AST"
    local_end_label:   str
    duration_label:    str        # "11:30"
    minimum_label:     str
    margin_label:      str


@dataclass
class FDPResult:
    """Calculated FDP analysis for one duty period."""
    actual_mins:         int
    limit_mins:          int
    margin_mins:         int
    is_within_limit:     bool
    is_marginal:         bool
    early_signin:        bool
    wocl_penetration:    bool
    wocl_minutes:        int
    actual_label:        str
    limit_label:         str
    margin_label:        str


@dataclass
class CarryOverResult:
    """Carry-over analysis."""
    carry_over_hours:    float
    max_allowed_hours:   float
    is_within_limit:     bool
    percentage_used:     float
    remaining_hours:     float


@dataclass
class DutyCalculation:
    """Full calculation result for one duty input."""
    input:           DutyInput
    fdp:             FDPResult
    rest:            Optional[RestWindow]    # None if next_duty not provided
    carry_over:      CarryOverResult
    total_duty_mins: int
    total_duty_label:str


class RestCalculator:
    """
    Core calculation engine.
    All methods take a RulesProfile — defaults to CABIN_STANDARD.
    """

    def calculate(
        self,
        inp: DutyInput,
        profile: RulesProfile = DEFAULT_PROFILE,
    ) -> DutyCalculation:
        """Full calculation: FDP + rest + carry-over."""
        fdp       = self._fdp(inp, profile)
        rest      = self._rest(inp, profile) if inp.next_duty_start_utc else None
        carry_ov  = self._carry_over(inp, profile)
        duty_mins = duration_minutes(inp.duty_start_utc, inp.duty_end_utc)

        return DutyCalculation(
            input           = inp,
            fdp             = fdp,
            rest            = rest,
            carry_over      = carry_ov,
            total_duty_mins = duty_mins,
            total_duty_label= format_duration(duty_mins),
        )

    # ── FDP ───────────────────────────────────────────────────────────────────

    def _fdp(self, inp: DutyInput,
             profile: RulesProfile) -> FDPResult:
        actual = duration_minutes(inp.duty_start_utc, inp.duty_end_utc)
        early  = is_early_signin(inp.report_local_hour)
        wocl_mins = wocl_minutes_in_window(
            inp.duty_start_utc, inp.duty_end_utc, inp.local_tz)
        wocl_pen = wocl_mins >= 30

        limit  = profile.fdp_limit_for(
            inp.num_operating_legs,
            inp.report_local_hour,
            wocl_pen,
            is_international=inp.is_international,
            is_augmented=inp.is_augmented,
        )
        margin = limit - actual

        return FDPResult(
            actual_mins      = actual,
            limit_mins       = limit,
            margin_mins      = margin,
            is_within_limit  = margin >= 0,
            is_marginal      = 0 <= margin <= profile.fdp_warning_buffer_mins,
            early_signin     = early,
            wocl_penetration = wocl_pen,
            wocl_minutes     = wocl_mins,
            actual_label     = format_duration(actual),
            limit_label      = format_duration(limit),
            margin_label     = format_duration(margin),
        )

    # ── Rest ──────────────────────────────────────────────────────────────────

    def _rest(self, inp: DutyInput,
              profile: RulesProfile) -> RestWindow:
        rest_start = inp.duty_end_utc
        rest_end   = inp.next_duty_start_utc

        actual_mins = duration_minutes(rest_start, rest_end)
        min_rest    = profile.min_rest_for(inp.is_international, inp.is_augmented)

        # Extended-FDP rest: an extended FDP can only INCREASE the required
        # rest, never reduce it below the category minimum. (Bug fix: the
        # previous assignment replaced min_rest with extended_rest_mins, which
        # under the unified canonical minimums would have LOWERED it.)
        fdp = self._fdp(inp, profile)
        if not fdp.is_within_limit:
            min_rest = max(min_rest, profile.extended_rest_mins)

        margin = actual_mins - min_rest

        return RestWindow(
            start_utc         = rest_start,
            end_utc           = rest_end,
            duration_mins     = actual_mins,
            minimum_mins      = min_rest,
            margin_mins       = margin,
            is_sufficient     = margin >= 0,
            is_marginal       = 0 <= margin <= profile.rest_warning_buffer_mins,
            local_start_label = local_time_label(rest_start, inp.local_tz),
            local_end_label   = local_time_label(rest_end, inp.local_tz),
            duration_label    = format_duration(actual_mins),
            minimum_label     = format_duration(min_rest),
            margin_label      = format_duration(margin),
        )

    # ── Carry-over ────────────────────────────────────────────────────────────

    def _carry_over(self, inp: DutyInput,
                    profile: RulesProfile) -> CarryOverResult:
        used_pct = (inp.carry_over_hours / profile.carry_over_max_hrs
                    if profile.carry_over_max_hrs > 0 else 0.0)
        return CarryOverResult(
            carry_over_hours  = inp.carry_over_hours,
            max_allowed_hours = profile.carry_over_max_hrs,
            is_within_limit   = inp.carry_over_hours <= profile.carry_over_max_hrs,
            percentage_used   = round(used_pct * 100, 1),
            remaining_hours   = max(0.0,
                                    profile.carry_over_max_hrs - inp.carry_over_hours),
        )

    # ── Helpers ───────────────────────────────────────────────────────────────

    def required_rest_minutes(
        self,
        is_international: bool,
        is_augmented: bool = False,
        profile: RulesProfile = DEFAULT_PROFILE,
    ) -> int:
        return profile.min_rest_for(is_international, is_augmented)

    def fdp_limit_minutes(
        self,
        num_legs: int,
        report_hour: int = 8,
        wocl: bool = False,
        profile: RulesProfile = DEFAULT_PROFILE,
    ) -> int:
        return profile.fdp_limit_for(num_legs, report_hour, wocl)
