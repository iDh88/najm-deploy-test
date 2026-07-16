"""P0-1 REGRESSION LOCK — all engines must agree on every FTL threshold.

The original release-blocking defect: three modules carried three different
rest minimums (14/15 h vs 10/11 h vs 10/11 h), so the same pairing was ruled
LEGAL by one engine and ILLEGAL by another. This suite pins the fix: the
/v1/legality engine, the rest_engine profiles, the intelligence pipeline's
checker, and the AI grounding block must all resolve to the SAME values —
including after an admin override — or these tests fail.

If a test here fails, do NOT adjust the assertion to match an engine; the
engines are wrong by definition. Fix the divergence at its source
(legality/rules_source.py consumers).
"""
from __future__ import annotations

from unittest.mock import patch

import pytest

from legality.rules_source import (
    get_effective_rules,
    invalidate_cache,
    min_rest_minutes,
    fdp_limit_minutes,
)
from legality.engine import FTLRules
from rest_engine.rules import CrewType, get_profile
from intelligence.utils.legality_checker import (
    BlockLimits,
    FDPLimits,
    RestLimits,
)
from ai.nlp_router import _ftl_grounding_block


# ── Firestore fakes (same seam as test_rules_source) ─────────────────────────

class _FakeDoc:
    def __init__(self, doc_id, data):
        self.id, self._data = doc_id, data

    def to_dict(self):
        return dict(self._data)


class _FakeDB:
    def __init__(self, docs):
        self._docs = docs

    def collection(self, name):
        docs = self._docs

        class _C:
            def stream(self):
                return iter(docs)
        return _C()


def _with_rules_docs(docs):
    return patch("utils.firebase.get_firestore", return_value=_FakeDB(docs))


@pytest.fixture(autouse=True)
def _fresh_cache():
    invalidate_cache()
    yield
    invalidate_cache()


# ── Rest minimums: four surfaces, one number ─────────────────────────────────

class TestRestMinimumAgreement:
    @pytest.mark.parametrize("is_international,is_augmented", [
        (False, False), (True, False), (False, True), (True, True),
    ])
    def test_all_surfaces_agree_on_defaults(self, is_international,
                                            is_augmented):
        with _with_rules_docs([]):
            canonical = min_rest_minutes(is_international, is_augmented)

            # Surface 1 — /v1/legality engine rules
            ftl = FTLRules.effective()
            if is_augmented:
                engine_mins = round(ftl.min_rest_augmented_hours * 60)
            elif is_international:
                engine_mins = round(ftl.min_rest_international_hours * 60)
            else:
                engine_mins = round(ftl.min_rest_domestic_hours * 60)

            # Surface 2 — rest_engine crew profiles (every crew type)
            profile_mins = {
                ct: get_profile(ct).min_rest_for(is_international, is_augmented)
                for ct in (CrewType.CABIN_STANDARD, CrewType.CABIN_LONG_HAUL,
                           CrewType.COCKPIT, CrewType.AUGMENTED)
            }

            # Surface 3 — intelligence pipeline checker (no augmented arg in
            # its legacy signature; only compare the shared categories)
            intel_mins = RestLimits.get_minimum(is_international)

        assert engine_mins == canonical
        for ct, mins in profile_mins.items():
            assert mins == canonical, f"profile {ct} diverged"
        if not is_augmented:
            assert intel_mins == canonical

    def test_the_original_p0_bug_cannot_recur(self):
        """The exact pre-fix disagreement: rest_engine said 600/660 while
        legality said 840/900. Assert the uncited values are gone."""
        with _with_rules_docs([]):
            assert get_profile(CrewType.CABIN_STANDARD).min_rest_for(False) != 600
            assert get_profile(CrewType.CABIN_STANDARD).min_rest_for(True) != 660
            assert RestLimits.get_minimum(False) != 600
            assert RestLimits.get_minimum(True) != 660


# ── FDP limits ────────────────────────────────────────────────────────────────

