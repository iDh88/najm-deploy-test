"""
Smart Ranking Engine
Scores and ranks flight lines for a specific user based on their active mode.
Every score includes a human-readable explanation in Arabic and English.
"""

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel, Field

def _canonical_min_rest_hours() -> float:
    from legality.rules_source import get_effective_rules
    return get_effective_rules().get("min_rest_domestic_hours")

logger = logging.getLogger("cip.ranking")
router = APIRouter()

# ─── Mode Weights ─────────────────────────────────────────────────────────────

MODE_WEIGHTS = {
    "money": {
        "salary": 0.50,
        "international_pct": 0.25,
        "overtime_potential": 0.15,
        "dest_preference": 0.10,
        "rest_quality": 0.00,
        "regularity": 0.00,
    },
    "rest": {
        "salary": 0.00,
        "international_pct": 0.00,
        "overtime_potential": 0.00,
        "dest_preference": 0.10,
        "rest_quality": 0.60,
        "regularity": 0.30,
    },
    "balanced": {
        "salary": 0.35,
        "international_pct": 0.00,
        "overtime_potential": 0.00,
        "dest_preference": 0.20,
        "rest_quality": 0.30,
        "regularity": 0.15,
    },
}

# ─── Pydantic Models ─────────────────────────────────────────────────────────

class UserPreferences(BaseModel):
    preferred_dest: list[str] = []
    avoided_dest: list[str] = []
    preferred_off: list[int] = []   # Day indices (0=Sun)
    max_duty_hours: float = 120.0
    # Scoring heuristic floor — sourced from the canonical rules (P0-1
    # single-source principle), not a hardcoded pre-remediation 10.0.
    min_rest_hours: float = Field(
        default_factory=lambda: _canonical_min_rest_hours())
    home_base_return: bool = True
    user_mode: str = "balanced"

class LineSummaryInput(BaseModel):
    line_id: str
    line_number: str
    total_legs: int
    total_block_hours: float
    total_duty_hours: float
    total_duty_days: int
    international_legs: int
    domestic_legs: int
    layover_count: int
    estimated_salary_min: float
    estimated_salary_max: float
    destinations: list[str] = []
    days_off: list[int] = []            # Day-of-week indices of days off
    min_rest_interval_hours: float = 14.0
    avg_rest_interval_hours: float = 16.0
    rest_near_minimum_count: int = 0    # Count of rests within 1h of minimum

class RankedLine(BaseModel):
    line_id: str
    line_number: str
    rank: int
    composite_score: float
    salary_score: float
    rest_quality_score: float
    dest_preference_score: float
    regularity_score: float
    component_scores: dict = {}
    explanation: str
    explanation_ar: str
    # Vision "Explainable AI": the individual reasons behind `explanation`,
    # for checkmark-style rendering. Additive field — older callers unaffected.
    reasons: list[str] = []
    estimated_salary_mid: float

class RankRequest(BaseModel):
    user_id: str
    user_preferences: UserPreferences
    lines: list[LineSummaryInput]
    all_lines_salary_max: float = 0.0  # For normalization

class RankResponse(BaseModel):
    ranked_lines: list[RankedLine]
    user_mode: str
    ranked_at: datetime = Field(default_factory=datetime.utcnow)

# ─── Scoring Functions ────────────────────────────────────────────────────────

def score_salary(line: LineSummaryInput, all_max: float) -> float:
    """Normalize salary against the highest-paying line this month. Returns 0-100."""
    if all_max <= 0:
        return 50.0
    mid = (line.estimated_salary_min + line.estimated_salary_max) / 2
    return min(100.0, (mid / all_max) * 100)

def score_international_pct(line: LineSummaryInput) -> float:
    """Score based on proportion of international legs (higher = more per diem)."""
    if line.total_legs == 0:
        return 0.0
    pct = line.international_legs / line.total_legs
    return pct * 100

def score_overtime_potential(line: LineSummaryInput) -> float:
    """Score lines that approach but don't exceed overtime thresholds."""
    # Overtime typically triggers after 80h block/month
    overtime_threshold = 80.0
    if line.total_block_hours >= overtime_threshold:
        return 80.0  # Good potential, slight cap for risk
    return (line.total_block_hours / overtime_threshold) * 80

