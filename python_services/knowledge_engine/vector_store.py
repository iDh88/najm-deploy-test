"""
Knowledge Engine — Vector Store
Abstract interface so the storage backend can scale from Firestore (v1)
to a dedicated vector DB (Pinecone/Weaviate/etc) later without touching
retrieval_service.py or any caller.
"""
from __future__ import annotations
import logging
from abc import ABC, abstractmethod
from datetime import datetime

from .models import DocumentChunk, RetrievedChunk, DocumentCategory
from .embeddings import cosine_similarity

logger = logging.getLogger("cip.knowledge_engine.vector_store")


class VectorStore(ABC):
    """Abstract vector storage interface."""

    @abstractmethod
    async def upsert_chunks(self, chunks: list[DocumentChunk]) -> None: ...

    @abstractmethod
    async def delete_version_chunks(self, version_id: str) -> None: ...

    @abstractmethod
    async def search(
        self,
        query_embedding: list[float],
        top_k: int = 8,
        category_filter: DocumentCategory | None = None,
        active_only: bool = True,
    ) -> list[RetrievedChunk]: ...


class FirestoreVectorStore(VectorStore):
    """
    v1 implementation — stores chunks + embeddings directly in Firestore
    and does cosine-similarity search in Python.

    Scales to tens of thousands of chunks comfortably. Beyond that,
    swap this class for a dedicated vector DB — callers are unaffected.
    """

    def __init__(self):
        self._db = None

    def _get_db(self):
        if self._db is None:
            from utils.firebase import get_firestore
            self._db = get_firestore()
        return self._db

    async def upsert_chunks(self, chunks: list[DocumentChunk]) -> None:
        db = self._get_db()
        batch = db.batch()
        col = db.collection("knowledgeChunks")

        for i, chunk in enumerate(chunks):
            ref = col.document(chunk.id)
            batch.set(ref, {
                "documentId":   chunk.document_id,
                "versionId":    chunk.version_id,
                "chunkIndex":   chunk.chunk_index,
                "text":         chunk.text,
                "embedding":    chunk.embedding,
                "pageNumber":   chunk.page_number,
                "sectionLabel": chunk.section_label,
                "charStart":    chunk.char_start,
                "charEnd":      chunk.char_end,
                "createdAt":    datetime.utcnow().isoformat(),
            })
            if i % 450 == 449:
                batch.commit()
                batch = db.batch()

        batch.commit()
        logger.info(f"Upserted {len(chunks)} chunks")

    async def delete_version_chunks(self, version_id: str) -> None:
        db   = self._get_db()
        docs = (db.collection("knowledgeChunks")
                .where("versionId", "==", version_id)
                .stream())
        batch = db.batch()
        count = 0
        for doc in docs:
            batch.delete(doc.reference)
            count += 1
            if count % 450 == 449:
                batch.commit()
                batch = db.batch()
        batch.commit()
        logger.info(f"Deleted {count} chunks for version {version_id}")

    async def search(
        self,
        query_embedding: list[float],
        top_k: int = 8,
        category_filter: DocumentCategory | None = None,
        active_only: bool = True,
    ) -> list[RetrievedChunk]:
        db = self._get_db()

        version_query = db.collection("documentVersions")
        if active_only:
            version_query = version_query.where("status", "==", "ACTIVE")

        version_docs = list(version_query.stream())
        version_map: dict[str, dict] = {}
        doc_ids_needed = set()

        for v in version_docs:
            vdata = v.to_dict()
            version_map[v.id] = vdata
            doc_ids_needed.add(vdata.get("documentId"))

        if not version_map:
            return []

        doc_map: dict[str, dict] = {}
        for doc_id in doc_ids_needed:
            doc_snap = db.collection("knowledgeDocuments").document(doc_id).get()
            if doc_snap.exists:
                doc_map[doc_id] = doc_snap.to_dict()

        if category_filter:
            allowed_version_ids = {
                vid for vid, v in version_map.items()
                if doc_map.get(v.get("documentId"), {}).get("category")
                   == category_filter.value
            }
        else:
            allowed_version_ids = set(version_map.keys())

        if not allowed_version_ids:
            return []

        scored: list[RetrievedChunk] = []
        chunk_docs = db.collection("knowledgeChunks").stream()

        for c in chunk_docs:
            data = c.to_dict()
            version_id = data.get("versionId")
            if version_id not in allowed_version_ids:
                continue

            embedding = data.get("embedding") or []
            similarity = cosine_similarity(query_embedding, embedding)

            version_info = version_map.get(version_id, {})
            doc_info = doc_map.get(version_info.get("documentId"), {})

            chunk = DocumentChunk(
                id=c.id,
                document_id=data.get("documentId", ""),
                version_id=version_id,
                chunk_index=data.get("chunkIndex", 0),
                text=data.get("text", ""),
                embedding=embedding,
                page_number=data.get("pageNumber"),
                section_label=data.get("sectionLabel"),
                char_start=data.get("charStart", 0),
                char_end=data.get("charEnd", 0),
            )

            scored.append(RetrievedChunk(
                chunk=chunk,
                document_name=doc_info.get("name", "Unknown Document"),
                version_number=version_info.get("versionNumber", 0),
                category=DocumentCategory(
                    doc_info.get("category", "OTHER")),
                similarity=similarity,
            ))

        scored.sort(key=lambda r: r.similarity, reverse=True)
        return scored[:top_k]
