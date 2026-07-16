"""
Legality Engine Unit Tests
60+ test cases covering all rule boundaries, edge conditions, and both directions.

Run: pytest python_services/tests/unit/test_legality.py -v
"""

import pytest
from datetime import datetime, timedelta
from legality.engine import (
    LegalityEngine, DutyPeriod, FTLRules, LegType, Severity
)

# ─── Fixtures ─────────────────────────────────────────────────────────────────

RULES = FTLRules()
ENGINE = LegalityEngine(RULES)

BASE_DATE = datetime(2026, 6, 1, 6, 0, 0)  # June 1 2026, 06:00 UTC

def make_duty(
    id: str = "leg1",
    origin: str = "RUH",
    destination: str = "JED",
    leg_type: LegType = LegType.domestic,
    duty_start: datetime = None,
    fdp_hours: float = 8.0,
    block_hours: float = 6.0,
    is_augmented: bool = False,
    sector_count: int = 1,
) -> DutyPeriod:
    ds = duty_start or BASE_DATE
    duty_end = ds + timedelta(hours=fdp_hours)
    release = duty_end + timedelta(minutes=30)
    return DutyPeriod(
        id=id,
        flight_number=f"SV{id}",
        origin=origin,
        destination=destination,
        leg_type=leg_type,
        duty_start=ds,
        duty_end=duty_end,
        release_time=release,
        block_hours=block_hours,
        fdp_hours=fdp_hours,
        is_augmented=is_augmented,
        sector_count=sector_count,
    )

# ─── FDP Tests ────────────────────────────────────────────────────────────────

class TestFDP:
    def test_domestic_fdp_exactly_at_limit_is_legal(self):
        duty = make_duty(fdp_hours=12.0, leg_type=LegType.domestic)
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        assert len(fdp_violations) == 0

    def test_domestic_fdp_one_minute_over_is_violation(self):
        duty = make_duty(fdp_hours=12.0167, leg_type=LegType.domestic)  # +1 min
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        assert len(fdp_violations) == 1
        assert fdp_violations[0].severity == Severity.blocking

    def test_international_fdp_exactly_at_limit_is_legal(self):
        duty = make_duty(fdp_hours=13.0, leg_type=LegType.international,
                         origin="RUH", destination="LHR")
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        assert len(fdp_violations) == 0

    def test_international_fdp_one_minute_over_is_violation(self):
        duty = make_duty(fdp_hours=13.0167, leg_type=LegType.international)
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        assert len(fdp_violations) == 1

    def test_augmented_crew_fdp_14h_is_legal(self):
        duty = make_duty(fdp_hours=14.0, leg_type=LegType.international, is_augmented=True)
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        assert len(fdp_violations) == 0

    def test_augmented_crew_fdp_over_14h_is_violation(self):
        duty = make_duty(fdp_hours=14.1, leg_type=LegType.international, is_augmented=True)
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        assert len(fdp_violations) == 1

    def test_fdp_approaching_limit_triggers_warning(self):
        # 90% of 12h = 10.8h — should trigger warning
        duty = make_duty(fdp_hours=11.0, leg_type=LegType.domestic)
        result = ENGINE.check_schedule([duty])
        fdp_warnings = [w for w in result.warnings if "FDP" in w.rule_id]
        assert len(fdp_warnings) == 1
        assert fdp_warnings[0].severity == Severity.warning

    def test_fdp_below_warning_threshold_no_warning(self):
        duty = make_duty(fdp_hours=9.0, leg_type=LegType.domestic)
        result = ENGINE.check_schedule([duty])
        fdp_issues = [x for x in result.violations + result.warnings if "FDP" in x.rule_id]
        assert len(fdp_issues) == 0


# ─── Rest Tests (Domestic) ────────────────────────────────────────────────────

