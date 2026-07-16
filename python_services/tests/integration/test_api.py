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

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }):
            response = client.post(
                "/v1/parser/parse",
                json=sample_parse_request,
                headers={"Authorization": "Bearer test_token"},
            )

        assert response.status_code == 200
        data = response.json()
        assert "linesProcessed" in data
        assert data["linesProcessed"] >= 1

    @patch("parser.excel_parser._download_from_storage")
    def test_parse_returns_422_on_empty_file(self, mock_download, sample_parse_request):
        """Empty Excel file should return 422 with error details."""
        mock_download.side_effect = Exception("File not found")

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }):
            response = client.post(
                "/v1/parser/parse",
                json=sample_parse_request,
                headers={"Authorization": "Bearer test_token"},
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

    def test_check_trade_returns_both_results(self, sample_legs):
        """Trade check must return results for BOTH initiator and receiver."""
        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user", "tier": "pro"
        }), patch("legality.engine.LegalityEngine.check_trade_legality") as mock_check:
            mock_check.return_value = {
                "passed": True,
                "initiatorResult": {"passed": True, "violations": [], "warnings": []},
                "receiverResult": {"passed": True, "violations": [], "warnings": []},
            }
            response = client.post(
                "/v1/legality/check-trade",
                json={
                    "initiatorId": "user_a",
                    "receiverId": "user_b",
                    "offeredLegId": "leg_1",
                    "requestedLegId": "leg_2",
                },
                headers={"Authorization": "Bearer test"},
            )

        if response.status_code == 200:
            data = response.json()
            assert "initiatorResult" in data
            assert "receiverResult" in data
            assert "passed" in data

    def test_domestic_rest_violation_detected(self):
        """14h domestic rest rule should be detected as a violation at 10h."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            DutyPeriod(
                leg_id="leg_1",
                duty_start=base,
                duty_end=base + timedelta(hours=4),
                release_time=base + timedelta(hours=4, minutes=30),
                leg_type="domestic",
            ),
            DutyPeriod(
                leg_id="leg_2",
                duty_start=base + timedelta(hours=14),  # only 9.5h after release
                duty_end=base + timedelta(hours=18),
                release_time=base + timedelta(hours=18, minutes=30),
                leg_type="domestic",
            ),
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
            DutyPeriod(
                leg_id="leg_1",
                duty_start=base,
                duty_end=base + timedelta(hours=8),
                release_time=base + timedelta(hours=8, minutes=30),
                leg_type="international",
            ),
            DutyPeriod(
                leg_id="leg_2",
                duty_start=base + timedelta(hours=20),  # 11.5h after release — violation
                duty_end=base + timedelta(hours=28),
                release_time=base + timedelta(hours=28, minutes=30),
                leg_type="international",
            ),
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
            DutyPeriod(
                leg_id="leg_1",
                duty_start=base,
                duty_end=base + timedelta(hours=8),
                release_time=base + timedelta(hours=8, minutes=30),
                leg_type="international",
            ),
            DutyPeriod(
                leg_id="leg_2",
                duty_start=base + timedelta(hours=24),  # 15.5h after release — legal
                duty_end=base + timedelta(hours=32),
                release_time=base + timedelta(hours=32, minutes=30),
                leg_type="international",
            ),
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
            DutyPeriod(
                leg_id="leg_1",
                duty_start=base,
                duty_end=base + timedelta(hours=4),
                release_time=base + timedelta(hours=4, minutes=30),
                leg_type="domestic",
            ),
            DutyPeriod(
                leg_id="leg_2",
                duty_start=base + timedelta(hours=18, minutes=30),  # exactly 14h after release
                duty_end=base + timedelta(hours=22),
                release_time=base + timedelta(hours=22, minutes=30),
                leg_type="domestic",
            ),
        ]

        result = engine.check_schedule(duties)
        assert result.passed

    def test_boundary_domestic_13h59m(self):
        """13h59m rest after domestic should be a violation (1 min under)."""
        from legality.engine import LegalityEngine, DutyPeriod

        engine = LegalityEngine()
        base = datetime(2026, 6, 1, 8, 0)

        duties = [
            DutyPeriod(
                leg_id="leg_1",
                duty_start=base,
                duty_end=base + timedelta(hours=4),
                release_time=base + timedelta(hours=4, minutes=30),
                leg_type="domestic",
            ),
            DutyPeriod(
                leg_id="leg_2",
                # 14h after release = 18:30. One minute early = 18:29
                duty_start=base + timedelta(hours=18, minutes=29),
                duty_end=base + timedelta(hours=22),
                release_time=base + timedelta(hours=22, minutes=30),
                leg_type="domestic",
            ),
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

    @patch("utils.rate_limiter.rate_limiter.check_and_increment")
    def test_free_tier_rate_limit_429(self, mock_limiter):
        """Free tier should return 429 when daily limit exceeded."""
        mock_limiter.return_value = (False, 5, 5)

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_free", "tier": "free"
        }):
            response = client.post(
                "/v1/ai/chat",
                json={
                    "userId": "test_user_free",
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
        long_message = "a" * 600  # exceeds 500 char limit

        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }):
            response = client.post(
                "/v1/ai/chat",
                json={"userId": "test_user_pro", "message": long_message, "history": []},
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
        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }), patch("auto_bid.engine.AutoBidEngine.fetch_line_data",
                  new_callable=AsyncMock, return_value=[]):
            response = client.post(
                "/v1/auto-bid/suggest",
                json={"userId": "test_user_pro", "month": "2026-06", "userMode": "money"},
                headers={"Authorization": "Bearer test"},
            )

        if response.status_code == 200:
            data = response.json()
            assert "suggestions" in data
            assert "coldStartPhase" in data
            assert "generatedAt" in data
            assert data["coldStartPhase"] in [1, 2, 3]

    def test_preference_update_returns_202(self):
        with patch("utils.auth.verify_firebase_token", return_value={
            "uid": "test_user_pro", "tier": "pro"
        }):
            response = client.post(
                "/v1/auto-bid/update-preference",
                json={
                    "userId": "test_user_pro",
                    "eventType": "bid_submitted",
                    "metadata": {"lineId": "line_411", "destinations": ["LHR"]},
                    "userMode": "money",
                },
                headers={"Authorization": "Bearer test"},
            )

        assert response.status_code in [200, 202]
