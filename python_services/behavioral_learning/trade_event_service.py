"""
Behavioral Learning — Trade Event Service
Records trade outcomes and triggers profile updates.
"""
from __future__ import annotations
import logging
from typing import Optional
from preference_engine.models import TradeOutcome
from preference_engine.profile_service import ProfileService

logger = logging.getLogger("cip.behavioral_learning")
_profile_svc = ProfileService()


class TradeEventService:
    """
    Single entry point for recording all trade-related user actions.
    Called from trade_engine and the API layer — never from the UI directly.
    """

    async def on_trade_viewed(self, user_id: str, trade_id: str,
                               trade_data: dict) -> None:
        await _profile_svc.record_event(
            user_id, trade_id, TradeOutcome.VIEWED, trade_data)

    async def on_trade_initiated(self, user_id: str, trade_id: str,
                                  trade_data: dict) -> None:
        """User posted or responded to a trade — strong positive signal."""
        await _profile_svc.record_event(
            user_id, trade_id, TradeOutcome.ACCEPTED, trade_data)

    async def on_trade_accepted(self, user_id: str, trade_id: str,
                                 trade_data: dict) -> None:
        await _profile_svc.record_event(
            user_id, trade_id, TradeOutcome.ACCEPTED, trade_data)

    async def on_trade_rejected(self, user_id: str, trade_id: str,
                                 trade_data: dict) -> None:
        await _profile_svc.record_event(
            user_id, trade_id, TradeOutcome.REJECTED, trade_data)

    async def on_trade_expired(self, user_id: str, trade_id: str,
                                trade_data: dict) -> None:
        """Trade expired without action — mild negative signal."""
        await _profile_svc.record_event(
            user_id, trade_id, TradeOutcome.EXPIRED, trade_data)

    async def record_event_raw(self, user_id: str, trade_id: str,
                                outcome: TradeOutcome, trade_data: dict) -> None:
        """Record an outcome the caller has already resolved to a
        TradeOutcome (the /events API route validates req.outcome before
        calling this) — used when the outcome isn't known ahead of time."""
        await _profile_svc.record_event(user_id, trade_id, outcome, trade_data)

    async def get_profile(self, user_id: str):
        return await _profile_svc.get_profile(user_id)

    async def rebuild_profile(self, user_id: str):
        return await _profile_svc.rebuild_profile(user_id)
