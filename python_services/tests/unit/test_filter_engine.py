"""filter_engine tests — the vision's contract, executable.

Locks four things:
  1. Registry integrity — ids stable/unique, ACTIVE defs evaluate on real
     line shapes, catalog serializes.
  2. Predicate semantics — a truth table per FilterKind, including the
     "RANGE over a list means EVERY item" reading and derived extractors
     (weekend, red-eye, haul, consecutive days).
  3. THE GOLDEN RULE — hybrid merge: manual clauses are immovable, AI is
     additive-only, every rejection is reported with a reason, invalid AI
     output cannot reach the engine.
  4. End-to-end search — Manual and Hybrid modes over fixture lines with
     transparent ranking (component scores + reasons) in the response.
"""
from __future__ import annotations

from datetime import datetime, timedelta

import pytest

from filter_engine import registry as reg
from filter_engine.ai_bridge import from_filter_response, infer_rank_mode
from filter_engine.engine import run_query
from filter_engine.hybrid import merge
from filter_engine.registry import FilterStatus, REGISTRY, active_ids, catalog
from filter_engine.schema import (
    FilterClause,
    FilterQuery,
    FilterValidationError,
    SearchRequest,
    validate_clause,
)


# ── Fixture lines (the real flightLines document shape) ──────────────────────

def _leg(origin, dest, dep_lt_hour, block, *, layover=False, layover_h=0.0,
         legal="legal", rest_after=15.0, aircraft="B787", day=10,
         per_diem=0.0, duty_h=None):
    dep = datetime(2026, 6, day, dep_lt_hour, 0)
    duty_h = duty_h if duty_h is not None else block + 2
    return {
        "flightNumber": f"SV{origin}{dest}",
        "origin": origin, "destination": dest,
        "departureLT": dep.isoformat(),
        "arrivalLT": (dep + timedelta(hours=block)).isoformat(),
        "dutyStart": (dep - timedelta(hours=1)).isoformat(),
        "dutyEnd": (dep + timedelta(hours=duty_h - 1)).isoformat(),
        "releaseTime": (dep + timedelta(hours=duty_h - 0.5)).isoformat(),
        "blockHours": block, "fdpHours": duty_h,
        "aircraftType": aircraft, "layover": layover,
        "layoverHours": layover_h, "perDiem": per_diem,
        "legalityStatus": legal, "restAfterHours": rest_after,
        "restBeforeHours": 15.0,
    }


def _line(line_id, *, destinations, days_off, legs, salary=(15000, 18000),
          intl=0, dom=0, duty_days=12, rank="FA",
          rest_quality=70.0, composite=70.0):
    return {
        "id": line_id, "lineNumber": line_id, "month": "JUN-2026",
        "rank": rank, "isActive": True,
        "destinations": destinations, "daysOff": days_off,
        "summary": {
            "totalLegs": len(legs),
            "totalBlockHours": sum(l["blockHours"] for l in legs),
            "totalDutyHours": sum(l["fdpHours"] for l in legs),
            "totalDutyDays": duty_days,
            "internationalLegs": intl, "domesticLegs": dom,
            "layoverCount": sum(1 for l in legs if l["layover"]),
            "estimatedSalaryMin": salary[0], "estimatedSalaryMax": salary[1],
            "salaryScore": 60.0, "restQualityScore": rest_quality,
            "compositeScore": composite,
        },
        "legs": legs,
    }


LONDON = _line(
    "L100",
    destinations=["LHR", "JED"], days_off=[5, 6, 2],   # Fri+Sat off
    legs=[_leg("JED", "LHR", 9, 6.5, layover=True, layover_h=26,
               per_diem=800, day=10),
          _leg("LHR", "JED", 13, 6.5, rest_after=30, day=12)],
    salary=(21000, 24000), intl=2, dom=0, duty_days=10, rest_quality=82,
    composite=85)

