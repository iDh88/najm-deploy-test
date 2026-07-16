"""Integration tests — /v1/roster-sync API surface (real FastAPI TestClient).

Offline these report SKIPPED-OFFLINE (the harness shims raise on
TestClient); CI runs them for real, like tests/integration/test_api.py.
Firebase auth + Firestore are patched at the same seams the unit conftest
uses, so these exercise routing, dependency wiring, status codes and
response shapes end-to-end over HTTP.
"""
from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


SERVICE_HEADERS = {"X-Service-Token": "test-service-token"}
ICS = (
    "BEGIN:VCALENDAR\n"
    "BEGIN:VEVENT\n"
    "SUMMARY:SV101 JED-LHR\n"
    "DTSTART:20260710T060000Z\n"
    "DTEND:20260710T123000Z\n"
    "END:VEVENT\n"
    "END:VCALENDAR\n"
)


class _MemDoc:
    def __init__(self, store, key):
        self._store, self._key = store, key

    def get(self):
        class _Snap:
            def __init__(self, data, doc_id):
                self._d, self.id = data, doc_id
                self.exists = data is not None

            def to_dict(self):
                return dict(self._d or {})
        return _Snap(self._store.get(self._key), self._key[1])

    def set(self, data, merge=False):
        cur = self._store.get(self._key, {}) if merge else {}
        self._store[self._key] = {**cur, **data}

    def update(self, data):
        self._store.setdefault(self._key, {}).update(data)


class _MemCollection:
    def __init__(self, store, name):
        self._store, self._name = store, name
        self._filters = []

    def document(self, doc_id):
        return _MemDoc(self._store, (self._name, doc_id))

    def add(self, data):
        key = (self._name, f"auto{len(self._store)}")
        self._store[key] = dict(data)
        return None, _MemDoc(self._store, key)

    def where(self, field, op, value):
        c = _MemCollection(self._store, self._name)
        c._filters = [*self._filters, (field, op, value)]
        return c

    def order_by(self, *a, **k):
        return self

    def limit(self, *_):
        return self

    def stream(self):
        for (name, doc_id), data in list(self._store.items()):
            if name != self._name:
                continue
            if all(data.get(f) == v for f, _op, v in self._filters):
                snap = _MemDoc(self._store, (name, doc_id)).get()
                yield snap


class _MemDB:
    def __init__(self):
        self.store = {}

    def collection(self, name):
        return _MemCollection(self.store, name)


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setenv("INTERNAL_SERVICE_TOKEN", "test-service-token")
    db = _MemDB()
    with patch("utils.firebase.get_firestore", return_value=db), \
         patch("utils.firebase.initialize_firebase", return_value=None):
        from main import app
        with TestClient(app) as c:
            c._db = db  # type: ignore[attr-defined]
            yield c


def test_providers_catalog_shape(client):
    res = client.get("/v1/roster-sync/providers", headers=SERVICE_HEADERS)
    assert res.status_code == 200
    providers = res.json()["providers"]
    ids = [p["provider_id"] for p in providers]
    assert ids[0] == "cae_crew_access"          # priority order (spec)
    assert ids[-1] == "manual_pdf"
    cae = providers[0]
    assert cae["recommended"] is True
    assert cae["availability"] == "pending_official_integration"
    assert "official" in cae["availability_note"]


def test_cae_connect_reports_honest_pending(client):
    res = client.post("/v1/roster-sync/connections",
                      json={"provider_id": "cae_crew_access",
                            "user_id": "u1"},
                      headers=SERVICE_HEADERS)
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "awaiting_official_integration"


def test_import_rejects_credential_shaped_payloads(client):
    res = client.post("/v1/roster-sync/import",
                      json={"provider_id": "ics_feed", "user_id": "u1",
                            "period": "JUL-2026", "year": 2026,
                            "payload_kind": "ics", "payload": ICS,
                            "password": "leaked"},
                      headers=SERVICE_HEADERS)
    assert res.status_code == 422
    assert "credential" in res.json()["detail"].lower()


def test_ics_import_then_duplicate_then_status(client):
    body = {"provider_id": "ics_feed", "user_id": "u1",
            "period": "JUL-2026", "year": 2026,
            "payload_kind": "ics", "payload": ICS}
    first = client.post("/v1/roster-sync/import", json=body,
                        headers=SERVICE_HEADERS)
    assert first.status_code == 200
    j = first.json()
    assert j["result"] == "imported"
    assert j["imported_flights"] == 1
    assert j["version"] == 1
    assert any(e["engine"] == "salary_engine" for e in j["engines"])

    second = client.post("/v1/roster-sync/import", json=body,
                         headers=SERVICE_HEADERS)
    assert second.status_code == 200
    assert second.json()["result"] == "duplicate"

    status = client.get("/v1/roster-sync/status?user_id=u1",
                        headers=SERVICE_HEADERS)
    assert status.status_code == 200
    s = status.json()
    assert s["preferred_source"] == "ics_feed"
    conn = next(c for c in s["connections"]
                if c["provider_id"] == "ics_feed")
    assert conn["imported_flights_last"] in (0, 1)


def test_failed_parse_keeps_previous_roster(client):
    good = {"provider_id": "ics_feed", "user_id": "u2",
            "period": "JUL-2026", "year": 2026,
            "payload_kind": "ics", "payload": ICS}
    assert client.post("/v1/roster-sync/import", json=good,
                       headers=SERVICE_HEADERS).status_code == 200

    bad = {**good, "payload": "not a calendar"}
    res = client.post("/v1/roster-sync/import", json=bad,
                      headers=SERVICE_HEADERS)
    assert res.status_code == 422

    lines = [d for (name, _), d in client._db.store.items()
             if name == "flightLines" and d.get("userId") == "u2"]
    assert len(lines) == 1 and lines[0]["isActive"] is True
