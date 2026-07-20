"""Tests for deterministic provider-internal cost estimation."""

from __future__ import annotations

import ast
import importlib.util
import inspect
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

import pytest
from pydantic import ValidationError

from ai_platform.contracts import ProviderUsage, ProviderUsageCertainty
from ai_platform.pricing import (
    ESTIMATION_DECIMAL_PRECISION_POLICY,
    ROUNDING_POLICY_REF,
    CostEstimateRequest,
    CostEstimateStatus,
    CostEstimationError,
    CostEstimationErrorCode,
    PricingModel,
    ProviderInternalCostEstimator,
    ProviderPricingFact,
)


ROOT = Path(__file__).resolve().parents[3]
MODULE = ROOT / "python_services" / "ai_platform" / "pricing.py"
NOW = datetime(2026, 7, 19, 12, tzinfo=timezone.utc)


def _usage(
    *,
    certainty: ProviderUsageCertainty = ProviderUsageCertainty.KNOWN,
    input_tokens: int | None = 1_000,
    output_tokens: int | None = None,
    additional: dict[str, Decimal] | None = None,
) -> ProviderUsage:
    return ProviderUsage(
        certainty=certainty,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        additional_native_units=additional or {},
    )


def _fact(
    unit: str = "input_tokens",
    *,
    fact_id: str | None = None,
    provider: str = "provider.test",
    model: str = "model.test",
    currency: str = "USD",
    price: Decimal = Decimal("0.003"),
    unit_quantity: Decimal = Decimal("1000"),
    pricing_model: PricingModel = PricingModel.PER_UNIT,
    effective_from: datetime = NOW - timedelta(days=1),
    effective_until: datetime = NOW + timedelta(days=1),
) -> ProviderPricingFact:
    return ProviderPricingFact(
        pricing_fact_id=fact_id or f"price.{unit}.v1",
        pricing_policy_version="provider-cost-policy.v1",
        provider_key=provider,
        model_key=model,
        usage_unit=unit,
        pricing_model=pricing_model,
        unit_quantity=unit_quantity,
        internal_cost_per_unit=price,
        currency=currency,
        effective_from=effective_from,
        effective_until=effective_until,
    )


def _request(
    usage: ProviderUsage | None = None,
    facts: tuple[ProviderPricingFact, ...] | None = None,
    *,
    provider: str = "provider.test",
    model: str = "model.test",
    currency: str = "USD",
    estimate_at: datetime = NOW,
    quantum: Decimal = Decimal("0.000001"),
) -> CostEstimateRequest:
    return CostEstimateRequest(
        provider_key=provider,
        model_key=model,
        currency=currency,
        estimate_at=estimate_at,
        usage=usage or _usage(),
        pricing_facts=facts if facts is not None else (_fact(),),
        currency_quantum=quantum,
    )


def _estimate(request: CostEstimateRequest):
    return ProviderInternalCostEstimator().estimate(request)


def test_complete_known_usage_estimate_preserves_provenance():
    result = _estimate(_request())

    assert result.status is CostEstimateStatus.COMPLETE
    assert result.estimated_internal_cost == Decimal("0.003000")
    assert result.currency == "USD"
    assert result.priced_usage_units == ("input_tokens",)
    assert result.missing_usage_units == ()
    assert result.pricing_fact_refs == ("price.input_tokens.v1",)
    assert result.pricing_policy_refs == ("provider-cost-policy.v1",)
    assert result.rounding_policy_ref == ROUNDING_POLICY_REF


def test_dtos_are_frozen():
    fact = _fact()
    request = _request(facts=(fact,))
    result = _estimate(request)

    for value, field, replacement in (
        (fact, "currency", "SAR"),
        (request, "currency", "SAR"),
        (result, "currency", "SAR"),
    ):
        with pytest.raises(ValidationError):
            setattr(value, field, replacement)


@pytest.mark.parametrize(
    ("field", "value"),
    (
        ("unit_quantity", 1000.0),
        ("internal_cost_per_unit", 0.003),
    ),
)
def test_pricing_fact_rejects_float_financial_values(field, value):
    values = _fact().model_dump()
    values[field] = value
    with pytest.raises(ValidationError):
        ProviderPricingFact(**values)


def test_request_rejects_float_currency_quantum():
    values = _request().model_dump()
    values["currency_quantum"] = 0.01
    with pytest.raises(ValidationError):
        CostEstimateRequest(**values)


@pytest.mark.parametrize("value", ("0.01", 1, 1.0))
def test_financial_fields_require_decimal_instances(value):
    values = _fact().model_dump()
    values["internal_cost_per_unit"] = value
    with pytest.raises(ValidationError):
        ProviderPricingFact(**values)


def test_provider_mismatch_is_unavailable_and_never_converted():
    result = _estimate(_request(provider="provider.other"))
    assert result.status is CostEstimateStatus.UNAVAILABLE
    assert result.estimated_internal_cost is None
    assert result.missing_usage_units == ("input_tokens",)


