"""
legality/rules_source.py — SINGLE SOURCE OF TRUTH for GACA FTL rule values.

Resolves audit findings P0-1 and P0-2:

  P0-1  Three modules previously carried independent, conflicting FTL values
        (legality/engine.py: 14h/15h rest · rest_engine/rules.py: 10h/11h ·
        intelligence/utils/legality_checker.py: 10h/11h), producing opposite
        legal verdicts on identical input. Every engine now derives its
        thresholds from THIS module.

  P0-2  The Admin Panel writes the Firestore `legalityRules` collection, which
        no engine read. This module loads that collection at runtime (TTL
        cache, fail-safe fallback), making the admin editor authoritative.

REGULATORY PROVENANCE — read before editing:
  The canonical defaults below are the values the project itself cites as
  "Official GOM Section 7.5.3 Table (F)" (see the header of legality/engine.py
  as originally authored), and they match the Flutter client constants and the
  AI grounding block. They are also the MOST CONSERVATIVE of the value sets
  found in the repository (higher rest requirement = fail-safe for a fatigue
  tool: a false "violation" is an inconvenience; a false "legal" is a safety
  risk). The divergent 10h/11h set carried no citation.

  ▶ These defaults still REQUIRE owner confirmation against the current
    GACA/Saudia GOM before launch — see OWNER_DECISION_REQUEST.md (ODR-001).
    Confirmed values can be applied WITHOUT a code change by editing the
    `legalityRules` collection in the Admin Panel (seed the collection with
    scripts/seed_legality_rules.py).

FDP note (ODR-002): the repo contains two FDP models — flat category caps
  (12h dom / 13h intl / 14h aug) and a per-sector table (14:00 → 11:30 for
  1→6 sectors, with early-report/WOCL reductions). Until the owner confirms
  which is GOM-authoritative, `fdp_limit_minutes()` enforces the CONSERVATIVE
  INTERSECTION (the lower of the two) so no engine can be more permissive
  than either project-native rule set.

Design constraints honored here:
  * Fail-safe: any Firestore/import/parse error → canonical defaults, logged.
  * Sanity clamps only (positive, bounded) — engineering guards against admin
    typos (e.g. 0h rest), NOT regulatory judgments. Rejected overrides are
    logged and the canonical default is retained for that field.
  * Thread-safe TTL cache so the hot path costs no Firestore reads.
"""
from __future__ import annotations

import logging
import os
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Optional

logger = logging.getLogger("cip.legality.rules_source")

# ═══════════════════════════════════════════════════════════════════════════
# CANONICAL DEFAULTS — GOM 7.5.3 Table (F) set as carried by this repository.
# Owner confirmation tracked in OWNER_DECISION_REQUEST.md (ODR-001).
# All rest measured from RELEASE TIME (block-in + release buffer).
# ═══════════════════════════════════════════════════════════════════════════

CANONICAL_DEFAULTS: dict[str, float] = {
    # ── Rest minimums (hours) ────────────────────────────────────────────
    "min_rest_domestic_hours":        14.0,   # GOM 7.5.3 Table (F) — un-augmented
    "min_rest_international_hours":   15.0,   # GOM 7.5.3 Table (F) — un-augmented
    "min_rest_augmented_hours":       18.0,   # GOM 7.5.3 Table (F) — augmented, all stations
    "min_rest_emergency_hours":       10.0,   # GOM 7.5.3 — GM approval + 8h sleep
    "min_uninterrupted_sleep_hours":   8.0,
    "release_buffer_minutes":         30.0,   # duty end → release time

    # ── FDP flat caps (hours) — see ODR-002 ─────────────────────────────
    "max_fdp_domestic_hours":         12.0,
    "max_fdp_international_hours":    13.0,
    "max_fdp_augmented_hours":        14.0,

    # ── Daily block (hours) ──────────────────────────────────────────────
    "max_daily_block_hours":           8.0,

    # ── Sector limits per FDP ────────────────────────────────────────────
    "max_sectors_short_haul":          4,
    "max_sectors_long_haul":           2,
    "long_haul_threshold_hours":       6.0,

    # ── Cumulative limits ────────────────────────────────────────────────
    "max_7day_flight_hours":          60.0,
    "min_7day_days_off":               1,
    "max_28day_flight_hours":        100.0,
    "max_monthly_duty_hours":        120.0,
    "max_annual_flight_hours":       900.0,   # ODR-001: 900 (GOM set) vs 1000 (uncited set)

    # ── Layover ──────────────────────────────────────────────────────────
    "min_layover_away_from_base_hours": 36.0,
    "away_from_base_trigger_hours":     72.0,

    # ── Standby (GOM 7.5.4) ──────────────────────────────────────────────
    "standby_max_hours":              14.0,
    "standby_report_minutes":         60,

    # ── Warning threshold (fraction of a limit that triggers amber) ─────
    "warning_threshold_pct":           0.90,
}

