"""
Knowledge Engine — FastAPI Router
Mounts at /v1/knowledge/* in main.py.

Admin endpoints require manage_knowledge_base privilege (checked via
Firestore custom claims, same pattern as the rest of the project).
User-facing endpoints (ask) are open to any approved crew member.
"""
from __future__ import annotations
import logging
import tempfile
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, Form, HTTPException, \
    BackgroundTasks, Query, Header
from pydantic import BaseModel
from typing import Optional

from .models import DocumentCategory, DocumentStatus, FileType
from .indexing_service import IndexingService
from .storage_service import KnowledgeStorageService
from .ai_assistant import OperationalAIAssistant
from .version_diff import VersionDiffEngine
from .extractors import extract_document

logger = logging.getLogger("cip.knowledge_engine")
router = APIRouter()

_indexing  = IndexingService()
_storage   = KnowledgeStorageService()
_assistant = OperationalAIAssistant()
_differ    = VersionDiffEngine()

SUPPORTED_EXTENSIONS = {".pdf": FileType.PDF, ".docx": FileType.DOCX,
                        ".xlsx": FileType.XLSX, ".csv": FileType.CSV,
                        ".zip": FileType.ZIP}


def _require_admin(authorization: Optional[str]) -> dict:
    """
    Verifies the Firebase ID token and checks for admin / superAdmin /
    manage_knowledge_base privilege. Raises 403 if unauthorized.

    Delegates to the shared revocation-checked helper (P1-1 closure):
    check_revoked=True + approved account, so a suspended admin whose
    refresh tokens were revoked loses access immediately.
    """
    from utils.auth import require_admin_claims
    return require_admin_claims(authorization, "manage_knowledge_base")


class AskRequest(BaseModel):
    query: str
    category: Optional[str] = None


class AskResponse(BaseModel):
    answer: str
    confidence: str
    citations: list[dict]


# ── Admin: Upload / Replace ──────────────────────────────────────────────────

@router.post("/documents", status_code=201)
async def upload_new_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    name: str = Form(...),
    category: str = Form(...),
    description: str = Form(""),
    effective_date: str = Form(...),
    expiration_date: Optional[str] = Form(None),
    authorization: Optional[str] = Header(None),
):
    """Upload a brand-new document (first version)."""
    decoded = _require_admin(authorization)
    uploaded_by = decoded["uid"]

    ext = Path(file.filename).suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(status_code=400,
                            detail=f"Unsupported file type: {ext}")
    file_type = SUPPORTED_EXTENSIONS[ext]

    try:
        category_enum = DocumentCategory(category)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid category: {category}")

    db = _get_db()
    document_id = str(uuid.uuid4())
    version_id  = str(uuid.uuid4())

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
    content = await file.read()
    tmp.write(content)
    tmp.flush()
    tmp.close()

    storage_path = _storage.build_storage_path(document_id, version_id, ext)
    file_size = await _storage.upload(tmp.name, storage_path, file.content_type or "")

    now = datetime.utcnow().isoformat()

    db.collection("knowledgeDocuments").document(document_id).set({
        "name": name,
        "category": category_enum.value,
        "description": description,
        "activeVersionId": None,
        "isDisabled": False,
        "createdAt": now,
    })

    db.collection("documentVersions").document(version_id).set({
        "documentId": document_id,
        "versionNumber": 1,
        "fileType": file_type.value,
        "storagePath": storage_path,
        "fileSizeBytes": file_size,
        "effectiveDate": effective_date,
        "expirationDate": expiration_date,
        "status": DocumentStatus.PROCESSING.value,
        "uploadedBy": uploaded_by,
        "uploadedAt": now,
        "previousVersionId": None,
    })

    background_tasks.add_task(
        _index_and_activate, document_id, version_id, tmp.name, file_type)

    return {"documentId": document_id, "versionId": version_id,
            "status": "processing"}