def test_model_mismatch_is_unavailable():
    result = _estimate(_request(model="model.other"))
    assert result.status is CostEstimateStatus.UNAVAILABLE
    assert result.estimated_internal_cost is None


def test_currency_mismatch_is_unavailable_without_conversion():
    result = _estimate(_request(currency="SAR"))
    assert result.status is CostEstimateStatus.UNAVAILABLE
    assert result.currency == "SAR"
    assert result.estimated_internal_cost is None


def test_effective_interval_includes_lower_boundary():
    fact = _fact(effective_from=NOW, effective_until=NOW + timedelta(seconds=1))
    result = _estimate(_request(facts=(fact,), estimate_at=NOW))
    assert result.status is CostEstimateStatus.COMPLETE


def test_effective_interval_excludes_upper_boundary():
    fact = _fact(effective_from=NOW - timedelta(seconds=1), effective_until=NOW)
    result = _estimate(_request(facts=(fact,), estimate_at=NOW))
    assert result.status is CostEstimateStatus.UNAVAILABLE


def test_pricing_fact_rejects_empty_or_reversed_interval():
    for until in (NOW, NOW - timedelta(seconds=1)):
        with pytest.raises(ValidationError):
            _fact(effective_from=NOW, effective_until=until)


def test_explicit_zero_usage_is_complete_without_a_rate():
    usage = _usage(
        certainty=ProviderUsageCertainty.KNOWN_ZERO,
        input_tokens=0,
    )
    result = _estimate(_request(usage=usage, facts=()))
    assert result.status is CostEstimateStatus.COMPLETE
    assert result.estimated_internal_cost == Decimal("0.000000")
    assert result.priced_usage_units == ()
    assert result.zero_usage_units == ("input_tokens",)
    assert result.pricing_fact_refs == ()


def test_partial_estimate_prices_known_units_and_lists_missing_units():
    usage = _usage(input_tokens=1_000, output_tokens=500)
    result = _estimate(_request(usage=usage, facts=(_fact(),)))

    assert result.status is CostEstimateStatus.PARTIAL
    assert result.estimated_internal_cost == Decimal("0.003000")
    assert result.priced_usage_units == ("input_tokens",)
    assert result.missing_usage_units == ("output_tokens",)


def test_no_applicable_facts_is_unavailable():
    result = _estimate(_request(facts=()))
    assert result.status is CostEstimateStatus.UNAVAILABLE
    assert result.estimated_internal_cost is None
    assert result.pricing_fact_refs == ()


def test_no_reported_usage_dimensions_is_unavailable_not_zero_cost():
    usage = ProviderUsage(certainty=ProviderUsageCertainty.UNCERTAIN)
    result = _estimate(_request(usage=usage))
    assert result.status is CostEstimateStatus.UNAVAILABLE
    assert result.estimated_internal_cost is None
    assert result.priced_usage_units == ()


def test_existing_unsupported_pricing_model_is_unsupported():
    fact = _fact(pricing_model=PricingModel.TIERED)
    result = _estimate(_request(facts=(fact,)))
    assert result.status is CostEstimateStatus.UNSUPPORTED
    assert result.estimated_internal_cost is None
    assert result.unsupported_usage_units == ("input_tokens",)


def test_supported_and_unsupported_units_produce_partial_estimate():
    usage = _usage(input_tokens=1000, output_tokens=100)
    facts = (
        _fact("input_tokens"),
        _fact("output_tokens", pricing_model=PricingModel.TIERED),
    )
    result = _estimate(_request(usage=usage, facts=facts))
    assert result.status is CostEstimateStatus.PARTIAL
    assert result.estimated_internal_cost == Decimal("0.003000")
    assert result.unsupported_usage_units == ("output_tokens",)


def test_additional_native_usage_unit_can_be_priced_exactly():
    usage = _usage(input_tokens=None, additional={"images": Decimal("2")})
    fact = _fact(
        "images",
        price=Decimal("0.004"),
        unit_quantity=Decimal("1"),
    )
    result = _estimate(_request(usage=usage, facts=(fact,)))
    assert result.status is CostEstimateStatus.COMPLETE
    assert result.estimated_internal_cost == Decimal("0.008000")


def test_exact_duplicate_pricing_facts_are_rejected_with_stable_error():
    fact = _fact()
    with pytest.raises(CostEstimationError) as captured:
        _estimate(_request(facts=(fact, fact)))
    assert captured.value.code is CostEstimationErrorCode.DUPLICATE_PRICING_FACT
    assert str(captured.value) == "duplicate_pricing_fact"


def test_multiple_applicable_facts_for_one_unit_are_ambiguous():
    facts = (_fact(fact_id="price.a"), _fact(fact_id="price.b"))
    with pytest.raises(CostEstimationError) as captured:
        _estimate(_request(facts=facts))
    assert captured.value.code is CostEstimationErrorCode.AMBIGUOUS_PRICING_FACT


