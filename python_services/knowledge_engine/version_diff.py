"""
Knowledge Engine — Version Diff
Compares two document versions and generates a Document Change Summary,
flagging rule/legality/fatigue changes specifically.
"""
from __future__ import annotations
import logging
import os
from datetime import datetime

from .models import DocumentChangeSummary, ChangeSummaryItem

logger = logging.getLogger("cip.knowledge_engine.version_diff")

CHANGE_CATEGORIES = ["rule_change", "legality_change", "fatigue_change", "general"]

DIFF_SYSTEM_PROMPT = """You are an aviation document change analyst for Saudi Airlines' \
operations team. You will be given the OLD and NEW text of an operational document. \
Identify meaningful changes only — ignore formatting, pagination, or trivial rewording.

For each meaningful change, classify it as one of:
- rule_change: a numeric limit, procedure, or policy changed
- legality_change: anything affecting flight/duty time, rest, or regulatory compliance
- fatigue_change: anything affecting fatigue risk management
- general: any other substantive content change

Respond ONLY with a JSON array of objects, each with:
{"category": "...", "description": "...", "old_text": "...", "new_text": "...", "section": "..."}

If there are no meaningful changes, respond with an empty array: []
Do not include any text outside the JSON array."""


class VersionDiffEngine:

    async def compare(
        self,
        document_name: str,
        old_text: str,
        new_text: str,
        old_version_number: int,
        new_version_number: int,
        document_id: str,
        old_version_id: str,
        new_version_id: str,
    ) -> DocumentChangeSummary:
        """
        Compares old vs new extracted text and generates a structured
        change summary using Claude.
        """
        items = await self._diff_with_ai(document_name, old_text, new_text)

        overall = self._build_overall_summary(document_name, items,
                                               old_version_number,
                                               new_version_number)

        return DocumentChangeSummary(
            document_id=document_id,
            old_version_id=old_version_id,
            new_version_id=new_version_id,
            old_version_number=old_version_number,
            new_version_number=new_version_number,
            generated_at=datetime.utcnow(),
            items=items,
            overall_summary=overall,
        )

    async def _diff_with_ai(
        self, document_name: str, old_text: str, new_text: str
    ) -> list[ChangeSummaryItem]:
        max_chars = 40_000
        old_trunc = old_text[:max_chars]
        new_trunc = new_text[:max_chars]
        if len(old_text) > max_chars or len(new_text) > max_chars:
            logger.warning(
                f"{document_name}: text truncated for diff "
                f"(old={len(old_text)}, new={len(new_text)} chars)")

        try:
            import anthropic
            client = anthropic.Anthropic(
                api_key=os.environ.get("ANTHROPIC_API_KEY"))

            message = client.messages.create(
                model="claude-sonnet-4-5",
                max_tokens=4000,
                system=DIFF_SYSTEM_PROMPT,
                messages=[{
                    "role": "user",
                    "content": (
                        f"Document: {document_name}\n\n"
                        f"=== OLD VERSION ===\n{old_trunc}\n\n"
                        f"=== NEW VERSION ===\n{new_trunc}"
                    ),
                }],
            )

            response_text = message.content[0].text.strip()
            return self._parse_diff_response(response_text)

        except Exception as e:
            logger.error(f"AI diff failed for {document_name}: {e}")
            return [ChangeSummaryItem(
                category="general",
                description=(
                    "Automatic change detection failed. "
                    "Please review both versions manually."
                ),
            )]

    def _parse_diff_response(self, response_text: str) -> list[ChangeSummaryItem]:
        import json
        import re

        cleaned = re.sub(r'^```json\s*|\s*```$', '', response_text.strip())

        try:
            raw_items = json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning(f"Could not parse diff JSON: {response_text[:200]}")
            return []

        items: list[ChangeSummaryItem] = []
        for raw in raw_items:
            category = raw.get("category", "general")
            if category not in CHANGE_CATEGORIES:
                category = "general"
            items.append(ChangeSummaryItem(
                category=category,
                description=raw.get("description", ""),
                old_text=raw.get("old_text"),
                new_text=raw.get("new_text"),
                section=raw.get("section"),
            ))
        return items

    def _build_overall_summary(
        self,
        document_name: str,
        items: list[ChangeSummaryItem],
        old_v: int,
        new_v: int,
    ) -> str:
        if not items:
            return (
                f"{document_name} Rev {new_v} contains no substantive "
                f"changes from Rev {old_v}."
            )

        rule_count    = sum(1 for i in items if i.category == "rule_change")
        legal_count   = sum(1 for i in items if i.category == "legality_change")
        fatigue_count = sum(1 for i in items if i.category == "fatigue_change")

        parts = [f"{document_name} updated from Rev {old_v} to Rev {new_v}."]
        if rule_count:
            parts.append(f"{rule_count} rule change(s) detected.")
        if legal_count:
            parts.append(f"{legal_count} legality-related change(s) detected.")
        if fatigue_count:
            parts.append(f"{fatigue_count} fatigue-related change(s) detected.")
        if not (rule_count or legal_count or fatigue_count):
            parts.append(f"{len(items)} general content change(s) detected.")

        return " ".join(parts)
