"""Tests for the pure deterministic Phase 9 Budget Controller."""

from __future__ import annotations

import ast
import importlib.util
import sys
from decimal import Decimal
from pathlib import Path

import pytest
from pydantic import ValidationError

from ai_platform.budget import (
    BudgetController,
    BudgetControllerError,
    BudgetControllerErrorCode,
    BudgetDecision,
    BudgetDecisionReason,
    BudgetDecisionRequest,
    BudgetEvaluationStatus,
    BudgetLimit,
    BudgetPolicy,
    BudgetScope,
)
from ai_platform.contracts import ProviderUsageCertainty
from ai_platform.pricing import CostEstimateResult, CostEstimateStatus


ROOT = Path(__file__).resolve().parents[3]
MODULE = ROOT / "python_services" / "ai_platform" / "budget.py"


def _estimate(
    cost: Decimal = Decimal("0.005"),
    *,
    status: CostEstimateStatus = CostEstimateStatus.COMPLETE,
    currency: str = "USD",
) -> CostEstimateResult:
    priced = status in {CostEstimateStatus.COMPLETE, CostEstimateStatus.PARTIAL}
    kwargs = {}
    if status is CostEstimateStatus.PARTIAL:
        kwargs["missing_usage_units"] = ("output_tokens",)
    elif status is CostEstimateStatus.UNSUPPORTED:
        kwargs["unsupported_usage_units"] = ("input_tokens",)
    return CostEstimateResult(
        status=status,
        provider_key="provider.test",
        model_key="model.test",
        currency=currency,
        estimated_internal_cost=cost if priced else None,
        usage_certainty=ProviderUsageCertainty.KNOWN,
        priced_usage_units=("input_tokens",) if priced else (),
        pricing_fact_refs=("price.input.v1",) if priced else (),
        pricing_policy_refs=("pricing-policy.v1",) if priced else (),
        **kwargs,
    )


def _limit(
    maximum: Decimal = Decimal("0.01"),
    *,
    ref: str = "budget.request.v1",
    scope: BudgetScope = BudgetScope.REQUEST,
    currency: str = "USD",
) -> BudgetLimit:
    return BudgetLimit(
        limit_ref=ref,
        scope=scope,
        maximum_internal_cost=maximum,
        currency=currency,
    )


def _policy(limits: tuple[BudgetLimit, ...] | None = None) -> BudgetPolicy:
    return BudgetPolicy(
        budget_policy_ref="budget-policy.v1",
        evaluation_policy_ref="budget-evaluation.v1",
        limits=limits or (_limit(),),
    )


def _request(
    estimate: CostEstimateResult | None = None,
    *,
    policy: BudgetPolicy | None = None,
    scopes: tuple[BudgetScope, ...] = (BudgetScope.REQUEST,),
) -> BudgetDecisionRequest:
    return BudgetDecisionRequest(
        decision_ref="budget-decision.request-1",
        request_id="request-1",
        cost_estimate_ref="cost-estimate.request-1",
        applicable_scopes=scopes,
        policy=policy or _policy(),
        cost_estimate=estimate if estimate is not None else _estimate(),
    )


def _evaluate(request: BudgetDecisionRequest) -> BudgetDecision:
    return BudgetController().evaluate(request)


def test_approves_cost_below_effective_limit_with_provenance():
    decision = _evaluate(_request(_estimate(Decimal("0.005"))))

    assert decision.status is BudgetEvaluationStatus.APPROVED
    assert decision.reasons == (BudgetDecisionReason.WITHIN_LIMIT,)
    assert decision.estimated_internal_cost == Decimal("0.005")
    assert decision.effective_maximum_internal_cost == Decimal("0.01")
    assert decision.budget_policy_ref == "budget-policy.v1"
    assert decision.evaluation_policy_ref == "budget-evaluation.v1"
    assert decision.cost_estimate_ref == "cost-estimate.request-1"
    assert decision.applied_limit_refs == ("budget.request.v1",)


def test_denies_cost_above_limit():
    decision = _evaluate(_request(_estimate(Decimal("0.011"))))
    assert decision.status is BudgetEvaluationStatus.DENIED
    assert decision.reasons == (BudgetDecisionReason.LIMIT_EXCEEDED,)


