"""Offline pytz shim over stdlib zoneinfo (Python ≥3.9).

Faithful to the real-pytz surface this codebase uses: `pytz.UTC` /
`pytz.utc`, `pytz.timezone(name)`, and — critically — `.localize(naive_dt)` /
`.normalize(aware_dt)` on the returned zone objects (rest_engine/
timezone_utils.py calls .localize on every naive input; an earlier shim
without it silently diverged from production behavior).
"""
from __future__ import annotations
from datetime import datetime, timezone as _stdtz, tzinfo as _tzinfo
from zoneinfo import ZoneInfo


class UnknownTimeZoneError(Exception):
    pass


class _Zone(_tzinfo):
    """Wraps a stdlib tzinfo, adding pytz's localize/normalize verbs."""

    def __init__(self, inner, name: str):
        self._inner = inner
        self.zone = name

    # tzinfo protocol — delegate
    def utcoffset(self, dt):
        return self._inner.utcoffset(dt)

    def dst(self, dt):
        return self._inner.dst(dt)

    def tzname(self, dt):
        return self._inner.tzname(dt)

    def fromutc(self, dt):
        return self._inner.fromutc(dt.replace(tzinfo=self._inner)).replace(tzinfo=self)

    # pytz verbs
    def localize(self, dt: datetime, is_dst: bool | None = None) -> datetime:
        if dt.tzinfo is not None:
            raise ValueError("Not naive datetime (tzinfo is already set)")
        return dt.replace(tzinfo=self)

    def normalize(self, dt: datetime) -> datetime:
        if dt.tzinfo is None:
            raise ValueError("Naive time - no tzinfo set")
        return dt.astimezone(self)

    def __repr__(self):
        return f"<OfflineShimZone {self.zone!r}>"


UTC = _Zone(_stdtz.utc, "UTC")
utc = UTC


def timezone(name: str) -> _Zone:
    if name in ("UTC", "utc"):
        return UTC
    try:
        return _Zone(ZoneInfo(name), name)
    except Exception as e:  # noqa: BLE001 — mirror pytz's single error type
        raise UnknownTimeZoneError(name) from e
