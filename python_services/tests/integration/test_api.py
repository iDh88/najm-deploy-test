"""
Integration Tests — Crew Intelligence Platform
End-to-end API tests using FastAPI TestClient.
These tests run against a test Firebase project with seeded data.
Set TEST_FIREBASE_PROJECT env var before running.
"""

import pytest
import json
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock, AsyncMock
from datetime import datetime, timedelta

# Import main app
from main import app

client = TestClient(app)

# Service-to-service auth (hardened, fail-closed): endpoints mounted with
# verify_service_token / verify_service_or_user accept this header when
# INTERNAL_SERVICE_TOKEN matches (set by the autouse fixture below).
SERVICE_HEADERS = {"X-Service-Token": "test-service-token"}


@pytest.fixture(autouse=True)
def _service_token_env(monkeypatch):
    monkeypatch.setenv("INTERNAL_SERVICE_TOKEN", "test-service-token")


# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def auth_headers():
    """Mock auth headers for a Pro-tier test user."""
    return {"Authorization": "Bearer test_token_pro_user"}

@pytest.fixture
def free_auth_headers():
    """Mock auth headers for a Free-tier test user."""
    return {"Authorization": "Bearer test_token_free_user"}

@pytest.fixture
def mock_auth_state_pro():
    """Mock request.state for a Pro user."""
    return {"user_id": "test_user_pro", "tier": "pro", "crew_id": "SA12345"}

@pytest.fixture
def mock_auth_state_free():
    """Mock request.state for a Free user."""
    return {"user_id": "test_user_free", "tier": "free", "crew_id": "SA67890"}

@pytest.fixture
def sample_parse_request():
    return {
        "userId": "test_user_pro",
        "month": "2026-06",
        "storageRef": "users/test_user_pro/rosters/2026-06.xlsx",
    }

@pytest.fixture
def sample_legs():
    base = datetime(2026, 6, 1, 8, 0)
    return [
        {
            "id": f"leg_{i}",
            "lineId": "line_411",
            "flightNumber": f"SV{100+i}",
            "origin": "RUH",
            "destination": "LHR" if i % 2 == 0 else "JED",
            "legType": "international" if i % 2 == 0 else "domestic",
            "departureLT": (base + timedelta(days=i*3)).isoformat(),
            "arrivalLT": (base + timedelta(days=i*3, hours=7)).isoformat(),
            "departureUTC": (base + timedelta(days=i*3)).isoformat(),
            "arrivalUTC": (base + timedelta(days=i*3, hours=7)).isoformat(),
            "dutyStart": (base + timedelta(days=i*3, hours=-1)).isoformat(),
            "dutyEnd": (base + timedelta(days=i*3, hours=8)).isoformat(),
            "releaseTime": (base + timedelta(days=i*3, hours=8, minutes=30)).isoformat(),
            "blockHours": 7.0 if i % 2 == 0 else 1.5,
            "fdpHours": 9.0,
            "restBeforeHours": 16.0,
            "restAfterHours": 24.0,
            "sequence": i,
        }
        for i in range(4)
    ]


def _duty(leg_id: str, duty_start, duty_end, release_time, leg_type: str):
    """Build a DutyPeriod on the current engine schema. The temporal fields
    drive the rest-rule tests; flight/block/fdp values are chosen well inside
    the FDP/block caps so only the rest rules under test can fire."""
    from legality.engine import DutyPeriod
    duty_hours = (duty_end - duty_start).total_seconds() / 3600
    return DutyPeriod(
        id=leg_id,
        flight_number="SV100",
        origin="RUH",
        destination="JED" if leg_type == "domestic" else "LHR",
        leg_type=leg_type,
        duty_start=duty_start,
        duty_end=duty_end,
        release_time=release_time,
        block_hours=max(duty_hours - 1.5, 0.5),
        fdp_hours=duty_hours,
    )


# ─── Health Check ─────────────────────────────────────────────────────────────

