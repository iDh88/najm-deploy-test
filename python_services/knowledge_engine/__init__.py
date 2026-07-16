"""
Knowledge Engine
Operational document management + RAG-based AI assistant.
Documents are NEVER exposed to the mobile app — only answers and citations.
"""
from .models import (
    KnowledgeDocument, DocumentVersion, DocumentChunk, RetrievedChunk,
    Citation, AIAnswer, DocumentChangeSummary, ChangeSummaryItem,
    DocumentCategory, DocumentStatus, FileType,
)
from .indexing_service   import IndexingService
from .retrieval_service  import RetrievalService
from .ai_assistant       import OperationalAIAssistant
from .version_diff       import VersionDiffEngine
from .storage_service    import KnowledgeStorageService
from .vector_store       import VectorStore, FirestoreVectorStore
from .router             import router

__all__ = [
    "KnowledgeDocument", "DocumentVersion", "DocumentChunk", "RetrievedChunk",
    "Citation", "AIAnswer", "DocumentChangeSummary", "ChangeSummaryItem",
    "DocumentCategory", "DocumentStatus", "FileType",
    "IndexingService", "RetrievalService", "OperationalAIAssistant",
    "VersionDiffEngine", "KnowledgeStorageService",
    "VectorStore", "FirestoreVectorStore",
    "router",
]
