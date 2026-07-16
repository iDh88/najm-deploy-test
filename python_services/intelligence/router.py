"""
Phase 2 — PDF Intelligence Engine router.
Mounts at /v1/intelligence/* in main.py.
"""
from fastapi import APIRouter, UploadFile, File, BackgroundTasks, Query, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
import re, uuid, tempfile, logging
from pathlib import Path

from utils.auth import verify_service_or_user, resolve_user_id

from .pipeline.extraction_pipeline import ExtractionPipeline
from .engines.fatigue_engine import FatigueEngine
from .engines.classification_engine import ClassificationEngine
from .engines.analytics_engine import AnalyticsEngine
from .engines.insight_engine import InsightEngine
from .engines.pattern_engine import PatternEngine
from .engines.comparison_engine import ComparisonEngine

logger = logging.getLogger("cip.intelligence")
router = APIRouter()

# ── Singleton engines ─────────────────────────────────────────────────────────
_pipeline       = ExtractionPipeline()
_fatigue        = FatigueEngine()
_classification = ClassificationEngine()
_analytics      = AnalyticsEngine(_fatigue, _classification)
_insights       = InsightEngine()
_patterns       = PatternEngine()
_comparison     = ComparisonEngine()

# ── Security limits (T2 remediation) ──────────────────────────────────────────
MAX_PDF_BYTES = 20 * 1024 * 1024          # 20 MB — largest roster PDFs seen are <2 MB
_READ_CHUNK   = 1 * 1024 * 1024
_PERIOD_RE    = re.compile(r"^[A-Za-z0-9 _\-]{1,20}$")
_YEAR_MIN, _YEAR_MAX = 2020, 2035


def _assert_owner(claims: dict, owner_user_id: Optional[str]) -> None:
    """Read-side ownership pin: service callers pass; end users may only read
    documents whose userId matches their verified token uid."""
    if claims.get("service"):
        return
    uid = claims.get("uid")
    if not uid or owner_user_id != uid:
        # 404 (not 403) so authenticated users cannot probe for foreign IDs.
        raise HTTPException(status_code=404, detail="Not found")


async def _process_pdf(upload_id: str, pdf_path: str, user_id: str,
                        period: str, year: int):
    """Background task: extract → analyse → write to Firestore."""
    try:
        from utils.firebase import get_firestore
        db = get_firestore()
        db.collection("uploads").document(upload_id).update({"status": "processing"})

        result = _pipeline.process(pdf_path, year=year)
        if not result.success or not result.pairings:
            db.collection("uploads").document(upload_id).update(
                {"status": "failed", "error": "; ".join(result.errors)})
            return

        pairings         = result.pairings
        fatigue_profile  = _fatigue.score_line(pairings)
        classification   = _classification.classify(pairings, fatigue_profile)
        line_id          = str(uuid.uuid4())
        monthly_analytics = _analytics.generate(line_id, period, pairings)
        insight_list     = _insights.generate(pairings, monthly_analytics)

        # Write to Firestore (simplified — full writer in shared firestore_service)
        db.collection("uploads").document(upload_id).update(
            {"status": "complete", "lineId": line_id})

        logger.info(f"✅ Intelligence processing done: lineId={line_id}")
    except Exception as e:
        logger.exception(f"Intelligence processing failed: {e}")
        try:
            from utils.firebase import get_firestore
            get_firestore().collection("uploads").document(upload_id).update(
                {"status": "failed", "error": str(e)})
        except Exception:
            pass
    finally:
        Path(pdf_path).unlink(missing_ok=True)


@router.post("/upload")
async def upload_pdf(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    user_id: str = Query(...),
    period:  str = Query(...),
    year:    int = Query(2026),
    claims: dict = Depends(verify_service_or_user),
):
    # Identity pin (T2): an authenticated user can only upload as themself;
    # the query-param user_id is honoured only for trusted service calls.
    user_id = resolve_user_id(claims, user_id)

    if not (file.filename or "").lower().endswith(".pdf"):
        return JSONResponse(status_code=400, content={"error": "PDF only"})
    if not _PERIOD_RE.match(period):
        return JSONResponse(status_code=400, content={"error": "Invalid period"})
    if not (_YEAR_MIN <= year <= _YEAR_MAX):
        return JSONResponse(status_code=400, content={"error": f"year must be {_YEAR_MIN}–{_YEAR_MAX}"})

    upload_id = str(uuid.uuid4())
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".pdf")
    total = 0
    try:
        while True:  # bounded, chunked read — never buffer an unbounded body
            chunk = await file.read(_READ_CHUNK)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_PDF_BYTES:
                raise HTTPException(status_code=413,
                                    detail=f"PDF exceeds {MAX_PDF_BYTES // (1024*1024)} MB limit")
            tmp.write(chunk)
        tmp.flush()
    except HTTPException:
        tmp.close(); Path(tmp.name).unlink(missing_ok=True)
        raise
    finally:
        tmp.close()

    try:
        from utils.firebase import get_firestore
        get_firestore().collection("uploads").document(upload_id).set({
            "userId": user_id, "fileName": file.filename,
            "period": period, "year": year, "status": "queued",
        })
    except Exception:
        # Fail loud, not silent: without this doc the client can never poll
        # status and the background task's update() calls would all fail.
        logger.exception("uploads/%s status doc write failed — rejecting upload", upload_id)
        Path(tmp.name).unlink(missing_ok=True)
        return JSONResponse(status_code=503,
                            content={"error": "Upload tracking unavailable, try again"})

    background_tasks.add_task(
        _process_pdf, upload_id, tmp.name, user_id, period, year)
    return {"uploadId": upload_id, "status": "queued"}


