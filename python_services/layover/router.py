"""
Phase 3 — Layover Intelligence router.
Content moderation, city data, recommendation management.
Mounts at /v1/layover/* in main.py.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging
import re

logger = logging.getLogger("cip.layover")
router = APIRouter()

# ── Blocked content list (mirrors Flutter ContentFilter) ──────────────────────
# Keep in sync with flutter_app/lib/core/utils/content_filter.dart.
BLOCKED_KEYWORDS = [
    "bar", "bars", "club", "clubs", "nightclub", "nightclubs",
    "pub", "pubs", "alcohol", "alcoholic", "beer", "wine", "liquor",
    "cocktail", "cocktails", "whiskey", "vodka", "spirits", "brewery",
    "winery", "casino", "gambling", "hookah bar", "shisha bar",
]

# F25: WORD-BOUNDARY matching. The previous substring check (`kw in lower`)
# falsely blocked legitimate content — "Barcelona" contains "bar", "Clube de
# Regatas" contains "club". Multi-word phrases match across whitespace.
_BLOCKED_PATTERNS = [
    (kw, re.compile(r"\b" + re.escape(kw) + r"\b", re.IGNORECASE))
    for kw in BLOCKED_KEYWORDS
]


def blocked_terms(text: str) -> list[str]:
    """All blocked keywords present in *text* (word-boundary match)."""
    return [kw for kw, pat in _BLOCKED_PATTERNS if pat.search(text)]


def is_content_allowed(text: str) -> bool:
    return not blocked_terms(text)


class ContentCheckRequest(BaseModel):
    name: str
    description: str
    category: str
    notes: Optional[str] = None


class ContentCheckResponse(BaseModel):
    allowed: bool
    blocked_reason: Optional[str] = None


@router.post("/content-check", response_model=ContentCheckResponse)
async def check_content(req: ContentCheckRequest):
    """Server-side content filter — mirrors Flutter ContentFilter."""
    combined = "\n".join([req.name, req.description, req.category, req.notes or ""])
    hits = blocked_terms(combined)
    if hits:
        return ContentCheckResponse(allowed=False, blocked_reason=", ".join(hits))
    return ContentCheckResponse(allowed=True)


@router.get("/cities")
async def get_cities():
    """Return all active layover cities."""
    try:
        from utils.firebase import get_firestore
        docs = (get_firestore().collection("layoverCities")
                .where("isActive", "==", True)
                .order_by("name").stream())
        return [d.to_dict() | {"id": d.id} for d in docs]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/cities/{city_id}/recommendations")
async def get_recommendations(
    city_id: str,
    category: Optional[str] = None,
    halal_only: bool = False,
):
    """Get recommendations for a city, optionally filtered."""
    try:
        from utils.firebase import get_firestore
        q = (get_firestore().collection("recommendations")
             .where("cityId", "==", city_id)
             .where("isDeleted", "==", False)
             .where("isApproved", "==", True))
        if category:    q = q.where("category", "==", category)
        if halal_only:  q = q.where("isHalal", "==", True)
        return [d.to_dict() | {"id": d.id} for d in q.stream()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/recommendations/{rec_id}")
async def admin_delete_recommendation(rec_id: str, admin_uid: str):
    """Admin soft-delete a recommendation."""
    try:
        from utils.firebase import get_firestore
        import firebase_admin.auth as fa
        # Verify admin token
        decoded = fa.verify_id_token(admin_uid)
        if not decoded.get("admin") and not decoded.get("superAdmin"):
            raise HTTPException(status_code=403, detail="Admin only")
        get_firestore().collection("recommendations").document(rec_id).update(
            {"isDeleted": True, "deletedBy": decoded["uid"]})
        return {"deleted": True, "recId": rec_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
