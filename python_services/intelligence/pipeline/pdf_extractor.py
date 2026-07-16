"""Primary PDF extractor using pdfplumber — handles digital PDFs."""
from __future__ import annotations
import re
import logging
from pathlib import Path
from typing import Optional

try:
    import pdfplumber
    PDFPLUMBER_AVAILABLE = True
except ImportError:
    PDFPLUMBER_AVAILABLE = False

from ..models.raw_models import (
    RawLine, RawPairing, RawSegment, ExtractionResult, ExtractionQuality
)

logger = logging.getLogger(__name__)


class PDFPlumberExtractor:
    """
    Layer 1 extractor — uses pdfplumber for clean digital PDFs.
    Handles Saudi Airlines standard monthly line format.
    """

    # Regex patterns for SV line format
    RE_LINE_HEADER    = re.compile(
        r'LINE\s+(\w+)\s+(?:BASE:\s*(\w+))?\s*(?:PERIOD:\s*([\w\s]+))?',
        re.IGNORECASE
    )
    RE_PAIRING_HEADER = re.compile(
        r'(?:PA|PR|PTG)\s*[-:]?\s*(\d{3,5})\s+(?:DATE[S]?:\s*)?([\dA-Z,\s-]+)',
        re.IGNORECASE
    )
    RE_FLIGHT         = re.compile(
        r'(?:(DH|DHD)\s+)?'         # optional deadhead flag
        r'(SV|SVA|SVQ|\w{2})\s*'   # airline code
        r'(\d{3,4})\s+'             # flight number
        r'([A-Z]{3})\s*[-–→]\s*'   # origin
        r'([A-Z]{3})\s+'            # destination
        r'(\d{4}[ZL]?)\s*[-–]\s*'  # departure
        r'(\d{4}[ZL]?(?:\+\d)?)\s*' # arrival
        r'(?:BLK[:\s]*(\d{1,2}:\d{2}))?',  # optional block
        re.IGNORECASE
    )
    RE_BLOCK_LINE     = re.compile(
        r'(?:BLOCK|BLK)[:\s]+([\d:]+)\s+'
        r'(?:DUTY|DTY)[:\s]+([\d:]+)',
        re.IGNORECASE
    )
    RE_REST_LINE      = re.compile(
        r'REST[:\s]+([\d:]+)',
        re.IGNORECASE
    )
    RE_REPORT_TIME    = re.compile(
        r'(?:RPT|REPORT)[:\s]+(\d{4}[ZL]?)',
        re.IGNORECASE
    )
    RE_RELEASE_TIME   = re.compile(
        r'(?:RLS|RELEASE)[:\s]+(\d{4}[ZL]?(?:\+\d)?)',
        re.IGNORECASE
    )
    RE_OFF_DAYS       = re.compile(
        r'OFF\s+([\dA-Z,\s]+)',
        re.IGNORECASE
    )

    def extract(self, pdf_path: str) -> ExtractionResult:
        if not PDFPLUMBER_AVAILABLE:
            raise RuntimeError("pdfplumber not installed")

        path = Path(pdf_path)
        if not path.exists():
            raise FileNotFoundError(f"PDF not found: {pdf_path}")

        errors:   list[str] = []
        warnings: list[str] = []
        all_text  = ""
        page_count = 0

        try:
            with pdfplumber.open(str(path)) as pdf:
                page_count = len(pdf.pages)
                for page in pdf.pages:
                    text = page.extract_text(x_tolerance=3, y_tolerance=3)
                    if text:
                        all_text += text + "\n"
                    else:
                        warnings.append(f"Page {page.page_number}: no text extracted")
        except Exception as e:
            errors.append(f"pdfplumber failed: {e}")
            return ExtractionResult(
                lines=[], quality=ExtractionQuality.LOW,
                extractor_used="pdfplumber", page_count=0,
                errors=errors, warnings=warnings,
            )

        if not all_text.strip():
            return ExtractionResult(
                lines=[], quality=ExtractionQuality.LOW,
                extractor_used="pdfplumber", page_count=page_count,
                errors=["No text content extracted"],
                warnings=warnings,
            )

        lines = self._parse_text(all_text, errors, warnings)
        quality = (
            ExtractionQuality.HIGH   if not errors else
            ExtractionQuality.MEDIUM if lines else
            ExtractionQuality.LOW
        )

        return ExtractionResult(
            lines=lines,
            quality=quality,
            extractor_used="pdfplumber",
            page_count=page_count,
            errors=errors,
            warnings=warnings,
        )

    def _parse_text(self, text: str,
                    errors: list[str],
                    warnings: list[str]) -> list[RawLine]:
        """Parse extracted text into RawLine structures."""
        lines = []
        current_line: Optional[RawLine] = None
        current_pairing: Optional[RawPairing] = None

        for line_num, text_line in enumerate(text.splitlines(), 1):
            stripped = text_line.strip()
            if not stripped:
                continue

            # Detect line header
            lh = self.RE_LINE_HEADER.search(stripped)
            if lh and 'PAIRING' not in stripped.upper():
                if current_line:
                    if current_pairing:
                        current_line.pairings.append(current_pairing)
                        current_pairing = None
                    lines.append(current_line)
                current_line = RawLine(
                    raw_text=stripped,
                    line_number=lh.group(1),
                    base=lh.group(2),
                    period_str=lh.group(3).strip() if lh.group(3) else None,
                )
                continue

            if current_line is None:
                continue

            # Detect pairing header
            ph = self.RE_PAIRING_HEADER.search(stripped)
            if ph:
                if current_pairing:
                    current_line.pairings.append(current_pairing)
                current_pairing = RawPairing(
                    raw_text=stripped,
                    pairing_id=f"PA{ph.group(1)}",
                    date_strings=[d.strip() for d in
                                  re.split(r'[,\s]+', ph.group(2))
                                  if d.strip()],
                )
                continue

            if current_pairing is None:
                continue

            # Flight segment
            fm = self.RE_FLIGHT.search(stripped)
            if fm:
                is_dh = bool(fm.group(1))
                seg = RawSegment(
                    raw_text=stripped,
                    flight_number=f"{fm.group(2)}{fm.group(3)}",
                    origin=fm.group(4).upper(),
                    destination=fm.group(5).upper(),
                    departure_str=fm.group(6),
                    arrival_str=fm.group(7),
                    block_str=fm.group(8),
                    is_deadhead=is_dh,
                    line_number=line_num,
                )
                current_pairing.segments.append(seg)
                continue

            # Report time
            rt = self.RE_REPORT_TIME.search(stripped)
            if rt:
                current_pairing.report_str = rt.group(1)

            # Release time
            rls = self.RE_RELEASE_TIME.search(stripped)
            if rls:
                current_pairing.release_str = rls.group(1)

            # Block/Duty totals
            blk = self.RE_BLOCK_LINE.search(stripped)
            if blk:
                current_pairing.block_str = blk.group(1)
                current_pairing.duty_str  = blk.group(2)

            # Rest
            rst = self.RE_REST_LINE.search(stripped)
            if rst:
                current_pairing.rest_str = rst.group(1)

            # Off days
            off = self.RE_OFF_DAYS.search(stripped)
            if off and current_line:
                days = [d.strip() for d in re.split(r'[,\s]+', off.group(1))
                        if d.strip()]
                current_line.off_days.extend(days)

        # Flush last items
        if current_pairing and current_line:
            current_line.pairings.append(current_pairing)
        if current_line:
            lines.append(current_line)

        if not lines:
            warnings.append("No LINE headers found — PDF format may differ")

        return lines
