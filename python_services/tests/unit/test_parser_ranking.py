"""
Tests for Excel Parser and Ranking Engine
"""
import pytest
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
import io

# ─── Parser Tests ─────────────────────────────────────────────────────────────
from parser.excel_parser import RosterParser, IATA_TIMEZONES, DOMESTIC_IATA

class TestRosterParser:
    """Tests for the Excel roster parser."""

    def setup_method(self):
        self.parser = RosterParser(user_id="test_user", month="2026-06")

    def test_extract_line_number_standard(self):
        assert self.parser._extract_line_number("Line 411") == "411"

    def test_extract_line_number_numeric_only(self):
        assert self.parser._extract_line_number("411") == "411"

    def test_extract_line_number_with_spaces(self):
        assert self.parser._extract_line_number("  Line 208  ") == "208"

    def test_extract_line_number_arabic(self):
        assert self.parser._extract_line_number("خط 317") == "317"

    def test_extract_line_number_invalid(self):
        assert self.parser._extract_line_number("Summary") is None

    def test_extract_line_number_no_digits(self):
        assert self.parser._extract_line_number("Instructions") is None

    def test_parse_datetime_iso_format(self):
        result = self.parser._parse_datetime("2026-06-15", "09:30")
        assert result == datetime(2026, 6, 15, 9, 30)

    def test_parse_datetime_dmy_format(self):
        result = self.parser._parse_datetime("15/06/2026", "09:30")
        assert result == datetime(2026, 6, 15, 9, 30)

    def test_parse_datetime_datetime_object(self):
        dt = datetime(2026, 6, 15, 9, 30)
        result = self.parser._parse_datetime(dt, dt)
        assert result == dt

    def test_parse_datetime_none_returns_none(self):
        result = self.parser._parse_datetime(None, "09:30")
        assert result is None

    def test_parse_datetime_hhmm_no_colon(self):
        result = self.parser._parse_datetime("2026-06-15", "0930")
        assert result == datetime(2026, 6, 15, 9, 30)

    def test_domestic_leg_type_riyadh_jeddah(self):
        assert "RUH" in DOMESTIC_IATA
        assert "JED" in DOMESTIC_IATA

    def test_international_leg_type_london(self):
        assert "LHR" not in DOMESTIC_IATA

    def test_compute_rest_intervals_basic(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)

        leg1 = ParsedLeg(
            id="l1", lineId="line1", flightNumber="SV100",
            origin="RUH", destination="JED", legType="domestic",
            departureLT=base.isoformat(), arrivalLT=(base + timedelta(hours=1)).isoformat(),
            departureUTC=base.isoformat(), arrivalUTC=(base + timedelta(hours=1)).isoformat(),
            dutyStart=base.isoformat(), dutyEnd=(base + timedelta(hours=2)).isoformat(),
            releaseTime=(base + timedelta(hours=2, minutes=30)).isoformat(),
            blockHours=1.0, fdpHours=2.0, sequence=0,
        )
        leg2 = ParsedLeg(
            id="l2", lineId="line1", flightNumber="SV101",
            origin="JED", destination="RUH", legType="domestic",
            departureLT=(base + timedelta(hours=18)).isoformat(),
            arrivalLT=(base + timedelta(hours=19)).isoformat(),
            departureUTC=(base + timedelta(hours=18)).isoformat(),
            arrivalUTC=(base + timedelta(hours=19)).isoformat(),
            dutyStart=(base + timedelta(hours=17)).isoformat(),
            dutyEnd=(base + timedelta(hours=20)).isoformat(),
            releaseTime=(base + timedelta(hours=20, minutes=30)).isoformat(),
            blockHours=1.0, fdpHours=3.0, sequence=1,
        )

        result = self.parser._compute_rest_intervals([leg1, leg2])
        # rest = duty_start[leg2] - release_time[leg1]
        #      = (base + 17h) - (base + 2h30) = 14.5h
        assert abs(result[1].restBeforeHours - 14.5) < 0.1
        assert abs(result[0].restAfterHours - 14.5) < 0.1

    def test_layover_detection(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)

        leg1 = ParsedLeg(
            id="l1", lineId="line1", flightNumber="SV200",
            origin="RUH", destination="LHR", legType="international",
            departureLT=base.isoformat(), arrivalLT=(base + timedelta(hours=7)).isoformat(),
            departureUTC=base.isoformat(), arrivalUTC=(base + timedelta(hours=7)).isoformat(),
            dutyStart=base.isoformat(), dutyEnd=(base + timedelta(hours=8)).isoformat(),
            releaseTime=(base + timedelta(hours=8, minutes=30)).isoformat(),
            blockHours=7.0, fdpHours=8.0, sequence=0,
        )
        leg2 = ParsedLeg(
            id="l2", lineId="line1", flightNumber="SV201",
            origin="LHR", destination="RUH", legType="international",
            departureLT=(base + timedelta(hours=32)).isoformat(),
            arrivalLT=(base + timedelta(hours=39)).isoformat(),
            departureUTC=(base + timedelta(hours=32)).isoformat(),
            arrivalUTC=(base + timedelta(hours=39)).isoformat(),
            dutyStart=(base + timedelta(hours=31)).isoformat(),
            dutyEnd=(base + timedelta(hours=40)).isoformat(),
            releaseTime=(base + timedelta(hours=40, minutes=30)).isoformat(),
            blockHours=7.0, fdpHours=9.0, sequence=1,
        )

        result = self.parser._compute_rest_intervals([leg1, leg2])
        # rest = 31:00 - 08:30 = 22.5h — should be a layover
        assert result[0].layover is True
        assert result[0].layoverHours > 20

    def test_rest_annotation_domestic_violation(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)
        leg = ParsedLeg(
            id="l1", lineId="l", flightNumber="SV100",
            origin="RUH", destination="JED", legType="domestic",
            departureLT=base.isoformat(), arrivalLT=(base+timedelta(hours=1)).isoformat(),
            departureUTC=base.isoformat(), arrivalUTC=(base+timedelta(hours=1)).isoformat(),
            dutyStart=base.isoformat(), dutyEnd=(base+timedelta(hours=2)).isoformat(),
            releaseTime=(base+timedelta(hours=2,minutes=30)).isoformat(),
            blockHours=1.0, fdpHours=2.0, restBeforeHours=10.0, sequence=0,
        )
        result = self.parser._annotate_legality([leg])
        assert result[0].legalityStatus == "violation"
        assert any("DOM" in f for f in result[0].legalityFlags)

    def test_rest_annotation_international_violation(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)
        leg = ParsedLeg(
            id="l1", lineId="l", flightNumber="SV200",
            origin="RUH", destination="LHR", legType="international",
            departureLT=base.isoformat(), arrivalLT=(base+timedelta(hours=7)).isoformat(),
            departureUTC=base.isoformat(), arrivalUTC=(base+timedelta(hours=7)).isoformat(),
            dutyStart=base.isoformat(), dutyEnd=(base+timedelta(hours=8)).isoformat(),
            releaseTime=(base+timedelta(hours=8,minutes=30)).isoformat(),
            blockHours=7.0, fdpHours=8.0, restBeforeHours=12.0, sequence=0,
        )
        result = self.parser._annotate_legality([leg])
        assert result[0].legalityStatus == "violation"
        assert any("INT" in f for f in result[0].legalityFlags)

    def test_rest_annotation_legal(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)
        leg = ParsedLeg(
            id="l1", lineId="l", flightNumber="SV100",
            origin="RUH", destination="JED", legType="domestic",
            departureLT=base.isoformat(), arrivalLT=(base+timedelta(hours=1)).isoformat(),
            departureUTC=base.isoformat(), arrivalUTC=(base+timedelta(hours=1)).isoformat(),
            dutyStart=base.isoformat(), dutyEnd=(base+timedelta(hours=2)).isoformat(),
            releaseTime=(base+timedelta(hours=2,minutes=30)).isoformat(),
            blockHours=1.0, fdpHours=2.0, restBeforeHours=16.0, sequence=0,
        )
        result = self.parser._annotate_legality([leg])
        assert result[0].legalityStatus == "legal"

    def test_fdp_violation(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)
        leg = ParsedLeg(
            id="l1", lineId="l", flightNumber="SV100",
            origin="RUH", destination="JED", legType="domestic",
            departureLT=base.isoformat(), arrivalLT=(base+timedelta(hours=1)).isoformat(),
            departureUTC=base.isoformat(), arrivalUTC=(base+timedelta(hours=1)).isoformat(),
            dutyStart=base.isoformat(), dutyEnd=(base+timedelta(hours=15)).isoformat(),
            releaseTime=(base+timedelta(hours=15,minutes=30)).isoformat(),
            blockHours=1.0, fdpHours=15.0, restBeforeHours=16.0, sequence=0,
        )
        result = self.parser._annotate_legality([leg])
        assert result[0].legalityStatus == "violation"
        assert any("FDP" in f for f in result[0].legalityFlags)

    def test_compute_summary_correct_totals(self):
        from parser.excel_parser import ParsedLeg
        base = datetime(2026, 6, 15, 8, 0)
        legs = [
            ParsedLeg(
                id=f"l{i}", lineId="l", flightNumber=f"SV{i}",
                origin="RUH", destination="LHR" if i % 2 == 0 else "JED",
                legType="international" if i % 2 == 0 else "domestic",
                departureLT=(base+timedelta(days=i)).isoformat(),
                arrivalLT=(base+timedelta(days=i,hours=3)).isoformat(),
                departureUTC=(base+timedelta(days=i)).isoformat(),
                arrivalUTC=(base+timedelta(days=i,hours=3)).isoformat(),
                dutyStart=(base+timedelta(days=i)).isoformat(),
                dutyEnd=(base+timedelta(days=i,hours=4)).isoformat(),
                releaseTime=(base+timedelta(days=i,hours=4,minutes=30)).isoformat(),
                blockHours=3.0, fdpHours=4.0, estimatedPay=500.0,
                perDiem=100.0, sequence=i,
            ) for i in range(4)
        ]
        summary = self.parser._compute_summary(legs)
        assert summary["totalLegs"] == 4
        assert abs(summary["totalBlockHours"] - 12.0) < 0.01
        assert summary["internationalLegs"] == 2
        assert summary["domesticLegs"] == 2

    def test_days_off_computation(self):
        from parser.excel_parser import ParsedLeg
        # Legs on Mon, Tue, Thu — Wed and Fri should be off
        dates = [
            datetime(2026, 6, 1),  # Monday
            datetime(2026, 6, 2),  # Tuesday
            datetime(2026, 6, 4),  # Thursday
        ]
        legs = [
            ParsedLeg(
                id=f"l{i}", lineId="l", flightNumber=f"SV{i}",
                origin="RUH", destination="JED", legType="domestic",
                departureLT=d.isoformat(), arrivalLT=(d+timedelta(hours=1)).isoformat(),
                departureUTC=d.isoformat(), arrivalUTC=(d+timedelta(hours=1)).isoformat(),
                dutyStart=d.isoformat(), dutyEnd=(d+timedelta(hours=2)).isoformat(),
                releaseTime=(d+timedelta(hours=2,minutes=30)).isoformat(),
                blockHours=1.0, fdpHours=2.0, sequence=i,
            ) for i, d in enumerate(dates)
        ]
        days_off = self.parser._compute_days_off(legs)
        # Wednesday (KSA dow 4) and Friday (KSA dow 6) should be in days_off
        assert len(days_off) > 0


