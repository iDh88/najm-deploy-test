"""roster_sync tests — the feature spec, executable.

Covers: the credential-never-server invariant (defence in depth), the ICS
parser (real RFC subset), checksum/dedup/diff versioning, import enrichment
(rest gaps, FDP, CANONICAL legality flags, salary estimate, daysOff), engine
fan-out isolation, every router flow including failure handling ("do not
erase previous roster"), and the CAE honesty contract — pending until
configured, activated purely by configuration.
"""
from __future__ import annotations

import copy
import json
from datetime import datetime

import pytest

from roster_sync import import_service, version_service
from roster_sync.engine_fanout import run_fanout
from roster_sync.ics_parser import parse_ics
from roster_sync.providers import get_provider
from roster_sync.schema import (
    CredentialLeakError,
    NormalizedLeg,
    NormalizedRoster,
    assert_no_credentials,
)


# ── In-memory Firestore fake (equality-where + stream + add) ─────────────────

class _Doc:
    def __init__(self, store, col, doc_id):
        self._store, self._col, self.id = store, col, doc_id

    @property
    def _data(self):
        return self._store.setdefault(self._col, {}).get(self.id)

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return copy.deepcopy(self._data) if self._data is not None else None

    def get(self):
        return self

    def set(self, data):
        self._store.setdefault(self._col, {})[self.id] = copy.deepcopy(data)

    def update(self, patch):
        self._store.setdefault(self._col, {}).setdefault(self.id, {}).update(
            copy.deepcopy(patch))


class _Query:
    def __init__(self, store, col, filters=()):
        self._store, self._col, self._filters = store, col, filters

    def where(self, field, op, value):
        assert op == "=="
        return _Query(self._store, self._col,
                      self._filters + ((field, value),))

    def stream(self):
        for doc_id, data in list(self._store.get(self._col, {}).items()):
            if all(data.get(f) == v for f, v in self._filters):
                yield _Doc(self._store, self._col, doc_id)


class _Collection(_Query):
    def document(self, doc_id):
        return _Doc(self._store, self._col, doc_id)

    def add(self, data):
        doc_id = f"auto_{len(self._store.setdefault(self._col, {}))}"
        self._store[self._col][doc_id] = copy.deepcopy(data)
        return _Doc(self._store, self._col, doc_id)


class FakeDB:
    def __init__(self):
        self.store: dict = {}

    def collection(self, name):
        return _Collection(self.store, name)


@pytest.fixture
def db():
    return FakeDB()


@pytest.fixture(autouse=True)
def _patch_db(db, monkeypatch):
    # The shared conftest autouse mock also patches utils.firebase — patch
    # the router's OWN resolver so ordering can never hand writes to a
    # MagicMock, plus the module seam for any indirect callers.
    import utils.firebase as fb
    import roster_sync.router as rr
    monkeypatch.setattr(fb, "get_firestore", lambda: db)
    monkeypatch.setattr(rr, "_db", lambda: db)


# ── Fixtures: rosters ────────────────────────────────────────────────────────

def _leg(fn, org, dst, dep, hours, *, intl=False, layover=False,
         layover_h=0.0):
    return NormalizedLeg(
        flightNumber=fn, origin=org, destination=dst,
        legType="international" if intl else "domestic",
        departureLT=dep,
        arrivalLT=dep.replace(hour=(dep.hour + int(hours)) % 24),
        blockHours=hours, layover=layover, layoverHours=layover_h)


def _roster(legs, period="JUN-2026"):
    return NormalizedRoster(period=period, year=2026, legs=legs)


