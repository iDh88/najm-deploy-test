"""
Structural parser — converts RawLine/RawPairing/RawSegment
into fully normalized Pairing, FlightSegment, DutyPeriod models.
"""
from __future__ import annotations
import logging
import uuid
from datetime import date, datetime, timedelta
from typing import Optional

from ..models.raw_models import RawLine, RawPairing, RawSegment
from ..models.pairing_models import (
    FlightSegment, DutyPeriod, Pairing,
    SegmentType, PairingClassification, PatternFlag, LegalityMargins,
)
from ..utils.time_utils import (
    parse_time_string, parse_duration_string, parse_date_string,
)
from ..utils.aviation_codes import get_timezone, timezone_delta, is_international
from ..utils.legality_checker import LegalityChecker

logger = logging.getLogger(__name__)


class StructuralParser:
    """
    Converts raw extraction models into fully normalized domain models.
    Handles missing data, day boundary crossing, timezone conversions.
    """

    def __init__(self):
        self.legality = LegalityChecker()

    # ── Public entry point ────────────────────────────────────────────────────

    def parse_line(self, raw: RawLine, year: int) -> tuple[list[Pairing], list[str]]:
        """
        Returns (pairings, warnings).
        year is the schedule year (e.g. 2026).
        """
        pairings: list[Pairing] = []
        warnings: list[str]    = []

        for raw_pairing in raw.pairings:
            try:
                pairing = self._parse_pairing(
                    raw_pairing,
                    line_id=raw.line_number or "UNKNOWN",
                    year=year,
                )
                if pairing:
                    pairings.append(pairing)
            except Exception as e:
                warnings.append(
                    f"Failed to parse pairing {raw_pairing.pairing_id}: {e}"
                )
                logger.warning("Pairing parse error", exc_info=True)

        return pairings, warnings

    # ── Pairing parsing ───────────────────────────────────────────────────────

    def _parse_pairing(self, raw: RawPairing, line_id: str,
                       year: int) -> Optional[Pairing]:
        if not raw.segments:
            return None

        # Resolve dates
        dates = self._resolve_dates(raw.date_strings, year)
        ref_date = dates[0].date() if dates else date(year, 1, 1)

        # Parse segments
        segments = self._parse_segments(
            raw.segments, raw.pairing_id or "UNKNOWN", ref_date
        )
        if not segments:
            return None

        # Group segments into duty periods
        duty_periods = self._build_duty_periods(
            segments,
            raw.report_str,
            raw.release_str,
            raw.rest_str,
            ref_date,
        )

        # Classify
        classification = self._classify_pairing(segments, duty_periods, raw)
        pattern_flags  = self._detect_pattern_flags(segments, duty_periods, raw)

        # Legality
        legality = self._check_legality(duty_periods, segments)

        return Pairing(
            id=str(uuid.uuid4()),
            line_id=line_id,
            pairing_number=raw.pairing_id or "UNKNOWN",
            dates=dates,
            duty_periods=duty_periods,
            classification=classification,
            pattern_flags=pattern_flags,
            legality=legality,
        )

    # ── Segment parsing ───────────────────────────────────────────────────────

    def _parse_segments(self, raw_segs: list[RawSegment],
                        pairing_id: str, ref_date: date) -> list[FlightSegment]:
        segments: list[FlightSegment] = []
        current_date = ref_date

        for i, raw in enumerate(raw_segs):
            if not raw.flight_number or not raw.origin or not raw.destination:
                continue

            orig_tz = get_timezone(raw.origin)
            dest_tz = get_timezone(raw.destination)

            dep_utc = parse_time_string(
                raw.departure_str or "0000Z", current_date, orig_tz
            )
            arr_utc = parse_time_string(
                raw.arrival_str or "0000Z", current_date, dest_tz
            )

            # Handle day boundary crossing
            if dep_utc and arr_utc and arr_utc < dep_utc:
                arr_utc += timedelta(days=1)

            # Advance date if this segment crosses midnight
            if dep_utc and dep_utc.hour < 6 and i > 0:
                current_date = current_date + timedelta(days=1)
                dep_utc = parse_time_string(
                    raw.departure_str or "0000Z", current_date, orig_tz
                )
                arr_utc = parse_time_string(
                    raw.arrival_str or "0000Z", current_date, dest_tz
                )
                if dep_utc and arr_utc and arr_utc < dep_utc:
                    arr_utc += timedelta(days=1)

            block_mins = parse_duration_string(raw.block_str or "")
            if block_mins == 0 and dep_utc and arr_utc:
                # Derive from times if not provided
                block_mins = int((arr_utc - dep_utc).total_seconds() / 60)

            tz_delta = timezone_delta(raw.origin, raw.destination)

            seg = FlightSegment(
                segment_id=str(uuid.uuid4()),
                pairing_id=pairing_id,
                sequence=i,
                segment_type=(
                    SegmentType.DEADHEAD if raw.is_deadhead
                    else SegmentType.OPERATING
                ),
                flight_number=raw.flight_number,
                origin=raw.origin,
                destination=raw.destination,
                departure_utc=dep_utc or datetime.utcnow(),
                arrival_utc=arr_utc or datetime.utcnow(),
                departure_local_str=raw.departure_str or "",
                arrival_local_str=raw.arrival_str or "",
                block_minutes=max(block_mins, 0),
                aircraft_type=raw.aircraft_type,
                timezone_delta_hours=tz_delta,
                origin_tz=orig_tz,
                destination_tz=dest_tz,
            )
            segments.append(seg)

            # Advance current_date based on arrival
            if arr_utc:
                current_date = arr_utc.date()

        return segments

    # ── Duty period grouping ──────────────────────────────────────────────────

    def _build_duty_periods(
        self,
        segments: list[FlightSegment],
        report_str: Optional[str],
        release_str: Optional[str],
        rest_str: Optional[str],
        ref_date: date,
    ) -> list[DutyPeriod]:
        """
        Groups segments into duty periods.
        A duty period boundary is detected when rest > 5h between segments.
        """
        if not segments:
            return []

        REST_BOUNDARY_MINS = 300   # 5 hours

        # Build simple single duty period initially
        duty_periods: list[DutyPeriod] = []
        current_duty_segs: list[FlightSegment] = []
        current_duty_start = 0

        for i, seg in enumerate(segments):
            if i == 0:
                current_duty_segs.append(seg)
                continue

            prev = segments[i - 1]
            gap_mins = int(
                (seg.departure_utc - prev.arrival_utc).total_seconds() / 60
            )

            if gap_mins >= REST_BOUNDARY_MINS:
                # Close current duty period
                dp = self._build_single_duty(
                    current_duty_segs,
                    report_str if current_duty_start == 0 else None,
                    None,
                    ref_date,
                    gap_mins,   # rest after = gap to next duty
                )
                duty_periods.append(dp)
                current_duty_segs = [seg]
                current_duty_start = i
            else:
                current_duty_segs.append(seg)

        # Last duty period
        if current_duty_segs:
            dp = self._build_single_duty(
                current_duty_segs,
                report_str if not duty_periods else None,
                release_str,
                ref_date,
                parse_duration_string(rest_str or ""),
            )
            duty_periods.append(dp)

        return duty_periods

    def _build_single_duty(
        self,
        segments: list[FlightSegment],
        report_str: Optional[str],
        release_str: Optional[str],
        ref_date: date,
        rest_after_mins: int,
    ) -> DutyPeriod:
        first_seg = segments[0]
        last_seg  = segments[-1]
        orig_tz   = first_seg.origin_tz

        if report_str:
            report_utc = parse_time_string(report_str, ref_date, orig_tz)
        else:
            report_utc = first_seg.departure_utc - timedelta(minutes=60)

        if release_str:
            release_utc = parse_time_string(release_str, last_seg.arrival_utc.date(), orig_tz)
        else:
            release_utc = last_seg.arrival_utc + timedelta(minutes=30)

        if report_utc is None:
            report_utc = first_seg.departure_utc - timedelta(minutes=60)
        if release_utc is None:
            release_utc = last_seg.arrival_utc + timedelta(minutes=30)

        # Sanity: release must be after report
        if release_utc < report_utc:
            release_utc = last_seg.arrival_utc + timedelta(minutes=30)

        return DutyPeriod(
            duty_index=0,
            report_utc=report_utc,
            release_utc=release_utc,
            segments=segments,
            rest_after_mins=rest_after_mins,
        )

    # ── Classification ────────────────────────────────────────────────────────

    def _classify_pairing(
        self,
        segments: list[FlightSegment],
        duty_periods: list[DutyPeriod],
        raw: RawPairing,
    ) -> PairingClassification:
        dh_count  = sum(1 for s in segments if s.is_deadhead)
        total     = len(segments)
        dh_ratio  = dh_count / total if total else 0

        has_intl   = any(
            is_international(s.origin, s.destination)
            for s in segments if not s.is_deadhead
        )
        total_duty = sum(dp.duty_minutes for dp in duty_periods)
        report_hr  = duty_periods[0].report_utc.hour if duty_periods else 12

        if dh_ratio > 0.5:                       return PairingClassification.HEAVY_DEADHEAD
        if total_duty > 12 * 60:                 return PairingClassification.LONG_DUTY
        if report_hr < 6:                        return PairingClassification.EARLY_SIGNIN
        if total > 5:                            return PairingClassification.HIGH_LEG_COUNT
        if has_intl:                             return PairingClassification.INTERNATIONAL
        if self._is_overnight(duty_periods):     return PairingClassification.OVERNIGHT
        return PairingClassification.STANDARD

    def _is_overnight(self, duty_periods: list[DutyPeriod]) -> bool:
        for dp in duty_periods:
            if dp.report_utc.date() != dp.release_utc.date():
                return True
        return False

    # ── Pattern detection ─────────────────────────────────────────────────────

    def _detect_pattern_flags(
        self,
        segments: list[FlightSegment],
        duty_periods: list[DutyPeriod],
        raw: RawPairing,
    ) -> list[PatternFlag]:
        flags: list[PatternFlag] = []

        destinations = [s.destination for s in segments]
        if len(destinations) != len(set(destinations)):
            flags.append(PatternFlag.REPEATED_DESTINATION)

        dh_segs = [s for s in segments if s.is_deadhead]
        for i in range(len(dh_segs) - 1):
            if dh_segs[i + 1].sequence == dh_segs[i].sequence + 1:
                flags.append(PatternFlag.BACK_TO_BACK_DEADHEAD)
                break

        for dp in duty_periods:
            if 0 < dp.rest_after_mins < 660:
                flags.append(PatternFlag.MINIMUM_REST_ONLY)
                break

        tz_deltas = [s.timezone_delta_hours for s in segments]
        if sum(tz_deltas) > 5:
            flags.append(PatternFlag.MULTI_TIMEZONE)

        if duty_periods:
            report_hr = duty_periods[0].report_utc.hour
            if report_hr < 6:
                flags.append(PatternFlag.EARLY_SIGNIN)

        return list(set(flags))

    # ── Legality ──────────────────────────────────────────────────────────────

    def _check_legality(
        self,
        duty_periods: list[DutyPeriod],
        segments: list[FlightSegment],
    ) -> LegalityMargins:
        if not duty_periods:
            return LegalityMargins(
                fdp_limit_mins=720, fdp_actual_mins=0, fdp_margin_mins=720,
                rest_minimum_mins=600, rest_actual_mins=0, rest_margin_mins=0,
                block_limit_mins=510, block_actual_mins=0, block_margin_mins=510,
                is_fdp_legal=True, is_rest_legal=True, is_block_legal=True,
            )

        dp = duty_periods[0]
        has_intl = any(
            is_international(s.origin, s.destination) for s in segments
        )
        num_ops = sum(1 for s in segments if not s.is_deadhead)
        report_hr = dp.report_utc.hour

        result = self.legality.check_duty_period(
            fdp_minutes=dp.fdp_minutes,
            block_minutes=dp.block_minutes,
            rest_after_minutes=dp.rest_after_mins,
            num_legs=num_ops,
            report_hour=report_hr,
            is_international=has_intl,
        )

        rest_min = 660 if has_intl else 600

        return LegalityMargins(
            fdp_limit_mins=result.fdp_limit_mins,
            fdp_actual_mins=dp.fdp_minutes,
            fdp_margin_mins=result.fdp_margin_mins,
            rest_minimum_mins=rest_min,
            rest_actual_mins=dp.rest_after_mins,
            rest_margin_mins=result.rest_margin_mins,
            block_limit_mins=result.block_limit_mins,
            block_actual_mins=dp.block_minutes,
            block_margin_mins=result.block_margin_mins,
            is_fdp_legal=result.is_fdp_legal,
            is_rest_legal=result.is_rest_legal,
            is_block_legal=result.is_block_legal,
        )

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _resolve_dates(self, date_strings: list[str],
                       year: int) -> list[datetime]:
        dates: list[datetime] = []
        for ds in date_strings:
            d = parse_date_string(ds, year)
            if d:
                dates.append(datetime(d.year, d.month, d.day))
        return sorted(set(dates))
