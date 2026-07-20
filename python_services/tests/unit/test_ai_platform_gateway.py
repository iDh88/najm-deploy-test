"""Boundary tests for the inert NAJM AI Gateway execution scaffolding.

These tests inject fake, in-test Provider Adapters only.  No provider SDK,
network call, credential, or Firebase interaction is involved.
"""

import ast
import inspect
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from ai_platform.contracts import (
    AIErrorDetail,
    AIFallbackReason,
    AIGatewayRequest,
    AIGatewayResponse,
    ErrorFactState,
    GatewayAttemptStatus,
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
)
from ai_platform.errors import ProviderErrorCode
from ai_platform.gateway import (
    AIGateway,
    GatewayAdapterCatalog,
    GatewayAttemptPlan,
    GatewayAttemptResult,
    GatewayExecutionError,
    GatewayExecutionResult,
    GatewayExecutionStatus,
    GatewayFallbackPolicy,
)
from ai_platform.provider_adapter import ProviderAdapter, ProviderAdapterError


PYTHON_SERVICES = Path(__file__).resolve().parents[2]
GATEWAY_MODULE = PYTHON_SERVICES / "ai_platform" / "gateway.py"

NOW = datetime(2026, 7, 16, 8, 0, tzinfo=timezone.utc)
LATER = NOW + timedelta(minutes=5)


# ─── Provider-neutral fixtures ────────────────────────────────────────────────
def _provider(
    *,
    provider_key: str = "provider.primary",
    adapter_key: str = "adapter.primary",
) -> ProviderRegistryRef:
    return ProviderRegistryRef(
        provider_key=provider_key,
        registry_revision="provider-rev-1",
        adapter_key=adapter_key,
        adapter_contract_version="1",
        lifecycle=ProviderLifecycleState.ENABLED,
    )


def _model(
    *,
    provider_key: str = "provider.primary",
    model_key: str = "model.general",
) -> ModelRegistryRef:
    return ModelRegistryRef(
        model_key=model_key,
        model_revision="model-rev-1",
        provider_key=provider_key,
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


def _request(
    *,
    attempt_id: str = "attempt-1",
    provider: ProviderRegistryRef | None = None,
    model: ModelRegistryRef | None = None,
    capability: ProviderCapability = ProviderCapability.TEXT_GENERATION,
    request_id: str = "request-1",
    feature_key: str = "ai.assistant",
) -> AIGatewayRequest:
    provider = provider if provider is not None else _provider()
    model = model if model is not None else _model()
    return AIGatewayRequest(
        contract_version="1",
        request_id=request_id,
        attempt_id=attempt_id,
        idempotency_key="idem-1",
        trace_id="trace-1",
        execution_plan_id="plan-1",
        feature_key=feature_key,
        provider=provider,
        model=model,
        prompt=_prompt(),
        capability=capability,
        normalized_input=NormalizedAIInput(
            messages=(
                NormalizedMessage(role="user", content="Explain the governed result."),
            ),
        ),
        output_contract_ref="output.text.v1",
        deadline_at=LATER,
        timeout_ms=3000,
        data_classification="internal",
        retention_policy_ref="retention.standard",
    )


def _completed_response(
    request: AIGatewayRequest,
    *,
    content: str = "normalized answer",
) -> AIGatewayResponse:
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
            provider_request_id=f"provider-request-{request.attempt_id}",
        ),
        content=content,
    )


def _unavailable_response(request: AIGatewayRequest) -> AIGatewayResponse:
    return AIGatewayResponse(
        contract_version="1",
        request_id=request.request_id,
        attempt_id=request.attempt_id,
        idempotency_key=request.idempotency_key,
        feature_key=request.feature_key,
        status=GatewayAttemptStatus.UNAVAILABLE,
        error=AIErrorDetail(
            provider_code=ProviderErrorCode.PROVIDER_UNAVAILABLE,
            same_route_retry_safe=True,
            execution_may_have_occurred=False,
            usage_state=ErrorFactState.UNCERTAIN,
            cost_state=ErrorFactState.UNCERTAIN,
            diagnostic_code="provider_unavailable_from_adapter",
        ),
    )