GOOD_LEGS = [
    NormalizedLeg(flightNumber="SV1020", origin="JED", destination="RUH",
                  legType="domestic",
                  departureLT=datetime(2026, 6, 3, 8, 0),
                  arrivalLT=datetime(2026, 6, 3, 9, 45), blockHours=1.75),
    NormalizedLeg(flightNumber="SV1021", origin="RUH", destination="JED",
                  legType="domestic",
                  departureLT=datetime(2026, 6, 4, 10, 0),
                  arrivalLT=datetime(2026, 6, 4, 11, 45), blockHours=1.75),
    NormalizedLeg(flightNumber="SV117", origin="JED", destination="LHR",
                  legType="international",
                  departureLT=datetime(2026, 6, 8, 9, 30),
                  arrivalLT=datetime(2026, 6, 8, 16, 0), blockHours=6.5,
                  layover=True, layoverHours=26.0),
    NormalizedLeg(flightNumber="SV118", origin="LHR", destination="JED",
                  legType="international",
                  departureLT=datetime(2026, 6, 9, 20, 0),
                  arrivalLT=datetime(2026, 6, 10, 2, 30), blockHours=6.5),
]


ICS_TEXT = "\r\n".join([
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//CrewPortal//Roster//EN",
    "BEGIN:VEVENT",
    "DTSTART;TZID=Asia/Riyadh:20260603T080000",
    "DTEND;TZID=Asia/Riyadh:20260603T094500",
    "SUMMARY:SV1020 JED-RUH",
    "DESCRIPTION:Duty day 1\\, aircraft A320",
    "END:VEVENT",
    "BEGIN:VEVENT",
    "DTSTART:20260608T093000",
    "DTEND:20260608T160000",
    "SUMMARY:Flight SV 117",
    # route only in LOCATION + a folded line
    "LOCATION:JED",
    " -LHR B787",
    "END:VEVENT",
    "BEGIN:VEVENT",                    # non-flight event → skipped honestly
    "DTSTART;VALUE=DATE:20260615",
    "SUMMARY:Recurrent training (ground)",
    "END:VEVENT",
    "END:VCALENDAR",
])


# ── 1. Credential guard ──────────────────────────────────────────────────────

class TestCredentialGuard:
    @pytest.mark.parametrize("payload", [
        {"password": "x"},
        {"meta": {"crew": {"Password": "x"}}},
        {"items": [{"apiToken": "x"}]},
        {"prn_secret": "x"},
        {"Authorization": "Bearer x"},
    ])
    def test_credential_shaped_keys_rejected_anywhere(self, payload):
        with pytest.raises(CredentialLeakError) as e:
            assert_no_credentials(payload)
        assert "Keychain" in str(e.value)

    def test_clean_payload_passes(self):
        assert_no_credentials({"provider_id": "ics_feed",
                               "payload": "BEGIN:VCALENDAR",
                               "auth_kind": "feed_url",
                               "legs": [{"flightNumber": "SV1"}]})


# ── 2. ICS parser ────────────────────────────────────────────────────────────

class TestIcsParser:
    def test_flights_extracted_nonflights_skipped(self):
        rep = parse_ics(ICS_TEXT, "JUN-2026", 2026)
        assert rep.roster is not None
        assert rep.events_total == 3
        assert rep.legs_extracted == 2
        assert rep.events_skipped == 1
        fns = [l.flightNumber for l in rep.roster.legs]
        assert fns == ["SV1020", "SV117"]

    def test_folded_location_route_and_aircraft(self):
        rep = parse_ics(ICS_TEXT, "JUN-2026", 2026)
        lhr = rep.roster.legs[1]
        assert (lhr.origin, lhr.destination) == ("JED", "LHR")
        assert lhr.legType == "international"
        assert lhr.aircraftType == "B787"
        assert lhr.blockHours == pytest.approx(6.5, abs=0.01)

    def test_domestic_classification_and_tzid(self):
        rep = parse_ics(ICS_TEXT, "JUN-2026", 2026)
        dom = rep.roster.legs[0]
        assert dom.legType == "domestic"
        assert dom.departureLT == datetime(2026, 6, 3, 8, 0)

    def test_not_a_calendar(self):
        rep = parse_ics("hello world", "JUN-2026", 2026)
        assert rep.roster is None and rep.errors

    def test_calendar_with_no_flights(self):
        text = ("BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20260601T080000\n"
                "DTEND:20260601T090000\nSUMMARY:Dentist\nEND:VEVENT\n"
                "END:VCALENDAR")
        rep = parse_ics(text, "JUN-2026", 2026)
        assert rep.roster is None
        assert "no flight events" in rep.errors[0]


