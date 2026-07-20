"""Phase 6 tests for the dependency-injected AI Orchestrator Coordinator."""

from __future__ import annotations

import ast
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from ai_platform.contracts import (
    AIFallbackReason,
    AIFeatureKeyCategory,
    AIGatewayRequest,
    AIGatewayResponse,
    AIOrchestratorRequest,
    AIPrincipalRef,
    AIRequestStatus,
    AISafetyDecision,
    AISafetyLevel,
    BudgetDecisionRef,
    BudgetDecisionResult,
    EntitlementDecisionRef,
    FeatureFlagDecisionRef,
    GatewayAttemptStatus,
    LedgerEventDraft,
    LedgerEventType,
    ModelLifecycleState,
    ModelRegistryRef,
    NormalizedAIInput,
    NormalizedMessage,
    PromptLifecycleState,
    PromptRegistryRef,
    ProviderCapability,
    ProviderCapabilityMetadata,
    ProviderConfigurationStatus,
    ProviderLifecycleState,
    ProviderRegistryRef,
    ProviderResponseRef,
    SafetyDecisionRef,
)
from ai_platform.errors import AIPlatformError, AIPlatformErrorCode
from ai_platform.gateway import (
    AIGateway,
    GatewayAdapterCatalog,
    GatewayAttemptPlan,
    GatewayFallbackPolicy,
)
from ai_platform.ledger import LedgerWriteResult, LedgerWriteStatus, LedgerWriter
from ai_platform.orchestrator import (
    AIOrchestratorCoordinator,
    OrchestratorCoordinationContext,
)
from ai_platform.policy import KillSwitchDecisionRef, KillSwitchDisposition
from ai_platform.policy import PolicyCompositionResult, PolicyDecisionStatus
from ai_platform.provider_adapter import ProviderAdapter


NOW = datetime(2026, 7, 19, 8, 0, tzinfo=timezone.utc)
LATER = NOW + timedelta(minutes=5)
ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR_MODULE = ROOT / "python_services" / "ai_platform" / "orchestrator.py"


def _provider(key: str = "provider.primary", adapter: str = "adapter.primary"):
    return ProviderRegistryRef(
        provider_key=key,
        registry_revision=f"{key}.revision.1",
        adapter_key=adapter,
        adapter_contract_version="1",
        lifecycle=ProviderLifecycleState.ENABLED,
    )


def _model(provider_key: str = "provider.primary"):
    return ModelRegistryRef(
        model_key=f"{provider_key}.model.general",
        model_revision="model.revision.1",
        provider_key=provider_key,
        lifecycle=ModelLifecycleState.ENABLED,
        capabilities={ProviderCapability.TEXT_GENERATION},
    )


def _prompt():
    return PromptRegistryRef(
        prompt_family_key="assistant.general",
        prompt_version="prompt.v1",
        registry_revision="prompt.revision.1",
        content_hash="sha256-prompt",
        lifecycle=PromptLifecycleState.ACTIVE,
    )


def _request():
    return AIOrchestratorRequest(
        contract_version="1",
        request_id="request-1",
        idempotency_key="idem-1",
        trace_id="trace-1",
        principal=AIPrincipalRef(
            principal_id="user-1",
            authorization_ref="authorization-1",
        ),
        environment="test",
        feature_category=AIFeatureKeyCategory.UNSPECIFIED,
        feature_key="ai.assistant",
        task_type="answer",
        product_input={"question": "Explain this result"},
        response_contract_ref="response.text.v1",
        deadline_at=LATER,
        product_transaction_ref="product-operation-1",
    )


def _feature_flag(allowed: bool = True):
    return FeatureFlagDecisionRef(
        evaluation_id="flag-1",
        flag_key="ai.assistant",
        feature_key="ai.assistant",
        flag_version="flag.v1",
        allowed=allowed,
        reason_code="enabled" if allowed else "disabled",
        source_ref="flag-source-1",
        evaluated_at=NOW,
    )


def _entitlement(allowed: bool = True):
    return EntitlementDecisionRef(
        decision_id="entitlement-1",
        feature_key="ai.assistant",
        policy_version="entitlement.v1",
        allowed=allowed,
        reason_code="allowed" if allowed else "denied",
        evaluated_at=NOW,
    )


def _safety(decision: AISafetyDecision = AISafetyDecision.ALLOWED):
    return SafetyDecisionRef(
        decision_id="safety-1",
        feature_key="ai.assistant",
        policy_version="safety.v1",
        level=AISafetyLevel.GENERAL_ASSISTANCE,
        decision=decision,
        evaluated_at=NOW,
        reason_codes=("safety-policy",),
    )


def _budget():
    return BudgetDecisionRef(
        decision_id="budget-1",
        request_id="request-1",
        feature_key="ai.assistant",
        policy_version="budget.v1",
        result=BudgetDecisionResult.ALLOW,
        evaluated_at=NOW,
        expires_at=LATER,
    )


