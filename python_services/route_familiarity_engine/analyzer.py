"""
Route Familiarity Engine
Scores how familiar a crew member's CURRENT monthly line is with a given route.
Uses only schedule data — no demographic inference.
"""
from __future__ import annotations
import logging
import re
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger("cip.route_familiarity")

# Route similarity thresholds
EXACT_MATCH_SCORE     = 1.00
PARTIAL_MATCH_SCORE   = 0.75
HUB_OVERLAP_SCORE     = 0.50
REGION_OVERLAP_SCORE  = 0.30
NO_OVERLAP_SCORE      = 0.00

# Airport region mapping — pure operational geography, no demographics
AIRPORT_REGIONS: dict[str, str] = {
    # South Asia
    "DEL": "south_asia", "BOM": "south_asia", "MAA": "south_asia",
    "BLR": "south_asia", "HYD": "south_asia", "CCU": "south_asia",
    "AMD": "south_asia", "GOI": "south_asia", "COK": "south_asia",
    "TRV": "south_asia", "KHI": "south_asia", "LHE": "south_asia",
    "ISB": "south_asia", "DAC": "south_asia", "CMB": "south_asia",
    "KTM": "south_asia", "MLE": "south_asia",

    # Southeast Asia
    "KUL": "southeast_asia", "SIN": "southeast_asia", "BKK": "southeast_asia",
    "CGK": "southeast_asia", "MNL": "southeast_asia", "HAN": "southeast_asia",
    "SGN": "southeast_asia", "RGN": "southeast_asia", "PNH": "southeast_asia",

    # East Asia
    "NRT": "east_asia", "HND": "east_asia", "ICN": "east_asia",
    "PEK": "east_asia", "PVG": "east_asia", "HKG": "east_asia",
    "TPE": "east_asia", "CAN": "east_asia",

    # Europe (West)
    "LHR": "europe_west", "LGW": "europe_west", "CDG": "europe_west",
    "AMS": "europe_west", "FRA": "europe_west", "MUC": "europe_west",
    "MXP": "europe_west", "FCO": "europe_west", "MAD": "europe_west",
    "BCN": "europe_west", "ZRH": "europe_west", "VIE": "europe_west",
    "BRU": "europe_west", "LIS": "europe_west",

    # Europe (East / South)
    "IST": "europe_east", "SAW": "europe_east", "ATH": "europe_east",
    "SVO": "europe_east", "DME": "europe_east", "VKO": "europe_east",
    "WAW": "europe_east", "BUD": "europe_east", "PRG": "europe_east",

    # Africa (East)
    "NBO": "africa_east", "ADD": "africa_east", "DAR": "africa_east",
    "EBB": "africa_east", "KGL": "africa_east",

    # Africa (Other)
    "JNB": "africa_south", "CPT": "africa_south",
    "LOS": "africa_west",  "ACC": "africa_west",
    "CMN": "africa_north", "TUN": "africa_north", "ALG": "africa_north",
    "CAI": "africa_north", "KRT": "africa_north",

    # GCC / Middle East
    "DXB": "gulf", "AUH": "gulf", "DOH": "gulf", "KWI": "gulf",
    "BAH": "gulf", "MCT": "gulf", "SHJ": "gulf",
    "AMM": "levant", "BEY": "levant", "BGW": "levant", "NJF": "levant",
    "TLV": "levant", "DAM": "levant",

    # Saudi Arabia
    "RUH": "saudi", "JED": "saudi", "DMM": "saudi", "MED": "saudi",
    "TUU": "saudi", "AHB": "saudi", "GIZ": "saudi", "TIF": "saudi",
    "HOF": "saudi", "YNB": "saudi", "ELQ": "saudi",

    # Americas
    "JFK": "north_america", "EWR": "north_america", "LAX": "north_america",
    "ORD": "north_america", "IAD": "north_america", "YYZ": "north_america",
    "GRU": "latin_america", "BOG": "latin_america", "LIM": "latin_america",

    # Oceania
    "SYD": "oceania", "MEL": "oceania", "BNE": "oceania",
}


@dataclass
class RouteMatch:
    """Result of matching one route against a candidate."""
    route_key:          str
    exact_match:        bool    = False
    shared_destinations:list[str] = field(default_factory=list)
    shared_regions:     list[str] = field(default_factory=list)
    familiarity_score:  float   = 0.0
    exposure_count:     int     = 0   # how many legs on this route in current line
    label:              str     = "No overlap"


