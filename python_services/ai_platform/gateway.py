"""Inert AI Gateway execution scaffolding for the NAJM AI Platform.

The Gateway executes one fully resolved, provider-neutral attempt against an
injected Provider Adapter and normalizes the outcome.  It is deliberately
inert: importing this module never imports a provider SDK, an HTTP client, or
Firebase, never registers a FastAPI route, never resolves a credential, and
never constructs a global adapter singleton.  The adapter catalog must be
constructed explicitly by the caller (today, tests only).

Boundary (see docs/architecture/AI_GATEWAY_AND_PROVIDER_ADAPTERS.md,
AI-GW-001/002/004):

* The Gateway validates the adapter binding and capability, invokes exactly one
  adapter per attempt, and returns normalized attempt facts.
* The Gateway does not own feature flags, entitlements, budgets, credits,
  safety policy, prompt selection, or provider/model business routing.
* Fallback is not a Gateway decision.  ``execute_with_fallback`` follows the
  caller-supplied, pre-approved, ordered attempt plan and stops after the first
  success.  The Gateway never independently chooses a route that is not present
  in the caller-supplied attempts.
* Provider Adapters remain the only component that will ever call an external
  provider.  This module talks to the abstract adapter interface only.
"""

from __future__ import annotations

from collections.abc import Iterable
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, model_validator

from .contracts import (
    AIErrorDetail,
    AIFallbackReason,
    AIGatewayRequest,
    AIGatewayResponse,
    ErrorFactState,
    GatewayAttemptStatus,
    ProviderCapability,
)
from .errors import AIPlatformErrorCode, ProviderErrorCode
from .provider_adapter import ProviderAdapter, ProviderAdapterError


class GatewayExecutionStatus(str, Enum):
    """Normalized Gateway classification of one attempt outcome.

    These are transport/execution facts, not Orchestrator policy outcomes: a
    Gateway attempt can never express ``denied``, ``deterministic_only``, or any
    entitlement/budget/credit/safety decision.
    """

    COMPLETED = "completed"
    ADAPTER_UNAVAILABLE = "adapter_unavailable"
    ROUTE_BINDING_INVALID = "route_binding_invalid"
    UNSUPPORTED_CAPABILITY = "unsupported_capability"
    PROVIDER_UNAVAILABLE = "provider_unavailable"
    PROVIDER_TIMEOUT = "provider_timeout"
    MALFORMED_RESPONSE = "malformed_response"
    PROVIDER_ERROR = "provider_error"
    CANCELLED = "cancelled"


_PROVIDER_ERROR_STATUS: dict[ProviderErrorCode, GatewayExecutionStatus] = {
    ProviderErrorCode.CONFIGURATION_UNAVAILABLE: (
        GatewayExecutionStatus.ADAPTER_UNAVAILABLE
    ),
    ProviderErrorCode.AUTHENTICATION_OR_CREDENTIAL_REJECTED: (
        GatewayExecutionStatus.ADAPTER_UNAVAILABLE
    ),
    ProviderErrorCode.MODEL_OR_CAPABILITY_UNAVAILABLE: (
        GatewayExecutionStatus.UNSUPPORTED_CAPABILITY
    ),
    ProviderErrorCode.INVALID_NORMALIZED_REQUEST: (
        GatewayExecutionStatus.MALFORMED_RESPONSE
    ),
    ProviderErrorCode.PROVIDER_INVALID_REQUEST_AFTER_TRANSLATION: (
        GatewayExecutionStatus.MALFORMED_RESPONSE
    ),
    ProviderErrorCode.RATE_LIMITED_OR_QUOTA_EXHAUSTED: (
        GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    ),
    ProviderErrorCode.TIMEOUT: GatewayExecutionStatus.PROVIDER_TIMEOUT,
    ProviderErrorCode.PROVIDER_UNAVAILABLE: (
        GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    ),
    ProviderErrorCode.TRANSPORT_FAILURE: (
        GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    ),
    ProviderErrorCode.CONTRACT_OR_RESPONSE_SHAPE_VIOLATION: (
        GatewayExecutionStatus.MALFORMED_RESPONSE
    ),
    ProviderErrorCode.OUTPUT_INCOMPLETE_OR_STREAMING_INTERRUPTED: (
        GatewayExecutionStatus.MALFORMED_RESPONSE
    ),
    ProviderErrorCode.CANCELLED: GatewayExecutionStatus.CANCELLED,
    # CONTENT_BLOCKED, USAGE_OR_BILLING_FACTS_UNCERTAIN, and
    # UNKNOWN_PROVIDER_FAILURE fall through to the generic provider error.
}

