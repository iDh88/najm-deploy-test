"""Profile data sources — the backend the Profile screen renders from.

The brief says: "No placeholders. No mock implementations." A Profile screen
is exactly where that rule gets broken, because a green dot and a version
number are easy to hardcode and nobody notices. These tests make the honest
behaviour executable:

  * AI status reports "unconfigured" — not a green light — when the AI
    provider genuinely cannot answer.
  * The model string and the engine list come from the SAME constants the
    assistant and the roster fan-out use, so the card cannot advertise a
    model we don't call or an engine we don't run.
  * An empty knowledge base reports zero documents and NO timestamp, rather
    than "Updated today".
  * The roster catalog tells the truth about every source in the brief:
    Excel is real (a Cloud Function parses uploaded workbooks), Email import
    is NOT built and says so.
"""
from __future__ import annotations

from unittest.mock import patch

import pytest

from ai.nlp_router import CLAUDE_MODEL
from ai.status_router import ai_status
from roster_sync.engine_fanout import ENGINE_REGISTRY
from roster_sync.providers import (NOT_IMPLEMENTED, PRIORITY_ORDER,
                                   provider_catalog)

SERVICE = {"service": True}


class _Snap:
    def __init__(self, data):
        self._d = data

    def to_dict(self):
        return dict(self._d)


class _Coll:
    def __init__(self, rows):
        self._rows = rows

    def stream(self):
        return iter([_Snap(r) for r in self._rows])


class _DB:
    def __init__(self, docs=(), versions=()):
        self._docs = list(docs)
        self._versions = list(versions)

    def collection(self, name):
        if name == "knowledgeDocuments":
            return _Coll(self._docs)
        if name == "documentVersions":
            return _Coll(self._versions)
        return _Coll([])


def _status(db, api_key=None, monkeypatch=None):
    if api_key is None:
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    else:
        monkeypatch.setenv("ANTHROPIC_API_KEY", api_key)
    with patch("utils.firebase.get_firestore", return_value=db):
        return pytest.run_async(ai_status(claims=SERVICE))


class TestAiStatusTruthfulness:
    def test_unconfigured_provider_is_not_reported_as_online(self, monkeypatch):
        body = _status(_DB(), api_key=None, monkeypatch=monkeypatch)
        assert body["status"] == "unconfigured"
        # …and the user is told what still works, instead of a bare failure.
        assert "manual filters" in body["status_detail"].lower()

    def test_configured_provider_reports_online(self, monkeypatch):
        body = _status(_DB(), api_key="sk-test", monkeypatch=monkeypatch)
        assert body["status"] == "online"

    def test_model_is_the_same_constant_the_assistant_calls(self, monkeypatch):
        body = _status(_DB(), api_key="sk-test", monkeypatch=monkeypatch)
        assert body["model"] == CLAUDE_MODEL

    def test_engines_cannot_drift_from_what_actually_runs(self, monkeypatch):
        body = _status(_DB(), api_key="sk-test", monkeypatch=monkeypatch)
        reported = [(e["engine"], e["trigger"]) for e in body["engines"]]
        assert reported == list(ENGINE_REGISTRY)
        assert len(reported) == 9

    def test_service_version_is_the_shared_constant(self, monkeypatch):
        from utils.version import SERVICE_VERSION
        body = _status(_DB(), api_key="sk-test", monkeypatch=monkeypatch)
        assert body["service_version"] == SERVICE_VERSION

    def test_empty_knowledge_base_invents_no_timestamp(self, monkeypatch):
        body = _status(_DB(), api_key="sk-test", monkeypatch=monkeypatch)
        kb = body["knowledge_base"]
        assert kb["documents"] == 0
        assert kb["last_updated"] is None        # NOT "today"
        assert kb["latest_version"] is None

    def test_knowledge_base_counts_and_latest_update_are_real(self, monkeypatch):
        db = _DB(
            docs=[{"name": "GOM", "isDisabled": False},
                  {"name": "Old memo", "isDisabled": True},
                  {"name": "FTL table", "isDisabled": False}],
            versions=[{"createdAt": "2026-07-01T09:00:00", "versionNumber": 1},
                      {"createdAt": "2026-07-11T09:42:00", "versionNumber": 3},
                      {"createdAt": "2026-07-05T09:00:00", "versionNumber": 2}],
        )
        kb = _status(db, api_key="sk-test", monkeypatch=monkeypatch)["knowledge_base"]
        assert kb["documents"] == 2              # disabled one excluded
        assert kb["documents_disabled"] == 1
        assert kb["last_updated"] == "2026-07-11T09:42:00"
        assert kb["latest_version"] == 3

    def test_knowledge_base_failure_degrades_honestly(self, monkeypatch):
        class _Boom:
            def collection(self, name):
                raise RuntimeError("firestore down")
        kb = _status(_Boom(), api_key="sk-test",
                     monkeypatch=monkeypatch)["knowledge_base"]
        assert kb["available"] is False
        assert kb["last_updated"] is None


class TestRosterCatalogHonesty:
    def test_every_source_in_the_brief_is_represented(self):
        ids = {p.provider_id for p in provider_catalog()}
        for expected in ("cae_crew_access", "ics_feed", "manual_pdf",
                         "excel_upload", "email_import"):
            assert expected in ids

    def test_excel_is_real_and_available(self):
        """A Cloud Function parses .xlsx roster uploads today
        (firebase/functions → /v1/parser/parse), so Excel is a genuine
        source, not a promise."""
        excel = next(p for p in provider_catalog()
                     if p.provider_id == "excel_upload")
        assert excel.availability == "available"

    def test_email_import_is_declared_not_implemented(self):
        """It appears in the product brief but does not exist. It must render
        as unavailable — never as a tile that pretends to work."""
        email = next(p for p in provider_catalog()
                     if p.provider_id == "email_import")
        assert email.availability == NOT_IMPLEMENTED
        assert "not built yet" in email.availability_note

    def test_priority_keeps_cae_first_and_uploads_last(self):
        assert PRIORITY_ORDER[0] == "cae_crew_access"
        assert PRIORITY_ORDER.index("ics_feed") < \
            PRIORITY_ORDER.index("manual_pdf")
        assert PRIORITY_ORDER[-1] == "email_import"

    def test_catalog_order_follows_priority(self):
        ids = [p.provider_id for p in provider_catalog()]
        ranked = [i for i in ids if i in PRIORITY_ORDER]
        assert ranked == sorted(ranked, key=PRIORITY_ORDER.index)
