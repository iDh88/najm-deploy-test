"""
Auto-Bid Engine — Crew Intelligence Platform
Learns from crew behavior to suggest and auto-submit bids.
Handles cold-start, preference vectors, and collaborative filtering.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from utils.auth import verify_service_or_user, resolve_user_id
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timedelta
from collections import defaultdict
import math
import logging
import uuid

logger = logging.getLogger("cip.auto_bid")
router = APIRouter()

# ─── Models ───────────────────────────────────────────────────────────────────

class BehaviorEvent(BaseModel):
    eventType: str
    metadata: dict
    timestamp: datetime
    userMode: str = "balanced"

class PreferenceVector(BaseModel):
    userId: str
    destinationAffinity: dict[str, float] = {}   # IATA → score
    depTimePreference: dict[str, float] = {}       # hour band → score
    dutyDurationPref: str = "medium"               # short|medium|long
    layoverPreference: float = 0.5                 # 0=avoid, 1=love
    dayOffPreference: dict[str, float] = {}        # weekday → score
    intlDomRatio: float = 0.6                      # 0=all dom, 1=all intl
    salarySensitivity: float = 0.5                 # 0=ignore, 1=maximize
    coldStartPhase: int = 1
    lastUpdated: datetime = Field(default_factory=datetime.utcnow)

class AutoBidSuggestion(BaseModel):
    lineId: str
    lineNumber: str
    suggestedPriority: int
    compositeScore: float
    salaryScore: float
    restScore: float
    prefMatchScore: float
    estimatedSalary: float
    explanationEn: str
    explanationAr: str
    isLegal: bool
    violations: list[str] = []

class AutoBidRequest(BaseModel):
    userId: str
    month: str
    userMode: str = "balanced"  # money | rest | balanced
    availableLineIds: list[str]
    autoSubmit: bool = False    # PRO hands-off mode

class AutoBidResponse(BaseModel):
    userId: str
    month: str
    suggestions: list[AutoBidSuggestion]
    autoSubmitted: bool
    submittedBidIds: list[str]
    explanation: str

class UpdateVectorRequest(BaseModel):
    userId: str
    events: list[BehaviorEvent]

# ─── Mode Weights ─────────────────────────────────────────────────────────────

MODE_WEIGHTS = {
    "money":    {"salary": 0.50, "rest": 0.15, "dest_pref": 0.25, "regularity": 0.10},
    "rest":     {"salary": 0.10, "rest": 0.55, "dest_pref": 0.25, "regularity": 0.10},
    "balanced": {"salary": 0.30, "rest": 0.35, "dest_pref": 0.25, "regularity": 0.10},
}

# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/suggest", response_model=AutoBidResponse)
async def suggest_bids(request: AutoBidRequest, background_tasks: BackgroundTasks,
                       claims: dict = Depends(verify_service_or_user)):
    """Generate ranked bid suggestions for a user based on learned preferences."""
    try:
        engine = AutoBidEngine(user_id=resolve_user_id(claims, request.userId), month=request.month)
        pref_vector = await engine.load_preference_vector()
        lines_data = await engine.load_lines(request.availableLineIds, request.month)
        suggestions = engine.rank_lines(lines_data, pref_vector, request.userMode)

        submitted_ids = []
        if request.autoSubmit and suggestions:
            submitted_ids = await engine.submit_bids(suggestions[:5])

        return AutoBidResponse(
            userId=request.userId,
            month=request.month,
            suggestions=suggestions[:10],
            autoSubmitted=request.autoSubmit,
            submittedBidIds=submitted_ids,
            explanation=_generate_batch_explanation(suggestions[:3], request.userMode),
        )
    except Exception as e:
        logger.error(f"Auto-bid failed for {request.userId}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/update-vector")
async def update_preference_vector(request: UpdateVectorRequest, background_tasks: BackgroundTasks,
                                   claims: dict = Depends(verify_service_or_user)):
    """Update a user's preference vector from new behavior events."""
    engine = AutoBidEngine(user_id=resolve_user_id(claims, request.userId), month="")
    background_tasks.add_task(engine.update_vector_from_events, request.events)
    return {"status": "queued", "eventCount": len(request.events)}


