"""
Behavioral Learning — Record Event Helper
Bridges the existing trade_intel engine with the new preference system.
Call these functions from trade_intel/engine.py after trade state changes.
"""
from __future__ import annotations
import asyncio
import logging
from typing import Optional

logger = logging.getLogger("cip.behavioral_learning")


def _extract_trade_data(trade_doc: dict) -> dict:
    """
    Map an existing Firestore trade document to the behavioral event format.
    Works with the current flightLines / trades schema.
    """
    legs = trade_doc.get("legs", [])
    origins      = [l.get("origin",      "") for l in legs if l.get("origin")]
    destinations = [l.get("destination", "") for l in legs if l.get("destination")]
    all_airports = list(dict.fromkeys(origins + destinations))

    # Build route key: first-origin → last-destination (or round-trip)
    if origins and destinations:
        if origins[0] == destinations[-1]:
            route_key = f"{origins[0]}-{destinations[0]}-{destinations[-1]}"
        else:
            route_key = f"{origins[0]}-{destinations[-1]}"
    else:
        route_key = trade_doc.get("routeKey", "UNK-UNK")

    return {
        "route_key":        route_key,
        "destinations":     all_airports,
        "block_hours":      float(trade_doc.get("totalBlockHours",  0)),
        "duty_hours":       float(trade_doc.get("totalDutyHours",   0)),
        "fatigue_score":    float(trade_doc.get("fatigueScore",     0.5)),
        "is_international": bool( trade_doc.get("isInternational",  False)),
        "has_deadhead":     bool( trade_doc.get("hasDeadhead",      False)),
        "signin_hour":      int(  trade_doc.get("signinHour",       8)),
        "layover_hours":    float(trade_doc.get("layoverHours",     0)),
        "rest_after_hours": float(trade_doc.get("restAfterHours",   11)),
    }


async def record_trade_viewed(user_id: str, trade_id: str, trade_doc: dict) -> None:
    try:
        from preference_engine.profile_service import ProfileService
        from preference_engine.models import TradeOutcome
        svc  = ProfileService()
        data = _extract_trade_data(trade_doc)
        await svc.record_event(user_id, trade_id, TradeOutcome.VIEWED, data)
    except Exception as e:
        logger.debug(f"record_trade_viewed silenced: {e}")


async def record_trade_accepted(user_id: str, trade_id: str, trade_doc: dict) -> None:
    try:
        from preference_engine.profile_service import ProfileService
        from preference_engine.models import TradeOutcome
        svc  = ProfileService()
        data = _extract_trade_data(trade_doc)
        await svc.record_event(user_id, trade_id, TradeOutcome.ACCEPTED, data)
    except Exception as e:
        logger.debug(f"record_trade_accepted silenced: {e}")


async def record_trade_rejected(user_id: str, trade_id: str, trade_doc: dict) -> None:
    try:
        from preference_engine.profile_service import ProfileService
        from preference_engine.models import TradeOutcome
        svc  = ProfileService()
        data = _extract_trade_data(trade_doc)
        await svc.record_event(user_id, trade_id, TradeOutcome.REJECTED, data)
    except Exception as e:
        logger.debug(f"record_trade_rejected silenced: {e}")


def fire_and_forget(coro) -> None:
    """
    Schedule a coroutine without awaiting it.
    Use from synchronous trade_intel code to trigger async preference updates.
    """
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            loop.create_task(coro)
        else:
            loop.run_until_complete(coro)
    except Exception as e:
        logger.debug(f"fire_and_forget silenced: {e}")