def _adapter_error(
    provider_code: ProviderErrorCode,
    *,
    diagnostic_code: str,
    execution_may_have_occurred: bool = False,
    same_route_retry_safe: bool = False,
) -> ProviderAdapterError:
    return ProviderAdapterError(
        AIErrorDetail(
            provider_code=provider_code,
            same_route_retry_safe=same_route_retry_safe,
            execution_may_have_occurred=execution_may_have_occurred,
            usage_state=ErrorFactState.UNCERTAIN,
            cost_state=ErrorFactState.UNCERTAIN,
            diagnostic_code=diagnostic_code,
        )
    )


class _FakeAdapter(ProviderAdapter):
    """In-test adapter: no SDK, no network, no secrets, no provider behavior.

    ``behavior`` is a plain callable ``(request) -> AIGatewayResponse`` that may
    also raise, so a single class can simulate success, a normalized error
    response, a raised normalized adapter error, a raw timeout, or a malformed
    result.
    """

    def __init__(
        self,
        *,
        adapter_key: str = "adapter.primary",
        provider_key: str = "provider.primary",
        capabilities=frozenset({ProviderCapability.TEXT_GENERATION}),
        behavior=None,
    ) -> None:
        self._adapter_key = adapter_key
        self._provider_key = provider_key
        self._capabilities = frozenset(capabilities)
        self._behavior = behavior or _completed_response
        self.seen_attempts: list[str] = []

    @property
    def adapter_key(self) -> str:
        return self._adapter_key

    @property
    def contract_version(self) -> str:
        return "1"

    @property
    def provider(self) -> ProviderRegistryRef:
        return _provider(
            provider_key=self._provider_key,
            adapter_key=self._adapter_key,
        )

    @property
    def capabilities(self) -> frozenset[ProviderCapability]:
        return self._capabilities

    def capability_metadata(self) -> tuple[ProviderCapabilityMetadata, ...]:
        return tuple(
            ProviderCapabilityMetadata(capability=capability)
            for capability in sorted(self._capabilities, key=lambda item: item.value)
        )

    def configuration_status(self) -> ProviderConfigurationStatus:
        return ProviderConfigurationStatus.CONFIGURED

    async def execute(self, request: AIGatewayRequest) -> AIGatewayResponse:
        self.seen_attempts.append(request.attempt_id)
        return self._behavior(request)


