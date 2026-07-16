"""roster_sync/router.py — /v1/roster-sync.

Endpoints (all `verify_service_or_user`; identity token-pinned):

  GET    /providers                    — source catalog + availability
  GET    /status                       — the Sync Status screen, one call
  POST   /connections                  — register a source (no credentials!)
  DELETE /connections/{provider_id}    — disconnect (server-side wipe;
                                         client wipes Keychain/Keystore)
  POST   /connections/{provider_id}/sync-now
  POST   /import                       — the client-orchestrated push:
                                         payload in, credentials NEVER

Failure-handling contract (spec): a failed or duplicate import changes
NOTHING about the previously imported roster; errors are recorded on the
connection and returned meaningfully.
"""
from __future__ import annotations

import logging
import time
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException

from utils.auth import resolve_user_id, verify_service_or_user

from . import import_service, version_service
from .engine_fanout import record_event, run_fanout
from .providers import ProviderNotAvailable, get_provider, provider_catalog
from .schema import (
    ConnectRequest,
    ConnectionStatus,
    CredentialLeakError,
    ImportRequest,
    ImportResponse,
    RosterConnection,
    StatusResponse,
    SyncNowResponse,
    VersionEntry,
    assert_no_credentials,
    assert_no_credentials_out,
)

logger = logging.getLogger("cip.roster_sync")
router = APIRouter()


def _db():
    from utils.firebase import get_firestore
    return get_firestore()


def _conn_doc_id(user_id: str, provider_id: str) -> str:
    return f"{user_id}_{provider_id}"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _load_connection(db, user_id: str, provider_id: str) -> Optional[dict]:
    doc = db.collection("rosterSources").document(
        _conn_doc_id(user_id, provider_id)).get()
    return doc.to_dict() if getattr(doc, "exists", False) else None


def _save_connection(db, conn: RosterConnection) -> None:
    data = conn.model_dump()
    for k, v in list(data.items()):
        if isinstance(v, datetime):
            data[k] = v.isoformat()
    db.collection("rosterSources").document(
        _conn_doc_id(conn.user_id, conn.provider_id)).set(data)


# ── Catalog ───────────────────────────────────────────────────────────────────

@router.get("/providers")
async def providers(claims: dict = Depends(verify_service_or_user)) -> dict:
    return {"providers": [p.model_dump() for p in provider_catalog()]}


# ── Connect / disconnect ─────────────────────────────────────────────────────

@router.post("/connections")
async def connect(
    request: ConnectRequest,
    claims: dict = Depends(verify_service_or_user),
) -> dict:
    assert_no_credentials(request.model_dump())
    user_id = resolve_user_id(claims, body_user_id="")
    provider = get_provider(request.provider_id)
    if provider is None:
        raise HTTPException(status_code=404,
                            detail=f"unknown provider '{request.provider_id}'")

    db = _db()
    availability, note = provider.availability()
    if availability != "available":
        # Honest state — nothing scraped, nothing simulated. The device may
        # still store the user's credentials locally so activation is
        # seamless when the official integration lands.
        conn = RosterConnection(
            user_id=user_id, provider_id=provider.provider_id,
            status=ConnectionStatus.AWAITING_OFFICIAL_INTEGRATION,
            orchestration=provider.orchestration,
            connected_at=_now(), last_error=None)
        _save_connection(db, conn)
        record_event(db, user_id, provider.provider_id, "connect_blocked",
                     detail=availability)
        return {"status": conn.status, "note": note}

    conn = RosterConnection(
        user_id=user_id, provider_id=provider.provider_id,
        status=ConnectionStatus.CONNECTED,
        orchestration=provider.orchestration,
        connected_at=_now())
    _save_connection(db, conn)
    record_event(db, user_id, provider.provider_id, "connect_ok")
    return {"status": conn.status,
            "note": "connected — first sync will run from the device"}