def _kill_switch(disposition=KillSwitchDisposition.CLEAR):
    return KillSwitchDecisionRef(
        evaluation_id="kill-switch-1",
        switch_key="ai.global",
        switch_version="switch.v1",
        disposition=disposition,
        reason_code="clear" if disposition is KillSwitchDisposition.CLEAR else "incident",
        source_ref="incident-policy-1",
        evaluated_at=NOW,
    )


def _gateway_request(
    *,
    attempt_id="attempt-1",
    provider=None,
    model=None,
):
    provider = provider or _provider()
    model = model or _model(provider.provider_key)
    return AIGatewayRequest(
        contract_version="1",
        request_id="request-1",
        attempt_id=attempt_id,
        idempotency_key="idem-1",
        trace_id="trace-1",
        execution_plan_id=f"plan-{attempt_id}",
        feature_key="ai.assistant",
        provider=provider,
        model=model,
        prompt=_prompt(),
        capability=ProviderCapability.TEXT_GENERATION,
        normalized_input=NormalizedAIInput(
            messages=(NormalizedMessage(role="user", content="Explain"),)
        ),
        output_contract_ref="response.text.v1",
        deadline_at=LATER,
        timeout_ms=3000,
        data_classification="internal",
        retention_policy_ref="retention.standard",
    )


def _completed_response(request: AIGatewayRequest):
    return AIGatewayResponse(
        contract_version="1",
        request_id=request.request_id,
        attempt_id=request.attempt_id,
        idempotency_key=request.idempotency_key,
        feature_key=request.feature_key,
        status=GatewayAttemptStatus.COMPLETED,
        provider_response=ProviderResponseRef(
            response_ref_id=f"response-{request.attempt_id}",
            attempt_id=request.attempt_id,
            provider=request.provider,
            model=request.model,
            received_at=NOW,
        ),
        content=f"answer from {request.provider.provider_key}",
        finish_reason="stop",
    )


class _Adapter(ProviderAdapter):
    def __init__(self, provider, behavior=None):
        self._provider = provider
        self._behavior = behavior or _completed_response
        self.seen = []

    @property
    def adapter_key(self):
        return self._provider.adapter_key

    @property
    def contract_version(self):
        return "1"

    @property
    def provider(self):
        return self._provider

    @property
    def capabilities(self):
        return frozenset({ProviderCapability.TEXT_GENERATION})

    def capability_metadata(self):
        return (
            ProviderCapabilityMetadata(capability=ProviderCapability.TEXT_GENERATION),
        )

    def configuration_status(self):
        return ProviderConfigurationStatus.CONFIGURED

    async def execute(self, request):
        self.seen.append(request)
        return self._behavior(request)


class _Ledger(LedgerWriter):
    def __init__(self, status=LedgerWriteStatus.RECORDED, raises=False):
        self.status = status
        self.raises = raises
        self.seen = []

    def append(self, event):
        self.seen.append(event)
        if self.raises:
            raise RuntimeError("storage failed with secret sk-never-return")
        successful = self.status in {
            LedgerWriteStatus.RECORDED,
            LedgerWriteStatus.ALREADY_RECORDED,
        }
        return LedgerWriteResult(
            status=self.status,
            event_id=event.event_id,
            canonical_event_id=(event.event_id if successful else None),
            idempotency_key=event.idempotency_key,
            semantic_fingerprint=event.semantic_fingerprint,
            payload_fingerprint="payload-fingerprint",
            recorded_at=NOW if successful else None,
            integrity_hash="integrity-hash" if successful else None,
            error_code=(
                AIPlatformErrorCode.LEDGER_UNAVAILABLE
                if self.status is LedgerWriteStatus.FAILED
                else None
            ),
        )


def _context(**changes):
    values = {
        "evaluated_at": NOW,
        "feature_flag": _feature_flag(),
        "entitlement": _entitlement(),
        "safety": _safety(),
        "budget": _budget(),
        "kill_switch": _kill_switch(),
        "provider": _provider(),
        "model": _model(),
        "prompt": _prompt(),
        "required_capability": ProviderCapability.TEXT_GENERATION,
        "activation_authorization_ref": "route-activation-1",
        "normalized_input": NormalizedAIInput(
            messages=(NormalizedMessage(role="user", content="Explain"),)
        ),
        "output_contract_ref": "response.text.v1",
        "attempt_id": "attempt-1",
        "plan_id": "plan-1",
        "timeout_ms": 3000,
        "data_classification": "internal",
        "retention_policy_ref": "retention.standard",
        "policy_version_refs": {
            "feature": "flag.v1",
            "entitlement": "entitlement.v1",
            "safety": "safety.v1",
            "budget": "budget.v1",
        },
        "provenance_refs": ("policy-snapshot-1",),
    }
    values.update(changes)
    return OrchestratorCoordinationContext(**values)


