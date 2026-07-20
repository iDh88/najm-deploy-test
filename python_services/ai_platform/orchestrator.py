"""Dependency-injected coordination over existing NAJM AI Platform contracts.

This module deliberately does not evaluate policy, discover routes, retrieve
prompts, manage credit balances, or register a runtime endpoint.  Callers
supply already-evaluated decisions and already-resolved execution inputs.
"""

from __future__ import annotations

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, JsonValue

from .contracts import (
    AIErrorDetail,
    AIExecutionMode,
    AIExecutionPlan,
    AIGatewayRequest,
    AIGatewayResponse,
    AIOrchestratorRequest,
    AIOrchestratorResponse,
    AIRequestStatus,
    BudgetDecisionRef,
    CreditReservationRef,
    EntitlementDecisionRef,
    ErrorFactState,
    FeatureFlagDecisionRef,
    LedgerEventDraft,
    NormalizedAIInput,
    NormalizedToolSchema,
    ModelRegistryRef,
    PromptRegistryRef,
    ProviderCapability,
    ProviderRegistryRef,
    RouteDecision,
    SafetyDecisionRef,
)
from .errors import AIPlatformError, AIPlatformErrorCode
from .gateway import (
    AIGateway,
    GatewayAttemptResult,
    GatewayExecutionResult,
    GatewayExecutionStatus,
    GatewayFallbackPolicy,
)
from .ledger import LedgerWriteStatus, LedgerWriter
from .policy import (
    KillSwitchDecisionRef,
    PolicyCompositionResult,
    PolicyDecisionStatus,
    compose_ai_policy_decision,
)
from .registry import validate_route_registry_refs


class OrchestratorCoordinationContext(BaseModel):
    """Already-resolved facts supplied to one coordination call.

    Optional policy fields exist so absence can fail closed.  Their presence
    never means this module evaluated or generated the referenced decision.
    """

    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
        allow_inf_nan=False,
        protected_namespaces=(),
    )

    evaluated_at: AwareDatetime
    feature_flag: FeatureFlagDecisionRef | None = None
    entitlement: EntitlementDecisionRef | None = None
    safety: SafetyDecisionRef | None = None
    budget: BudgetDecisionRef | None = None
    kill_switch: KillSwitchDecisionRef | None = None

    provider: ProviderRegistryRef | None = None
    model: ModelRegistryRef | None = None
    prompt: PromptRegistryRef | None = None
    required_capability: ProviderCapability | None = None
    activation_authorization_ref: str | None = None
    deprecated_model_compatibility_authorized: bool = False

    normalized_input: NormalizedAIInput | None = None
    output_contract_ref: str | None = None
    structured_output_schema: dict[str, JsonValue] | None = None
    tool_schemas: tuple[NormalizedToolSchema, ...] = ()
    generation_controls: dict[str, JsonValue] = Field(
        default_factory=dict,
        max_length=32,
    )
    attempt_id: str | None = None
    plan_id: str | None = None
    timeout_ms: int | None = Field(default=None, ge=1)
    max_same_route_retries: int = Field(default=0, ge=0)
    data_classification: str | None = None
    region_policy_ref: str | None = None
    retention_policy_ref: str | None = None

    credit_reservation: CreditReservationRef | None = None
    deterministic_result: dict[str, JsonValue] | None = None
    policy_version_refs: dict[str, str] = Field(min_length=1, max_length=32)
    provenance_refs: tuple[str, ...] = Field(min_length=1)
    may_commit_business_transaction: bool = False

    fallback_policy: GatewayFallbackPolicy | None = None
    ledger_events: tuple[LedgerEventDraft, ...] = ()


