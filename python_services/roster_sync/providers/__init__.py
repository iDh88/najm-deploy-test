"""roster_sync/providers — the common provider interface + registry.

Adding a provider (Sabre, Jeppesen, AIMS, NetLine, Excel, Email…) is one
subclass registered here; the API catalog, the status screen, the Flutter
connector picker and the import endpoint all pick it up. This mirrors the
filter_engine registry pattern.

HONESTY CONTRACT (feature spec): a provider may not fake capability.
`availability` must reflect reality:
  * "available" — the documented mechanism works today (ICS: standard feed
    text; manual_pdf: the shipped upload flow).
  * "pending_official_integration" — the full connector scaffold exists and
    activates purely through configuration when the official API/enterprise
    endpoints are provided. Connect attempts return this state; nothing is
    scraped, nothing is simulated.
"""
from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from typing import Optional

from ..schema import NormalizedRoster, ProviderInfo
from ..ics_parser import DEFAULT_PROFILE, ParseReport, parse_ics

logger = logging.getLogger("cip.roster_sync.providers")


class ProviderNotAvailable(Exception):
    """Raised when a flow needs an official integration that isn't
    configured. Carries the user-facing note."""

    def __init__(self, note: str):
        super().__init__(note)
        self.note = note


class TrustModel:
    """Which party can see a user's provider credentials."""
    ZERO_KNOWLEDGE = "zero_knowledge"            # device-only; NAJM never sees
    SERVER_ORCHESTRATED = "server_orchestrated"  # NAJM service creds server-side


# Availability states.
AVAILABLE = "available"
PENDING_OFFICIAL = "pending_official_integration"
REQUIRES_OWNER_APPROVAL = "requires_owner_approval"
# A source named in the product brief that is genuinely not built. Shown to
# the user as unavailable — never as a working tile that silently does
# nothing ("No placeholders. No mock implementations.").
NOT_IMPLEMENTED = "not_implemented"


def owner_approved_server_orchestration() -> tuple[bool, str]:
    """Zero-Knowledge directive, Architecture Rule:

        "Changing from client-managed credentials to server-managed
         credentials is considered an architectural decision. It MUST NOT
         happen automatically. It MUST require explicit approval from the
         project owner."

    So server-orchestrated providers are NOT activated by ordinary service
    configuration. They additionally require a deliberately-named approval
    reference — a value nobody sets by accident while wiring an API base URL:

        ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL="<owner>/<date>/<ADR-001>"

    Absent it, the adapter stays dormant and says so. See
    docs/adr/ADR-001-zero-knowledge-credentials.md.
    """
    ref = os.environ.get("ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL", "").strip()
    return bool(ref), ref


@dataclass(frozen=True)
class ProviderCapabilities:
    supports_delta: bool = False
    supports_server_orchestration: bool = False
    payload_kinds: tuple[str, ...] = ("normalized",)


class RosterProvider:
    provider_id: str = ""
    display_name: str = ""
    recommended: bool = False
    auth_kind: str = "none"                 # prn_password | feed_url | none
    orchestration: str = "client_orchestrated"

    @property
    def trust_model(self) -> str:
        return (TrustModel.SERVER_ORCHESTRATED
                if self.orchestration == "server_orchestrated"
                else TrustModel.ZERO_KNOWLEDGE)

    def client_config(self) -> dict:
        """Non-secret runtime configuration handed to the device connector
        (e.g. the official endpoint descriptor once a provider publishes
        one). Keeping this in CONFIG is what lets the adapter ship with no
        hardcoded endpoints while still being activatable without an app
        release. Never contains secrets."""
        return {}

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities()

    def availability(self) -> tuple[str, str]:
        """→ ("available" | "pending_official_integration", note)."""
        return "available", ""

    # Client-orchestrated providers receive PAYLOADS (never credentials);
    # parse_payload turns a payload of a supported kind into a roster.
    def parse_payload(self, kind: str, payload, period: str,
                      year: int) -> tuple[Optional[NormalizedRoster], list[str]]:
        raise NotImplementedError

    # Server-orchestrated slot — only meaningful once availability() says
    # "available" for a server-orchestrated provider. Never called otherwise.
    def server_fetch(self, user_id: str, period: str,
                     year: int) -> NormalizedRoster:   # pragma: no cover
        raise ProviderNotAvailable(self.availability()[1])

    def info(self) -> ProviderInfo:
        avail, note = self.availability()
        return ProviderInfo(
            provider_id=self.provider_id,
            display_name=self.display_name,
            recommended=self.recommended,
            auth_kind=self.auth_kind,
            orchestration=self.orchestration,
            availability=avail,
            availability_note=note,
            payload_kinds=list(self.capabilities().payload_kinds),
            trust_model=self.trust_model,
            client_config=self.client_config(),
        )


