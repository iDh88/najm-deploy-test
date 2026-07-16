"""
Rest Engine — FastAPI Router
Mounts at /v1/rest/* in main.py.
All endpoints return structured, UI-ready JSON.
"""
from __future__ import annotations
import logging
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from .rules import get_profile, DEFAULT_PROFILE, RulesProfile
from .calculator import DutyInput, RestCalculator
from .legality import LegalityEngine
from .fatigue import FatigueEngine
from .scoring import SafetyScorer
from .validators import DutyInputValidator
from .timezone_utils import format_duration

logger = logging.getLogger("cip.rest_engine")
router = APIRouter()

_calc      = RestCalculator()
_legality  = LegalityEngine()
_fatigue   = FatigueEngine()
_scorer    = SafetyScorer()
_validator = DutyInputValidator()


# ── Shared Pydantic input model ───────────────────────────────────────────────

class DutyRequest(BaseModel):
    duty_start_utc:       str = Field(..., description="ISO 8601 UTC datetime")
    duty_end_utc:         str = Field(..., description="ISO 8601 UTC datetime")
    report_local_hour:    int = Field(8,   ge=0, le=23)
    num_operating_legs:   int = Field(1,   ge=0)
    num_deadhead_legs:    int = Field(0,   ge=0)
    block_minutes:        int = Field(0,   ge=0)
    is_international:     bool = False
    is_augmented:         bool = False
    local_tz:             str = "Asia/Riyadh"
    carry_over_hours:     float = 0.0
    next_duty_start_utc:  Optional[str] = None
    crew_type:            str = "cabin_standard"
    rest_before_mins:     int = 660
    tz_delta_hours:       float = 0.0


class TradeDutyRequest(BaseModel):
    offered:          DutyRequest
    requested:        DutyRequest
    crew_type:        str = "cabin_standard"
    rest_before_mins: int = 660


def _parse_duty(req: DutyRequest) -> tuple[DutyInput, RulesProfile]:
    """Parse request into DutyInput + RulesProfile. Raises 400 on bad input."""
    try:
        duty_start = datetime.fromisoformat(req.duty_start_utc)
        duty_end   = datetime.fromisoformat(req.duty_end_utc)
        next_duty  = (datetime.fromisoformat(req.next_duty_start_utc)
                      if req.next_duty_start_utc else None)
    except ValueError as e:
        raise HTTPException(status_code=400,
                            detail=f"Invalid datetime format: {e}")

    inp = DutyInput(
        duty_start_utc      = duty_start,
        duty_end_utc        = duty_end,
        report_local_hour   = req.report_local_hour,
        num_operating_legs  = req.num_operating_legs,
        num_deadhead_legs   = req.num_deadhead_legs,
        block_minutes       = req.block_minutes,
        is_international    = req.is_international,
        is_augmented        = req.is_augmented,
        local_tz            = req.local_tz,
        carry_over_hours    = req.carry_over_hours,
        next_duty_start_utc = next_duty,
    )
    validation = _validator.validate(inp)
    if not validation.is_valid:
        raise HTTPException(status_code=400,
                            detail={"errors": validation.errors})

    profile = get_profile(req.crew_type)
    return inp, profile


