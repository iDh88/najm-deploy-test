"""
Crew Intelligence Platform — Legality Engine
Implements GACA/ICAO FTL rules with backward AND forward rest checks.
Every rule is configurable via Firestore — no hardcoded values in business logic.
"""

import logging
from datetime import datetime, timedelta
from typing import Optional
from enum import Enum

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

# ── FTL values: SINGLE SOURCE OF TRUTH is legality/rules_source.py ──────────
# (GOM Section 7.5.3 Table F canonical set + runtime admin overrides from the
# Firestore `legalityRules` collection). Do NOT hardcode regulatory numbers
# here — see rules_source.CANONICAL_DEFAULTS and OWNER_DECISION_REQUEST.md.
from legality.rules_source import (
    CANONICAL_DEFAULTS,
    get_effective_rules,
    fdp_limit_minutes as _shared_fdp_limit_minutes,
    RULE_METADATA,
    RULES_BASE_VERSION,
)
# ─────────────────────────────────────────────────────────────────────────────



logger = logging.getLogger("cip.legality")
router = APIRouter()

# ─── Rule Definitions ─────────────────────────────────────────────────────────

class LegType(str, Enum):
    domestic = "domestic"
    international = "international"
    positioning = "positioning"

class Severity(str, Enum):
    blocking = "blocking"
    warning = "warning"

class FTLRules(BaseModel):
    """All configurable FTL rule thresholds.

    Field defaults come from rules_source.CANONICAL_DEFAULTS (the single
    source of truth). At runtime, use FTLRules.effective() to also apply any
    admin overrides from the Firestore `legalityRules` collection.
    """

    # Rest minimums (from Release Time = Duty End + release buffer)
    min_rest_domestic_hours: float = CANONICAL_DEFAULTS["min_rest_domestic_hours"]
    min_rest_international_hours: float = CANONICAL_DEFAULTS["min_rest_international_hours"]
    min_rest_augmented_hours: float = CANONICAL_DEFAULTS["min_rest_augmented_hours"]

    # Release time buffer
    release_buffer_minutes: float = CANONICAL_DEFAULTS["release_buffer_minutes"]

    # FDP flat caps (a per-sector table ALSO applies — see rules_source, ODR-002)
    max_fdp_domestic_hours: float = CANONICAL_DEFAULTS["max_fdp_domestic_hours"]
    max_fdp_international_hours: float = CANONICAL_DEFAULTS["max_fdp_international_hours"]
    max_fdp_augmented_hours: float = CANONICAL_DEFAULTS["max_fdp_augmented_hours"]

    # Daily flight time
    max_daily_block_hours: float = CANONICAL_DEFAULTS["max_daily_block_hours"]

    # Sector limits per FDP
    max_sectors_short_haul: int = int(CANONICAL_DEFAULTS["max_sectors_short_haul"])
    max_sectors_long_haul: int = int(CANONICAL_DEFAULTS["max_sectors_long_haul"])
    long_haul_threshold_hours: float = CANONICAL_DEFAULTS["long_haul_threshold_hours"]

    # Cumulative limits
    max_7day_flight_hours: float = CANONICAL_DEFAULTS["max_7day_flight_hours"]
    min_7day_days_off: int = int(CANONICAL_DEFAULTS["min_7day_days_off"])
    max_28day_flight_hours: float = CANONICAL_DEFAULTS["max_28day_flight_hours"]
    max_monthly_duty_hours: float = CANONICAL_DEFAULTS["max_monthly_duty_hours"]
    max_annual_flight_hours: float = CANONICAL_DEFAULTS["max_annual_flight_hours"]

    # Layover
    min_layover_away_from_base_hours: float = CANONICAL_DEFAULTS["min_layover_away_from_base_hours"]
    away_from_base_trigger_hours: float = CANONICAL_DEFAULTS["away_from_base_trigger_hours"]

    # Warning thresholds (% of limit that triggers amber warning)
    warning_threshold_pct: float = CANONICAL_DEFAULTS["warning_threshold_pct"]

    @classmethod
    def effective(cls) -> "FTLRules":
        """Canonical defaults + live admin overrides (fail-safe to defaults)."""
        eff = get_effective_rules()
        known = set(cls.model_fields) if hasattr(cls, "model_fields") else set(cls.__fields__)
        return cls(**{k: v for k, v in eff.values.items() if k in known})

DEFAULT_RULES = FTLRules()

# ─── Pydantic Models ─────────────────────────────────────────────────────────