class TestFdpAgreement:
    @pytest.mark.parametrize("sectors", [1, 2, 3, 4, 5, 6])
    @pytest.mark.parametrize("is_international", [False, True])
    def test_intelligence_checker_matches_canonical(self, sectors,
                                                    is_international):
        with _with_rules_docs([]):
            assert FDPLimits.get_limit(
                sectors, report_hour=8,
                is_international=is_international,
            ) == fdp_limit_minutes(sectors, is_international=is_international)

    @pytest.mark.parametrize("sectors", [1, 2, 3, 4, 5, 6])
    def test_profiles_never_more_permissive_than_canonical(self, sectors):
        with _with_rules_docs([]):
            canonical = fdp_limit_minutes(sectors)
            for ct in (CrewType.CABIN_STANDARD, CrewType.CABIN_LONG_HAUL,
                       CrewType.COCKPIT, CrewType.AUGMENTED):
                assert get_profile(ct).fdp_limit_for(sectors) <= canonical

    def test_cabin_standard_equals_canonical_domestic(self):
        # Cabin profiles share the canonical sector table, so under the
        # intersection they resolve to exactly the canonical limit.
        with _with_rules_docs([]):
            for sectors in range(1, 7):
                assert get_profile(CrewType.CABIN_STANDARD).fdp_limit_for(
                    sectors) == fdp_limit_minutes(sectors)


# ── Block caps ────────────────────────────────────────────────────────────────

class TestBlockCapAgreement:
    def test_daily_monthly_annual_agree(self):
        with _with_rules_docs([]):
            eff = get_effective_rules(force_refresh=True)
            profile = get_profile(CrewType.CABIN_STANDARD)
            assert BlockLimits.MAX_DAILY_BLOCK_MINS \
                == profile.max_daily_block_mins \
                == eff.minutes("max_daily_block_hours") == 480
            assert BlockLimits.MAX_MONTHLY_BLOCK_HRS \
                == profile.max_monthly_block_hrs \
                == int(eff.get("max_28day_flight_hours")) == 100
            assert BlockLimits.MAX_ANNUAL_BLOCK_HRS \
                == profile.max_annual_block_hrs \
                == int(eff.get("max_annual_flight_hours")) == 900

    def test_uncited_1000h_annual_cap_is_gone(self):
        with _with_rules_docs([]):
            assert BlockLimits.MAX_ANNUAL_BLOCK_HRS != 1000
            assert get_profile(CrewType.CABIN_STANDARD).max_annual_block_hrs != 1000


# ── Admin override propagates to EVERY surface ───────────────────────────────

class TestOverridePropagation:
    def test_min_rest_override_reaches_all_engines_and_grounding(self):
        docs = [_FakeDoc("min_rest_domestic_hours", {"value": 16})]
        with _with_rules_docs(docs):
            invalidate_cache()
            assert min_rest_minutes(False) == 960
            assert round(FTLRules.effective().min_rest_domestic_hours * 60) == 960
            assert get_profile(CrewType.CABIN_STANDARD).min_rest_for(False) == 960
            assert RestLimits.get_minimum(False) == 960
            grounding = _ftl_grounding_block()
            assert "16.0h domestic" in grounding
            assert "+1 admin override" in grounding

    def test_block_override_reaches_live_facade(self):
        docs = [_FakeDoc("max_daily_block_hours", {"value": 7.5})]
        with _with_rules_docs(docs):
            invalidate_cache()
            assert BlockLimits.MAX_DAILY_BLOCK_MINS == 450
            assert get_profile(CrewType.CABIN_STANDARD).max_daily_block_mins == 450


# ── AI grounding mirrors the effective values ─────────────────────────────────

class TestGroundingAgreement:
    def test_grounding_block_carries_canonical_numbers_and_version(self):
        with _with_rules_docs([]):
            invalidate_cache()
            block = _ftl_grounding_block()
        assert "14.0h domestic" in block
        assert "15.0h international" in block
        assert "900.0h/year" in block
        assert "GACA-GOM-7.5.3-TF" in block
