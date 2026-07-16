"""
Trade Engine Router
FastAPI routes for trade search, recommendations, PRN workflow, and event tracking.
Mounts at /v1/trade/* in main.py.
"""
from __future__ import annotations
import logging
from fastapi import APIRouter, HTTPException, Query, BackgroundTasks, Depends
from utils.auth import verify_service_or_user, resolve_user_id
from pydantic import BaseModel, Field
from typing import Optional

from recommendation_engine.engine import RecommendationEngine, RecommendationRequest
from compatibility_scoring.scorer import TargetTrip
from behavioral_learning.trade_event_service import TradeEventService
from preference_engine.models import TradeOutcome

logger = logging.getLogger("cip.trade_engine")
router = APIRouter()

_engine   = RecommendationEngine()
_events   = TradeEventService()


# ── Request / Response models ─────────────────────────────────────────────────

class TradeSearchRequest(BaseModel):
    requesting_user_id: str
    requesting_rank:    str
    month:              str              # "JUN-2026"
    max_results:        int = Field(20, ge=1, le=50)

    # Target trip details
    route_key:          str              # "JED-DEL-JED"
    block_hours:        float
    duty_hours:         float
    fdp_minutes:        int
    signin_hour:        int = 8
    layover_hours:      float = 0.0
    is_international:   bool = False
    has_deadhead:       bool = False
    fatigue_score:      float = 0.5
    trip_dates:         list[int] = []   # day numbers in month


class TradeMatchResult(BaseModel):
    prn:               str
    compatibility_pct: float
    is_legal:          bool
    fatigue_level:     str
    route_match_label: str
    reasons:           list[str]
    component_scores:  dict[str, float]


class TradeSearchResponse(BaseModel):
    route:             str
    month:             str
    total_scanned:     int
    legal_count:       int
    match_count:       int
    is_cold_start:     bool
    matches:           list[TradeMatchResult]


class BehaviorEventRequest(BaseModel):
    user_id:         str
    trade_id:        str
    outcome:         str   # "accepted" | "rejected" | "viewed" | "expired"
    route_key:       str
    destinations:    list[str]
    block_hours:     float = 0.0
    duty_hours:      float = 0.0
    fatigue_score:   float = 0.5
    is_international:bool  = False
    has_deadhead:    bool  = False
    signin_hour:     int   = 8
    layover_hours:   float = 0.0
    rest_after_hours:float = 11.0


class PRNStatusUpdate(BaseModel):
    user_id:  str
    trade_id: str
    prn:      str
    status:   str   # "sent" | "pending" | "failed"
    note:     Optional[str] = None


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/search", response_model=TradeSearchResponse)
async def search_trades(req: TradeSearchRequest,
                        claims: dict = Depends(verify_service_or_user)):
    """
    Main trade recommendation endpoint.
    Returns ranked candidates for the given trip.
    All scoring is operational — route, schedule, legality, fatigue, behavior.
    """
    target = TargetTrip(
        route_key        = req.route_key,
        block_hours      = req.block_hours,
        duty_hours       = req.duty_hours,
        fdp_minutes      = req.fdp_minutes,
        signin_hour      = req.signin_hour,
        layover_hours    = req.layover_hours,
        is_international = req.is_international,
        has_deadhead     = req.has_deadhead,
        fatigue_score    = req.fatigue_score,
        dates            = req.trip_dates,
    )

    request = RecommendationRequest(
        requesting_user_id = resolve_user_id(claims, req.requesting_user_id),
        requesting_rank    = req.requesting_rank,
        target_trip        = target,
        month              = req.month,
        max_results        = req.max_results,
    )

    result = await _engine.recommend(request)

    matches = [
        TradeMatchResult(
            prn               = m.candidate_prn,
            compatibility_pct = m.total_score,
            is_legal          = m.is_legal,
            fatigue_level     = m.fatigue_level,
            route_match_label = m.route_match_label,
            reasons           = m.match_reasons,
            component_scores  = {
                "legality":  round(m.legality_score * 100, 1),
                "fatigue":   round(m.fatigue_score  * 100, 1),
                "route":     round(m.route_similarity_score * 100, 1),
                "schedule":  round(m.schedule_compat_score  * 100, 1),
            },
        )
        for m in result.matches
    ]

    return TradeSearchResponse(
        route         = result.request_route,
        month         = result.month,
        total_scanned = result.total_candidates,
        legal_count   = result.legal_candidates,
        match_count   = len(matches),
        is_cold_start = result.is_cold_start,
        matches       = matches,
    )