@router.post("/documents/{document_id}/versions", status_code=201)
async def upload_new_version(
    document_id: str,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    effective_date: str = Form(...),
    expiration_date: Optional[str] = Form(None),
    authorization: Optional[str] = Header(None),
):
    """Replace an existing document with a new version."""
    decoded = _require_admin(authorization)
    uploaded_by = decoded["uid"]

    db = _get_db()
    doc_snap = db.collection("knowledgeDocuments").document(document_id).get()
    if not doc_snap.exists:
        raise HTTPException(status_code=404, detail="Document not found")
    doc_data = doc_snap.to_dict()
    old_version_id = doc_data.get("activeVersionId")

    ext = Path(file.filename).suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {ext}")
    file_type = SUPPORTED_EXTENSIONS[ext]

    existing_versions = list(
        db.collection("documentVersions")
        .where("documentId", "==", document_id)
        .stream())
    next_version_number = max(
        (v.to_dict().get("versionNumber", 0) for v in existing_versions),
        default=0) + 1

    version_id = str(uuid.uuid4())

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
    content = await file.read()
    tmp.write(content)
    tmp.flush()
    tmp.close()

    storage_path = _storage.build_storage_path(document_id, version_id, ext)
    file_size = await _storage.upload(tmp.name, storage_path, file.content_type or "")
    now = datetime.utcnow().isoformat()

    db.collection("documentVersions").document(version_id).set({
        "documentId": document_id,
        "versionNumber": next_version_number,
        "fileType": file_type.value,
        "storagePath": storage_path,
        "fileSizeBytes": file_size,
        "effectiveDate": effective_date,
        "expirationDate": expiration_date,
        "status": DocumentStatus.PROCESSING.value,
        "uploadedBy": uploaded_by,
        "uploadedAt": now,
        "previousVersionId": old_version_id,
    })

    background_tasks.add_task(
        _index_replace_and_diff,
        document_id, old_version_id, version_id, tmp.name, file_type,
        doc_data.get("name", ""), next_version_number)

    return {"documentId": document_id, "versionId": version_id,
            "versionNumber": next_version_number, "status": "processing"}


async def _index_and_activate(document_id, version_id, local_path, file_type):
    result = await _indexing.index_version(document_id, version_id, local_path, file_type)
    if result.success:
        db = _get_db()
        db.collection("knowledgeDocuments").document(document_id).update({
            "activeVersionId": version_id,
        })
    Path(local_path).unlink(missing_ok=True)


async def _index_replace_and_diff(
    document_id, old_version_id, new_version_id, local_path, file_type,
    document_name, new_version_number,
):
    result = await _indexing.reindex_document_replacement(
        document_id, old_version_id, new_version_id, local_path, file_type)

    if result.success and old_version_id:
        try:
            db = _get_db()
            old_snap = db.collection("documentVersions").document(old_version_id).get()
            if old_snap.exists:
                old_data = old_snap.to_dict()
                old_path = old_data.get("storagePath")
                old_local = await _storage.download_to_temp(old_path)
                old_extraction = extract_document(old_local, old_data.get("fileType"))
                new_extraction = extract_document(local_path, file_type.value)

                summary = await _differ.compare(
                    document_name=document_name,
                    old_text=old_extraction.full_text,
                    new_text=new_extraction.full_text,
                    old_version_number=old_data.get("versionNumber", 0),
                    new_version_number=new_version_number,
                    document_id=document_id,
                    old_version_id=old_version_id,
                    new_version_id=new_version_id,
                )

                db.collection("documentChangeSummaries").add({
                    "documentId": document_id,
                    "oldVersionId": old_version_id,
                    "newVersionId": new_version_id,
                    "oldVersionNumber": summary.old_version_number,
                    "newVersionNumber": summary.new_version_number,
                    "generatedAt": summary.generated_at.isoformat(),
                    "overallSummary": summary.overall_summary,
                    "items": [
                        {"category": i.category, "description": i.description,
                         "oldText": i.old_text, "newText": i.new_text,
                         "section": i.section}
                        for i in summary.items
                    ],
                })
                Path(old_local).unlink(missing_ok=True)
        except Exception as e:
            logger.warning(f"Change summary generation failed: {e}")

    Path(local_path).unlink(missing_ok=True)