@router.get("/upload/{upload_id}/status")
async def get_status(upload_id: str, claims: dict = Depends(verify_service_or_user)):
    try:
        from utils.firebase import get_firestore
        doc = get_firestore().collection("uploads").document(upload_id).get()
        if not doc.exists:
            return {"uploadId": upload_id, "status": "not_found"}
        d = doc.to_dict()
        _assert_owner(claims, d.get("userId"))
        return {"uploadId": upload_id, "status": d.get("status"),
                "lineId": d.get("lineId"), "error": d.get("error")}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("status lookup failed for %s", upload_id)
        return {"uploadId": upload_id, "status": "error", "error": str(e)}


def _load_owned_line(line_id: str, claims: dict) -> dict:
    """Fetch a monthly_lines doc and enforce ownership. Raises HTTPException."""
    from utils.firebase import get_firestore
    doc = get_firestore().collection("monthly_lines").document(line_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Line not found")
    d = doc.to_dict()
    _assert_owner(claims, d.get("userId"))
    return d


@router.get("/lines/{line_id}")
async def get_line(line_id: str, claims: dict = Depends(verify_service_or_user)):
    try:
        return _load_owned_line(line_id, claims)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("line lookup failed for %s", line_id)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/lines/{line_id}/pairings")
async def get_pairings(line_id: str, claims: dict = Depends(verify_service_or_user)):
    try:
        _load_owned_line(line_id, claims)  # ownership gate
        from utils.firebase import get_firestore
        docs = (get_firestore().collection("pairings")
                .where("lineId", "==", line_id).stream())
        return [d.to_dict() for d in docs]
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("pairings lookup failed for %s", line_id)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/lines/{line_id}/fatigue")
async def get_fatigue_timeline(line_id: str, claims: dict = Depends(verify_service_or_user)):
    try:
        _load_owned_line(line_id, claims)  # ownership gate
        from utils.firebase import get_firestore
        docs = (get_firestore().collection("monthly_lines")
                .document(line_id).collection("timeline")
                .order_by("day").stream())
        return [d.to_dict() for d in docs]
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("fatigue timeline lookup failed for %s", line_id)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/search")
async def search_lines(
    user_id:          str           = Query(...),
    fatigue_level:    Optional[str] = Query(None),
    has_deadhead:     Optional[bool]= Query(None),
    is_international: Optional[bool]= Query(None),
    min_credit:       Optional[float]=Query(None),
    period:           Optional[str] = Query(None),
    limit:            int           = Query(20, ge=1, le=100),
    claims: dict = Depends(verify_service_or_user),
):
    user_id = resolve_user_id(claims, user_id)  # identity pin (T2)
    try:
        from utils.firebase import get_firestore
        q = get_firestore().collection("monthly_lines").where("userId", "==", user_id)
        if period:        q = q.where("period", "==", period)
        if fatigue_level: q = q.where("searchIndex.fatigueLevel", "==", fatigue_level)
        docs = q.limit(limit).stream()
        results = [d.to_dict() for d in docs]
        if min_credit:
            results = [r for r in results
                       if r.get("summary", {}).get("estimatedCredit", 0) >= min_credit]
        return results
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


class CompareRequest(BaseModel):
    line_a_id: str
    line_b_id: str


@router.post("/compare")
async def compare_lines(req: CompareRequest, claims: dict = Depends(verify_service_or_user)):
    try:
        a_data = _load_owned_line(req.line_a_id, claims)
        b_data = _load_owned_line(req.line_b_id, claims)
        a_fat = a_data.get("fatigueProfile", {}).get("averageFatigue", 0)
        b_fat = b_data.get("fatigueProfile", {}).get("averageFatigue", 0)
        a_blk = a_data.get("summary", {}).get("blockHours", 0)
        b_blk = b_data.get("summary", {}).get("blockHours", 0)
        winner = "A" if (1 - a_fat + a_blk / 100) > (1 - b_fat + b_blk / 100) else "B"
        return {
            "lineAId": req.line_a_id, "lineBId": req.line_b_id,
            "blockHoursDelta": round(a_blk - b_blk, 1),
            "fatigueDelta":    round(a_fat - b_fat, 3),
            "winner":          winner,
            "lineARadar": {"fatigue": round(1 - a_fat, 2), "income": round(min(a_blk/100, 1), 2), "recovery": 0.6, "deadhead": 0.8, "legality": 1.0, "efficiency": 0.75},
            "lineBRadar": {"fatigue": round(1 - b_fat, 2), "income": round(min(b_blk/100, 1), 2), "recovery": 0.5, "deadhead": 0.7, "legality": 1.0, "efficiency": 0.70},
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("compare failed for %s vs %s", req.line_a_id, req.line_b_id)
        return JSONResponse(status_code=500, content={"error": str(e)})