def _imported_modules(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
    return imported


# ─── Successful execution ─────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_gateway_executes_normalized_request_against_injected_adapter():
    adapter = _FakeAdapter()
    gateway = AIGateway(GatewayAdapterCatalog([adapter]))
    request = _request()

    result = await gateway.execute(request)

    assert isinstance(result, GatewayAttemptResult)
    assert result.status is GatewayExecutionStatus.COMPLETED
    assert result.succeeded is True
    assert result.error is None
    assert result.response is not None
    assert result.response.status is GatewayAttemptStatus.COMPLETED
    assert result.response.content == "normalized answer"
    assert result.provider_key == "provider.primary"
    assert result.adapter_key == "adapter.primary"
    assert adapter.seen_attempts == ["attempt-1"]


# ─── Pre-invocation normalized failures ───────────────────────────────────────
@pytest.mark.asyncio
async def test_missing_adapter_returns_explicit_unavailable_result():
    gateway = AIGateway(GatewayAdapterCatalog())  # no bindings
    request = _request()

    result = await gateway.execute(request)

    assert result.status is GatewayExecutionStatus.ADAPTER_UNAVAILABLE
    assert result.succeeded is False
    assert result.response is None
    assert result.error is not None
    assert result.error.status is GatewayExecutionStatus.ADAPTER_UNAVAILABLE
    assert result.error.reason_code == "adapter_binding_unavailable"


@pytest.mark.asyncio
async def test_capability_mismatch_returns_unsupported_capability_result():
    # Adapter is bound to the requested provider but cannot serve the capability.
    adapter = _FakeAdapter(capabilities=frozenset({ProviderCapability.EMBEDDINGS}))
    gateway = AIGateway(GatewayAdapterCatalog([adapter]))
    request = _request(capability=ProviderCapability.TEXT_GENERATION)

    result = await gateway.execute(request)

    assert result.status is GatewayExecutionStatus.UNSUPPORTED_CAPABILITY
    assert result.error is not None
    assert result.error.reason_code == "capability_not_supported_by_adapter"
    # The adapter was never invoked — the mismatch fails before execution.
    assert adapter.seen_attempts == []


@pytest.mark.asyncio
async def test_route_binding_mismatch_returns_invalid_binding_result():
    # Adapter bound under the requested adapter_key but for a different provider.
    adapter = _FakeAdapter(
        adapter_key="adapter.primary",
        provider_key="provider.other",
    )
    gateway = AIGateway(GatewayAdapterCatalog([adapter]))
    request = _request()

    result = await gateway.execute(request)

    assert result.status is GatewayExecutionStatus.ROUTE_BINDING_INVALID
    assert result.error is not None
    assert result.error.reason_code == "adapter_provider_binding_mismatch"
    assert adapter.seen_attempts == []


# ─── Adapter-signalled failures map to normalized results ─────────────────────
@pytest.mark.asyncio
async def test_adapter_raised_provider_unavailable_maps_to_unavailable():
    def _raise(_request):
        raise _adapter_error(
            ProviderErrorCode.PROVIDER_UNAVAILABLE,
            diagnostic_code="provider_unavailable",
            same_route_retry_safe=True,
        )

    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter(behavior=_raise)]))

    result = await gateway.execute(_request())

    assert result.status is GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    assert result.response is None
    assert result.error is not None
    assert result.error.provider_error_code is ProviderErrorCode.PROVIDER_UNAVAILABLE
    assert result.error.detail is not None


@pytest.mark.asyncio
async def test_adapter_returned_unavailable_response_maps_to_unavailable():
    gateway = AIGateway(
        GatewayAdapterCatalog([_FakeAdapter(behavior=_unavailable_response)])
    )

    result = await gateway.execute(_request())

    assert result.status is GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    # A normalized error response is preserved alongside the Gateway error.
    assert result.response is not None
    assert result.response.status is GatewayAttemptStatus.UNAVAILABLE
    assert result.error is not None
    assert result.error.provider_error_code is ProviderErrorCode.PROVIDER_UNAVAILABLE


@pytest.mark.asyncio
async def test_adapter_raised_timeout_maps_to_timeout():
    def _raise(_request):
        raise _adapter_error(
            ProviderErrorCode.TIMEOUT,
            diagnostic_code="provider_timeout",
            execution_may_have_occurred=True,
        )

    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter(behavior=_raise)]))

    result = await gateway.execute(_request())

    assert result.status is GatewayExecutionStatus.PROVIDER_TIMEOUT
    assert result.error is not None
    assert result.error.execution_may_have_occurred is True


@pytest.mark.asyncio
async def test_raw_timeout_exception_maps_to_timeout_without_leaking_text():
    def _raise(_request):
        raise TimeoutError("provider socket read timed out at 10.0.0.5")

    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter(behavior=_raise)]))

    result = await gateway.execute(_request())

    assert result.status is GatewayExecutionStatus.PROVIDER_TIMEOUT
    assert result.error is not None
    assert result.error.reason_code == "adapter_execution_timeout"
    # The raw exception text must not leak into the normalized result.
    assert "10.0.0.5" not in result.model_dump_json()


@pytest.mark.asyncio
async def test_unexpected_adapter_exception_is_redacted_to_provider_error():
    def _raise(_request):
        raise RuntimeError("provider client blew up with secret sk-abc123")

    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter(behavior=_raise)]))

    result = await gateway.execute(_request())

    assert result.status is GatewayExecutionStatus.PROVIDER_ERROR
    assert result.error is not None
    assert result.error.provider_error_code is ProviderErrorCode.UNKNOWN_PROVIDER_FAILURE
    assert "sk-abc123" not in result.model_dump_json()


