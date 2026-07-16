"""
Knowledge Engine — Retrieval Service
Takes a user query, embeds it, and retrieves the most relevant chunks
from active document versions only.
"""
from __future__ import annotations
import logging

from .models import RetrievedChunk, DocumentCategory
from .embeddings import EmbeddingClient
from .vector_store import FirestoreVectorStore

logger = logging.getLogger("cip.knowledge_engine.retrieval")

DEFAULT_TOP_K = 8
MIN_SIMILARITY_THRESHOLD = 0.25   # below this, a chunk isn't relevant enough


class RetrievalService:

    def __init__(self):
        self._embeddings = EmbeddingClient()
        self._vector_store = FirestoreVectorStore()

    async def retrieve(
        self,
        query: str,
        top_k: int = DEFAULT_TOP_K,
        category_filter: DocumentCategory | None = None,
    ) -> list[RetrievedChunk]:
        """
        Embeds the query and returns the top-k most relevant chunks
        from currently active document versions.
        """
        query_embedding = await self._embeddings.embed_query(query)
        if not query_embedding:
            logger.warning("Query embedding failed — returning no results")
            return []

        results = await self._vector_store.search(
            query_embedding=query_embedding,
            top_k=top_k,
            category_filter=category_filter,
            active_only=True,
        )

        relevant = [r for r in results if r.similarity >= MIN_SIMILARITY_THRESHOLD]

        if not relevant:
            logger.info(f"No sufficiently relevant chunks for query: {query[:80]}")

        return relevant