class DutyPeriod(BaseModel):
    id: str
    flight_number: str
    origin: str
    destination: str
    leg_type: LegType
    duty_start: datetime      # UTC
    duty_end: datetime        # UTC
    release_time: datetime    # duty_end + 30min buffer
    block_hours: float
    fdp_hours: float
    is_augmented: bool = False
    sector_count: int = 1

class LegalityViolation(BaseModel):
    rule_id: str
    rule_description: str
    rule_description_ar: str
    actual_value: float
    required_value: float
    unit: str
    severity: Severity
    affected_leg_ids: list[str] = []

class LegalityResult(BaseModel):
    passed: bool
    violations: list[LegalityViolation] = []
    warnings: list[LegalityViolation] = []
    checked_at: datetime = Field(default_factory=datetime.utcnow)
    # Overwritten per-request by the endpoints with real provenance (see
    # _resolve_rules); this default only appears if the model is constructed
    # directly. Kept aligned with the canonical base version string.
    rules_version: str = f"{RULES_BASE_VERSION} (defaults)"

class LegalityCheckRequest(BaseModel):
    crew_schedule: list[DutyPeriod]
    proposed_duty: Optional[DutyPeriod] = None  # If None: check existing schedule only
    # None → the EFFECTIVE rules (canonical defaults + admin overrides) are used.
    # A caller-supplied value is honored for what-if analysis, and the result's
    # rules_version is marked "caller-supplied (what-if)" so it cannot pass as
    # an official verdict.
    rules: Optional[FTLRules] = None

class TradeCheckRequest(BaseModel):
    initiator_schedule: list[DutyPeriod]
    receiver_schedule: list[DutyPeriod]
    offered_duty: DutyPeriod
    requested_duty: Optional[DutyPeriod] = None
    rules: Optional[FTLRules] = None  # same semantics as LegalityCheckRequest.rules

class TradeCheckResponse(BaseModel):
    initiator_result: LegalityResult
    receiver_result: LegalityResult
    overall_passed: bool

# ─── Core Legality Engine ─────────────────────────────────────────────────────

