"""roster_sync/engine_fanout.py — post-import engine triggering + analytics.

Spec lists nine engines to trigger after every successful sync. Their real
integration points differ, and the statuses say so honestly:

  ok        — computed inline during import (the enriched line doc IS the
              engine's output for this roster)
  queued    — an event/notification was written that the engine's existing
              consumer processes (behavior learning, auto-bid refresh)
  on_demand — the engine is query-time by design (trade search, layover
              recommendations, knowledge RAG); the synced roster is already
              its input the moment the user asks

Every step is isolated: one engine failing never blocks the import or the
other engines (spec: failure handling).
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

from .schema import EngineStatus

logger = logging.getLogger("cip.roster_sync")


# ── Canonical engine registry ────────────────────────────────────────────────
# The one list of engines the platform runs, with how each reacts to a roster
# import. The fan-out below and the Profile "AI Status" card (GET /v1/ai/status)
# BOTH read this — the UI cannot drift from what actually runs.
ENGINE_REGISTRY: tuple[tuple[str, str], ...] = (
    ("salary_engine",               "triggered"),
    ("ftl_engine",                  "triggered"),
    ("rest_calculator",             "triggered"),
    ("ranking_engine",              "triggered"),
    ("behavior_engine",             "queued"),
    ("bid_recommendation_engine",   "queued"),
    ("trade_recommendation_engine", "on_demand"),
    ("layover_recommendation_engine", "on_demand"),
    ("knowledge_engine",            "on_demand"),
)

ON_DEMAND_ENGINES = tuple(
    name for name, mode in ENGINE_REGISTRY if mode == "on_demand")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_fanout(db, user_id: str, line_doc: dict,
               provider_id: str) -> list[EngineStatus]:
    statuses: list[EngineStatus] = []

    def _try(engine: str, fn, ok_status: str = "ok", detail: str = ""):
        try:
            extra = fn() or ""
            statuses.append(EngineStatus(
                engine=engine, status=ok_status,
                detail=detail or extra))
        except Exception as exc:  # noqa: BLE001 — isolation by design
            logger.exception("fanout: %s failed", engine)
            statuses.append(EngineStatus(
                engine=engine, status="failed", detail=str(exc)[:200]))

    s = line_doc.get("summary", {})

    # 1–3: computed inline during import; report evidence from the doc.
    _try("salary_engine", lambda: (
        f"estimated SAR {s.get('estimatedSalaryMin', 0):.0f}–"
        f"{s.get('estimatedSalaryMax', 0):.0f}"))
    _try("ftl_engine", lambda: (
        f"{sum(1 for l in line_doc.get('legs', []) if l.get('legalityFlags'))}"
        " leg(s) flagged" if any(
            l.get("legalityFlags") for l in line_doc.get("legs", []))
        else "all duties legal under effective rules"))
    _try("rest_calculator", lambda: (
        f"rest quality {s.get('restQualityScore', 0)}"))

    # 4: ranking scores are on the doc; the filter engine serves them live.
    _try("ranking_engine", lambda: (
        f"composite {s.get('compositeScore', 0)}"))

    # 5–6: learning-side engines consume behaviorEvents — queue one.
    def _behavior_event():
        db.collection("behaviorEvents").add({
            "userId": user_id,
            "eventType": "roster_synced",
            "source": provider_id,
            "lineId": line_doc["id"],
            "month": line_doc["month"],
            "importedFlights": s.get("totalLegs", 0),
            "createdAt": _now(),
        })
    _try("behavior_engine", _behavior_event, ok_status="queued",
         detail="roster_synced event written")

    def _auto_bid_nudge():
        db.collection("autoBidRefresh").document(user_id).set({
            "userId": user_id, "reason": "roster_synced",
            "lineId": line_doc["id"], "requestedAt": _now(),
        })
    _try("bid_recommendation_engine", _auto_bid_nudge, ok_status="queued",
         detail="refresh requested")

    # 7–9: query-time engines — the synced roster is now their input.
    for engine in ON_DEMAND_ENGINES:
        statuses.append(EngineStatus(
            engine=engine, status="on_demand",
            detail="serves from the synced roster at query time"))

    return statuses


# ── Analytics (spec §Analytics) ───────────────────────────────────────────────

def record_event(db, user_id: str, provider_id: str, event_type: str,
                 *, duration_ms: int | None = None,
                 imported_flights: int | None = None,
                 version: int | None = None, detail: str = "") -> None:
    """syncEvents feed: connection success rate, sync duration, failures,
    version changes, imported flights, duplicate detection — all derivable
    from this one event stream."""
    # Zero-Knowledge directive: analytics never carry credential material.
    # Free-text detail passes the same key=value redaction as logs — defense
    # in depth on top of connectors that never emit secrets to begin with.
    if detail:
        from utils.logging_config import _redact
        detail = _redact(str(detail))
    try:
        db.collection("syncEvents").add({
            "userId": user_id,
            "providerId": provider_id,
            "type": event_type,      # connect_ok/connect_blocked/sync_ok/
                                     # sync_failed/duplicate/version_change/
                                     # disconnect
            "durationMs": duration_ms,
            "importedFlights": imported_flights,
            "version": version,
            "detail": detail[:300],
            "at": _now(),
        })
    except Exception:  # analytics must never break the flow
        logger.exception("syncEvents write failed (non-fatal)")
