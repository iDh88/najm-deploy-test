"""Monthly analytics and line classification models."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date
from enum import Enum
from typing import Optional
from .fatigue_models import LineFatigueProfile, FatigueLevel


class LineTag(str, Enum):
    HIGH_FATIGUE          = "HIGH_FATIGUE"
    RECOVERY_FRIENDLY     = "RECOVERY_FRIENDLY"
    HEAVY_DEADHEAD        = "HEAVY_DEADHEAD"
    HIGH_INCOME           = "HIGH_INCOME"
    INTERNATIONAL_HEAVY   = "INTERNATIONAL_HEAVY"
    EARLY_SIGNIN_HEAVY    = "EARLY_SIGNIN_HEAVY"
    LONG_DUTY             = "LONG_DUTY"
    NIGHT_HEAVY           = "NIGHT_HEAVY"
    SHORT_HAUL_INTENSIVE  = "SHORT_HAUL_INTENSIVE"
    OPTIMAL_BALANCE       = "OPTIMAL_BALANCE"
    STANDARD              = "STANDARD"


@dataclass
class LineClassification:
    primary:   LineTag
    all_tags:  list[LineTag]
    scores:    dict[str, float]         # tag -> confidence 0.0–1.0
    label:     str                      # human-readable label
    color:     str                      # hex color for UI
    icon:      str                      # emoji


@dataclass
class WeekAnalytics:
    week_number:   int
    start_date:    date
    end_date:      date
    block_hours:   float
    duty_hours:    float
    pairing_count: int
    off_days:      int
    fatigue_level: FatigueLevel
    destinations:  list[str]


@dataclass
class DestinationFrequency:
    iata:       str
    city:       str
    country:    str
    count:      int
    total_hrs:  float
    is_intl:    bool


@dataclass
class MonthlyAnalytics:
    line_id:                str
    period:                 str

    # Time blocks
    total_block_hours:      float
    total_duty_hours:       float
    total_deadhead_hours:   float
    total_rest_hours:       float
    carry_over_hours:       float

    # Counts
    total_pairings:         int
    total_operating_legs:   int
    total_deadhead_legs:    int
    off_days:               int
    open_days:              int
    consecutive_duty_max:   int

    # Financial estimate (Saudi Airlines formula)
    estimated_credit:       float
    estimated_per_diem_usd: float
    deadhead_ratio:         float

    # Destinations
    unique_destinations:    list[str]
    international_count:    int
    domestic_count:         int
    destination_freq:       list[DestinationFrequency]

    # Fatigue
    fatigue_profile:        LineFatigueProfile

    # Weekly breakdown
    weekly_breakdown:       list[WeekAnalytics]

    # Intelligence
    classification:         LineClassification
    vs_fleet_avg:           dict[str, float]    # metric -> % delta vs fleet


@dataclass
class LineComparison:
    line_a_id:          str
    line_b_id:          str
    line_a_label:       str
    line_b_label:       str

    # Deltas (A - B; positive means A is higher)
    block_hours_delta:  float
    duty_hours_delta:   float
    fatigue_delta:      float
    income_delta:       float
    deadhead_delta:     int
    recovery_delta:     float
    legality_delta:     float

    # Radar chart axes scores (0.0–1.0, higher = better)
    line_a_radar:       dict[str, float]
    line_b_radar:       dict[str, float]

    winner:             str          # "A" | "B" | "EQUAL"
    winner_reason:      str
    recommendation:     str          # Arabic AI text
    recommendation_en:  str


@dataclass
class CalendarDay:
    """One day in the monthly schedule view."""
    date:          date
    pairing_id:    Optional[str]
    pairing_label: Optional[str]
    fatigue_score: float
    fatigue_level: FatigueLevel
    is_off:        bool
    is_open:       bool
    is_rest:       bool
    duty_hours:    float
    block_hours:   float
    destinations:  list[str]