# ─── Ranking Engine Tests ──────────────────────────────────────────────────────
class TestRankingEngine:
    """Tests for the scoring and ranking engine (module-level functions)."""

    def test_import_ranking_functions(self):
        from ranking.scorer import score_salary, score_rest_quality, score_dest_preference, rank_lines
        assert callable(score_salary)
        assert callable(score_rest_quality)
        assert callable(score_dest_preference)
        assert callable(rank_lines)

    def test_money_mode_weights_salary_dominant(self):
        from ranking.scorer import MODE_WEIGHTS
        weights = MODE_WEIGHTS.get("money", {})
        assert weights.get("salary", 0) == max(weights.values()), \
            "Salary weight should be highest in money mode"

    def test_rest_mode_weights_rest_dominant(self):
        from ranking.scorer import MODE_WEIGHTS
        weights = MODE_WEIGHTS.get("rest", {})
        # The rest-related weight key is "rest_quality" (0.60), which is dominant
        # in rest mode.
        assert weights.get("rest_quality", 0) == max(weights.values()), \
            "rest_quality weight should be highest in rest mode"

    def test_balanced_mode_weights_sum_to_one(self):
        from ranking.scorer import MODE_WEIGHTS
        weights = MODE_WEIGHTS.get("balanced", {})
        assert abs(sum(weights.values()) - 1.0) < 0.001

    def _make_line(self, line_id, line_number, salary, block_hours, intl, dom, destinations, days_off):
        from ranking.scorer import LineSummaryInput
        return LineSummaryInput(
            line_id=line_id, line_number=line_number,
            total_legs=intl + dom, total_block_hours=block_hours,
            total_duty_hours=block_hours * 1.3, total_duty_days=len(days_off) + intl + dom,
            international_legs=intl, domestic_legs=dom,
            layover_count=max(0, intl - 1),
            estimated_salary_min=salary * 0.9, estimated_salary_max=salary,
            destinations=destinations, days_off=days_off,
            min_rest_interval_hours=16.0, avg_rest_interval_hours=18.0,
            rest_near_minimum_count=0,
        )

    def test_salary_score_max_returns_100(self):
        from ranking.scorer import score_salary, LineSummaryInput
        line = LineSummaryInput(
            line_id="l1", line_number="411",
            total_legs=6, total_block_hours=60, total_duty_hours=80, total_duty_days=10,
            international_legs=4, domestic_legs=2, layover_count=2,
            estimated_salary_min=15000, estimated_salary_max=15000,  # at the ceiling; midpoint == max
            destinations=["LHR"], days_off=[4, 5],
            min_rest_interval_hours=16.0, avg_rest_interval_hours=18.0,
            rest_near_minimum_count=0,
        )
        score = score_salary(line, all_max=15000)
        assert abs(score - 100.0) < 1.0

    def test_salary_score_zero_salary(self):
        from ranking.scorer import score_salary, LineSummaryInput
        line = LineSummaryInput(
            line_id="l1", line_number="411",
            total_legs=6, total_block_hours=60, total_duty_hours=80, total_duty_days=10,
            international_legs=4, domestic_legs=2, layover_count=2,
            estimated_salary_min=0, estimated_salary_max=0,
            destinations=[], days_off=[],
            min_rest_interval_hours=16.0, avg_rest_interval_hours=18.0,
            rest_near_minimum_count=0,
        )
        score = score_salary(line, all_max=15000)
        assert score == 0.0

    def test_destination_score_preferred(self):
        from ranking.scorer import score_dest_preference, LineSummaryInput, UserPreferences
        prefs = UserPreferences(preferred_dest=["LHR", "CDG"], avoided_dest=[], preferred_off=[4, 5])
        line = LineSummaryInput(
            line_id="l1", line_number="411",
            total_legs=6, total_block_hours=60, total_duty_hours=80, total_duty_days=10,
            international_legs=4, domestic_legs=2, layover_count=2,
            estimated_salary_min=10800, estimated_salary_max=12000,
            destinations=["LHR", "CDG", "RUH"], days_off=[4, 5],
            min_rest_interval_hours=16.0, avg_rest_interval_hours=18.0,
            rest_near_minimum_count=0,
        )
        score = score_dest_preference(line, prefs)
        assert score > 50.0

    def test_destination_score_avoided(self):
        from ranking.scorer import score_dest_preference, LineSummaryInput, UserPreferences
        prefs = UserPreferences(preferred_dest=[], avoided_dest=["LAX"], preferred_off=[])
        line = LineSummaryInput(
            line_id="l1", line_number="411",
            total_legs=3, total_block_hours=60, total_duty_hours=80, total_duty_days=10,
            international_legs=2, domestic_legs=1, layover_count=1,
            estimated_salary_min=10800, estimated_salary_max=12000,
            destinations=["LAX"], days_off=[0, 1],
            min_rest_interval_hours=16.0, avg_rest_interval_hours=18.0,
            rest_near_minimum_count=0,
        )
        score = score_dest_preference(line, prefs)
        assert score < 50.0

    def test_rank_lines_returns_sorted_descending(self):
        from ranking.scorer import rank_lines, LineSummaryInput, UserPreferences
        prefs = UserPreferences(preferred_dest=["LHR"], avoided_dest=[], preferred_off=[4, 5])
        lines = [
            LineSummaryInput(
                line_id="low", line_number="100",
                total_legs=9, total_block_hours=90, total_duty_hours=110, total_duty_days=12,
                international_legs=1, domestic_legs=8, layover_count=0,
                estimated_salary_min=7200, estimated_salary_max=8000,
                destinations=["DMM"], days_off=[0],
                min_rest_interval_hours=14.5, avg_rest_interval_hours=15.0,
                rest_near_minimum_count=3,
            ),
            LineSummaryInput(
                line_id="high", line_number="411",
                total_legs=8, total_block_hours=65, total_duty_hours=85, total_duty_days=10,
                international_legs=6, domestic_legs=2, layover_count=3,
                estimated_salary_min=13500, estimated_salary_max=15000,
                destinations=["LHR", "CDG"], days_off=[4, 5, 6],
                min_rest_interval_hours=18.0, avg_rest_interval_hours=22.0,
                rest_near_minimum_count=0,
            ),
        ]
        ranked = rank_lines(lines, prefs, all_max_salary=15000)
        assert len(ranked) == 2
        assert ranked[0].line_id == "high", "Higher-scored line should rank first"
        assert ranked[0].composite_score >= ranked[1].composite_score