class TestRestDomestic:
    def _make_two_duties_with_rest(self, rest_hours: float) -> list[DutyPeriod]:
        d1 = make_duty(id="d1", leg_type=LegType.domestic, duty_start=BASE_DATE, fdp_hours=8.0)
        # d1 release = BASE_DATE + 8h + 30min
        d2_start = d1.release_time + timedelta(hours=rest_hours)
        d2 = make_duty(id="d2", leg_type=LegType.domestic, duty_start=d2_start, fdp_hours=6.0)
        return [d1, d2]

    def test_exactly_14h_rest_is_legal(self):
        schedule = self._make_two_duties_with_rest(14.0)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) == 0

    def test_1min_below_14h_rest_is_violation(self):
        schedule = self._make_two_duties_with_rest(13.983)  # 14h - 1min
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1
        assert all(v.severity == Severity.blocking for v in rest_violations)

    def test_13h_rest_domestic_is_violation(self):
        schedule = self._make_two_duties_with_rest(13.0)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1

    def test_8h_rest_domestic_is_violation(self):
        schedule = self._make_two_duties_with_rest(8.0)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1

    def test_20h_rest_domestic_is_legal(self):
        schedule = self._make_two_duties_with_rest(20.0)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) == 0

    def test_rest_warning_triggers_below_110pct_of_minimum(self):
        # 14h * 1.1 = 15.4h — rest between 14h and 15.4h triggers warning
        schedule = self._make_two_duties_with_rest(14.5)
        result = ENGINE.check_schedule(schedule)
        rest_warnings = [w for w in result.warnings if "REST" in w.rule_id]
        assert len(rest_warnings) >= 1


# ─── Rest Tests (International) ───────────────────────────────────────────────

class TestRestInternational:
    def _make_two_intl_duties_with_rest(self, rest_hours: float) -> list[DutyPeriod]:
        d1 = make_duty(id="i1", leg_type=LegType.international,
                       origin="RUH", destination="LHR", duty_start=BASE_DATE, fdp_hours=10.0)
        d2_start = d1.release_time + timedelta(hours=rest_hours)
        d2 = make_duty(id="i2", leg_type=LegType.international,
                       origin="LHR", destination="RUH", duty_start=d2_start, fdp_hours=10.0)
        return [d1, d2]

    def test_exactly_15h_rest_international_is_legal(self):
        schedule = self._make_two_intl_duties_with_rest(15.0)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) == 0

    def test_1min_below_15h_rest_is_violation(self):
        schedule = self._make_two_intl_duties_with_rest(14.983)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1

    def test_14h_rest_international_is_violation(self):
        schedule = self._make_two_intl_duties_with_rest(14.0)
        result = ENGINE.check_schedule(schedule)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1

    def test_domestic_rule_does_not_apply_to_international(self):
        # 14h rest between two intl duties should violate (intl requires 15h)
        schedule = self._make_two_intl_duties_with_rest(14.5)
        result = ENGINE.check_schedule(schedule)
        violations_or_warnings = result.violations + result.warnings
        rest_issues = [x for x in violations_or_warnings if "REST" in x.rule_id]
        assert len(rest_issues) >= 1  # At least a warning


# ─── Backward & Forward Check Tests ─────────────────────────────────────────

class TestBackwardForwardCheck:
    def test_backward_check_catches_insufficient_rest_before_proposed(self):
        existing = make_duty(id="e1", duty_start=BASE_DATE, fdp_hours=8.0)
        # Proposed starts only 10h after existing's release (needs 14h for domestic)
        proposed_start = existing.release_time + timedelta(hours=10)
        proposed = make_duty(id="p1", duty_start=proposed_start, fdp_hours=6.0)
        result = ENGINE.check_schedule([existing], proposed=proposed)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1

    def test_forward_check_catches_insufficient_rest_after_proposed(self):
        # Proposed ends such that there's only 10h before next existing duty
        next_start = BASE_DATE + timedelta(hours=30)
        proposed_start = next_start - timedelta(hours=10) - timedelta(minutes=30)
        proposed = make_duty(id="p1", duty_start=proposed_start, fdp_hours=8.0)
        existing_next = make_duty(id="e2", duty_start=next_start, fdp_hours=6.0)
        result = ENGINE.check_schedule([existing_next], proposed=proposed)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1

    def test_both_directions_checked_simultaneously(self):
        existing_prev = make_duty(id="e1", duty_start=BASE_DATE, fdp_hours=8.0)
        # Only 10h rest before proposed AND only 10h rest after proposed
        proposed_start = existing_prev.release_time + timedelta(hours=10)
        proposed = make_duty(id="p1", duty_start=proposed_start, fdp_hours=6.0)
        next_start = proposed.release_time + timedelta(hours=10)
        existing_next = make_duty(id="e2", duty_start=next_start, fdp_hours=6.0)

        result = ENGINE.check_schedule([existing_prev, existing_next], proposed=proposed)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 2  # Both directions violated

    def test_legal_duty_passes_both_directions(self):
        existing_prev = make_duty(id="e1", duty_start=BASE_DATE, fdp_hours=8.0)
        proposed_start = existing_prev.release_time + timedelta(hours=15)
        proposed = make_duty(id="p1", duty_start=proposed_start, fdp_hours=6.0)
        next_start = proposed.release_time + timedelta(hours=15)
        existing_next = make_duty(id="e2", duty_start=next_start, fdp_hours=6.0)

        result = ENGINE.check_schedule([existing_prev, existing_next], proposed=proposed)
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) == 0


