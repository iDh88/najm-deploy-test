"""
Saudi Airlines Official Salary Calculator
Based on the 5 official rules:
1. Productivity Allowance (block hours tiers)
2. Monthly Flying Bonus (% of basic salary)
3. Layover Expenses (domestic 11 SAR/hr, international 14.5 SAR/hr)
4. Overtime (basic ÷ guarantee hours × credit hours above guarantee)
5. Flying on Days Off (60 SAR/hr, min 150 SAR per pairing)
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from dataclasses import dataclass
from typing import Optional

router = APIRouter()


# ─── Constants ────────────────────────────────────────────────────────────────

# Productivity Allowance tiers (SAR per block hour)
PRODUCTIVITY_TIERS = [
    (0,    50.00, 0),      # < 50h  → no allowance
    (50.01, 65.00, 75),    # 50:01–65:00 → 75 SAR/hr
    (65.01, 80.00, 90),    # 65:01–80:00 → 90 SAR/hr
    (80.01, float('inf'), 110),  # 80:01+ → 110 SAR/hr
]

# Flying Bonus tiers (min_hours, max_hours, % of basic, fixed_amount)
FLYING_BONUS_TIERS = [
    (0,     65.00, 0.000, 0),    # < 65h → no bonus
    (65.01, 75.00, 0.035, 150),  # 65:01–75:00 → 3.5% + 150
    (75.01, 85.00, 0.060, 250),  # 75:01–85:00 → 6% + 250
    (85.01, float('inf'), 0.080, 350),  # 85:01+ → 8% + 350
]

# Layover rates (SAR per hour)
DOMESTIC_LAYOVER_RATE      = 11.0
INTERNATIONAL_LAYOVER_RATE = 14.5

# Days off flying
DAYS_OFF_RATE_PER_HOUR = 60.0
DAYS_OFF_MIN_PER_PAIRING = 150.0

# Guarantee hours by base
GUARANTEE_HOURS = {
    "RUH": 70,
    "JED": 70,
    "BOM": 72,
    "KHI": 72,
    "DEL": 72,
    "CMN": 72,
    "MNL": 76,
    "CGK": 76,
}
DEFAULT_GUARANTEE_HOURS = 70


# ─── Models ───────────────────────────────────────────────────────────────────

class SalaryInput(BaseModel):
    userId: str
    rankCode: str          # GD, PCA, BUT, CHF, SNF, YCA, CA, FO
    baseStation: str       # RUH, JED, etc.
    basicSalary: float     # User's personal basic salary (SAR)
    totalBlockHours: float # Total block hours this month

    # Layover details per leg
    domesticLayoverHours: float = 0.0
    internationalLayoverHours: float = 0.0

    # Days off flying
    daysOffFlyingHours: float = 0.0
    daysOffPairingsCount: int = 0


class SalaryBreakdown(BaseModel):
    # Inputs used
    rankCode: str
    baseStation: str
    basicSalary: float
    totalBlockHours: float
    guaranteeHours: int

    # 1. Productivity Allowance
    productivityRate: float        # SAR/hr rate applied
    productivityAllowance: float   # Total SAR
    productivityNote: str

    # 2. Flying Bonus
    flyingBonusPercent: float      # e.g. 0.035 = 3.5%
    flyingBonusFromSalary: float   # % × basic
    flyingBonusFixed: float        # Fixed SAR amount
    flyingBonusTotal: float
    flyingBonusNote: str

    # 3. Layover Expenses
    domesticLayoverHours: float
    domesticLayoverAmount: float
    internationalLayoverHours: float
    internationalLayoverAmount: float
    totalLayoverExpenses: float

    # 4. Overtime
    creditHours: float             # = block hours (no TVL/TR/SB)
    overtimeHours: float           # credit - guarantee (0 if below)
    overtimeRate: float            # basic ÷ guarantee
    overtimeAmount: float
    overtimeNote: str

    # 5. Days Off
    daysOffFlyingHours: float
    daysOffPairingsCount: int
    daysOffAmount: float
    daysOffNote: str

    # Totals
    totalSalary: float
    totalSalaryNote: str

    # Display strings
    summaryLines: list[str]


# ─── Calculator ───────────────────────────────────────────────────────────────

class SalaryCalculator:

    def calculate(self, inp: SalaryInput) -> SalaryBreakdown:
        block = inp.totalBlockHours
        basic = inp.basicSalary
        guarantee = GUARANTEE_HOURS.get(inp.baseStation, DEFAULT_GUARANTEE_HOURS)

        # ── 1. Productivity Allowance ────────────────────────────────────────
        prod_rate, prod_amount, prod_note = self._productivity(block)

        # ── 2. Flying Bonus ──────────────────────────────────────────────────
        bonus_pct, bonus_from_salary, bonus_fixed, bonus_total, bonus_note = \
            self._flying_bonus(block, basic)

        # ── 3. Layover Expenses ──────────────────────────────────────────────
        dom_amount  = inp.domesticLayoverHours * DOMESTIC_LAYOVER_RATE
        intl_amount = inp.internationalLayoverHours * INTERNATIONAL_LAYOVER_RATE
        layover_total = dom_amount + intl_amount

        # ── 4. Overtime ──────────────────────────────────────────────────────
        credit_hours = block  # Only block hours (no TVL/TR/SB in Excel)
        ot_hours   = max(0.0, credit_hours - guarantee)
        ot_rate    = (basic / guarantee) if guarantee > 0 else 0

        # GOM 1.25.5: first 20h above MGT at 1:1, beyond 20h at 1.5:1
        if ot_hours <= 0:
            ot_amount = 0.0
            ot_note   = f"No overtime (credit {credit_hours:.2f}h ≤ guarantee {guarantee}h)"
        elif ot_hours <= 20:
            ot_amount = ot_hours * ot_rate
            ot_note   = (f"{ot_hours:.2f}h × SAR {ot_rate:.4f}/hr (1:1 rate) "
                         f"= SAR {ot_amount:.2f}")
        else:
            first_band  = 20 * ot_rate
            second_band = (ot_hours - 20) * ot_rate * 1.5
            ot_amount   = first_band + second_band
            ot_note     = (f"First 20h × {ot_rate:.4f} = {first_band:.2f} + "
                           f"{ot_hours-20:.2f}h × {ot_rate:.4f} × 1.5 = {second_band:.2f} "
                           f"→ SAR {ot_amount:.2f}")

        # ── 5. Days Off Flying ───────────────────────────────────────────────
        if inp.daysOffFlyingHours > 0:
            raw_days_off = inp.daysOffFlyingHours * DAYS_OFF_RATE_PER_HOUR
            min_days_off = inp.daysOffPairingsCount * DAYS_OFF_MIN_PER_PAIRING
            days_off_amount = max(raw_days_off, min_days_off)
            days_off_note = (
                f"{inp.daysOffFlyingHours:.2f}h × SAR {DAYS_OFF_RATE_PER_HOUR} "
                f"= SAR {raw_days_off:.0f} "
                f"(min SAR {min_days_off:.0f} for {inp.daysOffPairingsCount} pairings)"
            )
        else:
            days_off_amount = 0.0
            days_off_note = "No days-off flying this month"

        # ── Total ────────────────────────────────────────────────────────────
        total = (
            basic +
            prod_amount +
            bonus_total +
            layover_total +
            ot_amount +
            days_off_amount
        )

        summary = [
            f"Basic Salary:              SAR {basic:,.0f}",
            f"Productivity Allowance:    SAR {prod_amount:,.0f}  ({prod_note})",
            f"Flying Bonus:              SAR {bonus_total:,.0f}  ({bonus_note})",
            f"Layover Expenses:          SAR {layover_total:,.0f}",
            f"Overtime:                  SAR {ot_amount:,.0f}",
            f"Days-Off Incentive:        SAR {days_off_amount:,.0f}",
            f"─────────────────────────────────────────",
            f"TOTAL ESTIMATED:           SAR {total:,.0f}",
        ]

        return SalaryBreakdown(
            rankCode=inp.rankCode,
            baseStation=inp.baseStation,
            basicSalary=basic,
            totalBlockHours=block,
            guaranteeHours=guarantee,

            productivityRate=prod_rate,
            productivityAllowance=prod_amount,
            productivityNote=prod_note,

            flyingBonusPercent=bonus_pct,
            flyingBonusFromSalary=bonus_from_salary,
            flyingBonusFixed=bonus_fixed,
            flyingBonusTotal=bonus_total,
            flyingBonusNote=bonus_note,

            domesticLayoverHours=inp.domesticLayoverHours,
            domesticLayoverAmount=dom_amount,
            internationalLayoverHours=inp.internationalLayoverHours,
            internationalLayoverAmount=intl_amount,
            totalLayoverExpenses=layover_total,

            creditHours=credit_hours,
            overtimeHours=ot_hours,
            overtimeRate=ot_rate,
            overtimeAmount=ot_amount,
            overtimeNote=ot_note,

            daysOffFlyingHours=inp.daysOffFlyingHours,
            daysOffPairingsCount=inp.daysOffPairingsCount,
            daysOffAmount=days_off_amount,
            daysOffNote=days_off_note,

            totalSalary=total,
            totalSalaryNote="Estimate based on official Saudi Airlines rules. Actual pay may vary.",
            summaryLines=summary,
        )

    def _productivity(self, block: float) -> tuple[float, float, str]:
        if block <= 50.0:
            return 0, 0, f"Below 50h threshold (flew {block:.2f}h) — no allowance"
        for min_h, max_h, rate in PRODUCTIVITY_TIERS[1:]:
            if min_h <= block <= max_h:
                amount = block * rate
                return rate, amount, f"{block:.2f}h × SAR {rate}/hr = SAR {amount:,.0f}"
        # Above 80h
        rate = 110
        amount = block * rate
        return rate, amount, f"{block:.2f}h × SAR {rate}/hr = SAR {amount:,.0f}"

    def _flying_bonus(self, block: float, basic: float) -> tuple[float, float, float, float, str]:
        # Formula: MAX(% × basic, minimum)
        # The minimum is a floor, not an addition
        if block <= 65.0:
            return 0, 0, 0, 0, f"Below 65h threshold (flew {block:.2f}h) — no bonus"
        for min_h, max_h, pct, minimum in FLYING_BONUS_TIERS[1:]:
            if min_h <= block <= max_h:
                calc    = basic * pct
                total   = max(calc, minimum)
                applied = "minimum" if calc < minimum else f"{pct*100:.1f}% of basic"
                return (pct, calc, minimum, total,
                        f"MAX({pct*100:.1f}% × SAR {basic:,.0f}, SAR {minimum}) = SAR {total:,.2f} [{applied}]")
        # Above 85h
        pct, minimum = 0.08, 350
        calc  = basic * pct
        total = max(calc, minimum)
        applied = "minimum" if calc < minimum else "8% of basic"
        return (pct, calc, minimum, total,
                f"MAX(8% × SAR {basic:,.0f}, SAR {minimum}) = SAR {total:,.2f} [{applied}]")


# ─── Quick Estimate (no basic salary needed) ─────────────────────────────────

class QuickEstimateInput(BaseModel):
    totalBlockHours: float
    domesticLayoverHours: float = 0.0
    internationalLayoverHours: float = 0.0
    baseStation: str = "RUH"

class QuickEstimateOutput(BaseModel):
    blockHours: float
    productivityAllowance: float
    productivityNote: str
    layoverExpenses: float
    overtimeNote: str
    bonusNote: str
    totalExcludingBasicAndBonus: float
    note: str


# ─── API Endpoints ────────────────────────────────────────────────────────────

@router.post("/calculate", response_model=SalaryBreakdown)
async def calculate_salary(inp: SalaryInput):
    """
    Full salary calculation using all 5 official rules.
    Requires user's basic salary.
    """
    if inp.basicSalary <= 0:
        raise HTTPException(
            status_code=422,
            detail="Basic salary must be greater than 0. Please set your basic salary in Profile."
        )
    calc = SalaryCalculator()
    return calc.calculate(inp)


@router.post("/quick-estimate", response_model=QuickEstimateOutput)
async def quick_estimate(inp: QuickEstimateInput):
    """
    Quick estimate without basic salary.
    Returns productivity allowance and layover only.
    Bonus and overtime shown as notes (require basic salary).
    """
    calc = SalaryCalculator()
    prod_rate, prod_amount, prod_note = calc._productivity(inp.totalBlockHours)
    dom  = inp.domesticLayoverHours * DOMESTIC_LAYOVER_RATE
    intl = inp.internationalLayoverHours * INTERNATIONAL_LAYOVER_RATE
    layover = dom + intl
    guarantee = GUARANTEE_HOURS.get(inp.baseStation, DEFAULT_GUARANTEE_HOURS)
    ot_hours = max(0.0, inp.totalBlockHours - guarantee)

    if inp.totalBlockHours <= 65:
        bonus_note = f"No flying bonus (below 65h threshold)"
    elif inp.totalBlockHours <= 75:
        bonus_note = f"3.5% of your basic salary + SAR 150 (set basic salary in Profile to calculate)"
    elif inp.totalBlockHours <= 85:
        bonus_note = f"6% of your basic salary + SAR 250 (set basic salary in Profile to calculate)"
    else:
        bonus_note = f"8% of your basic salary + SAR 350 (set basic salary in Profile to calculate)"

    ot_note = (
        f"{ot_hours:.2f}h overtime (basic salary ÷ {guarantee} × {ot_hours:.2f}) — set basic salary to calculate"
        if ot_hours > 0
        else f"No overtime ({inp.totalBlockHours:.2f}h ≤ {guarantee}h guarantee)"
    )

    return QuickEstimateOutput(
        blockHours=inp.totalBlockHours,
        productivityAllowance=prod_amount,
        productivityNote=prod_note,
        layoverExpenses=layover,
        overtimeNote=ot_note,
        bonusNote=bonus_note,
        totalExcludingBasicAndBonus=prod_amount + layover,
        note="Add your basic salary in Profile → Settings to see full salary calculation including bonus and overtime."
    )


@router.get("/rules")
async def get_salary_rules():
    """Return the complete salary rule structure for display in the app."""
    return {
        "productivity": {
            "title": "Productivity Allowance",
            "note": "Minimum 50:01 block hours required",
            "tiers": [
                {"range": "< 50:00h",       "rate": 0,   "unit": "SAR/hr", "note": "No allowance"},
                {"range": "50:01 – 65:00h",  "rate": 75,  "unit": "SAR/hr"},
                {"range": "65:01 – 80:00h",  "rate": 90,  "unit": "SAR/hr"},
                {"range": "80:01h+",          "rate": 110, "unit": "SAR/hr"},
            ]
        },
        "flyingBonus": {
            "title": "Monthly Flying Bonus",
            "note": "Minimum 65:01 block hours required",
            "tiers": [
                {"range": "< 65:00h",       "percent": 0,   "fixed": 0,   "note": "No bonus"},
                {"range": "65:01 – 75:00h", "percent": 3.5, "fixed": 150},
                {"range": "75:01 – 85:00h", "percent": 6.0, "fixed": 250},
                {"range": "85:01h+",         "percent": 8.0, "fixed": 350},
            ]
        },
        "layover": {
            "title": "Layover Expenses",
            "domestic":      {"rate": DOMESTIC_LAYOVER_RATE,      "unit": "SAR/hr"},
            "international": {"rate": INTERNATIONAL_LAYOVER_RATE,  "unit": "SAR/hr"},
        },
        "overtime": {
            "title": "Overtime",
            "formula": "Basic Salary ÷ Guarantee Hours × Overtime Hours",
            "guaranteeHours": GUARANTEE_HOURS,
            "includes": ["Block Hours only (TVL/TR/SB not in Excel)"],
        },
        "daysOff": {
            "title": "Flying on Days Off",
            "rate":    DAYS_OFF_RATE_PER_HOUR,
            "minimum": DAYS_OFF_MIN_PER_PAIRING,
            "unit":    "SAR/hr",
            "note":    "Deadhead (D.H.D) NOT included. Minimum SAR 150 per pairing.",
        }
    }
