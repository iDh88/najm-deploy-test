"""Normalized pairing and segment models."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class SegmentType(str, Enum):
    OPERATING  = "OPERATING"
    DEADHEAD   = "DEADHEAD"
    POSITIONING= "POSITIONING"


class PairingClassification(str, Enum):
    STANDARD           = "STANDARD"
    HEAVY_DEADHEAD     = "HEAVY_DEADHEAD"
    LONG_DUTY          = "LONG_DUTY"
    EARLY_SIGNIN       = "EARLY_SIGNIN"
    OVERNIGHT          = "OVERNIGHT"
    INTERNATIONAL      = "INTERNATIONAL"
    HIGH_LEG_COUNT     = "HIGH_LEG_COUNT"
    MINIMUM_REST       = "MINIMUM_REST"
    MULTI_TIMEZONE     = "MULTI_TIMEZONE"


class PatternFlag(str, Enum):
    REPEATED_DESTINATION     = "REPEATED_DESTINATION"
    BACK_TO_BACK_DEADHEAD    = "BACK_TO_BACK_DEADHEAD"
    MINIMUM_REST_ONLY        = "MINIMUM_REST_ONLY"
    MULTI_TIMEZONE           = "MULTI_TIMEZONE"
    WOCL_PENETRATION         = "WOCL_PENETRATION"
    EARLY_SIGNIN             = "EARLY_SIGNIN"
    LATE_RELEASE             = "LATE_RELEASE"
    HIGH_BLOCK_SINGLE_DUTY   = "HIGH_BLOCK_SINGLE_DUTY"


@dataclass
class FlightSegment:
    segment_id:            str
    pairing_id:            str
    sequence:              int
    segment_type:          SegmentType
    flight_number:         str
    origin:                str
    destination:           str
    departure_utc:         datetime
    arrival_utc:           datetime
    departure_local_str:   str           # "1430L"
    arrival_local_str:     str
    block_minutes:         int
    aircraft_type:         Optional[str] = None
    timezone_delta_hours:  float         = 0.0
    origin_tz:             str           = "UTC"
    destination_tz:        str           = "UTC"

    @property
    def is_deadhead(self) -> bool:
        return self.segment_type == SegmentType.DEADHEAD

    @property
    def is_international(self) -> bool:
        # Simplified: real impl checks country pair
        saudi_airports = {"RUH", "JED", "DMM", "MED", "TUU", "GIZ",
                          "AHB", "ELQ", "HOF", "TIF", "YNB"}
        return (self.origin not in saudi_airports or
                self.destination not in saudi_airports)

    @property
    def block_hours(self) -> float:
        return self.block_minutes / 60


@dataclass
class DutyPeriod:
    """One continuous duty period within a pairing (may span midnight)."""
    duty_index:       int
    report_utc:       datetime
    release_utc:      datetime
    segments:         list[FlightSegment] = field(default_factory=list)
    rest_after_mins:  int = 0             # rest window following this duty

    @property
    def duty_minutes(self) -> int:
        return int((self.release_utc - self.report_utc).total_seconds() / 60)

    @property
    def fdp_minutes(self) -> int:
        if not self.segments:
            return 0
        first_dep = self.segments[0].departure_utc
        last_arr  = self.segments[-1].arrival_utc
        return int((last_arr - first_dep).total_seconds() / 60)

    @property
    def block_minutes(self) -> int:
        return sum(s.block_minutes for s in self.segments
                   if not s.is_deadhead)

    @property
    def operating_segments(self) -> list[FlightSegment]:
        return [s for s in self.segments if not s.is_deadhead]

    @property
    def deadhead_segments(self) -> list[FlightSegment]:
        return [s for s in self.segments if s.is_deadhead]


@dataclass
class LegalityMargins:
    fdp_limit_mins:        int
    fdp_actual_mins:       int
    fdp_margin_mins:       int
    rest_minimum_mins:     int
    rest_actual_mins:      int
    rest_margin_mins:      int
    block_limit_mins:      int
    block_actual_mins:     int
    block_margin_mins:     int
    is_fdp_legal:          bool
    is_rest_legal:         bool
    is_block_legal:        bool

    @property
    def is_fully_legal(self) -> bool:
        return self.is_fdp_legal and self.is_rest_legal and self.is_block_legal

    @property
    def tightest_margin_label(self) -> str:
        margins = {
            "FDP":   self.fdp_margin_mins,
            "REST":  self.rest_margin_mins,
            "BLOCK": self.block_margin_mins,
        }
        return min(margins, key=margins.get)


@dataclass
class Pairing:
    id:               str
    line_id:          str
    pairing_number:   str
    dates:            list[datetime]
    duty_periods:     list[DutyPeriod]
    classification:   PairingClassification
    pattern_flags:    list[PatternFlag]
    legality:         LegalityMargins

    @property
    def report_utc(self) -> datetime:
        return self.duty_periods[0].report_utc if self.duty_periods else None

    @property
    def release_utc(self) -> datetime:
        return self.duty_periods[-1].release_utc if self.duty_periods else None

    @property
    def all_segments(self) -> list[FlightSegment]:
        return [s for dp in self.duty_periods for s in dp.segments]

    @property
    def operating_segments(self) -> list[FlightSegment]:
        return [s for s in self.all_segments if not s.is_deadhead]

    @property
    def deadhead_segments(self) -> list[FlightSegment]:
        return [s for s in self.all_segments if s.is_deadhead]

    @property
    def total_block_minutes(self) -> int:
        return sum(dp.block_minutes for dp in self.duty_periods)

    @property
    def total_duty_minutes(self) -> int:
        return sum(dp.duty_minutes for dp in self.duty_periods)

    @property
    def total_fdp_minutes(self) -> int:
        return sum(dp.fdp_minutes for dp in self.duty_periods)

    @property
    def deadhead_ratio(self) -> float:
        total = len(self.all_segments)
        if total == 0:
            return 0.0
        return len(self.deadhead_segments) / total

    @property
    def is_international(self) -> bool:
        return any(s.is_international for s in self.operating_segments)

    @property
    def destinations(self) -> list[str]:
        return [s.destination for s in self.all_segments]

    @property
    def unique_destinations(self) -> set[str]:
        return set(self.destinations)
