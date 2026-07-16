"""filter_engine/hybrid.py — Hybrid-Mode merge semantics.

VISION RULE, enforced here in one place:
    "The AI should respect every manual filter. It may only optimize within
     the allowed search space. Manual filters always have priority."

Concretely:
  * Manual clauses are LOCKED — the merged query contains every one of them,
    verbatim.
  * AI clauses may only ADD constraints. An AI clause that targets a
    filter_id already locked by the user is DROPPED and reported (never
    merged, never averaged, never "smartly" reconciled — the user said what
    they said).
  * AI clauses that fail registry validation are DROPPED and reported with
    the exact validation message, so the model (and the user) can see why.
  * The AI can also propose a rank_mode; it applies only when the user did
    not explicitly choose one.

The return value is fully transparent: the caller can show the user exactly
which AI clauses ran and which were rejected, and why.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .schema import (
    FilterClause,
    FilterQuery,
    FilterValidationError,
    validate_clause,
)


@dataclass
class MergeResult:
    query: FilterQuery
    manual: list[FilterClause] = field(default_factory=list)
    ai_applied: list[FilterClause] = field(default_factory=list)
    ai_dropped: list[dict] = field(default_factory=list)   # {clause, reason}
    rank_mode: str = "balanced"


def merge(manual_clauses: list[FilterClause],
          ai_clauses: list[FilterClause],
          user_rank_mode: str | None,
          ai_rank_mode: str | None) -> MergeResult:
    locked_ids = set()
    manual: list[FilterClause] = []
    for c in manual_clauses:
        c = c.model_copy(update={"source": "manual"})
        validate_clause(c)                     # user input validates too
        if c.filter_id in locked_ids:
            raise FilterValidationError(
                f"duplicate manual clause for '{c.filter_id}'")
        locked_ids.add(c.filter_id)
        manual.append(c)

    applied: list[FilterClause] = []
    dropped: list[dict] = []
    for c in ai_clauses:
        c = c.model_copy(update={"source": "ai"})
        if c.filter_id in locked_ids:
            dropped.append({
                "clause": c.model_dump(),
                "reason": f"'{c.filter_id}' is locked by a manual filter — "
                          "manual filters always have priority",
            })
            continue
        try:
            validate_clause(c)
        except FilterValidationError as exc:
            dropped.append({"clause": c.model_dump(), "reason": str(exc)})
            continue
        if any(a.filter_id == c.filter_id for a in applied):
            dropped.append({"clause": c.model_dump(),
                            "reason": f"duplicate AI clause for '{c.filter_id}'"})
            continue
        applied.append(c)

    rank_mode = user_rank_mode or ai_rank_mode or "balanced"
    return MergeResult(
        query=FilterQuery(clauses=manual + applied),
        manual=manual,
        ai_applied=applied,
        ai_dropped=dropped,
        rank_mode=rank_mode,
    )