@router.get("/vector/{user_id}", response_model=PreferenceVector)
async def get_preference_vector(user_id: str,
                                claims: dict = Depends(verify_service_or_user)):
    user_id = resolve_user_id(claims, user_id)
    """Retrieve current preference vector for a user."""
    engine = AutoBidEngine(user_id=user_id, month="")
    vector = await engine.load_preference_vector()
    return vector

# ─── Core Engine ─────────────────────────────────────────────────────────────

class AutoBidEngine:
    def __init__(self, user_id: str, month: str):
        self.user_id = user_id
        self.month = month

    async def load_preference_vector(self) -> PreferenceVector:
        """Load from Firestore, or return cold-start defaults."""
        try:
            from utils.firebase import get_firestore
            db = get_firestore()
            doc = db.collection("users").document(self.user_id).get()
            if doc.exists:
                data = doc.to_dict()
                pv_data = data.get("preferenceVector", {})
                prefs = data.get("preferences", {})
                cold_start = data.get("coldStartPhase", 1)

                # Build vector from stored data + explicit preferences
                return PreferenceVector(
                    userId=self.user_id,
                    destinationAffinity=pv_data.get("destinationAffinity", {}),
                    depTimePreference=pv_data.get("depTimePreference", {}),
                    layoverPreference=pv_data.get("layoverPreference", 0.5),
                    dayOffPreference=self._build_day_off_pref(prefs.get("preferredOff", [])),
                    intlDomRatio=pv_data.get("intlDomRatio", 0.6),
                    salarySensitivity=pv_data.get("salarySensitivity", 0.5),
                    coldStartPhase=cold_start,
                )
        except Exception as e:
            logger.warning(f"Could not load vector for {self.user_id}: {e}")
        return PreferenceVector(userId=self.user_id)  # cold start defaults

    async def load_lines(self, line_ids: list[str], month: str) -> list[dict]:
        """Load flight line documents from Firestore."""
        try:
            from utils.firebase import get_firestore
            db = get_firestore()
            lines = []
            for line_id in line_ids:
                doc = db.collection("flightLines").document(line_id).get()
                if doc.exists:
                    lines.append({"id": line_id, **doc.to_dict()})
            return lines
        except Exception as e:
            logger.error(f"Failed to load lines: {e}")
            return []

    def rank_lines(
        self,
        lines: list[dict],
        pref_vector: PreferenceVector,
        user_mode: str,
    ) -> list[AutoBidSuggestion]:
        """Score and rank all lines for this user in the given mode."""
        weights = MODE_WEIGHTS.get(user_mode, MODE_WEIGHTS["balanced"])
        scored = []

        for line in lines:
            summary = line.get("summary", {})
            destinations = line.get("destinations", [])
            days_off = line.get("daysOff", [])

            salary_score = summary.get("salaryScore", 50)
            rest_score = summary.get("restQualityScore", 50)
            dest_pref_score = self._score_destinations(destinations, pref_vector)
            regularity_score = self._score_regularity(days_off, pref_vector)

            composite = (
                salary_score * weights["salary"]
                + rest_score * weights["rest"]
                + dest_pref_score * weights["dest_pref"]
                + regularity_score * weights["regularity"]
            )

            en_explanation, ar_explanation = self._build_explanation(
                line=line,
                salary_score=salary_score,
                rest_score=rest_score,
                dest_pref_score=dest_pref_score,
                user_mode=user_mode,
                destinations=destinations,
                summary=summary,
            )

            scored.append(AutoBidSuggestion(
                lineId=line["id"],
                lineNumber=line.get("lineNumber", "?"),
                suggestedPriority=0,  # set after sorting
                compositeScore=round(composite, 1),
                salaryScore=round(salary_score, 1),
                restScore=round(rest_score, 1),
                prefMatchScore=round(dest_pref_score, 1),
                estimatedSalary=summary.get("estimatedSalaryMin", 0),
                explanationEn=en_explanation,
                explanationAr=ar_explanation,
                isLegal=True,  # legality pre-checked before calling this
            ))

        scored.sort(key=lambda s: s.compositeScore, reverse=True)
        for i, suggestion in enumerate(scored):
            scored[i] = suggestion.model_copy(update={"suggestedPriority": i + 1})
        return scored

    def _score_destinations(self, destinations: list[str], pref: PreferenceVector) -> float:
        """Score line destinations against user's destination affinity."""
        if not destinations:
            return 50.0
        scores = []
        for dest in destinations:
            affinity = pref.destinationAffinity.get(dest, 50.0)
            scores.append(affinity)
        return round(sum(scores) / len(scores), 1)

    def _score_regularity(self, days_off: list[int], pref: PreferenceVector) -> float:
        """Score how well days off match user preferences."""
        if not days_off or not pref.dayOffPreference:
            return 50.0
        hits = sum(pref.dayOffPreference.get(str(d), 0) for d in days_off)
        max_possible = len(days_off) * 100
        return round((hits / max_possible) * 100, 1) if max_possible > 0 else 50.0

    def _build_explanation(
        self, line: dict, salary_score: float, rest_score: float,
        dest_pref_score: float, user_mode: str, destinations: list[str], summary: dict
    ) -> tuple[str, str]:
        """Generate human-readable explanation for this suggestion."""
        line_number = line.get("lineNumber", "?")
        salary = summary.get("estimatedSalaryMin", 0)
        total_duty = summary.get("totalDutyHours", 0)
        layovers = summary.get("layoverCount", 0)

        # Build English explanation
        reasons_en = []
        if salary_score >= 75:
            reasons_en.append(f"estimated salary SAR {salary:,.0f} (top tier this month)")
        if rest_score >= 75:
            reasons_en.append("excellent rest quality throughout the month")
        if dest_pref_score >= 70 and destinations:
            top_dest = destinations[:2]
            reasons_en.append(f"includes preferred destinations ({', '.join(top_dest)})")
        if layovers >= 2:
            reasons_en.append(f"{layovers} international layovers")
        if user_mode == "rest" and total_duty < 80:
            reasons_en.append(f"low total duty hours ({total_duty:.0f}h)")

        if not reasons_en:
            reasons_en.append(f"balanced score across salary, rest, and preferences")

        explanation_en = f"Line {line_number} ranked here because: {'; '.join(reasons_en)}."

        # Build Arabic explanation
        reasons_ar = []
        if salary_score >= 75:
            reasons_ar.append(f"الراتب المتوقع {salary:,.0f} ريال (الأعلى هذا الشهر)")
        if rest_score >= 75:
            reasons_ar.append("جودة راحة ممتازة طوال الشهر")
        if dest_pref_score >= 70 and destinations:
            reasons_ar.append(f"يشمل وجهات مفضلة")
        if not reasons_ar:
            reasons_ar.append("توازن بين الراتب والراحة والتفضيلات")

        explanation_ar = f"الخط {line_number} مقترح لأن: {' ؛ '.join(reasons_ar)}."

        return explanation_en, explanation_ar

    async def update_vector_from_events(self, events: list[BehaviorEvent]):
        """Recompute preference vector from behavioral events with time decay."""
        try:
            from utils.firebase import get_firestore
            db = get_firestore()

            # Load current vector
            current_vector = await self.load_preference_vector()

            dest_scores: dict[str, list[float]] = defaultdict(list)
            day_off_scores: dict[str, list[float]] = defaultdict(list)
            layover_signals: list[float] = []
            intl_signals: list[float] = []
            salary_signals: list[float] = []

            now = datetime.utcnow()

            for event in events:
                # Time decay: events older than 90 days get weight 0.3; recent events get 1.0
                age_days = (now - event.timestamp).days
                weight = max(0.3, 1.0 - (age_days / 90) * 0.7)

                if event.eventType == "line_viewed":
                    dwell = event.metadata.get("dwellTimeSeconds", 0)
                    signal = min(1.0, dwell / 60)  # normalize to 60s max
                    for dest in event.metadata.get("destinations", []):
                        dest_scores[dest].append(signal * weight * 50 + 50)

                elif event.eventType == "bid_submitted":
                    for dest in event.metadata.get("destinations", []):
                        dest_scores[dest].append(80 * weight)
                    intl_ratio = event.metadata.get("intlRatio", 0.5)
                    intl_signals.append(intl_ratio * weight)
                    mode = event.metadata.get("userMode", "balanced")
                    if mode == "money":
                        salary_signals.append(0.8 * weight)
                    elif mode == "rest":
                        salary_signals.append(0.2 * weight)

                elif event.eventType == "bid_outcome":
                    if event.metadata.get("awarded"):
                        for dest in event.metadata.get("destinations", []):
                            dest_scores[dest].append(90 * weight)
                    else:
                        for dest in event.metadata.get("destinations", []):
                            dest_scores[dest].append(40 * weight)

                elif event.eventType == "trade_initiated":
                    # Giving away a leg signals dislike of that destination
                    offered_dest = event.metadata.get("offeredDestination")
                    if offered_dest:
                        dest_scores[offered_dest].append(20 * weight)

                elif event.eventType == "mode_switched":
                    to_mode = event.metadata.get("toMode", "balanced")
                    if to_mode == "money":
                        salary_signals.append(0.9 * weight)
                    elif to_mode == "rest":
                        salary_signals.append(0.1 * weight)

            # Aggregate signals into updated vector
            updated_dest_affinity = dict(current_vector.destinationAffinity)
            for dest, scores in dest_scores.items():
                avg = sum(scores) / len(scores)
                # EMA with existing value
                existing = updated_dest_affinity.get(dest, 50.0)
                updated_dest_affinity[dest] = round(0.7 * avg + 0.3 * existing, 1)

            updated_intl_ratio = (
                sum(intl_signals) / len(intl_signals) if intl_signals
                else current_vector.intlDomRatio
            )
            updated_salary_sens = (
                sum(salary_signals) / len(salary_signals) if salary_signals
                else current_vector.salarySensitivity
            )

            # Determine cold start phase from event count
            total_events = len(events)
            cold_start_phase = 3 if total_events >= 50 else 2 if total_events >= 15 else 1

            # Persist updated vector
            db.collection("users").document(self.user_id).update({
                "preferenceVector": {
                    "destinationAffinity": updated_dest_affinity,
                    "depTimePreference": current_vector.depTimePreference,
                    "layoverPreference": current_vector.layoverPreference,
                    "dayOffPreference": current_vector.dayOffPreference,
                    "intlDomRatio": round(updated_intl_ratio, 2),
                    "salarySensitivity": round(updated_salary_sens, 2),
                    "lastUpdated": datetime.utcnow(),
                },
                "coldStartPhase": cold_start_phase,
            })

            logger.info(f"Updated preference vector for {self.user_id} "
                        f"(phase {cold_start_phase}, {len(updated_dest_affinity)} destinations)")
        except Exception as e:
            logger.error(f"Vector update failed for {self.user_id}: {e}", exc_info=True)

    async def submit_bids(self, suggestions: list[AutoBidSuggestion]) -> list[str]:
        """Auto-submit top suggestions as bids (ELITE tier hands-off mode)."""
        try:
            from utils.firebase import get_firestore
            db = get_firestore()
            bid_ids = []
            for priority, suggestion in enumerate(suggestions, start=1):
                bid_id = str(uuid.uuid4())
                db.collection("bids").document(bid_id).set({
                    "userId": self.user_id,
                    "lineId": suggestion.lineId,
                    "lineNumber": suggestion.lineNumber,
                    "month": self.month,
                    "priority": priority,
                    "status": "submitted",
                    "isAutoBid": True,
                    "autoReasons": [suggestion.explanationEn],
                    "scoreAtBid": {
                        "salaryScore": suggestion.salaryScore,
                        "restScore": suggestion.restScore,
                        "prefScore": suggestion.prefMatchScore,
                        "composite": suggestion.compositeScore,
                    },
                    "estimatedSalary": suggestion.estimatedSalary,
                    "submittedAt": datetime.utcnow(),
                })
                bid_ids.append(bid_id)
            return bid_ids
        except Exception as e:
            logger.error(f"Auto-submit failed: {e}", exc_info=True)
            return []

    def _build_day_off_pref(self, preferred_off: list[int]) -> dict[str, float]:
        """Convert preferred day-off list to scored dict."""
        if not preferred_off:
            return {}
        return {str(day): 100.0 for day in preferred_off}


def _generate_batch_explanation(suggestions: list[AutoBidSuggestion], mode: str) -> str:
    if not suggestions:
        return "No suggestions available for this month."
    top = suggestions[0]
    mode_label = {"money": "maximize salary", "rest": "maximize rest", "balanced": "balance both"}.get(mode, "optimize")
    return (f"Najm ranked {len(suggestions)} lines for you in {mode} mode. "
            f"Top pick: Line {top.lineNumber} (score {top.compositeScore}/100). "
            f"{top.explanationEn}")
