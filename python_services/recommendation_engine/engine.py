"""
Recommendation Engine
Orchestrates the full trade recommendation pipeline:
  1. Fetch all candidates (same rank, same month)
  2. Filter by legality
  3. Run compatibility scoring on each
  4. Apply collaborative boost
  5. Return ranked list
"""
from __future__ import annotations
import asyncio
import logging
from dataclasses import dataclass, field
from typing import Optional

from preference_engine.models import UserPreferenceProfile, TradeRecommendationScore
from preference_engine.profile_service import ProfileService
from compatibility_scoring.scorer import CompatibilityScorer, TradeCandidate, TargetTrip

logger = logging.getLogger("cip.recommendation_engine")

_scorer      = CompatibilityScorer()
_profile_svc = ProfileService()

# Minimum score to appear in results
MIN_SCORE_THRESHOLD = 30.0
MAX_RESULTS         = 50


@dataclass
class RecommendationRequest:
    """Input to the recommendation engine."""
    requesting_user_id:  str
    requesting_rank:     str
    target_trip:         TargetTrip
    month:               str          # "JUN-2026"
    max_results:         int = 20


@dataclass
class RecommendationResult:
    """Output from the recommendation engine."""
    request_route:       str
    month:               str
    total_candidates:    int
    legal_candidates:    int
    matches:             list[TradeRecommendationScore] = field(default_factory=list)
    is_cold_start:       bool = False  # True when requesting user has no history


class RecommendationEngine:
    """
    Main entry point for the trade recommendation system.
    All scoring is based on operational schedule data and behavioral history.
    """

    async def recommend(
        self, request: RecommendationRequest
    ) -> RecommendationResult:

        # ── 1. Fetch requesting user's preference profile ─────────────────────
        requester_profile = await _profile_svc.get_profile(request.requesting_user_id)

        # ── 2. Fetch all candidates ───────────────────────────────────────────
        all_candidates = await self._fetch_candidates(
            request.requesting_rank,
            request.month,
            exclude_user_id=request.requesting_user_id,
        )

        total = len(all_candidates)
        legal = [c for c in all_candidates if c.is_legal]
        logger.info(f"Candidates: {total} total, {len(legal)} legal for {request.requesting_rank}")

        # ── 3. Score each candidate ────────────────────────────────────────────
        scored: list[TradeRecommendationScore] = []
        for candidate in legal:
            # Fetch candidate's profile for behavioral scoring
            cand_profile = await _profile_svc.get_profile(candidate.user_id)

            collab_boost = self._collaborative_boost(
                cand_profile, request.target_trip
            )

            rec = _scorer.score(
                candidate    = candidate,
                target       = request.target_trip,
                profile      = cand_profile,
                collab_boost = collab_boost,
            )

            if rec.total_score >= MIN_SCORE_THRESHOLD:
                scored.append(rec)

        # ── 4. Rank ────────────────────────────────────────────────────────────
        scored.sort(key=lambda r: r.total_score, reverse=True)

        return RecommendationResult(
            request_route    = request.target_trip.route_key,
            month            = request.month,
            total_candidates = total,
            legal_candidates = len(legal),
            matches          = scored[:request.max_results],
            is_cold_start    = requester_profile.is_cold_start,
        )

    # ── Private ────────────────────────────────────────────────────────────────

    def _collaborative_boost(
        self,
        candidate_profile: UserPreferenceProfile,
        target: TargetTrip,
    ) -> float:
        """
        Boost based on whether other crew with similar behavioral patterns
        have accepted this type of trade.
        Fully anonymous — no identity involved, purely pattern matching.
        """
        if candidate_profile.is_cold_start:
            return 0.0

        # Check if this route is in their top routes
        if target.route_key in candidate_profile.top_routes:
            return 0.80

        # Check if any destination is in their top destinations
        airports = target.route_key.replace("→", "-").split("-")
        for iata in airports:
            if iata in candidate_profile.top_destinations:
                return 0.50

        return 0.0

    async def _fetch_candidates(
        self,
        rank:            str,
        month:           str,
        exclude_user_id: str,
    ) -> list[TradeCandidate]:
        """
        Fetch all crew of the same rank who have uploaded a line for this month.
        Returns TradeCandidate objects built from Firestore data.
        """
        candidates: list[TradeCandidate] = []

        try:
            from utils.firebase import get_firestore
            db = get_firestore()

            # Query flight lines by rank and month
            docs = (db.collection("flightLines")
                    .where("rank", "==", rank)
                    .where("month", "==", month)
                    .stream())

            for doc in docs:
                data = doc.to_dict()
                uid  = data.get("userId", "")
                if uid == exclude_user_id:
                    continue

                try:
                    c = self._build_candidate(doc.id, uid, data)
                    candidates.append(c)
                except Exception as e:
                    logger.debug(f"Skipping candidate {doc.id}: {e}")

        except Exception as e:
            logger.warning(f"Candidate fetch failed: {e}")
            # Return empty list — caller handles gracefully

        return candidates

    def _build_candidate(
        self, line_id: str, user_id: str, data: dict
    ) -> TradeCandidate:
        """Map Firestore flightLine document to TradeCandidate."""

        # Extract route keys from legs
        legs = data.get("legs", [])
        route_keys = []
        for leg in legs:
            orig = leg.get("origin", "")
            dest = leg.get("destination", "")
            if orig and dest:
                route_keys.append(f"{orig}-{dest}")

        return TradeCandidate(
            prn              = data.get("crewPrn", data.get("prn", user_id[:8])),
            user_id          = user_id,
            rank             = data.get("rank", ""),
            line_id          = line_id,
            route_keys       = route_keys,
            block_hours      = float(data.get("totalBlockHours", 0)),
            duty_hours       = float(data.get("totalDutyHours", 0)),
            fdp_minutes      = int(data.get("maxFdpMinutes", 0)),
            rest_after_mins  = int(data.get("minRestMinutes", 660)),
            is_legal         = bool(data.get("isLegal", True)),
            legality_margin  = float(data.get("legalityMargin", 0.5)),
            fatigue_score    = float(data.get("fatigueScore", 0.5)),
            carry_over_hrs   = float(data.get("carryOverHours", 0)),
            open_days        = list(data.get("openDays", [])),
            signin_hours     = list(data.get("signinHours", [8])),
        )
