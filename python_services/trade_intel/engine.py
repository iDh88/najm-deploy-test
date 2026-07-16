"""
Najm Trade Intelligence Engine
Aviation-grade trade matching with fatigue, legality and score analysis.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from datetime import datetime
import uuid, logging

logger = logging.getLogger("cip.trade_intel")
router = APIRouter()


# ── Enums ─────────────────────────────────────────────────────────
class SearchMode(str, Enum):
    EXACT_ROUTE    = "exact_route"
    SIMILAR_HOURS  = "similar_hours"
    BETTER_REST    = "better_rest"
    LOWEST_FATIGUE = "lowest_fatigue"
    HIGHEST_INCOME = "highest_income"
    SMART_FLEXIBLE = "smart_flexible"

class FatigueLevel(str, Enum):
    LOW = "LOW"; MEDIUM = "MEDIUM"; HIGH = "HIGH"

class TradeDifficulty(str, Enum):
    EASY = "EASY"; MEDIUM = "MEDIUM"; HARD = "HARD"

class LegType(str, Enum):
    OPERATING   = "OPERATING"
    DEADHEAD    = "DEADHEAD"
    POSITIONING = "POSITIONING"

class DateSearchMode(str, Enum):
    EXACT_DAY  = "exact_day"
    FLEX_RANGE = "flex_range"


# ── Core Models ───────────────────────────────────────────────────
class Leg(BaseModel):
    id:            str = Field(default_factory=lambda: str(uuid.uuid4()))
    flightNumber:  str
    origin:        str
    destination:   str
    legType:       LegType
    departureUTC:  datetime
    arrivalUTC:    datetime
    blockHours:    float
    isNight:       bool = False


class Pairing(BaseModel):
    id:              str = Field(default_factory=lambda: str(uuid.uuid4()))
    pairingCode:     str
    legs:            list[Leg]
    dutyStartUTC:    datetime
    dutyEndUTC:      datetime
    releaseTimeUTC:  datetime
    totalBlockHours: float
    totalDutyHours:  float
    fdpHours:        float
    restAfterHours:  float
    isInternational: bool = False
    carryOverHours:  float = 0.0
    hasDeadhead:     bool = False
    layoverHours:    float = 0.0

    @property
    def route_pattern(self) -> str:
        airports = [self.legs[0].origin] + [l.destination for l in self.legs]
        return "→".join(airports)

    @property
    def leg_type_pattern(self) -> list[str]:
        return [l.legType.value for l in self.legs]

    @property
    def exact_fingerprint(self) -> str:
        return "|".join(f"{l.origin}-{l.destination}:{l.legType.value}"
                        for l in self.legs)


class TradeFilters(BaseModel):
    legalOnly:          bool = True
    noCarryOver:        bool = False
    morningFlightsOnly: bool = False
    similarBlockHours:  bool = False
    operatingOnly:      bool = False
    avoidDeadheadHeavy: bool = False
    sameRoutePattern:   bool = False
    dateSearchMode:     DateSearchMode = DateSearchMode.EXACT_DAY
    flexDays:           int = 0
    minBlockHours:      Optional[float] = None
    maxBlockHours:      Optional[float] = None


class TradeSearchRequest(BaseModel):
    userId:          str
    userPRN:         str
    userLineId:      str
    targetPairingId: str
    searchMode:      SearchMode = SearchMode.SMART_FLEXIBLE
    filters:         TradeFilters = TradeFilters()
    month:           str
    maxResults:      int = 20


class LegalityViolation(BaseModel):
    ruleId:      str
    ruleName:    str
    description: str
    required:    float
    available:   float
    unit:        str = "hours"
    severity:    str = "BLOCKING"


class LegalityDetail(BaseModel):
    passed:     bool
    violations: list[LegalityViolation] = []
    warnings:   list[LegalityViolation] = []
    summary:    str


class FatigueDetail(BaseModel):
    level:      FatigueLevel
    score:      float
    factors:    list[str]
    comparison: str = ""


class TradeScoreBreakdown(BaseModel):
    total:           float
    restScore:       float
    fatigueScore:    float
    incomeScore:     float
    dutyScore:       float
    legalMarginScore:float
    reasons:         list[str]
    recommendation:  str


class TradeMatchResult(BaseModel):
    matchId:         str = Field(default_factory=lambda: str(uuid.uuid4()))
    lineId:          str
    lineNumber:      str
    ownerPRN:        str
    rank:            str
    base:            str
    category:        str
    date:            str
    departureTime:   str
    routePattern:    str
    legTypePattern:  list[str]
    blockHours:      float
    dutyHours:       float
    fdpHours:        float
    restAfterHours:  float
    income:          float
    expense:         float
    allowance:       float
    hasCarryOver:    bool
    hasDeadhead:     bool
    isInternational: bool
    legality:        LegalityDetail
    fatigue:         FatigueDetail
    tradeScore:      TradeScoreBreakdown
    difficulty:      TradeDifficulty
    phoneNumber:     Optional[str] = None


class TradeSearchResponse(BaseModel):
    searchId:        str = Field(default_factory=lambda: str(uuid.uuid4()))
    userId:          str
    results:         list[TradeMatchResult]
    totalFound:      int
    searchMode:      SearchMode
    searchDurationMs:float
    month:           str
    generatedAt:     str


# ── Fatigue Engine ────────────────────────────────────────────────
class FatigueEngine:
    def score(self, pairing: Pairing) -> FatigueDetail:
        s = 0.0
        factors = []
        h = pairing.dutyStartUTC.hour

        if h < 6:
            s += 15; factors.append(f"Early sign-in ({h:02d}:00Z)")
        elif h >= 22:
            s += 8;  factors.append("Late-night sign-in")

        if pairing.totalDutyHours > 12:
            s += 20; factors.append(f"Very long duty ({pairing.totalDutyHours:.1f}h)")
        elif pairing.totalDutyHours > 10:
            s += 12; factors.append(f"Long duty ({pairing.totalDutyHours:.1f}h)")

        legs = len(pairing.legs)
        if legs > 5:   s += 12; factors.append(f"Many legs ({legs})")
        elif legs > 3: s += 5;  factors.append(f"Multiple legs ({legs})")

        night = [l for l in pairing.legs
                 if l.departureUTC.hour >= 22 or l.departureUTC.hour < 6]
        if night:
            s += 10; factors.append(f"Night operations ({len(night)} leg(s))")

        dh = [l for l in pairing.legs if l.legType == LegType.DEADHEAD]
        if dh:
            s += 3 * len(dh); factors.append(f"Deadhead ({len(dh)} segment(s))")

        if pairing.restAfterHours > 0:
            if pairing.restAfterHours < 11:
                s += 20; factors.append(f"Short rest ({pairing.restAfterHours:.1f}h)")
            elif pairing.restAfterHours < 14:
                s += 10; factors.append(f"Tight rest ({pairing.restAfterHours:.1f}h)")

        if pairing.totalBlockHours > 10:
            s += 15; factors.append(f"Very long block ({pairing.totalBlockHours:.1f}h)")
        elif pairing.totalBlockHours > 8:
            s += 8;  factors.append(f"Long block ({pairing.totalBlockHours:.1f}h)")

        if pairing.isInternational:
            s += 8; factors.append("International timezone transition")

        s = min(s, 100.0)
        level = (FatigueLevel.HIGH if s >= 65 else
                 FatigueLevel.MEDIUM if s >= 30 else FatigueLevel.LOW)

        return FatigueDetail(
            level=level, score=round(s, 1),
            factors=factors or ["Standard duty — no significant fatigue factors"],
        )

    def compare_text(self, user: Pairing, cand: Pairing) -> str:
        diff = self.score(cand).score - self.score(user).score
        if diff < -10: return f"Much lower fatigue (-{abs(diff):.0f} pts)"
        if diff < -5:  return f"Lower fatigue (-{abs(diff):.0f} pts)"
        if abs(diff) <= 5: return "Similar fatigue to your pairing"
        if diff < 10:  return f"Slightly higher fatigue (+{diff:.0f} pts)"
        return f"Higher fatigue (+{diff:.0f} pts) — review carefully"


# ── Trade Score Engine ────────────────────────────────────────────
class TradeScoreEngine:
    def score(self, user: Pairing, cand: Pairing,
              legality: LegalityDetail, user_fat: FatigueDetail,
              cand_fat: FatigueDetail, cand_income: float,
              mode: SearchMode) -> TradeScoreBreakdown:

        if not legality.passed:
            return TradeScoreBreakdown(
                total=0, restScore=0, fatigueScore=0, incomeScore=0,
                dutyScore=0, legalMarginScore=0,
                reasons=["✗ Illegal — not recommended"],
                recommendation="This trade violates GACA regulations.",
            )

        reasons = []

        # Legal margin (25 pts)
        legal_pts = max(0, 25.0 - len(legality.warnings) * 3)
        reasons.append(f"+ Legal under GACA ({legal_pts:.0f}/25)")

        # Rest (20 pts)
        rest_diff = cand.restAfterHours - user.restAfterHours
        rest_pts  = 20 if rest_diff >= 4 else 17 if rest_diff >= 2 else \
                    14 if rest_diff >= 0 else 10 if rest_diff >= -2 else 5
        if rest_pts >= 17: reasons.append("+ Better rest than current pairing")
        elif rest_pts >= 14: reasons.append("+ Similar rest quality")
        else: reasons.append("− Lower rest than current pairing")

        # Fatigue (20 pts)
        fat_diff = user_fat.score - cand_fat.score
        fat_pts  = 20 if fat_diff > 20 else 17 if fat_diff > 10 else \
                   14 if fat_diff > 0  else 10 if fat_diff > -10 else 5
        if fat_pts >= 17: reasons.append("+ Lower fatigue")
        elif fat_pts >= 14: reasons.append("+ Similar fatigue level")
        else: reasons.append("− Higher fatigue")

        # Income (15 pts)
        inc_pts = 15 if cand_income > 0 else 8
        if cand_income > 0: reasons.append("+ Income data available")

        # Duty match (10 pts)
        duty_pts = max(0, 10 - abs(user.totalBlockHours - cand.totalBlockHours) * 1.5
                           - abs(user.totalDutyHours  - cand.totalDutyHours) * 1.0)

        # Carry over bonus (5 pts)
        co_pts = 5 if cand.carryOverHours == 0 else 0
        if co_pts: reasons.append("+ No carry over")
        else: reasons.append(f"− Carry over {cand.carryOverHours:.1f}h")

        # Route match (5 pts)
        if user.exact_fingerprint == cand.exact_fingerprint:
            route_pts = 5; reasons.append("+ Exact route and leg-type match")
        elif user.route_pattern == cand.route_pattern:
            route_pts = 2; reasons.append("+ Same route pattern")
        else:
            route_pts = 0

        # Mode boost
        boost = 0.0
        if mode == SearchMode.EXACT_ROUTE and user.exact_fingerprint == cand.exact_fingerprint:
            boost = 15
        elif mode == SearchMode.BETTER_REST and rest_diff > 2:
            boost = 15
        elif mode == SearchMode.LOWEST_FATIGUE and cand_fat.level == FatigueLevel.LOW:
            boost = 15
        elif mode == SearchMode.HIGHEST_INCOME and cand_income > 0:
            boost = 10
        elif mode == SearchMode.SIMILAR_HOURS:
            boost = max(0, 15 - abs(user.totalBlockHours - cand.totalBlockHours) * 2)

        total = min(100, legal_pts + rest_pts + fat_pts + inc_pts +
                    duty_pts + co_pts + route_pts + boost)

        rec = (f"Excellent match ({total:.0f}/100) — better rest, legal, low fatigue."
               if total >= 85 else
               f"Good option ({total:.0f}/100) — legal and compatible."
               if total >= 70 else
               f"Acceptable ({total:.0f}/100) — review details before accepting."
               if total >= 55 else
               f"Low compatibility ({total:.0f}/100) — consider other options.")

        return TradeScoreBreakdown(
            total=round(total, 1),
            restScore=rest_pts, fatigueScore=fat_pts, incomeScore=inc_pts,
            dutyScore=duty_pts, legalMarginScore=legal_pts,
            reasons=reasons, recommendation=rec,
        )


# ── Legality Engine ───────────────────────────────────────────────
class TradeLegalityEngine:
    # GOM 7.5.3 Table (F) — Rest measured from BLOCK-IN to BLOCK-OUT
    HOME_BASE_REST       = 14.0   # Home base un-augmented
    DOMESTIC_REST        = 14.0   # Non-home domestic un-augmented
    INTL_REST            = 15.0   # International un-augmented
    AUGMENTED_REST       = 18.0   # All stations augmented
    EMERGENCY_REST_MIN   = 10.0   # Emergency (GM approval + 8h sleep)
    STANDBY_MAX          = 14.0   # GOM 7.5.4
    STANDBY_REPORT_MIN   = 60     # minutes to report after notification
    FDP_BASE  = 13.0; FDP_AUG   = 14.0
    MAX_MONTHLY_BLOCK = 100.0; MAX_MONTHLY_DUTY = 120.0

    def validate(self, candidate: Pairing,
                 prev: Optional[Pairing] = None,
                 next_p: Optional[Pairing] = None,
                 monthly_block: float = 0,
                 monthly_duty:  float = 0) -> LegalityDetail:
        violations, warnings = [], []

        # Rest before
        if prev:
            # GOM 7.5.3: rest measured from BLOCK-IN (prev) to BLOCK-OUT (cand)
            avail = (candidate.dutyStartUTC - prev.dutyEndUTC
                     ).total_seconds() / 3600
            # Select correct minimum per Table (F)
            req = (self.INTL_REST if prev.isInternational
                   else self.HOME_BASE_REST)
            station_label = ("International" if prev.isInternational
                             else "Domestic (home base)")
            if avail < req:
                violations.append(LegalityViolation(
                    ruleId="GACA-REST-BEFORE",
                    ruleName="Insufficient Rest (GOM 7.5.3 Table F)",
                    description=(
                        f"{station_label} — minimum {req}h required "
                        f"(Block-In to Block-Out). "
                        f"Available: {avail:.2f}h. "
                        f"Shortfall: {req - avail:.2f}h."
                    ),
                    required=req, available=round(avail, 2)))
            elif avail < req + 1:
                warnings.append(LegalityViolation(
                    ruleId="GACA-REST-BEFORE-WARN",
                    ruleName="Tight Rest Window (GOM 7.5.3)",
                    description=(
                        f"Only {avail - req:.2f}h margin above {req}h minimum. "
                        f"Emergency minimum is {self.EMERGENCY_REST_MIN}h "
                        f"(requires GM approval)."
                    ),
                    required=req, available=round(avail, 2), severity="WARNING"))

        # Rest after
        if next_p:
            avail = (next_p.dutyStartUTC - candidate.releaseTimeUTC
                     ).total_seconds() / 3600
            req   = self.INTL_REST if candidate.isInternational else self.DOMESTIC_REST
            if avail < req:
                violations.append(LegalityViolation(
                    ruleId="GACA-REST-AFTER", ruleName="Insufficient Rest After Duty",
                    description=f"Need {req}h before next duty, only {avail:.2f}h available.",
                    required=req, available=round(avail, 2)))

        # FDP
        if candidate.fdpHours > self.FDP_AUG:
            violations.append(LegalityViolation(
                ruleId="GACA-FDP", ruleName="FDP Limit Exceeded",
                description=f"FDP {candidate.fdpHours:.2f}h exceeds {self.FDP_AUG}h max.",
                required=self.FDP_AUG, available=round(candidate.fdpHours, 2)))
        elif candidate.fdpHours > self.FDP_BASE:
            warnings.append(LegalityViolation(
                ruleId="GACA-FDP-WARN", ruleName="High FDP",
                description="Exceeds base FDP — augmented crew required.",
                required=self.FDP_BASE, available=round(candidate.fdpHours, 2),
                severity="WARNING"))

        # Monthly block
        proj_block = monthly_block + candidate.totalBlockHours
        if proj_block > self.MAX_MONTHLY_BLOCK:
            violations.append(LegalityViolation(
                ruleId="GACA-MONTHLY-BLOCK", ruleName="Monthly Block Limit",
                description=f"Would reach {proj_block:.1f}h, limit is {self.MAX_MONTHLY_BLOCK}h.",
                required=self.MAX_MONTHLY_BLOCK, available=round(proj_block, 2)))

        passed = len(violations) == 0
        summary = ("All GACA checks passed." if passed and not warnings else
                   f"Legal — {len(warnings)} warning(s)." if passed else
                   f"ILLEGAL — {len(violations)} violation(s): " +
                   "; ".join(f"{v.ruleName} (need {v.required}h, have {v.available}h)"
                             for v in violations))

        return LegalityDetail(passed=passed, violations=violations,
                              warnings=warnings, summary=summary)


# ── Matching Engine ───────────────────────────────────────────────
class TradeMatchingEngine:
    def __init__(self):
        self.fat = FatigueEngine()
        self.sc  = TradeScoreEngine()
        self.leg = TradeLegalityEngine()

    def search(self, user_pairing: Pairing, candidates: list[dict],
               request: TradeSearchRequest,
               monthly_block: float = 0,
               monthly_duty:  float = 0) -> list[TradeMatchResult]:
        results = []
        user_fat = self.fat.score(user_pairing)

        for c in candidates:
            try:
                pairing_data = c.get('pairing')
                if not pairing_data:
                    continue
                cand_pairing = Pairing(**pairing_data)
            except Exception:
                continue

            if not self._passes_filters(user_pairing, cand_pairing, request.filters):
                continue

            legality = self.leg.validate(
                cand_pairing, monthly_block=monthly_block, monthly_duty=monthly_duty)

            if request.filters.legalOnly and not legality.passed:
                continue

            cand_fat = self.fat.score(cand_pairing)
            cand_fat = cand_fat.copy(update={
                'comparison': self.fat.compare_text(user_pairing, cand_pairing)})

            score = self.sc.score(
                user=user_pairing, cand=cand_pairing,
                legality=legality, user_fat=user_fat, cand_fat=cand_fat,
                cand_income=c.get('income', 0), mode=request.searchMode)

            difficulty = (TradeDifficulty.HARD if len(cand_pairing.legs) > 4
                         else TradeDifficulty.MEDIUM if cand_pairing.isInternational
                         else TradeDifficulty.EASY)

            results.append(TradeMatchResult(
                lineId=c.get('lineId', ''), lineNumber=c.get('lineNumber', ''),
                ownerPRN=c.get('ownerPRN', ''), rank=c.get('rank', ''),
                base=c.get('base', ''), category=c.get('category', '9Z'),
                date=cand_pairing.dutyStartUTC.strftime('%Y-%m-%d'),
                departureTime=(cand_pairing.legs[0].departureUTC.strftime('%H:%M')
                               if cand_pairing.legs else ''),
                routePattern=cand_pairing.route_pattern,
                legTypePattern=cand_pairing.leg_type_pattern,
                blockHours=cand_pairing.totalBlockHours,
                dutyHours=cand_pairing.totalDutyHours,
                fdpHours=cand_pairing.fdpHours,
                restAfterHours=cand_pairing.restAfterHours,
                income=c.get('income', 0), expense=c.get('expense', 0),
                allowance=c.get('allowance', 0),
                hasCarryOver=cand_pairing.carryOverHours > 0,
                hasDeadhead=cand_pairing.hasDeadhead,
                isInternational=cand_pairing.isInternational,
                legality=legality, fatigue=cand_fat, tradeScore=score,
                difficulty=difficulty,
            ))

        results.sort(key=lambda r: r.tradeScore.total, reverse=True)
        return results[:request.maxResults]

    def _passes_filters(self, user: Pairing, cand: Pairing,
                        f: TradeFilters) -> bool:
        if f.sameRoutePattern and user.exact_fingerprint != cand.exact_fingerprint:
            return False
        if f.noCarryOver and cand.carryOverHours > 0:
            return False
        if f.morningFlightsOnly and cand.legs and cand.legs[0].departureUTC.hour >= 12:
            return False
        if f.operatingOnly and any(l.legType != LegType.OPERATING for l in cand.legs):
            return False
        if f.avoidDeadheadHeavy and cand.legs:
            dh_ratio = sum(1 for l in cand.legs
                          if l.legType == LegType.DEADHEAD) / len(cand.legs)
            if dh_ratio > 0.5: return False
        if f.similarBlockHours and user.totalBlockHours > 0:
            ratio = cand.totalBlockHours / user.totalBlockHours
            if ratio < 0.8 or ratio > 1.2: return False
        if f.minBlockHours and cand.totalBlockHours < f.minBlockHours: return False
        if f.maxBlockHours and cand.totalBlockHours > f.maxBlockHours: return False
        # Date filter
        user_date = user.dutyStartUTC.date()
        cand_date = cand.dutyStartUTC.date()
        delta = (cand_date - user_date).days
        if f.dateSearchMode == DateSearchMode.EXACT_DAY and delta != 0: return False
        if f.dateSearchMode == DateSearchMode.FLEX_RANGE and abs(delta) > f.flexDays:
            return False
        return True


# ── Singleton ────────────────────────────────────────────────────
_engine = TradeMatchingEngine()


# ── API Endpoints ─────────────────────────────────────────────────
@router.post("/search", response_model=TradeSearchResponse)
async def search_trades(request: TradeSearchRequest):
    """Find compatible trade options for a crew member's pairing."""
    start = datetime.utcnow()
    try:
        from utils.firebase import get_firestore
        db = get_firestore()

        # Load user's pairing
        pair_doc = (db.collection("flightLines")
                    .document(request.userLineId)
                    .collection("pairings")
                    .document(request.targetPairingId)
                    .get())
        if not pair_doc.exists:
            raise HTTPException(status_code=404, detail="Pairing not found")
        user_pairing = Pairing(**pair_doc.to_dict())

        # Load PRN map
        prn_map = {d.to_dict().get('assignedLineId', ''): d.to_dict().get('prn', '')
                   for d in db.collection("prnWhitelist").stream()}

        # Load candidate lines (same rank/base/month)
        candidates = []
        q = (db.collection("flightLines")
             .where("month", "==", request.month)
             .limit(300))
        for doc in q.stream():
            if doc.id == request.userLineId: continue
            d = doc.to_dict()
            for p_doc in (db.collection("flightLines")
                          .document(doc.id)
                          .collection("pairings").stream()):
                try:
                    candidates.append({
                        'lineId':    doc.id,
                        'lineNumber':d.get('lineNumber', ''),
                        'ownerPRN':  prn_map.get(doc.id, ''),
                        'rank':      d.get('rank', ''),
                        'base':      d.get('base', ''),
                        'category':  d.get('category', '9Z'),
                        'income':    d.get('income', 0),
                        'expense':   d.get('expense', 0),
                        'allowance': d.get('allowance', 0),
                        'pairing':   p_doc.to_dict(),
                    })
                except Exception:
                    continue

        results = _engine.search(
            user_pairing=user_pairing, candidates=candidates,
            request=request)

        # Cache results
        search_id = str(uuid.uuid4())
        batch = db.batch()
        for r in results[:10]:
            ref = db.collection("tradeMatches").document(r.matchId)
            batch.set(ref, r.dict())
        batch.commit()

        ms = (datetime.utcnow() - start).total_seconds() * 1000
        return TradeSearchResponse(
            searchId=search_id, userId=request.userId, results=results,
            totalFound=len(results), searchMode=request.searchMode,
            searchDurationMs=round(ms, 1), month=request.month,
            generatedAt=datetime.utcnow().isoformat())

    except HTTPException: raise
    except Exception as e:
        logger.error(f"Trade search error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/legality-explain/{code}")
