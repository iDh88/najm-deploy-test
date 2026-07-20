"""Contract-only tests for the inert NAJM AI Platform scaffolding."""

from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest
from pydantic import ValidationError

from ai_platform.contracts import (
    AIFallbackReason,
    AIFeatureKeyCategory,
    AIGatewayRequest,
    AIGatewayResponse,
    AIContextRef,
    AIErrorDetail,
    AIExecutionMode,
    AIExecutionPlan,
    AIOrchestratorRequest,
    AIOrchestratorResponse,
    AIPrincipalRef,
    AIRequestStatus,
    AISafetyDecision,
    AISafetyLevel,
    BudgetDecisionRef,
    BudgetDecisionResult,
    CreditReservationRef,
    CreditReservationStatus,
    EntitlementDecisionRef,
    ErrorFactState,
    FallbackAttempt,
    FeatureFlagDecisionRef,
    GatewayAttemptStatus,
    LedgerCreditDirection,
    LedgerEventDraft,
    LedgerEventType,
    ModelLifecycleState,
    ModelRegistryRef,
    NormalizedAIInput,
    NormalizedMessage,
    PromptLifecycleState,
    PromptRegistryRef,
    ProviderCapability,
    ProviderCostCertainty,
    ProviderLifecycleState,
    ProviderRegistryRef,
    ProviderResponseRef,
    ProviderUsage,
    ProviderUsageCertainty,
    RouteDecision,
    SafetyDecisionRef,
)
from ai_platform.errors import AIPlatformErrorCode, ProviderErrorCode


NOW = datetime(2026, 7, 16, 8, 0, tzinfo=timezone.utc)
LATER = NOW + timedelta(minutes=5)


def _principal() -> AIPrincipalRef:
    return AIPrincipalRef(
        principal_id="user-123",
        authorization_ref="authz-decision-1",
        organization_id="org-1",
    )


def _provider() -> ProviderRegistryRef:
    return ProviderRegistryRef(
        provider_key="provider.primary",
        registry_revision="provider-rev-1",
        adapter_key="adapter.primary",
        adapter_contract_version="1",
        lifecycle=ProviderLifecycleState.ENABLED,
    )


def _model() -> ModelRegistryRef:
    return ModelRegistryRef(
        model_key="model.general",
        model_revision="model-rev-1",
        provider_key="provider.primary",
        lifecycle=ModelLifecycleState.ENABLED,
        capabilities={ProviderCapability.TEXT_GENERATION},
    )


def _prompt() -> PromptRegistryRef:
    return PromptRegistryRef(
        prompt_family_key="assistant.general",
        prompt_version="prompt-v1",
        registry_revision="prompt-rev-1",
        content_hash="sha256-prompt-1",
        lifecycle=PromptLifecycleState.ACTIVE,
    )


def _feature_flag() -> FeatureFlagDecisionRef:
    return FeatureFlagDecisionRef(
        evaluation_id="flag-eval-1",
        flag_key="ai.assistant",
        feature_key="ai.assistant",
        flag_version="flag-v1",
        allowed=True,
        reason_code="cohort_allowed",
        source_ref="feature-policy-1",
        evaluated_at=NOW,
    )


def _entitlement() -> EntitlementDecisionRef:
    return EntitlementDecisionRef(
        decision_id="entitlement-1",
        feature_key="ai.assistant",
        policy_version="entitlement-v1",
        allowed=True,
        reason_code="compatibility_allowed",
        evaluated_at=NOW,
    )


def _safety() -> SafetyDecisionRef:
    return SafetyDecisionRef(
        decision_id="safety-1",
        feature_key="ai.assistant",
        policy_version="safety-v1",
        level=AISafetyLevel.GENERAL_ASSISTANCE,
        decision=AISafetyDecision.ALLOWED,
        evaluated_at=NOW,
    )


def _budget() -> BudgetDecisionRef:
    return BudgetDecisionRef(
        decision_id="budget-1",
        request_id="request-1",
        feature_key="ai.assistant",
        policy_version="budget-v1",
        result=BudgetDecisionResult.BOUNDED_ALLOW,
        evaluated_at=NOW,
        expires_at=LATER,
        max_najm_credits=Decimal("3"),
        max_attempts=2,
    )