# Per-sector FDP base table (minutes), sectors 1..6 — present identically in
# rest_engine/rules.py and intelligence/utils/legality_checker.py. Kept as a
# second constraint under the conservative intersection (ODR-002).
FDP_SECTOR_TABLE_MINUTES: dict[int, int] = {
    1: 840,  # 14:00
    2: 810,  # 13:30
    3: 780,  # 13:00
    4: 750,  # 12:30
    5: 720,  # 12:00
    6: 690,  # 11:30
}
FDP_EARLY_SIGNIN_REDUCTION_MINS = 30   # report before 06:00 local
FDP_WOCL_REDUCTION_MINS         = 60   # WOCL penetration
FDP_ABSOLUTE_FLOOR_MINS         = 480  # never reduced below 8:00

# WOCL window (local time) — identical in both prior engines.
WOCL_START_HOUR = 2
WOCL_END_HOUR   = 6   # exclusive upper bound label 05:59

RULES_BASE_VERSION = "GACA-GOM-7.5.3-TF"

# ═══════════════════════════════════════════════════════════════════════════
# SANITY BOUNDS — engineering typo guards only (not regulatory limits).
# An override outside its bound is REJECTED (logged; default retained).
# ═══════════════════════════════════════════════════════════════════════════

_SANITY_BOUNDS: dict[str, tuple[float, float]] = {
    "min_rest_domestic_hours":         (1.0, 48.0),
    "min_rest_international_hours":    (1.0, 48.0),
    "min_rest_augmented_hours":        (1.0, 48.0),
    "min_rest_emergency_hours":        (1.0, 48.0),
    "min_uninterrupted_sleep_hours":   (1.0, 24.0),
    "release_buffer_minutes":          (0.0, 240.0),
    "max_fdp_domestic_hours":          (4.0, 24.0),
    "max_fdp_international_hours":     (4.0, 24.0),
    "max_fdp_augmented_hours":         (4.0, 24.0),
    "max_daily_block_hours":           (1.0, 20.0),
    "max_sectors_short_haul":          (1, 12),
    "max_sectors_long_haul":           (1, 12),
    "long_haul_threshold_hours":       (1.0, 20.0),
    "max_7day_flight_hours":           (10.0, 168.0),
    "min_7day_days_off":               (0, 7),
    "max_28day_flight_hours":          (20.0, 400.0),
    "max_monthly_duty_hours":          (20.0, 500.0),
    "max_annual_flight_hours":         (100.0, 4000.0),
    "min_layover_away_from_base_hours": (0.0, 240.0),
    "away_from_base_trigger_hours":    (0.0, 720.0),
    "standby_max_hours":               (1.0, 48.0),
    "standby_report_minutes":          (5, 720),
    "warning_threshold_pct":           (0.50, 0.999),
}

_INT_FIELDS = {"max_sectors_short_haul", "max_sectors_long_haul",
               "min_7day_days_off", "standby_report_minutes"}


@dataclass(frozen=True)
class EffectiveRules:
    """Immutable snapshot of the effective FTL values + provenance."""
    values: dict[str, float]
    version: str                       # e.g. "GACA-GOM-7.5.3-TF (defaults)"
    source: str                        # "defaults" | "firestore-override"
    overridden_fields: tuple = ()
    loaded_at: float = field(default_factory=time.time)

    def get(self, key: str) -> float:
        return self.values[key]

    # Convenience minute accessors used by the minute-based engines.
    def minutes(self, hours_key: str) -> int:
        return int(round(self.values[hours_key] * 60))


# ── Cache state ──────────────────────────────────────────────────────────────
_lock = threading.Lock()
_cached: Optional[EffectiveRules] = None
_cached_at: float = 0.0


def _ttl_seconds() -> float:
    try:
        return float(os.getenv("LEGALITY_RULES_TTL_SECONDS", "300"))
    except ValueError:
        return 300.0