_PLATFORM_ERROR_STATUS: dict[AIPlatformErrorCode, GatewayExecutionStatus] = {
    AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE: (
        GatewayExecutionStatus.ADAPTER_UNAVAILABLE
    ),
    AIPlatformErrorCode.PROVIDER_UNAVAILABLE: (
        GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    ),
    AIPlatformErrorCode.MODEL_UNAVAILABLE: (
        GatewayExecutionStatus.PROVIDER_UNAVAILABLE
    ),
    AIPlatformErrorCode.PROVIDER_TIMEOUT: GatewayExecutionStatus.PROVIDER_TIMEOUT,
    AIPlatformErrorCode.MALFORMED_PROVIDER_RESPONSE: (
        GatewayExecutionStatus.MALFORMED_RESPONSE
    ),
    AIPlatformErrorCode.UNSUPPORTED_CAPABILITY: (
        GatewayExecutionStatus.UNSUPPORTED_CAPABILITY
    ),
}


def _status_from_error(detail: AIErrorDetail) -> GatewayExecutionStatus:
    """Map a normalized error detail to a Gateway execution status."""

    if detail.provider_code is not None:
        return _PROVIDER_ERROR_STATUS.get(
            detail.provider_code,
            GatewayExecutionStatus.PROVIDER_ERROR,
        )
    if detail.code is not None:
        return _PLATFORM_ERROR_STATUS.get(
            detail.code,
            GatewayExecutionStatus.PROVIDER_ERROR,
        )
    return GatewayExecutionStatus.PROVIDER_ERROR


class _GatewayModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
        protected_namespaces=(),
    )


class GatewayExecutionError(_GatewayModel):
    """Compact, redacted normalization of one failed attempt.

    It records the stable execution status and the normalized error facts.  It
    never carries a raw provider payload, provider-native error body, secret,
    or token; when the adapter produced a normalized ``AIErrorDetail`` it is
    retained verbatim under :attr:`detail`.
    """

    status: GatewayExecutionStatus
    reason_code: str = Field(min_length=1)
    same_route_retry_safe: bool = False
    execution_may_have_occurred: bool = False
    platform_error_code: AIPlatformErrorCode | None = None
    provider_error_code: ProviderErrorCode | None = None
    detail: AIErrorDetail | None = None

    @model_validator(mode="after")
    def _is_a_failure(self) -> "GatewayExecutionError":
        if self.status is GatewayExecutionStatus.COMPLETED:
            raise ValueError("a Gateway execution error cannot be COMPLETED")
        return self


class GatewayAttemptResult(_GatewayModel):
    """Normalized facts for exactly one Gateway attempt on one route."""

    request_id: str = Field(min_length=1)
    attempt_id: str = Field(min_length=1)
    feature_key: str = Field(min_length=1)
    provider_key: str = Field(min_length=1)
    model_key: str = Field(min_length=1)
    adapter_key: str = Field(min_length=1)
    capability: ProviderCapability
    status: GatewayExecutionStatus
    fallback_reason: AIFallbackReason | None = None
    response: AIGatewayResponse | None = None
    error: GatewayExecutionError | None = None

    @property
    def succeeded(self) -> bool:
        return self.status is GatewayExecutionStatus.COMPLETED

    @model_validator(mode="after")
    def _outcome_is_consistent(self) -> "GatewayAttemptResult":
        if self.status is GatewayExecutionStatus.COMPLETED:
            if self.error is not None:
                raise ValueError("a completed attempt cannot carry an error")
            if (
                self.response is None
                or self.response.status is not GatewayAttemptStatus.COMPLETED
            ):
                raise ValueError(
                    "a completed attempt requires a completed adapter response"
                )
        else:
            if self.error is None:
                raise ValueError("a non-completed attempt requires a normalized error")
            if self.error.status is not self.status:
                raise ValueError("attempt error status must match the attempt status")
        if self.response is not None:
            if (
                self.response.request_id != self.request_id
                or self.response.attempt_id != self.attempt_id
                or self.response.feature_key != self.feature_key
            ):
                raise ValueError("attempt response identity must match the attempt")
        return self


