"""
Knowledge Engine — Indexing Service
Orchestrates the full pipeline: extract → chunk → embed → store.
Runs as a background task after document upload.
"""
from __future__ import annotations
import logging
from datetime import datetime

from .models import DocumentVersion, DocumentChunk, DocumentStatus, FileType
from .extractors import extract_document
from .chunker import chunk_extraction
from .embeddings import EmbeddingClient
from .vector_store import FirestoreVectorStore
from .storage_service import KnowledgeStorageService

logger = logging.getLogger("cip.knowledge_engine.indexing")


class IndexingService:

    def __init__(self):
        self._embeddings = EmbeddingClient()
        self._vector_store = FirestoreVectorStore()
        self._storage = KnowledgeStorageService()

    async def index_version(
        self,
        document_id: str,
        version_id: str,
        local_file_path: str,
        file_type: FileType,
    ) -> IndexingResult:
        """
        Full pipeline for one document version.
        Updates the version's Firestore status as it progresses.
        """
        db = self._get_db()
        version_ref = db.collection("documentVersions").document(version_id)

        try:
            logger.info(f"Extracting {version_id} ({file_type.value})")
            extraction = extract_document(local_file_path, file_type.value)

            if not extraction.full_text.strip():
                version_ref.update({
                    "status": DocumentStatus.FAILED.value,
                    "processingError": "No extractable text found in document",
                })
                return IndexingResult(success=False,
                                      error="No extractable text found")

            raw_chunks = chunk_extraction(extraction)
            logger.info(f"Chunked into {len(raw_chunks)} pieces")

            if not raw_chunks:
                version_ref.update({
                    "status": DocumentStatus.FAILED.value,
                    "processingError": "No valid chunks produced",
                })
                return IndexingResult(success=False, error="No valid chunks")

            texts = [c.text for c in raw_chunks]
            vectors = await self._embeddings.embed_texts(texts)

            chunks: list[DocumentChunk] = []
            for i, (raw, vector) in enumerate(zip(raw_chunks, vectors)):
                chunks.append(DocumentChunk(
                    id=f"{version_id}_{i}",
                    document_id=document_id,
                    version_id=version_id,
                    chunk_index=i,
                    text=raw.text,
                    embedding=vector,
                    page_number=raw.page_number,
                    section_label=raw.section_label,
                    char_start=raw.char_start,
                    char_end=raw.char_end,
                ))

            await self._vector_store.upsert_chunks(chunks)

            version_ref.update({
                "status":       DocumentStatus.ACTIVE.value,
                "pageCount":    extraction.page_count,
                "chunkCount":   len(chunks),
                "indexedAt":    datetime.utcnow().isoformat(),
                "processingError": None,
            })

            logger.info(f"Indexing complete: {len(chunks)} chunks, "
                       f"{extraction.page_count} pages")

            return IndexingResult(
                success=True,
                chunk_count=len(chunks),
                page_count=extraction.page_count,
                warnings=extraction.warnings,
            )

        except Exception as e:
            logger.exception(f"Indexing failed for {version_id}: {e}")
            version_ref.update({
                "status": DocumentStatus.FAILED.value,
                "processingError": str(e),
            })
            return IndexingResult(success=False, error=str(e))

    async def reindex_document_replacement(
        self,
        document_id: str,
        old_version_id: str | None,
        new_version_id: str,
        local_file_path: str,
        file_type: FileType,
    ) -> IndexingResult:
        """
        Full replacement flow:
        1. Index the new version
        2. Archive the old version (and delete its chunks to save space)
        3. Update the parent document's active_version_id
        """
        result = await self.index_version(
            document_id, new_version_id, local_file_path, file_type)

        if not result.success:
            return result

        db = self._get_db()

        if old_version_id:
            db.collection("documentVersions").document(old_version_id).update({
                "status": DocumentStatus.ARCHIVED.value,
            })
            await self._vector_store.delete_version_chunks(old_version_id)

        db.collection("knowledgeDocuments").document(document_id).update({
            "activeVersionId": new_version_id,
        })

        return result

    def _get_db(self):
        from utils.firebase import get_firestore
        return get_firestore()


class IndexingResult:
    def __init__(
        self,
        success: bool,
        chunk_count: int = 0,
        page_count: int = 0,
        warnings: list[str] | None = None,
        error: str | None = None,
    ):
        self.success     = success
        self.chunk_count = chunk_count
        self.page_count  = page_count
        self.warnings    = warnings or []
        self.error        = error