def invalidate_cache() -> None:
    """Force the next get_effective_rules() to re-read Firestore (tests/admin)."""
    global _cached, _cached_at
    with _lock:
        _cached = None
        _cached_at = 0.0


def _validated(field_name: str, raw: Any) -> Optional[float]:
    """Return a sane numeric value for `field_name`, or None if rejected."""
    try:
        value = float(raw)
    except (TypeError, ValueError):
        logger.warning("legalityRules/%s: non-numeric value %r rejected", field_name, raw)
        return None
    lo, hi = _SANITY_BOUNDS.get(field_name, (float("-inf"), float("inf")))
    if not (lo <= value <= hi):
        logger.warning(
            "legalityRules/%s: value %s outside sanity bounds [%s, %s] — "
            "rejected, canonical default retained", field_name, value, lo, hi)
        return None
    if field_name in _INT_FIELDS:
        value = float(int(value))
    return value


def _load_overrides_from_firestore() -> dict[str, float]:
    """Read `legalityRules` docs (doc id == canonical field name, `value` field).

    Any failure returns {} — the engines then run on canonical defaults.
    """
    from utils.firebase import get_firestore  # lazy: keeps import side-effect free
    overrides: dict[str, float] = {}
    for doc in get_firestore().collection("legalityRules").stream():
        field_name = doc.id
        if field_name not in CANONICAL_DEFAULTS:
            logger.warning("legalityRules/%s: unknown rule id — ignored", field_name)
            continue
        data = doc.to_dict() or {}
        if data.get("enabled") is False:
            continue
        value = _validated(field_name, data.get("value"))
        if value is not None and value != CANONICAL_DEFAULTS[field_name]:
            overrides[field_name] = value
    return overrides


def get_effective_rules(force_refresh: bool = False) -> EffectiveRules:
    """Canonical defaults merged with admin overrides. NEVER raises.

    Fail-safe: on any error the canonical defaults are returned (and the
    failure is cached for the TTL so a broken Firestore doesn't get hammered).
    """
    global _cached, _cached_at
    now = time.time()
    with _lock:
        if (not force_refresh and _cached is not None
                and now - _cached_at < _ttl_seconds()):
            return _cached

        values = dict(CANONICAL_DEFAULTS)
        overridden: tuple = ()
        source = "defaults"
        try:
            overrides = _load_overrides_from_firestore()
            if overrides:
                values.update(overrides)
                overridden = tuple(sorted(overrides))
                source = "firestore-override"
                logger.info("FTL overrides active for: %s", ", ".join(overridden))
        except Exception as exc:  # noqa: BLE001 — deliberate fail-safe boundary
            logger.warning(
                "legalityRules load failed (%s) — running on canonical defaults", exc)

        version = (f"{RULES_BASE_VERSION} (+{len(overridden)} admin override"
                   f"{'s' if len(overridden) != 1 else ''})"
                   if overridden else f"{RULES_BASE_VERSION} (defaults)")
        _cached = EffectiveRules(values=values, version=version,
                                 source=source, overridden_fields=overridden)
        _cached_at = now
        return _cached


# ═══════════════════════════════════════════════════════════════════════════
# Shared derived calculations used by ALL engines
# ═══════════════════════════════════════════════════════════════════════════

def min_rest_minutes(is_international: bool, is_augmented: bool = False,
                     rules: Optional[EffectiveRules] = None) -> int:
    """Minimum rest in minutes for a leg category (single shared definition)."""
    r = rules or get_effective_rules()
    if is_augmented:
        return r.minutes("min_rest_augmented_hours")
    if is_international:
        return r.minutes("min_rest_international_hours")
    return r.minutes("min_rest_domestic_hours")


def fdp_limit_minutes(num_sectors: int, report_local_hour: int = 8,
                      wocl_penetration: bool = False,
                      is_international: bool = False,
                      is_augmented: bool = False,
                      rules: Optional[EffectiveRules] = None) -> int:
    """CONSERVATIVE-INTERSECTION FDP limit (ODR-002).

    Returns min(flat category cap, sector-table limit) so no consumer is more
    permissive than either project-native rule set, then applies the shared
    early-sign-in / WOCL reductions and the absolute 8:00 floor.
    """
    r = rules or get_effective_rules()
    table = FDP_SECTOR_TABLE_MINUTES.get(
        max(1, min(num_sectors, 6)), FDP_SECTOR_TABLE_MINUTES[6])
    if is_augmented:
        flat = r.minutes("max_fdp_augmented_hours")
    elif is_international:
        flat = r.minutes("max_fdp_international_hours")
    else:
        flat = r.minutes("max_fdp_domestic_hours")
    base = min(table, flat)
    if report_local_hour < 6:
        base -= FDP_EARLY_SIGNIN_REDUCTION_MINS
    if wocl_penetration:
        base -= FDP_WOCL_REDUCTION_MINS
    return max(base, FDP_ABSOLUTE_FLOOR_MINS)