# ── 3. Versioning ────────────────────────────────────────────────────────────

class TestVersioning:
    def test_checksum_order_independent(self):
        a = _roster(list(GOOD_LEGS))
        b = _roster(list(reversed(GOOD_LEGS)))
        assert version_service.roster_checksum(a) \
            == version_service.roster_checksum(b)

    def test_diff_added_removed_changed(self):
        prev = _roster(GOOD_LEGS[:3])
        cur_legs = [GOOD_LEGS[0],
                    GOOD_LEGS[2].model_copy(update={"blockHours": 7.0}),
                    GOOD_LEGS[3]]
        diff = version_service.diff_rosters(prev, _roster(cur_legs))
        assert diff == {"added": 1, "removed": 1, "changed": 1}

    def test_version_numbers_and_snapshot_roundtrip(self, db):
        r = _roster(GOOD_LEGS)
        assert version_service.next_version_number(
            db, "u1", "ics_feed", "JUN-2026") == 1
        from roster_sync.schema import VersionEntry
        version_service.record_version(
            db, "u1", "ics_feed", "JUN-2026",
            VersionEntry(version=1,
                         checksum=version_service.roster_checksum(r),
                         imported_flights=len(r.legs),
                         at=datetime(2026, 6, 1)),
            normalized_snapshot=r.model_dump(mode="json"))
        assert version_service.next_version_number(
            db, "u1", "ics_feed", "JUN-2026") == 2
        loaded = version_service.load_previous_roster(
            db, "u1", "ics_feed", "JUN-2026")
        assert loaded is not None and len(loaded.legs) == len(r.legs)


# ── 4. Import enrichment ─────────────────────────────────────────────────────

class TestImportEnrichment:
    def test_line_doc_shape_matches_flightlines_contract(self):
        doc = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(GOOD_LEGS))
        for key in ("id", "lineNumber", "month", "userId", "isActive",
                    "source", "rosterVersion", "destinations", "daysOff",
                    "summary", "legs"):
            assert key in doc, key
        s = doc["summary"]
        for key in ("totalLegs", "totalBlockHours", "totalDutyHours",
                    "totalDutyDays", "internationalLegs", "domesticLegs",
                    "layoverCount", "estimatedSalaryMin",
                    "estimatedSalaryMax", "salaryScore",
                    "restQualityScore", "compositeScore"):
            assert key in s, key
        assert s["totalLegs"] == 4
        assert s["internationalLegs"] == 2 and s["domesticLegs"] == 2
        assert s["estimatedSalaryMin"] > 0
        assert 0 < s["restQualityScore"] <= 100

    def test_rest_gaps_and_fdp_derived(self):
        doc = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(GOOD_LEGS))
        leg1 = doc["legs"][1]
        # duty0 ends 10:15 (09:45+30m); duty1 starts 09:00 (10:00−60m) next day
        assert leg1["restBeforeHours"] == pytest.approx(22.75, abs=0.02)
        # duty1: report 09:00 (10:00−60m) → duty end 12:15 (11:45+30m)
        assert leg1["fdpHours"] == pytest.approx(3.25, abs=0.02)

    def test_canonical_legality_flags_illegal_rest(self):
        # 10h gap before an international duty — illegal under the canonical
        # 15h minimum (P0 rules). The SAME engine as /v1/legality must flag it.
        tight = [
            NormalizedLeg(flightNumber="SV117", origin="JED",
                          destination="LHR", legType="international",
                          departureLT=datetime(2026, 6, 8, 8, 0),
                          arrivalLT=datetime(2026, 6, 8, 14, 30),
                          blockHours=6.5),
            NormalizedLeg(flightNumber="SV118", origin="LHR",
                          destination="JED", legType="international",
                          departureLT=datetime(2026, 6, 9, 2, 0),
                          arrivalLT=datetime(2026, 6, 9, 8, 30),
                          blockHours=6.5),
        ]
        doc = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(tight))
        flagged = [l for l in doc["legs"] if l["legalityFlags"]]
        assert flagged, "canonical engine must flag the short rest"
        assert any("REST" in f for l in flagged for f in l["legalityFlags"])
        assert any(l["legalityStatus"] in ("violation", "warning")
                   for l in flagged)

    def test_days_off_are_dutyless_weekdays(self):
        doc = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(GOOD_LEGS))
        # Duties on Jun 3 (Wed=3), 4 (Thu=4), 8 (Mon=1), 9 (Tue=2)
        assert doc["daysOff"] == [0, 5, 6]

    def test_deactivate_previous_keeps_history(self, db):
        old = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(GOOD_LEGS))
        import_service.write_line(db, old)
        n = import_service.deactivate_previous(db, "u1", "ics_feed",
                                               "JUN-2026")
        assert n == 1
        stored = db.store["flightLines"][old["id"]]
        assert stored["isActive"] is False          # kept, not erased


