"""filter_engine/ai_bridge.py — AI Mode's only path into the engine.

The LLM extraction that already ships (ai/nlp_router.handle_filter_intent →
FilterResponse) stays exactly as is — it's tuned and tested. This module
translates its output DETERMINISTICALLY into registry clauses. Anything the
model asked for that the registry can't express is returned in `unmapped`
with a reason and shown to the user; it is never silently absorbed and never
allowed to touch the result set outside the engine.

Golden rule at this seam: the AI produces FilterClause values like anyone
else; validation and locking happen downstream in schema.py / hybrid.py.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

from .schema import FilterClause


@dataclass
class AiClauses:
    clauses: list[FilterClause] = field(default_factory=list)
    unmapped: list[dict] = field(default_factory=list)   # {field, value, reason}
    rank_mode: str | None = None


def _clause(fid: str, value: Any) -> FilterClause:
    return FilterClause(filter_id=fid, value=value, source="ai")


def from_filter_response(fr: dict) -> AiClauses:
    """Map ai.nlp_router.FilterResponse (already exclude_none-dumped) into
    registry clauses. Field-by-field, no cleverness."""
    out = AiClauses()
    f = dict(fr or {})

    if f.get("destinations"):
        out.clauses.append(_clause(
            "destinations_any", [str(x).upper() for x in f["destinations"]]))
    if f.get("origins"):
        out.clauses.append(_clause(
            "origins_any", [str(x).upper() for x in f["origins"]]))
    if f.get("no_days_of_week"):
        out.clauses.append(_clause(
            "off_weekdays_all", [str(int(d)) for d in f["no_days_of_week"]]))
    if f.get("max_duty_hours") is not None:
        out.clauses.append(_clause(
            "duty_duration_each", {"max": float(f["max_duty_hours"])}))
    if f.get("min_rest_hours") is not None:
        out.clauses.append(_clause(
            "rest_interval_each", {"min": float(f["min_rest_hours"])}))
    if f.get("min_layover_hours") is not None:
        out.clauses.append(_clause(
            "layover_hours_each", {"min": float(f["min_layover_hours"])}))
    if f.get("requires_layover") is not None:
        out.clauses.append(_clause("has_layover", bool(f["requires_layover"])))
    if f.get("max_legs") is not None:
        out.clauses.append(_clause("legs_count", {"max": float(f["max_legs"])}))
    if f.get("min_salary") is not None:
        out.clauses.append(_clause("salary_min", {"min": float(f["min_salary"])}))
    if f.get("max_salary") is not None:
        out.clauses.append(_clause("salary_max", {"max": float(f["max_salary"])}))

    leg_types = [str(t).lower() for t in (f.get("leg_types") or [])]
    if len(leg_types) == 1 and leg_types[0] in ("domestic", "international"):
        out.clauses.append(_clause("leg_scope", leg_types[0]))
    elif len(leg_types) > 1:
        out.unmapped.append({
            "field": "leg_types", "value": leg_types,
            "reason": "both leg types requested — no scope constraint applied "
                      "(use leg_scope=mixed to require both in one line)",
        })

    return out


_RANK_MODE_PATTERNS: list[tuple[str, str]] = [
    (r"fatigue|rest|tired|sleep|راحة|إرهاق|تعب", "rest"),
    (r"salary|income|money|pay|earn|راتب|دخل|فلوس|مال", "money"),
]


def infer_rank_mode(text: str | None) -> str | None:
    """Cheap, transparent keyword inference for 'optimize for …' phrasing.
    Only a DEFAULT suggestion — an explicit user rank_mode always wins
    (hybrid.merge), and the response discloses which mode ran."""
    if not text:
        return None
    low = text.lower()
    for pattern, mode in _RANK_MODE_PATTERNS:
        if re.search(pattern, low):
            return mode
    return None
