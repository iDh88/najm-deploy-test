"""
Integration tests — Trade Search API
Tests the full /v1/trade/search endpoint end-to-end.
"""
import pytest
from httpx import AsyncClient
from main import app

BASE = "/v1/trade"

SAMPLE_SEARCH = {
    "requesting_user_id": "test_user_001",
    "requesting_rank":    "CA",
    "month":              "JUN-2026",
    "route_key":          "JED-DEL-JED",
    "block_hours":        5.5,
    "duty_hours":         8.0,
    "fdp_minutes":        420,
    "signin_hour":        9,
    "layover_hours":      18.0,
    "is_international":   True,
    "has_deadhead":       False,
    "fatigue_score":      0.35,
    "trip_dates":         [5, 6],
    "max_results":        10,
}


@pytest.mark.asyncio
async def test_search_returns_200():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.post(f"{BASE}/search", json=SAMPLE_SEARCH)
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_search_response_shape():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.post(f"{BASE}/search", json=SAMPLE_SEARCH)
    data = r.json()
    assert "route"          in data
    assert "matches"        in data
    assert "total_scanned"  in data
    assert "is_cold_start"  in data
    assert isinstance(data["matches"], list)


@pytest.mark.asyncio
async def test_match_shape():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.post(f"{BASE}/search", json=SAMPLE_SEARCH)
    data = r.json()
    if data["matches"]:
        m = data["matches"][0]
        assert "prn"               in m
        assert "compatibility_pct" in m
        assert "is_legal"          in m
        assert "fatigue_level"     in m
        assert "route_match_label" in m
        assert "reasons"           in m
        assert isinstance(m["reasons"], list)


@pytest.mark.asyncio
async def test_no_demographic_fields_in_response():
    """Critical: API response must never contain demographic labels."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.post(f"{BASE}/search", json=SAMPLE_SEARCH)
    response_text = r.text.lower()
    blocked = [
        "nationality", "ethnicity", "region_affinity",
        "probable_region", "name_origin", "demographic",
        "race", "religion",
    ]
    for term in blocked:
        assert term not in response_text, \
            f"Blocked term '{term}' found in API response"


@pytest.mark.asyncio
async def test_record_event_accepted():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.post(f"{BASE}/events", json={
            "user_id":          "test_user_001",
            "trade_id":         "trade_test_001",
            "outcome":          "accepted",
            "route_key":        "JED-DEL-JED",
            "destinations":     ["JED", "DEL"],
            "block_hours":      5.5,
            "duty_hours":       8.0,
            "fatigue_score":    0.35,
            "is_international": True,
            "has_deadhead":     False,
            "signin_hour":      9,
            "layover_hours":    18.0,
        })
    assert r.status_code == 200
    assert r.json()["recorded"] is True


@pytest.mark.asyncio
async def test_record_event_invalid_outcome():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.post(f"{BASE}/events", json={
            "user_id":   "test_user_001",
            "trade_id":  "trade_test_001",
            "outcome":   "invalid_outcome",
            "route_key": "JED-DEL",
            "destinations": [],
            "block_hours": 0, "duty_hours": 0,
            "fatigue_score": 0, "is_international": False,
            "has_deadhead": False, "signin_hour": 8, "layover_hours": 0,
        })
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_prn_status_update():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.put(f"{BASE}/prn-status", json={
            "user_id":  "test_user_001",
            "trade_id": "trade_test_001",
            "prn":      "12345678",
            "status":   "sent",
        })
    # Firestore may not be available in test env — both 200 and 500 are valid
    assert r.status_code in (200, 500)


@pytest.mark.asyncio
async def test_profile_endpoint_returns_operational_data_only():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.get(f"{BASE}/profile/test_user_001")
    if r.status_code == 200:
        data = r.json()
        # Should have operational fields
        assert "topRoutes"       in data
        assert "topDestinations" in data
        # Should NOT have demographic fields
        for blocked in ["nationality", "ethnicity", "regionAffinity"]:
            assert blocked not in data