def _serialize_legality(result) -> dict:
    calc = result.calculation

    rest_data = None
    if calc and calc.rest:
        r = calc.rest
        rest_data = {
            "duration_label":  r.duration_label,
            "minimum_label":   r.minimum_label,
            "margin_label":    r.margin_label,
            "is_sufficient":   r.is_sufficient,
            "is_marginal":     r.is_marginal,
            "local_start":     r.local_start_label,
            "local_end":       r.local_end_label,
        }

    fdp_data = None
    if calc:
        f = calc.fdp
        fdp_data = {
            "actual_label":    f.actual_label,
            "limit_label":     f.limit_label,
            "margin_label":    f.margin_label,
            "is_within_limit": f.is_within_limit,
            "is_marginal":     f.is_marginal,
            "early_signin":    f.early_signin,
            "wocl_penetration":f.wocl_penetration,
            "wocl_minutes":    f.wocl_minutes,
        }

    carry_data = None
    if calc:
        co = calc.carry_over
        carry_data = {
            "carry_over_hours":  co.carry_over_hours,
            "max_allowed_hours": co.max_allowed_hours,
            "is_within_limit":   co.is_within_limit,
            "percentage_used":   co.percentage_used,
            "remaining_hours":   co.remaining_hours,
        }

    return {
        "is_legal":      result.is_legal,
        "status_label":  result.status_label,
        "status_emoji":  result.status_emoji,
        "safety_score":  result.safety_score,
        "violations":    [
            {"severity": v.severity, "rule": v.rule,
             "description": v.description, "actual": v.actual,
             "limit": v.limit, "excess": v.excess}
            for v in result.violations
        ],
        "warnings": [
            {"severity": v.severity, "rule": v.rule,
             "description": v.description, "actual": v.actual,
             "limit": v.limit}
            for v in result.warnings
        ],
        "advisories": [
            {"severity": v.severity, "rule": v.rule,
             "description": v.description}
            for v in result.advisories
        ],
        "rest":       rest_data,
        "fdp":        fdp_data,
        "carry_over": carry_data,
        "total_duty_label": calc.total_duty_label if calc else None,
    }


def _serialize_fatigue(result) -> dict:
    return {
        "raw":           result.raw,
        "percentage":    result.percentage,
        "level":         result.level.value,
        "level_emoji":   result.level_emoji,
        "wocl_minutes":  result.wocl_minutes,
        "early_signin":  result.early_signin,
        "recommendation":result.recommendation,
        "factors": [
            {"name": f.name, "score": round(f.score, 3),
             "weight": f.weight, "weighted": round(f.weighted, 3),
             "description": f.description}
            for f in result.factors
        ],
    }


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/calculate")
async def calculate_rest(req: DutyRequest):
    """
    Full rest + FDP + carry-over calculation.
    Returns structured data for timeline and summary UI.
    """
    inp, profile = _parse_duty(req)
    calc = _calc.calculate(inp, profile)

    rest_data  = None
    if calc.rest:
        r = calc.rest
        rest_data = {
            "duration_mins":  r.duration_mins,
            "minimum_mins":   r.minimum_mins,
            "margin_mins":    r.margin_mins,
            "is_sufficient":  r.is_sufficient,
            "is_marginal":    r.is_marginal,
            "duration_label": r.duration_label,
            "minimum_label":  r.minimum_label,
            "margin_label":   r.margin_label,
            "local_start":    r.local_start_label,
            "local_end":      r.local_end_label,
        }

    return {
        "total_duty_label": calc.total_duty_label,
        "total_duty_mins":  calc.total_duty_mins,
        "fdp": {
            "actual_mins":      calc.fdp.actual_mins,
            "limit_mins":       calc.fdp.limit_mins,
            "margin_mins":      calc.fdp.margin_mins,
            "is_within_limit":  calc.fdp.is_within_limit,
            "is_marginal":      calc.fdp.is_marginal,
            "actual_label":     calc.fdp.actual_label,
            "limit_label":      calc.fdp.limit_label,
            "margin_label":     calc.fdp.margin_label,
            "early_signin":     calc.fdp.early_signin,
            "wocl_penetration": calc.fdp.wocl_penetration,
            "wocl_minutes":     calc.fdp.wocl_minutes,
        },
        "rest":       rest_data,
        "carry_over": {
            "carry_over_hours":  calc.carry_over.carry_over_hours,
            "max_allowed_hours": calc.carry_over.max_allowed_hours,
            "is_within_limit":   calc.carry_over.is_within_limit,
            "percentage_used":   calc.carry_over.percentage_used,
            "remaining_hours":   calc.carry_over.remaining_hours,
        },
        "profile_name": profile.name,
    }