# ── Admin: Manage ─────────────────────────────────────────────────────────────

@router.get("/documents")
async def list_documents(
    category: Optional[str] = Query(None),
    authorization: Optional[str] = Header(None),
):
    _require_admin(authorization)
    db = _get_db()
    query = db.collection("knowledgeDocuments")
    if category:
        query = query.where("category", "==", category)
    docs = query.stream()
    return [d.to_dict() | {"id": d.id} for d in docs]


@router.get("/documents/{document_id}/versions")
async def list_versions(document_id: str, authorization: Optional[str] = Header(None)):
    _require_admin(authorization)
    db = _get_db()
    versions = (db.collection("documentVersions")
                .where("documentId", "==", document_id)
                .order_by("versionNumber", direction="DESCENDING")
                .stream())
    return [v.to_dict() | {"id": v.id} for v in versions]


@router.get("/documents/{document_id}/changes")
async def list_change_summaries(
    document_id: str, authorization: Optional[str] = Header(None)
):
    _require_admin(authorization)
    db = _get_db()
    summaries = (db.collection("documentChangeSummaries")
                .where("documentId", "==", document_id)
                .order_by("generatedAt", direction="DESCENDING")
                .stream())
    return [s.to_dict() | {"id": s.id} for s in summaries]


@router.patch("/documents/{document_id}/disable")
async def disable_document(
    document_id: str, authorization: Optional[str] = Header(None)
):
    _require_admin(authorization)
    db = _get_db()
    db.collection("knowledgeDocuments").document(document_id).update(
        {"isDisabled": True})
    return {"disabled": True}


@router.patch("/documents/{document_id}/enable")
async def enable_document(
    document_id: str, authorization: Optional[str] = Header(None)
):
    _require_admin(authorization)
    db = _get_db()
    db.collection("knowledgeDocuments").document(document_id).update(
        {"isDisabled": False})
    return {"disabled": False}


@router.get("/documents/{document_id}/versions/{version_id}/download-url")
async def get_admin_download_url(
    document_id: str, version_id: str,
    authorization: Optional[str] = Header(None),
):
    """Admin-only short-lived signed URL for reviewing the original file."""
    _require_admin(authorization)
    db = _get_db()
    v_snap = db.collection("documentVersions").document(version_id).get()
    if not v_snap.exists:
        raise HTTPException(status_code=404, detail="Version not found")
    storage_path = v_snap.to_dict().get("storagePath")
    url = await _storage.generate_admin_signed_url(storage_path)
    return {"url": url, "expiresInMinutes": 10}


# ── User-facing: Ask Operations AI ────────────────────────────────────────────

@router.post("/ask", response_model=AskResponse)
async def ask_operations_ai(req: AskRequest):
    """
    Open to any approved crew member. The mobile app never sees documents —
    only this answer + citations.
    """
    category_filter = None
    if req.category:
        try:
            category_filter = DocumentCategory(req.category)
        except ValueError:
            pass

    answer = await _assistant.ask(req.query, category_filter=category_filter)

    return AskResponse(
        answer=answer.answer_text,
        confidence=answer.confidence,
        citations=[
            {
                "document": c.document_name,
                "version":  c.version_label,
                "section":  c.section,
                "page":     c.page,
                "label":    c.format_label(),
            }
            for c in answer.citations
        ],
    )


@router.get("/categories")
async def list_categories():
    """Public — used to populate category filter chips in the app."""
    return [c.value for c in DocumentCategory]


def _get_db():
    from utils.firebase import get_firestore
    return get_firestore()