def _ledger_event(event_type=LedgerEventType.USAGE_OUTCOME):
    return LedgerEventDraft(
        event_id="event-1",
        event_type=event_type,
        request_id="request-1",
        idempotency_key="idem-1",
        principal=_request().principal,
        feature_key="ai.assistant",
        task_type="answer",
        occurred_at=NOW,
        reason_code="observed",
        source_ref="orchestrator-observation-1",
        schema_version="1",
        semantic_fingerprint="semantic-1",
        retention_class="audit",
        policy_refs={"safety": "safety.v1"},
    )


@pytest.mark.asyncio
async def test_allowed_policy_executes_one_resolved_gateway_request():
    adapter = _Adapter(_provider())
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([adapter]))
    )

    response = await coordinator.coordinate(_request(), _context())

    assert response.status is AIRequestStatus.COMPLETED
    assert response.result["content"] == "answer from provider.primary"
    assert response.attempt_ids == ("attempt-1",)
    assert len(adapter.seen) == 1
    assert adapter.seen[0].request_id == "request-1"
    assert adapter.seen[0].idempotency_key == "idem-1"
    assert adapter.seen[0].trace_id == "trace-1"


@pytest.mark.asyncio
async def test_feature_denial_fails_before_gateway_execution():
    adapter = _Adapter(_provider())
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([adapter]))
    )

    response = await coordinator.coordinate(
        _request(),
        _context(feature_flag=_feature_flag(False)),
    )

    assert response.status is AIRequestStatus.DENIED
    assert response.error.code is AIPlatformErrorCode.FEATURE_DISABLED
    assert adapter.seen == []


@pytest.mark.asyncio
async def test_missing_safety_fails_closed_without_inventing_decision_evidence():
    coordinator = AIOrchestratorCoordinator(AIGateway(GatewayAdapterCatalog()))

    with pytest.raises(AIPlatformError) as error:
        await coordinator.coordinate(_request(), _context(safety=None))

    assert error.value.code is AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE


@pytest.mark.asyncio
async def test_deterministic_only_never_calls_gateway():
    adapter = _Adapter(_provider())
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([adapter]))
    )
    context = _context(
        safety=_safety(AISafetyDecision.DETERMINISTIC_ONLY),
        budget=None,
        provider=None,
        model=None,
        prompt=None,
        required_capability=None,
        activation_authorization_ref=None,
        deterministic_result={"authority_ref": "legality-result-1"},
    )

    response = await coordinator.coordinate(_request(), context)

    assert response.status is AIRequestStatus.DETERMINISTIC_ONLY
    assert response.result == {"authority_ref": "legality-result-1"}
    assert adapter.seen == []


@pytest.mark.asyncio
async def test_degraded_policy_never_calls_gateway():
    adapter = _Adapter(_provider())
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([adapter]))
    )
    response = await coordinator.coordinate(
        _request(),
        _context(kill_switch=_kill_switch(KillSwitchDisposition.DEGRADED)),
    )

    assert response.status is AIRequestStatus.UNAVAILABLE
    assert response.error.diagnostic_code == "policy_degraded"
    assert adapter.seen == []


@pytest.mark.asyncio
async def test_fallback_uses_only_supplied_attempts_in_supplied_order():
    primary = _provider()
    secondary = _provider("provider.secondary", "adapter.secondary")

    def fail(_request):
        raise TimeoutError("raw timeout with secret sk-never-return")

    primary_adapter = _Adapter(primary, fail)
    secondary_adapter = _Adapter(secondary)
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([primary_adapter, secondary_adapter]))
    )
    fallback = GatewayFallbackPolicy(
        attempts=(
            GatewayAttemptPlan(request=_gateway_request()),
            GatewayAttemptPlan(
                request=_gateway_request(
                    attempt_id="attempt-2",
                    provider=secondary,
                    model=_model(secondary.provider_key),
                ),
                fallback_reason=AIFallbackReason.TIMEOUT,
            ),
        )
    )

    response = await coordinator.coordinate(
        _request(),
        _context(fallback_policy=fallback),
    )

    assert response.status is AIRequestStatus.COMPLETED
    assert response.attempt_ids == ("attempt-1", "attempt-2")
    assert len(primary_adapter.seen) == 1
    assert len(secondary_adapter.seen) == 1
    assert "sk-never-return" not in response.model_dump_json()


@pytest.mark.asyncio
async def test_invalid_fallback_identity_fails_closed_before_gateway():
    adapter = _Adapter(_provider())
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([adapter]))
    )
    mismatched = _gateway_request().model_copy(update={"trace_id": "other-trace"})
    fallback = GatewayFallbackPolicy(
        attempts=(GatewayAttemptPlan(request=mismatched),)
    )

    response = await coordinator.coordinate(
        _request(),
        _context(fallback_policy=fallback),
    )

    assert response.status is AIRequestStatus.UNAVAILABLE
    assert adapter.seen == []