def test_exact_limit_is_approved_with_distinct_explanation():
    decision = _evaluate(_request(_estimate(Decimal("0.01"))))
    assert decision.status is BudgetEvaluationStatus.APPROVED
    assert decision.reasons == (BudgetDecisionReason.LIMIT_EXACTLY_MET,)


def test_zero_cost_is_approved():
    decision = _evaluate(_request(_estimate(Decimal("0"))))
    assert decision.status is BudgetEvaluationStatus.APPROVED
    assert decision.reasons == (BudgetDecisionReason.WITHIN_LIMIT,)


def test_unsupported_estimate_produces_unsupported_decision():
    decision = _evaluate(
        _request(_estimate(status=CostEstimateStatus.UNSUPPORTED))
    )
    assert decision.status is BudgetEvaluationStatus.UNSUPPORTED
    assert decision.reasons == (BudgetDecisionReason.COST_ESTIMATE_UNSUPPORTED,)
    assert decision.estimated_internal_cost is None


def test_unavailable_estimate_produces_unavailable_decision():
    decision = _evaluate(
        _request(_estimate(status=CostEstimateStatus.UNAVAILABLE))
    )
    assert decision.status is BudgetEvaluationStatus.UNAVAILABLE
    assert decision.reasons == (BudgetDecisionReason.COST_ESTIMATE_UNAVAILABLE,)


def test_partial_estimate_fails_closed_without_becoming_denial():
    decision = _evaluate(
        _request(_estimate(status=CostEstimateStatus.PARTIAL))
    )
    assert decision.status is BudgetEvaluationStatus.UNAVAILABLE
    assert decision.reasons == (BudgetDecisionReason.COST_ESTIMATE_PARTIAL,)


def test_missing_estimate_is_unavailable():
    request = BudgetDecisionRequest(
        decision_ref="budget-decision.request-1",
        request_id="request-1",
        cost_estimate_ref="cost-estimate.request-1",
        applicable_scopes=(BudgetScope.REQUEST,),
        policy=_policy(),
        cost_estimate=None,
    )
    decision = _evaluate(request)
    assert decision.status is BudgetEvaluationStatus.UNAVAILABLE
    assert decision.reasons == (BudgetDecisionReason.COST_ESTIMATE_MISSING,)
    assert decision.cost_estimate_status is None


def test_no_applicable_limit_is_unavailable():
    decision = _evaluate(
        _request(scopes=(BudgetScope.FEATURE,))
    )
    assert decision.status is BudgetEvaluationStatus.UNAVAILABLE
    assert decision.reasons == (BudgetDecisionReason.NO_APPLICABLE_LIMIT,)


def test_currency_mismatch_is_unavailable_without_conversion():
    decision = _evaluate(_request(_estimate(currency="SAR")))
    assert decision.status is BudgetEvaluationStatus.UNAVAILABLE
    assert decision.reasons == (BudgetDecisionReason.CURRENCY_MISMATCH,)
    assert decision.estimated_internal_cost is None


def test_strictest_applicable_limit_controls_decision():
    policy = _policy(
        (
            _limit(Decimal("0.02"), ref="limit.request", scope=BudgetScope.REQUEST),
            _limit(Decimal("0.004"), ref="limit.feature", scope=BudgetScope.FEATURE),
        )
    )
    decision = _evaluate(
        _request(
            _estimate(Decimal("0.005")),
            policy=policy,
            scopes=(BudgetScope.REQUEST, BudgetScope.FEATURE),
        )
    )
    assert decision.status is BudgetEvaluationStatus.DENIED
    assert decision.effective_maximum_internal_cost == Decimal("0.004")
    assert decision.applied_limit_refs == ("limit.feature", "limit.request")


def test_limit_order_and_scope_order_do_not_change_decision():
    limits = (
        _limit(Decimal("0.02"), ref="limit.request", scope=BudgetScope.REQUEST),
        _limit(Decimal("0.01"), ref="limit.feature", scope=BudgetScope.FEATURE),
        _limit(Decimal("0.03"), ref="limit.tenant", scope=BudgetScope.TENANT),
    )
    first = _evaluate(
        _request(
            policy=_policy(limits),
            scopes=(BudgetScope.REQUEST, BudgetScope.FEATURE, BudgetScope.TENANT),
        )
    )
    second = _evaluate(
        _request(
            policy=_policy(tuple(reversed(limits))),
            scopes=(BudgetScope.TENANT, BudgetScope.FEATURE, BudgetScope.REQUEST),
        )
    )
    assert first == second


