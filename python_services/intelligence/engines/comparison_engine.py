"""Comparison engine — line vs line, pairing vs pairing."""
from __future__ import annotations
from ..models.pairing_models import Pairing
from ..models.analytics_models import MonthlyAnalytics, LineComparison
from ..models.fatigue_models import FatigueLevel


class ComparisonEngine:

    def compare_lines(
        self,
        analytics_a: MonthlyAnalytics,
        analytics_b: MonthlyAnalytics,
        pairings_a: list[Pairing],
        pairings_b: list[Pairing],
    ) -> LineComparison:

        # Radar axes: higher = better (normalize 0–1)
        radar_a = self._build_radar(analytics_a, pairings_a)
        radar_b = self._build_radar(analytics_b, pairings_b)

        block_delta    = analytics_a.total_block_hours - analytics_b.total_block_hours
        duty_delta     = analytics_a.total_duty_hours  - analytics_b.total_duty_hours
        fatigue_delta  = (analytics_a.fatigue_profile.average_fatigue -
                          analytics_b.fatigue_profile.average_fatigue)
        income_delta   = analytics_a.estimated_credit - analytics_b.estimated_credit
        dh_delta       = analytics_a.total_deadhead_legs - analytics_b.total_deadhead_legs
        recovery_delta = (
            sum(w.duration_hours for w in analytics_a.fatigue_profile.recovery_windows) -
            sum(w.duration_hours for w in analytics_b.fatigue_profile.recovery_windows)
        )
        legal_a = sum(1 for p in pairings_a if p.legality.is_fully_legal) / max(len(pairings_a),1)
        legal_b = sum(1 for p in pairings_b if p.legality.is_fully_legal) / max(len(pairings_b),1)
        legality_delta = legal_a - legal_b

        winner, reason_en, reason_ar = self._declare_winner(
            analytics_a, analytics_b, radar_a, radar_b
        )

        rec_en, rec_ar = self._recommendation(
            analytics_a, analytics_b, winner
        )

        return LineComparison(
            line_a_id=analytics_a.line_id,
            line_b_id=analytics_b.line_id,
            line_a_label=f"Line {analytics_a.line_id}",
            line_b_label=f"Line {analytics_b.line_id}",
            block_hours_delta=round(block_delta, 1),
            duty_hours_delta=round(duty_delta, 1),
            fatigue_delta=round(fatigue_delta, 3),
            income_delta=round(income_delta, 1),
            deadhead_delta=dh_delta,
            recovery_delta=round(recovery_delta, 1),
            legality_delta=round(legality_delta, 3),
            line_a_radar=radar_a,
            line_b_radar=radar_b,
            winner=winner,
            winner_reason=reason_en,
            recommendation=rec_ar,
            recommendation_en=rec_en,
        )

    def _build_radar(
        self, analytics: MonthlyAnalytics, pairings: list[Pairing]
    ) -> dict[str, float]:
        """Build radar chart scores (0–1, higher = better)."""
        # Fatigue: invert (lower fatigue = better score)
        fatigue_score = 1.0 - analytics.fatigue_profile.average_fatigue

        # Income: normalize to 0–1 (100h = 1.0)
        income_score = min(analytics.estimated_credit / 100, 1.0)

        # Recovery: normalize total recovery hours (100h = 1.0)
        rec_hrs = sum(w.duration_hours
                      for w in analytics.fatigue_profile.recovery_windows)
        recovery_score = min(rec_hrs / 100, 1.0)

        # Deadhead efficiency: lower deadhead ratio = better
        dh_score = 1.0 - analytics.deadhead_ratio

        # Legality: % of legal pairings
        legal_score = sum(
            1 for p in pairings if p.legality.is_fully_legal
        ) / max(len(pairings), 1)

        # Duty efficiency: block/duty ratio (higher = more flying, less ground)
        duty_eff = (analytics.total_block_hours /
                    max(analytics.total_duty_hours, 1))
        duty_score = min(duty_eff / 0.8, 1.0)

        return {
            "fatigue":   round(fatigue_score, 3),
            "income":    round(income_score, 3),
            "recovery":  round(recovery_score, 3),
            "deadhead":  round(dh_score, 3),
            "legality":  round(legal_score, 3),
            "efficiency":round(duty_score, 3),
        }

    def _declare_winner(
        self,
        a: MonthlyAnalytics,
        b: MonthlyAnalytics,
        radar_a: dict,
        radar_b: dict,
    ) -> tuple[str, str, str]:
        score_a = sum(radar_a.values())
        score_b = sum(radar_b.values())
        diff    = abs(score_a - score_b)

        if diff < 0.2:
            return "EQUAL", "Both lines are closely matched overall.", \
                   "كلا الخطين متقاربان بشكل عام."
        elif score_a > score_b:
            return "A", \
                   f"Line {a.line_id} scores better overall ({score_a:.2f} vs {score_b:.2f}).", \
                   f"الخط {a.line_id} يتفوق بشكل عام ({score_a:.2f} مقابل {score_b:.2f})."
        else:
            return "B", \
                   f"Line {b.line_id} scores better overall ({score_b:.2f} vs {score_a:.2f}).", \
                   f"الخط {b.line_id} يتفوق بشكل عام ({score_b:.2f} مقابل {score_a:.2f})."

    def _recommendation(
        self, a: MonthlyAnalytics, b: MonthlyAnalytics, winner: str
    ) -> tuple[str, str]:
        if winner == "EQUAL":
            en = ("Both lines are comparable. Choose based on personal preference "
                  "for schedule pattern or destination variety.")
            ar = ("كلا الخطين متشابهان. اختر بناءً على تفضيلك الشخصي "
                  "لنمط الجدول الزمني أو تنوع الوجهات.")
        elif winner == "A":
            key_adv = self._key_advantage(a, b)
            en = f"Line {a.line_id} is recommended. {key_adv}"
            ar = f"يُوصى بالخط {a.line_id}. {self._key_advantage_ar(a, b)}"
        else:
            key_adv = self._key_advantage(b, a)
            en = f"Line {b.line_id} is recommended. {key_adv}"
            ar = f"يُوصى بالخط {b.line_id}. {self._key_advantage_ar(b, a)}"
        return en, ar

    def _key_advantage(self, winner: MonthlyAnalytics,
                       loser: MonthlyAnalytics) -> str:
        if winner.fatigue_profile.average_fatigue < loser.fatigue_profile.average_fatigue - 0.1:
            return "Significantly lower fatigue load."
        if winner.estimated_credit > loser.estimated_credit + 5:
            return f"{winner.estimated_credit - loser.estimated_credit:.1f} more credit hours."
        if winner.total_deadhead_legs < loser.total_deadhead_legs - 2:
            return "Fewer deadhead operations."
        return "Better overall operational balance."

    def _key_advantage_ar(self, winner: MonthlyAnalytics,
                           loser: MonthlyAnalytics) -> str:
        if winner.fatigue_profile.average_fatigue < loser.fatigue_profile.average_fatigue - 0.1:
            return "حمل إجهاد أقل بكثير."
        if winner.estimated_credit > loser.estimated_credit + 5:
            diff = winner.estimated_credit - loser.estimated_credit
            return f"ساعات ائتمان أكثر بـ{diff:.1f}."
        if winner.total_deadhead_legs < loser.total_deadhead_legs - 2:
            return "عمليات توجيه أقل."
        return "توازن تشغيلي أفضل بشكل عام."
