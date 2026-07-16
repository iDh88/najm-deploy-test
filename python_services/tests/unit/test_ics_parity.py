"""ICS golden-parity — the guard on a duplicated parser.

The Zero-Knowledge directive moved roster normalization ONTO THE DEVICE
("Roster is normalized → Normalized roster ONLY is uploaded"). That is the
right security call, but it creates a real engineering hazard: there are now
TWO ICS implementations —

  · python_services/roster_sync/ics_parser.py                  (canonical)
  · flutter_app/lib/core/roster_sync/providers/ics_normalizer.dart (device)

— and only one of them runs in this suite. If they drift, users silently get
a different roster than the backend would have produced, and nothing fails.

So both are pinned to ONE shared fixture:

  test_fixtures/roster_sync/ics_golden.ics    — the input
  test_fixtures/roster_sync/ics_golden.json   — the expected legs, GENERATED
                                                from the canonical parser

This module asserts the canonical parser still matches the golden. Its twin,
flutter_app/test/unit/ics_normalizer_test.dart, asserts the Dart normalizer
matches the SAME file in CI. Change extraction rules and both must be
updated deliberately — divergence becomes a failing build, not a support
ticket.
"""
from __future__ import annotations

import json
from pathlib import Path

from roster_sync.ics_parser import DEFAULT_PROFILE, parse_ics

# tests/unit/ → tests/ → python_services/ → repo root
_ROOT = Path(__file__).resolve().parents[3]
_FIXTURES = _ROOT / "test_fixtures" / "roster_sync"

DEVICE_FIELDS = ("flightNumber", "origin", "destination", "legType",
                 "departureLT", "arrivalLT", "blockHours", "aircraftType")


def _golden() -> dict:
    return json.loads((_FIXTURES / "ics_golden.json").read_text())


def _ics() -> str:
    return (_FIXTURES / "ics_golden.ics").read_text()


def _project(leg) -> dict:
    """The exact field set the device uploads — the contract both sides share.
    (`provider_note` is deliberately excluded: the device's note says
    'normalized on device', which is provenance, not roster data.)"""
    dumped = leg.model_dump(mode="json")
    out = {}
    for key in DEVICE_FIELDS:
        value = dumped[key]
        if key in ("departureLT", "arrivalLT") and isinstance(value, str):
            value = value.replace("Z", "").split("+")[0]
        out[key] = value
    return out


class TestIcsGoldenParity:
    def test_fixture_files_exist(self):
        assert (_FIXTURES / "ics_golden.ics").is_file()
        assert (_FIXTURES / "ics_golden.json").is_file()

    def test_canonical_parser_matches_golden_exactly(self):
        golden = _golden()
        report = parse_ics(_ics(), golden["period"], golden["year"],
                           DEFAULT_PROFILE)
        assert report.roster is not None, report.errors
        assert [_project(l) for l in report.roster.legs] == golden["legs"]

    def test_event_accounting_matches_golden(self):
        golden = _golden()
        report = parse_ics(_ics(), golden["period"], golden["year"],
                           DEFAULT_PROFILE)
        assert report.events_total == golden["events_total"]
        assert report.events_skipped == golden["events_skipped"]

    def test_private_events_are_dropped_not_uploaded(self):
        """The feed carries a dentist appointment, annual leave and a standby
        block. None is a flight; none may reach NAJM. On the device this is
        also a privacy guarantee — the raw calendar never leaves the phone."""
        golden = _golden()
        report = parse_ics(_ics(), golden["period"], golden["year"],
                           DEFAULT_PROFILE)
        blob = json.dumps([l.model_dump(mode="json")
                           for l in report.roster.legs]).upper()
        for private in ("DENTIST", "ANNUAL LEAVE", "STBY"):
            assert private not in blob

    def test_legs_are_chronological_even_though_the_feed_is_not(self):
        """The fixture lists the 05-Jul long-haul BEFORE the 03-Jul domestic
        leg on purpose: both implementations must sort."""
        golden = _golden()
        deps = [l["departureLT"] for l in golden["legs"]]
        assert deps == sorted(deps)
        assert golden["legs"][0]["flightNumber"] == "SV1023"

    def test_golden_block_hours_are_rounding_safe(self):
        """Python rounds half-to-even; Dart rounds half-away-from-zero. Any
        fixture duration landing exactly on a half-hundredth could pass here
        and fail on device. Quarter-hour durations are binary-exact, so the
        two implementations cannot disagree — this test keeps it that way."""
        for leg in _golden()["legs"]:
            assert (leg["blockHours"] * 100) % 25 == 0, leg["flightNumber"]