@pytest.mark.asyncio
async def test_adapter_malformed_response_maps_to_malformed_result():
    def _raise(_request):
        raise _adapter_error(
            ProviderErrorCode.CONTRACT_OR_RESPONSE_SHAPE_VIOLATION,
            diagnostic_code="malformed_provider_response",
            execution_may_have_occurred=True,
        )

    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter(behavior=_raise)]))

    result = await gateway.execute(_request())

    assert result.status is GatewayExecutionStatus.MALFORMED_RESPONSE
    assert result.error is not None
    assert (
        result.error.provider_error_code
        is ProviderErrorCode.CONTRACT_OR_RESPONSE_SHAPE_VIOLATION
    )


@pytest.mark.asyncio
async def test_adapter_response_for_wrong_attempt_is_rejected_as_malformed():
    # Adapter answers with a different attempt id; the mis-correlated payload is
    # dropped rather than attributed to this route.
    def _wrong_attempt(request):
        other = _request(attempt_id="attempt-elsewhere")
        return _completed_response(other)

    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter(behavior=_wrong_attempt)]))

    result = await gateway.execute(_request(attempt_id="attempt-1"))

    assert result.status is GatewayExecutionStatus.MALFORMED_RESPONSE
    assert result.response is None
    assert result.error is not None
    assert result.error.reason_code == "adapter_response_identity_mismatch"


# ─── Caller-supplied fallback semantics ───────────────────────────────────────
def _fallback_policy(*plans: GatewayAttemptPlan) -> GatewayFallbackPolicy:
    return GatewayFallbackPolicy(attempts=plans)


@pytest.mark.asyncio
async def test_gateway_follows_caller_supplied_fallback_order_until_success():
    def _fail(request):
        return _unavailable_response(request)

    primary_provider = _provider(
        provider_key="provider.primary",
        adapter_key="adapter.primary",
    )
    secondary_provider = _provider(
        provider_key="provider.secondary",
        adapter_key="adapter.secondary",
    )
    primary_adapter = _FakeAdapter(
        adapter_key="adapter.primary",
        provider_key="provider.primary",
        behavior=_fail,
    )
    secondary_adapter = _FakeAdapter(
        adapter_key="adapter.secondary",
        provider_key="provider.secondary",
        behavior=_completed_response,
    )
    gateway = AIGateway(
        GatewayAdapterCatalog([primary_adapter, secondary_adapter])
    )

    primary_request = _request(attempt_id="attempt-1", provider=primary_provider,
                               model=_model(provider_key="provider.primary"))
    secondary_request = _request(
        attempt_id="attempt-2",
        provider=secondary_provider,
        model=_model(provider_key="provider.secondary", model_key="model.general"),
    )
    policy = _fallback_policy(
        GatewayAttemptPlan(request=primary_request),
        GatewayAttemptPlan(
            request=secondary_request,
            fallback_reason=AIFallbackReason.PROVIDER_UNAVAILABLE,
        ),
    )

    result = await gateway.execute_with_fallback(policy)

    assert isinstance(result, GatewayExecutionResult)
    assert result.succeeded is True
    assert result.final_status is GatewayExecutionStatus.COMPLETED
    # Both attempts ran, in the caller-supplied order.
    assert [attempt.attempt_id for attempt in result.attempts] == [
        "attempt-1",
        "attempt-2",
    ]
    assert [attempt.provider_key for attempt in result.attempts] == [
        "provider.primary",
        "provider.secondary",
    ]
    assert result.attempts[0].status is GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    assert result.attempts[1].fallback_reason is AIFallbackReason.PROVIDER_UNAVAILABLE
    assert result.final is result.attempts[-1]


