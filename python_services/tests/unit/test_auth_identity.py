"""
Unit tests for Phase 1 auth hardening:
  - resolve_user_id (T1): user calls pinned to token uid, service calls trust body
  - approval enforcement (T2) is covered at the dependency level in integration tests

Runs under the repo's normal pytest environment (fastapi/pydantic installed).
"""
import pytest
from fastapi import HTTPException

from utils.auth import resolve_user_id


class TestResolveUserId:
    def test_service_call_trusts_body_user_id(self):
        # Service calls (Cloud Functions) may act on behalf of any user.
        claims = {"service": True, "uid": None}
        assert resolve_user_id(claims, "user-abc") == "user-abc"

    def test_user_call_is_pinned_to_token_uid(self):
        # An authenticated user is pinned to their own uid regardless of the body.
        claims = {"uid": "real-uid"}
        assert resolve_user_id(claims, "someone-elses-id") == "real-uid"

    def test_user_call_ignores_spoofed_body(self):
        claims = {"uid": "real-uid"}
        # Even if the attacker matches nothing, they only ever get their own id.
        assert resolve_user_id(claims, "") == "real-uid"

    def test_missing_uid_on_user_call_raises_401(self):
        with pytest.raises(HTTPException) as exc:
            resolve_user_id({}, "whatever")
        assert exc.value.status_code == 401

    def test_service_flag_false_is_treated_as_user(self):
        claims = {"service": False, "uid": "real-uid"}
        assert resolve_user_id(claims, "spoof") == "real-uid"
