"""
Knowledge Engine — AI Assistant
"Ask Operations AI" — answers crew questions using ONLY the retrieved
knowledge base context. Never answers from general training knowledge
for operational/regulatory questions — this prevents hallucinated rules.
"""
from __future__ import annotations
import logging
import os

from .models import AIAnswer, Citation, RetrievedChunk, DocumentCategory
from .retrieval_service import RetrievalService

logger = logging.getLogger("cip.knowledge_engine.ai_assistant")

SYSTEM_PROMPT = """You are Najm's Operations AI assistant for Saudi Airlines cabin crew. \
You answer questions about scheduling, trades, legality, fatigue, and company policy \
using ONLY the provided source excerpts below. 

CRITICAL RULES:
- If the provided excerpts do not contain enough information to answer confidently, \
say so clearly and suggest the crew member consult their supervisor or the full manual. \
NEVER invent or guess at rules, numbers, or policies not present in the excerpts.
- Always be precise with numbers (rest hours, FDP limits, etc.) — quote them exactly \
as they appear in the source.
- Keep answers concise and practical for a crew member reading on a phone.
- Do not mention "excerpts," "context," or "documents provided" — answer naturally \
as if you simply know this from company policy.
- Write only in English."""


class OperationalAIAssistant:

    def __init__(self):
        self._retrieval = RetrievalService()

    async def ask(
        self,
        query: str,
        category_filter: DocumentCategory | None = None,
    ) -> AIAnswer:
        chunks = await self._retrieval.retrieve(
            query, top_k=8, category_filter=category_filter)

        if not chunks:
            return AIAnswer(
                answer_text=(
                    "I couldn't find specific information about this in the "
                    "current knowledge base. Please check with your supervisor "
                    "or refer to the relevant manual directly."
                ),
                citations=[],
                confidence="LOW",
                query=query,
            )

        context_text = self._build_context(chunks)
        answer_text, confidence = await self._generate_answer(query, context_text)
        citations = self._build_citations(chunks)

        return AIAnswer(
            answer_text=answer_text,
            citations=citations,
            confidence=confidence,
            query=query,
        )

    def _build_context(self, chunks: list[RetrievedChunk]) -> str:
        parts = []
        for i, rc in enumerate(chunks, start=1):
            label = f"[Source {i}: {rc.document_name} Rev {rc.version_number}"
            if rc.chunk.section_label:
                label += f", Section {rc.chunk.section_label}"
            if rc.chunk.page_number:
                label += f", Page {rc.chunk.page_number}"
            label += "]"
            parts.append(f"{label}\n{rc.chunk.text}")
        return "\n\n---\n\n".join(parts)

    async def _generate_answer(
        self, query: str, context: str
    ) -> tuple[str, str]:
        try:
            import anthropic
            client = anthropic.Anthropic(
                api_key=os.environ.get("ANTHROPIC_API_KEY"))

            message = client.messages.create(
                model="claude-sonnet-4-5",
                max_tokens=1024,
                system=SYSTEM_PROMPT,
                messages=[{
                    "role": "user",
                    "content": (
                        f"Source excerpts:\n\n{context}\n\n"
                        f"Crew member's question: {query}"
                    ),
                }],
            )
            answer = message.content[0].text.strip()

            uncertain_markers = [
                "i couldn't find", "not enough information",
                "consult your supervisor", "i'm not certain",
                "doesn't contain", "unclear",
            ]
            confidence = "LOW" if any(
                m in answer.lower() for m in uncertain_markers) else "HIGH"

            return answer, confidence

        except Exception as e:
            logger.error(f"AI answer generation failed: {e}")
            return (
                "I'm having trouble generating an answer right now. "
                "Please try again or consult the relevant manual directly.",
                "LOW",
            )

    def _build_citations(self, chunks: list[RetrievedChunk]) -> list[Citation]:
        seen = set()
        citations: list[Citation] = []

        for rc in chunks:
            key = (rc.document_name, rc.version_number, rc.chunk.section_label,
                  rc.chunk.page_number)
            if key in seen:
                continue
            seen.add(key)

            citations.append(Citation(
                document_name=rc.document_name,
                version_label=f"Rev {rc.version_number}",
                section=rc.chunk.section_label,
                page=rc.chunk.page_number,
            ))

        return citations[:4]