async def explain_violation(code: str):
    """Plain-language explanation of a GACA violation code."""
    db = {
        "GACA-REST-BEFORE": {
            "title": "Insufficient Rest Before Duty",
            "plain": "You did not have enough rest between your last flight and this one.",
            "required": "14h domestic / 15h international from release time",
            "consequence": "This trade is blocked until rest requirement is met.",
        },
        "GACA-REST-AFTER": {
            "title": "Insufficient Rest After Duty",
            "plain": "After this pairing you would not have enough rest before your next duty.",
            "required": "14h domestic / 15h international",
            "consequence": "Accepting this trade would violate your next duty.",
        },
        "GACA-FDP": {
            "title": "Flight Duty Period Exceeded",
            "plain": "Total time from sign-in to release exceeds the legal maximum.",
            "required": "13h base / 14h augmented",
            "consequence": "This pairing cannot legally be operated as structured.",
        },
        "GACA-MONTHLY-BLOCK": {
            "title": "Monthly Block Hour Limit",
            "plain": "Adding this pairing would exceed your monthly flying hour limit.",
            "required": "100 block hours per 28-day period",
            "consequence": "You must give up other pairings to accept this trade.",
        },
    }
    result = db.get(code)
    if not result:
        raise HTTPException(status_code=404, detail="Unknown violation code")
    return result