# ── 5. Fan-out ───────────────────────────────────────────────────────────────

class TestFanout:
    def test_all_nine_engines_reported(self, db):
        doc = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(GOOD_LEGS))
        statuses = {s.engine: s for s in run_fanout(db, "u1", doc,
                                                    "ics_feed")}
        assert set(statuses) == {
            "salary_engine", "ftl_engine", "rest_calculator",
            "ranking_engine", "behavior_engine",
            "bid_recommendation_engine", "trade_recommendation_engine",
            "layover_recommendation_engine", "knowledge_engine"}
        assert statuses["behavior_engine"].status == "queued"
        assert "behaviorEvents" in db.store
        assert statuses["knowledge_engine"].status == "on_demand"

    def test_one_engine_failure_is_isolated(self, db):
        doc = import_service.build_line_doc("u1", "ics_feed", 1,
                                            _roster(GOOD_LEGS))

        class _Boom(FakeDB):
            def collection(self, name):
                if name == "behaviorEvents":
                    raise ConnectionError("firestore down")
                return super().collection(name)
        boom = _Boom()
        statuses = {s.engine: s for s in run_fanout(boom, "u1", doc,
                                                    "ics_feed")}
        assert statuses["behavior_engine"].status == "failed"
        assert statuses["salary_engine"].status == "ok"
        assert statuses["bid_recommendation_engine"].status == "queued"


# ── 6. Router flows ──────────────────────────────────────────────────────────

def _claims(uid="u1"):
    return {"uid": uid}


