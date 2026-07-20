"""roster_sync/schema.py — wire + storage contracts for roster synchronization.

SECURITY INVARIANT (feature spec): credentials never touch NAJM servers.
The import endpoint therefore accepts roster PAYLOADS only, and
`assert_no_credentials` rejects any request whose JSON contains
credential-shaped keys — defence in depth against a misbehaving client build
ever leaking a secret into our logs or storage.

Orchestration modes (the architectural reconciliation of "automatic sync"
with "credentials only in Keychain/Keystore"):
  * client_orchestrated — the DEVICE authenticates to the provider with the
    locally-stored credentials, fetches the roster, and POSTs the payload
    here. The server sees data, never secrets. This is the default and the
    only mode available to password-style providers.
  * server_orchestrated — reserved for official enterprise integrations that
    issue NAJM service credentials (config/secret-manager, never user
    passwords). No provider ships enabled in this mode today.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


# ── Credential guard ─────────────────────────────────────────────────────────

# Zero-Knowledge Credential Model (owner directive, 2026-07-12): the
# fragments below cover every field name the directive forbids on backend
# APIs — password, secret, credential, token, authHeader, authorization,
# sessionCookie, refreshToken, providerPassword/Secret/Credential — plus
# PRN and cookie/session/bearer generally. Substring matching means the
# camelCase composites are caught by their fragments.
# Zero-Knowledge Credential Model — Backend Contract (owner directive):
# "Backend APIs MUST NEVER expose fields such as: password, secret,
#  credential, token, authHeader, authorization, sessionCookie, refreshToken,
#  providerPassword, providerSecret, providerCredential."
# Enumerated verbatim so the directive is auditable against the code, then
# generalized to fragments so camelCase/snake_case/kebab variants are caught
# too (providerPassword, refresh_token, session-cookie, …).
_FORBIDDEN_FIELD_NAMES = (
    "password", "secret", "credential", "token", "authHeader",
    "authorization", "sessionCookie", "refreshToken", "providerPassword",
    "providerSecret", "providerCredential",
)
_CREDENTIAL_KEY_FRAGMENTS = (
    "password", "passwd", "secret", "token", "credential", "apikey",
    "api_key", "auth", "pin", "otp", "cookie", "session", "bearer", "prn",
)
# Keys that contain a fragment but are NOT secrets. Kept deliberately tiny:
# every entry is a hole in the wall, so each one is justified here.
#   auth_kind — which credential FIELDS a provider needs ("prn_password"),
#               a UI hint; carries no secret value.
_ALLOWED_EXACT = {"auth_kind", "authkind"}


class CredentialLeakError(ValueError):
    pass


def assert_no_credentials(obj: Any, path: str = "$") -> None:
    """Recursively reject credential-shaped keys anywhere in a payload."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            kl = str(k).lower()
            if kl not in _ALLOWED_EXACT and any(
                    frag in kl for frag in _CREDENTIAL_KEY_FRAGMENTS):
                raise CredentialLeakError(
                    f"credential-shaped key '{k}' at {path} — NAJM servers "
                    "never accept or store provider credentials; keep them "
                    "in the device Keychain/Keystore")
            assert_no_credentials(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            assert_no_credentials(v, f"{path}[{i}]")


def assert_no_credentials_out(obj: Any, where: str = "response") -> None:
    """Outbound wall. The directive forbids the backend from *exposing*
    credential-shaped fields, not merely from accepting them. Every
    /v1/roster-sync response is screened through this before it is returned,
    so a future field named `refreshToken` cannot quietly appear in an API
    payload — it fails loudly in tests and in staging instead.

    NOTE: this screens response BODIES. The `Authorization: Bearer <Firebase
    ID token>` request header is NAJM's own user identity — not a roster
    provider credential — and is untouched by this wall (it is, however,
    redacted from logs by utils.logging_config.SecretRedactionFilter).
    """
    try:
        assert_no_credentials(obj, path="$")
    except CredentialLeakError as exc:
        raise CredentialLeakError(
            f"outbound {where} carries a credential-shaped field: {exc}"
        ) from exc


# ── Normalized roster model (every provider converges here) ─────────────────

class NormalizedLeg(BaseModel):
    flightNumber: str
    origin: str
    destination: str
    legType: str = "domestic"              # domestic | international
    departureLT: datetime
    arrivalLT: datetime
    dutyStart: Optional[datetime] = None   # derived if absent
    dutyEnd: Optional[datetime] = None
    blockHours: float = 0.0
    aircraftType: str = ""
    layover: bool = False
    layoverHours: float = 0.0


class NormalizedRoster(BaseModel):
    period: str                            # e.g. JUN-2026
    year: int
    legs: list[NormalizedLeg]
    provider_note: str = ""                # parser provenance, human-readable


# ── Connection / version / import records (Firestore-backed) ────────────────

class ConnectionStatus:
    CONNECTED = "connected"
    AWAITING_OFFICIAL_INTEGRATION = "awaiting_official_integration"
    ERROR = "error"
    DISCONNECTED = "disconnected"


class RosterConnection(BaseModel):
    user_id: str
    provider_id: str
    status: str
    orchestration: str = "client_orchestrated"
    connected_at: Optional[datetime] = None
    last_sync_at: Optional[datetime] = None
    last_success_at: Optional[datetime] = None
    next_sync: str = "automatic"           # advisory; device scheduler decides
    last_error: Optional[str] = None
    imported_flights_last: int = 0
    auto_sync: bool = True


class VersionEntry(BaseModel):
    version: int
    checksum: str
    imported_flights: int
    at: datetime
    added: int = 0
    removed: int = 0
    changed: int = 0


# ── API request/response shapes ──────────────────────────────────────────────

class ConnectRequest(BaseModel):
    provider_id: str
    # Service-lane identity: Cloud Functions act on behalf of a user and pass
    # the user id here (resolve_user_id trusts it only for service callers;
    # user calls are always pinned to their verified token uid).
    user_id: str = ""
    # Non-secret client hints only (e.g. base station). NEVER credentials —
    # the router runs assert_no_credentials over the raw body.
    client_meta: dict = Field(default_factory=dict)


class ImportRequest(BaseModel):
    provider_id: str
    # Service-lane identity — same semantics as ConnectRequest.user_id.
    user_id: str = ""
    period: str
    year: int
    payload_kind: str                      # "ics" | "normalized"
    # ics → the raw text of the fetched calendar; normalized → NormalizedRoster
    payload: Any
    device_checksum: Optional[str] = None  # client's sha256 for early dedup
    sync_duration_ms: Optional[int] = None # device-measured, for analytics


class EngineStatus(BaseModel):
    engine: str
    status: str                            # ok | failed | on_demand | queued
    detail: str = ""


class ImportResponse(BaseModel):
    result: str                            # imported | duplicate | failed
    line_id: Optional[str] = None
    version: Optional[int] = None
    imported_flights: int = 0
    diff: dict = Field(default_factory=dict)
    engines: list[EngineStatus] = []
    checksum: Optional[str] = None


class SyncNowResponse(BaseModel):
    action: str        # client_sync_required | server_synced | unavailable
    detail: str = ""


class ProviderInfo(BaseModel):
    provider_id: str
    display_name: str
    recommended: bool = False
    auth_kind: str                        # prn_password | feed_url | none
    orchestration: str
    availability: str    # available | pending_official_integration |
    #                      requires_owner_approval (dormant, needs ADR-001 sign-off)
    availability_note: str = ""
    payload_kinds: list[str] = []
    # Which party can see the user's provider credentials for this source.
    # "zero_knowledge" = device-only (the platform default and preferred
    # model); "server_orchestrated" = NAJM service credentials server-side,
    # which requires explicit owner approval (ADR-001).
    trust_model: str = "zero_knowledge"
    # Non-secret runtime config for the device connector (e.g. an official
    # endpoint descriptor). Present so adapters need no hardcoded endpoints.
    client_config: dict = Field(default_factory=dict)


class StatusResponse(BaseModel):
    connections: list[RosterConnection]
    providers: list[ProviderInfo]
    preferred_source: str                 # provider_id or "manual_pdf"
    versions_latest: dict = Field(default_factory=dict)  # provider→VersionEntry
    # The trust model actually in force for this user's roster sync, so the
    # app can state it plainly instead of the user having to trust a claim.
    # "zero_knowledge" unless the owner has approved a server-orchestrated
    # adapter (ADR-001) AND the user is connected through it.
    trust_model: str = "zero_knowledge"
