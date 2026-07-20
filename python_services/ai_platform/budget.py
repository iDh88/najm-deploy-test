"""Pure deterministic budget evaluation over Phase 8 cost estimates.

This module evaluates caller-supplied budget policy only. It does not estimate
cost, reserve funds, manage credits, authorize execution, or perform I/O.
"""

from __future__ import annotations

from decimal import Decimal
from enum import Enum

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StrictStr,
    field_validator,
    model_validator,
)

from .pricing import CostEstimateResult, CostEstimateStatus


class BudgetScope(str, Enum):
    REQUEST = "request"
    ATTEMPT = "attempt"
    FEATURE = "feature"
    TENANT = "tenant"


class BudgetEvaluationStatus(str, Enum):
    APPROVED = "approved"
    DENIED = "denied"
    UNAVAILABLE = "unavailable"
    UNSUPPORTED = "unsupported"


class BudgetDecisionReason(str, Enum):
    WITHIN_LIMIT = "within_limit"
    LIMIT_EXACTLY_MET = "limit_exactly_met"
    LIMIT_EXCEEDED = "limit_exceeded"
    COST_ESTIMATE_MISSING = "cost_estimate_missing"
    COST_ESTIMATE_PARTIAL = "cost_estimate_partial"
    COST_ESTIMATE_UNAVAILABLE = "cost_estimate_unavailable"
    COST_ESTIMATE_UNSUPPORTED = "cost_estimate_unsupported"
    NO_APPLICABLE_LIMIT = "no_applicable_limit"
    CURRENCY_MISMATCH = "currency_mismatch"


class BudgetControllerErrorCode(str, Enum):
    INVALID_DECISION_REQUEST = "invalid_decision_request"


class BudgetControllerError(Exception):
    """Stable controller failure that never includes policy or cost values."""

    def __init__(self, code: BudgetControllerErrorCode) -> None:
        self.code = code
        super().__init__(code.value)


class _BudgetModel(BaseModel):
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
        raise ValueError("budget financial value must be a Decimal")
    if not value.is_finite():
        raise ValueError("budget financial value must be finite")
    return value


class BudgetLimit(_BudgetModel):
    """One immutable ceiling; it carries no balance or reservation meaning."""

    limit_ref: StrictStr = Field(min_length=1, max_length=200)
    scope: BudgetScope
    maximum_internal_cost: Decimal = Field(ge=0, max_digits=100, decimal_places=50)
    currency: StrictStr = Field(min_length=1, max_length=32)

    @field_validator("maximum_internal_cost", mode="before")
    @classmethod
    def maximum_is_decimal_only(cls, value: object) -> object:
        return _require_decimal(value)