# ── CAE Crew Access — the recommended source, scaffolded honestly ────────────

class CaeCrewAccessProvider(RosterProvider):
    """CAE Crew Access — CLIENT adapter (Zero-Knowledge lane). The default.

    Trust model: the DEVICE authenticates directly with CAE's official API
    and uploads a NORMALIZED roster. NAJM's backend never receives, stores,
    caches or logs the crew member's PRN or password — it cannot, because
    they never arrive (schema.assert_no_credentials is the second wall).

    Honest scaffolding, per the owner directive:
      * NO hardcoded endpoints. NO undocumented protocol. NO reverse-
        engineered authentication. NO placeholder implementation that would
        imply the integration already exists.
      * The official endpoint descriptor arrives as CONFIGURATION
        (CAE_OFFICIAL_DEVICE_CONFIG, a non-secret JSON blob relayed to the
        device via ProviderInfo.client_config) so the adapter activates
        WITHOUT an app release and without a URL ever being baked into the
        codebase.
      * Until CAE publishes an official integration, availability() reports
        pending_official_integration, the device connector stores nothing,
        and imports are refused (409). The module compiles and the platform
        is production-ready with this adapter inactive.
    """

    provider_id = "cae_crew_access"
    display_name = "CAE Crew Access"
    recommended = True
    auth_kind = "prn_password"
    orchestration = "client_orchestrated"        # → trust_model zero_knowledge

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(
            supports_delta=True,
            supports_server_orchestration=False,  # never, on this adapter
            payload_kinds=("normalized",),        # device normalizes; raw never
        )

    def _official_device_integration(self) -> bool:
        return os.environ.get(
            "CAE_OFFICIAL_DEVICE_INTEGRATION", "").strip().lower() in (
                "1", "true", "on", "yes")

    def client_config(self) -> dict:
        """Endpoint/protocol descriptor supplied by ops once CAE grants
        official access — never a secret, never hardcoded here."""
        raw = os.environ.get("CAE_OFFICIAL_DEVICE_CONFIG", "").strip()
        if not raw:
            return {}
        try:
            cfg = json.loads(raw)
            return cfg if isinstance(cfg, dict) else {}
        except json.JSONDecodeError:
            logger.error("CAE_OFFICIAL_DEVICE_CONFIG is not valid JSON — "
                         "ignoring (adapter stays inactive)")
            return {}

    def availability(self) -> tuple[str, str]:
        if self._official_device_integration():
            return AVAILABLE, (
                "Official CAE device integration enabled. Your PRN and "
                "password are used on this device only, to sign in to CAE "
                "directly — NAJM's servers never receive them.")
        return PENDING_OFFICIAL, (
            "NAJM connects to CAE Crew Access only through an official CAE "
            "integration. The connector is ready and activates by "
            "configuration the moment official access is granted — no "
            "unofficial automation, credential scraping or reverse-"
            "engineered login is used, now or later. Until then, use the "
            "calendar feed or manual PDF upload.")

    def parse_payload(self, kind, payload, period, year):
        if not self._official_device_integration():
            raise ProviderNotAvailable(self.availability()[1])
        if kind != "normalized":
            return None, [f"unsupported payload kind '{kind}' for CAE — the "
                          "device normalizes before upload"]
        try:
            return NormalizedRoster(**payload), []
        except Exception as exc:  # noqa: BLE001 — surfaced to caller
            return None, [f"normalized payload invalid: {exc}"]

    def server_fetch(self, user_id, period, year):   # pragma: no cover
        # Structurally impossible on the zero-knowledge lane: the server has
        # no credentials to fetch with. Enterprise orchestration lives in its
        # own adapter and needs the owner's approval (ADR-001).
        raise ProviderNotAvailable(
            "cae_crew_access is a zero-knowledge, device-orchestrated "
            "adapter — the server holds no credentials and cannot fetch. "
            "Server-side orchestration requires the separate enterprise "
            "adapter and explicit owner approval (ADR-001).")