class GatewayAttemptPlan(_GatewayModel):
    """One caller-approved, pre-resolved attempt in an ordered fallback plan.

    ``fallback_reason`` is descriptive evidence supplied by the caller; it never
    authorizes the Gateway to invent another attempt.  The primary (first)
    attempt has no fallback reason.
    """

    request: AIGatewayRequest
    fallback_reason: AIFallbackReason | None = None


class GatewayFallbackPolicy(_GatewayModel):
    """An ordered, caller-supplied sequence of pre-approved attempts.

    The Gateway executes these attempts in order and never adds, reorders, or
    substitutes a route.  All attempts belong to one logical request and carry
    distinct attempt identifiers.
    """

    attempts: tuple[GatewayAttemptPlan, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def _plan_is_consistent(self) -> "GatewayFallbackPolicy":
        first = self.attempts[0]
        if first.fallback_reason is not None:
            raise ValueError("the primary attempt cannot carry a fallback reason")
        request_id = first.request.request_id
        feature_key = first.request.feature_key
        seen_attempt_ids: set[str] = set()
        for index, plan in enumerate(self.attempts):
            if plan.request.request_id != request_id:
                raise ValueError("all fallback attempts must share one request_id")
            if plan.request.feature_key != feature_key:
                raise ValueError("all fallback attempts must share one feature_key")
            if index > 0 and plan.fallback_reason is None:
                raise ValueError("a non-primary attempt must record its fallback reason")
            if plan.request.attempt_id in seen_attempt_ids:
                raise ValueError("fallback attempt identifiers must be unique")
            seen_attempt_ids.add(plan.request.attempt_id)
        return self


class GatewayExecutionResult(_GatewayModel):
    """Normalized outcome of executing an ordered fallback plan."""

    request_id: str = Field(min_length=1)
    feature_key: str = Field(min_length=1)
    final_status: GatewayExecutionStatus
    attempts: tuple[GatewayAttemptResult, ...] = Field(min_length=1)

    @property
    def succeeded(self) -> bool:
        return self.final_status is GatewayExecutionStatus.COMPLETED

    @property
    def final(self) -> GatewayAttemptResult:
        return self.attempts[-1]

    @model_validator(mode="after")
    def _history_is_consistent(self) -> "GatewayExecutionResult":
        attempt_ids: list[str] = []
        for attempt in self.attempts:
            if attempt.request_id != self.request_id:
                raise ValueError("all attempts must share the execution request_id")
            if attempt.feature_key != self.feature_key:
                raise ValueError("all attempts must share the execution feature_key")
            attempt_ids.append(attempt.attempt_id)
        if len(set(attempt_ids)) != len(attempt_ids):
            raise ValueError("attempt identifiers must be unique")
        completed = [
            index for index, attempt in enumerate(self.attempts) if attempt.succeeded
        ]
        if len(completed) > 1:
            raise ValueError("at most one attempt may complete")
        if completed and completed[0] != len(self.attempts) - 1:
            raise ValueError("a completed attempt must be the final executed attempt")
        if self.final_status is not self.attempts[-1].status:
            raise ValueError("final status must match the last attempt status")
        return self


class GatewayAdapterCatalog:
    """Explicitly constructed adapter binding table.

    The catalog is never a global singleton and holds no real provider clients
    or credentials — only whatever :class:`ProviderAdapter` instances the caller
    injects.  Bindings are keyed by the adapter's stable NAJM adapter key.
    """

    def __init__(self, adapters: Iterable[ProviderAdapter] = ()) -> None:
        indexed: dict[str, ProviderAdapter] = {}
        for adapter in adapters:
            if not isinstance(adapter, ProviderAdapter):
                raise TypeError("adapter catalog requires ProviderAdapter instances")
            adapter_key = adapter.adapter_key
            if adapter_key in indexed:
                raise ValueError("duplicate adapter binding")
            indexed[adapter_key] = adapter
        self._adapters = indexed

    def get(self, adapter_key: str) -> ProviderAdapter | None:
        return self._adapters.get(adapter_key)

    def __contains__(self, adapter_key: object) -> bool:
        return adapter_key in self._adapters

    @property
    def adapter_keys(self) -> tuple[str, ...]:
        return tuple(self._adapters)


def _synthetic_detail(
    *,
    code: AIPlatformErrorCode,
    diagnostic_code: str,
    execution_may_have_occurred: bool = False,
    same_route_retry_safe: bool = False,
) -> AIErrorDetail:
    """Build a normalized platform error with no provider execution facts."""

    return AIErrorDetail(
        code=code,
        same_route_retry_safe=same_route_retry_safe,
        execution_may_have_occurred=execution_may_have_occurred,
        usage_state=ErrorFactState.KNOWN_ZERO,
        cost_state=ErrorFactState.KNOWN_ZERO,
        diagnostic_code=diagnostic_code,
    )


def _synthetic_provider_detail(
    *,
    provider_code: ProviderErrorCode,
    diagnostic_code: str,
    execution_may_have_occurred: bool,
    same_route_retry_safe: bool,
) -> AIErrorDetail:
    """Build a normalized provider error with uncertain usage/cost facts."""

    return AIErrorDetail(
        provider_code=provider_code,
        same_route_retry_safe=same_route_retry_safe,
        execution_may_have_occurred=execution_may_have_occurred,
        usage_state=ErrorFactState.UNCERTAIN,
        cost_state=ErrorFactState.UNCERTAIN,
        diagnostic_code=diagnostic_code,
    )


def _error_from_detail(
    detail: AIErrorDetail,
    *,
    status: GatewayExecutionStatus | None = None,
) -> GatewayExecutionError:
    return GatewayExecutionError(
        status=status if status is not None else _status_from_error(detail),
        reason_code=detail.diagnostic_code,
        same_route_retry_safe=detail.same_route_retry_safe,
        execution_may_have_occurred=detail.execution_may_have_occurred,
        platform_error_code=detail.code,
        provider_error_code=detail.provider_code,
        detail=detail,
    )


class AIGateway:
    """Inert execution boundary over an injected adapter catalog.

    ``AIGateway`` runs only the caller-supplied normalized requests it is given.
    It does not select providers or models, evaluate policy, reserve credits, or
    decide fallback; ``execute_with_fallback`` merely walks the caller's ordered
    plan and stops at the first success.
    """

    def __init__(self, catalog: GatewayAdapterCatalog) -> None:
        if not isinstance(catalog, GatewayAdapterCatalog):
            raise TypeError("AIGateway requires a GatewayAdapterCatalog")
        self._catalog = catalog

    async def execute(
        self,
        request: AIGatewayRequest,
        *,
        fallback_reason: AIFallbackReason | None = None,
    ) -> GatewayAttemptResult:
        """Execute exactly one normalized attempt against its bound adapter."""

        if not isinstance(request, AIGatewayRequest):
            raise TypeError("AIGateway.execute requires an AIGatewayRequest")

        adapter = self._catalog.get(request.provider.adapter_key)
        if adapter is None:
            return self._failure(
                request,
                fallback_reason,
                status=GatewayExecutionStatus.ADAPTER_UNAVAILABLE,
                detail=_synthetic_detail(
                    code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                    diagnostic_code="adapter_binding_unavailable",
                ),
            )

        if adapter.provider.provider_key != request.provider.provider_key:
            return self._failure(
                request,
                fallback_reason,
                status=GatewayExecutionStatus.ROUTE_BINDING_INVALID,
                detail=_synthetic_detail(
                    code=AIPlatformErrorCode.CONFIGURATION_UNAVAILABLE,
                    diagnostic_code="adapter_provider_binding_mismatch",
                ),
            )

        if request.capability not in adapter.capabilities:
            return self._failure(
                request,
                fallback_reason,
                status=GatewayExecutionStatus.UNSUPPORTED_CAPABILITY,
                detail=_synthetic_detail(
                    code=AIPlatformErrorCode.UNSUPPORTED_CAPABILITY,
                    diagnostic_code="capability_not_supported_by_adapter",
                ),
            )

        try:
            response = await adapter.execute(request)
        except ProviderAdapterError as exc:
            return self._failure_from_detail(request, fallback_reason, exc.details)
        except TimeoutError:
            return self._failure_from_detail(
                request,
                fallback_reason,
                _synthetic_provider_detail(
                    provider_code=ProviderErrorCode.TIMEOUT,
                    diagnostic_code="adapter_execution_timeout",
                    execution_may_have_occurred=True,
                    same_route_retry_safe=False,
                ),
            )
        except Exception:
            # Redaction boundary: no raw provider/adapter exception text or
            # payload may cross into the normalized result.
            return self._failure_from_detail(
                request,
                fallback_reason,
                _synthetic_provider_detail(
                    provider_code=ProviderErrorCode.UNKNOWN_PROVIDER_FAILURE,
                    diagnostic_code="adapter_unexpected_failure",
                    execution_may_have_occurred=True,
                    same_route_retry_safe=False,
                ),
            )

        return self._normalize_response(request, fallback_reason, response)

    async def execute_with_fallback(
        self,
        policy: GatewayFallbackPolicy,
    ) -> GatewayExecutionResult:
        """Execute the caller's ordered attempts, stopping at the first success.

        The Gateway never chooses a route: it only walks ``policy.attempts`` in
        the supplied order and halts once an attempt completes.
        """

        if not isinstance(policy, GatewayFallbackPolicy):
            raise TypeError(
                "AIGateway.execute_with_fallback requires a GatewayFallbackPolicy"
            )

        results: list[GatewayAttemptResult] = []
        for plan in policy.attempts:
            result = await self.execute(
                plan.request,
                fallback_reason=plan.fallback_reason,
            )
            results.append(result)
            if result.succeeded:
                break

        primary_request = policy.attempts[0].request
        return GatewayExecutionResult(
            request_id=primary_request.request_id,
            feature_key=primary_request.feature_key,
            final_status=results[-1].status,
            attempts=tuple(results),
        )

    def _normalize_response(
        self,
        request: AIGatewayRequest,
        fallback_reason: AIFallbackReason | None,
        response: object,
    ) -> GatewayAttemptResult:
        if not isinstance(response, AIGatewayResponse):
            return self._failure(
                request,
                fallback_reason,
                status=GatewayExecutionStatus.MALFORMED_RESPONSE,
                detail=_synthetic_detail(
                    code=AIPlatformErrorCode.MALFORMED_PROVIDER_RESPONSE,
                    diagnostic_code="adapter_returned_non_contract_result",
                    execution_may_have_occurred=True,
                ),
            )

        if (
            response.request_id != request.request_id
            or response.attempt_id != request.attempt_id
            or response.feature_key != request.feature_key
        ):
            # The adapter answered for a different attempt; drop the
            # mis-correlated payload rather than attribute it to this route.
            return self._failure(
                request,
                fallback_reason,
                status=GatewayExecutionStatus.MALFORMED_RESPONSE,
                detail=_synthetic_detail(
                    code=AIPlatformErrorCode.MALFORMED_PROVIDER_RESPONSE,
                    diagnostic_code="adapter_response_identity_mismatch",
                    execution_may_have_occurred=True,
                ),
            )

        if response.status is GatewayAttemptStatus.COMPLETED:
            return self._result(
                request,
                fallback_reason,
                status=GatewayExecutionStatus.COMPLETED,
                response=response,
                error=None,
            )

        # A non-completed adapter response always carries a normalized error.
        detail = response.error
        assert detail is not None  # guaranteed by AIGatewayResponse validation
        error = _error_from_detail(detail)
        return self._result(
            request,
            fallback_reason,
            status=error.status,
            response=response,
            error=error,
        )

    def _failure_from_detail(
        self,
        request: AIGatewayRequest,
        fallback_reason: AIFallbackReason | None,
        detail: AIErrorDetail,
    ) -> GatewayAttemptResult:
        error = _error_from_detail(detail)
        return self._result(
            request,
            fallback_reason,
            status=error.status,
            response=None,
            error=error,
        )

    def _failure(
        self,
        request: AIGatewayRequest,
        fallback_reason: AIFallbackReason | None,
        *,
        status: GatewayExecutionStatus,
        detail: AIErrorDetail,
    ) -> GatewayAttemptResult:
        error = _error_from_detail(detail, status=status)
        return self._result(
            request,
            fallback_reason,
            status=status,
            response=None,
            error=error,
        )

    @staticmethod
    def _result(
        request: AIGatewayRequest,
        fallback_reason: AIFallbackReason | None,
        *,
        status: GatewayExecutionStatus,
        response: AIGatewayResponse | None,
        error: GatewayExecutionError | None,
    ) -> GatewayAttemptResult:
        return GatewayAttemptResult(
            request_id=request.request_id,
            attempt_id=request.attempt_id,
            feature_key=request.feature_key,
            provider_key=request.provider.provider_key,
            model_key=request.model.model_key,
            adapter_key=request.provider.adapter_key,
            capability=request.capability,
            status=status,
            fallback_reason=fallback_reason,
            response=response,
            error=error,
        )


__all__ = [
    "AIGateway",
    "GatewayAdapterCatalog",
    "GatewayAttemptPlan",
    "GatewayAttemptResult",
    "GatewayExecutionError",
    "GatewayExecutionResult",
    "GatewayExecutionStatus",
    "GatewayFallbackPolicy",
]