@router.delete("/connections/{provider_id}")
async def disconnect(
    provider_id: str,
    claims: dict = Depends(verify_service_or_user),
) -> dict:
    user_id = resolve_user_id(claims, body_user_id="")
    db = _db()
    existing = _load_connection(db, user_id, provider_id)
    if existing is None:
        raise HTTPException(status_code=404, detail="not connected")
    db.collection("rosterSources").document(
        _conn_doc_id(user_id, provider_id)).set(
        {**existing, "status": ConnectionStatus.DISCONNECTED,
         "disconnectedAt": _now().isoformat()})
    record_event(db, user_id, provider_id, "disconnect")
    # Imported rosters are the USER'S data — they remain (spec: never erase
    # the previous roster). Credentials live only on the device; the client
    # must now securely erase Keychain/Keystore entries.
    return {"status": ConnectionStatus.DISCONNECTED,
            "client_action": "erase_local_credentials"}


# ── Sync-now ──────────────────────────────────────────────────────────────────

@router.post("/connections/{provider_id}/sync-now",
             response_model=SyncNowResponse)
async def sync_now(
    provider_id: str,
    claims: dict = Depends(verify_service_or_user),
) -> SyncNowResponse:
    user_id = resolve_user_id(claims, body_user_id="")
    provider = get_provider(provider_id)
    if provider is None:
        raise HTTPException(status_code=404, detail="unknown provider")
    availability, note = provider.availability()
    if availability != "available":
        return SyncNowResponse(action="unavailable", detail=note)
    if provider.orchestration == "client_orchestrated":
        # Credentials live on the device — the device performs the fetch.
        return SyncNowResponse(
            action="client_sync_required",
            detail="device sync scheduler triggered; the app fetches with "
                   "locally-stored credentials and pushes to /import")
    # server_orchestrated (future enterprise mode)
    try:
        roster = provider.server_fetch(user_id, period="", year=0)
    except ProviderNotAvailable as exc:
        return SyncNowResponse(action="unavailable", detail=exc.note)
    return SyncNowResponse(action="server_synced",
                           detail=f"{len(roster.legs)} legs fetched")


# ── The client-orchestrated import ───────────────────────────────────────────

@router.post("/import", response_model=ImportResponse)
async def import_roster(
    body: dict = Body(...),
    claims: dict = Depends(verify_service_or_user),
) -> ImportResponse:
    started = time.monotonic()
    # Defence in depth FIRST, on the raw body — before model parsing.
    try:
        assert_no_credentials(body)
    except CredentialLeakError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    try:
        request = ImportRequest(**body)
    except Exception as exc:  # noqa: BLE001 — shape error → 422
        raise HTTPException(status_code=422, detail=f"invalid import: {exc}")

    user_id = resolve_user_id(claims, body_user_id="")
    provider = get_provider(request.provider_id)
    if provider is None:
        raise HTTPException(status_code=404, detail="unknown provider")

    # Zero-Knowledge Credential Model (owner directive): device clients
    # normalize ON DEVICE and upload the normalized roster only — the raw
    # calendar (which can contain personal, non-flight events) never leaves
    # the phone. Raw "ics" payloads remain accepted from service tooling
    # (admin re-parse, migrations) where no user device is involved.
    if request.payload_kind == "ics" and not claims.get("service"):
        raise HTTPException(
            status_code=422,
            detail="device clients upload normalized rosters only "
                   "(zero-knowledge architecture) — update the app; raw "
                   "calendar text is normalized on the device")

    db = _db()

    # Parse payload → NormalizedRoster
    try:
        roster, notes = provider.parse_payload(
            request.payload_kind, request.payload,
            request.period, request.year)
    except ProviderNotAvailable as exc:
        record_event(db, user_id, provider.provider_id, "sync_failed",
                     detail=exc.note)
        raise HTTPException(status_code=409, detail=exc.note)

    if roster is None or not roster.legs:
        detail = "; ".join(notes) or "no legs extracted"
        _mark_error(db, user_id, provider.provider_id, detail)
        record_event(db, user_id, provider.provider_id, "sync_failed",
                     detail=detail)
        # Spec: keep the previous roster untouched; meaningful error out.
        raise HTTPException(status_code=422, detail=detail)

    # Dedup + versioning
    checksum = version_service.roster_checksum(roster)
    latest = version_service.latest_version(
        db, user_id, provider.provider_id, request.period)
    if latest and latest.get("checksum") == checksum:
        record_event(db, user_id, provider.provider_id, "duplicate",
                     version=latest.get("version"))
        _touch_sync(db, user_id, provider.provider_id, success=True,
                    imported=0)
        return ImportResponse(result="duplicate",
                              version=latest.get("version"),
                              checksum=checksum,
                              imported_flights=0)

    prev_roster = version_service.load_previous_roster(
        db, user_id, provider.provider_id, request.period)
    diff = version_service.diff_rosters(prev_roster, roster)
    version = version_service.next_version_number(
        db, user_id, provider.provider_id, request.period)

    # Import (enriched line doc) — previous stays until the new write lands.
    line_doc = import_service.build_line_doc(
        user_id, provider.provider_id, version, roster)
    import_service.deactivate_previous(
        db, user_id, provider.provider_id, request.period)
    line_id = import_service.write_line(db, line_doc)

    version_service.record_version(
        db, user_id, provider.provider_id, request.period,
        VersionEntry(version=version, checksum=checksum,
                     imported_flights=len(roster.legs), at=_now(), **diff),
        normalized_snapshot=roster.model_dump(mode="json")
        if hasattr(roster, "model_dump") else roster.dict())

    engines = run_fanout(db, user_id, line_doc, provider.provider_id)

    duration = request.sync_duration_ms or int(
        (time.monotonic() - started) * 1000)
    record_event(db, user_id, provider.provider_id, "sync_ok",
                 duration_ms=duration,
                 imported_flights=len(roster.legs), version=version)
    if version > 1:
        record_event(db, user_id, provider.provider_id, "version_change",
                     version=version,
                     detail=f"+{diff['added']}/-{diff['removed']}"
                            f"/~{diff['changed']}")
    _touch_sync(db, user_id, provider.provider_id, success=True,
                imported=len(roster.legs))

    return ImportResponse(
        result="imported", line_id=line_id, version=version,
        imported_flights=len(roster.legs), diff=diff,
        engines=engines, checksum=checksum)


