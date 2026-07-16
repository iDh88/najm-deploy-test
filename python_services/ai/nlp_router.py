"""
AI NLP Router — Najm Assistant
Routes natural language queries to the appropriate handler.
Uses Claude API (claude-sonnet-4-20250514) for all generative tasks.
"""

import os
import json
import logging
import time
from typing import Optional, Any
from datetime import datetime

import anthropic
from fastapi import APIRouter, HTTPException, Depends
from utils.auth import verify_service_or_user, resolve_user_id
from utils.firebase import get_firestore
from firebase_admin import firestore
try:
    from legality.engine import DEFAULT_RULES as _FTL
except Exception:  # pragma: no cover — keep chat working if legality import fails
    _FTL = None
from pydantic import BaseModel
from ai.glm_client import glm_chat

logger = logging.getLogger("cip.ai")
router = APIRouter()

# ─── Claude Client ────────────────────────────────────────────────────────────

_client: Optional[anthropic.Anthropic] = None

# Single source of truth for the deployed model id. Was inlined at three
# call sites; the Profile "AI Status" card reports THIS value, so a model
# upgrade can never leave the UI advertising a stale version.
CLAUDE_MODEL = "claude-sonnet-4-20250514"


def ai_provider() -> str:
    return os.getenv("AI_PROVIDER", "anthropic").strip().lower()


def get_claude_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic()  # Uses ANTHROPIC_API_KEY env var
    return _client

# ─── Intent Types ─────────────────────────────────────────────────────────────

INTENT_TYPES = ["filter", "calculation", "comparison", "legality", "recommendation", "general"]

# ─── Pydantic Models ─────────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str      # "user" | "assistant"
    content: str

class ChatRequest(BaseModel):
    user_id: str
    message: str
    history: list[ChatMessage] = []
    context: dict = {}  # { userMode, activeMonth, userBase, activeBidCount }

class RichContent(BaseModel):
    line_card: Optional[dict] = None
    legality_card: Optional[dict] = None
    # Registry-validated clauses for POST /v1/lines/search (filter_engine.v1)
    filter_query: Optional[dict] = None
    filter_result: Optional[dict] = None

class ChatResponse(BaseModel):
    text: str
    intent_type: str
    rich_content: RichContent = RichContent()
    response_time_ms: int
    tokens_used: int = 0

class FilterResponse(BaseModel):
    destinations: list[str] = []
    no_days_of_week: list[int] = []       # 0=Sun ... 6=Sat (KSA week)
    max_duty_hours: Optional[float] = None
    min_rest_hours: Optional[float] = None
    min_layover_hours: Optional[float] = None
    requires_layover: Optional[bool] = None
    max_legs: Optional[int] = None
    origins: list[str] = []
    max_salary: Optional[float] = None
    min_salary: Optional[float] = None
    leg_types: list[str] = []             # ["domestic", "international"]

# ─── System Prompts ───────────────────────────────────────────────────────────

def _ftl_grounding_block() -> str:
    """Inject the app's ACTUAL FTL thresholds so the model grounds regulatory
    answers in the same source of truth the legality engine uses, rather than
    reciting numbers from memory (a safety risk).

    Resolution order (P0-2 fix — admin overrides must reach the AI too):
      1. Live effective rules (canonical defaults + Firestore ``legalityRules``
         admin overrides, TTL-cached) via ``FTLRules.effective()``.
      2. Static import-time DEFAULT_RULES (``_FTL``) if the live path fails.
      3. Explicit "don't state numbers" instruction if both fail.
    """
    r = None
    version = None
    try:
        from legality.engine import FTLRules
        r = FTLRules.effective()
        try:
            from legality.rules_source import get_effective_rules
            version = get_effective_rules().version
        except Exception:  # pragma: no cover — version stamp is best-effort
            version = None
    except Exception:  # pragma: no cover — fall back to import-time snapshot
        r = _FTL
    if r is None:
        return "(FTL rule values unavailable — do NOT state specific regulatory numbers.)"
    header = "GROUNDED FTL THRESHOLDS (the app's configured rules — use THESE exact numbers"
    header += f"; source: {version}):\n" if version else "):\n"
    return header + (
        f"- Min rest: {r.min_rest_domestic_hours}h domestic / {r.min_rest_international_hours}h international\n"
        f"- Max FDP: {r.max_fdp_domestic_hours}h domestic / {r.max_fdp_international_hours}h intl / {r.max_fdp_augmented_hours}h augmented\n"
        f"- Max daily block: {r.max_daily_block_hours}h\n"
        f"- Sectors per FDP: {r.max_sectors_short_haul} short-haul / {r.max_sectors_long_haul} long-haul\n"
        f"- Cumulative: {r.max_7day_flight_hours}h/7d, {r.max_28day_flight_hours}h/28d, "
        f"{r.max_monthly_duty_hours}h duty/month, {r.max_annual_flight_hours}h/year\n"
        f"- Min layover away from base: {r.min_layover_away_from_base_hours}h"
    )


