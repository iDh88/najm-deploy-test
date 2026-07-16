"""
Knowledge Engine — Storage Service
Documents are NEVER public. Stored in a private bucket path.
Signed URLs are short-lived and admin-only.
"""
from __future__ import annotations
import logging
import uuid
from datetime import datetime, timedelta

logger = logging.getLogger("cip.knowledge_engine.storage")

PRIVATE_BUCKET_PREFIX = "knowledge_base"
SIGNED_URL_EXPIRY_MINUTES = 10


class KnowledgeStorageService:
    """
    All documents live under: knowledge_base/{documentId}/{versionId}.{ext}
    This path is never exposed to the Flutter app and never made public.
    """

    def __init__(self):
        self._bucket = None

    def _get_bucket(self):
        if self._bucket is None:
            from firebase_admin import storage
            self._bucket = storage.bucket()
        return self._bucket

    def build_storage_path(
        self, document_id: str, version_id: str, file_extension: str
    ) -> str:
        ext = file_extension.lower().lstrip(".")
        return f"{PRIVATE_BUCKET_PREFIX}/{document_id}/{version_id}.{ext}"

    async def upload(
        self, local_file_path: str, storage_path: str, content_type: str,
    ) -> int:
        """
        Uploads a file to the private bucket path. Returns file size in bytes.
        The blob is never made public — no `make_public()` call, ever.
        """
        bucket = self._get_bucket()
        blob   = bucket.blob(storage_path)
        blob.upload_from_filename(local_file_path, content_type=content_type)
        blob.reload()
        logger.info(f"Uploaded document to private path: {storage_path}")
        return blob.size or 0

    async def download_to_temp(self, storage_path: str) -> str:
        """Download a private document to a local temp file for processing."""
        bucket   = self._get_bucket()
        blob     = bucket.blob(storage_path)
        tmp_path = f"/tmp/_kb_download_{uuid.uuid4().hex}"
        blob.download_to_filename(tmp_path)
        return tmp_path

    async def generate_admin_signed_url(self, storage_path: str) -> str:
        """
        Short-lived signed URL for admin review/download only.
        Never call this for end-user (crew) access.
        """
        bucket = self._get_bucket()
        blob   = bucket.blob(storage_path)
        url = blob.generate_signed_url(
            expiration=timedelta(minutes=SIGNED_URL_EXPIRY_MINUTES),
            method="GET",
        )
        return url

    async def delete(self, storage_path: str) -> None:
        """Hard delete from storage — only used for failed/aborted uploads,
        never for published versions (those are archived, not deleted)."""
        bucket = self._get_bucket()
        blob   = bucket.blob(storage_path)
        if blob.exists():
            blob.delete()
            logger.info(f"Deleted document at: {storage_path}")
