"""filter_engine/registry.py — the catalog of every filter NAJM supports.

VISION CONTRACT (NAJM Vision — AI + Advanced Manual Filters):
  * The filtering engine is the SINGLE SOURCE OF TRUTH for search. The AI
    never bypasses it — it can only emit clauses that validate against THIS
    registry (see ai_bridge.py / schema.py).
  * Modular & extensible: adding a filter = adding one FilterDef entry here.
    Nothing else changes — the engine, the /v1/lines/filters catalog endpoint,
    the client UI (which renders the catalog dynamically) and the AI mapping
    all pick it up.
  * Honest capability: a filter is ACTIVE only when the underlying data
    exists on real `flightLines` documents today. Vision filters whose data
    the parser does not yet produce are registered as REQUIRES_FIELD with a
    note naming the missing field — visible in the catalog as "coming soon",
    never silently faked.

Line data surface (see flutter core/models/models.dart — the same shape the
parser writes to Firestore):
  top:     lineNumber, month, rank, destinations[], daysOff[] (weekday idx,
           0=Sun … 6=Sat), isActive, legs[]
  summary: totalLegs, totalBlockHours, totalDutyHours, totalDutyDays,
           internationalLegs, domesticLegs, layoverCount,
           estimatedSalaryMin/Max, salaryScore, restQualityScore,
           compositeScore
  legs[]:  flightNumber, origin, destination, legType, departureLT/arrivalLT,
           departureUTC/arrivalUTC, dutyStart/dutyEnd/releaseTime, blockHours,
           fdpHours, aircraftType, layover, layoverHours, payRate,
           estimatedPay, perDiem, legalityStatus, legalityFlags[],
           restBeforeHours, restAfterHours, sequence
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Callable, Optional


# ── Kinds ─────────────────────────────────────────────────────────────────────

class FilterKind(str, Enum):
    RANGE = "range"        # value: {"min"?: number, "max"?: number}
    SET_ANY = "set_any"    # value: [items] — line matches if ANY item present
    SET_ALL = "set_all"    # value: [items] — line matches if ALL items present
    SET_NONE = "set_none"  # value: [items] — line matches if NONE present
    BOOL = "bool"          # value: true/false — property must equal value
    ENUM = "enum"          # value: one of enum_values


class FilterStatus(str, Enum):
    ACTIVE = "active"
    REQUIRES_FIELD = "requires_field"   # data not produced by the parser yet


@dataclass(frozen=True)
class FilterDef:
    id: str
    category: str
    label: str
    kind: FilterKind
    # extractor(line_dict) -> number | bool | str | set[str] | list[number].
    # For SET_* kinds it returns the line's item-set; for RANGE a scalar OR a
    # list of scalars (list ⇒ EVERY item must satisfy the range — the crew
    # reading of "minimum layover hours" is "no layover shorter than …").
    extract: Optional[Callable[[dict], Any]] = None
    status: FilterStatus = FilterStatus.ACTIVE
    unit: str = ""
    enum_values: tuple[str, ...] = ()
    note: str = ""
    ai_hint: str = ""   # one line teaching the AI mapper when to emit this


# ── Line-reading helpers (tolerant of Firestore/JSON wire shapes) ────────────

def _summary(line: dict) -> dict:
    return line.get("summary") or {}


def _legs(line: dict) -> list[dict]:
    return line.get("legs") or []


def _num(v: Any, default: float = 0.0) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _dt(v: Any) -> Optional[datetime]:
    """Leg datetimes arrive as datetime objects (tests/service callers) or
    ISO strings (Firestore JSON wire). Naive parse; only hour-of-day is
    consumed."""
    if isinstance(v, datetime):
        return v
    if isinstance(v, str):
        try:
            return datetime.fromisoformat(v.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def _dep_hour_lt(leg: dict) -> Optional[int]:
    dt = _dt(leg.get("departureLT"))
    return dt.hour if dt else None


def _duty_hours(leg: dict) -> Optional[float]:
    s, e = _dt(leg.get("dutyStart")), _dt(leg.get("dutyEnd"))
    if s and e:
        return max((e - s).total_seconds() / 3600.0, 0.0)
    return None


# KSA weekend (daysOff indices: 0=Sun … 5=Fri, 6=Sat)
_WEEKEND = {5, 6}

_PERIOD_BOUNDS = (  # local departure hour → period label
    ("night", 0, 5), ("morning", 5, 12), ("afternoon", 12, 17),
    ("evening", 17, 22), ("night", 22, 24),
)


def _period_of(hour: int) -> str:
    for label, lo, hi in _PERIOD_BOUNDS:
        if lo <= hour < hi:
            return label
    return "night"


def _haul_of(block_hours: float) -> str:
    if block_hours < 3:
        return "short"
    if block_hours < 6:
        return "medium"
    if block_hours < 12:
        return "long"
    return "ultra_long"


# ── Derived extractors ────────────────────────────────────────────────────────

def _layover_hours_each(line: dict) -> list[float]:
    return [_num(l.get("layoverHours")) for l in _legs(line)
            if l.get("layover")]


def _rest_intervals_each(line: dict) -> list[float]:
    out = []
    for l in _legs(line):
        for key in ("restBeforeHours", "restAfterHours"):
            v = _num(l.get(key))
            if v > 0:
                out.append(v)
    return out


def _departure_periods(line: dict) -> set[str]:
    return {_period_of(h) for l in _legs(line)
            if (h := _dep_hour_lt(l)) is not None}


def _haul_types(line: dict) -> set[str]:
    return {_haul_of(_num(l.get("blockHours"))) for l in _legs(line)}


def _has_red_eye(line: dict) -> bool:
    for l in _legs(line):
        h = _dep_hour_lt(l)
        if h is not None and (h >= 22 or h < 5):
            return True
    return False


def _all_legs_legal(line: dict) -> bool:
    legs = _legs(line)
    return bool(legs) and all(
        str(l.get("legalityStatus", "legal")).lower() == "legal" for l in legs)


def _leg_scope(line: dict) -> str:
    s = _summary(line)
    intl, dom = int(_num(s.get("internationalLegs"))), int(_num(s.get("domesticLegs")))
    if intl and dom:
        return "mixed"
    if intl:
        return "international"
    return "domestic"


def _max_consecutive_duty_days(line: dict) -> Optional[float]:
    days = sorted({d.date() for l in _legs(line)
                   if (d := _dt(l.get("dutyStart")))})
    if not days:
        return None
    best = run = 1
    for prev, cur in zip(days, days[1:]):
        run = run + 1 if (cur - prev).days == 1 else 1
        best = max(best, run)
    return float(best)


def _upper(values) -> set[str]:
    return {str(v).upper() for v in (values or [])}


# ── THE REGISTRY ──────────────────────────────────────────────────────────────
# Vision categories: Schedule · Layovers · Destinations · Flights · Financial
# · Crew · Legal · Lifestyle. IDs are stable API — never rename, only add.

REGISTRY: dict[str, FilterDef] = {}


def _reg(d: FilterDef) -> None:
    if d.id in REGISTRY:
        raise ValueError(f"duplicate filter id {d.id}")
    REGISTRY[d.id] = d


# ── Schedule ─────────────────────────────────────────────────────────────────
_reg(FilterDef("days_off_count", "schedule", "Days off (count)", FilterKind.RANGE,
     lambda l: float(len(l.get("daysOff") or [])), unit="days",
     ai_hint='"10 days off" → {"min": 10}'))
_reg(FilterDef("off_weekdays_all", "schedule", "Specific weekdays off", FilterKind.SET_ALL,
     lambda l: {str(int(d)) for d in (l.get("daysOff") or [])},
     enum_values=("0", "1", "2", "3", "4", "5", "6"),
     ai_hint='"Fridays off" → ["5"]; 0=Sun … 5=Fri, 6=Sat'))
_reg(FilterDef("weekend_off", "schedule", "Weekend off (Fri+Sat)", FilterKind.BOOL,
     lambda l: _WEEKEND <= {int(d) for d in (l.get("daysOff") or [])},
     ai_hint='"weekends off" → true'))
_reg(FilterDef("duty_days", "schedule", "Number of duty days", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("totalDutyDays")), unit="days"))
_reg(FilterDef("legs_count", "schedule", "Number of sectors", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("totalLegs")), unit="sectors",
     ai_hint='"one sector" → {"max": 1}; "multi sector" → {"min": 2}'))
_reg(FilterDef("block_hours", "schedule", "Total block hours", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("totalBlockHours")), unit="hours"))
_reg(FilterDef("duty_hours", "schedule", "Total duty hours", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("totalDutyHours")), unit="hours"))
_reg(FilterDef("duty_duration_each", "schedule", "Per-duty duration", FilterKind.RANGE,
     lambda l: [h for leg in _legs(l) if (h := _duty_hours(leg)) is not None],
     unit="hours", ai_hint='"no duty longer than 10h" → {"max": 10}'))
_reg(FilterDef("max_consecutive_duty_days", "schedule", "Max consecutive duty days",
     FilterKind.RANGE, _max_consecutive_duty_days, unit="days",
     ai_hint='"max 4 days in a row" → {"max": 4}'))
_reg(FilterDef("fdp_each", "legal", "Per-duty FDP", FilterKind.RANGE,
     lambda l: [_num(leg.get("fdpHours")) for leg in _legs(l)], unit="hours"))
for _id, _label, _note in (
    ("rr_days", "RR days", "parser does not emit RR day codes"),
    ("rt_days", "RT days", "parser does not emit RT day codes"),
    ("hd_days", "HD days", "parser does not emit HD day codes"),
    ("carry_over_hours", "Carry-over hours", "carry-over not on line docs"),
):
    _reg(FilterDef(_id, "schedule", _label, FilterKind.RANGE,
         status=FilterStatus.REQUIRES_FIELD, note=_note))

# ── Layovers ─────────────────────────────────────────────────────────────────
_reg(FilterDef("has_layover", "layovers", "Has layover(s)", FilterKind.BOOL,
     lambda l: _num(_summary(l).get("layoverCount")) > 0))
_reg(FilterDef("layover_count", "layovers", "Layover count", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("layoverCount"))))
_reg(FilterDef("layover_hours_each", "layovers", "Every layover within (hours)",
     FilterKind.RANGE, _layover_hours_each, unit="hours",
     ai_hint='"min 24h layovers" → {"min": 24}'))
_reg(FilterDef("layover_cities_any", "layovers", "Layover in any of (cities)",
     FilterKind.SET_ANY,
     lambda l: _upper(leg.get("destination") for leg in _legs(l) if leg.get("layover")),
     ai_hint='"layover in London or Paris" → ["LHR","CDG"] (IATA)'))
_reg(FilterDef("layover_cities_none", "layovers", "No layover in (cities)",
     FilterKind.SET_NONE,
     lambda l: _upper(leg.get("destination") for leg in _legs(l) if leg.get("layover"))))
_reg(FilterDef("leg_scope", "layovers", "Domestic / international / mixed",
     FilterKind.ENUM, _leg_scope,
     enum_values=("domestic", "international", "mixed"),
     ai_hint='"only international" → "international"'))
for _id, _label in (("preferred_countries_any", "Countries (any)"),
                    ("avoid_countries_none", "Avoid countries")):
    _reg(FilterDef(_id, "layovers", _label, FilterKind.SET_ANY if "any" in _id
         else FilterKind.SET_NONE, status=FilterStatus.REQUIRES_FIELD,
         note="line docs carry IATA codes only; country mapping table pending"))

# ── Destinations ─────────────────────────────────────────────────────────────
_reg(FilterDef("destinations_any", "destinations", "Include destinations",
     FilterKind.SET_ANY, lambda l: _upper(l.get("destinations")),
     ai_hint='"I want Tokyo and Seoul" → ["NRT","HND","ICN"]'))
_reg(FilterDef("destinations_all", "destinations", "Must include all destinations",
     FilterKind.SET_ALL, lambda l: _upper(l.get("destinations"))))
_reg(FilterDef("destinations_none", "destinations", "Exclude destinations",
     FilterKind.SET_NONE, lambda l: _upper(l.get("destinations")),
     ai_hint='"exclude India" → Indian airport codes'))
_reg(FilterDef("origins_any", "destinations", "Departs from (airports)",
     FilterKind.SET_ANY,
     lambda l: _upper(leg.get("origin") for leg in _legs(l))))

# ── Flights ──────────────────────────────────────────────────────────────────
_reg(FilterDef("haul_types_any", "flights", "Haul length (any of)", FilterKind.SET_ANY,
     _haul_types, enum_values=("short", "medium", "long", "ultra_long"),
     ai_hint='"long haul" → ["long","ultra_long"]'))
_reg(FilterDef("departure_periods_any", "flights", "Departure time of day (any of)",
     FilterKind.SET_ANY, _departure_periods,
     enum_values=("morning", "afternoon", "evening", "night"),
     ai_hint='"morning flights" → ["morning"]'))
_reg(FilterDef("red_eye", "flights", "Contains red-eye departure", FilterKind.BOOL,
     _has_red_eye, ai_hint='"no red eyes" → false'))
_reg(FilterDef("flight_numbers_any", "flights", "Specific flights", FilterKind.SET_ANY,
     lambda l: _upper(leg.get("flightNumber") for leg in _legs(l))))
_reg(FilterDef("aircraft_types_any", "flights", "Aircraft type (any of)",
     FilterKind.SET_ANY,
     lambda l: _upper(leg.get("aircraftType") for leg in _legs(l)
                      if leg.get("aircraftType"))))
for _id, _label, _note in (
    ("deadhead", "Deadhead legs", "parser does not flag deadhead legs"),
    ("training_duty", "Training duties", "duty-type codes not parsed"),
    ("reserve_duty", "Reserve", "duty-type codes not parsed"),
    ("standby_duty", "Standby", "duty-type codes not parsed"),
):
    _reg(FilterDef(_id, "flights", _label, FilterKind.BOOL,
         status=FilterStatus.REQUIRES_FIELD, note=_note))

# ── Financial ────────────────────────────────────────────────────────────────
_reg(FilterDef("salary_min", "financial", "Minimum estimated salary", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("estimatedSalaryMin")), unit="SAR",
     ai_hint='"at least 20,000 SAR" → {"min": 20000} (conservative: line\'s LOW estimate must clear it)'))
_reg(FilterDef("salary_max", "financial", "Maximum estimated salary", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("estimatedSalaryMax")), unit="SAR"))
_reg(FilterDef("per_diem_total", "financial", "Total per-diem", FilterKind.RANGE,
     lambda l: sum(_num(leg.get("perDiem")) for leg in _legs(l)), unit="SAR"))
_reg(FilterDef("bonus_eligible", "financial", "Bonus eligible", FilterKind.BOOL,
     status=FilterStatus.REQUIRES_FIELD, note="bonus flags not on line docs"))

# ── Crew ─────────────────────────────────────────────────────────────────────
_reg(FilterDef("rank_any", "crew", "Line rank (any of)", FilterKind.SET_ANY,
     lambda l: _upper([l.get("rank")]) if l.get("rank") else set(),
     ai_hint='"captain lines" → ["CA"]'))
_reg(FilterDef("crew_combination", "crew", "Preferred crew combinations",
     FilterKind.SET_ANY, status=FilterStatus.REQUIRES_FIELD,
     note="pairing crew composition not in line docs"))

# ── Legal ────────────────────────────────────────────────────────────────────
_reg(FilterDef("legal_only", "legal", "Only fully-legal lines", FilterKind.BOOL,
     _all_legs_legal, ai_hint='"only legal schedules" → true'))
_reg(FilterDef("rest_interval_each", "legal", "Every rest interval within (hours)",
     FilterKind.RANGE, _rest_intervals_each, unit="hours",
     ai_hint='"minimum 14h rest" → {"min": 14}'))
_reg(FilterDef("rest_quality_score", "legal", "Rest-quality score", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("restQualityScore")), unit="0–100",
     ai_hint='"minimum fatigue" → {"min": 70} (higher score = better rest)'))
_reg(FilterDef("fatigue_score", "legal", "Fatigue score (intelligence)",
     FilterKind.RANGE, status=FilterStatus.REQUIRES_FIELD,
     note="lives on PDF-intelligence line analyses, not roster line docs; "
          "join planned (see VISION_GAP_ANALYSIS)"))

# ── Lifestyle (composed conveniences the AI maps colloquialisms onto) ────────
_reg(FilterDef("composite_score", "lifestyle", "Overall line score", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("compositeScore")), unit="0–100"))
_reg(FilterDef("salary_score", "lifestyle", "Salary score", FilterKind.RANGE,
     lambda l: _num(_summary(l).get("salaryScore")), unit="0–100"))
_reg(FilterDef("approval_probability", "lifestyle", "Approval probability",
     FilterKind.RANGE, status=FilterStatus.REQUIRES_FIELD,
     note="prediction model output — a ranking signal (auto_bid), not yet a "
          "stored line field"))


# ── Catalog / lookup API ─────────────────────────────────────────────────────

def get(filter_id: str) -> Optional[FilterDef]:
    return REGISTRY.get(filter_id)


def active_ids() -> list[str]:
    return sorted(i for i, d in REGISTRY.items()
                  if d.status is FilterStatus.ACTIVE)


def catalog() -> list[dict]:
    """Serializable registry for GET /v1/lines/filters — the client renders
    its Manual-Mode UI from this, so new filters need no app release."""
    out = []
    for d in sorted(REGISTRY.values(), key=lambda d: (d.category, d.id)):
        out.append({
            "id": d.id,
            "category": d.category,
            "label": d.label,
            "kind": d.kind.value,
            "status": d.status.value,
            "unit": d.unit,
            "enum_values": list(d.enum_values),
            "note": d.note,
        })
    return out