DOMESTIC = _line(
    "D200",
    destinations=["RUH", "DMM"], days_off=[1, 3],
    legs=[_leg("JED", "RUH", 23, 1.5, day=10),                 # red-eye
          _leg("RUH", "JED", 6, 1.5, rest_after=12, day=11),
          _leg("JED", "DMM", 7, 1.8, day=12),
          _leg("DMM", "JED", 11, 1.8, rest_after=13, day=13)],
    salary=(12000, 14000), intl=0, dom=4, duty_days=16, rest_quality=48,
    composite=52)

MIXED = _line(
    "M300",
    destinations=["BOM", "JED", "RUH"], days_off=[5, 6, 0, 1],
    legs=[_leg("JED", "BOM", 10, 4.0, layover=True, layover_h=14,
               legal="warning", per_diem=300, day=15),
          _leg("BOM", "JED", 15, 4.2, rest_after=14.5, day=16),
          _leg("JED", "RUH", 8, 1.5, day=18)],
    salary=(16000, 20000), intl=2, dom=1, duty_days=13, rest_quality=61,
    composite=66)

LINES = [LONDON, DOMESTIC, MIXED]


def _q(*clauses) -> FilterQuery:
    return FilterQuery(clauses=[FilterClause(**c) for c in clauses])


def _ids(matches):
    return sorted(m["id"] for m in matches)


# ── 1. Registry integrity ─────────────────────────────────────────────────────

class TestRegistryIntegrity:
    def test_ids_unique_and_categorized(self):
        assert len(REGISTRY) == len({d.id for d in REGISTRY.values()})
        cats = {d.category for d in REGISTRY.values()}
        assert {"schedule", "layovers", "destinations", "flights",
                "financial", "crew", "legal", "lifestyle"} <= cats

    def test_every_active_filter_evaluates_on_a_real_line(self):
        for fid in active_ids():
            d = REGISTRY[fid]
            assert d.extract is not None, fid
            d.extract(LONDON)   # must not raise

    def test_requires_field_entries_are_honest(self):
        pending = [d for d in REGISTRY.values()
                   if d.status is FilterStatus.REQUIRES_FIELD]
        assert pending, "vision filters without data must be visible"
        for d in pending:
            assert d.note, f"{d.id} needs a note naming the missing data"
            assert d.extract is None

    def test_catalog_serializes_every_entry(self):
        cat = catalog()
        assert len(cat) == len(REGISTRY)
        assert all({"id", "category", "kind", "status"} <= set(e) for e in cat)

    def test_active_breadth_covers_the_vision_categories(self):
        by_cat: dict[str, int] = {}
        for fid in active_ids():
            by_cat[REGISTRY[fid].category] = by_cat.get(
                REGISTRY[fid].category, 0) + 1
        for cat in ("schedule", "layovers", "destinations", "flights",
                    "financial", "legal"):
            assert by_cat.get(cat, 0) >= 2, f"category '{cat}' too thin"
        assert len(active_ids()) >= 28


# ── 2. Predicate semantics ────────────────────────────────────────────────────

