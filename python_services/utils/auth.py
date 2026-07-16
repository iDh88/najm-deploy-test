"""
utils/auth.py — Request authentication middleware
Verifies Firebase ID tokens on every protected endpoint.
"""

import os
import hmac
import logging
from fastapi import HTTPException, Header, Depends
from typing import Annotated, Optional
from utils.firebase import verify_firebase_token

logger = logging.getLogger("cip.auth")


async def verify_firebase_auth(
    authorization: Annotated[str | None, Header()] = None
) -> dict:
    """
    FastAPI dependency — verifies Bearer token in Authorization header.
    Usage: user_claims = Depends(verify_firebase_auth)
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization must be Bearer token")

    token = authorization[7:]
    try:
        claims = verify_firebase_token(token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))

    # T2 — require an approved account on every user-facing endpoint. Service
    # calls never reach here (they authenticate via verify_service_token), so
    # this gates real users only. Claims propagate on ID-token refresh, so a
    # just-approved user may need a token refresh (same as Firestore rules).
    if claims.get("accountStatus") != "approved":
        raise HTTPException(status_code=403, detail="Account is not approved")
    return claims


async def verify_service_token(
    x_service_token: Annotated[str | None, Header()] = None
) -> bool:
    """
    Verify internal service-to-service token (Cloud Functions → Python service).

    FAILS CLOSED. If INTERNAL_SERVICE_TOKEN is not configured, the request is
    refused with 503 rather than allowed. The previous implementation returned
    True when the env var was missing, which silently disabled ALL service auth
    on any misconfigured / freshly-provisioned environment — the core of the
    0.1 finding. Comparison is constant-time to avoid token-timing leaks.
    """
    expected = os.getenv("INTERNAL_SERVICE_TOKEN")
    if not expected:
        logger.error(
            "INTERNAL_SERVICE_TOKEN is not set — refusing request (fail closed)"
        )
        raise HTTPException(
            status_code=503, detail="Service authentication is not configured"
        )
    if not x_service_token or not hmac.compare_digest(x_service_token, expected):
        raise HTTPException(status_code=403, detail="Invalid service token")
    return True


async def verify_service_or_user(
    authorization: Annotated[str | None, Header()] = None,
    x_service_token: Annotated[str | None, Header()] = None,
) -> dict:
    """
    Dependency for endpoints reachable by BOTH callers:
      • the Cloud Functions layer (service-to-service, via X-Service-Token), and
      • the Flutter app directly (end users, via a Firebase Bearer token).

    Resolution order:
      1. If X-Service-Token is supplied, it must be valid (fails closed on an
         unconfigured token, exactly like verify_service_token).
      2. Otherwise, verify the Firebase Bearer token.
      3. If neither is supplied, reject with 401.

    Returns a claims dict. Service calls get a sentinel {"service": True,
    "uid": None} — there is no end-user identity, so any user_id must come from
    the (trusted) service request body. User calls get the decoded Firebase
    token, which includes `uid`.
    """
    if x_service_token is not None:
        await verify_service_token(x_service_token=x_service_token)
        return {"service": True, "uid": None}
    if authorization:
        return await verify_firebase_auth(authorization=authorization)
    raise HTTPException(
        status_code=401,
        detail="Missing credentials: provide a Firebase Bearer token or X-Service-Token",
    )


# require_tier() removed (0.3) — it was superseded, unused dead code. Entitlement
# is decided by subscription_engine.feature_gate.FeatureGate (Firestore-config
# driven), the system the Admin Panel controls.


def resolve_user_id(claims: dict, body_user_id: str) -> str:
    """
    Dual-caller identity resolution (Phase 1 / T1).

    - Service calls (Cloud Functions) act on behalf of a user and may pass any
      user_id in the (trusted) request body.
    - User calls are pinned to their own verified token uid, so an authenticated
      user can never operate on another user's id by spoofing the body/path.
    """
    if claims.get("service"):
        return body_user_id
    uid = claims.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Missing authenticated user id")
    return uid


# ── Sync header-string helpers (P1-1 closure for legacy routers) ──────────────
# subscription_engine and knowledge_engine predate the Depends() dependencies
# above and take the raw Authorization header string. These helpers give them
# the SAME hardened path — utils.firebase.verify_firebase_token with
# check_revoked=True — instead of calling firebase_admin.auth.verify_id_token
# directly (which silently skipped revocation checks).

def _decode_bearer(authorization: Optional[str]) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing authorization token")
    token = authorization.split(" ", 1)[1]
    try:
        from utils.firebase import verify_firebase_token
        return verify_firebase_token(token)  # check_revoked=True inside
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


def require_admin_claims(authorization: Optional[str], privilege: str) -> dict:
    """Revocation-checked admin gate: superAdmin, or admin holding `privilege`.
    Also requires an approved account (suspended admins lose API access even
    before their revoked token would expire)."""
    decoded = _decode_bearer(authorization)
    if decoded.get("accountStatus") not in (None, "approved"):
        raise HTTPException(status_code=403, detail="Account is not approved")
    is_super   = decoded.get("superAdmin") is True
    is_admin   = decoded.get("admin") is True
    privileges = decoded.get("privileges") or []
    if not (is_super or (is_admin and privilege in privileges)):
        raise HTTPException(status_code=403, detail=f"{privilege} privilege required")
    return decoded


def require_approved_user_claims(authorization: Optional[str]) -> dict:
    """Revocation-checked end-user gate; account must be approved."""
    decoded = _decode_bearer(authorization)
    if decoded.get("accountStatus") != "approved":
        raise HTTPException(status_code=403, detail="Account is not approved")
    return decoded