class LegalityEngine:
    def __init__(self, rules: FTLRules = DEFAULT_RULES):
        self.rules = rules

    def check_schedule(
        self,
        schedule: list[DutyPeriod],
        proposed: Optional[DutyPeriod] = None,
    ) -> LegalityResult:
        """
        Full legality check on a schedule, optionally with a proposed new duty.
        Performs BACKWARD (rest after previous duty) and FORWARD (rest before next duty) checks.
        """
        violations: list[LegalityViolation] = []
        warnings: list[LegalityViolation] = []

        # Insert proposed duty into timeline
        working_schedule = sorted(schedule, key=lambda d: d.duty_start)
        if proposed is not None:
            working_schedule.append(proposed)
            working_schedule.sort(key=lambda d: d.duty_start)

        # ── Per-duty checks ──────────────────────────────────────────────────
        for i, duty in enumerate(working_schedule):
            # FDP check
            fdp_v, fdp_w = self._check_fdp(duty)
            violations.extend(fdp_v)
            warnings.extend(fdp_w)

            # Daily block hours
            blk_v, blk_w = self._check_daily_block(duty)
            violations.extend(blk_v)
            warnings.extend(blk_w)

            # BACKWARD rest: gap from previous duty's release_time to this duty_start
            if i > 0:
                prev = working_schedule[i - 1]
                rest_hours = (duty.duty_start - prev.release_time).total_seconds() / 3600
                bk_v, bk_w = self._check_rest(
                    rest_hours=rest_hours,
                    leg_type=duty.leg_type,
                    direction="backward",
                    duty_id=duty.id,
                    prev_duty_id=prev.id,
                    is_augmented=duty.is_augmented,
                )
                violations.extend(bk_v)
                warnings.extend(bk_w)

            # FORWARD rest: gap from this duty's release_time to next duty_start
            if i < len(working_schedule) - 1:
                next_duty = working_schedule[i + 1]
                rest_hours = (next_duty.duty_start - duty.release_time).total_seconds() / 3600
                fw_v, fw_w = self._check_rest(
                    rest_hours=rest_hours,
                    leg_type=next_duty.leg_type,
                    direction="forward",
                    duty_id=duty.id,
                    next_duty_id=next_duty.id,
                    is_augmented=next_duty.is_augmented,
                )
                violations.extend(fw_v)
                warnings.extend(fw_w)

        # ── Rolling accumulation checks ──────────────────────────────────────
        if working_schedule:
            cum_v, cum_w = self._check_cumulative(working_schedule)
            violations.extend(cum_v)
            warnings.extend(cum_w)

        return LegalityResult(
            passed=len(violations) == 0,
            violations=violations,
            warnings=warnings,
        )

    # ── FDP Check ────────────────────────────────────────────────────────────
    def _check_fdp(self, duty: DutyPeriod) -> tuple[list, list]:
        violations, warnings = [], []
        if duty.is_augmented:
            flat_cap = self.rules.max_fdp_augmented_hours
        elif duty.leg_type == LegType.domestic:
            flat_cap = self.rules.max_fdp_domestic_hours
        else:
            flat_cap = self.rules.max_fdp_international_hours
        # ODR-002 conservative intersection: also honor the per-sector FDP table
        # shared by every engine, so this check is never more permissive than
        # the sector-based model. (fdp_limit_minutes already includes flat_cap
        # when self.rules matches effective rules; recompute with OUR rules'
        # flat cap so caller-supplied what-if rules are respected too.)
        from legality.rules_source import (
            FDP_SECTOR_TABLE_MINUTES, FDP_ABSOLUTE_FLOOR_MINS)
        sector_limit_h = max(
            FDP_SECTOR_TABLE_MINUTES.get(
                max(1, min(duty.sector_count, 6)), FDP_SECTOR_TABLE_MINUTES[6]),
            FDP_ABSOLUTE_FLOOR_MINS,
        ) / 60.0
        max_fdp = min(flat_cap, sector_limit_h)

        warn_threshold = max_fdp * self.rules.warning_threshold_pct

        if duty.fdp_hours > max_fdp:
            violations.append(LegalityViolation(
                rule_id="GACA-FDP-001",
                rule_description=f"Flight Duty Period exceeds maximum ({max_fdp}h)",
                rule_description_ar=f"فترة واجب الطيران تتجاوز الحد الأقصى ({max_fdp} ساعة)",
                actual_value=round(duty.fdp_hours, 2),
                required_value=max_fdp,
                unit="hours",
                severity=Severity.blocking,
                affected_leg_ids=[duty.id],
            ))
        elif duty.fdp_hours > warn_threshold:
            warnings.append(LegalityViolation(
                rule_id="GACA-FDP-001-W",
                rule_description=f"FDP approaching maximum (>{warn_threshold:.1f}h, max {max_fdp}h)",
                rule_description_ar=f"فترة الواجب تقترب من الحد الأقصى",
                actual_value=round(duty.fdp_hours, 2),
                required_value=max_fdp,
                unit="hours",
                severity=Severity.warning,
                affected_leg_ids=[duty.id],
            ))
        return violations, warnings

    # ── Daily Block Hours Check ───────────────────────────────────────────────
    def _check_daily_block(self, duty: DutyPeriod) -> tuple[list, list]:
        violations, warnings = [], []
        max_block = self.rules.max_daily_block_hours

        if duty.block_hours > max_block:
            violations.append(LegalityViolation(
                rule_id="GACA-BLK-001",
                rule_description=f"Daily block hours exceed maximum ({max_block}h)",
                rule_description_ar=f"ساعات الطيران اليومية تتجاوز ({max_block} ساعة)",
                actual_value=round(duty.block_hours, 2),
                required_value=max_block,
                unit="hours",
                severity=Severity.blocking,
                affected_leg_ids=[duty.id],
            ))
        return violations, warnings

    # ── Rest Check (Backward & Forward) ──────────────────────────────────────
    def _check_rest(
        self,
        rest_hours: float,
        leg_type: LegType,
        direction: str,
        duty_id: str = "",
        prev_duty_id: str = "",
        next_duty_id: str = "",
        is_augmented: bool = False,
    ) -> tuple[list, list]:
        violations, warnings = [], []

        if is_augmented:
            # GOM 7.5.3 Table (F): augmented crew rest minimum applies at all
            # stations and supersedes the domestic/international minimum.
            min_rest = self.rules.min_rest_augmented_hours
            rule_id = "GACA-REST-AUG-001"
            rule_ar = f"الراحة الدنيا للطاقم المعزَّز ({min_rest} ساعة من وقت الإفراج)"
            rule_en = f"Minimum rest augmented crew ({min_rest}h from release time)"
        elif leg_type == LegType.domestic:
            min_rest = self.rules.min_rest_domestic_hours
            rule_id = "GACA-REST-DOM-001"
            rule_ar = f"الراحة الدنيا للرحلات الداخلية ({min_rest} ساعة من وقت الإفراج)"
            rule_en = f"Minimum rest domestic ({min_rest}h from release time)"
        else:
            min_rest = self.rules.min_rest_international_hours
            rule_id = "GACA-REST-INTL-001"
            rule_ar = f"الراحة الدنيا للرحلات الدولية ({min_rest} ساعة من وقت الإفراج)"
            rule_en = f"Minimum rest international ({min_rest}h from release time)"

        warn_threshold = min_rest * 1.1  # Warn if rest < 110% of minimum
        affected = [duty_id, prev_duty_id or next_duty_id]

        if rest_hours < min_rest:
            violations.append(LegalityViolation(
                rule_id=f"{rule_id}-{direction.upper()}",
                rule_description=f"{rule_en} [{direction} check] — actual: {rest_hours:.2f}h",
                rule_description_ar=f"{rule_ar} [{direction}]",
                actual_value=round(rest_hours, 2),
                required_value=min_rest,
                unit="hours",
                severity=Severity.blocking,
                affected_leg_ids=[x for x in affected if x],
            ))
        elif rest_hours < warn_threshold:
            warnings.append(LegalityViolation(
                rule_id=f"{rule_id}-{direction.upper()}-W",
                rule_description=f"Rest period approaching minimum ({rest_hours:.1f}h, min {min_rest}h)",
                rule_description_ar=f"فترة الراحة تقترب من الحد الأدنى",
                actual_value=round(rest_hours, 2),
                required_value=min_rest,
                unit="hours",
                severity=Severity.warning,
                affected_leg_ids=[x for x in affected if x],
            ))
        return violations, warnings

    # ── Cumulative Checks ────────────────────────────────────────────────────
    def _check_cumulative(self, schedule: list[DutyPeriod]) -> tuple[list, list]:
        violations, warnings = [], []
        now = schedule[-1].duty_end if schedule else datetime.utcnow()

        # 7-day rolling window
        window_7d = [d for d in schedule if d.duty_start >= now - timedelta(days=7)]
        hours_7d = sum(d.block_hours for d in window_7d)

        if hours_7d > self.rules.max_7day_flight_hours:
            violations.append(LegalityViolation(
                rule_id="GACA-CUM-7D-001",
                rule_description=f"7-day flight hours exceed {self.rules.max_7day_flight_hours}h",
                rule_description_ar=f"ساعات الطيران في 7 أيام تتجاوز {self.rules.max_7day_flight_hours} ساعة",
                actual_value=round(hours_7d, 2),
                required_value=self.rules.max_7day_flight_hours,
                unit="hours",
                severity=Severity.blocking,
                affected_leg_ids=[d.id for d in window_7d],
            ))
        elif hours_7d > self.rules.max_7day_flight_hours * self.rules.warning_threshold_pct:
            warnings.append(LegalityViolation(
                rule_id="GACA-CUM-7D-001-W",
                rule_description=f"Approaching 7-day limit ({hours_7d:.1f}/{self.rules.max_7day_flight_hours}h)",
                rule_description_ar="تقترب من حد 7 أيام",
                actual_value=round(hours_7d, 2),
                required_value=self.rules.max_7day_flight_hours,
                unit="hours",
                severity=Severity.warning,
                affected_leg_ids=[d.id for d in window_7d],
            ))

        # Minimum 1 day off in 7-day window
        duty_dates = {d.duty_start.date() for d in window_7d}
        days_in_window = 7
        days_off_7d = days_in_window - len(duty_dates)
        if days_off_7d < self.rules.min_7day_days_off:
            violations.append(LegalityViolation(
                rule_id="GACA-CUM-7D-002",
                rule_description=f"Must have ≥{self.rules.min_7day_days_off} day(s) off in any 7-day window",
                rule_description_ar=f"يجب أن يكون هناك {self.rules.min_7day_days_off} يوم إجازة في كل 7 أيام",
                actual_value=max(0, days_off_7d),
                required_value=self.rules.min_7day_days_off,
                unit="days",
                severity=Severity.blocking,
                affected_leg_ids=[d.id for d in window_7d],
            ))

        # 28-day rolling window
        window_28d = [d for d in schedule if d.duty_start >= now - timedelta(days=28)]
        hours_28d = sum(d.block_hours for d in window_28d)

        if hours_28d > self.rules.max_28day_flight_hours:
            violations.append(LegalityViolation(
                rule_id="GACA-CUM-28D-001",
                rule_description=f"28-day flight hours exceed {self.rules.max_28day_flight_hours}h",
                rule_description_ar=f"ساعات الطيران في 28 يوماً تتجاوز الحد",
                actual_value=round(hours_28d, 2),
                required_value=self.rules.max_28day_flight_hours,
                unit="hours",
                severity=Severity.blocking,
                affected_leg_ids=[d.id for d in window_28d],
            ))

        # Monthly duty hours
        month_duties = [d for d in schedule if
                        d.duty_start.month == now.month and d.duty_start.year == now.year]
        monthly_duty = sum(d.fdp_hours for d in month_duties)

        if monthly_duty > self.rules.max_monthly_duty_hours:
            violations.append(LegalityViolation(
                rule_id="GACA-CUM-MON-001",
                rule_description=f"Monthly duty hours exceed {self.rules.max_monthly_duty_hours}h",
                rule_description_ar=f"ساعات الواجب الشهرية تتجاوز الحد",
                actual_value=round(monthly_duty, 2),
                required_value=self.rules.max_monthly_duty_hours,
                unit="hours",
                severity=Severity.blocking,
                affected_leg_ids=[d.id for d in month_duties],
            ))
        elif monthly_duty > self.rules.max_monthly_duty_hours * self.rules.warning_threshold_pct:
            warnings.append(LegalityViolation(
                rule_id="GACA-CUM-MON-001-W",
                rule_description=f"Monthly duty approaching limit ({monthly_duty:.1f}/{self.rules.max_monthly_duty_hours}h)",
                rule_description_ar="ساعات الواجب الشهرية تقترب من الحد",
                actual_value=round(monthly_duty, 2),
                required_value=self.rules.max_monthly_duty_hours,
                unit="hours",
                severity=Severity.warning,
                affected_leg_ids=[d.id for d in month_duties],
            ))

        return violations, warnings