class TestRouterFlows:
    def _import(self, db, body, claims=None):
        from roster_sync.router import import_roster
        return pytest.run_async(import_roster(body, claims or _claims()))

    @staticmethod
    def _normalized(ics_text, period="JUN-2026", year=2026):
        """Device contract: normalize ON DEVICE, upload normalized only.
        Tests use the server parser as the reference normalizer — the Dart
        normalizer mirrors it (parity fixtures in
        flutter_app/test/unit/ics_normalizer_test.dart)."""
        from roster_sync.ics_parser import parse_ics
        report = parse_ics(ics_text, period, year)
        assert report.roster is not None, report.errors
        legs = []
        for leg in report.roster.legs:
            d = leg.model_dump()
            for k in ("departureLT", "arrivalLT", "dutyStart", "dutyEnd"):
                if d.get(k) is not None:
                    d[k] = d[k].isoformat()
            legs.append(d)
        return {"period": report.roster.period,
                "year": report.roster.year,
                "legs": legs,
                "provider_note": report.roster.provider_note}

    def test_provider_catalog_priority_and_cae_pending(self):
        from roster_sync.providers import provider_catalog
        cat = provider_catalog()
        assert [p.provider_id for p in cat][:3] == [
            "cae_crew_access", "ics_feed", "manual_pdf"]
        cae = cat[0]
        assert cae.recommended is True
        assert cae.availability == "pending_official_integration"
        assert "official" in cae.availability_note
        assert cat[1].availability == "available"

    def test_connect_cae_is_honest(self, db):
        from roster_sync.router import connect
        from roster_sync.schema import ConnectRequest
        out = pytest.run_async(connect(
            ConnectRequest(provider_id="cae_crew_access"), _claims()))
        assert out["status"] == "awaiting_official_integration"
        assert "official" in out["note"]
        conn = db.store["rosterSources"]["u1_cae_crew_access"]
        assert conn["status"] == "awaiting_official_integration"
        events = list(db.store["syncEvents"].values())
        assert events and events[0]["type"] == "connect_blocked"

    def test_import_ics_happy_path(self, db):
        out = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT),
        })
        assert out.result == "imported" and out.version == 1
        assert out.imported_flights == 2
        assert out.line_id in db.store["flightLines"]
        assert {e.engine for e in out.engines} >= {"salary_engine",
                                                   "knowledge_engine"}
        conn = db.store["rosterSources"]["u1_ics_feed"]
        assert conn["imported_flights_last"] == 2
        assert conn["last_success_at"]
        types = [e["type"] for e in db.store["syncEvents"].values()]
        assert "sync_ok" in types

    def test_duplicate_import_is_detected_and_harmless(self, db):
        first = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT)})
        again = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT)})
        assert again.result == "duplicate" and again.version == 1
        line = db.store["flightLines"][first.line_id]
        assert line["isActive"] is True             # untouched
        types = [e["type"] for e in db.store["syncEvents"].values()]
        assert "duplicate" in types

    def test_changed_roster_versions_up_and_deactivates_old(self, db):
        first = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT)})
        changed = ICS_TEXT.replace("20260603T094500", "20260603T101500")
        second = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(changed)})
        assert second.result == "imported" and second.version == 2
        assert second.diff["changed"] == 1
        assert db.store["flightLines"][first.line_id]["isActive"] is False
        assert db.store["flightLines"][second.line_id]["isActive"] is True
        types = [e["type"] for e in db.store["syncEvents"].values()]
        assert "version_change" in types

    def test_credential_key_rejected_422(self, db):
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as e:
            self._import(db, {
                "provider_id": "ics_feed", "period": "JUN-2026",
                "year": 2026, "payload_kind": "ics",
                "payload": ICS_TEXT, "password": "hunter2"})
        assert e.value.status_code == 422
        assert "Keychain" in str(e.value.detail)
        assert "flightLines" not in db.store    # nothing imported

    def test_failed_parse_preserves_previous_roster(self, db):
        first = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT)})
        from fastapi import HTTPException
        # A device whose normalizer yielded nothing (corrupt/empty feed).
        with pytest.raises(HTTPException) as e:
            self._import(db, {
                "provider_id": "ics_feed", "period": "JUN-2026",
                "year": 2026, "payload_kind": "normalized",
                "payload": {"period": "JUN-2026", "year": 2026, "legs": []}})
        assert e.value.status_code == 422
        # Spec: a failed sync must NOT erase the roster the crew relies on.
        assert db.store["flightLines"][first.line_id]["isActive"] is True
        conn = db.store["rosterSources"]["u1_ics_feed"]
        assert conn["status"] == "error" and conn["last_error"]

    def test_raw_calendar_from_a_device_is_refused(self, db):
        """Zero-Knowledge directive: devices upload NORMALIZED rosters only.
        The raw calendar (which carries personal, non-flight events) must
        never leave the phone — so the backend refuses it from user tokens."""
        from fastapi import HTTPException
        with pytest.raises(HTTPException) as e:
            self._import(db, {
                "provider_id": "ics_feed", "period": "JUN-2026",
                "year": 2026, "payload_kind": "ics", "payload": ICS_TEXT})
        assert e.value.status_code == 422
        assert "normalized" in str(e.value.detail)
        assert "flightLines" not in db.store

    def test_raw_calendar_still_allowed_for_service_tooling(self, db):
        """…but admin/migration tooling (service token, no user device in the
        loop) may still re-parse raw calendars server-side."""
        out = self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "ics", "payload": ICS_TEXT},
            claims={"service": True})
        assert out.result == "imported"

    def test_sync_now_semantics(self, db):
        from roster_sync.router import sync_now
        ics = pytest.run_async(sync_now("ics_feed", _claims()))
        assert ics.action == "client_sync_required"
        cae = pytest.run_async(sync_now("cae_crew_access", _claims()))
        assert cae.action == "unavailable" and "official" in cae.detail

    def test_disconnect_keeps_rosters_and_orders_local_wipe(self, db):
        self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT)})
        from roster_sync.router import disconnect
        out = pytest.run_async(disconnect("ics_feed", _claims()))
        assert out["client_action"] == "erase_local_credentials"
        assert any(d.get("isActive")
                   for d in db.store["flightLines"].values())

    def test_status_prefers_connected_sync_source(self, db):
        from roster_sync.router import status
        before = pytest.run_async(status(_claims()))
        assert before.preferred_source == "manual_pdf"
        self._import(db, {
            "provider_id": "ics_feed", "period": "JUN-2026", "year": 2026,
            "payload_kind": "normalized", "payload": self._normalized(ICS_TEXT)})
        after = pytest.run_async(status(_claims()))
        assert after.preferred_source == "ics_feed"
        assert any(p.provider_id == "cae_crew_access"
                   for p in after.providers)