class CaeEnterpriseProvider(RosterProvider):
    """CAE Crew Access — ENTERPRISE adapter (server-orchestrated lane).

    The directive's "Future Enterprise Integrations" clause: if CAE later
    publishes an enterprise API requiring server-side orchestration, we do
    NOT rewrite the zero-knowledge architecture — we add a DEDICATED adapter
    beside it, and both trust models coexist.

    This adapter is DORMANT by default and cannot be switched on by ordinary
    configuration. It requires, together:
      1. ZK_SERVER_ORCHESTRATION_OWNER_APPROVAL — the project owner's
         explicit approval reference (an architectural decision, ADR-001),
      2. CAE_ENTERPRISE_BASE_URL — the documented enterprise endpoint,
      3. an implementation of server_fetch against CAE's published API.
    It never touches a user's PRN or password: enterprise orchestration uses
    NAJM's own service credentials from the secret manager.
    """

    provider_id = "cae_enterprise"
    display_name = "CAE Crew Access (Enterprise)"
    recommended = False
    auth_kind = "none"                  # no user credentials, ever
    orchestration = "server_orchestrated"   # → trust_model server_orchestrated

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(
            supports_delta=True,
            supports_server_orchestration=True,
            payload_kinds=("normalized",),
        )

    def availability(self) -> tuple[str, str]:
        approved, ref = owner_approved_server_orchestration()
        if not approved:
            return REQUIRES_OWNER_APPROVAL, (
                "Server-orchestrated sync would move NAJM from the "
                "zero-knowledge trust model to server-managed credentials. "
                "Per ADR-001 that is an architectural decision requiring "
                "explicit project-owner approval; this adapter stays dormant "
                "until it is granted.")
        if not os.environ.get("CAE_ENTERPRISE_BASE_URL", "").strip():
            return PENDING_OFFICIAL, (
                f"Owner-approved ({ref}) but the CAE enterprise endpoint is "
                "not configured, and no endpoint is hardcoded in NAJM.")
        return AVAILABLE, f"enterprise integration active (owner approval: {ref})"

    def parse_payload(self, kind, payload, period, year):
        avail, note = self.availability()
        if avail != AVAILABLE:
            raise ProviderNotAvailable(note)
        if kind != "normalized":
            return None, [f"unsupported payload kind '{kind}'"]
        try:
            return NormalizedRoster(**payload), []
        except Exception as exc:  # noqa: BLE001
            return None, [f"normalized payload invalid: {exc}"]

    def server_fetch(self, user_id, period, year):   # pragma: no cover
        avail, note = self.availability()
        if avail != AVAILABLE:
            raise ProviderNotAvailable(note)
        # Deliberately NOT implemented: writing a speculative HTTP call
        # against an API we have not been given would be exactly the
        # "placeholder implementation that implies the integration already
        # exists" the directive forbids. Implement against CAE's published
        # enterprise docs at activation time (docs/ROSTER_SYNC.md §8).
        raise ProviderNotAvailable(
            "enterprise server_fetch is not implemented — implement it "
            "against CAE's documented enterprise API (no endpoint is "
            "hardcoded in NAJM). Everything downstream is live and tested.")


# ── ICS calendar feed — real today ───────────────────────────────────────────

class IcsFeedProvider(RosterProvider):
    """Standards-based (RFC 5545). The user pastes their crew-portal calendar
    subscription URL; the DEVICE stores it (a feed URL can embed a personal
    token → it is treated as a credential), fetches the text, and pushes it
    here as payload_kind="ics"."""

    provider_id = "ics_feed"
    display_name = "Calendar feed (ICS)"
    auth_kind = "feed_url"

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(payload_kinds=("ics", "normalized"))

    def parse_payload(self, kind, payload, period, year):
        if kind == "normalized":
            try:
                return NormalizedRoster(**payload), []
            except Exception as exc:  # noqa: BLE001
                return None, [f"normalized payload invalid: {exc}"]
        if kind != "ics":
            return None, [f"unsupported payload kind '{kind}'"]
        if not isinstance(payload, str):
            return None, ["ics payload must be the raw calendar text"]
        report: ParseReport = parse_ics(payload, period, year, DEFAULT_PROFILE)
        notes = list(report.errors)
        if report.roster and report.events_skipped:
            notes.append(f"{report.events_skipped} non-flight events skipped")
        return report.roster, notes


