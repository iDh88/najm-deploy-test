"""ai/status_router.py — GET /v1/ai/status for the Profile "AI Status" card.

DESIGN RULE (owner: "No placeholders. No mock implementations."): every field
below is read from something that actually exists, or it is not returned at
all. Nothing here is decorative.

  status            — the AI provider is only "online" if an API key is
                      actually configured. Without one the assistant genuinely
                      cannot answer, so we report "unconfigured" rather than a
                      green light that lies.
  model             — ai.nlp_router.CLAUDE_MODEL, the SAME constant the
                      assistant calls with. A model upgrade updates the card
                      automatically; the UI cannot advertise a stale version.
  engines           — roster_sync.engine_fanout.ENGINE_REGISTRY, the SAME
                      registry the post-import fan-out iterates. The card
                      cannot list an engine the platform does not run.
  knowledge_base    — live counts/timestamps from the real `knowledgeDocuments`
                      and `documentVersions` collections. An empty knowledge
                      base reports zero documents and a null timestamp — it
                      does not invent "Updated today".
  service_version   — utils.version.SERVICE_VERSION, the same constant the
                      FastAPI app is built with.

Deliberately NOT here: daily AI usage. That already exists in the subscription
service (`GET /v1/subscription/usage/{feature_key}`) and the app already has
`usageStatusProvider`. Duplicating it would be a second source of truth for a
billing-adjacent number.
"""
from __future__ import annotations

import logging
import os
from typing import Any, Optional

from fastapi import APIRouter, Depends

from ai.nlp_router import CLAUDE_MODEL
from roster_sync.engine_fanout import ENGINE_REGISTRY
from utils.auth import verify_service_or_user
from utils.version import SERVICE_VERSION

logger = logging.getLogger("cip.ai.status")

router = APIRouter()

# The env var the Anthropic client reads (ai.nlp_router.get_claude_client).
_API_KEY_ENV = "ANTHROPIC_API_KEY"


def _provider_configured() -> bool:
    return bool(os.environ.get(_API_KEY_ENV, "").strip())


_KB_UNAVAILABLE = {"available": False, "documents": 0, "documents_disabled": 0,
                   "latest_version": None, "last_updated": None}


def _knowledge_base(db) -> dict[str, Any]:
    """Real knowledge-base state. Any failure degrades to an honest
    'unavailable' — never a fabricated timestamp. `db` may be None when
    Firestore is not reachable (e.g. no credentials in local dev)."""
    if db is None:
        return dict(_KB_UNAVAILABLE)
    try:
        docs = [d.to_dict() or {} for d in
                db.collection("knowledgeDocuments").stream()]
        active = [d for d in docs if not d.get("isDisabled")]

        latest: Optional[str] = None
        highest_version = 0
        for v in db.collection("documentVersions").stream():
            data = v.to_dict() or {}
            created = data.get("createdAt")
            if isinstance(created, str) and (latest is None or created > latest):
                latest = created
            try:
                highest_version = max(highest_version,
                                      int(data.get("versionNumber") or 0))
            except (TypeError, ValueError):
                continue

        return {
            "available": True,
            "documents": len(active),
            "documents_disabled": len(docs) - len(active),
            "latest_version": highest_version or None,
            "last_updated": latest,          # None when nothing is loaded yet
        }
    except Exception:
        logger.exception("knowledge-base status unavailable")
        return dict(_KB_UNAVAILABLE)


@router.get("/status")
async def ai_status(claims: dict = Depends(verify_service_or_user)) -> dict:
    from utils.firebase import get_firestore   # lazy: testability

    # Firestore may be unreachable in local development (no default
    # credentials). Degrade the knowledge-base card to an honest
    # 'unavailable' instead of 500-ing the whole status endpoint — the
    # provider/model/engine fields below do not depend on Firestore.
    try:
        db = get_firestore()
    except Exception:
        logger.warning("Firestore unavailable; AI status knowledge_base "
                       "degrades to unavailable", exc_info=True)
        db = None

    configured = _provider_configured()
    return {
        "status": "online" if configured else "unconfigured",
        "status_detail": (
            "Assistant, filter generation and explanations are live."
            if configured else
            "The AI provider is not configured on this deployment, so the "
            "assistant is unavailable. Manual filters, legality, salary and "
            "rest calculations are unaffected."),
        "provider": "anthropic",
        "model": CLAUDE_MODEL,
        "service_version": SERVICE_VERSION,
        "engines": [{"engine": name, "trigger": mode}
                    for name, mode in ENGINE_REGISTRY],
        "knowledge_base": _knowledge_base(db),
    }