# ── 7. Trust model: two dedicated adapters, owner-approval gate ─────────────
#
# Zero-Knowledge directive, Architecture Rule: moving from client-managed to
# server-managed credentials "MUST NOT happen automatically. It MUST require
# explicit approval from the project owner." These tests are that rule's
# enforcement — they fail if a future change lets ordinary configuration flip
# NAJM's trust model.

class TestZeroKnowledgeTrustModel:
    def _clear(self, monkeypatch):
        for var in ("CAE_OFFICIAL_DEVICE_INTEGRATION",
                    "CAE_OFFICIAL_DEVICE_CONFIG",
                    "CAE_ENTERPRISE_BASE_URL",
                    "ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL"):
            monkeypatch.delenv(var, raising=False)

    # ── the zero-knowledge lane (default) ──
    def test_cae_client_adapter_is_zero_knowledge_and_pending(self, monkeypatch):
        self._clear(monkeypatch)
        cae = get_provider("cae_crew_access")
        avail, note = cae.availability()
        assert avail == "pending_official_integration"
        assert cae.trust_model == "zero_knowledge"
        assert "no unofficial automation" in note.replace("-\n", "").lower() \
            or "unofficial" in note.lower()

    def test_official_device_integration_activates_by_config(self, db, monkeypatch):
        self._clear(monkeypatch)
        monkeypatch.setenv("CAE_OFFICIAL_DEVICE_INTEGRATION", "1")
        cae = get_provider("cae_crew_access")
        assert cae.availability()[0] == "available"
        assert cae.trust_model == "zero_knowledge"   # still device-only

        from roster_sync.router import import_roster
        out = pytest.run_async(import_roster({
            "provider_id": "cae_crew_access", "period": "JUN-2026",
            "year": 2026, "payload_kind": "normalized",
            "payload": _roster(GOOD_LEGS).model_dump(mode="json"),
        }, _claims()))
        assert out.result == "imported" and out.imported_flights == 4
        assert db.store["flightLines"][out.line_id]["source"] == "cae_crew_access"

    def test_zero_knowledge_adapter_can_never_server_fetch(self, monkeypatch):
        self._clear(monkeypatch)
        monkeypatch.setenv("CAE_OFFICIAL_DEVICE_INTEGRATION", "1")
        from roster_sync.providers import ProviderNotAvailable
        with pytest.raises(ProviderNotAvailable):
            get_provider("cae_crew_access").server_fetch("u1", "JUN-2026", 2026)

    def test_unconfigured_cae_import_is_409(self, db, monkeypatch):
        self._clear(monkeypatch)
        from fastapi import HTTPException
        from roster_sync.router import import_roster
        with pytest.raises(HTTPException) as e:
            pytest.run_async(import_roster({
                "provider_id": "cae_crew_access", "period": "JUN-2026",
                "year": 2026, "payload_kind": "normalized",
                "payload": _roster(GOOD_LEGS).model_dump(mode="json"),
            }, _claims()))
        assert e.value.status_code == 409
        assert "flightLines" not in db.store

    # ── the server-orchestrated lane (dormant without owner sign-off) ──
    def test_enterprise_adapter_dormant_without_owner_approval(self, monkeypatch):
        self._clear(monkeypatch)
        # Even fully "configured" by ops, it must NOT activate.
        monkeypatch.setenv("CAE_ENTERPRISE_BASE_URL",
                           "https://enterprise.cae.example/v1")
        ent = get_provider("cae_enterprise")
        avail, note = ent.availability()
        assert avail == "requires_owner_approval"
        assert "ADR-001" in note
        assert ent.trust_model == "server_orchestrated"

    def test_dormant_adapter_is_hidden_from_the_crew_catalog(self, monkeypatch):
        self._clear(monkeypatch)
        from roster_sync.providers import provider_catalog
        ids = [p.provider_id for p in provider_catalog()]
        assert "cae_enterprise" not in ids
        # …but it exists, and ops/tests can see it is deliberately dormant.
        all_ids = [p.provider_id
                   for p in provider_catalog(include_dormant=True)]
        assert "cae_enterprise" in all_ids

    def test_owner_approval_alone_is_not_enough_without_an_endpoint(
            self, monkeypatch):
        self._clear(monkeypatch)
        monkeypatch.setenv("ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL",
                           "owner/2026-07-12/ADR-001")
        avail, note = get_provider("cae_enterprise").availability()
        assert avail == "pending_official_integration"
        assert "not configured" in note and "hardcoded" in note

    def test_enterprise_activates_only_with_approval_and_endpoint(
            self, monkeypatch):
        self._clear(monkeypatch)
        monkeypatch.setenv("ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL",
                           "owner/2026-07-12/ADR-001")
        monkeypatch.setenv("CAE_ENTERPRISE_BASE_URL",
                           "https://enterprise.cae.example/v1")
        ent = get_provider("cae_enterprise")
        avail, note = ent.availability()
        assert avail == "available"
        assert "owner/2026-07-12/ADR-001" in note
        from roster_sync.providers import provider_catalog
        assert "cae_enterprise" in [p.provider_id for p in provider_catalog()]

    def test_enterprise_server_fetch_is_not_a_placeholder(self, monkeypatch):
        """The directive forbids placeholder implementations that imply the
        integration exists. Even when approved AND configured, server_fetch
        refuses honestly until it is implemented against CAE's real docs."""
        self._clear(monkeypatch)
        monkeypatch.setenv("ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL", "owner/x")
        monkeypatch.setenv("CAE_ENTERPRISE_BASE_URL", "https://e.example/v1")
        from roster_sync.providers import ProviderNotAvailable
        with pytest.raises(ProviderNotAvailable) as e:
            get_provider("cae_enterprise").server_fetch("u1", "JUN-2026", 2026)
        assert "not implemented" in str(e.value).lower()



