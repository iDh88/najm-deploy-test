"""Layover content-filter tests (F25/F37).

Twin of flutter_app/test/unit/content_filter_test.dart — the two suites
assert the SAME fixture strings so the client and server filters cannot
drift apart silently. If you change a fixture here, change it there.

Locks the word-boundary regression: the pre-remediation substring filter
blocked "Barcelona" (⊃ "bar"), "Public transport" (⊃ "pub") and
"clubhouse" (⊃ "club").
"""
from __future__ import annotations

import pytest

from layover.router import (
    BLOCKED_KEYWORDS,
    blocked_terms,
    is_content_allowed,
)


# ── Real matches must still block ────────────────────────────────────────────

@pytest.mark.parametrize("text", [
    "great sports BAR downtown",
    "Wine tasting tour",
    "the casino floor",
    "best Nightclub in town",
    "a hookah bar near the hotel",
    "shisha bar rooftop",
    "bar",
    "beer.",
    "Vodka",
    "wine-tasting evening",   # hyphen is a boundary — full word still hits
    "(bar)",
])
def test_blocked_content_is_blocked(text):
    assert not is_content_allowed(text)


# ── Word-boundary false-positive regression ─────────────────────────────────

@pytest.mark.parametrize("text", [
    "Barcelona tapas walk",       # ⊃ bar
    "Public transport tips",      # ⊃ pub
    "clubhouse sandwich cafe",    # ⊃ club
    "rebar art installation",     # ⊃ bar (suffix position)
    "scuba diving trip",          # clean control sample
    "barbershop quartet",         # ⊃ bar (prefix position)
    "winesap apple orchard",      # ⊃ wine
])
def test_substring_only_occurrences_are_allowed(text):
    assert is_content_allowed(text), f"false positive on: {text!r}"


def test_clean_multifield_content_reports_no_terms():
    combined = "\n".join([
        "Al Baik",
        "Legendary fried chicken, halal, near the corniche",
        "restaurants",
        "crew favourite after Barcelona layovers",
    ])
    assert blocked_terms(combined) == []


def test_hits_are_reported_once_per_keyword():
    combined = "\n".join(["Beer garden", "craft beer and wine", "restaurants"])
    hits = blocked_terms(combined)
    assert "beer" in hits and "wine" in hits
    assert hits.count("beer") == 1


# ── Keyword-list contract (mirrors the Dart contract test) ──────────────────

def test_keyword_list_is_nonempty_lowercase_unique():
    assert BLOCKED_KEYWORDS
    assert all(kw == kw.lower() for kw in BLOCKED_KEYWORDS)
    assert len(set(BLOCKED_KEYWORDS)) == len(BLOCKED_KEYWORDS)


def test_keyword_list_matches_flutter_mirror():
    """The Dart file duplicates this list; pin the exact contents so a
    one-sided edit fails a test instead of silently diverging. (Parsing the
    Dart source at test time was rejected as brittle; an explicit pinned
    copy makes the drift visible in the diff of whichever side changed.)"""
    assert BLOCKED_KEYWORDS == [
        "bar", "bars", "club", "clubs", "nightclub", "nightclubs",
        "pub", "pubs", "alcohol", "alcoholic", "beer", "wine", "liquor",
        "cocktail", "cocktails", "whiskey", "vodka", "spirits", "brewery",
        "winery", "casino", "gambling", "hookah bar", "shisha bar",
    ]
