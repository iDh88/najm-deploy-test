"""Line classification engine — 10 specialized classifiers."""
from __future__ import annotations
from dataclasses import dataclass
from ..models.pairing_models import Pairing
from ..models.fatigue_models import FatigueLevel, LineFatigueProfile
from ..models.analytics_models import LineTag, LineClassification


@dataclass
class ClassifierResult:
    matches:    bool
    tag:        LineTag
    confidence: float   # 0.0–1.0


class _BaseClassifier:
    tag: LineTag
    def evaluate(self, pairings: list[Pairing],
                 fatigue: LineFatigueProfile) -> ClassifierResult:
        raise NotImplementedError


class HighFatigueClassifier(_BaseClassifier):
    tag = LineTag.HIGH_FATIGUE

    def evaluate(self, pairings, fatigue):
        matches = (
            fatigue.average_fatigue > 0.55 or
            fatigue.high_fatigue_days >= 3 or
            fatigue.peak_fatigue > 0.80
        )
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=fatigue.average_fatigue)


class RecoveryFriendlyClassifier(_BaseClassifier):
    tag = LineTag.RECOVERY_FRIENDLY

    def evaluate(self, pairings, fatigue):
        from ..models.fatigue_models import RecoveryQuality
        good_windows = sum(
            1 for w in fatigue.recovery_windows
            if w.quality in (RecoveryQuality.EXCELLENT, RecoveryQuality.GOOD)
        )
        consecutive_max = max(
            (len(p.dates) for p in pairings), default=0
        )
        matches = (
            fatigue.average_fatigue < 0.35 and
            good_windows >= 2 and
            consecutive_max <= 3 and
            fatigue.early_signin_count == 0
        )
        confidence = max(0.0, 1.0 - fatigue.average_fatigue)
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=confidence)


class HeavyDeadheadClassifier(_BaseClassifier):
    tag = LineTag.HEAVY_DEADHEAD

    def evaluate(self, pairings, fatigue):
        if not pairings:
            return ClassifierResult(False, self.tag, 0.0)
        total_segs = sum(len(p.all_segments) for p in pairings)
        total_dh   = sum(len(p.deadhead_segments) for p in pairings)
        ratio = total_dh / total_segs if total_segs else 0
        matches = ratio > 0.35
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=min(ratio * 2, 1.0))


class HighIncomeClassifier(_BaseClassifier):
    tag = LineTag.HIGH_INCOME

    def evaluate(self, pairings, fatigue):
        total_block = sum(p.total_block_minutes for p in pairings)
        block_hours = total_block / 60
        # High income: >80h block or >15 operating legs
        total_legs = sum(len(p.operating_segments) for p in pairings)
        matches = block_hours > 75 or total_legs > 14
        confidence = min(block_hours / 100, 1.0)
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=confidence)


class InternationalHeavyClassifier(_BaseClassifier):
    tag = LineTag.INTERNATIONAL_HEAVY

    def evaluate(self, pairings, fatigue):
        intl_pairings = sum(1 for p in pairings if p.is_international)
        ratio = intl_pairings / len(pairings) if pairings else 0
        matches = ratio > 0.6
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=ratio)


class EarlySignInClassifier(_BaseClassifier):
    tag = LineTag.EARLY_SIGNIN_HEAVY

    def evaluate(self, pairings, fatigue):
        early = fatigue.early_signin_count
        total = len(pairings)
        ratio = early / total if total else 0
        matches = ratio > 0.4 or early >= 3
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=ratio)


class LongDutyClassifier(_BaseClassifier):
    tag = LineTag.LONG_DUTY

    def evaluate(self, pairings, fatigue):
        long_duties = sum(
            1 for p in pairings
            if p.total_duty_minutes > 11 * 60
        )
        total = len(pairings)
        ratio = long_duties / total if total else 0
        matches = ratio > 0.4 or long_duties >= 2
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=ratio)


class NightHeavyClassifier(_BaseClassifier):
    tag = LineTag.NIGHT_HEAVY

    def evaluate(self, pairings, fatigue):
        night_ops = fatigue.night_ops_count
        total = len(pairings)
        wocl_hours = fatigue.wocl_total_minutes / 60
        ratio = night_ops / total if total else 0
        matches = ratio > 0.4 or wocl_hours > 8
        confidence = min(wocl_hours / 20, 1.0)
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=confidence)


