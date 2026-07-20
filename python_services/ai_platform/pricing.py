"""Pure provider-internal cost estimation over caller-supplied pricing facts.

This module does not define customer prices, credits, billing, budgets, or
execution authorization.  It performs no I/O and owns no pricing catalog.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal, ROUND_HALF_EVEN, localcontext
from enum import Enum

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    StrictStr,
    field_validator,
    model_validator,
)

from .contracts import ProviderUsage, ProviderUsageCertainty


ROUNDING_MODE = ROUND_HALF_EVEN
ROUNDING_POLICY_REF = "decimal.round-half-even.v1"
ESTIMATION_DECIMAL_PRECISION_POLICY = (
    "double-largest-significand-plus-20-guard-digits-capped-500.v1"
)

_PRECISION_MULTIPLIER = 2
_PRECISION_GUARD_DIGITS = 20
_PRECISION_BASELINE_DIGITS = 50
_PRECISION_MAXIMUM_DIGITS = 500

_STANDARD_USAGE_UNITS = (
    "input_tokens",
    "output_tokens",
    "cached_tokens",
    "reasoning_tokens",
    "embedding_tokens",
)


class PricingModel(str, Enum):
    """Declared pricing models; Phase 8 evaluates only linear per-unit facts."""

    PER_UNIT = "per_unit"
    TIERED = "tiered"


class CostEstimateStatus(str, Enum):
    COMPLETE = "complete"
    PARTIAL = "partial"
    UNAVAILABLE = "unavailable"
    UNSUPPORTED = "unsupported"


class CostEstimationErrorCode(str, Enum):
    DUPLICATE_PRICING_FACT = "duplicate_pricing_fact"
    AMBIGUOUS_PRICING_FACT = "ambiguous_pricing_fact"
    INVALID_ESTIMATION_REQUEST = "invalid_estimation_request"


class CostEstimationError(Exception):
    """Stable failure that never includes rates, quantities, or raw inputs."""

    def __init__(self, code: CostEstimationErrorCode) -> None:
        self.code = code
        super().__init__(code.value)


class _PricingModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
        allow_inf_nan=False,
        hide_input_in_errors=True,
        protected_namespaces=(),
    )


def _require_decimal(value: object) -> object:
    if isinstance(value, float) or not isinstance(value, Decimal):
        raise ValueError("financial value must be a Decimal")
    if not value.is_finite():
        raise ValueError("financial value must be finite")
    return value


class ProviderPricingFact(_PricingModel):
    """Immutable, caller-supplied internal provider price provenance."""

    pricing_fact_id: StrictStr = Field(min_length=1, max_length=200)
    pricing_policy_version: StrictStr = Field(min_length=1, max_length=200)
    provider_key: StrictStr = Field(min_length=1, max_length=200)
    model_key: StrictStr = Field(min_length=1, max_length=200)
    usage_unit: StrictStr = Field(min_length=1, max_length=200)
    pricing_model: PricingModel = PricingModel.PER_UNIT
    unit_quantity: Decimal = Field(gt=0, max_digits=100, decimal_places=50)
    internal_cost_per_unit: Decimal = Field(ge=0, max_digits=100, decimal_places=50)
    currency: StrictStr = Field(min_length=1, max_length=32)
    effective_from: AwareDatetime
    effective_until: AwareDatetime

    @field_validator("unit_quantity", "internal_cost_per_unit", mode="before")
    @classmethod
    def financial_values_are_decimal_only(cls, value: object) -> object:
        return _require_decimal(value)

    @model_validator(mode="after")
    def interval_is_closed_open(self) -> "ProviderPricingFact":
        if self.effective_until <= self.effective_from:
            raise ValueError("pricing interval must be non-empty")
        return self

    def applies_at(self, at: datetime) -> bool:
        return self.effective_from <= at < self.effective_until


class CostEstimateRequest(_PricingModel):
    """One deterministic estimate request with no route authorization effect."""

    provider_key: StrictStr = Field(min_length=1, max_length=200)
    model_key: StrictStr = Field(min_length=1, max_length=200)
    currency: StrictStr = Field(min_length=1, max_length=32)
    estimate_at: AwareDatetime
    usage: ProviderUsage
    pricing_facts: tuple[ProviderPricingFact, ...] = ()
    currency_quantum: Decimal = Field(gt=0, max_digits=50, decimal_places=20)

    @field_validator("currency_quantum", mode="before")
    @classmethod
    def quantum_is_decimal_only(cls, value: object) -> object:
        return _require_decimal(value)


class CostEstimateResult(_PricingModel):
    """Internal estimate facts; never a customer charge or execution approval."""

    status: CostEstimateStatus
    provider_key: StrictStr
    model_key: StrictStr
    currency: StrictStr
    estimated_internal_cost: Decimal | None = Field(default=None, ge=0)
    usage_certainty: ProviderUsageCertainty
    priced_usage_units: tuple[StrictStr, ...] = ()
    zero_usage_units: tuple[StrictStr, ...] = ()
    missing_usage_units: tuple[StrictStr, ...] = ()
    unsupported_usage_units: tuple[StrictStr, ...] = ()
    pricing_fact_refs: tuple[StrictStr, ...] = ()
    pricing_policy_refs: tuple[StrictStr, ...] = ()
    rounding_policy_ref: StrictStr = ROUNDING_POLICY_REF

    @field_validator("estimated_internal_cost", mode="before")
    @classmethod
    def result_cost_is_decimal_only(cls, value: object) -> object:
        if value is None:
            return value
        return _require_decimal(value)

    @model_validator(mode="after")
    def outcome_is_consistent(self) -> "CostEstimateResult":
        if self.status in {CostEstimateStatus.COMPLETE, CostEstimateStatus.PARTIAL}:
            if self.estimated_internal_cost is None:
                raise ValueError("priced estimate requires an internal cost")
        elif self.estimated_internal_cost is not None:
            raise ValueError("unpriced estimate cannot claim an internal cost")
        if self.status is CostEstimateStatus.COMPLETE and (
            self.missing_usage_units or self.unsupported_usage_units
        ):
            raise ValueError("complete estimate cannot omit usage units")
        if self.status is CostEstimateStatus.PARTIAL and not (
            self.missing_usage_units or self.unsupported_usage_units
        ):
            raise ValueError("partial estimate requires an omitted usage unit")
        if self.status is CostEstimateStatus.UNSUPPORTED and not (
            self.unsupported_usage_units
        ):
            raise ValueError("unsupported estimate requires an unsupported unit")
        return self


def _usage_quantities(usage: ProviderUsage) -> dict[str, Decimal]:
    quantities: dict[str, Decimal] = {}
    for unit in _STANDARD_USAGE_UNITS:
        value = getattr(usage, unit)
        if value is not None:
            quantities[unit] = Decimal(value)
    for unit, value in usage.additional_native_units.items():
        quantities[unit] = value
    return quantities


def _fact_identity(fact: ProviderPricingFact) -> tuple[str, ...]:
    return (
        fact.pricing_fact_id,
        fact.pricing_policy_version,
        fact.provider_key,
        fact.model_key,
        fact.usage_unit,
        fact.pricing_model.value,
        str(fact.unit_quantity),
        str(fact.internal_cost_per_unit),
        fact.currency,
        fact.effective_from.isoformat(),
        fact.effective_until.isoformat(),
    )


def _validate_no_duplicate_facts(facts: tuple[ProviderPricingFact, ...]) -> None:
    identities = [_fact_identity(fact) for fact in facts]
    if len(identities) != len(set(identities)):
        raise CostEstimationError(CostEstimationErrorCode.DUPLICATE_PRICING_FACT)


def _calculation_precision(
    quantities: dict[str, Decimal],
    facts: tuple[ProviderPricingFact, ...],
) -> int:
    """Return the explicit bounded precision used for estimate arithmetic.

    Doubling the largest input significand leaves room for multiplication of a
    usage quantity by a rate. Guard digits protect the following division and
    final aggregate from premature rounding. The baseline keeps ordinary small
    inputs well above the process-global Decimal default. The 500-digit ceiling
    supports the Phase 8 DTO bounds with substantial headroom while preventing
    caller-controlled quantities from creating an unbounded Decimal context.
    """

    digit_counts = [_PRECISION_BASELINE_DIGITS]
    for value in quantities.values():
        digit_counts.append(len(value.as_tuple().digits))
    for fact in facts:
        digit_counts.extend(
            (
                len(fact.unit_quantity.as_tuple().digits),
                len(fact.internal_cost_per_unit.as_tuple().digits),
            )
        )
    return min(
        max(digit_counts) * _PRECISION_MULTIPLIER + _PRECISION_GUARD_DIGITS,
        _PRECISION_MAXIMUM_DIGITS,
    )


class ProviderInternalCostEstimator:
    """Pure deterministic estimator over explicit request-local facts."""

    def estimate(self, request: CostEstimateRequest) -> CostEstimateResult:
        if not isinstance(request, CostEstimateRequest):
            raise CostEstimationError(
                CostEstimationErrorCode.INVALID_ESTIMATION_REQUEST
            )
        _validate_no_duplicate_facts(request.pricing_facts)
        quantities = _usage_quantities(request.usage)
        units = tuple(sorted(quantities))

        if not units:
            return CostEstimateResult(
                status=CostEstimateStatus.UNAVAILABLE,
                provider_key=request.provider_key,
                model_key=request.model_key,
                currency=request.currency,
                usage_certainty=request.usage.certainty,
            )

        applicable: dict[str, ProviderPricingFact] = {}
        for fact in sorted(request.pricing_facts, key=_fact_identity):
            if (
                fact.provider_key != request.provider_key
                or fact.model_key != request.model_key
                or fact.currency != request.currency
                or not fact.applies_at(request.estimate_at)
                or fact.usage_unit not in quantities
            ):
                continue
            if fact.usage_unit in applicable:
                raise CostEstimationError(
                    CostEstimationErrorCode.AMBIGUOUS_PRICING_FACT
                )
            applicable[fact.usage_unit] = fact

        priced: list[str] = []
        zero_usage: list[str] = []
        missing: list[str] = []
        unsupported: list[str] = []
        components: list[Decimal] = []
        used_facts: list[ProviderPricingFact] = []

        with localcontext() as context:
            context.prec = _calculation_precision(quantities, request.pricing_facts)
            for unit in units:
                quantity = quantities[unit]
                fact = applicable.get(unit)
                if quantity == 0 and fact is None:
                    zero_usage.append(unit)
                    continue
                if fact is None:
                    missing.append(unit)
                    continue
                if fact.pricing_model is not PricingModel.PER_UNIT:
                    unsupported.append(unit)
                    continue
                components.append(
                    quantity
                    * fact.internal_cost_per_unit
                    / fact.unit_quantity
                )
                priced.append(unit)
                used_facts.append(fact)

            # CostEstimateStatus describes pricing coverage only.
            # ProviderUsageCertainty separately describes confidence in the
            # measured usage. These concepts are intentionally independent;
            # future changes must not automatically couple certainty to status.
            if unsupported and not priced:
                status = CostEstimateStatus.UNSUPPORTED
                total = None
            elif not missing and not unsupported:
                status = CostEstimateStatus.COMPLETE
                total = sum(components, Decimal(0)).quantize(
                    request.currency_quantum,
                    rounding=ROUNDING_MODE,
                )
            elif priced:
                status = CostEstimateStatus.PARTIAL
                total = sum(components, Decimal(0)).quantize(
                    request.currency_quantum,
                    rounding=ROUNDING_MODE,
                )
            elif unsupported:
                status = CostEstimateStatus.UNSUPPORTED
                total = None
            else:
                status = CostEstimateStatus.UNAVAILABLE
                total = None

        fact_refs = tuple(sorted({fact.pricing_fact_id for fact in used_facts}))
        policy_refs = tuple(
            sorted({fact.pricing_policy_version for fact in used_facts})
        )
        return CostEstimateResult(
            status=status,
            provider_key=request.provider_key,
            model_key=request.model_key,
            currency=request.currency,
            estimated_internal_cost=total,
            usage_certainty=request.usage.certainty,
            priced_usage_units=tuple(sorted(priced)),
            zero_usage_units=tuple(sorted(zero_usage)),
            missing_usage_units=tuple(sorted(missing)),
            unsupported_usage_units=tuple(sorted(unsupported)),
            pricing_fact_refs=fact_refs,
            pricing_policy_refs=policy_refs,
        )
