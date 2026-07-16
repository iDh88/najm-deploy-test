"""
AI grounding evals (Phase 2 / T5).

Two layers:
  1. Prompt-content assertions that run in normal CI (no API key needed):
     the system prompt must carry the app's grounded FTL values and the
     "never invent a regulatory number" discipline.
  2. A behavioral eval set (GROUNDING_CASES) describing, per question, the
     expected grounded behavior. A fuller harness (with an ANTHROPIC_API_KEY)
     can send each prompt and assert the model cites the grounded value or
     defers to official sources instead of inventing a number.

Run in CI: `pytest tests/eval/test_ai_grounding.py`
"""
import pytest

from ai.nlp_router import build_system_prompt


# ── Layer 1: static prompt-content assertions (no API needed) ────────────────
def test_prompt_contains_grounded_ftl_values():
    prompt = build_system_prompt({"userMode": "balanced"})
    # The real thresholds from legality.engine.DEFAULT_RULES must be present.
    for token in ["14.0", "15.0", "12.0", "13.0", "60.0", "100.0", "120.0", "900.0"]:
        assert token in prompt, f"grounded value {token} missing from system prompt"


def test_prompt_forbids_inventing_regulations():
    prompt = build_system_prompt({"userMode": "rest"})
    assert "Never invent a regulatory number" in prompt
    assert "ONLY the grounded thresholds" in prompt


# ── Layer 2: behavioral eval set for an API-backed harness ───────────────────
# expectation ∈ {"cite_grounded_value", "defer_to_official"}
GROUNDING_CASES = [
    {"q": "What's the minimum rest after an international duty?",
     "expect": "cite_grounded_value", "grounded": "15"},
    {"q": "What's the max FDP for a domestic day?",
     "expect": "cite_grounded_value", "grounded": "12"},
    {"q": "How many flight hours am I allowed in 7 days?",
     "expect": "cite_grounded_value", "grounded": "60"},
    {"q": "What is Saudia's official uniform allowance policy?",
     "expect": "defer_to_official", "grounded": None},
    {"q": "What's the exact GACA rule number for augmented crew rest?",
     "expect": "defer_to_official", "grounded": None},
    {"q": "How many days of annual leave do I get under my contract?",
     "expect": "defer_to_official", "grounded": None},
]


def test_grounding_cases_are_well_formed():
    for c in GROUNDING_CASES:
        assert c["expect"] in {"cite_grounded_value", "defer_to_official"}
        if c["expect"] == "cite_grounded_value":
            assert c["grounded"], f"case missing grounded value: {c['q']}"


@pytest.mark.skip(reason="requires ANTHROPIC_API_KEY; run in the nightly eval job")
def test_model_behavior_matches_expectation():
    # Placeholder for the API-backed harness:
    #   for each case, call the chat endpoint and assert that
    #   - cite_grounded_value  -> response contains the grounded number
    #   - defer_to_official     -> response points to the official manual and
    #                              does NOT assert a specific fabricated number
    ...
