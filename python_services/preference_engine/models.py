"""
Preference Engine — Data Models
All models for behavioral preference learning and trade recommendation.
Built entirely on user behavior — no demographic inference.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


# ── Enums ─────────────────────────────────────────────────────────────────────

class TradeOutcome(str, Enum):
    ACCEPTED  = "accepted"
    REJECTED  = "rejected"
    EXPIRED   = "expired"
    CANCELLED = "cancelled"
    VIEWED    = "viewed"        # saw it but didn't act


class PreferenceSignalStrength(str, Enum):
    STRONG  = "strong"    # repeated consistent behavior
    MEDIUM  = "medium"    # some evidence
    WEAK    = "weak"      # single data point


# ── Firestore-backed models ────────────────────────────────────────────────────

class RouteFrequencyEntry(BaseModel):
    """How often a user has engaged with a specific route."""
    route:            str           # "JED-DEL" or "JED-DEL-JED"
    accept_count:     int = 0
    reject_count:     int = 0
    view_count:       int = 0
    last_accepted_at: Optional[datetime] = None
    last_seen_at:     Optional[datetime] = None

    @property
    def acceptance_rate(self) -> float:
        total = self.accept_count + self.reject_count
        return self.accept_count / total if total > 0 else 0.0

    @property
    def engagement_score(self) -> float:
        """
        Composite engagement: accepts weighted 3x, rejects 0x, views 0.5x.
        Normalized 0–1 against max plausible value of 30.
        """
        raw = (self.accept_count * 3.0) + (self.view_count * 0.5)
        return min(raw / 30.0, 1.0)


class DestinationPreference(BaseModel):
    """Learned preference for a specific destination airport."""
    iata:             str
    accept_count:     int = 0
    reject_count:     int = 0
    save_count:       int = 0      # saved layover recs for this city
    layover_hours_avg: float = 0.0
    last_visited_at:  Optional[datetime] = None

    @property
    def preference_score(self) -> float:
        signal = (self.accept_count * 3.0) + (self.save_count * 1.5)
        penalty = self.reject_count * 1.0
        return max(0.0, min((signal - penalty) / 20.0, 1.0))


class SchedulePatternPreference(BaseModel):
    """Learned preference for schedule/duty patterns."""
    # Timing
    preferred_signin_hour_start: int = 6   # preferred earliest report hour
    preferred_signin_hour_end:   int = 14  # preferred latest report hour
    preferred_layover_min_hours: float = 14.0
    preferred_layover_max_hours: float = 72.0

    # Duration preferences
    preferred_block_min: float = 0.0
    preferred_block_max: float = 12.0
    preferred_duty_max:  float = 14.0

    # Structure preferences
    prefers_international:  bool = False
    prefers_short_haul:     bool = False
    prefers_long_layovers:  bool = False
    avoids_early_signin:    bool = False
    avoids_deadhead:        bool = False

    # Confidence (how many data points back this up)
    confidence:             float = 0.0    # 0–1


class FatigueToleranceProfile(BaseModel):
    """
    Inferred fatigue tolerance from what the user actually accepts.
    High-fatigue trades accepted → higher tolerance.
    """
    avg_fatigue_of_accepted: float = 0.0   # 0–1
    max_fatigue_accepted:    float = 0.0
    high_fatigue_accepts:    int = 0
    total_accepts:           int = 0
    tolerance_level:         str = "medium"  # "low" | "medium" | "high"

    def compute_tolerance(self) -> str:
        if self.total_accepts == 0:
            return "medium"
        ratio = self.high_fatigue_accepts / self.total_accepts
        if ratio > 0.5:   return "high"
        if ratio > 0.2:   return "medium"
        return "low"


class UserPreferenceProfile(BaseModel):
    """
    Complete behavioral preference profile for one crew member.
    Stored in Firestore: users/{userId}/preferenceProfile/main
    Built entirely from the user's own trade behavior — no external inference.
    """
    user_id:          str
    updated_at:       datetime = Field(default_factory=datetime.utcnow)
    total_events:     int = 0

    # Learned preferences
    route_frequency:          dict[str, RouteFrequencyEntry] = {}
    destination_preferences:  dict[str, DestinationPreference] = {}
    schedule_pattern:         SchedulePatternPreference = SchedulePatternPreference()
    fatigue_tolerance:        FatigueToleranceProfile = FatigueToleranceProfile()

    # Aggregate signals
    top_routes:               list[str] = []    # top 5 by engagement
    top_destinations:         list[str] = []    # top 5 by preference score
    preferred_timing_band:    str = "morning"   # "early" | "morning" | "afternoon" | "evening"

    # Cold-start flag
    is_cold_start:            bool = True       # True until 5+ events


# ── Behavioral event (write-only log) ────────────────────────────────────────

class BehavioralEvent(BaseModel):
    """
    One recorded user action on a trade.
    Written to Firestore: behaviorEvents/{eventId}
    Used to train the preference model — never exposed in UI.
    """
    event_id:         str
    user_id:          str
    trade_id:         str
    outcome:          TradeOutcome
    recorded_at:      datetime = Field(default_factory=datetime.utcnow)

    # Trade properties at time of event
    route_key:        str            # "JED-DEL" or "JED-DEL-JED"
    destinations:     list[str]      # all IATA codes in the trade
    block_hours:      float
    duty_hours:       float
    fatigue_score:    float          # 0–1
    is_international: bool
    has_deadhead:     bool
    signin_hour:      int            # local hour of first report
    layover_hours:    float          # 0 if no layover
    rest_after_hours: float


# ── Recommendation output ─────────────────────────────────────────────────────

@dataclass
class TradeRecommendationScore:
    """Final composite score for one trade match — shown to user."""
    trade_id:          str
    candidate_prn:     str

    # Component scores (all 0–1)
    legality_score:           float = 0.0
    fatigue_score:            float = 0.0
    route_similarity_score:   float = 0.0
    schedule_compat_score:    float = 0.0
    preference_match_score:   float = 0.0
    behavioral_score:         float = 0.0
    collaborative_score:      float = 0.0

    # Composite
    total_score:       float = 0.0   # 0–100

    # User-facing reasons (plain English, no demographic labels)
    match_reasons:     list[str] = field(default_factory=list)

    # Metadata
    is_legal:          bool = True
    fatigue_level:     str = "medium"
    route_match_label: str = "Similar route"

    def compute_total(self) -> float:
        weights = {
            'legality':   0.25,
            'fatigue':    0.15,
            'route':      0.20,
            'schedule':   0.15,
            'preference': 0.15,
            'behavioral': 0.07,
            'collab':     0.03,
        }
        raw = (
            self.legality_score         * weights['legality']  +
            self.fatigue_score          * weights['fatigue']   +
            self.route_similarity_score * weights['route']     +
            self.schedule_compat_score  * weights['schedule']  +
            self.preference_match_score * weights['preference']+
            self.behavioral_score       * weights['behavioral']+
            self.collaborative_score    * weights['collab']
        )
        self.total_score = round(raw * 100, 1)
        return self.total_score
