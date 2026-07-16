"""Raw extraction models — output of the PDF parser before normalization."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class ExtractionQuality(str, Enum):
    HIGH   = "HIGH"    # digital PDF, clean extraction
    MEDIUM = "MEDIUM"  # some reconstruction needed
    LOW    = "LOW"     # OCR fallback used


@dataclass
class RawSegment:
    """One row from the PDF representing a flight or deadhead leg."""
    raw_text:        str
    flight_number:   Optional[str]  = None
    origin:          Optional[str]  = None
    destination:     Optional[str]  = None
    departure_str:   Optional[str]  = None   # raw time string e.g. "1430Z"
    arrival_str:     Optional[str]  = None
    block_str:       Optional[str]  = None   # e.g. "1:45"
    is_deadhead:     bool           = False
    aircraft_type:   Optional[str]  = None
    line_number:     int            = 0      # PDF line number for debugging


@dataclass
class RawPairing:
    """A pairing block as extracted directly from the PDF."""
    raw_text:       str
    pairing_id:     Optional[str]         = None   # e.g. "PA4421"
    date_strings:   list[str]             = field(default_factory=list)
    segments:       list[RawSegment]      = field(default_factory=list)
    report_str:     Optional[str]         = None
    release_str:    Optional[str]         = None
    block_str:      Optional[str]         = None
    duty_str:       Optional[str]         = None
    credit_str:     Optional[str]         = None
    rest_str:       Optional[str]         = None
    hotel_info:     Optional[str]         = None


@dataclass
class RawLine:
    """A complete monthly line as extracted from the PDF."""
    raw_text:         str
    line_number:      Optional[str]        = None   # e.g. "001"
    base:             Optional[str]        = None   # e.g. "RUH"
    period_str:       Optional[str]        = None   # e.g. "JUN2026"
    rank:             Optional[str]        = None
    pairings:         list[RawPairing]     = field(default_factory=list)
    carry_over_str:   Optional[str]        = None
    total_block_str:  Optional[str]        = None
    off_days:         list[str]            = field(default_factory=list)
    open_days:        list[str]            = field(default_factory=list)


@dataclass
class ExtractionResult:
    """Full result of a PDF extraction pass."""
    lines:            list[RawLine]
    quality:          ExtractionQuality
    extractor_used:   str                  # "pdfplumber" | "pymupdf" | "ocr"
    page_count:       int
    errors:           list[str]            = field(default_factory=list)
    warnings:         list[str]            = field(default_factory=list)
