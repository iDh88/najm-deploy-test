"""
Compatibility Scoring Engine
Computes composite trade match scores from operational factors only.
"""
from .scorer import CompatibilityScorer, TradeCandidate, TargetTrip
__all__ = ["CompatibilityScorer", "TradeCandidate", "TargetTrip"]
