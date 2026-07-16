"""
Rest Engine
Aviation-grade rest calculation, legality validation, and fatigue scoring.
Ships with built-in GACA/ICAO-aligned default rules.
Zero configuration required.
"""
from .rules      import RulesProfile, get_profile, DEFAULT_PROFILE, CrewType
from .calculator import RestCalculator, DutyInput, DutyCalculation, RestWindow
from .legality   import LegalityEngine, LegalityResult, Violation, ViolationSeverity
from .fatigue    import FatigueEngine, FatigueScore, FatigueLevel
from .scoring    import SafetyScorer, SafetyReport
from .validators import DutyInputValidator
from .router     import router

__all__ = [
    "RulesProfile", "get_profile", "DEFAULT_PROFILE", "CrewType",
    "RestCalculator", "DutyInput", "DutyCalculation", "RestWindow",
    "LegalityEngine", "LegalityResult", "Violation", "ViolationSeverity",
    "FatigueEngine", "FatigueScore", "FatigueLevel",
    "SafetyScorer", "SafetyReport",
    "DutyInputValidator",
    "router",
]
