"""Fatigue scoring models — FRMS-based."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from typing import Optional


class FatigueLevel(str, Enum):
    LOW    = "LOW"
    MEDIUM = "MEDIUM"
    HIGH   = "HIGH"


class RecoveryQuality(str, Enum):
    EXCELLENT = "EXCELLENT"   # ≥12h
    GOOD      = "GOOD"        # 10–12h
    ADEQUATE  = "ADEQUATE"    # 8–10h
    POOR      = "POOR"        # <8h


@dataclass
class FatigueFactor:
    name:        str
    score:       float          # 0.0–1.0 contribution
    weight:      float
    description: str

    @property
    def weighted_score(self) -> float:
        return self.score * self.weight


@dataclass
class FatigueScore:
    raw:           float                    # 0.0–1.0
    level:         FatigueLevel
    factors:       list[FatigueFactor]      = field(default_factory=list)
    wocl_minutes:  int                      = 0
    early_signin:  bool                     = False
    night_ops:     bool                     = False

    @property
    def percentage(self) -> int:
        return int(self.raw * 100)

    @property
    def dominant_factor(self) -> Optional[FatigueFactor]:
        if not self.factors:
            return None
        return max(self.factors, key=lambda f: f.weighted_score)


@dataclass
class RecoveryWindow:
    start_day:      date
    end_day:        date
    duration_hours: float
    quality:        RecoveryQuality
    description:    str

    @property
    def duration_days(self) -> int:
        return (self.end_day - self.start_day).days + 1


@dataclass
class FatiguePoint:
    """One point on the monthly fatigue timeline chart."""
    day:           date
    score:         float
    level:         FatigueLevel
    label:         str           # pairing ID or "REST" or "OFF"
    cumulative:    float         # accumulated fatigue to this point
    delta:         float         # change from previous day (+/-)


@dataclass
class LineFatigueProfile:
    pairing_scores:      list[FatigueScore]
    average_fatigue:     float
    peak_fatigue:        float
    high_fatigue_days:   int
    medium_fatigue_days: int
    low_fatigue_days:    int
    recovery_windows:    list[RecoveryWindow]
    timeline:            list[FatiguePoint]
    overall_level:       FatigueLevel
    wocl_total_minutes:  int
    early_signin_count:  int
    night_ops_count:     int

    @property
    def fatigue_percentage(self) -> int:
        return int(self.average_fatigue * 100)

    @property
    def best_recovery_window(self) -> Optional[RecoveryWindow]:
        good = [w for w in self.recovery_windows
                if w.quality in (RecoveryQuality.EXCELLENT, RecoveryQuality.GOOD)]
        return max(good, key=lambda w: w.duration_hours) if good else None
