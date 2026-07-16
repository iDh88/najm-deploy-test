"""
Knowledge Engine — Data Models
Document lifecycle: upload → extract → chunk → embed → index → retrieve.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class DocumentCategory(str, Enum):
    GOM                    = "GOM"
    FATIGUE_MANAGEMENT     = "FATIGUE_MANAGEMENT"
    CREW_SCHEDULING        = "CREW_SCHEDULING"
    TRADE_POLICIES         = "TRADE_POLICIES"
    GACA_REGULATIONS       = "GACA_REGULATIONS"
    OPERATIONAL_BULLETINS  = "OPERATIONAL_BULLETINS"
    AIRPORT_INFORMATION    = "AIRPORT_INFORMATION"
    LAYOVER_GUIDES         = "LAYOVER_GUIDES"
    COMPANY_PROCEDURES     = "COMPANY_PROCEDURES"
    EMERGENCY_PROCEDURES   = "EMERGENCY_PROCEDURES"
    OTHER                  = "OTHER"


class DocumentStatus(str, Enum):
    PROCESSING = "PROCESSING"   # extraction/embedding in progress
    ACTIVE     = "ACTIVE"       # live, searchable, current version
    ARCHIVED   = "ARCHIVED"     # superseded by a newer version
    FAILED     = "FAILED"       # processing failed
    DISABLED   = "DISABLED"     # manually deactivated by admin, kept for history


class FileType(str, Enum):
    PDF  = "PDF"
    DOCX = "DOCX"
    XLSX = "XLSX"
    CSV  = "CSV"
    ZIP  = "ZIP"
    PPTX = "PPTX"   # future-ready
    HTML = "HTML"   # future-ready
    TXT  = "TXT"    # future-ready


@dataclass
class KnowledgeDocument:
    """
    One document record. A 'document' is the logical entity (e.g. "Fatigue Manual").
    Each upload creates a new DocumentVersion linked to this document.
    """
    id:               str
    name:             str
    category:         DocumentCategory
    description:      str
    created_at:       datetime
    active_version_id: Optional[str] = None
    is_disabled:      bool = False

    @property
    def display_category(self) -> str:
        return self.category.value.replace("_", " ").title()


@dataclass
class DocumentVersion:
    """One specific uploaded file version of a KnowledgeDocument."""
    id:                str
    document_id:       str
    version_number:    int
    file_type:         FileType
    storage_path:       str    # private bucket path, never public
    file_size_bytes:   int
    effective_date:    datetime
    expiration_date:   Optional[datetime]
    status:            DocumentStatus
    uploaded_by:       str     # admin user id
    uploaded_at:       datetime
    previous_version_id: Optional[str] = None

    # Processing metadata
    page_count:        Optional[int] = None
    chunk_count:       Optional[int] = None
    processing_error:  Optional[str] = None
    indexed_at:        Optional[datetime] = None

    @property
    def is_active(self) -> bool:
        return self.status == DocumentStatus.ACTIVE

    @property
    def is_expired(self) -> bool:
        if not self.expiration_date:
            return False
        return datetime.utcnow() > self.expiration_date


@dataclass
class DocumentChunk:
    """
    One searchable chunk of text extracted from a document version.
    Stored with its embedding vector for retrieval.
    """
    id:             str
    document_id:    str
    version_id:     str
    chunk_index:    int          # position within the document
    text:           str
    embedding:      list[float]  # vector — typically 1536 dims (text-embedding-3-small)
    page_number:    Optional[int] = None
    section_label:  Optional[str] = None   # e.g. "7.3" or "Section 7.3"
    char_start:     int = 0
    char_end:       int = 0


@dataclass
class RetrievedChunk:
    """A chunk returned from a similarity search, with its score."""
    chunk:          DocumentChunk
    document_name:  str
    version_number: int
    category:       DocumentCategory
    similarity:     float    # 0–1, higher = more relevant


@dataclass
class Citation:
    """User-facing source citation — no internal IDs or scores exposed."""
    document_name:  str
    version_label:  str       # "Rev 12"
    section:        Optional[str]
    page:           Optional[int]

    def format_label(self) -> str:
        parts = [self.document_name, self.version_label]
        if self.section:
            parts.append(f"Section {self.section}")
        if self.page:
            parts.append(f"Page {self.page}")
        return " · ".join(parts)


@dataclass
class AIAnswer:
    """Final answer returned to the Flutter app."""
    answer_text:   str
    citations:     list[Citation]
    confidence:    str          # "HIGH" | "MEDIUM" | "LOW"
    query:         str
    answered_at:   datetime = field(default_factory=datetime.utcnow)


@dataclass
class ChangeSummaryItem:
    category:      str    # "rule_change" | "fatigue_change" | "legality_change" | "general"
    description:   str
    old_text:      Optional[str] = None
    new_text:      Optional[str] = None
    section:       Optional[str] = None


@dataclass
class DocumentChangeSummary:
    """Generated when a new version replaces an old one."""
    document_id:        str
    old_version_id:      str
    new_version_id:      str
    old_version_number:  int
    new_version_number:  int
    generated_at:        datetime
    items:               list[ChangeSummaryItem] = field(default_factory=list)
    overall_summary:     str = ""

    @property
    def has_rule_changes(self) -> bool:
        return any(i.category == "rule_change" for i in self.items)

    @property
    def has_legality_changes(self) -> bool:
        return any(i.category == "legality_change" for i in self.items)

    @property
    def has_fatigue_changes(self) -> bool:
        return any(i.category == "fatigue_change" for i in self.items)