# ─── Auto-Bid Engine Tests ────────────────────────────────────────────────────
class TestAutoBidEngine:
    """Tests for the auto-bid preference and suggestion engine."""

    def test_engine_instantiates(self):
        from auto_bid.engine import AutoBidEngine
        engine = AutoBidEngine(user_id="u1", month="2026-06")
        assert engine is not None

    def test_score_destinations_preferred(self):
        from auto_bid.engine import AutoBidEngine, PreferenceVector
        engine = AutoBidEngine(user_id="u1", month="2026-06")
        pv = PreferenceVector(
            userId="u1",
            destinationAffinity={"LHR": 90.0, "CDG": 80.0},
        )
        score = engine._score_destinations(["LHR", "CDG", "RUH"], pv)
        assert score > 50.0

    def test_score_destinations_avoided(self):
        from auto_bid.engine import AutoBidEngine, PreferenceVector
        engine = AutoBidEngine(user_id="u1", month="2026-06")
        pv = PreferenceVector(
            userId="u1",
            destinationAffinity={"LAX": 10.0},
        )
        score = engine._score_destinations(["LAX"], pv)
        assert score < 50.0

    def test_score_regularity_returns_float(self):
        from auto_bid.engine import AutoBidEngine, PreferenceVector
        engine = AutoBidEngine(user_id="u1", month="2026-06")
        pv = PreferenceVector(userId="u1")
        score = engine._score_regularity([4, 5, 6], pv)
        assert isinstance(score, float)
        assert 0.0 <= score <= 100.0

    def test_preference_vector_defaults(self):
        from auto_bid.engine import PreferenceVector
        pv = PreferenceVector(userId="u1")
        assert pv.userId == "u1"
        assert isinstance(pv.destinationAffinity, dict)

    def test_rank_lines_returns_sorted(self):
        from auto_bid.engine import AutoBidEngine, PreferenceVector
        engine = AutoBidEngine(user_id="u1", month="2026-06")
        pv = PreferenceVector(userId="u1", destinationAffinity={"LHR": 90.0})
        lines = [
            {
                "id": "line_low", "lineNumber": "100",
                "summary": {
                    "estimatedSalaryMax": 8000, "totalBlockHours": 95,
                    "restQualityScore": 30, "internationalLegs": 1,
                    "domesticLegs": 8,
                },
                "destinations": ["DMM"],
                "daysOff": [0],
                "legs": [],
            },
            {
                "id": "line_high", "lineNumber": "411",
                "summary": {
                    "estimatedSalaryMax": 15000, "totalBlockHours": 65,
                    "restQualityScore": 88, "internationalLegs": 6,
                    "domesticLegs": 2,
                },
                "destinations": ["LHR", "CDG"],
                "daysOff": [4, 5, 6],
                "legs": [],
            },
        ]
        ranked = engine.rank_lines(lines, pv, user_mode="balanced")
        assert len(ranked) == 2
        # Higher scoring line should be first
        assert ranked[0].compositeScore >= ranked[1].compositeScore