def _reservation() -> CreditReservationRef:
    return CreditReservationRef(
        reservation_id="reservation-1",
        request_id="request-1",
        idempotency_key="idem-1",
        status=CreditReservationStatus.ACTIVE,
        credit_policy_version="credit-v1",
        maximum_najm_credits=Decimal("3"),
        reserved_najm_credits=Decimal("3"),
        account_id="credit-account-1",
    )


def _execution_plan() -> AIExecutionPlan:
    return AIExecutionPlan(
        contract_version="1",
        plan_id="plan-1",
        request_id="request-1",
        attempt_id="attempt-1",
        idempotency_key="idem-1",
        trace_id="trace-1",
        feature_key="ai.assistant",
        task_type="answer",
        execution_mode=AIExecutionMode.PROVIDER,
        route_decision=RouteDecision.PROVIDER_EXECUTION,
        feature_flag=_feature_flag(),
        entitlement=_entitlement(),
        safety=_safety(),
        budget=_budget(),
        credit_reservation=_reservation(),
        provider=_provider(),
        model=_model(),
        prompt=_prompt(),
        capability=ProviderCapability.TEXT_GENERATION,
        normalized_input=NormalizedAIInput(
            messages=(
                NormalizedMessage(
                    role="user",
                    content="Explain this governed result.",
                ),
            ),
        ),
        output_contract_ref="output.text.v1",
        deadline_at=LATER,
        timeout_ms=3000,
        data_classification="internal",
        retention_policy_ref="retention.standard",
    )


@pytest.mark.parametrize(
    ("enum_type", "expected"),
    [
        (
            AIFeatureKeyCategory,
            ["unspecified"],
        ),
        (
            AIRequestStatus,
            [
                "pending",
                "in_progress",
                "completed",
                "denied",
                "unavailable",
                "deterministic_only",
                "cached",
                "abstained",
                "invalid",
                "failed",
                "cancelled",
            ],
        ),
        (AIExecutionMode, ["provider", "deterministic_only", "cache", "none"]),
        (
            AISafetyLevel,
            [
                "general_assistance",
                "grounded_operational_information",
                "aviation_sensitive_advisory",
                "deterministic_exclusive",
            ],
        ),
        (
            AISafetyDecision,
            [
                "allowed",
                "grounded",
                "deterministic_only",
                "abstained",
                "refused",
                "degraded",
                "unavailable",
                "escalated",
            ],
        ),
        (
            AIFallbackReason,
            [
                "provider_unavailable",
                "model_unavailable",
                "capability_unavailable",
                "rate_limited",
                "timeout",
                "transport_failure",
                "route_suspended",
                "incident_policy",
            ],
        ),
        (
            ProviderCapability,
            [
                "text_generation",
                "structured_output",
                "tool_calling",
                "embeddings",
                "vision",
                "streaming",
                "usage_reporting",
                "provider_side_caching",
            ],
        ),
        (
            ModelLifecycleState,
            [
                "proposed",
                "evaluating",
                "approved_disabled",
                "enabled",
                "deprecated",
                "suspended",
                "retired",
            ],
        ),
        (
            PromptLifecycleState,
            [
                "draft",
                "in_review",
                "approved",
                "staged",
                "active",
                "superseded",
                "suspended",
                "retired",
            ],
        ),
        (
            RouteDecision,
            ["allow", "deny", "deterministic_only", "cache", "provider_execution"],
        ),
        (BudgetDecisionResult, ["allow", "deny", "bounded_allow"]),
        (
            CreditReservationStatus,
            [
                "requested",
                "active",
                "amended",
                "reconciliation_pending",
                "reconciled",
                "released",
                "expired",
                "disputed",
                "adjusted",
            ],
        ),
        (
            LedgerEventType,
            [
                "credit_allocation",
                "reservation",
                "provider_attempt",
                "usage_outcome",
                "credit_reconciliation",
                "cost_reconciliation",
                "adjustment",
                "audit",
            ],
        ),
    ],
)
def test_required_enum_values_are_stable(enum_type, expected):
    assert [member.value for member in enum_type] == expected


