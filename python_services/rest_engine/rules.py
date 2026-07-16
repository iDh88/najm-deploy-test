"""
Rest Engine — Rules System

P0-1 REMEDIATION: this module NO LONGER carries its own FTL numbers. All rest
minimums, the daily/monthly/annual block caps and the FDP model are derived
from legality/rules_source.py — the single source of truth (canonical GOM
7.5.3 Table F defaults + live admin overrides from the Firestore
`legalityRules` collection). The previous uncited 10h/11h rest minimums, 8h
"augmented" rest, 8:30 daily block and 1000h annual cap contradicted the
project's own cited rule set and produced opposite verdicts to /v1/legality
on identical input (see FORENSIC_RELEASE_AUDIT.md P0-1 and
OWNER_DECISION_REQUEST.md ODR-001/ODR-003).

Crew-type profiles remain as PRESENTATION variants (briefing times, warning
buffers, fatigue thresholds). Their SAFETY thresholds are floored at the
canonical minimums: a profile may be stricter than the canonical rules, never
more permissive.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

from legality.rules_source import (
    get_effective_rules,
    min_rest_minutes as _canonical_min_rest_minutes,
    fdp_limit_minutes as _canonical_fdp_limit_minutes,
    FDP_SECTOR_TABLE_MINUTES,
    FDP_EARLY_SIGNIN_REDUCTION_MINS,
    FDP_WOCL_REDUCTION_MINS,
    FDP_ABSOLUTE_FLOOR_MINS,
    WOCL_START_HOUR,
    WOCL_END_HOUR,
)


class CrewType(str, Enum):
    CABIN_STANDARD  = "cabin_standard"
    CABIN_LONG_HAUL = "cabin_long_haul"
    COCKPIT         = "cockpit"
    AUGMENTED       = "augmented"


@dataclass
class RulesProfile:
    """
    Complete set of operational rules for one crew type.
    All values in minutes unless labeled otherwise.
    """
    name: str
    crew_type: CrewType

    # ── Rest minimums ─────────────────────────────────────────────────────────
    # Defaults are placeholders overwritten by build_profiles(); every profile
    # produced by get_profile() carries the CANONICAL minimums (floored).
    min_rest_domestic_mins:       int = 840   # canonical 14:00 (rules_source)
    min_rest_international_mins:  int = 900   # canonical 15:00 (rules_source)
    min_rest_augmented_mins:      int = 1080  # canonical 18:00 (rules_source)
    extended_rest_mins:           int = 900   # ≥ intl minimum (after extended FDP)

    # ── FDP limits ────────────────────────────────────────────────────────────
    # Base FDP by number of operating legs (minutes)
    fdp_limits_by_legs: dict[int, int] = field(default_factory=lambda: {
        1: 840,   # 14:00
        2: 810,   # 13:30
        3: 780,   # 13:00
        4: 750,   # 12:30
        5: 720,   # 12:00
        6: 690,   # 11:30
    })

    # FDP reductions
    fdp_early_signin_reduction_mins: int = 30   # report before 06:00
    fdp_wocl_reduction_mins:         int = 60   # WOCL penetration > 2h
    fdp_min_floor_mins:              int = 480  # never below 8:00

    # ── Block limits ──────────────────────────────────────────────────────────
    max_daily_block_mins:   int  = 480   # canonical 8:00 (rules_source)
    max_monthly_block_hrs:  int  = 100   # canonical 28-day flight cap
    max_annual_block_hrs:   int  = 900   # canonical annual cap (ODR-001)

    # ── Duty limits ───────────────────────────────────────────────────────────
    max_duty_mins:               int = 840   # 14:00
    max_consecutive_duty_days:   int = 7
    min_weekly_rest_hrs:         int = 36

    # ── Briefing / debriefing ────────────────────────────────────────────────
    pre_flight_briefing_mins:    int = 60
    post_flight_debriefing_mins: int = 30

    # ── WOCL ─────────────────────────────────────────────────────────────────
    wocl_start_hour: int = WOCL_START_HOUR   # 02:00 local (rules_source)
    wocl_end_hour:   int = WOCL_END_HOUR     # 05:59 local (rules_source)

    # ── Fatigue thresholds ────────────────────────────────────────────────────
    fatigue_high_threshold:   float = 0.65
    fatigue_medium_threshold: float = 0.35

    # ── Carry-over ────────────────────────────────────────────────────────────
    carry_over_max_hrs: float = 30.0   # max carry-over block hours allowed

    # ── Marginal warning zone ─────────────────────────────────────────────────
    # Warn when actual rest is within this many minutes of the minimum
    rest_warning_buffer_mins:    int = 30
    fdp_warning_buffer_mins:     int = 30
    block_warning_buffer_mins:   int = 30

    def fdp_limit_for(self, num_legs: int, report_hour: int = 8,
                      wocl_penetration: bool = False,
                      is_international: bool = False,
                      is_augmented: bool = False) -> int:
        """FDP limit in minutes — CONSERVATIVE INTERSECTION (ODR-002).

        min(profile sector table, canonical flat cap + shared sector table),
        then the shared early-sign-in/WOCL reductions and 8:00 floor. A profile
        can therefore only tighten the canonical limit, never loosen it.
        """
        profile_base = self.fdp_limits_by_legs.get(
            min(max(num_legs, 1), 6),
            self.fdp_limits_by_legs[6],
        )
        if report_hour < 6:
            profile_base -= self.fdp_early_signin_reduction_mins
        if wocl_penetration:
            profile_base -= self.fdp_wocl_reduction_mins
        profile_limit = max(profile_base, self.fdp_min_floor_mins)

        canonical_limit = _canonical_fdp_limit_minutes(
            num_sectors=num_legs,
            report_local_hour=report_hour,
            wocl_penetration=wocl_penetration,
            is_international=is_international,
            is_augmented=is_augmented,
        )
        return min(profile_limit, canonical_limit)

    def min_rest_for(self, is_international: bool,
                     is_augmented: bool = False) -> int:
        """Minimum rest in minutes, floored at the canonical (effective) value
        so no profile can ever be more permissive than the single source of
        truth (P0-1)."""
        canonical = _canonical_min_rest_minutes(is_international, is_augmented)
        if is_augmented:
            own = self.min_rest_augmented_mins
        elif is_international:
            own = self.min_rest_international_mins
        else:
            own = self.min_rest_domestic_mins
        return max(own, canonical)


# ── Built-in profiles — built LIVE from the canonical effective rules ────────
# Crew-type variants only carry presentation/operational deltas (briefing
# times, warning buffers, FDP tables that are STRICTER than canonical, fatigue
# thresholds). All rest minimums come from rules_source (floored in
# min_rest_for as belt-and-braces).

def _canonical_kwargs() -> dict:
    """Shared safety thresholds derived from the effective canonical rules."""
    eff = get_effective_rules()
    return dict(
        min_rest_domestic_mins      = eff.minutes("min_rest_domestic_hours"),
        min_rest_international_mins = eff.minutes("min_rest_international_hours"),
        min_rest_augmented_mins     = eff.minutes("min_rest_augmented_hours"),
        extended_rest_mins          = eff.minutes("min_rest_international_hours"),
        max_daily_block_mins        = eff.minutes("max_daily_block_hours"),
        max_monthly_block_hrs       = int(eff.get("max_28day_flight_hours")),
        max_annual_block_hrs        = int(eff.get("max_annual_flight_hours")),
        min_weekly_rest_hrs         = int(eff.get("min_layover_away_from_base_hours")),
    )


def build_profiles() -> dict[str, "RulesProfile"]:
    """Construct all crew-type profiles from the CURRENT effective rules.

    Called per request via get_profile(); rules_source's TTL cache makes this
    cheap, and admin edits to `legalityRules` propagate here within the TTL.
    """
    base = _canonical_kwargs()

    cabin_standard = RulesProfile(
        name="Cabin Crew — Standard",
        crew_type=CrewType.CABIN_STANDARD,
        **base,
    )
    cabin_long_haul = RulesProfile(
        name="Cabin Crew — Long Haul",
        crew_type=CrewType.CABIN_LONG_HAUL,
        **base,
    )
    cockpit = RulesProfile(
        name="Flight Crew — Cockpit",
        crew_type=CrewType.COCKPIT,
        # Cockpit FDP table is stricter than the shared table — kept.
        fdp_limits_by_legs={1: 780, 2: 750, 3: 720, 4: 690, 5: 660, 6: 630},
        pre_flight_briefing_mins=90,
        **base,
    )
    augmented = RulesProfile(
        name="Augmented Crew",
        crew_type=CrewType.AUGMENTED,
        **base,
    )
    return {
        CrewType.CABIN_STANDARD:  cabin_standard,
        CrewType.CABIN_LONG_HAUL: cabin_long_haul,
        CrewType.COCKPIT:         cockpit,
        CrewType.AUGMENTED:       augmented,
    }


def get_profile(crew_type: str) -> RulesProfile:
    """Rules profile for a crew type, built from the LIVE effective rules.
    Falls back to the cabin-standard profile for unknown types."""
    profiles = build_profiles()
    return profiles.get(crew_type, profiles[CrewType.CABIN_STANDARD])


# Backwards-compatible module-level singletons (tests / direct imports).
# NOTE: these are snapshots taken at import time; request paths use
# get_profile() and therefore always see live admin overrides.
_snapshot = build_profiles()
CABIN_STANDARD_PROFILE  = _snapshot[CrewType.CABIN_STANDARD]
CABIN_LONG_HAUL_PROFILE = _snapshot[CrewType.CABIN_LONG_HAUL]
COCKPIT_PROFILE         = _snapshot[CrewType.COCKPIT]
AUGMENTED_PROFILE       = _snapshot[CrewType.AUGMENTED]
DEFAULT_PROFILE         = CABIN_STANDARD_PROFILE
ALL_PROFILES: dict[str, RulesProfile] = dict(_snapshot)
