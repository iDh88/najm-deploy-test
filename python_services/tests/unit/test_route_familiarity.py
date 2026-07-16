"""
Unit tests — Route Familiarity Engine
Tests airport region mapping, route parsing, and similarity scoring.
"""
import pytest
from route_familiarity_engine.analyzer import (
    RouteFamiliarityAnalyzer, AIRPORT_REGIONS,
)


class TestRouteParsing:
    def setup_method(self):
        self.a = RouteFamiliarityAnalyzer()

    def test_parses_hyphen_separated(self):
        result = self.a._parse_airports("JED-DEL-JED")
        assert result == ["JED", "DEL", "JED"]

    def test_parses_arrow_separated(self):
        result = self.a._parse_airports("JED→DEL→JED")
        assert result == ["JED", "DEL", "JED"]

    def test_parses_two_leg(self):
        result = self.a._parse_airports("JED-LHR")
        assert result == ["JED", "LHR"]

    def test_ignores_non_iata(self):
        result = self.a._parse_airports("JED-AB-LHR")
        # "AB" is only 2 chars — should be excluded
        assert "AB" not in result

    def test_empty_route(self):
        result = self.a._parse_airports("")
        assert result == []


class TestRegionMapping:
    def test_del_is_south_asia(self):
        assert AIRPORT_REGIONS.get("DEL") == "south_asia"

    def test_bom_is_south_asia(self):
        assert AIRPORT_REGIONS.get("BOM") == "south_asia"

    def test_mad_is_europe_west(self):
        assert AIRPORT_REGIONS.get("MAD") == "europe_west"

    def test_nrt_is_east_asia(self):
        assert AIRPORT_REGIONS.get("NRT") == "east_asia"

    def test_saudi_airports_in_saudi_region(self):
        for code in ["RUH", "JED", "DMM", "MED"]:
            assert AIRPORT_REGIONS.get(code) == "saudi"

    def test_no_demographic_region_names(self):
        """Region names must be geographical, not demographic."""
        blocked_terms = [
            "indian", "arab", "asian", "western", "eastern",
            "muslim", "christian", "caucasian", "hispanic",
        ]
        for region in AIRPORT_REGIONS.values():
            for term in blocked_terms:
                assert term not in region.lower(), \
                    f"Demographic term '{term}' found in region '{region}'"


class TestFamiliarityScoring:
    def setup_method(self):
        self.a = RouteFamiliarityAnalyzer()

    def test_exact_match_scores_max(self):
        r = self.a.analyze("JED-DEL-JED", ["JED-DEL-JED"])
        assert r.familiarity_score >= 0.95
        assert r.familiarity_label == "High"

    def test_same_region_scores_above_zero(self):
        # DEL and BOM are both south_asia
        r = self.a.analyze("JED-DEL", ["JED-BOM", "JED-MAA"])
        assert r.familiarity_score > 0.0

    def test_unrelated_regions_score_zero(self):
        r = self.a.analyze("JED-NRT", ["JED-MAD", "JED-LHR"])
        assert r.familiarity_score == 0.0

    def test_multiple_matching_legs_boost(self):
        single = self.a.analyze("JED-DEL", ["JED-DEL"])
        multi  = self.a.analyze(
            "JED-DEL",
            ["JED-DEL", "DEL-JED", "JED-BOM", "BOM-JED", "JED-MAA"],
        )
        assert multi.familiarity_score >= single.familiarity_score

    def test_empty_line_returns_zero(self):
        r = self.a.analyze("JED-DEL", [])
        assert r.familiarity_score == 0.0
        assert r.familiarity_label == "None"

    def test_exposure_pct_ranges_0_to_1(self):
        r = self.a.analyze("JED-DEL", ["JED-DEL", "JED-RUH", "JED-BOM"])
        assert 0.0 <= r.route_exposure_pct <= 1.0

    def test_label_none_when_no_overlap(self):
        r = self.a.analyze("JED-SYD", ["JED-LHR", "JED-CDG"])
        assert r.familiarity_label == "None"

    def test_route_similarity_symmetric(self):
        ab = self.a.route_similarity("JED-DEL", "JED-BOM")
        ba = self.a.route_similarity("JED-BOM", "JED-DEL")
        assert abs(ab - ba) < 0.01   # symmetric within rounding


class TestNoDemographicInference:
    """
    Critical: The familiarity engine must never produce
    demographic labels, nationality inferences, or identity tags.
    """
    def setup_method(self):
        self.a = RouteFamiliarityAnalyzer()

    def test_report_contains_no_demographic_labels(self):
        r = self.a.analyze("JED-DEL-JED", ["JED-DEL-JED", "JED-BOM"])
        report_dict = {
            "familiarity_label": r.familiarity_label,
            "route_key":         r.route_match.route_key,
        }
        blocked = [
            "indian", "saudi", "pakistani", "arab", "asian",
            "european", "nationality", "ethnic", "origin",
        ]
        report_str = str(report_dict).lower()
        for term in blocked:
            assert term not in report_str, \
                f"Blocked term '{term}' in report: {report_dict}"

    def test_shared_regions_are_geographic_not_demographic(self):
        r = self.a.analyze("JED-DEL", ["JED-BOM"])
        for region in r.route_match.shared_regions:
            assert "_" in region or region.isalpha()
            blocked = ["indian", "arab", "ethnic", "nationality"]
            for b in blocked:
                assert b not in region.lower()