def test_half_even_rounding_is_explicit_and_deterministic():
    down = _fact(price=Decimal("0.0025"), unit_quantity=Decimal("1"))
    up = _fact(price=Decimal("0.0035"), unit_quantity=Decimal("1"))
    usage = _usage(input_tokens=1)

    down_result = _estimate(
        _request(usage=usage, facts=(down,), quantum=Decimal("0.001"))
    )
    up_result = _estimate(
        _request(usage=usage, facts=(up,), quantum=Decimal("0.001"))
    )
    assert down_result.estimated_internal_cost == Decimal("0.002")
    assert up_result.estimated_internal_cost == Decimal("0.004")


def test_decimal_precision_policy_is_explicit_and_versioned():
    assert ESTIMATION_DECIMAL_PRECISION_POLICY == (
        "double-largest-significand-plus-20-guard-digits-capped-500.v1"
    )


def test_large_values_remain_decimal_and_exact():
    usage = _usage(input_tokens=10**60)
    fact = _fact(price=Decimal("99999999999999999999.999"))
    result = _estimate(
        _request(usage=usage, facts=(fact,), quantum=Decimal("0.001"))
    )
    assert isinstance(result.estimated_internal_cost, Decimal)
    assert result.estimated_internal_cost == Decimal(
        "99999999999999999999999000000000000000000000000000000000000000000000000000000.000"
    )


def test_order_independence_for_facts_and_usage_units():
    facts = (
        _fact("output_tokens", price=Decimal("0.006")),
        _fact("input_tokens", price=Decimal("0.003")),
        _fact("images", price=Decimal("0.01"), unit_quantity=Decimal("1")),
    )
    first_usage = _usage(
        input_tokens=1000,
        output_tokens=500,
        additional={"images": Decimal("2"), "audio_seconds": Decimal("0")},
    )
    second_usage = ProviderUsage(
        certainty=ProviderUsageCertainty.KNOWN,
        output_tokens=500,
        input_tokens=1000,
        additional_native_units={
            "audio_seconds": Decimal("0"),
            "images": Decimal("2"),
        },
    )

    first = _estimate(_request(usage=first_usage, facts=facts))
    second = _estimate(_request(usage=second_usage, facts=tuple(reversed(facts))))
    assert first == second


def test_uncertain_usage_can_still_have_complete_unit_coverage():
    usage = _usage(
        certainty=ProviderUsageCertainty.UNCERTAIN,
        input_tokens=1000,
    )
    result = _estimate(_request(usage=usage))
    assert result.status is CostEstimateStatus.COMPLETE
    assert result.usage_certainty is ProviderUsageCertainty.UNCERTAIN


def test_errors_and_representations_do_not_include_financial_values():
    secret_rate = Decimal("987654321.123456")
    fact = _fact(price=secret_rate)
    with pytest.raises(CostEstimationError) as captured:
        _estimate(_request(facts=(fact, fact)))
    representations = (str(captured.value), repr(captured.value), str(captured.value.args))
    assert all(str(secret_rate) not in value for value in representations)


def test_invalid_request_type_uses_stable_redacted_error():
    with pytest.raises(CostEstimationError) as captured:
        ProviderInternalCostEstimator().estimate(object())  # type: ignore[arg-type]
    assert captured.value.code is CostEstimationErrorCode.INVALID_ESTIMATION_REQUEST


def test_module_has_no_forbidden_imports_or_runtime_dependencies():
    tree = ast.parse(MODULE.read_text(encoding="utf-8"))
    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module.split(".")[0])

    forbidden = {
        "anthropic",
        "fastapi",
        "firebase_admin",
        "google",
        "httpx",
        "openai",
        "requests",
        "sqlalchemy",
    }
    assert imported.isdisjoint(forbidden)
    source = MODULE.read_text(encoding="utf-8").lower()
    for forbidden_term in (
        "aigateway",
        "ledgerwriter",
        "firestore",
        "customer_price",
        "credit_reservation",
    ):
        assert forbidden_term not in source


def test_import_is_inert(monkeypatch):
    blocked = []

    def fail(*args, **kwargs):
        blocked.append((args, kwargs))
        raise AssertionError("I/O attempted during import")

    monkeypatch.setattr("builtins.open", fail)
    monkeypatch.setattr("socket.socket", fail)
    module_name = "ai_platform._pricing_import_safety_probe"
    spec = importlib.util.spec_from_file_location(module_name, MODULE)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    try:
        spec.loader.exec_module(module)
    finally:
        sys.modules.pop(module_name, None)
    assert blocked == []


def test_estimator_source_contains_no_float_arithmetic():
    source = inspect.getsource(ProviderInternalCostEstimator)
    assert "float(" not in source
    assert "Decimal(" in source
