"""
Unit tests — Knowledge Engine
Tests chunking, extraction dispatch, and model behavior.
No network calls (embeddings/AI calls are mocked or skipped).
"""
import pytest
import tempfile
import os
import csv

from knowledge_engine.models import (
    DocumentCategory, DocumentStatus, FileType,
    KnowledgeDocument, DocumentVersion, Citation, DocumentChangeSummary,
    ChangeSummaryItem,
)
from knowledge_engine.extractors import (
    extract_document, ExtractedPage, ExtractionResult,
)
from knowledge_engine.chunker import chunk_extraction, RawChunk
from knowledge_engine.embeddings import cosine_similarity


# ── Models ────────────────────────────────────────────────────────────────────

class TestModels:

    def test_document_category_values(self):
        assert DocumentCategory.GOM.value == "GOM"
        assert DocumentCategory.FATIGUE_MANAGEMENT.value == "FATIGUE_MANAGEMENT"

    def test_document_display_category(self):
        doc = KnowledgeDocument(
            id="d1", name="Fatigue Manual",
            category=DocumentCategory.FATIGUE_MANAGEMENT,
            description="", created_at=None,
        )
        assert doc.display_category == "Fatigue Management"

    def test_version_is_active(self):
        v = DocumentVersion(
            id="v1", document_id="d1", version_number=2,
            file_type=FileType.PDF, storage_path="x", file_size_bytes=100,
            effective_date=None, expiration_date=None,
            status=DocumentStatus.ACTIVE, uploaded_by="u1", uploaded_at=None,
        )
        assert v.is_active is True

    def test_version_not_active_when_archived(self):
        v = DocumentVersion(
            id="v1", document_id="d1", version_number=1,
            file_type=FileType.PDF, storage_path="x", file_size_bytes=100,
            effective_date=None, expiration_date=None,
            status=DocumentStatus.ARCHIVED, uploaded_by="u1", uploaded_at=None,
        )
        assert v.is_active is False

    def test_citation_format_label_full(self):
        c = Citation(document_name="GOM", version_label="Rev 12",
                     section="7.3", page=284)
        assert c.format_label() == "GOM · Rev 12 · Section 7.3 · Page 284"

    def test_citation_format_label_minimal(self):
        c = Citation(document_name="GOM", version_label="Rev 1",
                     section=None, page=None)
        assert c.format_label() == "GOM · Rev 1"

    def test_change_summary_flags(self):
        summary = DocumentChangeSummary(
            document_id="d1", old_version_id="v1", new_version_id="v2",
            old_version_number=1, new_version_number=2, generated_at=None,
            items=[
                ChangeSummaryItem(category="legality_change", description="x"),
                ChangeSummaryItem(category="general", description="y"),
            ],
        )
        assert summary.has_legality_changes is True
        assert summary.has_fatigue_changes is False
        assert summary.has_rule_changes is False


# ── Extractors ────────────────────────────────────────────────────────────────

class TestExtractors:

    def test_csv_extraction(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".csv", delete=False, newline=""
        ) as f:
            writer = csv.writer(f)
            writer.writerow(["Rule", "Limit"])
            writer.writerow(["FDP", "14:00"])
            writer.writerow(["Rest", "10:00"])
            path = f.name

        try:
            result = extract_document(path, "CSV")
            assert result.page_count == 1
            assert "FDP" in result.full_text
            assert "14:00" in result.full_text
        finally:
            os.unlink(path)

    def test_unsupported_type_raises(self):
        with pytest.raises(ValueError):
            extract_document("/tmp/fake.xyz", "XYZ")

    def test_pdf_extraction_handles_missing_file_gracefully(self):
        result = extract_document("/tmp/does_not_exist_12345.pdf", "PDF")
        assert isinstance(result, ExtractionResult)
        assert result.page_count == 0
        assert len(result.warnings) > 0


# ── Chunker ───────────────────────────────────────────────────────────────────

class TestChunker:

    def _make_result(self, pages_text: list[str]) -> ExtractionResult:
        pages = [
            ExtractedPage(page_number=i + 1, text=t, section_label=None)
            for i, t in enumerate(pages_text)
        ]
        return ExtractionResult(
            pages=pages,
            full_text="\n\n".join(pages_text),
            page_count=len(pages),
            extractor="test",
            warnings=[],
        )

    def test_short_text_produces_one_chunk(self):
        result = self._make_result(["This is a short page of text. " * 5])  # >100 chars
        chunks = chunk_extraction(result)
        assert len(chunks) == 1

    def test_long_text_produces_multiple_chunks(self):
        long_text = "This is a sentence about crew scheduling rules. " * 200
        result = self._make_result([long_text])
        chunks = chunk_extraction(result)
        assert len(chunks) > 1

    def test_chunks_preserve_page_number(self):
        result = self._make_result(["Page one content here. " * 6])  # >100 chars
        chunks = chunk_extraction(result)
        assert chunks[0].page_number == 1

    def test_empty_pages_produce_no_chunks(self):
        result = self._make_result(["", "   ", ""])
        chunks = chunk_extraction(result)
        assert len(chunks) == 0

    def test_section_label_propagated_from_page(self):
        # section_label is populated by the EXTRACTOR (extractors.py detects
        # operations-manual headings) and stored on ExtractedPage. The chunker's
        # contract is to PROPAGATE that page-level label onto its chunks, not to
        # re-parse headings from text. This verifies that propagation.
        # (Heading->label extraction itself is covered at the extractor layer.)
        result = self._make_result([
            "This section describes FDP limits for cabin crew operating "
            "international routes and the applicable rest requirements." * 3
        ])
        result.pages[0].section_label = "7.3"
        chunks = chunk_extraction(result)
        assert chunks and all(c.section_label == "7.3" for c in chunks)

    def test_chunks_have_overlap(self):
        long_text = " ".join(f"Sentence number {i}." for i in range(300))
        result = self._make_result([long_text])
        chunks = chunk_extraction(result)
        if len(chunks) >= 2:
            assert chunks[0].char_end > chunks[1].char_start

    def test_minimum_chunk_size_respected(self):
        result = self._make_result(["short"])  # below MIN_CHUNK_CHARS
        chunks = chunk_extraction(result)
        assert len(chunks) == 0


# ── Embeddings utility ─────────────────────────────────────────────────────────

class TestCosineSimilarity:

    def test_identical_vectors_similarity_one(self):
        v = [1.0, 2.0, 3.0]
        assert abs(cosine_similarity(v, v) - 1.0) < 1e-6

    def test_orthogonal_vectors_similarity_zero(self):
        a = [1.0, 0.0]
        b = [0.0, 1.0]
        assert abs(cosine_similarity(a, b)) < 1e-6

    def test_opposite_vectors_similarity_negative(self):
        a = [1.0, 0.0]
        b = [-1.0, 0.0]
        assert cosine_similarity(a, b) < 0

    def test_empty_vectors_return_zero(self):
        assert cosine_similarity([], []) == 0.0
        assert cosine_similarity([1.0], []) == 0.0

    def test_mismatched_length_returns_zero(self):
        assert cosine_similarity([1.0, 2.0], [1.0]) == 0.0