@pytest.mark.asyncio
async def test_gateway_does_not_execute_fallback_attempts_after_success():
    primary_adapter = _FakeAdapter(
        adapter_key="adapter.primary",
        provider_key="provider.primary",
        behavior=_completed_response,
    )
    secondary_adapter = _FakeAdapter(
        adapter_key="adapter.secondary",
        provider_key="provider.secondary",
        behavior=_completed_response,
    )
    gateway = AIGateway(
        GatewayAdapterCatalog([primary_adapter, secondary_adapter])
    )

    policy = _fallback_policy(
        GatewayAttemptPlan(request=_request(attempt_id="attempt-1")),
        GatewayAttemptPlan(
            request=_request(
                attempt_id="attempt-2",
                provider=_provider(
                    provider_key="provider.secondary",
                    adapter_key="adapter.secondary",
                ),
                model=_model(provider_key="provider.secondary"),
            ),
            fallback_reason=AIFallbackReason.TIMEOUT,
        ),
    )

    result = await gateway.execute_with_fallback(policy)

    assert result.succeeded is True
    assert len(result.attempts) == 1
    assert result.attempts[0].attempt_id == "attempt-1"
    # The fallback adapter was never touched.
    assert primary_adapter.seen_attempts == ["attempt-1"]
    assert secondary_adapter.seen_attempts == []


@pytest.mark.asyncio
async def test_gateway_reports_fallback_exhaustion_when_every_attempt_fails():
    def _fail(request):
        return _unavailable_response(request)

    primary_adapter = _FakeAdapter(
        adapter_key="adapter.primary", provider_key="provider.primary", behavior=_fail
    )
    secondary_adapter = _FakeAdapter(
        adapter_key="adapter.secondary",
        provider_key="provider.secondary",
        behavior=_fail,
    )
    gateway = AIGateway(
        GatewayAdapterCatalog([primary_adapter, secondary_adapter])
    )

    policy = _fallback_policy(
        GatewayAttemptPlan(request=_request(attempt_id="attempt-1")),
        GatewayAttemptPlan(
            request=_request(
                attempt_id="attempt-2",
                provider=_provider(
                    provider_key="provider.secondary",
                    adapter_key="adapter.secondary",
                ),
                model=_model(provider_key="provider.secondary"),
            ),
            fallback_reason=AIFallbackReason.PROVIDER_UNAVAILABLE,
        ),
    )

    result = await gateway.execute_with_fallback(policy)

    assert result.succeeded is False
    assert len(result.attempts) == 2
    assert result.final_status is GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    assert all(not attempt.succeeded for attempt in result.attempts)


@pytest.mark.asyncio
async def test_gateway_never_uses_a_route_absent_from_caller_supplied_attempts():
    supplied_providers = {"provider.primary", "provider.secondary"}

    def _fail(request):
        return _unavailable_response(request)

    primary_adapter = _FakeAdapter(
        adapter_key="adapter.primary", provider_key="provider.primary", behavior=_fail
    )
    secondary_adapter = _FakeAdapter(
        adapter_key="adapter.secondary",
        provider_key="provider.secondary",
        behavior=_completed_response,
    )
    # A third adapter exists in the catalog but is not in the attempt plan; it
    # must never be selected by the Gateway.
    unused_adapter = _FakeAdapter(
        adapter_key="adapter.tertiary",
        provider_key="provider.tertiary",
        behavior=_completed_response,
    )
    gateway = AIGateway(
        GatewayAdapterCatalog([primary_adapter, secondary_adapter, unused_adapter])
    )

    policy = _fallback_policy(
        GatewayAttemptPlan(request=_request(attempt_id="attempt-1")),
        GatewayAttemptPlan(
            request=_request(
                attempt_id="attempt-2",
                provider=_provider(
                    provider_key="provider.secondary",
                    adapter_key="adapter.secondary",
                ),
                model=_model(provider_key="provider.secondary"),
            ),
            fallback_reason=AIFallbackReason.PROVIDER_UNAVAILABLE,
        ),
    )

    result = await gateway.execute_with_fallback(policy)

    used_providers = {attempt.provider_key for attempt in result.attempts}
    assert used_providers <= supplied_providers
    assert "provider.tertiary" not in used_providers
    assert unused_adapter.seen_attempts == []


