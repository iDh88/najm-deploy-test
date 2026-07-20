"""
pytest configuration and shared fixtures for CIP Python Services tests.
"""
import pytest
import asyncio
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch
from typing import Generator


# ─── Offline-harness compatibility shim ───────────────────────────────────────
# Several tests were authored against tools/offline_harness, whose fake pytest
# exposes `pytest.run_async`. Provide the same helper under real pytest so those
# tests behave identically in both harnesses. Mirrors
# tools/offline_harness/shims/pytest.py::run_async.
def _run_async(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


pytest.run_async = _run_async


# ─── Event Loop ───────────────────────────────────────────────────────────────
@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


# ─── Mock Firebase ────────────────────────────────────────────────────────────
@pytest.fixture(autouse=True)
def mock_firebase():
    """Auto-mock Firebase for all tests — no real Firebase connections."""
    mock_db = MagicMock()
    mock_bucket = MagicMock()

    with patch("utils.firebase.get_firestore", return_value=mock_db), \
         patch("utils.firebase.get_storage", return_value=mock_bucket), \
         patch("utils.firebase.initialize_firebase"):
        yield mock_db, mock_bucket


# ─── Mock Anthropic API ───────────────────────────────────────────────────────
@pytest.fixture
def mock_claude():
    """Mock Claude API responses."""
    with patch("ai.nlp_router.claude_client") as mock:
        mock.messages.create.return_value = MagicMock(
            content=[MagicMock(type="text", text='{"destinations": ["LHR"], "maxDutyHours": 100}')]
        )
        yield mock


# ─── Sample Data Fixtures ─────────────────────────────────────────────────────
@pytest.fixture
def sample_leg_domestic():
    """A valid domestic leg with legal rest."""
    from parser.excel_parser import ParsedLeg
    base = datetime(2026, 6, 15, 8, 0)
    return ParsedLeg(
        id="leg-dom-001",
        lineId="line-001",
        flightNumber="SV100",
        origin="RUH",
        destination="JED",
        legType="domestic",
        departureLT=base.isoformat(),
        arrivalLT=(base + timedelta(hours=1, minutes=30)).isoformat(),
        departureUTC=base.isoformat(),
        arrivalUTC=(base + timedelta(hours=1, minutes=30)).isoformat(),
        dutyStart=(base - timedelta(hours=1)).isoformat(),
        dutyEnd=(base + timedelta(hours=2, minutes=30)).isoformat(),
        releaseTime=(base + timedelta(hours=3)).isoformat(),
        blockHours=1.5,
        fdpHours=3.5,
        restBeforeHours=16.0,
        restAfterHours=16.0,
        estimatedPay=225.0,
        perDiem=50.0,
        payRate=100.0,
        sequence=0,
    )


@pytest.fixture
def sample_leg_international():
    """A valid international leg (RUH→LHR) with legal rest."""
    from parser.excel_parser import ParsedLeg
    base = datetime(2026, 6, 15, 10, 0)
    return ParsedLeg(
        id="leg-int-001",
        lineId="line-001",
        flightNumber="SV118",
        origin="RUH",
        destination="LHR",
        legType="international",
        departureLT=base.isoformat(),
        arrivalLT=(base + timedelta(hours=6, minutes=45)).isoformat(),
        departureUTC=base.isoformat(),
        arrivalUTC=(base + timedelta(hours=6, minutes=45)).isoformat(),
        dutyStart=(base - timedelta(hours=1)).isoformat(),
        dutyEnd=(base + timedelta(hours=8)).isoformat(),
        releaseTime=(base + timedelta(hours=8, minutes=30)).isoformat(),
        blockHours=6.75,
        fdpHours=9.0,
        layover=True,
        layoverHours=36.0,
        restBeforeHours=18.0,
        restAfterHours=36.0,
        estimatedPay=1212.5,
        perDiem=150.0,
        payRate=160.0,
        sequence=0,
    )


@pytest.fixture
def sample_line_summary():
    """A representative line summary for scoring tests."""
    return {
        "totalLegs": 8,
        "totalBlockHours": 52.0,
        "totalDutyHours": 68.0,
        "totalDutyDays": 14,
        "internationalLegs": 4,
        "domesticLegs": 4,
        "layoverCount": 2,
        "estimatedSalaryMin": 10800.0,
        "estimatedSalaryMax": 12000.0,
        "salaryScore": 72.0,
        "restQualityScore": 85.0,
        "compositeScore": 78.5,
    }


@pytest.fixture
def sample_preference_vector():
    """A realistic preference vector for a pro user."""
    from auto_bid.engine import PreferenceVector
    return PreferenceVector(
        userId="user-001",
        destAffinities={
            "LHR": 0.9,
            "CDG": 0.7,
            "FRA": 0.5,
            "LAX": -0.3,
            "RUH": 0.0,
        },
        layoverPreference=0.7,
        dayOffPreferences=[0.3, 0.4, 0.5, 0.5, 0.9, 1.0, 0.8],  # Fri+Sat strong preference
        intlDomRatio=0.7,
        salarySensitivity=0.6,
        eventCount=45,
    )


# ─── HTTP Test Client ─────────────────────────────────────────────────────────
@pytest.fixture
def test_client():
    """FastAPI test client."""
    from fastapi.testclient import TestClient
    from main import app
    return TestClient(app)
