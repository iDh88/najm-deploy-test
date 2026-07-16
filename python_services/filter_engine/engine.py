"""filter_engine/engine.py — applies a validated FilterQuery to lines.

Design (vision: "fast, cache-friendly, hundreds of filters, no degradation"):
  * Clauses are compiled ONCE per request into closures; evaluation is a
    single pass over the lines with short-circuit AND.
  * Extractors are memoised per line within a request, so ten clauses over
    leg-derived values parse the legs once, not ten times.
  * The engine is pure and framework-free: dict lines in, matches out —
    independently testable and independent of the AI, exactly as mandated.

Semantics reference (see registry.FilterKind):
  RANGE over a scalar  → min ≤ v ≤ max.
  RANGE over a list    → EVERY item within range ("minimum layover hours"
                         means no layover shorter than that). Empty list ⇒
                         vacuously true; a missing scalar (None) ⇒ False —
                         a line without the data cannot claim to satisfy it.
  SET_ANY  → line's set intersects requested items.
  SET_ALL  → requested ⊆ line's set.
  SET_NONE → intersection empty.
  BOOL     → extracted property == requested value.
  ENUM     → extracted label == requested value.
"""
from __future__ import annotations

from typing import Any, Callable

from .registry import FilterDef, FilterKind, get
from .schema import FilterClause, FilterQuery


Predicate = Callable[[dict, dict], bool]   # (line, memo) -> bool


def _extract(d: FilterDef, line: dict, memo: dict) -> Any:
    if d.id not in memo:
        memo[d.id] = d.extract(line) if d.extract else None
    return memo[d.id]


def _compile_clause(clause: FilterClause) -> Predicate:
    d = get(clause.filter_id)
    assert d is not None and d.extract is not None  # validated upstream
    v = clause.value

    if d.kind is FilterKind.RANGE:
        lo = v.get("min")
        hi = v.get("max")

        def in_range(x: float) -> bool:
            if lo is not None and x < lo:
                return False
            if hi is not None and x > hi:
                return False
            return True

        def pred(line: dict, memo: dict) -> bool:
            got = _extract(d, line, memo)
            if got is None:
                return False
            if isinstance(got, (list, tuple, set)):
                return all(in_range(float(x)) for x in got)
            return in_range(float(got))
        return pred

    if d.kind in (FilterKind.SET_ANY, FilterKind.SET_ALL, FilterKind.SET_NONE):
        wanted = {str(x).upper() if not d.enum_values else str(x) for x in v}

        def pred(line: dict, memo: dict) -> bool:
            got = _extract(d, line, memo) or set()
            got = set(got)
            if d.kind is FilterKind.SET_ANY:
                return bool(got & wanted)
            if d.kind is FilterKind.SET_ALL:
                return wanted <= got
            return not (got & wanted)
        return pred

    if d.kind is FilterKind.BOOL:
        def pred(line: dict, memo: dict) -> bool:
            return bool(_extract(d, line, memo)) is v
        return pred

    # ENUM
    def pred(line: dict, memo: dict) -> bool:
        return _extract(d, line, memo) == v
    return pred


def run_query(query: FilterQuery, lines: list[dict]) -> list[dict]:
    """Return the lines matching ALL clauses. `query` must already be
    validated (schema.FilterQuery.validate_all). Each returned line is the
    original dict, untouched."""
    query.validate_all()
    compiled = [(_compile_clause(c), c) for c in query.clauses]

    matches: list[dict] = []
    for line in lines:
        memo: dict = {}
        if all(pred(line, memo) for pred, _ in compiled):
            matches.append(line)
    return matches
