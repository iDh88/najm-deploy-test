"""filter_engine/schema.py — the wire contract, validated against the registry.

Every clause — whether a human tapped it in Manual Mode or the AI generated
it — must validate here before the engine will run it. This is where the
vision's Golden Rule is enforced by construction: there is no AI-shaped side
door; the AI's output is just another FilterQuery.
"""
from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field

from .registry import FilterDef, FilterKind, FilterStatus, REGISTRY, get


class FilterValidationError(ValueError):
    """Raised with a message precise enough for a UI toast or an AI retry."""


# ── Clause ────────────────────────────────────────────────────────────────────

class FilterClause(BaseModel):
    filter_id: str
    # RANGE → {"min"?: num, "max"?: num} · SET_* → [items] · BOOL → bool ·
    # ENUM → str. Validated by validate_clause() against the registry def.
    value: Any = None
    # Provenance — who asked for this clause. "manual" clauses are LOCKED in
    # hybrid mode: the AI can never remove or alter them (see hybrid.py).
    source: str = "manual"          # "manual" | "ai"


def validate_clause(clause: FilterClause) -> FilterDef:
    d = get(clause.filter_id)
    if d is None:
        raise FilterValidationError(
            f"unknown filter '{clause.filter_id}'; valid ids: "
            f"{', '.join(sorted(REGISTRY))}")
    if d.status is not FilterStatus.ACTIVE:
        raise FilterValidationError(
            f"filter '{d.id}' is not available yet ({d.note or 'requires data'})")

    v = clause.value
    if d.kind is FilterKind.RANGE:
        if not isinstance(v, dict) or not ({"min", "max"} & set(v)):
            raise FilterValidationError(
                f"'{d.id}' expects {{\"min\"?: number, \"max\"?: number}}")
        for key in ("min", "max"):
            if key in v and not isinstance(v[key], (int, float)):
                raise FilterValidationError(f"'{d.id}'.{key} must be a number")
        if "min" in v and "max" in v and v["min"] > v["max"]:
            raise FilterValidationError(f"'{d.id}': min > max")
    elif d.kind in (FilterKind.SET_ANY, FilterKind.SET_ALL, FilterKind.SET_NONE):
        if not isinstance(v, list) or not v \
                or not all(isinstance(x, str) and x.strip() for x in v):
            raise FilterValidationError(
                f"'{d.id}' expects a non-empty list of strings")
        if d.enum_values:
            bad = [x for x in v if x not in d.enum_values]
            if bad:
                raise FilterValidationError(
                    f"'{d.id}': invalid {bad}; allowed: {list(d.enum_values)}")
    elif d.kind is FilterKind.BOOL:
        if not isinstance(v, bool):
            raise FilterValidationError(f"'{d.id}' expects true or false")
    elif d.kind is FilterKind.ENUM:
        if v not in d.enum_values:
            raise FilterValidationError(
                f"'{d.id}' expects one of {list(d.enum_values)}")
    return d


# ── Query ─────────────────────────────────────────────────────────────────────

class FilterQuery(BaseModel):
    """AND of clauses. At most one clause per filter_id — a second clause on
    the same id is a conflict the caller must resolve (hybrid.py resolves it
    by manual-wins)."""
    clauses: list[FilterClause] = []

    def validate_all(self) -> None:
        seen: set[str] = set()
        for c in self.clauses:
            validate_clause(c)
            if c.filter_id in seen:
                raise FilterValidationError(
                    f"duplicate clause for '{c.filter_id}'")
            seen.add(c.filter_id)


# ── Search request / response ────────────────────────────────────────────────

class SearchRequest(BaseModel):
    """Manual Mode: clauses only. Hybrid Mode: clauses (locked) +
    ai_instruction. AI Mode: ai_instruction only (empty clauses)."""
    # Service callers (Cloud Functions) may act for a user; end-user tokens
    # are pinned to their own uid regardless of this value (resolve_user_id).
    user_id: Optional[str] = None
    month: Optional[str] = None            # e.g. "JUN-2026"; default: all
    clauses: list[FilterClause] = []       # manual — LOCKED in hybrid
    ai_instruction: Optional[str] = Field(
        default=None, max_length=500,
        description="Natural-language request; the AI converts it into "
                    "additional clauses and/or a ranking mode — it can never "
                    "override a manual clause.")
    rank_mode: str = "balanced"            # money | rest | balanced
    limit: int = Field(default=50, ge=1, le=200)
    # Service/test callers may supply lines inline instead of Firestore.
    lines: Optional[list[dict]] = None


class MatchedFilter(BaseModel):
    filter_id: str
    label: str
    source: str                            # manual | ai


class RankedResult(BaseModel):
    line_id: str
    line_number: str
    rank: int
    total_score: float
    component_scores: dict[str, float]     # transparent ranking breakdown
    matched_filters: list[MatchedFilter]   # why it was IN the result set
    explanation: list[str]                 # human "Recommended because ✓ …"


class AppliedFilters(BaseModel):
    manual: list[FilterClause] = []
    ai: list[FilterClause] = []
    dropped_ai: list[dict] = []            # {clause, reason} — full honesty


class SearchResponse(BaseModel):
    results: list[RankedResult]
    total_matched: int
    total_scanned: int
    applied: AppliedFilters
    rank_mode: str
    ai_summary: Optional[str] = None       # AI's own explanation of its clauses
    engine: str = "filter_engine.v1"       # provenance — the single source
