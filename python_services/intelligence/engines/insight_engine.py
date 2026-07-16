"""Insight engine — generates Arabic + English operational intelligence."""
from __future__ import annotations
from ..models.pairing_models import Pairing
from ..models.analytics_models import MonthlyAnalytics
from ..models.fatigue_models import FatigueLevel
from ..models.insight_models import Insight, InsightType, InsightCategory


class InsightEngine:

    FLEET_AVG_BLOCK = 72.0   # fleet average block hours/month

    def generate(self, pairings: list[Pairing],
                 analytics: MonthlyAnalytics) -> list[Insight]:
        insights: list[Insight] = []
        fp = analytics.fatigue_profile

        # ── Fatigue ────────────────────────────────────────────────────────
        if fp.average_fatigue > 0.60:
            insights.append(Insight(
                type=InsightType.WARNING,
                category=InsightCategory.FATIGUE,
                icon="⚠️",
                title_en="High Fatigue Line",
                body_en=(
                    f"This line averages {fp.fatigue_percentage}% fatigue load "
                    f"with {fp.high_fatigue_days} high-fatigue duty days. "
                    "Ensure adequate rest and monitor cumulative fatigue."
                ),
                title_ar="خط إجهاد عالٍ",
                body_ar=(
                    f"يبلغ متوسط الإجهاد في هذا الخط {fp.fatigue_percentage}% "
                    f"مع {fp.high_fatigue_days} أيام خدمة بإجهاد مرتفع. "
                    "تأكد من الحصول على راحة كافية ومراقبة تراكم الإجهاد."
                ),
                priority=1,
                metric_value=f"{fp.fatigue_percentage}%",
            ))
        elif fp.average_fatigue < 0.35:
            insights.append(Insight(
                type=InsightType.POSITIVE,
                category=InsightCategory.FATIGUE,
                icon="✅",
                title_en="Low Fatigue Profile",
                body_en=(
                    f"This line maintains a low fatigue profile at "
                    f"{fp.fatigue_percentage}% average. "
                    "Good recovery spacing throughout the month."
                ),
                title_ar="مستوى إجهاد منخفض",
                body_ar=(
                    f"يحافظ هذا الخط على مستوى إجهاد منخفض بمتوسط "
                    f"{fp.fatigue_percentage}%. "
                    "توزيع جيد لفترات الراحة خلال الشهر."
                ),
                priority=3,
                metric_value=f"{fp.fatigue_percentage}%",
            ))

        # ── Early sign-ins ─────────────────────────────────────────────────
        if fp.early_signin_count >= 3:
            insights.append(Insight(
                type=InsightType.WARNING,
                category=InsightCategory.FATIGUE,
                icon="🌅",
                title_en="Frequent Early Sign-Ins",
                body_en=(
                    f"{fp.early_signin_count} pairings require sign-in before 06:00. "
                    "Early operations significantly increase fatigue risk "
                    "due to circadian disruption."
                ),
                title_ar="إبلاغ مبكر متكرر",
                body_ar=(
                    f"{fp.early_signin_count} أزواج تستلزم الإبلاغ قبل الساعة 06:00. "
                    "تزيد العمليات المبكرة بشكل ملحوظ من خطر الإجهاد "
                    "بسبب اضطراب الإيقاع اليومي."
                ),
                priority=2,
                metric_value=f"{fp.early_signin_count} duties",
            ))

        # ── WOCL ───────────────────────────────────────────────────────────
        if fp.wocl_total_minutes > 120:
            wocl_hrs = fp.wocl_total_minutes // 60
            insights.append(Insight(
                type=InsightType.WARNING,
                category=InsightCategory.FATIGUE,
                icon="🌙",
                title_en="WOCL Window Operations",
                body_en=(
                    f"{wocl_hrs}h of operations fall within the Window of "
                    "Circadian Low (02:00–05:59). This significantly degrades "
                    "alertness and reaction time."
                ),
                title_ar="عمليات في نافذة الانخفاض اليومي",
                body_ar=(
                    f"{wocl_hrs} ساعة من العمليات تقع ضمن نافذة الانخفاض اليومي "
                    "(02:00–05:59). يؤثر هذا بشكل كبير على اليقظة ووقت رد الفعل."
                ),
                priority=2,
                metric_value=f"{wocl_hrs}h",
            ))

        # ── Recovery windows ───────────────────────────────────────────────
        best = fp.best_recovery_window
        if best:
            insights.append(Insight(
                type=InsightType.POSITIVE,
                category=InsightCategory.RECOVERY,
                icon="🟢",
                title_en="Strong Recovery Window",
                body_en=(
                    f"Days {best.start_day.day}–{best.end_day.day} offer "
                    f"{int(best.duration_hours / 24)} consecutive rest days. "
                    "Ideal period for full fatigue recovery."
                ),
                title_ar="نافذة تعافٍ قوية",
                body_ar=(
                    f"الأيام {best.start_day.day}–{best.end_day.day} توفر "
                    f"{int(best.duration_hours / 24)} أيام راحة متتالية. "
                    "فترة مثالية للتعافي الكامل من الإجهاد."
                ),
                priority=3,
                metric_value=f"{int(best.duration_hours/24)} days",
            ))

        # ── Deadhead ───────────────────────────────────────────────────────
        dh_pct = int(analytics.deadhead_ratio * 100)
        if dh_pct > 35:
            insights.append(Insight(
                type=InsightType.INFO,
                category=InsightCategory.OPERATIONS,
                icon="🔄",
                title_en="Heavy Deadhead Operations",
                body_en=(
                    f"{analytics.total_deadhead_legs} deadhead legs ({dh_pct}% "
                    "of all operations). High positioning overhead — "
                    "this affects income efficiency."
                ),
                title_ar="عمليات توجيه مكثفة",
                body_ar=(
                    f"{analytics.total_deadhead_legs} رحلة توجيه ({dh_pct}% "
                    "من إجمالي العمليات). تكاليف توضع عالية — "
                    "يؤثر هذا على كفاءة الدخل."
                ),
                priority=3,
                metric_value=f"{dh_pct}%",
            ))

        # ── Income ─────────────────────────────────────────────────────────
        if analytics.total_block_hours > self.FLEET_AVG_BLOCK * 1.10:
            pct_above = int((analytics.total_block_hours / self.FLEET_AVG_BLOCK - 1) * 100)
            insights.append(Insight(
                type=InsightType.POSITIVE,
                category=InsightCategory.INCOME,
                icon="💰",
                title_en="Above-Average Block Hours",
                body_en=(
                    f"{analytics.total_block_hours:.1f} block hours — "
                    f"{pct_above}% above fleet average. "
                    "Strong income potential this month."
                ),
                title_ar="ساعات طيران فوق المتوسط",
                body_ar=(
                    f"{analytics.total_block_hours:.1f} ساعة طيران — "
                    f"أعلى بـ{pct_above}% من متوسط الأسطول. "
                    "إمكانات دخل قوية هذا الشهر."
                ),
                priority=2,
                metric_value=f"{analytics.total_block_hours:.1f}h",
            ))
        elif analytics.total_block_hours < self.FLEET_AVG_BLOCK * 0.85:
            insights.append(Insight(
                type=InsightType.INFO,
                category=InsightCategory.INCOME,
                icon="📉",
                title_en="Below-Average Block Hours",
                body_en=(
                    f"{analytics.total_block_hours:.1f} block hours — "
                    "below fleet average. Consider open day pickups to "
                    "improve monthly credit."
                ),
                title_ar="ساعات طيران دون المتوسط",
                body_ar=(
                    f"{analytics.total_block_hours:.1f} ساعة طيران — "
                    "دون متوسط الأسطول. فكر في التقاط الأيام المفتوحة "
                    "لتحسين الرصيد الشهري."
                ),
                priority=3,
                metric_value=f"{analytics.total_block_hours:.1f}h",
            ))

        # ── International heavy ────────────────────────────────────────────
        if analytics.international_count > analytics.domestic_count * 1.5:
            insights.append(Insight(
                type=InsightType.INFO,
                category=InsightCategory.OPERATIONS,
                icon="🌍",
                title_en="International-Heavy Schedule",
                body_en=(
                    f"{analytics.international_count} international legs vs "
                    f"{analytics.domestic_count} domestic. "
                    "Higher per-diem potential with increased jet lag risk."
                ),
                title_ar="جدول دولي مكثف",
                body_ar=(
                    f"{analytics.international_count} رحلة دولية مقابل "
                    f"{analytics.domestic_count} داخلية. "
                    "إمكانية بدل يومي أعلى مع زيادة خطر اضطراب الرحلات."
                ),
                priority=4,
                metric_value=f"{analytics.international_count} intl",
            ))

        # ── Legality warnings ──────────────────────────────────────────────
        illegal_pairings = [p for p in pairings if not p.legality.is_fully_legal]
        if illegal_pairings:
            insights.append(Insight(
                type=InsightType.WARNING,
                category=InsightCategory.LEGALITY,
                icon="🚨",
                title_en="Legality Issues Detected",
                body_en=(
                    f"{len(illegal_pairings)} pairing(s) may have legality "
                    "violations. Review FDP limits and rest requirements "
                    "before operating."
                ),
                title_ar="تم اكتشاف مشاكل قانونية",
                body_ar=(
                    f"قد تحتوي {len(illegal_pairings)} زوج على انتهاكات قانونية. "
                    "راجع حدود فترة واجب الرحلة ومتطلبات الراحة قبل التشغيل."
                ),
                priority=1,
                metric_value=f"{len(illegal_pairings)} pairings",
            ))

        return sorted(insights, key=lambda x: x.priority)