def test_error_codes_are_stable_strings():
    assert [member.value for member in AIPlatformErrorCode] == [
        "feature_disabled",
        "entitlement_denied",
        "budget_denied",
        "credit_reservation_denied",
        "safety_denied",
        "prompt_unavailable",
        "model_unavailable",
        "provider_unavailable",
        "provider_timeout",
        "malformed_provider_response",
        "unsupported_capability",
        "idempotency_conflict",
        "invalid_ledger_event",
        "ledger_unavailable",
        "configuration_unavailable",
    ]
    assert all(isinstance(member.value, str) for member in AIPlatformErrorCode)
    assert [member.value for member in ProviderErrorCode] == [
        "configuration_unavailable",
        "authentication_or_credential_rejected",
        "model_or_capability_unavailable",
        "invalid_normalized_request",
        "provider_invalid_request_after_translation",
        "content_blocked",
        "rate_limited_or_quota_exhausted",
        "timeout",
        "provider_unavailable",
        "transport_failure",
        "contract_or_response_shape_violation",
        "output_incomplete_or_streaming_interrupted",
        "usage_or_billing_facts_uncertain",
        "cancelled",
        "unknown_provider_failure",
    ]


def test_orchestrator_contract_round_trip_is_provider_neutral():
    request = AIOrchestratorRequest(
        contract_version="1",
        request_id="request-1",
        idempotency_key="idem-1",
        trace_id="trace-1",
        principal=_principal(),
        environment="test",
        feature_category=AIFeatureKeyCategory.UNSPECIFIED,
        feature_key="ai.assistant",
        task_type="answer",
        product_input={"question": "What does the deterministic result mean?"},
        context_refs=(
            AIContextRef(
                context_id="context-1",
                context_type="deterministic_result",
                source_ref="legality-result-1",
                source_version="rules-v1",
                data_classification="private",
                retention_policy_ref="retention.short",
            ),
        ),
        response_contract_ref="response.text.v1",
        deadline_at=LATER,
        product_transaction_ref="product-operation-1",
    )

    restored = AIOrchestratorRequest.model_validate_json(request.model_dump_json())
    assert restored == request
    dumped = request.model_dump(mode="json")
    assert "provider" not in dumped
    assert "model" not in dumped
    assert "firebase_token" not in dumped["principal"]

    response = AIOrchestratorResponse(
        contract_version="1",
        request_id=request.request_id,
        idempotency_key=request.idempotency_key,
        trace_id=request.trace_id,
        feature_key=request.feature_key,
        status=AIRequestStatus.DETERMINISTIC_ONLY,
        execution_mode=AIExecutionMode.DETERMINISTIC_ONLY,
        route_decision=RouteDecision.DETERMINISTIC_ONLY,
        safety=_safety(),
        result={"authority_ref": "legality-result-1"},
        policy_version_refs={"safety": "safety-v1"},
        provenance_refs=("legality-result-1",),
        may_commit_business_transaction=False,
    )
    assert AIOrchestratorResponse.model_validate(response.model_dump()) == response


def test_request_and_billing_effect_models_require_idempotency():
    request_data = {
        "contract_version": "1",
        "request_id": "request-1",
        "trace_id": "trace-1",
        "principal": _principal(),
        "environment": "test",
        "feature_category": "unspecified",
        "feature_key": "ai.assistant",
        "task_type": "answer",
        "response_contract_ref": "response.text.v1",
        "deadline_at": LATER,
        "product_transaction_ref": "product-operation-1",
    }
    with pytest.raises(ValidationError, match="idempotency_key"):
        AIOrchestratorRequest.model_validate(request_data)

    event_data = {
        "event_id": "event-1",
        "event_type": "usage_outcome",
        "request_id": "request-1",
        "principal": _principal(),
        "feature_key": "ai.assistant",
        "task_type": "answer",
        "occurred_at": NOW,
        "reason_code": "completed",
        "retention_class": "audit",
    }
    with pytest.raises(ValidationError, match="idempotency_key"):
        LedgerEventDraft.model_validate(event_data)


