"""filter_engine/router.py — /v1/lines: the three-mode search surface.

One endpoint serves all three vision workflows because they differ only in
where the clauses come from:

  Manual : clauses only                      → engine → rank
  AI     : ai_instruction only               → LLM extraction → ai_bridge →
                                               validate → engine → rank
  Hybrid : clauses (LOCKED) + ai_instruction → merge (manual wins) → engine
                                               → rank

The response always discloses exactly which clauses ran, which AI clauses
were dropped and why, and the full per-line ranking breakdown — the vision's
"never a black box" requirement is a response-shape guarantee, not a habit.

GET /v1/lines/filters returns the registry catalog so the client renders its
Manual-Mode UI dynamically: shipping a new filter is a server deploy, not an
app release.
"""
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from utils.auth import resolve_user_id, verify_service_or_user
from legality.rules_source import get_effective_rules
from ranking.scorer import LineSummaryInput, UserPreferences, rank_lines

from .ai_bridge import AiClauses, from_filter_response, infer_rank_mode
from .engine import run_query
from .hybrid import merge
from .registry import catalog, get as get_def
from .schema import (
    AppliedFilters,
    FilterClause,
    FilterValidationError,
    MatchedFilter,
    RankedResult,
    SearchRequest,
    SearchResponse,
)
from . import registry as _reg_helpers

logger = logging.getLogger("cip.filter_engine")

router = APIRouter()


# ── Catalog ───────────────────────────────────────────────────────────────────

@router.get("/filters")
async def list_filters() -> dict:
    """The full filter catalog (active + requires_field with notes)."""
    return {"filters": catalog(), "engine": "filter_engine.v1"}


# ── Line loading ─────────────────────────────────────────────────────────────

def _load_lines(user_id: str, month: Optional[str]) -> list[dict]:
    from utils.firebase import get_firestore  # lazy for testability
    q = (get_firestore().collection("flightLines")
         .where("userId", "==", user_id)
         .where("isActive", "==", True))
    if month:
        q = q.where("month", "==", month)
    return [{**d.to_dict(), "id": d.id} for d in q.stream()]


# ── Ranking bridge ───────────────────────────────────────────────────────────

def _to_summary_input(line: dict) -> LineSummaryInput:
    s = line.get("summary") or {}
    rests = _reg_helpers._rest_intervals_each(line)
    eff = get_effective_rules()
    min_rest_canonical = eff.get("min_rest_domestic_hours")
    return LineSummaryInput(
        line_id=str(line.get("id") or line.get("lineNumber") or ""),
        line_number=str(line.get("lineNumber") or ""),
        total_legs=int(s.get("totalLegs") or 0),
        total_block_hours=float(s.get("totalBlockHours") or 0),
        total_duty_hours=float(s.get("totalDutyHours") or 0),
        total_duty_days=int(s.get("totalDutyDays") or 0),
        international_legs=int(s.get("internationalLegs") or 0),
        domestic_legs=int(s.get("domesticLegs") or 0),
        layover_count=int(s.get("layoverCount") or 0),
        estimated_salary_min=float(s.get("estimatedSalaryMin") or 0),
        estimated_salary_max=float(s.get("estimatedSalaryMax") or 0),
        destinations=[str(d).upper() for d in (line.get("destinations") or [])],
        days_off=[int(d) for d in (line.get("daysOff") or [])],
        min_rest_interval_hours=min(rests) if rests else min_rest_canonical,
        avg_rest_interval_hours=(sum(rests) / len(rests)) if rests
        else min_rest_canonical,
        rest_near_minimum_count=sum(
            1 for r in rests if r <= min_rest_canonical + 1.0),
    )


def _matched_filters(clauses: list[FilterClause]) -> list[MatchedFilter]:
    out = []
    for c in clauses:
        d = get_def(c.filter_id)
        out.append(MatchedFilter(
            filter_id=c.filter_id,
            label=d.label if d else c.filter_id,
            source=c.source,
        ))
    return out


# ── AI extraction (reuses the shipped NL parser) ─────────────────────────────

async def _ai_clauses(instruction: str, context: dict) -> tuple[AiClauses, str]:
    from ai.nlp_router import handle_filter_intent  # lazy: avoids import cycle
    summary, filter_dict = await handle_filter_intent(instruction, context)
    return from_filter_response(filter_dict), summary


# ── Search ────────────────────────────────────────────────────────────────────

@router.post("/search", response_model=SearchResponse)
async def search_lines(
    request: SearchRequest,
    claims: dict = Depends(verify_service_or_user),
) -> SearchResponse:
    # Identity: non-service callers are pinned to their token uid.
    user_id = "inline" if request.lines is not None else \
        resolve_user_id(claims, body_user_id=request.user_id or "")

    # 1) AI Mode / Hybrid Mode — turn the instruction into clauses.
    ai = AiClauses()
    ai_summary: Optional[str] = None
    if request.ai_instruction:
        try:
            ai, ai_summary = await _ai_clauses(
                request.ai_instruction, {"userMode": request.rank_mode})
        except Exception:
            logger.exception("AI clause extraction failed — proceeding with "
                             "manual clauses only (AI never blocks search)")
            ai = AiClauses()
            ai_summary = ("AI assistance was unavailable for this search; "
                          "your manual filters were applied unchanged.")

    # 2) Merge — manual clauses are locked; AI is additive-only.
    user_rank_mode = request.rank_mode if request.rank_mode != "balanced" else None
    try:
        merged = merge(
            manual_clauses=request.clauses,
            ai_clauses=ai.clauses,
            user_rank_mode=user_rank_mode,
            ai_rank_mode=infer_rank_mode(request.ai_instruction),
        )
    except FilterValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    for um in ai.unmapped:
        merged.ai_dropped.append({"clause": um, "reason": um.get("reason", "")})

    # 3) The ENGINE is the search — nothing else touches the result set.
    lines = request.lines if request.lines is not None \
        else _load_lines(user_id, request.month)
    matches = run_query(merged.query, lines)

    # 4) Rank transparently (existing scorer: components + explanations).
    prefs = UserPreferences(user_mode=merged.rank_mode)
    inputs = [_to_summary_input(l) for l in matches]
    all_max = max((i.estimated_salary_max for i in inputs), default=0.0)
    ranked = rank_lines(inputs, prefs, all_max)[: request.limit]

    matched = _matched_filters(merged.query.clauses)
    results = [
        RankedResult(
            line_id=r.line_id,
            line_number=r.line_number,
            rank=r.rank,
            total_score=r.composite_score,
            component_scores={k: round(v, 1)
                              for k, v in r.component_scores.items()},
            matched_filters=matched,
            explanation=r.reasons or [r.explanation],
        )
        for r in ranked
    ]

    return SearchResponse(
        results=results,
        total_matched=len(matches),
        total_scanned=len(lines),
        applied=AppliedFilters(
            manual=merged.manual,
            ai=merged.ai_applied,
            dropped_ai=merged.ai_dropped,
        ),
        rank_mode=merged.rank_mode,
        ai_summary=ai_summary,
    )