# ─── Attempt history carries only normalized facts ────────────────────────────
@pytest.mark.asyncio
async def test_attempt_history_carries_no_raw_provider_payload_channels():
    gateway = AIGateway(GatewayAdapterCatalog([_FakeAdapter()]))
    result = await gateway.execute_with_fallback(
        _fallback_policy(GatewayAttemptPlan(request=_request()))
    )

    forbidden_fields = {
        "raw_payload",
        "raw_provider_payload",
        "raw_provider_request",
        "raw_provider_response",
        "provider_payload",
        "provider_output",
        "raw_prompt",
        "prompt_body",
        "api_key",
        "secret",
        "authorization",
    }
    for model_type in (
        GatewayExecutionResult,
        GatewayAttemptResult,
        GatewayExecutionError,
    ):
        assert set(model_type.model_fields).isdisjoint(forbidden_fields)

    # Target unambiguous raw-payload/credential JSON keys.  Bare substrings like
    # "authorization" are avoided because normalized contracts legitimately carry
    # opaque reference fields such as "compatibility_authorization_ref".
    serialized = result.model_dump_json().lower()
    for needle in (
        '"raw_payload"',
        '"raw_provider_payload"',
        '"raw_provider_request"',
        '"raw_provider_response"',
        '"provider_payload"',
        '"provider_output"',
        '"api_key"',
        '"prompt_body"',
        '"authorization_header"',
    ):
        assert needle not in serialized


# ─── Gateway owns no product/semantic policy ──────────────────────────────────
def test_gateway_does_not_own_entitlement_budget_credit_or_safety_policy():
    public_members = {
        name for name, _ in inspect.getmembers(AIGateway) if not name.startswith("_")
    }
    prohibited = {
        "entitlement",
        "subscription",
        "credit",
        "credits",
        "budget",
        "safety",
        "billing",
        "pricing",
        "prompt",
        "feature_flag",
        "route",
        "select_provider",
        "select_model",
    }
    assert public_members.isdisjoint(prohibited)

    result_fields: set[str] = set()
    for model_type in (
        GatewayAttemptResult,
        GatewayExecutionResult,
        GatewayAttemptPlan,
        GatewayExecutionError,
    ):
        result_fields |= set(model_type.model_fields)
    assert result_fields.isdisjoint(prohibited)


def test_gateway_status_cannot_express_orchestrator_policy_outcomes():
    values = {member.value for member in GatewayExecutionStatus}
    # Gateway statuses are execution facts, never policy verdicts.
    assert values.isdisjoint(
        {"denied", "deterministic_only", "entitlement_denied", "budget_denied"}
    )


# ─── No wiring, no provider SDKs ──────────────────────────────────────────────
def test_gateway_module_has_no_provider_sdk_or_network_or_firebase_imports():
    prohibited_roots = {
        "anthropic",
        "openai",
        "google",
        "zhipuai",
        "dashscope",
        "httpx",
        "requests",
        "urllib3",
        "aiohttp",
        "firebase_admin",
        "google.cloud",
    }
    imported = _imported_modules(GATEWAY_MODULE)
    blocked = sorted(
        module
        for module in imported
        if module.split(".", maxsplit=1)[0] in {root.split(".")[0] for root in prohibited_roots}
    )
    assert blocked == []


def test_existing_runtime_modules_do_not_import_the_gateway():
    violations: dict[str, list[str]] = {}
    for path in sorted(PYTHON_SERVICES.rglob("*.py")):
        relative = path.relative_to(PYTHON_SERVICES)
        if relative.parts[0] in {"ai_platform", "tests", ".venv"}:
            continue
        imported = _imported_modules(path)
        matches = sorted(
            module for module in imported if module == "ai_platform.gateway"
        )
        if matches:
            violations[str(relative)] = matches
    assert violations == {}