@dataclass
class CandidateFamiliarityReport:
    """Full familiarity analysis for one candidate crew member."""
    candidate_prn:      str
    target_route_key:   str
    route_match:        RouteMatch
    current_line_routes:list[str]
    total_line_legs:    int
    route_exposure_pct: float     # % of their line that matches target region
    familiarity_score:  float     # 0–1 final score
    familiarity_label:  str       # "High" | "Medium" | "Low" | "None"


class RouteFamiliarityAnalyzer:
    """
    Scores how familiar a candidate's CURRENT schedule is
    with a given target route.
    Purely operational — uses airport codes and schedule structure.
    """

    def analyze(
        self,
        target_route: str,
        candidate_line_routes: list[str],
        candidate_prn: str = "",
    ) -> CandidateFamiliarityReport:
        """
        target_route: route key like "JED-DEL" or "JED-DEL-JED"
        candidate_line_routes: all route keys in candidate's current monthly line
        """
        target_airports = self._parse_airports(target_route)
        target_regions  = {
            AIRPORT_REGIONS.get(a, "unknown") for a in target_airports
            if a not in ("JED", "RUH", "DMM")  # exclude Saudi bases (everyone has them)
        }

        best_match = RouteMatch(route_key=target_route)
        total_matching_legs = 0

        for cand_route in candidate_line_routes:
            cand_airports = self._parse_airports(cand_route)
            cand_regions  = {
                AIRPORT_REGIONS.get(a, "unknown") for a in cand_airports
                if a not in ("JED", "RUH", "DMM")
            }

            shared_dest   = list(set(target_airports) & set(cand_airports) -
                                  {"JED", "RUH", "DMM"})
            shared_reg    = list(target_regions & cand_regions -
                                  {"saudi", "gulf", "unknown"})

            score = self._score_pair(
                target_airports, cand_airports,
                shared_dest, shared_reg,
            )

            if score > best_match.familiarity_score:
                best_match = RouteMatch(
                    route_key           = cand_route,
                    exact_match         = sorted(target_airports) == sorted(cand_airports),
                    shared_destinations = shared_dest,
                    shared_regions      = shared_reg,
                    familiarity_score   = score,
                    label               = self._score_label(score),
                )

            if shared_dest or shared_reg:
                total_matching_legs += 1

        exposure_pct = (
            total_matching_legs / len(candidate_line_routes)
            if candidate_line_routes else 0.0
        )

        # Boost score when multiple legs in the line overlap
        boosted = min(
            best_match.familiarity_score + exposure_pct * 0.15,
            1.0,
        )

        return CandidateFamiliarityReport(
            candidate_prn       = candidate_prn,
            target_route_key    = target_route,
            route_match         = best_match,
            current_line_routes = candidate_line_routes,
            total_line_legs     = len(candidate_line_routes),
            route_exposure_pct  = round(exposure_pct, 3),
            familiarity_score   = round(boosted, 3),
            familiarity_label   = self._score_label(boosted),
        )

    def route_similarity(
        self, route_a: str, route_b: str
    ) -> float:
        """
        Standalone route similarity between two routes (0–1).
        Used by compatibility scorer without a full profile.
        """
        airports_a = self._parse_airports(route_a)
        airports_b = self._parse_airports(route_b)
        shared     = set(airports_a) & set(airports_b) - {"JED", "RUH", "DMM"}
        regions_a  = {AIRPORT_REGIONS.get(a, "?") for a in airports_a}
        regions_b  = {AIRPORT_REGIONS.get(a, "?") for a in airports_b}
        shared_reg = regions_a & regions_b - {"saudi", "gulf", "unknown"}
        return self._score_pair(airports_a, airports_b, list(shared), list(shared_reg))

    # ── Private ────────────────────────────────────────────────────────────────

    def _parse_airports(self, route_key: str) -> list[str]:
        """Extract airport codes from a route key like 'JED-DEL-JED'."""
        return [a.strip().upper() for a in re.split(r'[-→]', route_key) if len(a.strip()) == 3]

    def _score_pair(
        self,
        airports_a: list[str],
        airports_b: list[str],
        shared_dest: list[str],
        shared_reg: list[str],
    ) -> float:
        if sorted(airports_a) == sorted(airports_b):
            return EXACT_MATCH_SCORE
        if shared_dest:
            return PARTIAL_MATCH_SCORE + min(len(shared_dest) * 0.05, 0.15)
        if shared_reg:
            return REGION_OVERLAP_SCORE + min(len(shared_reg) * 0.05, 0.10)
        return NO_OVERLAP_SCORE

    def _score_label(self, score: float) -> str:
        if score >= 0.85: return "High"
        if score >= 0.50: return "Medium"
        if score > 0.0:   return "Low"
        return "None"