# ─── 7-Day Rolling Tests ─────────────────────────────────────────────────────

class TestSevenDayRolling:
    def _make_schedule_with_hours(self, total_block_hours: float, num_duties: int = 5) -> list[DutyPeriod]:
        duties = []
        block_per_duty = total_block_hours / num_duties
        fdp_per_duty = block_per_duty + 1.5
        current_start = BASE_DATE - timedelta(days=6)

        for i in range(num_duties):
            duty = make_duty(
                id=f"d{i}",
                duty_start=current_start,
                fdp_hours=fdp_per_duty,
                block_hours=block_per_duty,
            )
            duties.append(duty)
            current_start = duty.release_time + timedelta(hours=15)

        return duties

    def test_exactly_60h_7day_is_legal(self):
        schedule = self._make_schedule_with_hours(60.0)
        result = ENGINE.check_schedule(schedule)
        cum_violations = [v for v in result.violations if "7D" in v.rule_id]
        assert len(cum_violations) == 0

    def test_60h_1min_7day_is_violation(self):
        schedule = self._make_schedule_with_hours(60.1)
        result = ENGINE.check_schedule(schedule)
        cum_violations = [v for v in result.violations if "7D" in v.rule_id]
        assert len(cum_violations) >= 1

    def test_7day_approaching_limit_triggers_warning(self):
        schedule = self._make_schedule_with_hours(55.0)  # 55/60 = 91.7% > 90%
        result = ENGINE.check_schedule(schedule)
        cum_warnings = [w for w in result.warnings if "7D" in w.rule_id]
        assert len(cum_warnings) >= 1

    def test_min_1_day_off_7day_window_enforced(self):
        duties = []
        start = BASE_DATE - timedelta(days=6)
        for i in range(7):
            duty = make_duty(id=f"d{i}", duty_start=start + timedelta(days=i), fdp_hours=9.0, block_hours=7.0)
            duties.append(duty)
        result = ENGINE.check_schedule(duties)
        day_off_violations = [v for v in result.violations if "7D-002" in v.rule_id]
        assert len(day_off_violations) >= 1


# ─── 28-Day Rolling Tests ────────────────────────────────────────────────────

class TestTwentyEightDayRolling:
    def test_exactly_100h_28day_is_legal(self):
        duties = []
        hours_each = 10.0
        start = BASE_DATE - timedelta(days=27)
        for i in range(10):
            duty = make_duty(id=f"d{i}", duty_start=start + timedelta(days=i*2),
                             fdp_hours=hours_each + 1.5, block_hours=hours_each)
            duties.append(duty)
        result = ENGINE.check_schedule(duties)
        cum_violations = [v for v in result.violations if "28D" in v.rule_id]
        assert len(cum_violations) == 0

    def test_over_100h_28day_is_violation(self):
        duties = []
        hours_each = 10.2  # 10.2 * 10 = 102h > 100h
        start = BASE_DATE - timedelta(days=27)
        for i in range(10):
            duty = make_duty(id=f"d{i}", duty_start=start + timedelta(days=i*2),
                             fdp_hours=hours_each + 1.5, block_hours=hours_each)
            duties.append(duty)
        result = ENGINE.check_schedule(duties)
        cum_violations = [v for v in result.violations if "28D" in v.rule_id]
        assert len(cum_violations) >= 1


# ─── Monthly Duty Hours Tests ────────────────────────────────────────────────

