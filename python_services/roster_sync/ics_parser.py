"""roster_sync/ics_parser.py — roster extraction from an iCalendar feed.

Why ICS: it is a real, documented standard (RFC 5545) that several crew
portals expose as a personal subscription URL. Parsing it violates no terms
and needs no scraping — the user pastes THEIR feed URL, the device fetches
the text, and this module turns VEVENTs into a NormalizedRoster.

Scope, stated honestly:
  * Implements the RFC subset rosters use: line unfolding, VEVENT blocks,
    DTSTART/DTEND (with basic TZID/UTC/date-only handling), SUMMARY,
    DESCRIPTION, LOCATION.
  * Flight extraction is pattern-based and CONFIGURABLE per airline
    (default patterns cover the common "SV123 JED-LHR" style plus
    origin/destination in LOCATION). Events that don't match any flight
    pattern are skipped and counted — never guessed.
  * No network: callers hand us text. (The device fetches; see the Flutter
    RosterSyncService.)
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

from .schema import NormalizedLeg, NormalizedRoster


# ── Line-level RFC handling ──────────────────────────────────────────────────

def _unfold(text: str) -> list[str]:
    """RFC 5545 §3.1: a CRLF followed by a space/tab continues the line."""
    out: list[str] = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and out:
            out[-1] += raw[1:]
        else:
            out.append(raw)
    return [l for l in out if l.strip()]


def _prop(line: str) -> tuple[str, dict, str]:
    """'DTSTART;TZID=Asia/Riyadh:20260610T083000' → (name, params, value)."""
    head, _, value = line.partition(":")
    parts = head.split(";")
    name = parts[0].upper()
    params = {}
    for p in parts[1:]:
        k, _, v = p.partition("=")
        params[k.upper()] = v
    return name, params, value


def _parse_dt(value: str, params: dict) -> Optional[datetime]:
    value = value.strip()
    try:
        if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
            return datetime.strptime(value, "%Y%m%d")
        if value.endswith("Z"):
            return datetime.strptime(value, "%Y%m%dT%H%M%SZ")  # naive UTC
        dt = datetime.strptime(value, "%Y%m%dT%H%M%S")
        tzid = params.get("TZID")
        if tzid:
            try:
                # convert to naive local of the event's own zone — roster
                # times are consumed as local times downstream
                return dt.replace(tzinfo=ZoneInfo(tzid)).replace(tzinfo=None)
            except Exception:  # unknown zone → keep as-is
                return dt
        return dt
    except ValueError:
        return None


# ── Flight extraction patterns (configurable) ────────────────────────────────

@dataclass
class ExtractionProfile:
    """Airline-adaptable patterns. The default profile covers the common
    'SV123 JED-LHR' summary style; add profiles per feed as they appear."""
    flight_re: re.Pattern = field(default_factory=lambda: re.compile(
        r"\b(?P<fn>[A-Z]{2}\s?\d{2,4})\b"))
    route_re: re.Pattern = field(default_factory=lambda: re.compile(
        r"\b(?P<org>[A-Z]{3})\s*[-–>/]\s*(?P<dst>[A-Z]{3})\b"))
    aircraft_re: re.Pattern = field(default_factory=lambda: re.compile(
        r"\b(?P<ac>A3\d{2}|B7\d{2}|77\dW?|78\d)\b"))
    domestic_airports: frozenset = frozenset({
        "JED", "RUH", "DMM", "MED", "AHB", "TUU", "GIZ", "ELQ", "HAS",
        "TIF", "YNB", "AJF", "EAM", "URY", "RAE", "BHH", "WAE", "DWD",
    })


DEFAULT_PROFILE = ExtractionProfile()


@dataclass
class ParseReport:
    roster: Optional[NormalizedRoster]
    events_total: int = 0
    legs_extracted: int = 0
    events_skipped: int = 0
    skipped_samples: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def parse_ics(text: str, period: str, year: int,
              profile: ExtractionProfile = DEFAULT_PROFILE) -> ParseReport:
    report = ParseReport(roster=None)
    if "BEGIN:VCALENDAR" not in text:
        report.errors.append("not an iCalendar document (no BEGIN:VCALENDAR)")
        return report

    legs: list[NormalizedLeg] = []
    in_event = False
    ev: dict = {}
    for line in _unfold(text):
        name, params, value = _prop(line)
        if name == "BEGIN" and value.upper() == "VEVENT":
            in_event, ev = True, {}
            continue
        if name == "END" and value.upper() == "VEVENT":
            in_event = False
            report.events_total += 1
            leg = _event_to_leg(ev, profile)
            if leg is not None:
                legs.append(leg)
                report.legs_extracted += 1
            else:
                report.events_skipped += 1
                if len(report.skipped_samples) < 5:
                    report.skipped_samples.append(
                        (ev.get("SUMMARY") or "")[:60])
            continue
        if in_event:
            if name in ("DTSTART", "DTEND"):
                ev[name] = _parse_dt(value, params)
            elif name in ("SUMMARY", "DESCRIPTION", "LOCATION"):
                ev[name] = value.replace("\\,", ",").replace("\\n", " ")

    legs.sort(key=lambda l: l.departureLT)
    if not legs:
        report.errors.append(
            "no flight events matched the extraction patterns "
            f"({report.events_total} events seen)")
        return report

    report.roster = NormalizedRoster(
        period=period, year=year, legs=legs,
        provider_note=(f"ics: {report.legs_extracted} legs from "
                       f"{report.events_total} events"))
    return report


def _event_to_leg(ev: dict, profile: ExtractionProfile) -> Optional[NormalizedLeg]:
    start, end = ev.get("DTSTART"), ev.get("DTEND")
    if not isinstance(start, datetime) or not isinstance(end, datetime):
        return None
    text = " ".join(str(ev.get(k) or "")
                    for k in ("SUMMARY", "DESCRIPTION", "LOCATION")).upper()

    m_fn = profile.flight_re.search(text)
    m_rt = profile.route_re.search(text)
    if not (m_fn and m_rt):
        return None                       # not a flight event → skip honestly

    origin = m_rt.group("org")
    dest = m_rt.group("dst")
    intl = not ({origin, dest} <= profile.domestic_airports)
    block = max(round((end - start).total_seconds() / 3600.0, 2), 0.0)
    m_ac = profile.aircraft_re.search(text)

    return NormalizedLeg(
        flightNumber=m_fn.group("fn").replace(" ", ""),
        origin=origin, destination=dest,
        legType="international" if intl else "domestic",
        departureLT=start, arrivalLT=end,
        blockHours=block,
        aircraftType=m_ac.group("ac") if m_ac else "",
    )