class ShortHaulIntensiveClassifier(_BaseClassifier):
    tag = LineTag.SHORT_HAUL_INTENSIVE

    def evaluate(self, pairings, fatigue):
        if not pairings:
            return ClassifierResult(False, self.tag, 0.0)
        avg_block_per_seg = (
            sum(p.total_block_minutes for p in pairings) /
            max(sum(len(p.operating_segments) for p in pairings), 1)
        )
        # Short-haul: avg segment < 2h block and many legs
        total_legs = sum(len(p.operating_segments) for p in pairings)
        matches = avg_block_per_seg < 120 and total_legs > 10
        confidence = max(0.0, 1.0 - avg_block_per_seg / 200)
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=confidence)


class OptimalBalanceClassifier(_BaseClassifier):
    tag = LineTag.OPTIMAL_BALANCE

    def evaluate(self, pairings, fatigue):
        if not pairings:
            return ClassifierResult(False, self.tag, 0.0)
        block_hours = sum(p.total_block_minutes for p in pairings) / 60
        dh_ratio = (
            sum(len(p.deadhead_segments) for p in pairings) /
            max(sum(len(p.all_segments) for p in pairings), 1)
        )
        # Balanced: medium fatigue, good income, low deadhead
        matches = (
            0.25 <= fatigue.average_fatigue <= 0.55 and
            60 <= block_hours <= 85 and
            dh_ratio < 0.25 and
            fatigue.high_fatigue_days <= 1
        )
        balance_score = (
            (1 - abs(fatigue.average_fatigue - 0.4)) * 0.4 +
            (min(block_hours / 80, 1.0)) * 0.3 +
            (1 - dh_ratio) * 0.3
        )
        return ClassifierResult(matches=matches, tag=self.tag,
                                confidence=balance_score)


# ── Tag metadata ──────────────────────────────────────────────────────────────

TAG_META: dict[LineTag, dict] = {
    LineTag.HIGH_FATIGUE:         {"label": "High Fatigue",          "color": "#EF4444", "icon": "⚠️"},
    LineTag.RECOVERY_FRIENDLY:    {"label": "Recovery Friendly",      "color": "#22C55E", "icon": "🟢"},
    LineTag.HEAVY_DEADHEAD:       {"label": "Heavy Deadhead",         "color": "#3B82F6", "icon": "🔄"},
    LineTag.HIGH_INCOME:          {"label": "High Income",            "color": "#D4AF37", "icon": "💰"},
    LineTag.INTERNATIONAL_HEAVY:  {"label": "International Heavy",    "color": "#8B5CF6", "icon": "🌍"},
    LineTag.EARLY_SIGNIN_HEAVY:   {"label": "Early Sign-In Heavy",    "color": "#F59E0B", "icon": "🌅"},
    LineTag.LONG_DUTY:            {"label": "Long Duty",              "color": "#F97316", "icon": "⏱️"},
    LineTag.NIGHT_HEAVY:          {"label": "Night Heavy",            "color": "#6366F1", "icon": "🌙"},
    LineTag.SHORT_HAUL_INTENSIVE: {"label": "Short-Haul Intensive",   "color": "#06B6D4", "icon": "✈️"},
    LineTag.OPTIMAL_BALANCE:      {"label": "Optimal Balance",        "color": "#10B981", "icon": "⭐"},
    LineTag.STANDARD:             {"label": "Standard Line",          "color": "#64748B", "icon": "📋"},
}


class ClassificationEngine:

    CLASSIFIERS = [
        HighFatigueClassifier(),
        RecoveryFriendlyClassifier(),
        HeavyDeadheadClassifier(),
        HighIncomeClassifier(),
        InternationalHeavyClassifier(),
        EarlySignInClassifier(),
        LongDutyClassifier(),
        NightHeavyClassifier(),
        ShortHaulIntensiveClassifier(),
        OptimalBalanceClassifier(),
    ]

    def classify(
        self,
        pairings: list[Pairing],
        fatigue: LineFatigueProfile,
    ) -> LineClassification:
        tags:   list[LineTag]    = []
        scores: dict[str, float] = {}

        for clf in self.CLASSIFIERS:
            result = clf.evaluate(pairings, fatigue)
            if result.matches:
                tags.append(result.tag)
                scores[result.tag.value] = result.confidence

        if not tags:
            primary = LineTag.STANDARD
        else:
            primary = max(scores, key=lambda k: scores[k])
            primary = LineTag(primary)

        meta = TAG_META.get(primary, TAG_META[LineTag.STANDARD])

        return LineClassification(
            primary=primary,
            all_tags=tags or [LineTag.STANDARD],
            scores=scores,
            label=meta["label"],
            color=meta["color"],
            icon=meta["icon"],
        )