class BudgetPolicy(_BudgetModel):
    """Caller-supplied policy containing layered deterministic cost ceilings."""

    budget_policy_ref: StrictStr = Field(min_length=1, max_length=200)
    evaluation_policy_ref: StrictStr = Field(min_length=1, max_length=200)
    limits: tuple[BudgetLimit, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def limit_references_are_unique(self) -> "BudgetPolicy":
        refs = tuple(limit.limit_ref for limit in self.limits)
        if len(refs) != len(set(refs)):
            raise ValueError("duplicate budget limit reference")
        return self


class BudgetDecisionRequest(_BudgetModel):
    """Complete caller-owned input for one side-effect-free evaluation."""

    decision_ref: StrictStr = Field(min_length=1, max_length=200)
    request_id: StrictStr = Field(min_length=1, max_length=200)
    cost_estimate_ref: StrictStr = Field(min_length=1, max_length=200)
    applicable_scopes: tuple[BudgetScope, ...] = Field(min_length=1)
    policy: BudgetPolicy
    cost_estimate: CostEstimateResult | None = None

    @model_validator(mode="after")
    def scopes_are_unique(self) -> "BudgetDecisionRequest":
        if len(self.applicable_scopes) != len(set(self.applicable_scopes)):
            raise ValueError("duplicate applicable budget scope")
        return self


class BudgetDecision(_BudgetModel):
    """Budget-policy result only; never execution or reservation authority."""

    decision_ref: StrictStr
    request_id: StrictStr
    status: BudgetEvaluationStatus
    reasons: tuple[BudgetDecisionReason, ...] = Field(min_length=1)
    budget_policy_ref: StrictStr
    evaluation_policy_ref: StrictStr
    cost_estimate_ref: StrictStr
    cost_estimate_status: CostEstimateStatus | None = None
    currency: StrictStr | None = None
    estimated_internal_cost: Decimal | None = Field(default=None, ge=0)
    effective_maximum_internal_cost: Decimal | None = Field(default=None, ge=0)
    applied_limit_refs: tuple[StrictStr, ...] = ()

    @field_validator(
        "estimated_internal_cost",
        "effective_maximum_internal_cost",
        mode="before",
    )
    @classmethod
    def decision_costs_are_decimal_only(cls, value: object) -> object:
        if value is None:
            return value
        return _require_decimal(value)

    @model_validator(mode="after")
    def decision_is_consistent(self) -> "BudgetDecision":
        evaluated = self.status in {
            BudgetEvaluationStatus.APPROVED,
            BudgetEvaluationStatus.DENIED,
        }
        if evaluated:
            if self.cost_estimate_status is not CostEstimateStatus.COMPLETE:
                raise ValueError("budget approval or denial requires complete cost")
            if (
                self.estimated_internal_cost is None
                or self.effective_maximum_internal_cost is None
                or self.currency is None
                or not self.applied_limit_refs
            ):
                raise ValueError("evaluated budget decision requires complete facts")
        if self.status is BudgetEvaluationStatus.APPROVED and not set(self.reasons) <= {
            BudgetDecisionReason.WITHIN_LIMIT,
            BudgetDecisionReason.LIMIT_EXACTLY_MET,
        }:
            raise ValueError("approved decision requires an approval reason")
        if self.status is BudgetEvaluationStatus.DENIED and self.reasons != (
            BudgetDecisionReason.LIMIT_EXCEEDED,
        ):
            raise ValueError("denied decision requires limit exceeded")
        return self


def _base_decision(
    request: BudgetDecisionRequest,
    *,
    status: BudgetEvaluationStatus,
    reason: BudgetDecisionReason,
) -> BudgetDecision:
    estimate = request.cost_estimate
    return BudgetDecision(
        decision_ref=request.decision_ref,
        request_id=request.request_id,
        status=status,
        reasons=(reason,),
        budget_policy_ref=request.policy.budget_policy_ref,
        evaluation_policy_ref=request.policy.evaluation_policy_ref,
        cost_estimate_ref=request.cost_estimate_ref,
        cost_estimate_status=estimate.status if estimate is not None else None,
    )


class BudgetController:
    """Evaluate immutable budget ceilings without cost or balance ownership."""

    def evaluate(self, request: BudgetDecisionRequest) -> BudgetDecision:
        if not isinstance(request, BudgetDecisionRequest):
            raise BudgetControllerError(
                BudgetControllerErrorCode.INVALID_DECISION_REQUEST
            )

        estimate = request.cost_estimate
        if estimate is None:
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNAVAILABLE,
                reason=BudgetDecisionReason.COST_ESTIMATE_MISSING,
            )
        if estimate.status is CostEstimateStatus.UNSUPPORTED:
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNSUPPORTED,
                reason=BudgetDecisionReason.COST_ESTIMATE_UNSUPPORTED,
            )
        if estimate.status is CostEstimateStatus.UNAVAILABLE:
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNAVAILABLE,
                reason=BudgetDecisionReason.COST_ESTIMATE_UNAVAILABLE,
            )
        if estimate.status is CostEstimateStatus.PARTIAL:
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNAVAILABLE,
                reason=BudgetDecisionReason.COST_ESTIMATE_PARTIAL,
            )

        if estimate.estimated_internal_cost is None:
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNAVAILABLE,
                reason=BudgetDecisionReason.COST_ESTIMATE_UNAVAILABLE,
            )

        scopes = set(request.applicable_scopes)
        applicable = tuple(
            sorted(
                (limit for limit in request.policy.limits if limit.scope in scopes),
                key=lambda limit: limit.limit_ref,
            )
        )
        if not applicable:
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNAVAILABLE,
                reason=BudgetDecisionReason.NO_APPLICABLE_LIMIT,
            )
        if any(limit.currency != estimate.currency for limit in applicable):
            return _base_decision(
                request,
                status=BudgetEvaluationStatus.UNAVAILABLE,
                reason=BudgetDecisionReason.CURRENCY_MISMATCH,
            )

        effective_maximum = min(
            limit.maximum_internal_cost for limit in applicable
        )
        applied_refs = tuple(limit.limit_ref for limit in applicable)
        cost = estimate.estimated_internal_cost
        if cost > effective_maximum:
            status = BudgetEvaluationStatus.DENIED
            reasons = (BudgetDecisionReason.LIMIT_EXCEEDED,)
        elif cost == effective_maximum:
            status = BudgetEvaluationStatus.APPROVED
            reasons = (BudgetDecisionReason.LIMIT_EXACTLY_MET,)
        else:
            status = BudgetEvaluationStatus.APPROVED
            reasons = (BudgetDecisionReason.WITHIN_LIMIT,)

        return BudgetDecision(
            decision_ref=request.decision_ref,
            request_id=request.request_id,
            status=status,
            reasons=reasons,
            budget_policy_ref=request.policy.budget_policy_ref,
            evaluation_policy_ref=request.policy.evaluation_policy_ref,
            cost_estimate_ref=request.cost_estimate_ref,
            cost_estimate_status=estimate.status,
            currency=estimate.currency,
            estimated_internal_cost=cost,
            effective_maximum_internal_cost=effective_maximum,
            applied_limit_refs=applied_refs,
        )
