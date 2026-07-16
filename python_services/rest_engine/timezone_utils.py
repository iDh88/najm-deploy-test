"""
Rest Engine — Timezone Utilities
UTC/local conversion, WOCL detection, overnight crossing support.
"""
from __future__ import annotations
from datetime import datetime, timedelta
from typing import Optional
import pytz

# Saudi Arabia base timezone
BASE_TZ = "Asia/Riyadh"

# WOCL window (Window of Circadian Low)
WOCL_START = 2   # 02:00 local
WOCL_END   = 6   # 05:59 local


def to_utc(dt: datetime, tz_name: str) -> datetime:
    """Convert a naive local datetime to UTC."""
    if dt.tzinfo is not None:
        return dt.astimezone(pytz.UTC)
    tz  = pytz.timezone(tz_name)
    local = tz.localize(dt)
    return local.astimezone(pytz.UTC)


def to_local(dt_utc: datetime, tz_name: str) -> datetime:
    """Convert a UTC datetime to local time."""
    tz = pytz.timezone(tz_name)
    if dt_utc.tzinfo is None:
        dt_utc = pytz.UTC.localize(dt_utc)
    return dt_utc.astimezone(tz)


def duration_minutes(start: datetime, end: datetime) -> int:
    """Minutes between two datetimes. Handles timezone-aware datetimes."""
    if start.tzinfo is None and end.tzinfo is None:
        return int((end - start).total_seconds() / 60)
    # Normalize to UTC for comparison
    s = start.astimezone(pytz.UTC) if start.tzinfo else pytz.UTC.localize(start)
    e = end.astimezone(pytz.UTC)   if end.tzinfo   else pytz.UTC.localize(end)
    diff = int((e - s).total_seconds() / 60)
    return max(diff, 0)


def wocl_minutes_in_window(start_utc: datetime, end_utc: datetime,
                            local_tz: str) -> int:
    """
    Calculate minutes of a duty/flight that fall within the WOCL
    (02:00–05:59 local time).
    Samples every 15 minutes for performance.
    """
    if start_utc.tzinfo is None:
        start_utc = pytz.UTC.localize(start_utc)
    if end_utc.tzinfo is None:
        end_utc = pytz.UTC.localize(end_utc)

    tz      = pytz.timezone(local_tz)
    wocl    = 0
    current = start_utc
    step    = timedelta(minutes=15)

    while current < end_utc:
        local_h = current.astimezone(tz).hour
        if WOCL_START <= local_h < WOCL_END:
            wocl += 15
        current += step

    return min(wocl, duration_minutes(start_utc, end_utc))


def penetrates_wocl(start_utc: datetime, end_utc: datetime,
                    local_tz: str, threshold_mins: int = 30) -> bool:
    """True if the window contains ≥ threshold_mins of WOCL."""
    return wocl_minutes_in_window(start_utc, end_utc, local_tz) >= threshold_mins


def is_early_signin(report_local_hour: int) -> bool:
    """True if report time is before 06:00 local."""
    return report_local_hour < 6


def crosses_midnight(start: datetime, end: datetime) -> bool:
    """True if the period spans a midnight boundary (local dates differ)."""
    return start.date() != end.date()


def format_duration(minutes: int) -> str:
    """Format minutes as HH:MM."""
    sign = "-" if minutes < 0 else ""
    m    = abs(minutes)
    return f"{sign}{m // 60}:{m % 60:02d}"


def local_time_label(dt_utc: datetime, tz_name: str) -> str:
    """Return a human-readable local time string e.g. '14:30 AST'."""
    tz    = pytz.timezone(tz_name)
    local = dt_utc.astimezone(tz)
    abbr  = local.strftime("%Z")
    return local.strftime(f"%H:%M {abbr}")


def timezone_delta_hours(origin_tz: str, destination_tz: str) -> float:
    """Signed timezone delta in hours between two IANA timezone names."""
    now = datetime.utcnow().replace(tzinfo=pytz.UTC)
    orig_offset = pytz.timezone(origin_tz).utcoffset(now)
    dest_offset = pytz.timezone(destination_tz).utcoffset(now)
    if orig_offset is None or dest_offset is None:
        return 0.0
    return (dest_offset - orig_offset).total_seconds() / 3600
