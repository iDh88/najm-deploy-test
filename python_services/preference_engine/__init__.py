"""
Preference Engine
Builds and maintains user preference profiles from behavioral events.
All signals derive from the user's own operational trade history only.
No demographic inference. No identity classification.
"""
from .models import (
    UserPreferenceProfile, BehavioralEvent, TradeOutcome,
    RouteFrequencyEntry, DestinationPreference,
    SchedulePatternPreference, FatigueToleranceProfile,
    TradeRecommendationScore,
)
from .profile_builder import ProfileBuilder
from .profile_service  import ProfileService

__all__ = [
    "UserPreferenceProfile", "BehavioralEvent", "TradeOutcome",
    "RouteFrequencyEntry", "DestinationPreference",
    "SchedulePatternPreference", "FatigueToleranceProfile",
    "TradeRecommendationScore", "ProfileBuilder", "ProfileService",
]
