"""
Unit tests — Rest Engine
Tests rules, calculator, legality, fatigue, and scoring.
"""
import pytest
from datetime import datetime, timedelta
import pytz

from rest_engine.rules      import get_profile, DEFAULT_PROFILE, CABIN_LONG_HAUL_PROFILE
from rest_engine.calculator import RestCalculator, DutyInput
from rest_engine.legality   import LegalityEngine, ViolationSeverity
from rest_engine.fatigue    import FatigueEngine, FatigueLevel
from rest_engine.scoring    import SafetyScorer
from rest_engine.validators import DutyInputValidator


# ── Helpers ───────────────────────────────────────────────────────────────────

def _utc(year=2026, month=6, day=10, hour=8, minute=0) -> datetime:
    return datetime(year, month, day, hour, minute, tzinfo=pytz.UTC)


def _make_input(
    start_hour: int = 8,
    duration_hrs: float = 8.0,
    next_duty_gap_hrs: float | None = 12.0,
    legs: int = 2,
    block_mins: int = 0,
    is_intl: bool = False,
    carry_over: float = 0.0,
    report_hour: int = 8,
) -> DutyInput:
    start = _utc(hour=start_hour)
    end   = start + timedelta(hours=duration_hrs)
    next_duty = (end + timedelta(hours=next_duty_gap_hrs)
                 if next_duty_gap_hrs is not None else None)
    return DutyInput(
        duty_start_utc      = start,
        duty_end_utc        = end,
        report_local_hour   = report_hour,
        num_operating_legs  = legs,
        block_minutes       = block_mins,
        is_international    = is_intl,
        carry_over_hours    = carry_over,
        next_duty_start_utc = next_duty,
    )


# ── RulesProfile ──────────────────────────────────────────────────────────────

class TestRulesProfile:

    def test_default_profile_loads(self):
        # Canonical GOM 7.5.3 Table (F) minimums via legality/rules_source
        # (P0-1). If these asserts fail, a rule value changed — that change
        # must go through OWNER_DECISION_REQUEST.md, not a silent edit.
        assert DEFAULT_PROFILE is not None
        assert DEFAULT_PROFILE.min_rest_domestic_mins == 840        # 14:00
        assert DEFAULT_PROFILE.min_rest_international_mins == 900   # 15:00
        assert DEFAULT_PROFILE.min_rest_augmented_mins == 1080      # 18:00
        assert DEFAULT_PROFILE.max_daily_block_mins == 480          # 08:00
        assert DEFAULT_PROFILE.max_annual_block_hrs == 900

    def test_get_profile_by_type(self):
        p = get_profile("cabin_long_haul")
        # Long-haul is a presentation variant; its SAFETY minimums are the
        # canonical ones (a profile may only tighten, never loosen — P0-1).
        assert p.min_rest_international_mins == 900   # 15:00 canonical

    def test_unknown_crew_type_returns_default(self):
        p = get_profile("non_existent_type")
        assert p == DEFAULT_PROFILE

    def test_fdp_limit_decreases_with_early_signin(self):
        p     = DEFAULT_PROFILE
        std   = p.fdp_limit_for(2, report_hour=8)
        early = p.fdp_limit_for(2, report_hour=4)
        assert early < std
        assert std - early == p.fdp_early_signin_reduction_mins

    def test_fdp_limit_decreases_with_wocl(self):
        p       = DEFAULT_PROFILE
        std     = p.fdp_limit_for(2, report_hour=8, wocl_penetration=False)
        wocl    = p.fdp_limit_for(2, report_hour=8, wocl_penetration=True)
        assert wocl < std

    def test_fdp_limit_never_increases_with_more_legs(self):
        # ODR-002 conservative intersection: the flat domestic cap (12:00)
        # can FLATTEN the low-sector end of the table, so the guarantee is
        # non-increasing, with strict decreases where the sector table binds.
        p = DEFAULT_PROFILE
        limits = [p.fdp_limit_for(n) for n in range(1, 7)]
        assert all(a >= b for a, b in zip(limits, limits[1:])), limits
        # table binds domestically at the high-sector end …
        assert p.fdp_limit_for(4) > p.fdp_limit_for(6)
        # … and internationally already at the low end (13:00 flat > table@4)
        assert (p.fdp_limit_for(1, is_international=True)
                > p.fdp_limit_for(4, is_international=True))

    def test_fdp_floor_never_below_minimum(self):
        p     = DEFAULT_PROFILE
        limit = p.fdp_limit_for(6, report_hour=3, wocl_penetration=True)
        assert limit >= p.fdp_min_floor_mins

    def test_min_rest_international_higher_than_domestic(self):
        p = DEFAULT_PROFILE
        assert p.min_rest_for(True) > p.min_rest_for(False)

    def test_augmented_rest_is_the_highest_minimum(self):
        # Pre-remediation this module gave augmented crews LESS rest (8h) than
        # standard (10h) — inverted vs the project's own cited GOM Table (F),
        # where augmented = 18h at all stations (ODR-001). Lock the direction.
        p = DEFAULT_PROFILE
        assert p.min_rest_for(False, is_augmented=True) == 1080
        assert (p.min_rest_for(False, is_augmented=True)
                > p.min_rest_for(True)
                > p.min_rest_for(False))