def build_system_prompt(context: dict) -> str:
    user_mode = context.get("userMode", "balanced")
    month = context.get("activeMonth", "this month")
    base = context.get("userBase", "RUH")

    return f"""You are Najm (نجم), an intelligent scheduling assistant for Saudi Airlines cabin crew.
You are running inside the Crew Intelligence Platform (CIP) — an unofficial crew scheduling assistant.

CURRENT USER CONTEXT:
- Optimization Mode: {user_mode} ({'prioritizing salary' if user_mode == 'money' else 'prioritizing rest' if user_mode == 'rest' else 'balancing salary and rest'})
- Active Month: {month}
- Base Station: {base}

YOUR CAPABILITIES:
1. FILTER: Parse natural language schedule filters into structured JSON
2. CALCULATION: Compute flight hours, rest periods, salary estimates from schedule data
3. COMPARISON: Compare multiple flight lines across salary, rest, destinations
4. LEGALITY: Explain legality checks, rest rules, FTL regulations in plain language
5. RECOMMENDATION: Suggest which lines to bid, which trades to make

YOUR COMMUNICATION STYLE:
- Respond in the SAME LANGUAGE as the user's message (Arabic or English)
- For Arabic responses: use Modern Standard Arabic, right-to-left friendly phrasing
- Be concise, warm, and professional — like a knowledgeable colleague
- Always provide a specific reason grounded in the user's data
- Use aviation crew terminology naturally (FDP, layover, release time, block hours)
- NEVER suggest anything that violates GACA rest regulations
- When you can't compute something precisely, say so clearly and explain what data you'd need

IMPORTANT LIMITS:
- You do NOT have real-time access to Saudi Airlines systems
- You only know what the user has shared with you in this conversation
- If asked about official SA policies, recommend checking official sources
- Always mention that CIP is an unofficial tool when relevant to the context

GROUNDING RULES (critical — regulatory accuracy is a safety matter):
{_ftl_grounding_block()}
- For any FTL / rest / FDP / duty-limit question, use ONLY the grounded thresholds above. Do NOT state regulatory numbers from memory.
- If a rule or official policy is NOT in the grounded list above and NOT in the user's data, say plainly you cannot confirm it and point to the official manual or Knowledge Center. Never invent a regulatory number.
- Prefer running or echoing a legality check over describing rules from memory, and cite the app's rule values as the source.

FORMATTING:
- Keep responses under 200 words unless the question genuinely requires more
- Use bullet points sparingly — prefer flowing text
- For calculations, show the formula briefly before the result
- For Arabic text, do not mix LTR/RTL inline in the same paragraph"""

