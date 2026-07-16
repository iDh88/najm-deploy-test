"""Time utilities for aviation operations."""
from __future__ import annotations
from datetime import datetime, date, timedelta
from typing import Optional
import pytz
import re


WOCL_START = 2   # 02:00 local
WOCL_END   = 6   # 05:59 local


def parse_time_string(time_str: str, reference_date: date,
                      timezone: str = "UTC") -> Optional[datetime]:
    """
    Parse aviation time strings like:
    "1430Z", "1430L", "14:30", "1430", "0220+1" (next day)
    """
    if not time_str:
        return None

    time_str = time_str.strip().upper()
    day_offset = 0

    # Handle day offset notation (+1, +2)
    offset_match = re.search(r'\+(\d)', time_str)
    if offset_match:
        day_offset = int(offset_match.group(1))
        time_str = time_str[:offset_match.start()]

    # Strip Z or L suffix
    is_utc = time_str.endswith('Z')
    time_str = time_str.rstrip('ZL').strip(':').replace(':', '')

    if len(time_str) != 4:
        return None

    try:
        hour   = int(time_str[:2])
        minute = int(time_str[2:])
    except ValueError:
        return None

    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None

    target_date = reference_date + timedelta(days=day_offset)

    if is_utc or timezone == "UTC":
        dt = datetime(target_date.year, target_date.month, target_date.day,
                      hour, minute, tzinfo=pytz.UTC)
    else:
        tz = pytz.timezone(timezone)
        dt_naive = datetime(target_date.year, target_date.month,
                            target_date.day, hour, minute)
        dt = tz.localize(dt_naive)

    return dt


def parse_duration_string(duration_str: str) -> int:
    """
    Parse duration strings like "1:45", "01:45", "145" → minutes.
    """
    if not duration_str:
        return 0
    duration_str = str(duration_str).strip()

    # "H:MM" format
    if ':' in duration_str:
        parts = duration_str.split(':')
        try:
            hours   = int(parts[0])
            minutes = int(parts[1]) if len(parts) > 1 else 0
            return hours * 60 + minutes
        except ValueError:
            return 0

    # Pure number — assume minutes if < 24, else treat as HHMM
    try:
        val = int(duration_str)
        if val < 100:
            return val * 60
        hours   = val // 100
        minutes = val % 100
        return hours * 60 + minutes
    except ValueError:
        return 0


def parse_date_string(date_str: str, year: int) -> Optional[date]:
    """
    Parse date strings like "06JUN", "6JUN", "06JUN2026".
    """
    if not date_str:
        return None

    MONTHS = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
        'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
        'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    }

    date_str = date_str.strip().upper()
    match = re.match(r'(\d{1,2})([A-Z]{3})(\d{4})?', date_str)
    if not match:
        return None

    day   = int(match.group(1))
    month = MONTHS.get(match.group(2))
    yr    = int(match.group(3)) if match.group(3) else year

    if not month:
        return None

    try:
        return date(yr, month, day)
    except ValueError:
        return None


def minutes_in_wocl(start: datetime, end: datetime) -> int:
    """
    Calculate minutes that fall within the WOCL window (02:00–05:59 local).
    Assumes datetime objects have timezone info.
    """
    total_wocl = 0
    current = start

    while current < end:
        local_hour = current.hour
        if WOCL_START <= local_hour < WOCL_END:
            total_wocl += 1
        current += timedelta(minutes=1)

    return total_wocl


def format_duration(minutes: int) -> str:
    """Format minutes as 'H:MM' aviation style."""
    h = minutes // 60
    m = minutes % 60
    return f"{h}:{m:02d}"


def local_time_str(dt: datetime, tz_name: str) -> str:
    """Convert UTC datetime to local time string."""
    try:
        tz  = pytz.timezone(tz_name)
        local = dt.astimezone(tz)
        return local.strftime("%H%MZ")
    except Exception:
        return dt.strftime("%H%MZ")