# ── 8. The credential walls, verbatim against the directive ─────────────────
#
# "Backend APIs MUST NEVER expose fields such as: password, secret,
#  credential, token, authHeader, authorization, sessionCookie, refreshToken,
#  providerPassword, providerSecret, providerCredential."
# Enumerated here so the code is auditable line-by-line against the owner's
# list — inbound (never accepted) and outbound (never exposed).

_DIRECTIVE_FORBIDDEN = [
    "password", "secret", "credential", "token", "authHeader",
    "authorization", "sessionCookie", "refreshToken", "providerPassword",
    "providerSecret", "providerCredential",
    # camel/snake/kebab variants of the same things
    "provider_password", "refresh_token", "session_cookie", "auth_header",
    "PRN", "prn_password", "apiKey",
]


class TestCredentialWalls:
    @pytest.mark.parametrize("field", _DIRECTIVE_FORBIDDEN)
    def test_inbound_wall_rejects_every_forbidden_field(self, field):
        from roster_sync.schema import (CredentialLeakError,
                                        assert_no_credentials)
        with pytest.raises(CredentialLeakError):
            assert_no_credentials({"provider_id": "ics_feed", field: "x"})

    @pytest.mark.parametrize("field", _DIRECTIVE_FORBIDDEN)
    def test_outbound_wall_refuses_to_expose_forbidden_fields(self, field):
        from roster_sync.schema import (CredentialLeakError,
                                        assert_no_credentials_out)
        with pytest.raises(CredentialLeakError):
            assert_no_credentials_out({"connections": [{field: "x"}]})

    def test_wall_reaches_nested_and_listed_payloads(self):
        from roster_sync.schema import (CredentialLeakError,
                                        assert_no_credentials)
        with pytest.raises(CredentialLeakError):
            assert_no_credentials(
                {"payload": {"legs": [{"meta": {"refreshToken": "x"}}]}})

    def test_wall_does_not_block_legitimate_roster_traffic(self):
        """The wall must not be so broad it breaks real syncs."""
        from roster_sync.schema import assert_no_credentials
        assert_no_credentials({
            "provider_id": "cae_crew_access", "period": "JUN-2026",
            "year": 2026, "payload_kind": "normalized",
            "payload": {"period": "JUN-2026", "year": 2026, "legs": [
                {"flightNumber": "SV123", "origin": "JED",
                 "destination": "LHR", "blockHours": 6.5}]},
            "auth_kind": "prn_password",   # a UI hint, not a secret
        })

    def test_status_response_is_screened_before_it_leaves(self, db):
        """The contract is about FIELD NAMES, not substrings: `auth_kind:
        "prn_password"` is a UI hint naming which inputs to render, and must
        keep working. A field *called* password/refreshToken must not."""
        from roster_sync.router import status
        from roster_sync.schema import assert_no_credentials_out

        resp = pytest.run_async(status(_claims()))
        payload = resp.model_dump(mode="json")

        def keys(obj):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    yield str(k).lower()
                    yield from keys(v)
            elif isinstance(obj, list):
                for v in obj:
                    yield from keys(v)

        emitted = set(keys(payload))
        for bad in ("password", "secret", "credential", "token",
                    "authheader", "authorization", "sessioncookie",
                    "refreshtoken"):
            assert bad not in emitted, f"status exposes a '{bad}' field"

        assert_no_credentials_out(payload, "GET /status")   # the live guard
        assert "prn_password" in json.dumps(payload)          # hint survives
        assert resp.trust_model == "zero_knowledge"   # the platform default