class TestPredicates:
    def test_range_scalar(self):
        assert _ids(run_query(_q({"filter_id": "days_off_count",
                                  "value": {"min": 3}}), LINES)) \
            == ["L100", "M300"]
        assert _ids(run_query(_q({"filter_id": "salary_min",
                                  "value": {"min": 20000}}), LINES)) == ["L100"]

    def test_range_over_list_means_every_item(self):
        # DOMESTIC has 12h & 13h rests → fails min 14; MIXED has a 14.5 → ok
        got = run_query(_q({"filter_id": "rest_interval_each",
                            "value": {"min": 14}}), LINES)
        assert _ids(got) == ["L100", "M300"]

    def test_layover_hours_each_min(self):
        # MIXED's layover is 14h → fails min 24; DOMESTIC has none (vacuous ✓)
        got = run_query(_q({"filter_id": "layover_hours_each",
                            "value": {"min": 24}}), LINES)
        assert _ids(got) == ["D200", "L100"]

    def test_set_any_all_none(self):
        assert _ids(run_query(_q({"filter_id": "destinations_any",
                                  "value": ["LHR", "CDG"]}), LINES)) == ["L100"]
        assert _ids(run_query(_q({"filter_id": "destinations_all",
                                  "value": ["BOM", "RUH"]}), LINES)) == ["M300"]
        assert _ids(run_query(_q({"filter_id": "destinations_none",
                                  "value": ["BOM"]}), LINES)) \
            == ["D200", "L100"]

    def test_bool_and_enum(self):
        assert _ids(run_query(_q({"filter_id": "red_eye", "value": False}),
                              LINES)) == ["L100", "M300"]
        assert _ids(run_query(_q({"filter_id": "leg_scope",
                                  "value": "mixed"}), LINES)) == ["M300"]
        assert _ids(run_query(_q({"filter_id": "legal_only", "value": True}),
                              LINES)) == ["D200", "L100"]

    def test_weekend_and_weekday_derivations(self):
        assert _ids(run_query(_q({"filter_id": "weekend_off", "value": True}),
                              LINES)) == ["L100", "M300"]
        assert _ids(run_query(_q({"filter_id": "off_weekdays_all",
                                  "value": ["2"]}), LINES)) == ["L100"]

    def test_haul_and_period_derivations(self):
        assert _ids(run_query(_q({"filter_id": "haul_types_any",
                                  "value": ["long"]}), LINES)) == ["L100"]
        assert _ids(run_query(_q({"filter_id": "departure_periods_any",
                                  "value": ["night"]}), LINES)) == ["D200"]

    def test_consecutive_duty_days(self):
        got = run_query(_q({"filter_id": "max_consecutive_duty_days",
                            "value": {"max": 3}}), LINES)
        assert "D200" not in _ids(got)          # 4 consecutive duty days

    def test_and_composition_and_empty_query(self):
        got = run_query(_q(
            {"filter_id": "weekend_off", "value": True},
            {"filter_id": "salary_min", "value": {"min": 20000}},
        ), LINES)
        assert _ids(got) == ["L100"]
        assert _ids(run_query(FilterQuery(), LINES)) == ["D200", "L100", "M300"]


# ── 3. Validation + the Golden Rule ──────────────────────────────────────────

class TestValidationAndGoldenRule:
    def test_unknown_filter_rejected_with_valid_ids_listed(self):
        with pytest.raises(FilterValidationError) as e:
            validate_clause(FilterClause(filter_id="nope", value=True))
        assert "destinations_any" in str(e.value)

    def test_requires_field_filter_cannot_run(self):
        with pytest.raises(FilterValidationError):
            validate_clause(FilterClause(filter_id="rr_days",
                                         value={"min": 1}))

    @pytest.mark.parametrize("fid,bad", [
        ("salary_min", 20000),                 # RANGE needs a dict
        ("salary_min", {"min": "high"}),       # numeric only
        ("salary_min", {"min": 5, "max": 1}),  # min > max
        ("destinations_any", []),              # non-empty list
        ("weekend_off", "yes"),                # bool only
        ("leg_scope", "space"),                # enum member only
        ("off_weekdays_all", ["7"]),           # weekday enum 0..6
    ])
    def test_malformed_values_rejected(self, fid, bad):
        with pytest.raises(FilterValidationError):
            validate_clause(FilterClause(filter_id=fid, value=bad))

    def test_manual_clause_is_locked_against_ai(self):
        m = merge(
            manual_clauses=[FilterClause(filter_id="salary_min",
                                         value={"min": 20000})],
            ai_clauses=[FilterClause(filter_id="salary_min",
                                     value={"min": 5000}),
                        FilterClause(filter_id="weekend_off", value=True)],
            user_rank_mode=None, ai_rank_mode=None,
        )
        applied_ids = [c.filter_id for c in m.query.clauses]
        assert applied_ids == ["salary_min", "weekend_off"]
        locked = next(c for c in m.query.clauses
                      if c.filter_id == "salary_min")
        assert locked.value == {"min": 20000} and locked.source == "manual"
        assert m.ai_dropped and "priority" in m.ai_dropped[0]["reason"]

    def test_invalid_ai_clause_dropped_with_reason_not_fatal(self):
        m = merge(
            manual_clauses=[],
            ai_clauses=[FilterClause(filter_id="fatigue_score",
                                     value={"min": 50}),      # requires_field
                        FilterClause(filter_id="red_eye", value=False)],
            user_rank_mode=None, ai_rank_mode=None,
        )
        assert [c.filter_id for c in m.ai_applied] == ["red_eye"]
        assert "not available" in m.ai_dropped[0]["reason"]

    def test_user_rank_mode_beats_ai_suggestion(self):
        m = merge([], [], user_rank_mode="money", ai_rank_mode="rest")
        assert m.rank_mode == "money"
        m2 = merge([], [], user_rank_mode=None, ai_rank_mode="rest")
        assert m2.rank_mode == "rest"