FILTER_EXTRACTION_PROMPT = """You are a flight schedule filter parser for Saudi Airlines cabin crew.
Extract a structured filter from the natural language query.

AVAILABLE FILTER FIELDS:
{
  "destinations": ["list of IATA codes the user wants to fly to"],
  "origins": ["list of IATA codes the user wants to depart from"],
  "no_days_of_week": [0-6 where 0=Sunday, 1=Monday, ..., 6=Saturday — days user does NOT want duties],
  "max_duty_hours": number or null (maximum total duty hours for the month),
  "min_rest_hours": number or null (minimum rest hours required between duties),
  "min_layover_hours": number or null,
  "requires_layover": true/false/null,
  "max_legs": number or null,
  "min_salary": number or null (SAR),
  "max_salary": number or null (SAR),
  "leg_types": ["domestic", "international"] or []
}

RULES:
- Return ONLY valid JSON. No preamble, no markdown, no explanation.
- If a field is not mentioned, set it to null or empty list.
- Convert city names to IATA codes (London → LHR, Paris → CDG, etc.)
- For day references: Friday=6, Thursday=5, Wednesday=4 in KSA week (0=Sunday)
- Weekend in KSA = Friday (6) + Saturday (0... wait, 0=Sunday)
  Actually KSA week: Sunday=0, Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6
  KSA weekend = Friday(5) + Saturday(6)
- "no early flights" = no duty starting before 06:00 (cannot be expressed as filter — note this)
- Numbers like "12,000" = 12000 SAR

EXAMPLE:
Query: "Show lines with London or Paris layovers and no duties on Fridays"
Response: {"destinations": ["LHR", "CDG"], "no_days_of_week": [5], "requires_layover": true}"""

INTENT_CLASSIFICATION_PROMPT = """Classify this crew scheduling query into exactly one intent type.
Return ONLY the intent type string, nothing else.

Intent types:
- filter: User wants to filter/search flight lines by criteria
- calculation: User wants a number computed (hours, salary, rest, etc.)
- comparison: User wants to compare 2+ flight lines
- legality: User asks about rules, violations, rest requirements
- recommendation: User wants a suggestion (what to bid, which trade)
- general: General question about the app or aviation

Query: {query}
Intent:"""

# ─── Intent Classification ────────────────────────────────────────────────────

async def classify_intent(message: str) -> str:
    try:
        prompt = INTENT_CLASSIFICATION_PROMPT.format(query=message)
        if ai_provider() == "glm":
            text, _usage = await glm_chat(
                [{"role": "user", "content": prompt}],
                max_tokens=20,
                temperature=0,
            )
            intent = text.strip().lower()
        else:
            response = get_claude_client().messages.create(
                model=CLAUDE_MODEL,
                max_tokens=20,
                messages=[{"role": "user", "content": prompt}],
            )
            intent = response.content[0].text.strip().lower()
        return intent if intent in INTENT_TYPES else "general"
    except Exception as e:
        logger.warning(f"Intent classification failed: {e}")
        return "general"

# ─── Filter Intent Handler ────────────────────────────────────────────────────

async def handle_filter_intent(message: str, context: dict) -> tuple[str, dict]:
    """Extract structured filter from NL query. Returns (explanation, filter_dict)."""
    try:
        if ai_provider() == "glm":
            raw, _usage = await glm_chat(
                [
                    {"role": "system", "content": FILTER_EXTRACTION_PROMPT},
                    {"role": "user", "content": f"Query: {message}"},
                ],
                max_tokens=500,
                temperature=0,
            )
        else:
            response = get_claude_client().messages.create(
                model=CLAUDE_MODEL,
                max_tokens=500,
                messages=[
                    {"role": "user", "content": FILTER_EXTRACTION_PROMPT},
                    {"role": "user", "content": f"Query: {message}"},
                ],
            )
            raw = response.content[0].text.strip()
        # Clean any accidental markdown
        raw = raw.replace("```json", "").replace("```", "").strip()
        filter_dict = json.loads(raw)

        # Validate with Pydantic
        validated = FilterResponse(**filter_dict).model_dump(exclude_none=True)

        # Generate human-readable explanation
        parts = []
        if validated.get("destinations"):
            parts.append(f"destinations: {', '.join(validated['destinations'])}")
        if validated.get("no_days_of_week"):
            day_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            days = [day_names[d] for d in validated["no_days_of_week"]]
            parts.append(f"no duties on: {', '.join(days)}")
        if validated.get("min_salary"):
            parts.append(f"salary ≥ SAR {validated['min_salary']:,.0f}")
        if validated.get("requires_layover"):
            parts.append("requires layovers")

        explanation = f"Filtering lines by: {' · '.join(parts)}" if parts else "Showing all lines"
        return explanation, validated

    except json.JSONDecodeError:
        return "I understood your filter but couldn't parse it precisely. Try being more specific.", {}
    except Exception as e:
        logger.exception(f"Filter handler error: {e}")
        return "I had trouble parsing that filter. Could you rephrase?", {}