@router.post("/events")
async def record_behavior_event(
    req: BehaviorEventRequest,
    background_tasks: BackgroundTasks,
    claims: dict = Depends(verify_service_or_user),
):
    ev_user_id = resolve_user_id(claims, req.user_id)
    """
    Record a trade interaction event (view, accept, reject).
    Called by the Flutter app after every trade action.
    Updates the user's preference profile in the background.
    """
    try:
        outcome = TradeOutcome(req.outcome)
    except ValueError:
        raise HTTPException(status_code=400,
                            detail=f"Invalid outcome: {req.outcome}")

    trade_data = req.model_dump(exclude={"user_id", "trade_id", "outcome"})

    async def _record():
        await _events.record_event_raw(
            ev_user_id, req.trade_id, outcome, trade_data)

    background_tasks.add_task(_record)
    return {"recorded": True, "outcome": req.outcome}


@router.get("/profile/{user_id}")
async def get_preference_summary(user_id: str,
                                 claims: dict = Depends(verify_service_or_user)):
    user_id = resolve_user_id(claims, user_id)
    """
    Returns the user's behavioral preference summary.
    Only exposes operational stats — no hidden labels.
    """
    profile = await _events.get_profile(user_id)
    return {
        "userId":             user_id,
        "totalEvents":        profile.total_events,
        "isColdStart":        profile.is_cold_start,
        "topRoutes":          profile.top_routes,
        "topDestinations":    profile.top_destinations,
        "preferredTiming":    profile.preferred_timing_band,
        "fatigueToleranceLevel": profile.fatigue_tolerance.tolerance_level,
        "prefersInternational":  profile.schedule_pattern.prefers_international,
        "prefersLongLayovers":   profile.schedule_pattern.prefers_long_layovers,
        "avoidsEarlySignin":     profile.schedule_pattern.avoids_early_signin,
    }


@router.post("/profile/{user_id}/rebuild")
async def rebuild_profile(user_id: str, background_tasks: BackgroundTasks,
                          claims: dict = Depends(verify_service_or_user)):
    """Admin endpoint — triggers full profile rebuild from all historical events."""
    user_id = resolve_user_id(claims, user_id)
    background_tasks.add_task(_events.rebuild_profile, user_id)
    return {"status": "rebuild_queued", "userId": user_id}


@router.put("/prn-status")
async def update_prn_status(req: PRNStatusUpdate,
                            claims: dict = Depends(verify_service_or_user)):
    """
    Track the manual PRN contact workflow status.
    Stores per-trade per-PRN status: sent / pending / failed.
    """
    req.user_id = resolve_user_id(claims, req.user_id)
    try:
        from utils.firebase import get_firestore
        db = get_firestore()
        doc_id = f"{req.user_id}_{req.trade_id}_{req.prn}"
        db.collection("tradeContacts").document(doc_id).set({
            "userId":  req.user_id,
            "tradeId": req.trade_id,
            "prn":     req.prn,
            "status":  req.status,
            "note":    req.note,
        }, merge=True)
        return {"updated": True, "status": req.status}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/prn-status/{user_id}/{trade_id}")
async def get_prn_statuses(user_id: str, trade_id: str,
                           claims: dict = Depends(verify_service_or_user)):
    user_id = resolve_user_id(claims, user_id)
    """
    Get all PRN contact statuses for a specific trade search session.
    Returns list of {prn, status, note} for display in the PRN workflow UI.
    """
    try:
        from utils.firebase import get_firestore
        docs = (get_firestore().collection("tradeContacts")
                .where("userId",  "==", user_id)
                .where("tradeId", "==", trade_id)
                .stream())
        return [d.to_dict() for d in docs]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
