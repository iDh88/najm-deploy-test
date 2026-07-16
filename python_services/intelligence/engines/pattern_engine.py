"""Pattern recognition engine — detects operational patterns across the month."""
from __future__ import annotations
from collections import Counter
from dataclasses import dataclass
from ..models.pairing_models import Pairing


@dataclass
class OperationalPattern:
    pattern_type: str
    description_en: str
    description_ar: str
    frequency: int
    affected_pairings: list[str]
    severity: str   # "INFO" | "NOTE" | "WATCH"


class PatternEngine:

    def analyze(self, pairings: list[Pairing]) -> list[OperationalPattern]:
        patterns: list[OperationalPattern] = []

        patterns.extend(self._repeated_destinations(pairings))
        patterns.extend(self._repeated_deadheads(pairings))
        patterns.extend(self._high_freq_turns(pairings))
        patterns.extend(self._minimum_rest_chain(pairings))
        patterns.extend(self._long_layovers(pairings))

        return patterns

    def _repeated_destinations(
        self, pairings: list[Pairing]
    ) -> list[OperationalPattern]:
        dest_count: Counter = Counter()
        dest_pairings: dict[str, list[str]] = {}

        for p in pairings:
            for dest in p.unique_destinations:
                dest_count[dest] += 1
                dest_pairings.setdefault(dest, []).append(p.pairing_number)

        result = []
        for dest, count in dest_count.items():
            if count >= 3:
                result.append(OperationalPattern(
                    pattern_type="REPEATED_DESTINATION",
                    description_en=f"Destination {dest} appears in {count} pairings.",
                    description_ar=f"الوجهة {dest} تظهر في {count} أزواج.",
                    frequency=count,
                    affected_pairings=dest_pairings[dest],
                    severity="INFO",
                ))
        return result

    def _repeated_deadheads(
        self, pairings: list[Pairing]
    ) -> list[OperationalPattern]:
        dh_routes: Counter = Counter()
        dh_pairings: dict[str, list[str]] = {}

        for p in pairings:
            for seg in p.deadhead_segments:
                route = f"{seg.origin}→{seg.destination}"
                dh_routes[route] += 1
                dh_pairings.setdefault(route, []).append(p.pairing_number)

        result = []
        for route, count in dh_routes.items():
            if count >= 2:
                result.append(OperationalPattern(
                    pattern_type="REPEATED_DEADHEAD",
                    description_en=f"Deadhead route {route} repeats {count} times.",
                    description_ar=f"مسار التوجيه {route} يتكرر {count} مرات.",
                    frequency=count,
                    affected_pairings=dh_pairings[route],
                    severity="NOTE",
                ))
        return result

    def _high_freq_turns(
        self, pairings: list[Pairing]
    ) -> list[OperationalPattern]:
        """Detect pairings with 4+ operating legs (high-frequency turn operations)."""
        high_freq = [
            p for p in pairings if len(p.operating_segments) >= 4
        ]
        if not high_freq:
            return []
        return [OperationalPattern(
            pattern_type="HIGH_FREQUENCY_TURNS",
            description_en=(
                f"{len(high_freq)} pairings have 4+ operating legs — "
                "high-frequency turn operations detected."
            ),
            description_ar=(
                f"{len(high_freq)} أزواج تحتوي على 4+ أرجل تشغيلية — "
                "تم اكتشاف عمليات دوران عالية التكرار."
            ),
            frequency=len(high_freq),
            affected_pairings=[p.pairing_number for p in high_freq],
            severity="WATCH",
        )]

    def _minimum_rest_chain(
        self, pairings: list[Pairing]
    ) -> list[OperationalPattern]:
        """Detect chains of pairings with minimum legal rest between them."""
        min_rest = [
            p for p in pairings
            for dp in p.duty_periods
            if 0 < dp.rest_after_mins < 660
        ]
        if len(min_rest) < 2:
            return []
        return [OperationalPattern(
            pattern_type="MINIMUM_REST_CHAIN",
            description_en=(
                f"{len(min_rest)} duty periods have near-minimum rest. "
                "Cumulative fatigue risk is elevated."
            ),
            description_ar=(
                f"{len(min_rest)} فترات خدمة لديها راحة قريبة من الحد الأدنى. "
                "خطر الإجهاد التراكمي مرتفع."
            ),
            frequency=len(min_rest),
            affected_pairings=[p.pairing_number for p in min_rest],
            severity="WATCH",
        )]

    def _long_layovers(
        self, pairings: list[Pairing]
    ) -> list[OperationalPattern]:
        """Detect pairings with multi-day layovers (rest > 24h)."""
        long = [
            p for p in pairings
            for dp in p.duty_periods
            if dp.rest_after_mins > 24 * 60
        ]
        if not long:
            return []
        return [OperationalPattern(
            pattern_type="LONG_LAYOVER",
            description_en=(
                f"{len(long)} pairings include extended layovers (>24h). "
                "Good recovery opportunity but increases TAFB."
            ),
            description_ar=(
                f"{len(long)} أزواج تتضمن توقفات ممتدة (أكثر من 24 ساعة). "
                "فرصة تعافٍ جيدة لكنها تزيد من وقت الغياب عن القاعدة."
            ),
            frequency=len(long),
            affected_pairings=[p.pairing_number for p in long],
            severity="INFO",
        )]