@router.post("/validate")
async def validate_legality(req: DutyRequest):
    """Full legality check with all violations, warnings, and advisories."""
    inp, profile = _parse_duty(req)
    result       = _legality.validate(inp, profile)
    return _serialize_legality(result)


@router.post("/fatigue")
async def score_fatigue(req: DutyRequest):
    """FRMS-based fatigue scoring for one duty period."""
    inp, profile = _parse_duty(req)
    result       = _fatigue.score(
        inp,
        rest_before_mins = req.rest_before_mins,
        tz_delta_hours   = req.tz_delta_hours,
        profile          = profile,
    )
    return _serialize_fatigue(result)


@router.post("/safety")
async def safety_report(req: DutyRequest):
    """
    Combined safety report: legality + fatigue + composite score.
    Primary endpoint for trade compatibility display.
    """
    inp, profile = _parse_duty(req)
    report       = _scorer.score(
        inp,
        rest_before_mins = req.rest_before_mins,
        tz_delta_hours   = req.tz_delta_hours,
        profile          = profile,
    )
    return {
        "is_legal":            report.is_legal,
        "is_safe":             report.is_safe,
        "safety_score":        report.safety_score,
        "fatigue_level":       report.fatigue_level,
        "fatigue_score":       report.fatigue_score,
        "summary":             report.summary,
        "legality_component":  round(report.legality_component * 100, 1),
        "fatigue_component":   round(report.fatigue_component  * 100, 1),
        "rest_component":      round(report.rest_component     * 100, 1),
        "fdp_component":       round(report.fdp_component      * 100, 1),
        "legality":            _serialize_legality(report.legality_result),
        "fatigue":             _serialize_fatigue(report.fatigue_result),
    }


@router.post("/trade")
async def validate_trade(req: TradeDutyRequest):
    """
    Validate both sides of a trade.
    Returns trade_is_safe flag and both safety reports.
    """
    offered_inp,   offered_profile   = _parse_duty(req.offered)
    requested_inp, requested_profile = _parse_duty(req.requested)

    result = _scorer.score_trade_pair(
        offered          = offered_inp,
        requested        = requested_inp,
        rest_before_mins = req.rest_before_mins,
        profile          = offered_profile,
    )

    return {
        "trade_is_safe":    result["trade_is_safe"],
        "avg_safety_score": result["avg_safety_score"],
        "recommendation":   result["recommendation"],
        "offered": {
            "is_legal":     result["offered_report"].is_legal,
            "is_safe":      result["offered_report"].is_safe,
            "safety_score": result["offered_report"].safety_score,
            "fatigue_level":result["offered_report"].fatigue_level,
            "summary":      result["offered_report"].summary,
        },
        "requested": {
            "is_legal":     result["requested_report"].is_legal,
            "is_safe":      result["requested_report"].is_safe,
            "safety_score": result["requested_report"].safety_score,
            "fatigue_level":result["requested_report"].fatigue_level,
            "summary":      result["requested_report"].summary,
        },
    }


@router.get("/rules")
async def get_rules(crew_type: str = "cabin_standard"):
    """Return the active rules profile for a crew type."""
    profile = get_profile(crew_type)
    return {
        "name":      profile.name,
        "crew_type": profile.crew_type,
        "rest_minimums": {
            "domestic_mins":      profile.min_rest_domestic_mins,
            "international_mins": profile.min_rest_international_mins,
            "extended_mins":      profile.extended_rest_mins,
        },
        "fdp_limits": profile.fdp_limits_by_legs,
        "block_limit_mins":  profile.max_daily_block_mins,
        "wocl_hours":        f"{profile.wocl_start_hour:02d}:00–{profile.wocl_end_hour:02d}:59",
        "briefing_mins":     profile.pre_flight_briefing_mins,
        "debriefing_mins":   profile.post_flight_debriefing_mins,
    }