# ─── Conversational Handler (all other intents) ───────────────────────────────

async def handle_conversational(
    message: str,
    history: list[ChatMessage],
    context: dict,
    intent: str,
) -> tuple[str, int]:
    """Send to the configured AI provider with full system prompt and history."""
    messages = []

    # Inject conversation history (last 10 turns)
    for msg in history[-10:]:
        messages.append({"role": msg.role, "content": msg.content})

    # Add current message
    messages.append({"role": "user", "content": message})

    try:
        if ai_provider() == "glm":
            glm_messages = [{"role": "system", "content": build_system_prompt(context)}] + messages
            text, usage = await glm_chat(
                glm_messages,
                max_tokens=1000,
                temperature=float(os.getenv("AI_TEMPERATURE", "0.3")),
            )
            tokens = int(usage.get("total_tokens") or 0)
            return text, tokens

        response = get_claude_client().messages.create(
            model=CLAUDE_MODEL,
            max_tokens=1000,
            system=build_system_prompt(context),
            messages=messages,
        )
        text = response.content[0].text
        tokens = response.usage.input_tokens + response.usage.output_tokens
        return text, tokens
    except anthropic.RateLimitError:
        return "I'm handling too many requests right now. Please try again in a moment. 🌙", 0
    except anthropic.APIConnectionError:
        return "I'm having trouble connecting to my AI backend. Please check your connection.", 0
    except Exception as e:
        logger.exception(f"AI provider error: {e}")
        return "I encountered an error. Please try rephrasing your question.", 0

# ─── Main Chat Endpoint ───────────────────────────────────────────────────────

_ai_limit_cache: dict = {"value": None, "at": 0.0}
_AI_LIMIT_TTL_SECONDS = 60.0

def _ai_daily_free_limit() -> int:
    """F20 — same precedence as the Cloud Function (index.ts aiDailyFreeLimit):
    subscriptionConfig/main.aiDailyFreeLimit when set by an admin, else the
    AI_DAILY_FREE_LIMIT env var, else 50. TTL-cached; fail-safe to env."""
    import time as _time
    now = _time.monotonic()
    if _ai_limit_cache["value"] is not None and now - _ai_limit_cache["at"] < _AI_LIMIT_TTL_SECONDS:
        return _ai_limit_cache["value"]
    limit = int(os.getenv("AI_DAILY_FREE_LIMIT", "50"))
    try:
        snap = get_firestore().collection("subscriptionConfig").document("main").get()
        if snap.exists:
            raw = (snap.to_dict() or {}).get("aiDailyFreeLimit")
            if isinstance(raw, (int, float)) and raw > 0:
                limit = int(raw)
    except Exception as e:  # noqa: BLE001 — config read must never break chat
        logger.warning(f"aiDailyFreeLimit config read failed, using env fallback: {e}")
    _ai_limit_cache["value"] = limit
    _ai_limit_cache["at"] = now
    return limit

