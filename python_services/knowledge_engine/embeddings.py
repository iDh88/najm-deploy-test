"""
Knowledge Engine — Embeddings
Wraps the embedding model used to vectorize chunks and queries.
Uses OpenAI text-embedding-3-small (1536 dims) — cheap, fast, good for
manual/procedural text retrieval.
"""
from __future__ import annotations
import asyncio
import logging
import os

logger = logging.getLogger("cip.knowledge_engine.embeddings")

EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_DIMS  = 1536
BATCH_SIZE = 96


class EmbeddingClient:
    """Thin wrapper — swap implementation here if the embedding provider changes."""

    def __init__(self):
        self._client = None

    def _get_client(self):
        if self._client is None:
            try:
                from openai import OpenAI
                api_key = os.environ.get("OPENAI_API_KEY")
                if not api_key:
                    raise RuntimeError(
                        "OPENAI_API_KEY not set — required for knowledge base embeddings")
                self._client = OpenAI(api_key=api_key)
            except ImportError:
                raise RuntimeError("openai package not installed")
        return self._client

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        """Embed a batch of texts. Returns vectors in the same order."""
        if not texts:
            return []

        client = self._get_client()
        all_vectors: list[list[float]] = []

        for i in range(0, len(texts), BATCH_SIZE):
            batch = texts[i:i + BATCH_SIZE]
            vectors = await asyncio.get_event_loop().run_in_executor(
                None, self._embed_batch_sync, client, batch
            )
            all_vectors.extend(vectors)

        return all_vectors

    async def embed_query(self, query: str) -> list[float]:
        """Embed a single query string for retrieval."""
        vectors = await self.embed_texts([query])
        return vectors[0] if vectors else []

    def _embed_batch_sync(self, client, batch: list[str]) -> list[list[float]]:
        try:
            response = client.embeddings.create(
                model=EMBEDDING_MODEL,
                input=batch,
            )
            return [item.embedding for item in response.data]
        except Exception as e:
            logger.error(f"Embedding batch failed: {e}")
            return [[0.0] * EMBEDDING_DIMS for _ in batch]


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Cosine similarity between two vectors. Used by the Firestore-backed
    vector store for v1 (see vector_store.py)."""
    if not a or not b or len(a) != len(b):
        return 0.0
    dot    = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(y * y for y in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)