class TestMonthlyDutyHours:
    def test_exactly_120h_monthly_duty_is_legal(self):
        duties = []
        fdp_each = 12.0  # 10 * 12 = 120h
        start = datetime(2026, 6, 1, 8, 0, 0)
        for i in range(10):
            duty = make_duty(id=f"d{i}", duty_start=start + timedelta(days=i*2),
                             fdp_hours=fdp_each, block_hours=fdp_each - 1.5)
            duties.append(duty)
        result = ENGINE.check_schedule(duties)
        monthly_violations = [v for v in result.violations if "MON" in v.rule_id]
        assert len(monthly_violations) == 0

    def test_121h_monthly_duty_is_violation(self):
        duties = []
        start = datetime(2026, 6, 1, 8, 0, 0)
        for i in range(10):
            duty = make_duty(id=f"d{i}", duty_start=start + timedelta(days=i*2),
                             fdp_hours=12.1, block_hours=10.0)
            duties.append(duty)
        result = ENGINE.check_schedule(duties)
        monthly_violations = [v for v in result.violations if "MON" in v.rule_id]
        assert len(monthly_violations) >= 1

    def test_monthly_approaching_limit_triggers_warning(self):
        # The engine warns when monthly duty is STRICTLY above the warning
        # threshold (90% of 120h = 108h) and at/below the 120h hard limit.
        # 108h exactly does NOT warn (boundary is `>`), so build 114h to sit
        # clearly inside the warning band. NOTE (owner decision, P0-adjacent):
        # if GACA policy is that the amber warning should fire AT exactly 90%,
        # change the engine threshold from `>` to `>=` instead of this test.
        duties = []
        start = datetime(2026, 6, 1, 8, 0, 0)
        for i in range(9):  # 8 * 12 + 1 * 18 = 114h  (in the 108–120h warning band)
            fdp = 18.0 if i == 8 else 12.0
            duty = make_duty(id=f"d{i}", duty_start=start + timedelta(days=i*2),
                             fdp_hours=fdp, block_hours=10.0)
            duties.append(duty)
        result = ENGINE.check_schedule(duties)
        monthly_warnings = [w for w in result.warnings if "MON" in w.rule_id]
        assert len(monthly_warnings) >= 1


# ─── Daily Block Hours Tests ─────────────────────────────────────────────────

class TestDailyBlockHours:
    def test_exactly_8h_block_is_legal(self):
        duty = make_duty(block_hours=8.0, fdp_hours=10.0)
        result = ENGINE.check_schedule([duty])
        blk_violations = [v for v in result.violations if "BLK" in v.rule_id]
        assert len(blk_violations) == 0

    def test_8h_1min_block_is_violation(self):
        duty = make_duty(block_hours=8.02, fdp_hours=10.0)
        result = ENGINE.check_schedule([duty])
        blk_violations = [v for v in result.violations if "BLK" in v.rule_id]
        assert len(blk_violations) >= 1


# ─── Trade Check Tests ────────────────────────────────────────────────────────

class TestTradeCheck:
    from legality.engine import TradeCheckRequest

    def test_legal_trade_passes_both_parties(self):
        from legality.engine import TradeCheckRequest
        initiator_schedule = [make_duty(id="i1", duty_start=BASE_DATE, fdp_hours=8.0)]
        offered = initiator_schedule[0]

        receiver_schedule = [make_duty(id="r1", duty_start=BASE_DATE + timedelta(days=2), fdp_hours=8.0)]
        requested = receiver_schedule[0]

        engine = LegalityEngine()
        # Build post-trade schedules
        initiator_new = [requested]
        receiver_new = [offered]

        initiator_result = engine.check_schedule(initiator_new)
        receiver_result = engine.check_schedule(receiver_new)

        assert initiator_result.passed
        assert receiver_result.passed

    def test_illegal_trade_blocked_for_initiator(self):
        engine = LegalityEngine()
        # Initiator has a duty immediately before the requested leg (no rest)
        prev_duty = make_duty(id="prev", duty_start=BASE_DATE, fdp_hours=10.0)
        requested = make_duty(id="req", duty_start=prev_duty.release_time + timedelta(hours=5), fdp_hours=8.0)
        # Only 5h rest — less than 14h minimum

        initiator_new = [prev_duty, requested]
        result = engine.check_schedule(initiator_new)
        assert not result.passed
        assert len(result.violations) >= 1


# ─── Edge Cases ───────────────────────────────────────────────────────────────