class TestNoHardcodedProviderEndpoints:
    """The directive bans hardcoded endpoints / reverse-engineered protocols.
    A comment promising that is worth nothing; this test enforces it. If
    anyone ever pastes a CAE host into the codebase, CI fails here."""

    def test_no_cae_host_anywhere_in_shipped_code(self):
        import pathlib
        import re as _re
        here = pathlib.Path(__file__).resolve()
        roots = [here.parents[2],                              # python_services
                 here.parents[3] / "flutter_app" / "lib"]      # app source
        # Brand names in class names are fine (CaeCrewAccessConnector); an
        # actual provider URL compiled into the app is not.
        url_re = _re.compile(r"https?://[^\s'\"\)]*cae[^\s'\"\)]*", _re.I)
        offenders = []
        for root in roots:
            if not root.exists():
                continue
            for f in list(root.rglob("*.py")) + list(root.rglob("*.dart")):
                if "__pycache__" in str(f) or f.name == here.name:
                    continue
                for m in url_re.finditer(f.read_text(errors="ignore")):
                    offenders.append(f"{f.name}: {m.group(0)}")
        assert not offenders, (
            "a provider endpoint is hardcoded in shipped code — the CAE "
            "adapter must stay endpoint-free until official access is "
            f"granted (endpoints arrive as config): {offenders}")