def score_rest_quality(line: LineSummaryInput, prefs: UserPreferences) -> float:
    """Score rest quality based on minimums, averages, and near-minimum counts."""
    score = 100.0

    # Penalty for each rest period near minimum (within 1h)
    score -= line.rest_near_minimum_count * 15.0

    # Bonus for generous average rest
    if line.avg_rest_interval_hours >= 20:
        score += 10
    elif line.avg_rest_interval_hours >= 18:
        score += 5

    # Penalty if min rest is very close to minimum required
    min_required = prefs.min_rest_hours
    if line.min_rest_interval_hours < min_required + 1:
        score -= 20.0

    # Preferred days off hit rate
    if prefs.preferred_off and line.days_off:
        hits = len(set(prefs.preferred_off) & set(line.days_off))
        hit_rate = hits / len(prefs.preferred_off)
        score += hit_rate * 20.0

    return max(0.0, min(100.0, score))

def score_dest_preference(line: LineSummaryInput, prefs: UserPreferences) -> float:
    """Score based on destination preference and avoidance."""
    score = 50.0  # Neutral baseline

    for dest in line.destinations:
        if dest in prefs.preferred_dest:
            score += 20.0
        if dest in prefs.avoided_dest:
            score -= 25.0

    # Novel destinations bonus (not in preferred or avoided — exploration)
    known = set(prefs.preferred_dest) | set(prefs.avoided_dest)
    novel = [d for d in line.destinations if d not in known]
    score += len(novel) * 3.0  # Small exploration bonus

    return max(0.0, min(100.0, score))

def score_regularity(line: LineSummaryInput, prefs: UserPreferences) -> float:
    """Score schedule regularity: clustered days off, consistent patterns."""
    score = 50.0

    # Days off clustering: consecutive days off score higher
    days_off_sorted = sorted(line.days_off)
    if len(days_off_sorted) >= 2:
        consecutive_count = 0
        for i in range(len(days_off_sorted) - 1):
            if days_off_sorted[i+1] - days_off_sorted[i] == 1:
                consecutive_count += 1
        score += consecutive_count * 5.0

    # Duty days ratio
    if line.total_duty_days <= 15:
        score += 15.0
    elif line.total_duty_days <= 20:
        score += 5.0

    # Home base return preference
    if prefs.home_base_return and line.layover_count == 0:
        score += 10.0
    elif not prefs.home_base_return and line.layover_count > 0:
        score += 10.0

    return max(0.0, min(100.0, score))

# ─── Explanation Generator ────────────────────────────────────────────────────

def generate_explanation(
    line: LineSummaryInput,
    rank: int,
    scores: dict,
    prefs: UserPreferences,
    mode: str,
) -> tuple[str, str]:
    """Generate English and Arabic explanations for a ranking."""
    reasons_en = []
    reasons_ar = []
    mid_salary = (line.estimated_salary_min + line.estimated_salary_max) / 2

    if mode == "money":
        reasons_en.append(f"estimated salary SAR {mid_salary:,.0f}")
        reasons_ar.append(f"الراتب التقديري {mid_salary:,.0f} ريال")
        if line.international_legs > 0:
            reasons_en.append(f"{line.international_legs} international legs with per diem")
            reasons_ar.append(f"{line.international_legs} رحلة دولية مع بدل إقامة")

    elif mode == "rest":
        if prefs.preferred_off:
            day_names_en = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            day_names_ar = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
            hits = set(prefs.preferred_off) & set(line.days_off)
            if hits:
                en_days = " & ".join(day_names_en[d] for d in sorted(hits))
                ar_days = " و".join(day_names_ar[d] for d in sorted(hits))
                reasons_en.append(f"includes your preferred days off ({en_days})")
                reasons_ar.append(f"يشمل أيام إجازتك المفضلة ({ar_days})")
        reasons_en.append(f"avg rest {line.avg_rest_interval_hours:.0f}h between duties")
        reasons_ar.append(f"متوسط الراحة {line.avg_rest_interval_hours:.0f} ساعة بين الواجبات")

    else:  # balanced
        reasons_en.append(f"salary SAR {mid_salary:,.0f}")
        reasons_ar.append(f"الراتب {mid_salary:,.0f} ريال")
        reasons_en.append(f"rest quality score {scores['rest_quality']:.0f}/100")
        reasons_ar.append(f"درجة جودة الراحة {scores['rest_quality']:.0f}/100")

    # Preferred destinations
    matching_dest = [d for d in line.destinations if d in prefs.preferred_dest]
    if matching_dest:
        reasons_en.append(f"includes your preferred destinations ({', '.join(matching_dest[:3])})")
        reasons_ar.append(f"يشمل وجهاتك المفضلة ({', '.join(matching_dest[:3])})")

    rank_text_en = f"Line {line.line_number} ranked #{rank} because it has "
    rank_text_ar = f"الخط {line.line_number} في المرتبة #{rank} لأنه يتضمن "

    explanation_en = rank_text_en + ", ".join(reasons_en) + "."
    explanation_ar = rank_text_ar + "، ".join(reasons_ar) + "."

    return explanation_en, explanation_ar, reasons_en