# Human/Admin metadata for seeding + the /v1/legality/rules endpoint.
RULE_METADATA: dict[str, dict[str, str]] = {
    "min_rest_domestic_hours":        {"description": "Minimum rest — domestic (from release time)", "unit": "hours", "legType": "domestic", "severity": "blocking"},
    "min_rest_international_hours":   {"description": "Minimum rest — international (from release time)", "unit": "hours", "legType": "international", "severity": "blocking"},
    "min_rest_augmented_hours":       {"description": "Minimum rest — augmented crew (all stations)", "unit": "hours", "legType": "both", "severity": "blocking"},
    "min_rest_emergency_hours":       {"description": "Emergency minimum rest (GM approval + 8h sleep)", "unit": "hours", "legType": "both", "severity": "blocking"},
    "min_uninterrupted_sleep_hours":  {"description": "Minimum uninterrupted sleep within rest", "unit": "hours", "legType": "both", "severity": "blocking"},
    "release_buffer_minutes":         {"description": "Release-time buffer added after duty end", "unit": "minutes", "legType": "both", "severity": "blocking"},
    "max_fdp_domestic_hours":         {"description": "Maximum FDP — domestic (flat cap; sector table also applies)", "unit": "hours", "legType": "domestic", "severity": "blocking"},
    "max_fdp_international_hours":    {"description": "Maximum FDP — international (flat cap; sector table also applies)", "unit": "hours", "legType": "international", "severity": "blocking"},
    "max_fdp_augmented_hours":        {"description": "Maximum FDP — augmented crew", "unit": "hours", "legType": "both", "severity": "blocking"},
    "max_daily_block_hours":          {"description": "Maximum daily block (flight) hours", "unit": "hours", "legType": "both", "severity": "blocking"},
    "max_sectors_short_haul":         {"description": "Maximum sectors per FDP — short haul", "unit": "sectors", "legType": "both", "severity": "blocking"},
    "max_sectors_long_haul":          {"description": "Maximum sectors per FDP — long haul", "unit": "sectors", "legType": "both", "severity": "blocking"},
    "long_haul_threshold_hours":      {"description": "Block hours above which a sector is long-haul", "unit": "hours", "legType": "both", "severity": "blocking"},
    "max_7day_flight_hours":          {"description": "Maximum flight hours in any 7 days", "unit": "hours", "legType": "both", "severity": "blocking"},
    "min_7day_days_off":              {"description": "Minimum days off in any 7 days", "unit": "days", "legType": "both", "severity": "blocking"},
    "max_28day_flight_hours":         {"description": "Maximum flight hours in any 28 days", "unit": "hours", "legType": "both", "severity": "blocking"},
    "max_monthly_duty_hours":         {"description": "Maximum duty hours per calendar month", "unit": "hours", "legType": "both", "severity": "blocking"},
    "max_annual_flight_hours":        {"description": "Maximum flight hours per year", "unit": "hours", "legType": "both", "severity": "blocking"},
    "min_layover_away_from_base_hours": {"description": "Minimum layover when away from base", "unit": "hours", "legType": "both", "severity": "blocking"},
    "away_from_base_trigger_hours":   {"description": "Away-from-base hours that trigger the layover minimum", "unit": "hours", "legType": "both", "severity": "warning"},
    "standby_max_hours":              {"description": "Maximum standby duration (GOM 7.5.4)", "unit": "hours", "legType": "both", "severity": "blocking"},
    "standby_report_minutes":         {"description": "Standby report-within time (GOM 7.5.4)", "unit": "minutes", "legType": "both", "severity": "blocking"},
    "warning_threshold_pct":          {"description": "Fraction of a limit that triggers an amber warning", "unit": "fraction", "legType": "both", "severity": "warning"},
}