# ── RestCalculator ────────────────────────────────────────────────────────────

class TestRestCalculator:
    def setup_method(self):
        self.calc = RestCalculator()

    def test_calculates_fdp_correctly(self):
        inp    = _make_input(duration_hrs=10.0)
        result = self.calc.calculate(inp)
        assert result.fdp.actual_mins == 600   # 10h = 600 min

    def test_rest_window_calculated_when_next_duty_provided(self):
        inp    = _make_input(duration_hrs=8.0, next_duty_gap_hrs=12.0)
        result = self.calc.calculate(inp)
        assert result.rest is not None
        assert result.rest.duration_mins == 12 * 60

    def test_rest_none_when_no_next_duty(self):
        inp    = _make_input(next_duty_gap_hrs=None)
        result = self.calc.calculate(inp)
        assert result.rest is None

    def test_rest_is_sufficient_when_above_minimum(self):
        # 16h gap comfortably clears the canonical 14h domestic minimum
        # (12h — the old fixture — is now correctly INSUFFICIENT).
        inp    = _make_input(duration_hrs=8.0, next_duty_gap_hrs=16.0)
        result = self.calc.calculate(inp)
        assert result.rest.is_sufficient is True

    def test_rest_now_insufficient_at_old_10h_minimum(self):
        # P0-1 regression lock: 12h rest passed the OLD uncited 10h rule but
        # violates the canonical 14h domestic minimum.
        inp    = _make_input(duration_hrs=8.0, next_duty_gap_hrs=12.0)
        result = self.calc.calculate(inp)
        assert result.rest.is_sufficient is False

    def test_rest_insufficient_when_below_minimum(self):
        inp    = _make_input(duration_hrs=8.0, next_duty_gap_hrs=8.0)
        result = self.calc.calculate(inp)
        assert result.rest.is_sufficient is False

    def test_carry_over_within_limit(self):
        inp    = _make_input(carry_over=10.0)
        result = self.calc.calculate(inp)
        assert result.carry_over.is_within_limit is True

    def test_carry_over_exceeds_limit(self):
        inp    = _make_input(carry_over=35.0)
        result = self.calc.calculate(inp)
        assert result.carry_over.is_within_limit is False

    def test_fdp_marginal_flag(self):
        # FDP within 30 min of limit (2 legs = 810 min, so 785–810 is marginal)
        p     = DEFAULT_PROFILE
        limit = p.fdp_limit_for(2, report_hour=8)
        inp   = DutyInput(
            duty_start_utc      = _utc(hour=8),
            duty_end_utc        = _utc(hour=8) + timedelta(minutes=limit - 10),
            report_local_hour   = 8,
            num_operating_legs  = 2,
        )
        result = self.calc.calculate(inp)
        assert result.fdp.is_marginal is True
        assert result.fdp.is_within_limit is True

    def test_total_duty_label_format(self):
        inp    = _make_input(duration_hrs=9.5)
        result = self.calc.calculate(inp)
        assert ':' in result.total_duty_label