def _enforce_ai_daily_limit(user_id: str) -> None:
    """T3 — per-user daily AI cap, enforced on the path the client actually calls.
    Free allowance while subscriptions are disabled; sourced from config so it
    lines up with the Cloud Function limit. Soft limiter (read-then-increment)."""
    limit = _ai_daily_free_limit()
    db = get_firestore()
    today = datetime.utcnow().strftime("%Y-%m-%d")
    ref = db.collection("aiUsage").document(f"{user_id}_{today}")
    snap = ref.get()
    used = (snap.to_dict() or {}).get("count", 0) if snap.exists else 0
    if used >= limit:
        raise HTTPException(
            status_code=429,
            detail=f"Daily AI limit ({limit}) reached. Please try again tomorrow.",
        )
    ref.set(
        {"count": firestore.Increment(1), "updatedAt": firestore.SERVER_TIMESTAMP},
        merge=True,
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    claims: dict = Depends(verify_service_or_user),
) -> ChatResponse:
    start_time = time.time()
    # T1: pin identity to the verified token for user calls
    user_id = resolve_user_id(claims, request.user_id)
    # T3: enforce the AI daily limit here (service calls exempt — caller enforces its own)
    if not claims.get("service"):
        _enforce_ai_daily_limit(user_id)

    if not request.message.strip():
        raise HTTPException(400, "Message cannot be empty")

    if len(request.message) > 1000:
        raise HTTPException(400, "Message too long (max 1000 characters)")

    # Sanitize: strip potential prompt injection patterns
    safe_message = request.message.replace("<|", "").replace("|>", "").replace("SYSTEM:", "")

    # Classify intent
    intent = await classify_intent(safe_message)
    logger.info(f"User {user_id}: intent={intent}, message='{safe_message[:60]}...'")

    rich_content = RichContent()
    tokens_used = 0

    if intent == "filter":
        explanation, filter_dict = await handle_filter_intent(safe_message, request.context)
        # Vision golden rule: the assistant's filter answer is ALSO expressed
        # as registry clauses (filter_engine), pre-validated, so the client
        # can hand them straight to POST /v1/lines/search. Legacy
        # `filter_result` stays for existing consumers.
        try:
            from filter_engine.ai_bridge import from_filter_response
            from filter_engine.schema import validate_clause
            bridged = from_filter_response(filter_dict)
            valid_clauses, rejected = [], list(bridged.unmapped)
            for cl in bridged.clauses:
                try:
                    validate_clause(cl)
                    valid_clauses.append(cl.model_dump())
                except Exception as _exc:  # noqa: BLE001 — reported, not fatal
                    rejected.append({"clause": cl.model_dump(),
                                     "reason": str(_exc)})
            rich_content.filter_query = {
                "clauses": valid_clauses,
                "rejected": rejected,
                "engine": "filter_engine.v1",
            }
        except Exception:
            logger.exception("filter_query bridging failed — legacy "
                             "filter_result still returned")
        response_text = explanation
        rich_content.filter_result = filter_dict
    else:
        response_text, tokens_used = await handle_conversational(
            safe_message, request.history, request.context, intent
        )

    response_time_ms = int((time.time() - start_time) * 1000)
    logger.info(f"Response: {response_time_ms}ms, {tokens_used} tokens, intent={intent}")

    return ChatResponse(
        text=response_text,
        intent_type=intent,
        rich_content=rich_content,
        response_time_ms=response_time_ms,
        tokens_used=tokens_used,
    )

# ─── Suggestion Prompts Endpoint ──────────────────────────────────────────────

@router.get("/suggestions")
async def get_suggestions(user_mode: str = "balanced", locale: str = "ar") -> dict:
    """Return contextual suggested prompts for the AI assistant welcome screen."""
    suggestions_by_mode = {
        "money": [
            ("💰", "أي خط فيه أعلى راتب هذا الشهر؟", "Which line has the highest salary this month?"),
            ("✈️", "أرني الخطوط الدولية بأعلى بدل إقامة", "Show international lines with highest per diem"),
            ("📊", "احسب راتبي التقديري للخط 411", "Calculate my estimated salary for Line 411"),
        ],
        "rest": [
            ("😴", "أرني خطوط بدون رحلات في الجمعة والسبت", "Lines with no duties on Fri/Sat"),
            ("⏰", "أي خط فيه أكبر فترة راحة؟", "Which line has the longest rest periods?"),
            ("🏠", "خطوط تعود فيها للبيت كل يوم", "Lines where I return home daily"),
        ],
        "balanced": [
            ("⭐", "ما هو أفضل خط لي هذا الشهر؟", "What's the best line for me this month?"),
            ("🔍", "أرني خطوط بتوقف في لندن أو باريس", "Show lines with London or Paris layovers"),
            ("⚖️", "قارن بين الخط 208 والخط 317", "Compare Line 208 vs Line 317"),
            ("⚠️", "هل الخط 411 قانوني بالنسبة لي؟", "Is Line 411 legal for my current hours?"),
        ],
    }

    suggestions = suggestions_by_mode.get(user_mode, suggestions_by_mode["balanced"])
    return {
        "suggestions": [
            {"emoji": s[0], "ar": s[1], "en": s[2]} for s in suggestions
        ]
    }
