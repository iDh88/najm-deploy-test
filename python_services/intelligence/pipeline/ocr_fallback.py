"""OCR fallback for scanned or corrupted PDFs."""
from __future__ import annotations
import logging
import re
from pathlib import Path

try:
    import fitz           # PyMuPDF
    FITZ_AVAILABLE = True
except ImportError:
    FITZ_AVAILABLE = False

try:
    from pdf2image import convert_from_path
    import pytesseract
    from PIL import Image
    OCR_AVAILABLE = True
except ImportError:
    OCR_AVAILABLE = False

from ..models.raw_models import ExtractionResult, ExtractionQuality
from .pdf_extractor import PDFPlumberExtractor

logger = logging.getLogger(__name__)


class PyMuPDFExtractor:
    """
    Layer 2 extractor — PyMuPDF handles complex layouts and some
    PDFs that pdfplumber fails on.
    """

    def extract(self, pdf_path: str) -> ExtractionResult:
        if not FITZ_AVAILABLE:
            raise RuntimeError("PyMuPDF (fitz) not installed")

        errors:   list[str] = []
        warnings: list[str] = []
        all_text = ""

        try:
            doc = fitz.open(pdf_path)
            page_count = len(doc)
            for page in doc:
                # Use dict extraction for better layout preservation
                blocks = page.get_text("blocks")
                blocks.sort(key=lambda b: (b[1], b[0]))  # sort top→bottom, left→right
                for block in blocks:
                    if block[6] == 0:   # text block (not image)
                        all_text += block[4] + "\n"
            doc.close()
        except Exception as e:
            errors.append(f"PyMuPDF failed: {e}")
            return ExtractionResult(
                lines=[], quality=ExtractionQuality.LOW,
                extractor_used="pymupdf", page_count=0,
                errors=errors,
            )

        if not all_text.strip():
            return ExtractionResult(
                lines=[], quality=ExtractionQuality.LOW,
                extractor_used="pymupdf", page_count=page_count,
                errors=["PyMuPDF: no text extracted"],
            )

        # Reuse the same parser logic from pdfplumber extractor
        parser = PDFPlumberExtractor()
        lines  = parser._parse_text(all_text, errors, warnings)
        quality = ExtractionQuality.MEDIUM if lines else ExtractionQuality.LOW

        return ExtractionResult(
            lines=lines, quality=quality,
            extractor_used="pymupdf", page_count=page_count,
            errors=errors, warnings=warnings,
        )


class OCRFallbackExtractor:
    """
    Layer 3 extractor — converts pages to images and runs Tesseract OCR.
    Used only when all other extractors fail.
    """

    TESSERACT_CONFIG = "--psm 6 -l eng"   # page segmentation mode 6 = uniform block

    def extract(self, pdf_path: str, dpi: int = 300) -> ExtractionResult:
        if not OCR_AVAILABLE:
            raise RuntimeError("pdf2image / pytesseract / Pillow not installed")

        errors:   list[str] = []
        warnings: list[str] = []
        all_text = ""

        try:
            images = convert_from_path(pdf_path, dpi=dpi)
        except Exception as e:
            errors.append(f"pdf2image conversion failed: {e}")
            return ExtractionResult(
                lines=[], quality=ExtractionQuality.LOW,
                extractor_used="ocr", page_count=0,
                errors=errors,
            )

        for i, img in enumerate(images):
            try:
                # Pre-process for better OCR accuracy
                img = self._preprocess(img)
                text = pytesseract.image_to_string(img, config=self.TESSERACT_CONFIG)
                all_text += text + "\n"
            except Exception as e:
                warnings.append(f"OCR failed on page {i+1}: {e}")

        if not all_text.strip():
            return ExtractionResult(
                lines=[], quality=ExtractionQuality.LOW,
                extractor_used="ocr", page_count=len(images),
                errors=["OCR produced no text"],
            )

        # Clean OCR artifacts common in aviation documents
        all_text = self._clean_ocr_text(all_text)

        parser = PDFPlumberExtractor()
        lines  = parser._parse_text(all_text, errors, warnings)

        return ExtractionResult(
            lines=lines,
            quality=ExtractionQuality.LOW,   # OCR always LOW quality
            extractor_used="ocr",
            page_count=len(images),
            errors=errors,
            warnings=warnings,
        )

    def _preprocess(self, img):
        """Convert to greyscale and increase contrast for better OCR."""
        img = img.convert('L')   # greyscale
        return img

    def _clean_ocr_text(self, text: str) -> str:
        """Fix common OCR errors in aviation documents."""
        replacements = {
            r'\bSU\b':  'SV',      # common OCR misread
            r'0RUH':    'ORUH',
            r'l(\d)':   r'1\1',    # lowercase L misread as 1
            r'(\d)l':   r'\g<1>1',
            r'\|':      'I',       # pipe misread
            r'D\.H\.':  'DH',
            r'(?<=[A-Z]{2})\s+(?=\d{3,4})': '',  # fix split flight numbers
        }
        for pattern, replacement in replacements.items():
            text = re.sub(pattern, replacement, text)
        return text
