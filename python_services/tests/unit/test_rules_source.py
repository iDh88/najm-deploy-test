"""Unit tests for legality/rules_source.py — the FTL single source of truth.

Covers the behaviors the whole platform now depends on (P0-1/P0-2):
defaults, Firestore override merging, sanity clamps, enabled:false and
unknown-id handling, TTL caching + invalidation, the fail-safe boundary, and
the shared derived calculations (min-rest selection, conservative-intersection
FDP with early/WOCL reductions and the 8 h floor).

Firestore is faked at the utils.firebase.get_firestore seam (the same seam
the autouse conftest mock patches), so these tests run identically under real
pytest in CI and the offline harness.
"""
from __future__ import annotations

from unittest.mock import patch

import pytest

from legality import rules_source as rs
from legality.rules_source import (
    CANONICAL_DEFAULTS,
    FDP_ABSOLUTE_FLOOR_MINS,
    FDP_EARLY_SIGNIN_REDUCTION_MINS,
    FDP_SECTOR_TABLE_MINUTES,
    FDP_WOCL_REDUCTION_MINS,
    fdp_limit_minutes,
    get_effective_rules,
    invalidate_cache,
    min_rest_minutes,
)


# ── Firestore fakes ───────────────────────────────────────────────────────────

class _FakeDoc:
    def __init__(self, doc_id: str, data: dict):
        self.id = doc_id
        self._data = data

    def to_dict(self):
        return dict(self._data)


class _FakeCollection:
    def __init__(self, docs):
        self._docs = docs

    def stream(self):
        return iter(self._docs)


class _FakeDB:
    def __init__(self, docs):
        self._docs = docs

    def collection(self, name):
        assert name == "legalityRules"
        return _FakeCollection(self._docs)


def _with_rules_docs(docs):
    """Patch the Firestore seam so the loader sees exactly `docs`."""
    return patch("utils.firebase.get_firestore", return_value=_FakeDB(docs))


@pytest.fixture(autouse=True)
def _fresh_cache():
    """The module keeps a process-wide TTL cache — isolate every test."""
    invalidate_cache()
    yield
    invalidate_cache()


# ── Defaults & provenance ─────────────────────────────────────────────────────

class TestDefaults:
    def test_empty_collection_yields_canonical_defaults(self):
        with _with_rules_docs([]):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values == CANONICAL_DEFAULTS
        assert eff.source == "defaults"
        assert eff.overridden_fields == ()
        assert eff.version.startswith("GACA-GOM-7.5.3-TF")
        assert "(defaults)" in eff.version

    def test_canonical_values_are_the_gom_table_f_set(self):
        # The exact numbers under owner review (ODR-001) — a silent edit to
        # any of these must fail a test, not slip through.
        assert CANONICAL_DEFAULTS["min_rest_domestic_hours"] == 14.0
        assert CANONICAL_DEFAULTS["min_rest_international_hours"] == 15.0
        assert CANONICAL_DEFAULTS["min_rest_augmented_hours"] == 18.0
        assert CANONICAL_DEFAULTS["max_daily_block_hours"] == 8.0
        assert CANONICAL_DEFAULTS["max_annual_flight_hours"] == 900.0
        assert CANONICAL_DEFAULTS["max_fdp_domestic_hours"] == 12.0
        assert CANONICAL_DEFAULTS["max_fdp_international_hours"] == 13.0

    def test_minutes_helper_rounds_hours(self):
        with _with_rules_docs([]):
            eff = get_effective_rules(force_refresh=True)
        assert eff.minutes("min_rest_domestic_hours") == 840
        assert eff.minutes("min_rest_international_hours") == 900


# ── Override merging ──────────────────────────────────────────────────────────

