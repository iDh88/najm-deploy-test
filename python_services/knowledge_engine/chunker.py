"""
Knowledge Engine — Chunker
Splits extracted page text into overlapping chunks suitable for embedding.
Preserves page/section metadata on every chunk for accurate citations.
"""
from __future__ import annotations
import re
from dataclasses import dataclass

from .extractors import ExtractionResult, ExtractedPage

CHUNK_TARGET_CHARS  = 1800     # ~450 tokens
CHUNK_OVERLAP_CHARS = 250
MIN_CHUNK_CHARS     = 100      # discard fragments smaller than this


@dataclass
class RawChunk:
    text:          str
    page_number:   int | None
    section_label: str | None
    char_start:    int
    char_end:      int


def chunk_extraction(result: ExtractionResult) -> list[RawChunk]:
    """
    Chunk every page independently so page/section metadata stays accurate.
    Long pages are split with overlap; short pages may be merged with
    the next one up to the target size.
    """
    chunks: list[RawChunk] = []
    buffer_text = ""
    buffer_page = None
    buffer_section = None
    buffer_start = 0

    for page in result.pages:
        text = _normalize(page.text)
        if not text:
            continue

        if not buffer_text:
            buffer_page = page.page_number
            buffer_section = page.section_label
            buffer_start = 0

        buffer_text += ("\n\n" if buffer_text else "") + text

        while len(buffer_text) >= CHUNK_TARGET_CHARS:
            piece = buffer_text[:CHUNK_TARGET_CHARS]
            cut = _find_break_point(piece)
            chunk_text = buffer_text[:cut].strip()

            if len(chunk_text) >= MIN_CHUNK_CHARS:
                chunks.append(RawChunk(
                    text=chunk_text,
                    page_number=buffer_page,
                    section_label=buffer_section,
                    char_start=buffer_start,
                    char_end=buffer_start + cut,
                ))

            advance = max(cut - CHUNK_OVERLAP_CHARS, 1)
            buffer_text = buffer_text[advance:]
            buffer_start += advance
            buffer_page = page.page_number

    tail = buffer_text.strip()
    if len(tail) >= MIN_CHUNK_CHARS:
        chunks.append(RawChunk(
            text=tail,
            page_number=buffer_page,
            section_label=buffer_section,
            char_start=buffer_start,
            char_end=buffer_start + len(tail),
        ))

    return chunks


def _normalize(text: str) -> str:
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _find_break_point(piece: str) -> int:
    """
    Find a clean break point near the end of `piece`, preferring
    paragraph breaks, then sentence ends, then falling back to the
    full length.
    """
    search_zone_start = max(0, len(piece) - 300)
    search_zone = piece[search_zone_start:]

    para_idx = search_zone.rfind("\n\n")
    if para_idx != -1:
        return search_zone_start + para_idx + 2

    sentence_idx = max(
        search_zone.rfind(". "),
        search_zone.rfind(".\n"),
    )
    if sentence_idx != -1:
        return search_zone_start + sentence_idx + 2

    return len(piece)
