"""Insight and recommendation models."""
from __future__ import annotations
from dataclasses import dataclass
from enum import Enum
from typing import Optional


class InsightType(str, Enum):
    WARNING  = "WARNING"
    POSITIVE = "POSITIVE"
    INFO     = "INFO"
    TIP      = "TIP"


class InsightCategory(str, Enum):
    FATIGUE    = "FATIGUE"
    INCOME     = "INCOME"
    OPERATIONS = "OPERATIONS"
    RECOVERY   = "RECOVERY"
    LEGALITY   = "LEGALITY"
    TRADE      = "TRADE"


@dataclass
class Insight:
    type:         InsightType
    category:     InsightCategory
    icon:         str
    title_en:     str
    body_en:      str
    title_ar:     str
    body_ar:      str
    priority:     int           # 1 = highest
    metric_value: Optional[str] = None   # e.g. "68%", "3 days"
    action_label: Optional[str] = None


@dataclass
class SmartSearchIndex:
    """Denormalized search index stored in Firestore for fast filtering."""
    line_id:          str
    period:           str
    base:             str
    rank:             str
    tags:             list[str]
    fatigue_level:    str          # "LOW" | "MEDIUM" | "HIGH"
    has_deadhead:     bool
    deadhead_ratio:   float
    is_international: bool
    block_hours:      float
    duty_hours:       float
    estimated_credit: float
    off_days:         int
    open_days:        int
    classification:   str
    destinations:     list[str]


@dataclass
class TradeAnalysis:
    offer_line_id:      str
    request_line_id:    str
    requesting_rank:    str
    is_legal:           bool
    legality_notes:     list[str]
    fatigue_comparison: dict[str, float]    # offer vs request
    income_comparison:  dict[str, float]
    winner:             str                 # "OFFER" | "REQUEST" | "EQUAL"
    recommendation_en:  str
    recommendation_ar:  str
    risk_level:         str                 # "LOW" | "MEDIUM" | "HIGH"