@pytest.mark.parametrize(
    ("model_type", "payload", "missing_field"),
    [
        (
            ProviderRegistryRef,
            {
                "provider_key": "provider.primary",
                "adapter_key": "adapter.primary",
                "adapter_contract_version": "1",
            },
            "registry_revision",
        ),
        (
            ModelRegistryRef,
            {
                "model_key": "model.general",
                "provider_key": "provider.primary",
                "lifecycle": "enabled",
            },
            "model_revision",
        ),
        (
            PromptRegistryRef,
            {
                "prompt_family_key": "assistant.general",
                "registry_revision": "prompt-rev-1",
                "content_hash": "sha256-prompt-1",
                "lifecycle": "active",
            },
            "prompt_version",
        ),
    ],
)
def test_registry_references_require_revisions(model_type, payload, missing_field):
    with pytest.raises(ValidationError, match=missing_field):
        model_type.model_validate(payload)


def test_provider_usage_preserves_internal_native_facts():
    usage = ProviderUsage(
        certainty=ProviderUsageCertainty.KNOWN,
        input_tokens=100,
        output_tokens=20,
        cached_tokens=40,
        reasoning_tokens=5,
        embedding_tokens=0,
        additional_native_units={"image_units": Decimal("2")},
        reported_at=NOW,
    )
    restored = ProviderUsage.model_validate_json(usage.model_dump_json())
    assert restored == usage
    assert restored.input_tokens == 100
    assert restored.embedding_tokens == 0
    assert "najm" not in usage.model_dump(mode="json")

    with pytest.raises(ValidationError):
        ProviderUsage(certainty="known", input_tokens=-1)


def test_gateway_failure_and_fallback_models_round_trip_without_raw_payloads():
    provider_response = ProviderResponseRef(
        response_ref_id="provider-response-1",
        attempt_id="attempt-1",
        provider=_provider(),
        model=_model(),
        received_at=NOW,
        provider_request_id="provider-request-1",
        response_fingerprint="sha256-response-1",
    )
    error = AIErrorDetail(
        provider_code=ProviderErrorCode.TIMEOUT,
        same_route_retry_safe=True,
        execution_may_have_occurred=False,
        usage_state=ErrorFactState.KNOWN_ZERO,
        cost_state=ErrorFactState.KNOWN_ZERO,
        diagnostic_code="provider_timeout_before_execution",
        provider_response_ref="provider-response-1",
    )
    gateway_response = AIGatewayResponse(
        contract_version="1",
        request_id="request-1",
        attempt_id="attempt-1",
        idempotency_key="idem-1",
        feature_key="ai.assistant",
        status=GatewayAttemptStatus.UNAVAILABLE,
        provider_response=provider_response,
        usage=ProviderUsage(
            certainty=ProviderUsageCertainty.KNOWN_ZERO,
            input_tokens=0,
        ),
        reported_internal_cost=Decimal("0"),
        reported_cost_currency="USD",
        cost_certainty=ProviderCostCertainty.KNOWN_ZERO,
        error=error,
    )
    fallback = FallbackAttempt(
        request_id="request-1",
        attempt_id="attempt-2",
        previous_attempt_id="attempt-1",
        idempotency_key="idem-1",
        feature_key="ai.assistant",
        ordinal=2,
        reason=AIFallbackReason.TIMEOUT,
        status=GatewayAttemptStatus.UNAVAILABLE,
        provider=_provider(),
        model=_model(),
        budget=_budget(),
        credit_reservation=_reservation(),
        error=error,
    )

    assert AIGatewayResponse.model_validate_json(gateway_response.model_dump_json()) == (
        gateway_response
    )
    assert FallbackAttempt.model_validate_json(fallback.model_dump_json()) == fallback
    assert "raw_payload" not in ProviderResponseRef.model_fields

    contradictory_usage = gateway_response.model_dump()
    contradictory_usage["usage"] = {
        "certainty": "known",
        "input_tokens": 1,
    }
    with pytest.raises(ValidationError, match="contradicts normalized usage"):
        AIGatewayResponse.model_validate(contradictory_usage)

    contradictory_cost = gateway_response.model_dump()
    contradictory_cost["reported_internal_cost"] = Decimal("1")
    with pytest.raises(ValidationError, match="requires a zero cost"):
        AIGatewayResponse.model_validate(contradictory_cost)