def test_repeated_evaluation_is_deterministic():
    request = _request()
    controller = BudgetController()
    assert controller.evaluate(request) == controller.evaluate(request)


def test_phase_9_dtos_are_immutable():
    limit = _limit()
    policy = _policy((limit,))
    request = _request(policy=policy)
    decision = _evaluate(request)
    for value, field in (
        (limit, "currency"),
        (policy, "budget_policy_ref"),
        (request, "request_id"),
        (decision, "status"),
    ):
        with pytest.raises(ValidationError):
            setattr(value, field, "changed")


@pytest.mark.parametrize("value", (0.01, 1, "0.01"))
def test_budget_limits_reject_non_decimal_financial_values(value):
    with pytest.raises(ValidationError):
        _limit(value)  # type: ignore[arg-type]


def test_budget_limit_rejects_negative_value():
    with pytest.raises(ValidationError):
        _limit(Decimal("-0.01"))


def test_policy_requires_at_least_one_limit():
    with pytest.raises(ValidationError):
        BudgetPolicy(
            budget_policy_ref="budget-policy.v1",
            evaluation_policy_ref="budget-evaluation.v1",
            limits=(),
        )


def test_policy_rejects_duplicate_limit_references():
    with pytest.raises(ValidationError):
        _policy((_limit(), _limit(maximum=Decimal("0.02"))))


def test_request_rejects_duplicate_scopes():
    with pytest.raises(ValidationError):
        _request(scopes=(BudgetScope.REQUEST, BudgetScope.REQUEST))


def test_decision_validator_prevents_approval_without_complete_cost():
    values = _evaluate(_request()).model_dump()
    values["cost_estimate_status"] = CostEstimateStatus.PARTIAL
    with pytest.raises(ValidationError):
        BudgetDecision(**values)


def test_invalid_request_type_has_stable_redacted_error():
    with pytest.raises(BudgetControllerError) as captured:
        BudgetController().evaluate(object())  # type: ignore[arg-type]
    assert captured.value.code is BudgetControllerErrorCode.INVALID_DECISION_REQUEST
    assert str(captured.value) == "invalid_decision_request"


def test_errors_do_not_include_budget_or_cost_values():
    sensitive_value = Decimal("987654321.123456")
    with pytest.raises(BudgetControllerError) as captured:
        BudgetController().evaluate(sensitive_value)  # type: ignore[arg-type]
    representations = (str(captured.value), repr(captured.value), str(captured.value.args))
    assert all(str(sensitive_value) not in value for value in representations)


def test_module_has_no_forbidden_imports_or_runtime_dependencies():
    tree = ast.parse(MODULE.read_text(encoding="utf-8"))
    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module.split(".")[0])
    assert imported.isdisjoint(
        {
            "anthropic",
            "fastapi",
            "firebase_admin",
            "google",
            "httpx",
            "openai",
            "requests",
            "sqlalchemy",
        }
    )
    source = MODULE.read_text(encoding="utf-8").lower()
    for term in (
        "aigateway",
        "ledgerwriter",
        "firestore",
        "provideradapter",
        "creditreservation",
        "customer_price",
    ):
        assert term not in source


def test_import_is_inert(monkeypatch):
    attempted_io = []

    def fail(*args, **kwargs):
        attempted_io.append((args, kwargs))
        raise AssertionError("I/O attempted during import")

    monkeypatch.setattr("builtins.open", fail)
    monkeypatch.setattr("socket.socket", fail)
    module_name = "ai_platform._budget_import_safety_probe"
    spec = importlib.util.spec_from_file_location(module_name, MODULE)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    try:
        spec.loader.exec_module(module)
    finally:
        sys.modules.pop(module_name, None)
    assert attempted_io == []


def test_module_performs_no_logging_or_side_effect_calls():
    source = MODULE.read_text(encoding="utf-8")
    assert "logging" not in source
    assert "print(" not in source
    assert "open(" not in source
    assert "float(" not in source