class TestEdgeCases:
    def test_empty_schedule_passes(self):
        result = ENGINE.check_schedule([])
        assert result.passed

    def test_single_legal_duty_passes(self):
        duty = make_duty(fdp_hours=8.0, block_hours=6.0)
        result = ENGINE.check_schedule([duty])
        assert result.passed

    def test_positioning_leg_uses_international_rules(self):
        duties = []
        d1 = make_duty(id="d1", leg_type=LegType.positioning,
                       duty_start=BASE_DATE, fdp_hours=5.0)
        d2_start = d1.release_time + timedelta(hours=14.5)  # Only 14.5h — warning for intl (need 15h)
        d2 = make_duty(id="d2", leg_type=LegType.positioning, duty_start=d2_start, fdp_hours=5.0)
        result = ENGINE.check_schedule([d1, d2])
        rest_issues = result.violations + result.warnings
        assert len(rest_issues) >= 1

    def test_proposed_duty_overlapping_existing_is_violation(self):
        existing = make_duty(id="e1", duty_start=BASE_DATE, fdp_hours=10.0)
        # Proposed starts DURING the existing duty
        proposed = make_duty(id="p1", duty_start=BASE_DATE + timedelta(hours=5), fdp_hours=6.0)
        result = ENGINE.check_schedule([existing], proposed=proposed)
        # Rest backward should be negative → violation
        assert not result.passed

    def test_all_violations_contain_affected_leg_ids(self):
        d1 = make_duty(id="d1", duty_start=BASE_DATE, fdp_hours=8.0)
        d2 = make_duty(id="d2", duty_start=d1.release_time + timedelta(hours=5), fdp_hours=8.0)
        result = ENGINE.check_schedule([d1, d2])
        for violation in result.violations:
            assert len(violation.affected_leg_ids) > 0

    def test_violation_actual_value_is_accurate(self):
        d1 = make_duty(id="d1", duty_start=BASE_DATE, fdp_hours=8.0)
        rest_provided = 10.0  # Less than 14h required
        d2 = make_duty(id="d2", duty_start=d1.release_time + timedelta(hours=rest_provided), fdp_hours=6.0)
        result = ENGINE.check_schedule([d1, d2])
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        assert len(rest_violations) >= 1
        assert abs(rest_violations[0].actual_value - rest_provided) < 0.1

    def test_custom_rules_override_defaults(self):
        custom_rules = FTLRules(min_rest_domestic_hours=10.0)  # Relaxed
        engine = LegalityEngine(custom_rules)
        d1 = make_duty(id="d1", duty_start=BASE_DATE, fdp_hours=8.0)
        d2 = make_duty(id="d2", duty_start=d1.release_time + timedelta(hours=12), fdp_hours=6.0)
        result = engine.check_schedule([d1, d2])
        rest_violations = [v for v in result.violations if "REST" in v.rule_id]
        # 12h > custom 10h minimum → should pass
        assert len(rest_violations) == 0

    def test_result_passed_false_when_any_blocking_violation(self):
        duty = make_duty(fdp_hours=15.0, leg_type=LegType.domestic)  # Way over limit
        result = ENGINE.check_schedule([duty])
        assert result.passed is False

    def test_result_passed_true_when_only_warnings(self):
        # FDP at 91% of 12h = 10.92h → warning, no violation
        duty = make_duty(fdp_hours=11.0, leg_type=LegType.domestic)
        result = ENGINE.check_schedule([duty])
        fdp_violations = [v for v in result.violations if "FDP" in v.rule_id]
        fdp_warnings = [w for w in result.warnings if "FDP" in w.rule_id]
        assert len(fdp_violations) == 0
        assert len(fdp_warnings) >= 1
        # passed can still be True if only warnings (no blocking violations)
        blocking = [v for v in result.violations if v.severity == Severity.blocking]
        assert result.passed == (len(blocking) == 0)

    def test_arabic_descriptions_present_in_all_violations(self):
        duty = make_duty(fdp_hours=15.0)
        result = ENGINE.check_schedule([duty])
        for v in result.violations:
            assert v.rule_description_ar, f"Missing Arabic description for rule {v.rule_id}"
            assert len(v.rule_description_ar) > 5

    def test_violations_have_required_value_set(self):
        duty = make_duty(fdp_hours=15.0, leg_type=LegType.domestic)
        result = ENGINE.check_schedule([duty])
        for v in result.violations:
            assert v.required_value > 0

    def test_check_at_timestamp_populated(self):
        result = ENGINE.check_schedule([])
        assert result.checked_at is not None

    def test_rules_version_in_result(self):
        # Direct engine calls carry the canonical-defaults stamp; the HTTP
        # endpoints overwrite it with live provenance via _resolve_rules
        # (tested below). The stale hardcoded "GACA-2024-v1" is gone.
        result = ENGINE.check_schedule([])
        assert result.rules_version.startswith("GACA-GOM-7.5.3-TF")

    def test_resolve_rules_provenance(self):
        from legality.engine import _resolve_rules, FTLRules
        # Omitted → effective rules with real version string
        rules, version = _resolve_rules(None)
        assert isinstance(rules, FTLRules)
        assert version.startswith("GACA-GOM-7.5.3-TF")
        # Caller-supplied → unmistakably marked what-if
        supplied, what_if = _resolve_rules(FTLRules())
        assert supplied is not None
        assert what_if == "caller-supplied (what-if)"