def test_gateway_request_requires_matching_trace_identifiers():
    plan = _execution_plan()
    request = AIGatewayRequest(
        contract_version="1",
        request_id=plan.request_id,
        attempt_id=plan.attempt_id,
        idempotency_key=plan.idempotency_key,
        trace_id=plan.trace_id,
        execution_plan_id=plan.plan_id,
        feature_key=plan.feature_key,
        provider=plan.provider,
        model=plan.model,
        prompt=plan.prompt,
        capability=plan.capability,
        normalized_input=plan.normalized_input,
        output_contract_ref=plan.output_contract_ref,
        structured_output_schema=plan.structured_output_schema,
        tool_schemas=plan.tool_schemas,
        generation_controls=plan.generation_controls,
        deadline_at=plan.deadline_at,
        timeout_ms=plan.timeout_ms,
        max_same_route_retries=plan.max_same_route_retries,
        data_classification=plan.data_classification,
        region_policy_ref=plan.region_policy_ref,
        retention_policy_ref=plan.retention_policy_ref,
    )
    assert AIGatewayRequest.model_validate_json(request.model_dump_json()) == request

    conflicting_model = request.model.model_copy(update={"provider_key": "provider.other"})
    with pytest.raises(ValidationError, match="Registry references must match"):
        AIGatewayRequest.model_validate(
            {**request.model_dump(), "model": conflicting_model.model_dump()}
        )


def test_gateway_contract_contains_execution_facts_not_business_policy():
    fields = set(AIGatewayRequest.model_fields)
    assert fields.isdisjoint(
        {
            "feature_flag",
            "entitlement",
            "safety",
            "budget",
            "credit_reservation",
            "ledger",
        }
    )


def test_provider_execution_plan_requires_a_complete_registry_route():
    payload = _execution_plan().model_dump()
    payload["model"] = None
    with pytest.raises(ValidationError, match="provider_execution requires"):
        AIExecutionPlan.model_validate(payload)


def test_provider_execution_plan_is_deny_dominant():
    payload = _execution_plan().model_dump()
    payload["feature_flag"]["allowed"] = False
    payload["feature_flag"]["reason_code"] = "disabled"
    with pytest.raises(ValidationError, match="cannot bypass a deny"):
        AIExecutionPlan.model_validate(payload)

    payload = _execution_plan().model_dump()
    payload["safety"]["decision"] = "deterministic_only"
    with pytest.raises(ValidationError, match="permitting safety"):
        AIExecutionPlan.model_validate(payload)


@pytest.mark.parametrize(
    "forbidden_key",
    [
        "apiKey",
        "providerApiKey",
        "anthropic_api_key",
        "openai_api_key",
        "authToken",
        "refreshToken",
        "sessionCookie",
        "authorization",
        "providerEndpoint",
        "modelOverride",
    ],
)
def test_normalized_inputs_reject_secret_and_route_override_channels(forbidden_key):
    with pytest.raises(ValidationError, match="forbidden payload key"):
        AIOrchestratorRequest(
            contract_version="1",
            request_id="request-1",
            idempotency_key="idem-1",
            trace_id="trace-1",
            principal=_principal(),
            environment="test",
            feature_category=AIFeatureKeyCategory.UNSPECIFIED,
            feature_key="ai.assistant",
            task_type="answer",
            product_input={"nested": {forbidden_key: "not-allowed"}},
            response_contract_ref="response.text.v1",
            deadline_at=LATER,
            product_transaction_ref="product-operation-1",
        )

    with pytest.raises(ValidationError, match="must not be empty"):
        NormalizedAIInput()


def test_active_credit_reservations_require_bounded_funding():
    payload = _reservation().model_dump()
    payload["maximum_najm_credits"] = None
    with pytest.raises(ValidationError, match="maximum and reserved"):
        CreditReservationRef.model_validate(payload)

    payload = _reservation().model_dump()
    payload["reserved_najm_credits"] = Decimal("4")
    with pytest.raises(ValidationError, match="cannot exceed"):
        CreditReservationRef.model_validate(payload)


def test_staged_prompt_cannot_enter_the_generic_execution_contract():
    payload = _execution_plan().model_dump()
    payload["prompt"]["lifecycle"] = "staged"
    with pytest.raises(ValidationError, match="executable prompt"):
        AIExecutionPlan.model_validate(payload)


