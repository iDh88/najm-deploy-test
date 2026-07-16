"""roster_sync/import_service.py — normalized roster → the platform's line doc.

Spec: "Everything must work from the synchronized roster without requiring
manual uploads." The way that is literally true: the import writes the SAME
`flightLines` document shape the rest of the platform already consumes
(lines screen, filter engine, ranking, trade/auto-bid readers), fully
ENRICHED so no engine needs a second pass:

  legs   ← rest-before/after from inter-duty gaps · dutyStart/End derived
           (report 60 min before departure, release 30 min after arrival,
            per GOM practice already encoded in legality.DutyPeriod docs)
           · per-duty FDP · per-leg legality verdict from the CANONICAL
           legality engine (P0 single source — same verdicts as
           /v1/legality/check)
  summary← block/duty totals · intl/domestic counts · layover count ·
           salary estimate via the salary engine's quick-estimate rules ·
           rest-quality score via the rest engine's safety scorer ·
           composite via the ranking components
  line   ← destinations · daysOff (weekday indices with zero duties across
           the whole period — the platform's existing dual-read semantics)
           · source/provider/version provenance

Previous active roster docs for the same user+provider+period are marked
isActive=false (never deleted — "Do not erase previous roster"), so a failed
or duplicate import leaves the last good roster untouched.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta
from typing import Optional

from legality.engine import DutyPeriod, LegType, LegalityEngine
from legality.rules_source import get_effective_rules
from rest_engine.calculator import DutyInput
from rest_engine.scoring import SafetyScorer
from salary.calculator import (
    DOMESTIC_LAYOVER_RATE,
    INTERNATIONAL_LAYOVER_RATE,
    SalaryCalculator,
)

from .schema import NormalizedLeg, NormalizedRoster

logger = logging.getLogger("cip.roster_sync")

_REPORT_BEFORE = timedelta(minutes=60)
_RELEASE_AFTER = timedelta(minutes=30)

_legality = LegalityEngine()
_safety = SafetyScorer()
_salary = SalaryCalculator()


def _weekday_ksa(dt: datetime) -> int:
    """Platform convention: 0=Sun … 6=Sat (python: Mon=0 … Sun=6)."""
    return (dt.weekday() + 1) % 7


def _duty_bounds(leg: NormalizedLeg) -> tuple[datetime, datetime]:
    start = leg.dutyStart or (leg.departureLT - _REPORT_BEFORE)
    end = leg.dutyEnd or (leg.arrivalLT + _RELEASE_AFTER)
    return start, end


def build_line_doc(user_id: str, provider_id: str, version: int,
                   roster: NormalizedRoster, rank: str = "") -> dict:
    """Pure function: NormalizedRoster → flightLines document dict."""
    legs_sorted = sorted(roster.legs, key=lambda l: l.departureLT)
    eff = get_effective_rules()

    # ── per-leg derivation ────────────────────────────────────────────────
    leg_docs: list[dict] = []
    duty_periods: list[DutyPeriod] = []
    for i, leg in enumerate(legs_sorted):
        d_start, d_end = _duty_bounds(leg)
        prev_end = _duty_bounds(legs_sorted[i - 1])[1] if i else None
        next_start = _duty_bounds(legs_sorted[i + 1])[0] \
            if i + 1 < len(legs_sorted) else None
        rest_before = max((d_start - prev_end).total_seconds() / 3600, 0.0) \
            if prev_end else 0.0
        rest_after = max((next_start - d_end).total_seconds() / 3600, 0.0) \
            if next_start else 0.0
        fdp_hours = round((d_end - d_start).total_seconds() / 3600, 2)

        duty_periods.append(DutyPeriod(
            id=f"leg_{i}",
            flight_number=leg.flightNumber,
            origin=leg.origin, destination=leg.destination,
            leg_type=LegType(leg.legType),
            duty_start=d_start, duty_end=d_end,
            release_time=d_end,
            block_hours=leg.blockHours, fdp_hours=fdp_hours,
        ))
        leg_docs.append({
            "id": f"leg_{i}", "lineId": "",   # backfilled below
            "flightNumber": leg.flightNumber,
            "origin": leg.origin, "destination": leg.destination,
            "legType": leg.legType,
            "departureLT": leg.departureLT.isoformat(),
            "arrivalLT": leg.arrivalLT.isoformat(),
            "departureUTC": leg.departureLT.isoformat(),   # feeds carry LT;
            "arrivalUTC": leg.arrivalLT.isoformat(),       # UTC join = Phase 2
            "dutyStart": d_start.isoformat(),
            "dutyEnd": d_end.isoformat(),
            "releaseTime": (d_end + _RELEASE_AFTER).isoformat(),
            "blockHours": leg.blockHours,
            "fdpHours": fdp_hours,
            "aircraftType": leg.aircraftType,
            "layover": leg.layover or rest_after >= 8.0 and
            leg.destination != legs_sorted[0].origin and rest_after < 96,
            "layoverHours": leg.layoverHours or (
                round(rest_after, 1) if rest_after >= 8.0 else 0.0),
            "payRate": 0.0, "estimatedPay": 0.0, "perDiem": 0.0,
            "legalityStatus": "legal",       # refined below
            "legalityFlags": [],
            "restBeforeHours": round(rest_before, 2),
            "restAfterHours": round(rest_after, 2),
            "sequence": i,
        })

    # ── canonical legality per whole schedule (same engine as /v1/legality) ─
    try:
        result = _legality.check_schedule(duty_periods)
        flagged: dict[str, list[str]] = {}
        for v in list(result.violations) + list(result.warnings):
            for leg_id in v.affected_leg_ids:
                flagged.setdefault(leg_id, []).append(v.rule_id)
        blocking_ids = {leg_id for v in result.violations
                        for leg_id in v.affected_leg_ids}
        for doc in leg_docs:
            ids = flagged.get(doc["id"], [])
            if ids:
                doc["legalityFlags"] = ids
                doc["legalityStatus"] = ("violation"
                                         if doc["id"] in blocking_ids
                                         else "warning")
    except Exception:
        logger.exception("legality enrichment failed — legs default legal, "
                         "flag recorded")
        for doc in leg_docs:
            doc["legalityFlags"] = ["ENRICHMENT_UNAVAILABLE"]

    # ── summary + scores ─────────────────────────────────────────────────
    total_block = round(sum(l.blockHours for l in legs_sorted), 2)
    total_duty = round(sum(d["fdpHours"] for d in leg_docs), 2)
    intl = sum(1 for l in legs_sorted if l.legType == "international")
    dom = len(legs_sorted) - intl
    duty_days = len({_duty_bounds(l)[0].date() for l in legs_sorted})
    dom_lay = sum(d["layoverHours"] for d, l in zip(leg_docs, legs_sorted)
                  if d["layover"] and l.legType == "domestic")
    intl_lay = sum(d["layoverHours"] for d, l in zip(leg_docs, legs_sorted)
                   if d["layover"] and l.legType == "international")

    try:
        # Same rules the salary engine's quick-estimate endpoint applies:
        # productivity allowance (official block-hour bands) + layover
        # expenses. Bonus/overtime need the user's basic salary → the 15%
        # headroom mirrors the app's existing min/max presentation.
        _, prod_amount, _ = _salary._productivity(total_block)
        layover_pay = (dom_lay * DOMESTIC_LAYOVER_RATE
                       + intl_lay * INTERNATIONAL_LAYOVER_RATE)
        variable = prod_amount + layover_pay
        salary_min = round(variable, 0)
        salary_max = round(variable * 1.15, 0)   # bonus/overtime headroom
    except Exception:
        logger.exception("salary enrichment failed — estimates zeroed")
        salary_min = salary_max = 0.0

    rest_quality = _rest_quality_score(leg_docs, legs_sorted)
    salary_score = min(100.0, (salary_min / 250.0)) if salary_min else 0.0
    composite = round(0.5 * salary_score + 0.5 * rest_quality, 1)

    # ── daysOff: weekdays with zero duties across the period ────────────
    duty_weekdays = {_weekday_ksa(_duty_bounds(l)[0]) for l in legs_sorted}
    days_off = sorted(set(range(7)) - duty_weekdays)

    line_id = f"roster_{user_id}_{roster.period}_{provider_id}_v{version}"
    for d in leg_docs:
        d["lineId"] = line_id

    return {
        "id": line_id,
        "lineNumber": f"SYNC-{roster.period}-v{version}",
        "month": roster.period,
        "userId": user_id,
        "rank": rank,
        "uploadedAt": datetime.utcnow().isoformat(),
        "validationStatus": "synced",
        "isActive": True,
        "source": provider_id,
        "rosterVersion": version,
        "destinations": sorted({l.destination for l in legs_sorted}),
        "daysOff": days_off,
        "summary": {
            "totalLegs": len(legs_sorted),
            "totalBlockHours": total_block,
            "totalDutyHours": total_duty,
            "totalDutyDays": duty_days,
            "internationalLegs": intl,
            "domesticLegs": dom,
            "layoverCount": sum(1 for d in leg_docs if d["layover"]),
            "estimatedSalaryMin": salary_min,
            "estimatedSalaryMax": salary_max,
            "salaryScore": round(salary_score, 1),
            "restQualityScore": rest_quality,
            "compositeScore": composite,
        },
        "legs": leg_docs,
    }


def _rest_quality_score(leg_docs: list[dict],
                        legs: list[NormalizedLeg]) -> float:
    """Average of the rest engine's composite safety score across duties
    (same scorer the trade recommendations use)."""
    scores: list[float] = []
    for doc, leg in zip(leg_docs, legs):
        try:
            d_start = datetime.fromisoformat(doc["dutyStart"])
            d_end = datetime.fromisoformat(doc["dutyEnd"])
            nxt = (d_end + timedelta(hours=doc["restAfterHours"])
                   if doc["restAfterHours"] else None)
            inp = DutyInput(
                duty_start_utc=d_start, duty_end_utc=d_end,
                report_local_hour=d_start.hour,
                num_operating_legs=1,
                is_international=(leg.legType == "international"),
                next_duty_start_utc=nxt,
            )
            rest_before_mins = int(doc["restBeforeHours"] * 60) or 900
            scores.append(_safety.score(
                inp, rest_before_mins=rest_before_mins).safety_score)
        except Exception:
            logger.exception("rest scoring failed for %s",
                             doc.get("flightNumber"))
    return round(sum(scores) / len(scores), 1) if scores else 0.0


# ── Firestore write path ─────────────────────────────────────────────────────

def deactivate_previous(db, user_id: str, provider_id: str,
                        period: str) -> int:
    """Mark prior synced roster docs inactive (kept — version history)."""
    q = (db.collection("flightLines")
         .where("userId", "==", user_id)
         .where("source", "==", provider_id)
         .where("month", "==", period))
    count = 0
    for doc in q.stream():
        if (doc.to_dict() or {}).get("isActive"):
            db.collection("flightLines").document(doc.id).update(
                {"isActive": False})
            count += 1
    return count


def write_line(db, line_doc: dict) -> str:
    db.collection("flightLines").document(line_doc["id"]).set(line_doc)
    return line_doc["id"]
