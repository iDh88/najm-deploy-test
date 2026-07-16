"""Monthly analytics engine — aggregates all intelligence into MonthlyAnalytics."""
from __future__ import annotations
from datetime import date, timedelta
from collections import Counter

from ..models.pairing_models import Pairing
from ..models.fatigue_models import LineFatigueProfile
from ..models.analytics_models import (
    MonthlyAnalytics, LineClassification, WeekAnalytics,
    DestinationFrequency, CalendarDay,
)
from ..utils.aviation_codes import get_city, get_airport, is_international


class AnalyticsEngine:

    def __init__(self, fatigue_engine, classification_engine):
        self.fatigue        = fatigue_engine
        self.classification = classification_engine

    # ── Public ────────────────────────────────────────────────────────────────

    def generate(
        self,
        line_id: str,
        period: str,
        pairings: list[Pairing],
        fleet_avg: dict[str, float] | None = None,
    ) -> MonthlyAnalytics:

        fatigue_profile = self.fatigue.score_line(pairings)
        classification  = self.classification.classify(pairings, fatigue_profile)

        total_block    = sum(p.total_block_minutes for p in pairings) / 60
        total_duty     = sum(p.total_duty_minutes  for p in pairings) / 60
        total_dh_block = sum(
            sum(s.block_minutes for s in p.deadhead_segments)
            for p in pairings
        ) / 60

        all_segs        = [s for p in pairings for s in p.all_segments]
        operating_segs  = [s for s in all_segs if not s.is_deadhead]
        deadhead_segs   = [s for s in all_segs if s.is_deadhead]

        all_destinations = [s.destination for s in all_segs]
        unique_dests     = list(set(all_destinations))

        intl_legs = sum(
            1 for s in operating_segs
            if is_international(s.origin, s.destination)
        )
        dom_legs = len(operating_segs) - intl_legs

        dh_ratio = len(deadhead_segs) / max(len(all_segs), 1)

        estimated_credit = self._estimate_credit(total_block, len(pairings))
        per_diem         = self._estimate_per_diem(pairings)

        consecutive_max  = self._consecutive_duty_max(pairings)
        off_days, open_days = self._count_day_types(pairings, period)

        weekly    = self._weekly_breakdown(pairings, fatigue_profile, period)
        dest_freq = self._destination_frequency(all_segs)
        vs_fleet  = self._vs_fleet(
            total_block, total_duty, len(pairings),
            fatigue_profile.average_fatigue, fleet_avg,
        )

        # Estimate total rest (not in explicit data — approximate)
        total_rest = max(0.0, (30 * 24) - total_duty - off_days * 24)

        return MonthlyAnalytics(
            line_id=line_id,
            period=period,
            total_block_hours=round(total_block, 2),
            total_duty_hours=round(total_duty, 2),
            total_deadhead_hours=round(total_dh_block, 2),
            total_rest_hours=round(total_rest, 1),
            carry_over_hours=0.0,    # populated from raw if available
            total_pairings=len(pairings),
            total_operating_legs=len(operating_segs),
            total_deadhead_legs=len(deadhead_segs),
            off_days=off_days,
            open_days=open_days,
            consecutive_duty_max=consecutive_max,
            estimated_credit=round(estimated_credit, 1),
            estimated_per_diem_usd=round(per_diem, 2),
            deadhead_ratio=round(dh_ratio, 3),
            unique_destinations=unique_dests,
            international_count=intl_legs,
            domestic_count=dom_legs,
            destination_freq=dest_freq,
            fatigue_profile=fatigue_profile,
            weekly_breakdown=weekly,
            classification=classification,
            vs_fleet_avg=vs_fleet,
        )

    def build_calendar(
        self,
        pairings: list[Pairing],
        fatigue_profile: LineFatigueProfile,
        period: str,
    ) -> list[CalendarDay]:
        """Build day-by-day calendar view."""
        year, month = self._parse_period(period)
        if not year:
            return []

        import calendar
        days_in_month = calendar.monthrange(year, month)[1]

        # Map dates to pairings
        duty_map: dict[date, tuple[Pairing, int]] = {}
        for i, p in enumerate(pairings):
            for dt in p.dates:
                duty_map[dt.date()] = (p, i)

        # Build timeline map
        timeline_map = {pt.day: pt for pt in fatigue_profile.timeline}

        calendar_days: list[CalendarDay] = []
        for day_num in range(1, days_in_month + 1):
            d = date(year, month, day_num)
            pt = timeline_map.get(d)
            pairing_entry = duty_map.get(d)

            if pairing_entry:
                p, idx = pairing_entry
                f_score = fatigue_profile.pairing_scores[idx] if idx < len(fatigue_profile.pairing_scores) else None
                calendar_days.append(CalendarDay(
                    date=d,
                    pairing_id=p.id,
                    pairing_label=p.pairing_number,
                    fatigue_score=f_score.raw if f_score else 0.0,
                    fatigue_level=f_score.level if f_score else fatigue_profile.overall_level,
                    is_off=False,
                    is_open=False,
                    is_rest=False,
                    duty_hours=p.total_duty_minutes / 60,
                    block_hours=p.total_block_minutes / 60,
                    destinations=[s.destination for s in p.all_segments],
                ))
            else:
                from ..models.fatigue_models import FatigueLevel
                calendar_days.append(CalendarDay(
                    date=d,
                    pairing_id=None,
                    pairing_label=None,
                    fatigue_score=0.0,
                    fatigue_level=FatigueLevel.LOW,
                    is_off=True,
                    is_open=False,
                    is_rest=True,
                    duty_hours=0.0,
                    block_hours=0.0,
                    destinations=[],
                ))

        return calendar_days

    # ── Private ───────────────────────────────────────────────────────────────

    def _estimate_credit(self, block_hours: float,
                         pairing_count: int) -> float:
        """
        Saudi Airlines credit formula: block + 0.5h per pairing + overrides.
        Simplified estimate.
        """
        return block_hours + pairing_count * 0.5

    def _estimate_per_diem(self, pairings: list[Pairing]) -> float:
        """
        Estimate per-diem based on time away from base.
        International layovers: ~$4.00/h (simplified).
        """
        total_tafb_hrs = sum(p.total_duty_minutes for p in pairings) / 60
        intl_factor = sum(
            1 for p in pairings if p.is_international
        ) / max(len(pairings), 1)
        rate = 3.0 + intl_factor * 1.5
        return total_tafb_hrs * rate

    def _consecutive_duty_max(self, pairings: list[Pairing]) -> int:
        if not pairings:
            return 0
        duty_dates: set[date] = set()
        for p in pairings:
            for dt in p.dates:
                duty_dates.add(dt.date())
        if not duty_dates:
            return 0

        all_dates  = sorted(duty_dates)
        max_run    = 1
        current    = 1

        for i in range(1, len(all_dates)):
            if (all_dates[i] - all_dates[i-1]).days == 1:
                current += 1
                max_run  = max(max_run, current)
            else:
                current = 1

        return max_run

    def _count_day_types(
        self, pairings: list[Pairing], period: str
    ) -> tuple[int, int]:
        year, month = self._parse_period(period)
        if not year:
            return 0, 0

        import calendar
        total_days = calendar.monthrange(year, month)[1]
        duty_dates: set[date] = set()
        for p in pairings:
            for dt in p.dates:
                if dt.month == month and dt.year == year:
                    duty_dates.add(dt.date())

        off_days  = total_days - len(duty_dates)
        open_days = max(0, off_days - 4)   # heuristic
        return off_days, open_days

    def _weekly_breakdown(
        self,
        pairings: list[Pairing],
        fatigue: LineFatigueProfile,
        period: str,
    ) -> list[WeekAnalytics]:
        year, month = self._parse_period(period)
        if not year:
            return []

        from ..models.fatigue_models import FatigueLevel

        weeks: list[WeekAnalytics] = []
        import calendar
        month_days = calendar.monthrange(year, month)[1]

        # Build 4–5 weeks
        day = 1
        week_num = 1
        while day <= month_days:
            week_end = min(day + 6, month_days)
            start_d  = date(year, month, day)
            end_d    = date(year, month, week_end)

            week_pairings = [
                p for p in pairings
                if any(start_d <= dt.date() <= end_d for dt in p.dates)
            ]

            block_h = sum(p.total_block_minutes for p in week_pairings) / 60
            duty_h  = sum(p.total_duty_minutes  for p in week_pairings) / 60
            dests   = list({s.destination for p in week_pairings
                            for s in p.all_segments})

            # Fatigue for this week
            week_pts = [pt for pt in fatigue.timeline
                        if start_d <= pt.day <= end_d]
            avg_f = (sum(pt.cumulative for pt in week_pts) / len(week_pts)
                     if week_pts else 0.0)

            weeks.append(WeekAnalytics(
                week_number=week_num,
                start_date=start_d,
                end_date=end_d,
                block_hours=round(block_h, 1),
                duty_hours=round(duty_h, 1),
                pairing_count=len(week_pairings),
                off_days=7 - len(week_pairings),
                fatigue_level=FatigueEngine._classify(avg_f)
                    if avg_f > 0 else FatigueLevel.LOW,
                destinations=dests,
            ))

            day      += 7
            week_num += 1

        return weeks

    def _destination_frequency(
        self, segments
    ) -> list[DestinationFrequency]:
        counts: Counter = Counter()
        hours:  dict[str, float] = {}

        for seg in segments:
            dest = seg.destination
            counts[dest] += 1
            hours[dest]   = hours.get(dest, 0) + seg.block_minutes / 60

        result: list[DestinationFrequency] = []
        for dest, count in counts.most_common(20):
            airport = get_airport(dest)
            result.append(DestinationFrequency(
                iata=dest,
                city=airport.get("city", dest),
                country=airport.get("country", "??"),
                count=count,
                total_hrs=round(hours.get(dest, 0), 1),
                is_intl=airport.get("country", "") != "SA",
            ))
        return result

    def _vs_fleet(
        self, block: float, duty: float,
        pairings: int, fatigue: float,
        fleet_avg: dict | None,
    ) -> dict[str, float]:
        if not fleet_avg:
            return {}
        result = {}
        if "block_hours" in fleet_avg and fleet_avg["block_hours"] > 0:
            result["block_hours"] = (block - fleet_avg["block_hours"]) / fleet_avg["block_hours"] * 100
        if "fatigue" in fleet_avg and fleet_avg["fatigue"] > 0:
            result["fatigue"]     = (fatigue - fleet_avg["fatigue"]) / fleet_avg["fatigue"] * 100
        return result

    def _parse_period(self, period: str) -> tuple[int, int]:
        """Parse 'JUN-2026' → (2026, 6)."""
        import re
        MONTHS = {'JAN':1,'FEB':2,'MAR':3,'APR':4,'MAY':5,'JUN':6,
                  'JUL':7,'AUG':8,'SEP':9,'OCT':10,'NOV':11,'DEC':12}
        m = re.match(r'([A-Z]{3})[-]?(\d{4})', period.upper())
        if not m:
            return 0, 0
        return int(m.group(2)), MONTHS.get(m.group(1), 1)


# Avoid circular import
from ..engines.fatigue_engine import FatigueEngine