def _touch_sync(db, user_id: str, provider_id: str, *,
                success: bool, imported: int, error: str = "") -> None:
    existing = _load_connection(db, user_id, provider_id) or {}
    now = _now().isoformat()
    existing.update({
        "user_id": user_id, "provider_id": provider_id,
        "status": existing.get("status") or ConnectionStatus.CONNECTED,
        "last_sync_at": now,
        "next_sync": "automatic",
    })
    if success:
        existing["last_success_at"] = now
        existing["imported_flights_last"] = imported
        existing["last_error"] = None
        existing["status"] = ConnectionStatus.CONNECTED
    else:
        existing["last_error"] = error[:300]
        existing["status"] = ConnectionStatus.ERROR
    db.collection("rosterSources").document(
        _conn_doc_id(user_id, provider_id)).set(existing)


def _mark_error(db, user_id: str, provider_id: str, error: str) -> None:
    _touch_sync(db, user_id, provider_id, success=False, imported=0,
                error=error)


# ── Status (the Sync Status screen in one call) ──────────────────────────────

@router.get("/status", response_model=StatusResponse)
async def status(claims: dict = Depends(verify_service_or_user)
                 ) -> StatusResponse:
    user_id = resolve_user_id(claims, body_user_id="")
    db = _db()
    conns: list[RosterConnection] = []
    versions_latest: dict = {}
    for doc in (db.collection("rosterSources")
                .where("user_id", "==", user_id).stream()):
        data = doc.to_dict() or {}
        try:
            conns.append(RosterConnection(**{
                k: v for k, v in data.items()
                if k in RosterConnection.model_fields}))
        except Exception:
            logger.exception("bad rosterSources doc %s", doc.id)

    preferred = "manual_pdf"
    for pid in ("cae_crew_access", "cae_enterprise", "ics_feed"):
        if any(c.provider_id == pid
               and c.status == ConnectionStatus.CONNECTED for c in conns):
            preferred = pid
            break

    # Which trust model is actually in force for THIS user right now.
    catalog = {p.provider_id: p for p in provider_catalog(include_dormant=True)}
    active = catalog.get(preferred)
    trust_model = active.trust_model if active else "zero_knowledge"

    response = StatusResponse(
        connections=conns,
        providers=provider_catalog(),
        preferred_source=preferred,
        versions_latest=versions_latest,
        trust_model=trust_model,
    )
    # Outbound wall: the directive forbids the backend from EXPOSING
    # credential-shaped fields, not just from accepting them.
    assert_no_credentials_out(response.model_dump(mode="json"), "GET /status")
    return response