# ── LegalityEngine ────────────────────────────────────────────────────────────

class TestLegalityEngine:
    def setup_method(self):
        self.engine = LegalityEngine()

    def test_legal_when_all_within_limits(self):
        inp    = _make_input(duration_hrs=8.0, legs=2,
                             next_duty_gap_hrs=16.0)
        result = self.engine.validate(inp)
        assert result.is_legal is True
        assert len(result.violations) == 0

    def test_violation_when_fdp_exceeded(self):
        inp = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=8) + timedelta(hours=15),
            report_local_hour = 8,
            num_operating_legs= 2,
        )
        result = self.engine.validate(inp)
        assert not result.is_legal
        fdp_viols = [v for v in result.violations if 'FDP' in v.rule]
        assert len(fdp_viols) >= 1

    def test_violation_when_rest_insufficient(self):
        inp    = _make_input(duration_hrs=8.0, next_duty_gap_hrs=7.0,
                             is_intl=False)
        result = self.engine.validate(inp)
        rest_viols = [v for v in result.violations if 'Rest' in v.rule]
        assert len(rest_viols) >= 1

    def test_warning_when_fdp_marginal(self):
        p     = DEFAULT_PROFILE
        limit = p.fdp_limit_for(2, report_hour=8)
        inp   = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=8) + timedelta(minutes=limit - 15),
            report_local_hour = 8,
            num_operating_legs= 2,
        )
        result = self.engine.validate(inp)
        assert result.is_legal is True
        assert any('FDP' in w.rule for w in result.warnings)

    def test_block_violation(self):
        inp = _make_input(duration_hrs=9.0, block_mins=540)  # 9h block > 8:00 canonical cap
        result = self.engine.validate(inp)
        block_viols = [v for v in result.violations if 'Block' in v.rule]
        assert len(block_viols) >= 1

    def test_carry_over_violation(self):
        inp    = _make_input(carry_over=35.0)
        result = self.engine.validate(inp)
        co_viols = [v for v in result.violations if 'Carry' in v.rule]
        assert len(co_viols) >= 1

    def test_safety_score_100_when_fully_legal(self):
        inp    = _make_input(duration_hrs=6.0, legs=1, next_duty_gap_hrs=16.0)
        result = self.engine.validate(inp)
        assert result.safety_score >= 80.0

    def test_safety_score_lower_when_violations(self):
        inp = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=8) + timedelta(hours=16),
            report_local_hour = 8,
            num_operating_legs= 2,
        )
        result = self.engine.validate(inp)
        assert result.safety_score < 80.0

    def test_status_labels(self):
        inp_legal   = _make_input(duration_hrs=6.0, next_duty_gap_hrs=16.0)
        inp_illegal = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=8) + timedelta(hours=16),
            report_local_hour = 8,
            num_operating_legs= 2,
        )
        assert self.engine.validate(inp_legal).is_legal is True
        assert self.engine.validate(inp_illegal).is_legal is False

    def test_validate_trade_returns_both_sides(self):
        offered   = _make_input(duration_hrs=8.0)
        requested = _make_input(duration_hrs=9.0)
        result = self.engine.validate_trade(offered, requested)
        assert 'trade_is_safe'    in result
        assert 'offered_result'   in result
        assert 'requested_result' in result


# ── FatigueEngine ─────────────────────────────────────────────────────────────