class AIOrchestratorCoordinator:
    """Coordinate existing policy, Gateway, and observational ledger seams."""

    def __init__(
        self,
        gateway: AIGateway,
        ledger_writer: LedgerWriter | None = None,
    ) -> None:
        if not isinstance(gateway, AIGateway):
            raise TypeError("AIOrchestratorCoordinator requires an AIGateway")
        if ledger_writer is not None and not isinstance(ledger_writer, LedgerWriter):
            raise TypeError("ledger_writer must implement LedgerWriter")
        self._gateway = gateway
        self._ledger_writer = ledger_writer

    async def coordinate(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
    ) -> AIOrchestratorResponse:
        """Coordinate one request without evaluating or inventing decisions."""

        if not isinstance(request, AIOrchestratorRequest):
            raise TypeError("coordinate requires an AIOrchestratorRequest")
        if not isinstance(context, OrchestratorCoordinationContext):
            raise TypeError("coordinate requires an OrchestratorCoordinationContext")
        if context.safety is None:
            # The protected response contract requires a SafetyDecisionRef.
            # Failing explicitly is safer than manufacturing decision evidence.
            raise AIPlatformError(AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE)

        route = None
        if context.required_capability is not None:
            try:
                route = validate_route_registry_refs(
                    provider=context.provider,
                    model=context.model,
                    prompt=context.prompt,
                    required_capability=context.required_capability,
                    activation_authorization_ref=context.activation_authorization_ref,
                    deprecated_model_compatibility_authorized=(
                        context.deprecated_model_compatibility_authorized
                    ),
                )
            except Exception:
                response = self._error_response(
                    request,
                    context,
                    status=AIRequestStatus.UNAVAILABLE,
                    code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                    diagnostic_code="route_validation_failed",
                )
                return self._append_observations(response, context.ledger_events)

        try:
            policy = compose_ai_policy_decision(
                request_id=request.request_id,
                feature_key=request.feature_key,
                evaluated_at=context.evaluated_at,
                feature_flag=context.feature_flag,
                entitlement=context.entitlement,
                safety=context.safety,
                budget=context.budget,
                kill_switch=context.kill_switch,
                registry_route=route,
            )
        except Exception:
            response = self._error_response(
                request,
                context,
                status=AIRequestStatus.UNAVAILABLE,
                code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                diagnostic_code="policy_composition_failed",
            )
            return self._append_observations(response, context.ledger_events)

        if policy.status is PolicyDecisionStatus.ALLOW:
            response = await self._execute_allowed(request, context, policy)
        elif policy.status is PolicyDecisionStatus.DETERMINISTIC_ONLY:
            response = self._deterministic_response(request, context)
        elif policy.status is PolicyDecisionStatus.DENY:
            response = self._denied_response(request, context, policy)
        else:
            diagnostic = (
                "policy_degraded"
                if policy.status is PolicyDecisionStatus.DEGRADED
                else "policy_unavailable"
            )
            response = self._error_response(
                request,
                context,
                status=AIRequestStatus.UNAVAILABLE,
                code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                diagnostic_code=diagnostic,
            )
        return self._append_observations(response, context.ledger_events)

    async def _execute_allowed(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        policy: PolicyCompositionResult,
    ) -> AIOrchestratorResponse:
        try:
            if context.fallback_policy is not None:
                self._validate_fallback_identity(request, context.fallback_policy)
                result = await self._gateway.execute_with_fallback(
                    context.fallback_policy
                )
                return self._from_execution_result(request, context, result)

            plan = self._build_execution_plan(request, context, policy)
            gateway_request = self._gateway_request_from_plan(plan)
            result = await self._gateway.execute(gateway_request)
            return self._from_attempt_result(request, context, result)
        except Exception:
            return self._error_response(
                request,
                context,
                status=AIRequestStatus.UNAVAILABLE,
                code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                diagnostic_code="orchestrator_execution_failed",
                execution_mode=AIExecutionMode.NONE,
                route_decision=RouteDecision.DENY,
            )

    @staticmethod
    def _build_execution_plan(
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        policy: PolicyCompositionResult,
    ) -> AIExecutionPlan:
        if not policy.provider_execution_allowed:
            raise ValueError("policy does not permit provider execution")
        required = (
            context.feature_flag,
            context.entitlement,
            context.safety,
            context.budget,
            context.provider,
            context.model,
            context.required_capability,
            context.normalized_input,
            context.attempt_id,
            context.plan_id,
            context.timeout_ms,
            context.data_classification,
            context.retention_policy_ref,
        )
        if any(value is None for value in required):
            raise ValueError("allowed execution requires complete resolved inputs")
        return AIExecutionPlan(
            contract_version=request.contract_version,
            plan_id=context.plan_id,
            request_id=request.request_id,
            attempt_id=context.attempt_id,
            idempotency_key=request.idempotency_key,
            trace_id=request.trace_id,
            feature_key=request.feature_key,
            task_type=request.task_type,
            execution_mode=AIExecutionMode.PROVIDER,
            route_decision=RouteDecision.PROVIDER_EXECUTION,
            feature_flag=context.feature_flag,
            entitlement=context.entitlement,
            safety=context.safety,
            budget=context.budget,
            credit_reservation=context.credit_reservation,
            provider=context.provider,
            model=context.model,
            prompt=context.prompt,
            capability=context.required_capability,
            normalized_input=context.normalized_input,
            output_contract_ref=context.output_contract_ref,
            structured_output_schema=context.structured_output_schema,
            tool_schemas=context.tool_schemas,
            generation_controls=context.generation_controls,
            deadline_at=request.deadline_at,
            timeout_ms=context.timeout_ms,
            max_same_route_retries=context.max_same_route_retries,
            data_classification=context.data_classification,
            region_policy_ref=context.region_policy_ref,
            retention_policy_ref=context.retention_policy_ref,
        )

    @staticmethod
    def _gateway_request_from_plan(plan: AIExecutionPlan) -> AIGatewayRequest:
        assert plan.attempt_id is not None
        assert plan.provider is not None
        assert plan.model is not None
        assert plan.capability is not None
        assert plan.normalized_input is not None
        assert plan.timeout_ms is not None
        return AIGatewayRequest(
            contract_version=plan.contract_version,
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

    @staticmethod
    def _validate_fallback_identity(
        request: AIOrchestratorRequest,
        fallback: GatewayFallbackPolicy,
    ) -> None:
        for attempt in fallback.attempts:
            candidate = attempt.request
            if (
                candidate.request_id != request.request_id
                or candidate.idempotency_key != request.idempotency_key
                or candidate.trace_id != request.trace_id
                or candidate.feature_key != request.feature_key
            ):
                raise ValueError("fallback request identity mismatch")

    def _from_attempt_result(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        attempt: GatewayAttemptResult,
    ) -> AIOrchestratorResponse:
        if attempt.succeeded:
            assert attempt.response is not None
            return self._completed_response(
                request,
                context,
                attempt_ids=(attempt.attempt_id,),
                gateway_response=attempt.response,
            )
        return self._gateway_error_response(
            request,
            context,
            status=attempt.status,
            attempt_ids=(attempt.attempt_id,),
            detail=attempt.error.detail if attempt.error is not None else None,
        )

    def _from_execution_result(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        execution: GatewayExecutionResult,
    ) -> AIOrchestratorResponse:
        attempt_ids = tuple(item.attempt_id for item in execution.attempts)
        final = execution.final
        if execution.succeeded:
            assert final.response is not None
            return self._completed_response(
                request,
                context,
                attempt_ids=attempt_ids,
                gateway_response=final.response,
            )
        return self._gateway_error_response(
            request,
            context,
            status=execution.final_status,
            attempt_ids=attempt_ids,
            detail=final.error.detail if final.error is not None else None,
        )

    @staticmethod
    def _normalized_result(
        gateway_response: AIGatewayResponse,
    ) -> dict[str, JsonValue]:
        result: dict[str, JsonValue] = {}
        for field in (
            "content",
            "structured_output",
            "embedding",
            "embedding_dimension",
            "embedding_normalized",
            "finish_reason",
            "streaming_complete",
        ):
            value = getattr(gateway_response, field)
            if value is not None:
                result[field] = value
        if gateway_response.tool_calls:
            result["tool_calls"] = [
                call.model_dump(mode="json") for call in gateway_response.tool_calls
            ]
        return result

    def _completed_response(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        *,
        attempt_ids: tuple[str, ...],
        gateway_response: AIGatewayResponse,
    ) -> AIOrchestratorResponse:
        return AIOrchestratorResponse(
            contract_version=request.contract_version,
            request_id=request.request_id,
            idempotency_key=request.idempotency_key,
            trace_id=request.trace_id,
            feature_key=request.feature_key,
            status=AIRequestStatus.COMPLETED,
            execution_mode=AIExecutionMode.PROVIDER,
            route_decision=RouteDecision.PROVIDER_EXECUTION,
            safety=context.safety,
            result=self._normalized_result(gateway_response),
            attempt_ids=attempt_ids,
            credit_reservation=context.credit_reservation,
            policy_version_refs=context.policy_version_refs,
            provenance_refs=context.provenance_refs,
            may_commit_business_transaction=context.may_commit_business_transaction,
        )

    def _gateway_error_response(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        *,
        status: GatewayExecutionStatus,
        attempt_ids: tuple[str, ...],
        detail: AIErrorDetail | None,
    ) -> AIOrchestratorResponse:
        unavailable = {
            GatewayExecutionStatus.ADAPTER_UNAVAILABLE,
            GatewayExecutionStatus.UNSUPPORTED_CAPABILITY,
            GatewayExecutionStatus.PROVIDER_UNAVAILABLE,
            GatewayExecutionStatus.PROVIDER_TIMEOUT,
        }
        if status is GatewayExecutionStatus.CANCELLED:
            outcome = AIRequestStatus.CANCELLED
        elif status is GatewayExecutionStatus.MALFORMED_RESPONSE:
            outcome = AIRequestStatus.INVALID
        elif status in unavailable:
            outcome = AIRequestStatus.UNAVAILABLE
        else:
            outcome = AIRequestStatus.FAILED
        if detail is None:
            detail = self._platform_error(
                AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                "gateway_result_missing_error_detail",
            )
        return AIOrchestratorResponse(
            contract_version=request.contract_version,
            request_id=request.request_id,
            idempotency_key=request.idempotency_key,
            trace_id=request.trace_id,
            feature_key=request.feature_key,
            status=outcome,
            execution_mode=AIExecutionMode.PROVIDER,
            route_decision=RouteDecision.PROVIDER_EXECUTION,
            safety=context.safety,
            attempt_ids=attempt_ids,
            credit_reservation=context.credit_reservation,
            policy_version_refs=context.policy_version_refs,
            provenance_refs=context.provenance_refs,
            error=detail,
            may_commit_business_transaction=False,
        )

    def _deterministic_response(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
    ) -> AIOrchestratorResponse:
        if context.deterministic_result is None:
            return self._error_response(
                request,
                context,
                status=AIRequestStatus.UNAVAILABLE,
                code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                diagnostic_code="deterministic_result_unavailable",
            )
        return AIOrchestratorResponse(
            contract_version=request.contract_version,
            request_id=request.request_id,
            idempotency_key=request.idempotency_key,
            trace_id=request.trace_id,
            feature_key=request.feature_key,
            status=AIRequestStatus.DETERMINISTIC_ONLY,
            execution_mode=AIExecutionMode.DETERMINISTIC_ONLY,
            route_decision=RouteDecision.DETERMINISTIC_ONLY,
            safety=context.safety,
            result=context.deterministic_result,
            credit_reservation=context.credit_reservation,
            policy_version_refs=context.policy_version_refs,
            provenance_refs=context.provenance_refs,
            may_commit_business_transaction=False,
        )

    def _denied_response(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        policy: PolicyCompositionResult,
    ) -> AIOrchestratorResponse:
        primary = policy.reason_codes[0] if policy.reason_codes else "policy_denied"
        code = {
            "feature_disabled": AIPlatformErrorCode.FEATURE_DISABLED,
            "entitlement_denied": AIPlatformErrorCode.ENTITLEMENT_DENIED,
            "safety_denied": AIPlatformErrorCode.SAFETY_DENIED,
            "budget_denied": AIPlatformErrorCode.BUDGET_DENIED,
        }.get(primary, AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE)
        return self._error_response(
            request,
            context,
            status=AIRequestStatus.DENIED,
            code=code,
            diagnostic_code=primary,
        )

    def _error_response(
        self,
        request: AIOrchestratorRequest,
        context: OrchestratorCoordinationContext,
        *,
        status: AIRequestStatus,
        code: AIPlatformErrorCode,
        diagnostic_code: str,
        execution_mode: AIExecutionMode = AIExecutionMode.NONE,
        route_decision: RouteDecision = RouteDecision.DENY,
    ) -> AIOrchestratorResponse:
        return AIOrchestratorResponse(
            contract_version=request.contract_version,
            request_id=request.request_id,
            idempotency_key=request.idempotency_key,
            trace_id=request.trace_id,
            feature_key=request.feature_key,
            status=status,
            execution_mode=execution_mode,
            route_decision=route_decision,
            safety=context.safety,
            credit_reservation=context.credit_reservation,
            policy_version_refs=context.policy_version_refs,
            provenance_refs=context.provenance_refs,
            error=self._platform_error(code, diagnostic_code),
            may_commit_business_transaction=False,
        )

    @staticmethod
    def _platform_error(
        code: AIPlatformErrorCode,
        diagnostic_code: str,
    ) -> AIErrorDetail:
        return AIErrorDetail(
            code=code,
            same_route_retry_safe=False,
            execution_may_have_occurred=False,
            usage_state=ErrorFactState.KNOWN_ZERO,
            cost_state=ErrorFactState.KNOWN_ZERO,
            diagnostic_code=diagnostic_code,
        )

    def _append_observations(
        self,
        response: AIOrchestratorResponse,
        events: tuple[LedgerEventDraft, ...],
    ) -> AIOrchestratorResponse:
        if self._ledger_writer is None or not events:
            return response
        references = list(response.ledger_event_refs)
        for event in events:
            try:
                written = self._ledger_writer.append(event)
                if written.status in {
                    LedgerWriteStatus.RECORDED,
                    LedgerWriteStatus.ALREADY_RECORDED,
                }:
                    reference = written.canonical_event_id or written.event_id
                    if not isinstance(reference, str) or not reference:
                        continue
                    references.append(reference)
            except Exception:
                continue
        return response.model_copy(update={"ledger_event_refs": tuple(references)})


__all__ = [
    "AIOrchestratorCoordinator",
    "OrchestratorCoordinationContext",
]
