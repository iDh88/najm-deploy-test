"""
Fatigue Engine — FRMS-based (Fatigue Risk Management System).
Multi-factor scoring model for aviation duty operations.
"""
from __future__ import annotations
import logging
from datetime import date, datetime, timedelta
from typing import Optional

from ..models.pairing_models import Pairing, FlightSegment, DutyPeriod
from ..models.fatigue_models import (
    FatigueLevel, FatigueFactor, FatigueScore,
    RecoveryWindow, RecoveryQuality,
    FatiguePoint, LineFatigueProfile,
)

logger = logging.getLogger(__name__)

WOCL_START_H = 2   # 02:00 local
WOCL_END_H   = 6   # 05:59 local


class FatigueEngine:

    WEIGHTS = {
        'early_signin':         0.22,
        'wocl_penetration':     0.25,
        'duty_length':          0.18,
        'leg_count':            0.10,
        'consecutive_duties':   0.12,
        'rest_quality':         0.08,
        'timezone_transitions': 0.05,
    }

    # ── Public API ────────────────────────────────────────────────────────────

    def score_pairing(self, pairing: Pairing) -> FatigueScore:
        factors: list[FatigueFactor] = []
        raw = 0.0

        for dp in pairing.duty_periods:
            # Early sign-in
            signin_score, signin_desc = self._early_signin_factor(dp)
            if signin_score > 0:
                f = FatigueFactor(
                    name="Early Sign-In",
                    score=signin_score,
                    weight=self.WEIGHTS['early_signin'],
                    description=signin_desc,
                )
                factors.append(f)
                raw += f.weighted_score

            # WOCL penetration
            wocl_mins = self._wocl_minutes(dp.segments)
            if wocl_mins > 0:
                wocl_score = min(wocl_mins / 240.0, 1.0)  # norm to 4h
                f = FatigueFactor(
                    name="WOCL Operations",
                    score=wocl_score,
                    weight=self.WEIGHTS['wocl_penetration'],
                    description=f"{wocl_mins} min operating during 02:00–05:59",
                )
                factors.append(f)
                raw += f.weighted_score

            # Duty length
            duty_hrs = dp.duty_minutes / 60
            duty_score = min(duty_hrs / 14.0, 1.0)
            f = FatigueFactor(
                name="Duty Length",
                score=duty_score,
                weight=self.WEIGHTS['duty_length'],
                description=f"{duty_hrs:.1f}h duty",
            )
            factors.append(f)
            raw += f.weighted_score

            # Leg count
            leg_count  = len(dp.operating_segments)
            leg_score  = min(leg_count / 6.0, 1.0)
            if leg_score > 0:
                f = FatigueFactor(
                    name="Leg Count",
                    score=leg_score,
                    weight=self.WEIGHTS['leg_count'],
                    description=f"{leg_count} operating legs",
                )
                factors.append(f)
                raw += f.weighted_score

            # Rest quality
            rest_score, rest_desc = self._rest_quality_factor(dp.rest_after_mins)
            f = FatigueFactor(
                name="Rest Quality",
                score=rest_score,
                weight=self.WEIGHTS['rest_quality'],
                description=rest_desc,
            )
            factors.append(f)
            raw += f.weighted_score

        # Timezone transitions
        tz_delta = sum(s.timezone_delta_hours for s in pairing.all_segments)
        tz_score = min(tz_delta / 12.0, 1.0)
        if tz_score > 0:
            f = FatigueFactor(
                name="Timezone Transitions",
                score=tz_score,
                weight=self.WEIGHTS['timezone_transitions'],
                description=f"{tz_delta:.0f}h total TZ shift",
            )
            factors.append(f)
            raw += f.weighted_score

        raw = min(raw, 1.0)
        level = self._classify(raw)

        return FatigueScore(
            raw=raw,
            level=level,
            factors=factors,
            wocl_minutes=self._wocl_minutes(pairing.all_segments),
            early_signin=any(dp.report_utc.hour < 6 for dp in pairing.duty_periods),
            night_ops=any(
                6 <= s.departure_utc.hour <= 4 or s.departure_utc.hour >= 22
                for s in pairing.all_segments
            ),
        )

    def score_line(self, pairings: list[Pairing]) -> LineFatigueProfile:
        if not pairings:
            return LineFatigueProfile(
                pairing_scores=[], average_fatigue=0, peak_fatigue=0,
                high_fatigue_days=0, medium_fatigue_days=0, low_fatigue_days=0,
                recovery_windows=[], timeline=[], overall_level=FatigueLevel.LOW,
                wocl_total_minutes=0, early_signin_count=0, night_ops_count=0,
            )

        scores = [self.score_pairing(p) for p in pairings]
        timeline = self.build_timeline(pairings, scores)
        recovery_windows = self._find_recovery_windows(pairings, scores)

        avg = sum(s.raw for s in scores) / len(scores)
        peak = max(s.raw for s in scores)

        return LineFatigueProfile(
            pairing_scores=scores,
            average_fatigue=avg,
            peak_fatigue=peak,
            high_fatigue_days=sum(1 for s in scores if s.level == FatigueLevel.HIGH),
            medium_fatigue_days=sum(1 for s in scores if s.level == FatigueLevel.MEDIUM),
            low_fatigue_days=sum(1 for s in scores if s.level == FatigueLevel.LOW),
            recovery_windows=recovery_windows,
            timeline=timeline,
            overall_level=self._classify(avg),
            wocl_total_minutes=sum(s.wocl_minutes for s in scores),
            early_signin_count=sum(1 for s in scores if s.early_signin),
            night_ops_count=sum(1 for s in scores if s.night_ops),
        )

    def build_timeline(
        self,
        pairings: list[Pairing],
        scores: list[FatigueScore] | None = None,
    ) -> list[FatiguePoint]:
        """
        Builds day-by-day fatigue timeline for chart rendering.
        Uses a decay model: fatigue accumulates on duty days,
        decreases on rest days proportional to rest hours.
        """
        if not pairings:
            return []

        if scores is None:
            scores = [self.score_pairing(p) for p in pairings]

        # Build date→(pairing, score) map
        duty_map: dict[date, tuple[Pairing, FatigueScore]] = {}
        for p, s in zip(pairings, scores):
            for dt in p.dates:
                duty_map[dt.date()] = (p, s)

        if not duty_map:
            return []

        start = min(duty_map.keys())
        end   = max(duty_map.keys())
        all_dates = [start + timedelta(days=i)
                     for i in range((end - start).days + 1)]

        timeline: list[FatiguePoint] = []
        cumulative = 0.0
        prev_score = 0.0

        for day in all_dates:
            if day in duty_map:
                pairing, score = duty_map[day]
                # Accumulate: 70% of pairing score added
                delta = score.raw * 0.7
                cumulative = min(cumulative + delta, 1.0)
                label = pairing.pairing_number
            else:
                # Recovery day: reduce by 12–20% depending on rest
                recovery = 0.18
                delta = -recovery
                cumulative = max(cumulative - recovery, 0.0)
                label = "REST"

            point = FatiguePoint(
                day=day,
                score=score.raw if day in duty_map else 0.0,
                level=self._classify(cumulative),
                label=label,
                cumulative=cumulative,
                delta=cumulative - prev_score,
            )
            timeline.append(point)
            prev_score = cumulative

        return timeline

    # ── Private helpers ───────────────────────────────────────────────────────

    def _early_signin_factor(self, dp: DutyPeriod) -> tuple[float, str]:
        hour = dp.report_utc.hour
        if hour >= 6:
            return 0.0, f"Standard sign-in at {hour:02d}:00"
        # Progressive penalty: earlier = higher score
        # 05:xx → 0.2, 04:xx → 0.5, 03:xx → 0.7, 02:xx → 0.9, 01:xx → 1.0
        scores = {5: 0.2, 4: 0.5, 3: 0.7, 2: 0.9, 1: 1.0, 0: 1.0}
        score = scores.get(hour, 0.3)
        return score, f"Sign-in at {hour:02d}:00 local"

    def _wocl_minutes(self, segments: list[FlightSegment]) -> int:
        total = 0
        for seg in segments:
            dep_h = seg.departure_utc.hour
            arr_h = seg.arrival_utc.hour
            # Simple approximation: check if flight crosses WOCL
            if dep_h < WOCL_END_H or arr_h > WOCL_START_H:
                wocl_overlap = self._estimate_wocl_overlap(
                    seg.departure_utc, seg.arrival_utc
                )
                total += wocl_overlap
        return total

    def _estimate_wocl_overlap(self, dep: datetime, arr: datetime) -> int:
        """Estimate minutes of flight within 02:00–05:59."""
        mins = 0
        current = dep
        step = timedelta(minutes=15)
        while current < arr:
            h = current.hour
            if WOCL_START_H <= h < WOCL_END_H:
                mins += 15
            current += step
        return mins

    def _rest_quality_factor(self, rest_minutes: int) -> tuple[float, str]:
        if rest_minutes <= 0:
            return 0.1, "Rest not specified"
        rest_hours = rest_minutes / 60
        if rest_hours >= 12:
            return 0.0, f"Excellent rest: {rest_hours:.1f}h"
        if rest_hours >= 10:
            return 0.2, f"Good rest: {rest_hours:.1f}h"
        if rest_hours >= 8:
            return 0.5, f"Adequate rest: {rest_hours:.1f}h"
        return 0.9, f"Poor rest: {rest_hours:.1f}h (below recommended)"

    def _find_recovery_windows(
        self,
        pairings: list[Pairing],
        scores: list[FatigueScore],
    ) -> list[RecoveryWindow]:
        """Find consecutive rest days between pairings."""
        if not pairings:
            return []

        duty_dates: set[date] = set()
        for p in pairings:
            for dt in p.dates:
                duty_dates.add(dt.date())

        if not duty_dates:
            return []

        start = min(duty_dates)
        end   = max(duty_dates)
        all_dates = [start + timedelta(days=i)
                     for i in range((end - start).days + 1)]

        windows: list[RecoveryWindow] = []
        run_start: Optional[date] = None
        run_count = 0

        for day in all_dates:
            if day not in duty_dates:
                if run_start is None:
                    run_start = day
                run_count += 1
            else:
                if run_start and run_count >= 1:
                    run_end   = run_start + timedelta(days=run_count - 1)
                    hours     = run_count * 24.0
                    quality   = self._rest_quality_from_days(run_count)
                    windows.append(RecoveryWindow(
                        start_day=run_start,
                        end_day=run_end,
                        duration_hours=hours,
                        quality=quality,
                        description=f"{run_count} consecutive rest days",
                    ))
                run_start = None
                run_count = 0

        return windows

    def _rest_quality_from_days(self, days: int) -> RecoveryQuality:
        if days >= 4:   return RecoveryQuality.EXCELLENT
        if days >= 2:   return RecoveryQuality.GOOD
        if days == 1:   return RecoveryQuality.ADEQUATE
        return RecoveryQuality.POOR

    @staticmethod
    def _classify(score: float) -> FatigueLevel:
        if score < 0.35: return FatigueLevel.LOW
        if score < 0.65: return FatigueLevel.MEDIUM
        return FatigueLevel.HIGH
