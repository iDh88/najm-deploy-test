"""
Main extraction pipeline — orchestrates all extraction layers,
normalizes to domain models, and handles fallback chains.
"""
from __future__ import annotations
import logging
import re
from pathlib import Path

from ..models.raw_models import ExtractionResult, ExtractionQuality, RawLine
from ..models.pairing_models import Pairing
from .pdf_extractor import PDFPlumberExtractor
from .ocr_fallback import PyMuPDFExtractor, OCRFallbackExtractor
from .structural_parser import StructuralParser

logger = logging.getLogger(__name__)


class ExtractionPipeline:
    """
    Multi-layer PDF extraction pipeline.

    Layer 1: pdfplumber  — fast, accurate for digital PDFs
    Layer 2: PyMuPDF     — fallback for complex layouts
    Layer 3: OCR         — last resort for scanned PDFs
    Layer 4: Structural  — raw tokens → normalized models
    """

    def __init__(self):
        self.extractors = [
            PDFPlumberExtractor(),
            PyMuPDFExtractor(),
            OCRFallbackExtractor(),
        ]
        self.parser = StructuralParser()

    def process(self, pdf_path: str,
                year: int = 2026) -> PipelineResult:
        """
        Run the full extraction and normalization pipeline.
        Returns a PipelineResult with all pairings and metadata.
        """
        path = Path(pdf_path)
        if not path.exists():
            return PipelineResult(
                success=False,
                errors=[f"File not found: {pdf_path}"],
            )

        # ── Phase 1: Extract raw text ─────────────────────────────────────────
        extraction: ExtractionResult | None = None

        for extractor in self.extractors:
            try:
                result = extractor.extract(pdf_path)
                if result.lines:
                    extraction = result
                    logger.info(
                        "Extraction succeeded",
                        extractor=result.extractor_used,
                        lines=len(result.lines),
                        quality=result.quality,
                    )
                    break
                else:
                    logger.warning(
                        "Extractor returned no lines, trying next",
                        extractor=result.extractor_used,
                        errors=result.errors,
                    )
            except Exception as e:
                logger.warning(f"Extractor failed: {e}")
                continue

        if not extraction or not extraction.lines:
            return PipelineResult(
                success=False,
                errors=["All extraction layers failed — unsupported PDF format"],
            )

        # ── Phase 2: Detect period/year ───────────────────────────────────────
        detected_year = self._detect_year(extraction) or year

        # ── Phase 3: Structural parse ─────────────────────────────────────────
        all_pairings:  list[Pairing] = []
        all_warnings:  list[str]     = []
        all_raw_lines: list[RawLine] = extraction.lines

        for raw_line in all_raw_lines:
            pairings, warnings = self.parser.parse_line(raw_line, detected_year)
            all_pairings.extend(pairings)
            all_warnings.extend(warnings)

        return PipelineResult(
            success=True,
            raw_lines=all_raw_lines,
            pairings=all_pairings,
            extraction_quality=extraction.quality,
            extractor_used=extraction.extractor_used,
            page_count=extraction.page_count,
            warnings=all_warnings,
            errors=extraction.errors,
            detected_year=detected_year,
        )

    def _detect_year(self, extraction: ExtractionResult) -> int | None:
        """Try to detect the schedule year from raw text."""
        for raw_line in extraction.lines:
            if raw_line.period_str:
                match = re.search(r'20\d{2}', raw_line.period_str)
                if match:
                    return int(match.group())
        return None


class PipelineResult:
    def __init__(
        self,
        success: bool,
        raw_lines: list[RawLine] | None = None,
        pairings: list[Pairing] | None = None,
        extraction_quality: ExtractionQuality = ExtractionQuality.LOW,
        extractor_used: str = "none",
        page_count: int = 0,
        warnings: list[str] | None = None,
        errors: list[str] | None = None,
        detected_year: int = 2026,
    ):
        self.success            = success
        self.raw_lines          = raw_lines or []
        self.pairings           = pairings or []
        self.extraction_quality = extraction_quality
        self.extractor_used     = extractor_used
        self.page_count         = page_count
        self.warnings           = warnings or []
        self.errors             = errors or []
        self.detected_year      = detected_year

    @property
    def pairing_count(self) -> int:
        return len(self.pairings)

    @property
    def line_count(self) -> int:
        return len(self.raw_lines)