class TestOverrides:
    def test_valid_override_is_applied_with_provenance(self):
        docs = [_FakeDoc("min_rest_domestic_hours", {"value": 16})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values["min_rest_domestic_hours"] == 16.0
        assert eff.source == "firestore-override"
        assert eff.overridden_fields == ("min_rest_domestic_hours",)
        assert "+1 admin override" in eff.version
        # untouched fields keep their canonical values
        assert eff.values["min_rest_international_hours"] == 15.0

    def test_override_equal_to_default_is_not_counted_as_override(self):
        docs = [_FakeDoc("min_rest_domestic_hours", {"value": 14.0})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert eff.source == "defaults"
        assert eff.overridden_fields == ()

    def test_disabled_doc_is_skipped(self):
        docs = [_FakeDoc("min_rest_domestic_hours",
                         {"value": 16, "enabled": False})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values["min_rest_domestic_hours"] == 14.0

    def test_unknown_rule_id_is_ignored(self):
        docs = [_FakeDoc("not_a_real_rule", {"value": 999})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert "not_a_real_rule" not in eff.values
        assert eff.values == CANONICAL_DEFAULTS

    def test_integer_fields_are_coerced_to_whole_numbers(self):
        docs = [_FakeDoc("max_sectors_short_haul", {"value": 5.9})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values["max_sectors_short_haul"] == 5.0


# ── Sanity clamps (typo guards, not regulatory judgments) ─────────────────────

class TestSanityClamps:
    @pytest.mark.parametrize("bad", [0, -3, 1000, "not-a-number", None])
    def test_out_of_bounds_or_non_numeric_rejected_default_retained(self, bad):
        docs = [_FakeDoc("min_rest_domestic_hours", {"value": bad})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values["min_rest_domestic_hours"] == 14.0
        assert eff.overridden_fields == ()

    def test_boundary_values_inside_bounds_accepted(self):
        docs = [_FakeDoc("warning_threshold_pct", {"value": 0.95})]
        with _with_rules_docs(docs):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values["warning_threshold_pct"] == 0.95


# ── Fail-safe boundary ────────────────────────────────────────────────────────

class TestFailSafe:
    def test_firestore_exception_falls_back_to_defaults_never_raises(self):
        with patch("utils.firebase.get_firestore",
                   side_effect=RuntimeError("firestore down")):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values == CANONICAL_DEFAULTS
        assert eff.source == "defaults"

    def test_stream_exception_falls_back_too(self):
        class _Boom:
            def collection(self, _):
                raise ConnectionError("boom")
        with patch("utils.firebase.get_firestore", return_value=_Boom()):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values == CANONICAL_DEFAULTS


# ── TTL cache behavior ────────────────────────────────────────────────────────

class TestCache:
    def test_second_call_within_ttl_does_not_reload(self):
        docs = [_FakeDoc("min_rest_domestic_hours", {"value": 16})]
        with _with_rules_docs(docs) as seam:
            get_effective_rules(force_refresh=True)
            first_calls = seam.call_count
            get_effective_rules()          # served from cache
            assert seam.call_count == first_calls

    def test_invalidate_cache_forces_reload(self):
        with _with_rules_docs([_FakeDoc("min_rest_domestic_hours",
                                        {"value": 16})]):
            assert get_effective_rules(
                force_refresh=True).values["min_rest_domestic_hours"] == 16.0
        invalidate_cache()
        with _with_rules_docs([]):
            eff = get_effective_rules()
        assert eff.values["min_rest_domestic_hours"] == 14.0

    def test_force_refresh_bypasses_cache(self):
        with _with_rules_docs([]):
            get_effective_rules(force_refresh=True)
        with _with_rules_docs([_FakeDoc("min_rest_domestic_hours",
                                        {"value": 17})]):
            eff = get_effective_rules(force_refresh=True)
        assert eff.values["min_rest_domestic_hours"] == 17.0


# ── Shared derived calculations ───────────────────────────────────────────────

class TestMinRestSelection:
    def test_category_selection(self):
        with _with_rules_docs([]):
            eff = get_effective_rules(force_refresh=True)
            assert min_rest_minutes(False, rules=eff) == 840          # domestic
            assert min_rest_minutes(True, rules=eff) == 900           # international
            assert min_rest_minutes(False, True, rules=eff) == 1080   # augmented
            assert min_rest_minutes(True, True, rules=eff) == 1080    # aug wins


class TestFdpIntersection:
    """ODR-002: limit = min(flat category cap, per-sector table) − reductions,
    floored at 8:00."""

    def test_domestic_flat_cap_wins_when_lower_than_table(self):
        with _with_rules_docs([]):
            # table(1)=840 vs flat dom 720 → 720
            assert fdp_limit_minutes(1) == 720

    def test_table_wins_when_lower_than_flat_cap(self):
        with _with_rules_docs([]):
            # augmented flat 840 vs table(6)=690 → 690
            assert fdp_limit_minutes(6, is_augmented=True) == 690

    def test_international_selection(self):
        with _with_rules_docs([]):
            # intl flat 780 vs table(2)=810 → 780
            assert fdp_limit_minutes(2, is_international=True) == 780

    def test_early_signin_and_wocl_reductions_stack(self):
        with _with_rules_docs([]):
            base = fdp_limit_minutes(6, is_augmented=True)          # 690
            early = fdp_limit_minutes(6, report_local_hour=5,
                                      is_augmented=True)
            both = fdp_limit_minutes(6, report_local_hour=5,
                                     wocl_penetration=True,
                                     is_augmented=True)
            assert early == base - FDP_EARLY_SIGNIN_REDUCTION_MINS
            assert both == base - FDP_EARLY_SIGNIN_REDUCTION_MINS \
                                - FDP_WOCL_REDUCTION_MINS

    def test_absolute_floor_never_undercut(self):
        with _with_rules_docs([_FakeDoc("max_fdp_domestic_hours",
                                        {"value": 8.0})]):
            eff = get_effective_rules(force_refresh=True)
            limit = fdp_limit_minutes(6, report_local_hour=4,
                                      wocl_penetration=True, rules=eff)
        assert limit == FDP_ABSOLUTE_FLOOR_MINS

    def test_sector_count_clamped_into_table_range(self):
        with _with_rules_docs([]):
            assert fdp_limit_minutes(0) == fdp_limit_minutes(1)
            assert fdp_limit_minutes(99) == fdp_limit_minutes(6)

    def test_table_is_monotonic_nonincreasing(self):
        limits = [FDP_SECTOR_TABLE_MINUTES[i] for i in range(1, 7)]
        assert limits == sorted(limits, reverse=True)


class TestMetadataContract:
    def test_every_canonical_field_has_admin_metadata(self):
        # The admin panel renders whatever the seeder writes; the seeder
        # writes RULE_METADATA — every rule must therefore have an entry.
        assert set(rs.RULE_METADATA) == set(CANONICAL_DEFAULTS)
        for meta in rs.RULE_METADATA.values():
            assert meta["description"]
            assert meta["unit"]
            assert meta["severity"] in ("blocking", "warning")