class TestFatigueEngine:
    def setup_method(self):
        self.engine = FatigueEngine()

    def test_low_fatigue_for_easy_duty(self):
        inp    = _make_input(start_hour=8, duration_hrs=6.0,
                             legs=1, report_hour=8)
        result = self.engine.score(inp, rest_before_mins=720)
        assert result.level == FatigueLevel.LOW

    def test_higher_fatigue_for_early_signin(self):
        late  = _make_input(report_hour=9)
        early = _make_input(report_hour=3)
        late_s  = self.engine.score(late,  rest_before_mins=660)
        early_s = self.engine.score(early, rest_before_mins=660)
        assert early_s.raw > late_s.raw

    def test_higher_fatigue_for_poor_rest(self):
        good_rest = self.engine.score(_make_input(), rest_before_mins=720)
        poor_rest = self.engine.score(_make_input(), rest_before_mins=480)
        assert poor_rest.raw > good_rest.raw

    def test_factors_sum_reasonable(self):
        inp    = _make_input()
        result = self.engine.score(inp)
        total  = sum(f.weighted for f in result.factors)
        assert 0.0 <= total <= 1.0

    def test_fatigue_percentage_matches_raw(self):
        inp    = _make_input()
        result = self.engine.score(inp)
        assert result.percentage == int(result.raw * 100)

    def test_recommendation_not_empty(self):
        inp    = _make_input()
        result = self.engine.score(inp)
        assert len(result.recommendation) > 0


# ── SafetyScorer ──────────────────────────────────────────────────────────────

class TestSafetyScorer:
    def setup_method(self):
        self.scorer = SafetyScorer()

    def test_safe_duty_scores_high(self):
        # "Comfortably safe" is defined against the CANONICAL minimums
        # (14h domestic rest — legality/rules_source, P0-1). A 20h forward
        # gap and 16h prior rest leave healthy margins; under the old,
        # uncited 10h minimum a 16h gap looked comfortable, under the
        # canonical rules it is only barely legal and rightly scores lower.
        inp    = _make_input(duration_hrs=6.0, legs=1,
                             next_duty_gap_hrs=20.0, report_hour=8)
        report = self.scorer.score(inp, rest_before_mins=960)
        assert report.safety_score >= 70.0
        assert report.is_legal is True

    def test_illegal_duty_not_safe(self):
        inp = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=8) + timedelta(hours=15),
            report_local_hour = 8,
            num_operating_legs= 2,
        )
        report = self.scorer.score(inp)
        assert report.is_legal is False
        assert report.is_safe  is False

    def test_score_between_0_and_100(self):
        inp    = _make_input()
        report = self.scorer.score(inp)
        assert 0 <= report.safety_score <= 100

    def test_trade_pair_returns_both_sides(self):
        a = _make_input(duration_hrs=7.0)
        b = _make_input(duration_hrs=9.0)
        result = self.scorer.score_trade_pair(a, b)
        assert 'trade_is_safe'   in result
        assert 'offered_report'  in result
        assert 'requested_report'in result
        assert 'recommendation'  in result


# ── DutyInputValidator ────────────────────────────────────────────────────────

class TestDutyInputValidator:
    def setup_method(self):
        self.v = DutyInputValidator()

    def test_valid_input_passes(self):
        inp    = _make_input()
        result = self.v.validate(inp)
        assert result.is_valid is True

    def test_end_before_start_fails(self):
        inp = DutyInput(
            duty_start_utc    = _utc(hour=10),
            duty_end_utc      = _utc(hour=8),
            report_local_hour = 10,
            num_operating_legs= 2,
        )
        result = self.v.validate(inp)
        assert result.is_valid is False
        assert any('duty_end_utc must be after' in e for e in result.errors)

    def test_negative_legs_fails(self):
        inp = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=16),
            report_local_hour = 8,
            num_operating_legs= -1,
        )
        result = self.v.validate(inp)
        assert result.is_valid is False

    def test_invalid_report_hour_fails(self):
        inp = DutyInput(
            duty_start_utc    = _utc(hour=8),
            duty_end_utc      = _utc(hour=16),
            report_local_hour = 25,
            num_operating_legs= 2,
        )
        result = self.v.validate(inp)
        assert result.is_valid is False

    def test_next_duty_before_end_fails(self):
        inp = DutyInput(
            duty_start_utc      = _utc(hour=8),
            duty_end_utc        = _utc(hour=16),
            report_local_hour   = 8,
            num_operating_legs  = 2,
            next_duty_start_utc = _utc(hour=14),
        )
        result = self.v.validate(inp)
        assert result.is_valid is False