# ── Manual PDF — the existing flow as a first-class (fallback) source ───────

class ManualPdfProvider(RosterProvider):
    """Wraps the shipped /v1/intelligence/upload flow into the source
    catalog so priority ordering (CAE Sync → Manual Upload) and the status
    screen have one vocabulary. Imports keep flowing through the existing
    endpoint; this entry is catalog/status only."""

    provider_id = "manual_pdf"
    display_name = "Manual PDF upload"
    auth_kind = "none"

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(payload_kinds=())

    def parse_payload(self, kind, payload, period, year):
        return None, ["manual_pdf imports go through /v1/intelligence/upload"]


# ── Excel upload — REAL: a Cloud Function triggers on an uploaded workbook ──

class ExcelUploadProvider(RosterProvider):
    """Roster workbooks (.xlsx) dropped in the user's Storage folder are
    parsed by the shipped Cloud Function trigger (firebase/functions →
    /v1/parser/parse). That path already works, so Excel earns a real
    catalog entry: the Profile screen lists it as an available upload
    source. Imports flow through the existing endpoint; this entry is
    catalog/status only (no duplicated business logic)."""

    provider_id = "excel_upload"
    display_name = "Excel roster (.xlsx)"
    auth_kind = "none"

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(payload_kinds=())

    def parse_payload(self, kind, payload, period, year):
        return None, ["excel_upload is parsed by the Storage-trigger "
                      "Cloud Function (/v1/parser/parse)"]


# ── Email import — declared UNAVAILABLE, because it does not exist ──────────

class EmailImportProvider(RosterProvider):
    """The product brief lists Email Import as a roster source. It is NOT
    implemented — there is no mailbox connector, no parser, no endpoint.

    It is registered here *as unavailable* rather than quietly omitted, so
    the Profile screen can show it honestly ("Not available yet") instead of
    a tile that pretends to work. Building it means one RosterConnector
    subclass + a parser; the interface already supports it.
    """

    provider_id = "email_import"
    display_name = "Email import"
    auth_kind = "none"

    def capabilities(self) -> ProviderCapabilities:
        return ProviderCapabilities(payload_kinds=())

    def availability(self) -> tuple[str, str]:
        return NOT_IMPLEMENTED, (
            "Email roster import is not built yet. Use CAE sync, a calendar "
            "feed, or upload your roster as PDF or Excel.")

    def parse_payload(self, kind, payload, period, year):
        return None, ["email_import is not implemented"]


# ── Registry ─────────────────────────────────────────────────────────────────

_PROVIDERS: dict[str, RosterProvider] = {}


def _register(p: RosterProvider) -> None:
    if p.provider_id in _PROVIDERS:
        raise ValueError(f"duplicate provider {p.provider_id}")
    _PROVIDERS[p.provider_id] = p


_register(CaeCrewAccessProvider())
_register(CaeEnterpriseProvider())
_register(IcsFeedProvider())
_register(ManualPdfProvider())
_register(ExcelUploadProvider())
_register(EmailImportProvider())

# Priority order per the spec: CAE Sync first, manual upload last.
PRIORITY_ORDER = ("cae_crew_access", "cae_enterprise", "ics_feed",
                  "manual_pdf", "excel_upload", "email_import")


def get_provider(provider_id: str) -> Optional[RosterProvider]:
    return _PROVIDERS.get(provider_id)


def provider_catalog(include_dormant: bool = False) -> list[ProviderInfo]:
    """User-facing source list, in spec priority order.

    Adapters awaiting the project owner's architectural approval
    (REQUIRES_OWNER_APPROVAL — i.e. the server-orchestrated lane) are DORMANT
    and hidden from crew: offering a source nobody can switch on would be
    noise, and showing it as merely "unavailable" would understate that the
    blocker is a deliberate trust-model decision, not a missing feature.
    Ops/tests can see them with include_dormant=True.
    """
    ordered = [p for pid in PRIORITY_ORDER if (p := _PROVIDERS.get(pid))]
    ordered += [p for pid, p in _PROVIDERS.items() if pid not in PRIORITY_ORDER]
    infos = [p.info() for p in ordered]
    if include_dormant:
        return infos
    return [i for i in infos if i.availability != REQUIRES_OWNER_APPROVAL]