@pytest.mark.asyncio
async def test_successful_observation_adds_ledger_reference():
    ledger = _Ledger()
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([_Adapter(_provider())])),
        ledger,
    )

    response = await coordinator.coordinate(
        _request(),
        _context(ledger_events=(_ledger_event(),)),
    )

    assert response.status is AIRequestStatus.COMPLETED
    assert response.ledger_event_refs == ("event-1",)
    assert len(ledger.seen) == 1


@pytest.mark.asyncio
async def test_ledger_failure_does_not_rewrite_successful_gateway_outcome():
    ledger = _Ledger(raises=True)
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([_Adapter(_provider())])),
        ledger,
    )

    response = await coordinator.coordinate(
        _request(),
        _context(
            ledger_events=(_ledger_event(LedgerEventType.RESERVATION),),
            may_commit_business_transaction=True,
        ),
    )

    assert response.status is AIRequestStatus.COMPLETED
    assert response.may_commit_business_transaction is True
    assert response.ledger_event_refs == ()
    assert "sk-never-return" not in response.model_dump_json()


def test_orchestrator_module_is_import_safe_and_owns_no_runtime_clients():
    tree = ast.parse(
        ORCHESTRATOR_MODULE.read_text(encoding="utf-8"),
        filename=str(ORCHESTRATOR_MODULE),
    )
    imported = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
    prohibited = {
        "anthropic",
        "openai",
        "httpx",
        "requests",
        "firebase_admin",
        "fastapi",
    }
    assert not {name.split(".")[0] for name in imported} & prohibited


def test_coordinator_requires_existing_injected_interfaces():
    with pytest.raises(TypeError):
        AIOrchestratorCoordinator(object())
    with pytest.raises(TypeError):
        AIOrchestratorCoordinator(AIGateway(GatewayAdapterCatalog()), object())


@pytest.mark.asyncio
async def test_route_validation_failure_is_redacted_and_fails_closed(monkeypatch):
    def fail_validation(**_kwargs):
        raise RuntimeError("route lookup exposed secret sk-route-secret")

    monkeypatch.setattr(
        "ai_platform.orchestrator.validate_route_registry_refs",
        fail_validation,
    )
    adapter = _Adapter(_provider())
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([adapter]))
    )

    response = await coordinator.coordinate(_request(), _context())

    assert response.status is AIRequestStatus.UNAVAILABLE
    assert response.error.diagnostic_code == "route_validation_failed"
    assert "sk-route-secret" not in response.model_dump_json()
    assert adapter.seen == []


@pytest.mark.asyncio
async def test_empty_denial_reason_codes_use_stable_fallback(monkeypatch):
    empty_denial = PolicyCompositionResult.model_construct(
        status=PolicyDecisionStatus.DENY,
        provider_execution_allowed=False,
        entitlement_allowed=False,
        reason_codes=(),
        snapshot=None,
    )
    monkeypatch.setattr(
        "ai_platform.orchestrator.compose_ai_policy_decision",
        lambda **_kwargs: empty_denial,
    )
    coordinator = AIOrchestratorCoordinator(AIGateway(GatewayAdapterCatalog()))

    response = await coordinator.coordinate(_request(), _context())

    assert response.status is AIRequestStatus.DENIED
    assert response.error.diagnostic_code == "policy_denied"
    assert response.error.code is AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE


@pytest.mark.asyncio
async def test_malformed_ledger_result_is_observational_only():
    class MalformedLedger(LedgerWriter):
        def append(self, _event):
            return object()

    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog([_Adapter(_provider())])),
        MalformedLedger(),
    )

    response = await coordinator.coordinate(
        _request(),
        _context(ledger_events=(_ledger_event(),)),
    )

    assert response.status is AIRequestStatus.COMPLETED
    assert response.ledger_event_refs == ()


@pytest.mark.asyncio
async def test_sensitive_route_and_ledger_failures_never_enter_response(monkeypatch):
    def fail_validation(**_kwargs):
        raise ValueError("credential password=route-secret")

    monkeypatch.setattr(
        "ai_platform.orchestrator.validate_route_registry_refs",
        fail_validation,
    )
    ledger = _Ledger(raises=True)
    coordinator = AIOrchestratorCoordinator(
        AIGateway(GatewayAdapterCatalog()),
        ledger,
    )

    response = await coordinator.coordinate(
        _request(),
        _context(ledger_events=(_ledger_event(),)),
    )

    serialized = response.model_dump_json()
    assert response.status is AIRequestStatus.UNAVAILABLE
    assert "route-secret" not in serialized
    assert "sk-never-return" not in serialized