# ── AI bridge mapping ─────────────────────────────────────────────────────────

class TestAiBridge:
    def test_filter_response_maps_field_by_field(self):
        out = from_filter_response({
            "destinations": ["lhr"], "min_salary": 20000,
            "no_days_of_week": [5], "requires_layover": True,
            "min_layover_hours": 24, "leg_types": ["international"],
            "max_legs": 4,
        })
        got = {c.filter_id: c.value for c in out.clauses}
        assert got == {
            "destinations_any": ["LHR"],
            "salary_min": {"min": 20000.0},
            "off_weekdays_all": ["5"],
            "has_layover": True,
            "layover_hours_each": {"min": 24.0},
            "leg_scope": "international",
            "legs_count": {"max": 4.0},
        }
        assert all(c.source == "ai" for c in out.clauses)
        for c in out.clauses:
            validate_clause(c)   # everything the bridge emits must validate

    def test_ambiguous_leg_types_reported_not_guessed(self):
        out = from_filter_response({"leg_types": ["domestic", "international"]})
        assert not out.clauses
        assert out.unmapped and out.unmapped[0]["field"] == "leg_types"

    def test_rank_mode_inference(self):
        assert infer_rank_mode("optimize for lowest fatigue") == "rest"
        assert infer_rank_mode("maximum income please") == "money"
        assert infer_rank_mode("أريد أعلى راتب") == "money"
        assert infer_rank_mode("nice schedules") is None


# ── 4. End-to-end search (router path, inline lines) ─────────────────────────

class TestSearchEndToEnd:
    def _search(self, **kw):
        from filter_engine.router import search_lines
        import pytest as _p
        req = SearchRequest(lines=LINES, **kw)
        return _p.run_async(search_lines(req, claims={"service": True}))

    def test_manual_mode_full_transparency(self):
        resp = self._search(
            clauses=[FilterClause(filter_id="weekend_off", value=True)],
            rank_mode="money")
        assert resp.total_scanned == 3 and resp.total_matched == 2
        assert [r.line_id for r in resp.results] == ["L100", "M300"]
        top = resp.results[0]
        assert top.rank == 1 and top.total_score > 0
        assert set(top.component_scores) >= {"salary", "rest_quality"}
        assert top.explanation and all(isinstance(x, str)
                                       for x in top.explanation)
        assert top.matched_filters[0].filter_id == "weekend_off"
        assert resp.applied.manual and not resp.applied.ai
        assert resp.engine == "filter_engine.v1"

    def test_rank_mode_changes_the_weighted_score(self):
        money = self._search(clauses=[], rank_mode="money")
        rest = self._search(clauses=[], rank_mode="rest")
        assert money.rank_mode == "money" and rest.rank_mode == "rest"
        # Component scores are mode-independent by design; the MODE lives in
        # the weighting. For the same line, the weighted total must differ
        # between a salary-weighted and a rest-weighted ranking.
        score = {m.line_id: m.total_score for m in money.results}
        for r in rest.results:
            if r.line_id == "D200":     # weak earner, weak rest — any mode
                continue
            assert score[r.line_id] != r.total_score, r.line_id

    def test_invalid_manual_clause_is_422_shaped(self):
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as e:
            self._search(
                clauses=[FilterClause(filter_id="ghost", value=True)])
        assert e.value.status_code == 422

    def test_limit_respected(self):
        resp = self._search(clauses=[], limit=1)
        assert len(resp.results) == 1 and resp.total_matched == 3