def test_usage_certainty_and_native_units_are_accounting_safe():
    with pytest.raises(ValidationError, match="known_zero"):
        ProviderUsage(
            certainty=ProviderUsageCertainty.KNOWN_ZERO,
            input_tokens=1,
        )
    with pytest.raises(ValidationError, match="known non-zero"):
        ProviderUsage(
            certainty=ProviderUsageCertainty.KNOWN,
            input_tokens=0,
        )
    with pytest.raises(ValidationError):
        ProviderUsage(
            certainty=ProviderUsageCertainty.KNOWN,
            additional_native_units={"image_units": Decimal("-1")},
        )


def test_gateway_attempt_status_cannot_express_orchestrator_policy_outcomes():
    payload = {
        "contract_version": "1",
        "request_id": "request-1",
        "attempt_id": "attempt-1",
        "idempotency_key": "idem-1",
        "feature_key": "ai.assistant",
        "status": "denied",
    }
    with pytest.raises(ValidationError, match="status"):
        AIGatewayResponse.model_validate(payload)

    completed_without_result = {**payload, "status": "completed"}
    with pytest.raises(ValidationError, match="requires a result"):
        AIGatewayResponse.model_validate(completed_without_result)


def test_ledger_draft_uses_najm_credits_and_rejects_provider_payloads():
    event = LedgerEventDraft(
        event_id="event-1",
        event_type=LedgerEventType.CREDIT_RECONCILIATION,
        request_id="request-1",
        idempotency_key="idem-1",
        principal=_principal(),
        feature_key="ai.assistant",
        task_type="answer",
        occurred_at=NOW,
        reason_code="reconciled",
        source_ref="credit-reconciliation-1",
        schema_version="1",
        semantic_fingerprint="sha256-ledger-1",
        retention_class="billing_audit",
        reservation_id="reservation-1",
        credit_transaction_ref="credit-transaction-1",
        credit_account_id="credit-account-1",
        najm_credit_amount=Decimal("2"),
        credit_direction=LedgerCreditDirection.DEBIT,
        policy_refs={"credit": "credit-v1", "budget": "budget-v1"},
    )
    assert event.najm_credit_amount == Decimal("2")
    assert "provider_tokens" not in event.model_fields

    with pytest.raises(ValidationError, match="debit or credit direction"):
        LedgerEventDraft.model_validate(
            {**event.model_dump(), "credit_direction": "none"}
        )

    non_financial_payload = event.model_dump()
    non_financial_payload.update(
        {
            "najm_credit_amount": None,
            "credit_direction": "none",
            "credit_transaction_ref": None,
        }
    )
    with pytest.raises(ValidationError, match="financial ledger event"):
        LedgerEventDraft.model_validate(non_financial_payload)

    with pytest.raises(ValidationError, match="Extra inputs are not permitted"):
        LedgerEventDraft.model_validate(
            {**event.model_dump(), "raw_provider_payload": {"secret": "value"}}
        )


def test_contracts_are_frozen_and_reject_unknown_secret_fields():
    principal = _principal()
    with pytest.raises(ValidationError):
        principal.principal_id = "other"

    with pytest.raises(ValidationError, match="Extra inputs are not permitted"):
        AIPrincipalRef(
            principal_id="user-123",
            authorization_ref="authz-decision-1",
            firebase_token="raw-token",
        )


def test_orchestrator_terminal_outcomes_cannot_contradict_commit_state():
    valid = AIOrchestratorResponse(
        contract_version="1",
        request_id="request-1",
        idempotency_key="idem-1",
        trace_id="trace-1",
        feature_key="ai.assistant",
        status=AIRequestStatus.DETERMINISTIC_ONLY,
        execution_mode=AIExecutionMode.DETERMINISTIC_ONLY,
        route_decision=RouteDecision.DETERMINISTIC_ONLY,
        safety=_safety(),
        result={"authority_ref": "legality-result-1"},
        policy_version_refs={"safety": "safety-v1"},
        provenance_refs=("legality-result-1",),
    )
    with pytest.raises(ValidationError, match="requires an error and no result"):
        AIOrchestratorResponse.model_validate(
            {**valid.model_dump(), "status": "failed"}
        )
    with pytest.raises(ValidationError, match="only a completed"):
        AIOrchestratorResponse.model_validate(
            {**valid.model_dump(), "may_commit_business_transaction": True}
        )