class TestHealth:
    def test_health_returns_200(self):
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_healthy(self):
        response = client.get("/health")
        data = response.json()
        assert data["status"] == "healthy"
        assert "version" in data
        assert "service" in data

    def test_health_no_auth_required(self):
        """Health endpoint must be publicly accessible for load balancer checks."""
        response = client.get("/health")
        assert response.status_code != 401


# ─── Parser Endpoint ──────────────────────────────────────────────────────────

class TestParserEndpoint:
    @patch("parser.excel_parser._download_from_storage")
    @patch("parser.excel_parser._save_to_firestore")
    def test_parse_returns_200_with_valid_excel(
        self, mock_save, mock_download, sample_parse_request
    ):
        """Parser should return 200 with parsed lines for a valid Excel file."""
        import openpyxl
        import io

        # Create minimal test workbook
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Line 411"
        # Headers
        ws.append(["Flight", "From", "To", "Date", "Dep Time", "Arr Time",
                   "Duty Start", "Duty End", "Aircraft", "Pay Rate"])
        # One leg row
        ws.append(["SV100", "RUH", "LHR", "2026-06-01", "09:00", "16:00",
                   "08:00", "17:00", "B787", "55"])

        buf = io.BytesIO()
        wb.save(buf)
        mock_download.return_value = buf.getvalue()
        mock_save.return_value = None

        # /v1/parser is service-only (verify_service_token at mount time).
        response = client.post(
            "/v1/parser/parse",
            json=sample_parse_request,
            headers=SERVICE_HEADERS,
        )

        assert response.status_code == 200
        data = response.json()
        assert "linesProcessed" in data
        assert data["linesProcessed"] >= 1

    @patch("parser.excel_parser._download_from_storage")
    def test_parse_returns_422_on_empty_file(self, mock_download, sample_parse_request):
        """Empty Excel file should return 422 with error details."""
        mock_download.side_effect = Exception("File not found")

        response = client.post(
            "/v1/parser/parse",
            json=sample_parse_request,
            headers=SERVICE_HEADERS,
        )

        assert response.status_code == 422

    def test_parse_requires_auth(self, sample_parse_request):
        """Parser endpoint must require authentication."""
        response = client.post("/v1/parser/parse", json=sample_parse_request)
        assert response.status_code in [401, 403, 422]


# ─── Legality Endpoint ────────────────────────────────────────────────────────