# ─── API Endpoints ────────────────────────────────────────────────────────────

def _resolve_rules(supplied: Optional[FTLRules]) -> tuple[FTLRules, str]:
    """Return (rules, rules_version). Omitted → effective (admin-configured)
    rules with real provenance; caller-supplied → what-if marker so the result
    can never be mistaken for an official verdict."""
    if supplied is not None:
        return supplied, "caller-supplied (what-if)"
    return FTLRules.effective(), get_effective_rules().version


@router.get("/rules")
async def get_effective_ftl_rules() -> dict:
    """The EFFECTIVE FTL rule set (canonical defaults + admin overrides from
    the `legalityRules` collection), with provenance. This is the value set
    every legality/rest/intelligence engine and the AI grounding use."""
    eff = get_effective_rules()
    return {
        "version": eff.version,
        "source": eff.source,
        "overridden_fields": list(eff.overridden_fields),
        "values": eff.values,
        "metadata": RULE_METADATA,
    }


@router.post("/check", response_model=LegalityResult)
async def check_legality(request: LegalityCheckRequest) -> LegalityResult:
    rules, version = _resolve_rules(request.rules)
    engine = LegalityEngine(rules)
    result = engine.check_schedule(request.crew_schedule, request.proposed_duty)
    result.rules_version = version
    return result

@router.post("/check-trade", response_model=TradeCheckResponse)
async def check_trade_legality(request: TradeCheckRequest) -> TradeCheckResponse:
    rules, version = _resolve_rules(request.rules)
    engine = LegalityEngine(rules)

    # Build post-trade schedules for both parties
    initiator_new_schedule = [
        d for d in request.initiator_schedule if d.id != request.offered_duty.id
    ]
    if request.requested_duty:
        initiator_new_schedule.append(request.requested_duty)

    receiver_new_schedule = list(request.receiver_schedule)
    if request.requested_duty:
        receiver_new_schedule = [
            d for d in request.receiver_schedule if d.id != request.requested_duty.id
        ]
    receiver_new_schedule.append(request.offered_duty)

    initiator_result = engine.check_schedule(initiator_new_schedule)
    receiver_result = engine.check_schedule(receiver_new_schedule)
    initiator_result.rules_version = version
    receiver_result.rules_version = version

    return TradeCheckResponse(
        initiator_result=initiator_result,
        receiver_result=receiver_result,
        overall_passed=initiator_result.passed and receiver_result.passed,
    )