# ─── Main Ranker ──────────────────────────────────────────────────────────────

def rank_lines(
    lines: list[LineSummaryInput],
    prefs: UserPreferences,
    all_max_salary: float,
) -> list[RankedLine]:
    mode = prefs.user_mode
    weights = MODE_WEIGHTS.get(mode, MODE_WEIGHTS["balanced"])
    ranked: list[RankedLine] = []

    for line in lines:
        component_scores = {
            "salary": score_salary(line, all_max_salary),
            "international_pct": score_international_pct(line),
            "overtime_potential": score_overtime_potential(line),
            "rest_quality": score_rest_quality(line, prefs),
            "dest_preference": score_dest_preference(line, prefs),
            "regularity": score_regularity(line, prefs),
        }

        composite = sum(
            component_scores.get(key, 0.0) * weight
            for key, weight in weights.items()
        )
        composite = min(100.0, max(0.0, composite))

        ranked.append(RankedLine(
            line_id=line.line_id,
            line_number=line.line_number,
            rank=0,  # Set after sorting
            composite_score=round(composite, 1),
            salary_score=round(component_scores["salary"], 1),
            rest_quality_score=round(component_scores["rest_quality"], 1),
            dest_preference_score=round(component_scores["dest_preference"], 1),
            regularity_score=round(component_scores["regularity"], 1),
            component_scores=component_scores,
            explanation="",
            explanation_ar="",
            estimated_salary_mid=round(
                (line.estimated_salary_min + line.estimated_salary_max) / 2, 0
            ),
        ))

    # Sort and assign ranks
    ranked.sort(key=lambda r: r.composite_score, reverse=True)
    for i, r in enumerate(ranked):
        line = next(l for l in lines if l.line_id == r.line_id)
        exp_en, exp_ar, reasons_en = generate_explanation(
            line, i + 1, r.component_scores, prefs, mode
        )
        ranked[i] = r.model_copy(update={
            "rank": i + 1,
            "reasons": reasons_en,
            "explanation": exp_en,
            "explanation_ar": exp_ar,
        })

    return ranked

# ─── API Endpoints ────────────────────────────────────────────────────────────

@router.post("/rank", response_model=RankResponse)
async def rank_flight_lines(request: RankRequest) -> RankResponse:
    if not request.lines:
        return RankResponse(ranked_lines=[], user_mode=request.user_preferences.user_mode)

    all_max = request.all_lines_salary_max
    if all_max <= 0:
        all_max = max(
            (l.estimated_salary_max for l in request.lines), default=1.0
        )

    ranked = rank_lines(request.lines, request.user_preferences, all_max)
    logger.info(
        f"Ranked {len(ranked)} lines for user {request.user_id} in {request.user_preferences.user_mode} mode"
    )
    return RankResponse(ranked_lines=ranked, user_mode=request.user_preferences.user_mode)