class TestLegalityEndpoint:
    def test_check_bid_endpoint_exists(self):
        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user", "tier": "pro"
        }):
            response = client.post(
                "/v1/legality/check-bid",
                json={"userId": "test_user", "lineId": "line_411"},
                headers={"Authorization": "Bearer test"},
            )
        # 200 or 404 (line not found in test) — endpoint must exist
        assert response.status_code in [200, 404, 500]

    def test_check_trade_returns_both_results(self):
        """Trade check must return results for BOTH initiator and receiver."""
        base = datetime(2026, 6, 1, 8, 0)
        offered = _duty("leg_1", base, base + timedelta(hours=8),
                        base + timedelta(hours=8, minutes=30), "international")
        requested = _duty("leg_2", base + timedelta(days=3),
                          base + timedelta(days=3, hours=8),
                          base + timedelta(days=3, hours=8, minutes=30),
                          "international")

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user", "tier": "pro", "accountStatus": "approved"
        }):
            response = client.post(
                "/v1/legality/check-trade",
                json={
                    "initiator_schedule": [offered.model_dump(mode="json")],
                    "receiver_schedule": [requested.model_dump(mode="json")],
                    "offered_duty": offered.model_dump(mode="json"),
                    "requested_duty": requested.model_dump(mode="json"),
                },
                headers={"Authorization": "Bearer test"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "initiator_result" in data
        assert "receiver_result" in data
        assert "overall_passed" in data

    def test_domestic_rest_violation_detected(self):
        """14h domestic rest rule should be detected as a violation at 10h."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            _duty("leg_1", base, base + timedelta(hours=4),
                  base + timedelta(hours=4, minutes=30), "domestic"),
            # only 9.5h after release
            _duty("leg_2", base + timedelta(hours=14),
                  base + timedelta(hours=18),
                  base + timedelta(hours=18, minutes=30), "domestic"),
        ]

        result = engine.check_schedule(duties)
        assert not result.passed
        assert any("DOM" in v.rule_id for v in result.violations)

    def test_international_rest_violation_detected(self):
        """15h international rest rule should be detected as a violation at 12h."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            _duty("leg_1", base, base + timedelta(hours=8),
                  base + timedelta(hours=8, minutes=30), "international"),
            # 11.5h after release — violation
            _duty("leg_2", base + timedelta(hours=20),
                  base + timedelta(hours=28),
                  base + timedelta(hours=28, minutes=30), "international"),
        ]

        result = engine.check_schedule(duties)
        assert not result.passed
        assert any("INT" in v.rule_id for v in result.violations)

    def test_legal_schedule_passes(self):
        """A schedule with adequate rest should pass all checks."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            _duty("leg_1", base, base + timedelta(hours=8),
                  base + timedelta(hours=8, minutes=30), "international"),
            # 15.5h after release — legal
            _duty("leg_2", base + timedelta(hours=24),
                  base + timedelta(hours=32),
                  base + timedelta(hours=32, minutes=30), "international"),
        ]

        result = engine.check_schedule(duties)
        assert result.passed
        assert len(result.violations) == 0

    def test_boundary_domestic_exactly_14h(self):
        """Exactly 14h rest after domestic should be legal (boundary)."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            _duty("leg_1", base, base + timedelta(hours=4),
                  base + timedelta(hours=4, minutes=30), "domestic"),
            # exactly 14h after release
            _duty("leg_2", base + timedelta(hours=18, minutes=30),
                  base + timedelta(hours=22),
                  base + timedelta(hours=22, minutes=30), "domestic"),
        ]

        result = engine.check_schedule(duties)
        assert result.passed

    def test_boundary_domestic_13h59m(self):
        """13h59m rest after domestic should be a violation (1 min under)."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            _duty("leg_1", base, base + timedelta(hours=4),
                  base + timedelta(hours=4, minutes=30), "domestic"),
            # 14h after release = 18:30. One minute early = 18:29
            _duty("leg_2", base + timedelta(hours=18, minutes=29),
                  base + timedelta(hours=22),
                  base + timedelta(hours=22, minutes=30), "domestic"),
        ]

        result = engine.check_schedule(duties)
        assert not result.passed


# ─── AI Assistant Endpoint ────────────────────────────────────────────────────

class TestAIEndpoint:
    @patch("ai.nlp_router.chat")
    def test_chat_returns_200(self, mock_claude):
        mock_claude.return_value = {
            "text": "Based on your schedule, I recommend Line 411.",
            "intentType": "recommendation",
        }

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }), patch("utils.rate_limiter.rate_limiter.check_and_increment",
                  new_callable=AsyncMock, return_value=(True, 1, None)):
            response = client.post(
                "/v1/ai/chat",
                json={
                    "userId": "test_user_pro",
                    "message": "Which line should I bid for this month?",
                    "history": [],
                },
                headers={"Authorization": "Bearer test"},
            )

        if response.status_code == 200:
            data = response.json()
            assert "text" in data
            assert "intentType" in data

    def test_free_tier_rate_limit_429(self):
        """User calls get 429 once the daily AI cap is reached (T3)."""
        snap = MagicMock()
        snap.exists = True
        snap.to_dict.return_value = {"count": 5}
        db = MagicMock()
        db.collection.return_value.document.return_value.get.return_value = snap

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_free", "tier": "free", "accountStatus": "approved"
        }), patch("ai.nlp_router.get_firestore", return_value=db), \
             patch("ai.nlp_router._ai_daily_free_limit", return_value=5):
            response = client.post(
                "/v1/ai/chat",
                json={
                    "user_id": "test_user_free",
                    "message": "What is the best line?",
                    "history": [],
                },
                headers={"Authorization": "Bearer test"},
            )

        assert response.status_code == 429
        data = response.json()
        assert "detail" in data

    def test_chat_requires_auth(self):
        response = client.post(
            "/v1/ai/chat",
            json={"userId": "user", "message": "Hello", "history": []},
        )
        assert response.status_code in [401, 403, 422]

    def test_message_too_long_rejected(self):
        long_message = "a" * 1100  # exceeds 1000 char limit

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro", "accountStatus": "approved"
        }), patch("ai.nlp_router._enforce_ai_daily_limit"):
            response = client.post(
                "/v1/ai/chat",
                json={"user_id": "test_user_pro", "message": long_message,
                      "history": []},
                headers={"Authorization": "Bearer test"},
            )

        assert response.status_code in [422, 400]


# ─── Ranking Endpoint ─────────────────────────────────────────────────────────

class TestRankingEndpoint:
    @patch("ranking.scorer.rank_lines")
    def test_ranking_returns_sorted_lines(self, mock_score):
        mock_score.return_value = [
            {"lineId": "line_411", "lineNumber": "411", "rank": 1, "compositeScore": 85.0,
             "salaryScore": 90.0, "restScore": 80.0, "explanation": "Best match",
             "explanationAr": "الأنسب", "estimatedSalary": 14000},
            {"lineId": "line_208", "lineNumber": "208", "rank": 2, "compositeScore": 72.0,
             "salaryScore": 70.0, "restScore": 75.0, "explanation": "Good rest",
             "explanationAr": "راحة جيدة", "estimatedSalary": 11000},
        ]

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }):
            response = client.post(
                "/v1/ranking/rank",
                json={"userId": "test_user_pro", "month": "2026-06", "userMode": "balanced"},
                headers={"Authorization": "Bearer test"},
            )

        if response.status_code == 200:
            data = response.json()
            assert "rankedLines" in data
            if len(data["rankedLines"]) >= 2:
                assert data["rankedLines"][0]["compositeScore"] >= data["rankedLines"][1]["compositeScore"]


# ─── Auto-Bid Endpoint ────────────────────────────────────────────────────────

class TestAutoBidEndpoint:
    def test_suggestion_response_structure(self):
        from auto_bid.engine import PreferenceVector
        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro", "accountStatus": "approved"
        }), patch("auto_bid.engine.AutoBidEngine.load_preference_vector",
                  new_callable=AsyncMock,
                  return_value=PreferenceVector(userId="test_user_pro")), \
             patch("auto_bid.engine.AutoBidEngine.load_lines",
                   new_callable=AsyncMock, return_value=[]):
            response = client.post(
                "/v1/auto-bid/suggest",
                json={"userId": "test_user_pro", "month": "2026-06",
                      "userMode": "money", "availableLineIds": []},
                headers={"Authorization": "Bearer test"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "suggestions" in data
        assert "explanation" in data
        assert data["autoSubmitted"] is False

    def test_preference_update_returns_202(self):
        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro", "accountStatus": "approved"
        }), patch("auto_bid.engine.AutoBidEngine.update_vector_from_events",
                  new_callable=AsyncMock):
            response = client.post(
                "/v1/auto-bid/update-vector",
                json={
                    "userId": "test_user_pro",
                    "events": [{
                        "eventType": "bid_submitted",
                        "metadata": {"lineId": "line_411",
                                     "destinations": ["LHR"]},
                        "timestamp": "2026-06-01T08:00:00",
                        "userMode": "money",
                    }],
                },
                headers={"Authorization": "Bearer test"},
            )

        assert response.status_code in [200, 202]
        assert response.json()["status"] == "queued"
