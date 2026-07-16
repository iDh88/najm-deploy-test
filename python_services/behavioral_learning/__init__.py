"""
Behavioral Learning
Records trade events and triggers incremental preference profile updates.
"""
from .trade_event_service import TradeEventService
from .record_event_helper import (
    record_trade_viewed,
    record_trade_accepted,
    record_trade_rejected,
    fire_and_forget,
)
__all__ = [
    "TradeEventService",
    "record_trade_viewed", "record_trade_accepted",
    "record_trade_rejected", "fire_and_forget",
]
