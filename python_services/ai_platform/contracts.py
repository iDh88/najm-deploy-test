"""Provider-independent contracts for the future NAJM AI Platform.

The models in this module are inert interface scaffolding. They do not route
requests, evaluate policy, reserve credits, write ledgers, or invoke providers.
Exact product feature keys and product result schemas remain owner-approved
future implementation details.
"""

from __future__ import annotations

import re
from decimal import Decimal
from enum import Enum
from typing import Annotated

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    JsonValue,
    StringConstraints,
    model_validator,
)

from .errors import AIPlatformErrorCode, ProviderErrorCode


Identifier = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=200),
]
PayloadText = Annotated[str, StringConstraints(min_length=1)]
DiagnosticCode = Annotated[
    str,
    StringConstraints(pattern=r"^[a-z][a-z0-9_.:-]{0,127}$"),
]
NonNegativeDecimal = Annotated[Decimal, Field(ge=0)]
MetadataValue = str | int | float | bool | None

_FORBIDDEN_PAYLOAD_KEYS = {
    "access_token",
    "api_key",
    "authorization_header",
    "credential",
    "credentials",
    "firebase_token",
    "ai_model_key",
    "ai_provider_key",
    "model_override",
    "native_model",
    "native_model_name",
    "password",
    "provider_api_key",
    "provider_base_url",
    "provider_endpoint",
    "provider_model",
    "provider_override",
    "provider_secret",
    "roster_credentials",
    "secret_key",
    "service_token",
}


def _reject_forbidden_payload_keys(value: JsonValue | dict[str, MetadataValue]) -> None:
    """Reject explicit secret and route-control fields, not user text content."""

    if isinstance(value, dict):
        for key, nested in value.items():
            snake_key = re.sub(r"(?<!^)(?=[A-Z])", "_", key.strip())
            normalized_key = re.sub(r"[^a-z0-9]+", "_", snake_key.lower()).strip(
                "_"
            )
            parts = set(normalized_key.split("_"))
            is_credential_channel = (
                normalized_key in _FORBIDDEN_PAYLOAD_KEYS
                or "api_key" in normalized_key
                or "password" in parts
                or "secret" in parts
                or "credential" in parts
                or "credentials" in parts
                or "token" in parts
                or normalized_key in {
                    "authorization",
                    "auth_header",
                    "session_cookie",
                }
            )
            is_route_channel = (
                ("provider" in parts and parts & {"endpoint", "key", "model", "override"})
                or ("model" in parts and parts & {"native", "override"})
                or normalized_key == "sdk_client"
            )
            if is_credential_channel or is_route_channel:
                raise ValueError(f"forbidden payload key: {normalized_key}")
            if isinstance(nested, (dict, list)):
                _reject_forbidden_payload_keys(nested)
    elif isinstance(value, list):
        for nested in value:
            if isinstance(nested, (dict, list)):
                _reject_forbidden_payload_keys(nested)


class AIFeatureKeyCategory(str, Enum):
    """Placeholder until the owner approves the target feature taxonomy."""

    UNSPECIFIED = "unspecified"


class AIRequestStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    DENIED = "denied"
    UNAVAILABLE = "unavailable"
    DETERMINISTIC_ONLY = "deterministic_only"
    CACHED = "cached"
    ABSTAINED = "abstained"
    INVALID = "invalid"
    FAILED = "failed"
    CANCELLED = "cancelled"


class AIExecutionMode(str, Enum):
    PROVIDER = "provider"
    DETERMINISTIC_ONLY = "deterministic_only"
    CACHE = "cache"
    NONE = "none"


class GatewayAttemptStatus(str, Enum):
    COMPLETED = "completed"
    FAILED = "failed"
    UNAVAILABLE = "unavailable"
    CANCELLED = "cancelled"


class AISafetyLevel(str, Enum):
    GENERAL_ASSISTANCE = "general_assistance"
    GROUNDED_OPERATIONAL_INFORMATION = "grounded_operational_information"
    AVIATION_SENSITIVE_ADVISORY = "aviation_sensitive_advisory"
    DETERMINISTIC_EXCLUSIVE = "deterministic_exclusive"


class AISafetyDecision(str, Enum):
    ALLOWED = "allowed"
    GROUNDED = "grounded"
    DETERMINISTIC_ONLY = "deterministic_only"
    ABSTAINED = "abstained"
    REFUSED = "refused"
    DEGRADED = "degraded"
    UNAVAILABLE = "unavailable"
    ESCALATED = "escalated"


class AIFallbackReason(str, Enum):
    """Fallback evidence only; a value never authorizes another attempt."""

    PROVIDER_UNAVAILABLE = "provider_unavailable"
    MODEL_UNAVAILABLE = "model_unavailable"
    CAPABILITY_UNAVAILABLE = "capability_unavailable"
    RATE_LIMITED = "rate_limited"
    TIMEOUT = "timeout"
    TRANSPORT_FAILURE = "transport_failure"
    ROUTE_SUSPENDED = "route_suspended"
    INCIDENT_POLICY = "incident_policy"


class ProviderCapability(str, Enum):
    TEXT_GENERATION = "text_generation"
    STRUCTURED_OUTPUT = "structured_output"
    TOOL_CALLING = "tool_calling"
    EMBEDDINGS = "embeddings"
    VISION = "vision"
    STREAMING = "streaming"
    USAGE_REPORTING = "usage_reporting"
    PROVIDER_SIDE_CACHING = "provider_side_caching"


class ProviderLifecycleState(str, Enum):
    PROPOSED = "proposed"
    APPROVED_DISABLED = "approved_disabled"
    ENABLED = "enabled"
    SUSPENDED = "suspended"
    RETIRED = "retired"


class ModelLifecycleState(str, Enum):
    PROPOSED = "proposed"
    EVALUATING = "evaluating"
    APPROVED_DISABLED = "approved_disabled"
    ENABLED = "enabled"
    DEPRECATED = "deprecated"
    SUSPENDED = "suspended"
    RETIRED = "retired"


class PromptLifecycleState(str, Enum):
    DRAFT = "draft"
    IN_REVIEW = "in_review"
    APPROVED = "approved"
    STAGED = "staged"
    ACTIVE = "active"
    SUPERSEDED = "superseded"
    SUSPENDED = "suspended"
    RETIRED = "retired"


class RouteDecision(str, Enum):
    ALLOW = "allow"
    DENY = "deny"
    DETERMINISTIC_ONLY = "deterministic_only"
    CACHE = "cache"
    PROVIDER_EXECUTION = "provider_execution"


class BudgetDecisionResult(str, Enum):
    ALLOW = "allow"
    DENY = "deny"
    BOUNDED_ALLOW = "bounded_allow"


class CreditReservationStatus(str, Enum):
    REQUESTED = "requested"
    ACTIVE = "active"
    AMENDED = "amended"
    RECONCILIATION_PENDING = "reconciliation_pending"
    RECONCILED = "reconciled"
    RELEASED = "released"
    EXPIRED = "expired"
    DISPUTED = "disputed"
    ADJUSTED = "adjusted"


class LedgerEventType(str, Enum):
    """Stable event families; granular storage event names remain deferred."""

    CREDIT_ALLOCATION = "credit_allocation"
    RESERVATION = "reservation"
    PROVIDER_ATTEMPT = "provider_attempt"
    USAGE_OUTCOME = "usage_outcome"
    CREDIT_RECONCILIATION = "credit_reconciliation"
    COST_RECONCILIATION = "cost_reconciliation"
    ADJUSTMENT = "adjustment"
    AUDIT = "audit"


class LedgerCreditDirection(str, Enum):
    NONE = "none"
    DEBIT = "debit"
    CREDIT = "credit"


class ProviderUsageCertainty(str, Enum):
    KNOWN_ZERO = "known_zero"
    KNOWN = "known"
    PARTIAL = "partial"
    ESTIMATED = "estimated"
    DELAYED = "delayed"
    UNCERTAIN = "uncertain"


class ProviderCostCertainty(str, Enum):
    KNOWN_ZERO = "known_zero"
    KNOWN = "known"
    PARTIAL = "partial"
    ESTIMATED = "estimated"
    DELAYED = "delayed"
    UNCERTAIN = "uncertain"


class ErrorFactState(str, Enum):
    KNOWN_ZERO = "known_zero"
    KNOWN = "known"
    PARTIAL = "partial"
    UNCERTAIN = "uncertain"


class ProviderConfigurationStatus(str, Enum):
    CONFIGURED = "configured"
    UNCONFIGURED = "unconfigured"


class ProviderHealthStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNAVAILABLE = "unavailable"
    UNKNOWN = "unknown"


class AIMessageRole(str, Enum):
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


class _ContractModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
        allow_inf_nan=False,
        protected_namespaces=(),
    )


class ProviderCapabilityMetadata(_ContractModel):
    """Provider-neutral adapter capability and governed constraint references."""

    capability: ProviderCapability
    modality_refs: tuple[Identifier, ...] = ()
    limit_refs: tuple[Identifier, ...] = ()
    known_limitation_codes: tuple[Identifier, ...] = ()
    usage_detail_supported: bool = False


class AIPrincipalRef(_ContractModel):
    """Minimized authenticated-principal reference; never a raw auth token."""

    principal_id: Identifier
    principal_type: Identifier = "user"
    authorization_ref: Identifier
    tenant_id: Identifier | None = None
    organization_id: Identifier | None = None


class AIContextRef(_ContractModel):
    """Reference to authorized context without embedding the source payload."""

    context_id: Identifier
    context_type: Identifier
    source_ref: Identifier
    source_version: Identifier | None = None
    data_classification: Identifier
    retention_policy_ref: Identifier
    metadata: dict[str, MetadataValue] = Field(default_factory=dict, max_length=32)

    @model_validator(mode="after")
    def metadata_has_no_secret_or_route_channel(self) -> "AIContextRef":
        if "://" in self.source_ref:
            raise ValueError("context source_ref must be an opaque reference, not a URL")
        _reject_forbidden_payload_keys(self.metadata)
        return self


class AIApprovedContextRef(AIContextRef):
    """Context reference authorized by an Orchestrator data-policy decision."""

    transmission_policy_ref: Identifier


class ProviderRegistryRef(_ContractModel):
    provider_key: Identifier
    registry_revision: Identifier
    adapter_key: Identifier
    adapter_contract_version: Identifier
    lifecycle: ProviderLifecycleState | None = None


class ModelRegistryRef(_ContractModel):
    model_key: Identifier
    model_revision: Identifier
    provider_key: Identifier
    lifecycle: ModelLifecycleState
    capabilities: frozenset[ProviderCapability] = Field(default_factory=frozenset)
    compatibility_authorization_ref: Identifier | None = None


class PromptRegistryRef(_ContractModel):
    prompt_family_key: Identifier
    prompt_version: Identifier
    registry_revision: Identifier
    content_hash: Identifier
    lifecycle: PromptLifecycleState
    rendering_key: Identifier | None = None


class FeatureFlagDecisionRef(_ContractModel):
    evaluation_id: Identifier
    flag_key: Identifier
    feature_key: Identifier
    flag_version: Identifier
    allowed: bool
    reason_code: Identifier
    source_ref: Identifier
    evaluated_at: AwareDatetime


class EntitlementDecisionRef(_ContractModel):
    decision_id: Identifier
    feature_key: Identifier
    policy_version: Identifier
    allowed: bool
    reason_code: Identifier
    evaluated_at: AwareDatetime
    service_level: Identifier | None = None
    valid_until: AwareDatetime | None = None
    source_ref: Identifier | None = None
    limits: dict[str, MetadataValue] = Field(default_factory=dict, max_length=32)


class SafetyDecisionRef(_ContractModel):
    decision_id: Identifier
    feature_key: Identifier
    policy_version: Identifier
    level: AISafetyLevel
    decision: AISafetyDecision
    evaluated_at: AwareDatetime
    reason_codes: tuple[Identifier, ...] = ()
    deterministic_authority_refs: tuple[Identifier, ...] = ()


class BudgetDecisionRef(_ContractModel):
    decision_id: Identifier
    request_id: Identifier
    feature_key: Identifier
    policy_version: Identifier
    result: BudgetDecisionResult
    evaluated_at: AwareDatetime
    expires_at: AwareDatetime
    reason_codes: tuple[Identifier, ...] = ()
    max_internal_cost: Decimal | None = Field(default=None, ge=0)
    internal_cost_currency: Identifier | None = None
    max_najm_credits: Decimal | None = Field(default=None, ge=0)
    max_attempts: int = Field(default=1, ge=1)
    override_ref: Identifier | None = None


class CreditReservationRef(_ContractModel):
    reservation_id: Identifier
    request_id: Identifier
    idempotency_key: Identifier
    status: CreditReservationStatus
    credit_policy_version: Identifier
    maximum_najm_credits: Decimal | None = Field(default=None, ge=0)
    reserved_najm_credits: Decimal | None = Field(default=None, ge=0)
    account_id: Identifier | None = None
    pool_id: Identifier | None = None
    expires_at: AwareDatetime | None = None

    @model_validator(mode="after")
    def active_reservation_has_bounded_funding(self) -> "CreditReservationRef":
        bounded_statuses = {
            CreditReservationStatus.ACTIVE,
            CreditReservationStatus.AMENDED,
            CreditReservationStatus.RECONCILIATION_PENDING,
        }
        if self.status in bounded_statuses:
            if self.maximum_najm_credits is None or self.reserved_najm_credits is None:
                raise ValueError("active reservation requires maximum and reserved credits")
            if self.account_id is None and self.pool_id is None:
                raise ValueError("active reservation requires an account or pool")
        if (
            self.maximum_najm_credits is not None
            and self.reserved_najm_credits is not None
            and self.reserved_najm_credits > self.maximum_najm_credits
        ):
            raise ValueError("reserved credits cannot exceed the authorized maximum")
        return self


class ProviderUsage(_ContractModel):
    """Internal provider-native usage facts; never customer credit units."""

    certainty: ProviderUsageCertainty
    input_tokens: int | None = Field(default=None, ge=0)
    output_tokens: int | None = Field(default=None, ge=0)
    cached_tokens: int | None = Field(default=None, ge=0)
    reasoning_tokens: int | None = Field(default=None, ge=0)
    embedding_tokens: int | None = Field(default=None, ge=0)
    additional_native_units: dict[Identifier, NonNegativeDecimal] = Field(
        default_factory=dict,
        max_length=16,
    )
    reported_at: AwareDatetime | None = None

    @model_validator(mode="after")
    def certainty_matches_reported_facts(self) -> "ProviderUsage":
        facts = (
            self.input_tokens,
            self.output_tokens,
            self.cached_tokens,
            self.reasoning_tokens,
            self.embedding_tokens,
            *self.additional_native_units.values(),
        )
        known_facts = tuple(value for value in facts if value is not None)
        if self.certainty in {
            ProviderUsageCertainty.KNOWN,
            ProviderUsageCertainty.KNOWN_ZERO,
        } and not known_facts:
            raise ValueError("known usage requires at least one reported fact")
        if self.certainty is ProviderUsageCertainty.KNOWN_ZERO and any(
            value != 0 for value in known_facts
        ):
            raise ValueError("known_zero usage cannot contain a positive quantity")
        if self.certainty is ProviderUsageCertainty.KNOWN and not any(
            value > 0 for value in known_facts
        ):
            raise ValueError("known non-zero usage requires a positive quantity")
        return self


class ProviderResponseRef(_ContractModel):
    """Opaque provider response provenance; no provider payload is retained."""

    response_ref_id: Identifier
    attempt_id: Identifier
    provider: ProviderRegistryRef
    model: ModelRegistryRef
    received_at: AwareDatetime
    provider_request_id: Identifier | None = None
    response_fingerprint: Identifier | None = None

    @model_validator(mode="after")
    def registry_route_is_consistent(self) -> "ProviderResponseRef":
        if self.provider.provider_key != self.model.provider_key:
            raise ValueError("provider and model Registry references must match")
        return self


class AIErrorDetail(_ContractModel):
    code: AIPlatformErrorCode | None = None
    provider_code: ProviderErrorCode | None = None
    same_route_retry_safe: bool
    execution_may_have_occurred: bool
    usage_state: ErrorFactState
    cost_state: ErrorFactState
    diagnostic_code: DiagnosticCode
    retry_after_seconds: float | None = Field(default=None, ge=0)
    provider_response_ref: Identifier | None = None
    provider_request_id: Identifier | None = None

    @model_validator(mode="after")
    def has_a_stable_error_category(self) -> "AIErrorDetail":
        if (self.code is None) == (self.provider_code is None):
            raise ValueError("exactly one platform or provider error code is required")
        return self


class NormalizedMessage(_ContractModel):
    role: AIMessageRole
    content: PayloadText
    name: Identifier | None = None
    tool_call_id: Identifier | None = None


class NormalizedToolSchema(_ContractModel):
    tool_key: Identifier
    description: str | None = None
    input_schema: dict[str, JsonValue]

    @model_validator(mode="after")
    def schema_has_no_secret_or_route_channel(self) -> "NormalizedToolSchema":
        _reject_forbidden_payload_keys(self.input_schema)
        return self


class NormalizedToolCall(_ContractModel):
    call_id: Identifier
    tool_key: Identifier
    arguments: dict[str, JsonValue]


class NormalizedAIInput(_ContractModel):
    """Resolved provider-neutral input; never a provider-native request body."""

    messages: tuple[NormalizedMessage, ...] = ()
    embedding_inputs: tuple[PayloadText, ...] = ()
    document_contexts: tuple[AIApprovedContextRef, ...] = ()
    structured_variables: dict[str, JsonValue] = Field(default_factory=dict, max_length=64)

    @model_validator(mode="after")
    def input_is_non_empty_and_has_no_override_channel(self) -> "NormalizedAIInput":
        if not (
            self.messages
            or self.embedding_inputs
            or self.document_contexts
            or self.structured_variables
        ):
            raise ValueError("normalized input must not be empty")
        _reject_forbidden_payload_keys(self.structured_variables)
        return self


class AIOrchestratorRequest(_ContractModel):
    """Provider-neutral work request accepted from a Product API."""

    contract_version: Identifier
    request_id: Identifier
    idempotency_key: Identifier
    trace_id: Identifier
    principal: AIPrincipalRef
    environment: Identifier
    feature_category: AIFeatureKeyCategory
    feature_key: Identifier
    task_type: Identifier
    product_input: dict[str, JsonValue] = Field(default_factory=dict, max_length=64)
    context_refs: tuple[AIContextRef, ...] = ()
    locale: Identifier = "en"
    response_contract_ref: Identifier
    safety_hint: AISafetyLevel | None = None
    deadline_at: AwareDatetime
    product_transaction_ref: Identifier
    continuity_ref: Identifier | None = None

    @model_validator(mode="after")
    def product_input_has_no_secret_or_route_channel(self) -> "AIOrchestratorRequest":
        if not self.product_input and not self.context_refs:
            raise ValueError("an AI work request requires product input or context")
        _reject_forbidden_payload_keys(self.product_input)
        return self


class AIExecutionPlan(_ContractModel):
    """Resolved Orchestrator decision snapshot for at most one Gateway attempt."""

    contract_version: Identifier
    plan_id: Identifier
    request_id: Identifier
    attempt_id: Identifier | None = None
    idempotency_key: Identifier
    trace_id: Identifier
    feature_key: Identifier
    task_type: Identifier
    execution_mode: AIExecutionMode
    route_decision: RouteDecision
    feature_flag: FeatureFlagDecisionRef
    entitlement: EntitlementDecisionRef
    safety: SafetyDecisionRef
    budget: BudgetDecisionRef
    credit_reservation: CreditReservationRef | None = None
    provider: ProviderRegistryRef | None = None
    model: ModelRegistryRef | None = None
    prompt: PromptRegistryRef | None = None
    capability: ProviderCapability | None = None
    normalized_input: NormalizedAIInput | None = None
    output_contract_ref: Identifier | None = None
    structured_output_schema: dict[str, JsonValue] | None = None
    tool_schemas: tuple[NormalizedToolSchema, ...] = ()
    generation_controls: dict[str, JsonValue] = Field(
        default_factory=dict,
        max_length=32,
    )
    deadline_at: AwareDatetime
    timeout_ms: int | None = Field(default=None, ge=1)
    max_same_route_retries: int = Field(default=0, ge=0)
    data_classification: Identifier
    region_policy_ref: Identifier | None = None
    retention_policy_ref: Identifier

    @model_validator(mode="after")
    def provider_execution_has_a_complete_route(self) -> "AIExecutionPlan":
        decision_feature_keys = (
            self.feature_flag.feature_key,
            self.entitlement.feature_key,
            self.safety.feature_key,
            self.budget.feature_key,
        )
        if any(key != self.feature_key for key in decision_feature_keys):
            raise ValueError("policy decision feature keys must match the plan")
        if self.budget.request_id != self.request_id:
            raise ValueError("Budget Decision request_id must match the plan")
        if self.credit_reservation is not None:
            if self.credit_reservation.request_id != self.request_id:
                raise ValueError("credit reservation request_id must match the plan")
            if self.credit_reservation.idempotency_key != self.idempotency_key:
                raise ValueError("credit reservation idempotency_key must match the plan")
        if self.route_decision is RouteDecision.PROVIDER_EXECUTION:
            required = (
                self.attempt_id,
                self.provider,
                self.model,
                self.capability,
                self.normalized_input,
                self.timeout_ms,
            )
            if any(value is None for value in required):
                raise ValueError(
                    "provider_execution requires a complete executable route and input"
                )
            if self.execution_mode is not AIExecutionMode.PROVIDER:
                raise ValueError("provider_execution requires provider execution mode")
            if not self.feature_flag.allowed or not self.entitlement.allowed:
                raise ValueError("provider_execution cannot bypass a deny decision")
            if self.budget.result not in {
                BudgetDecisionResult.ALLOW,
                BudgetDecisionResult.BOUNDED_ALLOW,
            }:
                raise ValueError("provider_execution requires budget approval")
            if self.safety.decision not in {
                AISafetyDecision.ALLOWED,
                AISafetyDecision.GROUNDED,
                AISafetyDecision.DEGRADED,
            }:
                raise ValueError("provider_execution requires a permitting safety decision")
            if self.credit_reservation is not None and self.credit_reservation.status not in {
                CreditReservationStatus.ACTIVE,
                CreditReservationStatus.AMENDED,
            }:
                raise ValueError("provider_execution requires an active credit reservation")
            assert self.provider is not None and self.model is not None
            if self.provider.provider_key != self.model.provider_key:
                raise ValueError("provider and model Registry references must match")
            if self.provider.lifecycle is not ProviderLifecycleState.ENABLED:
                raise ValueError("provider_execution requires an enabled provider revision")
            if self.model.lifecycle is ModelLifecycleState.DEPRECATED:
                if self.model.compatibility_authorization_ref is None:
                    raise ValueError("deprecated model requires compatibility authorization")
            elif self.model.lifecycle is not ModelLifecycleState.ENABLED:
                raise ValueError("provider_execution requires an eligible model revision")
            assert self.capability is not None and self.normalized_input is not None
            if self.capability not in self.model.capabilities:
                raise ValueError("model revision does not declare the required capability")
            if self.capability is ProviderCapability.EMBEDDINGS:
                if not self.normalized_input.embedding_inputs:
                    raise ValueError("embedding execution requires embedding input")
            elif not (
                self.normalized_input.messages
                or self.normalized_input.document_contexts
                or self.normalized_input.structured_variables
            ):
                raise ValueError("generation execution requires normalized input")
            if self.capability is ProviderCapability.STRUCTURED_OUTPUT:
                if self.structured_output_schema is None:
                    raise ValueError("structured output requires a resolved schema")
            if self.capability is ProviderCapability.TOOL_CALLING and not self.tool_schemas:
                raise ValueError("tool calling requires resolved tool schemas")
            if self.capability is not ProviderCapability.EMBEDDINGS:
                if (
                    self.prompt is None
                    or self.prompt.lifecycle is not PromptLifecycleState.ACTIVE
                ):
                    raise ValueError("generation execution requires an executable prompt")
            _reject_forbidden_payload_keys(self.generation_controls)
            if self.structured_output_schema is not None:
                _reject_forbidden_payload_keys(self.structured_output_schema)
        elif self.execution_mode is AIExecutionMode.PROVIDER:
            raise ValueError("provider execution mode requires provider_execution route")
        if (
            self.route_decision is RouteDecision.DENY
            and self.execution_mode is not AIExecutionMode.NONE
        ):
            raise ValueError("deny route requires none execution mode")
        if (
            self.route_decision is RouteDecision.DETERMINISTIC_ONLY
            and self.execution_mode is not AIExecutionMode.DETERMINISTIC_ONLY
        ):
            raise ValueError("deterministic-only route requires deterministic-only mode")
        if (
            self.route_decision is RouteDecision.CACHE
            and self.execution_mode is not AIExecutionMode.CACHE
        ):
            raise ValueError("cache route requires cache execution mode")
        return self


class AIGatewayRequest(_ContractModel):
    """One normalized attempt; the Gateway does not re-evaluate product policy."""

    contract_version: Identifier
    request_id: Identifier
    attempt_id: Identifier
    idempotency_key: Identifier
    trace_id: Identifier
    execution_plan_id: Identifier
    feature_key: Identifier
    provider: ProviderRegistryRef
    model: ModelRegistryRef
    prompt: PromptRegistryRef | None = None
    capability: ProviderCapability
    normalized_input: NormalizedAIInput
    output_contract_ref: Identifier | None = None
    structured_output_schema: dict[str, JsonValue] | None = None
    tool_schemas: tuple[NormalizedToolSchema, ...] = ()
    generation_controls: dict[str, JsonValue] = Field(
        default_factory=dict,
        max_length=32,
    )
    deadline_at: AwareDatetime
    timeout_ms: int = Field(ge=1)
    max_same_route_retries: int = Field(default=0, ge=0)
    data_classification: Identifier
    region_policy_ref: Identifier | None = None
    retention_policy_ref: Identifier

    @model_validator(mode="after")
    def registry_route_is_consistent(self) -> "AIGatewayRequest":
        if self.provider.provider_key != self.model.provider_key:
            raise ValueError("provider and model Registry references must match")
        if self.provider.lifecycle is not ProviderLifecycleState.ENABLED:
            raise ValueError("Gateway execution requires an enabled provider revision")
        if self.model.lifecycle is ModelLifecycleState.DEPRECATED:
            if self.model.compatibility_authorization_ref is None:
                raise ValueError("deprecated model requires compatibility authorization")
        elif self.model.lifecycle is not ModelLifecycleState.ENABLED:
            raise ValueError("Gateway execution requires an eligible model revision")
        if self.capability not in self.model.capabilities:
            raise ValueError("model revision does not declare the required capability")
        if self.capability is ProviderCapability.EMBEDDINGS:
            if not self.normalized_input.embedding_inputs:
                raise ValueError("embedding execution requires embedding input")
        elif not (
            self.normalized_input.messages
            or self.normalized_input.document_contexts
            or self.normalized_input.structured_variables
        ):
            raise ValueError("generation execution requires normalized input")
        if self.capability is ProviderCapability.STRUCTURED_OUTPUT:
            if self.structured_output_schema is None:
                raise ValueError("structured output requires a resolved schema")
        if self.capability is ProviderCapability.TOOL_CALLING and not self.tool_schemas:
            raise ValueError("tool calling requires resolved tool schemas")
        if self.capability is not ProviderCapability.EMBEDDINGS:
            if (
                self.prompt is None
                or self.prompt.lifecycle is not PromptLifecycleState.ACTIVE
            ):
                raise ValueError("generation execution requires an executable prompt")
        _reject_forbidden_payload_keys(self.generation_controls)
        if self.structured_output_schema is not None:
            _reject_forbidden_payload_keys(self.structured_output_schema)
        return self


class AIGatewayResponse(_ContractModel):
    """Normalized attempt facts returned by the Gateway."""

    contract_version: Identifier
    request_id: Identifier
    attempt_id: Identifier
    idempotency_key: Identifier
    feature_key: Identifier
    status: GatewayAttemptStatus
    provider_response: ProviderResponseRef | None = None
    content: str | None = None
    structured_output: dict[str, JsonValue] | None = None
    embedding: tuple[float, ...] | None = None
    embedding_dimension: int | None = Field(default=None, ge=1)
    embedding_normalized: bool | None = None
    tool_calls: tuple[NormalizedToolCall, ...] = ()
    provider_safety_signal_refs: tuple[Identifier, ...] = ()
    finish_reason: Identifier | None = None
    streaming_complete: bool | None = None
    usage: ProviderUsage | None = None
    reported_internal_cost: NonNegativeDecimal | None = None
    reported_cost_currency: Identifier | None = None
    cost_certainty: ProviderCostCertainty | None = None
    provider_cache_ref: Identifier | None = None
    latency_ms: int | None = Field(default=None, ge=0)
    retry_count: int = Field(default=0, ge=0)
    error: AIErrorDetail | None = None

    @model_validator(mode="after")
    def terminal_result_is_consistent(self) -> "AIGatewayResponse":
        if self.provider_response is not None:
            if self.provider_response.attempt_id != self.attempt_id:
                raise ValueError("provider response attempt_id must match Gateway response")
            if (
                self.error is not None
                and self.error.provider_response_ref is not None
                and self.error.provider_response_ref
                != self.provider_response.response_ref_id
            ):
                raise ValueError("error provider response reference must match")
        has_result = any(
            (
                self.content is not None,
                self.structured_output is not None,
                self.embedding is not None,
                bool(self.tool_calls),
            )
        )
        if self.status is GatewayAttemptStatus.COMPLETED:
            if self.error is not None or not has_result or self.provider_response is None:
                raise ValueError("completed Gateway response requires a result and no error")
        elif self.error is None:
            raise ValueError("non-completed Gateway response requires an error")
        if self.error is not None:
            expected_usage_states = {
                ErrorFactState.KNOWN_ZERO: {ProviderUsageCertainty.KNOWN_ZERO},
                ErrorFactState.KNOWN: {ProviderUsageCertainty.KNOWN},
                ErrorFactState.PARTIAL: {ProviderUsageCertainty.PARTIAL},
                ErrorFactState.UNCERTAIN: {
                    ProviderUsageCertainty.ESTIMATED,
                    ProviderUsageCertainty.DELAYED,
                    ProviderUsageCertainty.UNCERTAIN,
                },
            }
            if self.error.usage_state is not ErrorFactState.UNCERTAIN:
                if self.usage is None:
                    raise ValueError("known or partial error usage requires usage facts")
            if self.usage is not None and self.usage.certainty not in expected_usage_states[
                self.error.usage_state
            ]:
                raise ValueError("error usage state contradicts normalized usage facts")

            expected_cost_states = {
                ErrorFactState.KNOWN_ZERO: {ProviderCostCertainty.KNOWN_ZERO},
                ErrorFactState.KNOWN: {ProviderCostCertainty.KNOWN},
                ErrorFactState.PARTIAL: {ProviderCostCertainty.PARTIAL},
                ErrorFactState.UNCERTAIN: {
                    ProviderCostCertainty.ESTIMATED,
                    ProviderCostCertainty.DELAYED,
                    ProviderCostCertainty.UNCERTAIN,
                },
            }
            if self.error.cost_state is not ErrorFactState.UNCERTAIN:
                if self.reported_internal_cost is None:
                    raise ValueError("known or partial error cost requires cost facts")
            if self.cost_certainty is not None and self.cost_certainty not in (
                expected_cost_states[self.error.cost_state]
            ):
                raise ValueError("error cost state contradicts normalized cost facts")
            if self.error.cost_state is ErrorFactState.KNOWN_ZERO:
                if self.reported_internal_cost != 0:
                    raise ValueError("known_zero error cost requires a zero cost fact")
            if self.error.cost_state is ErrorFactState.KNOWN:
                if self.reported_internal_cost == 0:
                    raise ValueError("known non-zero error cost cannot be zero")
        if self.embedding is not None:
            if self.embedding_dimension != len(self.embedding):
                raise ValueError("embedding dimension must match the normalized vector")
        elif self.embedding_dimension is not None or self.embedding_normalized is not None:
            raise ValueError("embedding metadata requires a normalized embedding")
        if (self.reported_internal_cost is None) != (
            self.reported_cost_currency is None
        ):
            raise ValueError("reported cost and currency must be present together")
        if self.reported_internal_cost is not None and self.cost_certainty is None:
            raise ValueError("reported cost requires a cost certainty classification")
        return self


class FallbackAttempt(_ContractModel):
    """Trace of an Orchestrator-authorized attempt, never fallback permission."""

    request_id: Identifier
    attempt_id: Identifier
    idempotency_key: Identifier
    feature_key: Identifier
    ordinal: int = Field(ge=1)
    reason: AIFallbackReason
    status: GatewayAttemptStatus
    provider: ProviderRegistryRef
    model: ModelRegistryRef
    budget: BudgetDecisionRef
    credit_reservation: CreditReservationRef | None = None
    previous_attempt_id: Identifier | None = None
    error: AIErrorDetail | None = None

    @model_validator(mode="after")
    def correlation_is_consistent(self) -> "FallbackAttempt":
        if self.provider.provider_key != self.model.provider_key:
            raise ValueError("provider and model Registry references must match")
        if self.budget.request_id != self.request_id:
            raise ValueError("Budget Decision request_id must match fallback request")
        if self.budget.feature_key != self.feature_key:
            raise ValueError("Budget Decision feature_key must match fallback feature")
        if self.credit_reservation is not None:
            if self.credit_reservation.request_id != self.request_id:
                raise ValueError("credit reservation request_id must match fallback request")
            if self.credit_reservation.idempotency_key != self.idempotency_key:
                raise ValueError(
                    "credit reservation idempotency_key must match fallback request"
                )
        return self


class LedgerEventDraft(_ContractModel):
    """Append candidate containing compact facts and references, not content."""

    event_id: Identifier
    event_type: LedgerEventType
    request_id: Identifier
    idempotency_key: Identifier
    principal: AIPrincipalRef
    feature_key: Identifier
    task_type: Identifier
    occurred_at: AwareDatetime
    reason_code: Identifier
    source_ref: Identifier
    schema_version: Identifier
    semantic_fingerprint: Identifier
    retention_class: Identifier
    attempt_id: Identifier | None = None
    reservation_id: Identifier | None = None
    credit_transaction_ref: Identifier | None = None
    credit_account_id: Identifier | None = None
    credit_pool_id: Identifier | None = None
    provider_usage: ProviderUsage | None = None
    najm_credit_amount: Decimal | None = Field(default=None, ge=0)
    credit_direction: LedgerCreditDirection = LedgerCreditDirection.NONE
    related_event_ids: tuple[Identifier, ...] = ()
    policy_refs: dict[str, Identifier] = Field(min_length=1, max_length=32)

    @model_validator(mode="after")
    def credit_effect_has_direction_and_funding(self) -> "LedgerEventDraft":
        financial_event_types = {
            LedgerEventType.CREDIT_ALLOCATION,
            LedgerEventType.CREDIT_RECONCILIATION,
            LedgerEventType.ADJUSTMENT,
        }
        if self.event_type in financial_event_types:
            if self.najm_credit_amount is None or self.credit_transaction_ref is None:
                raise ValueError(
                    "financial ledger event requires a credit effect and transaction reference"
                )
        if self.najm_credit_amount is None:
            if self.credit_direction is not LedgerCreditDirection.NONE:
                raise ValueError("credit direction requires a NAJM credit amount")
        else:
            if self.credit_direction is LedgerCreditDirection.NONE:
                raise ValueError("NAJM credit amount requires debit or credit direction")
            if self.credit_account_id is None and self.credit_pool_id is None:
                raise ValueError("credit effect requires an account or pool reference")
        return self


class AIOrchestratorResponse(_ContractModel):
    """Provider-neutral outcome returned to a Product API."""

    contract_version: Identifier
    request_id: Identifier
    idempotency_key: Identifier
    trace_id: Identifier
    feature_key: Identifier
    status: AIRequestStatus
    execution_mode: AIExecutionMode
    route_decision: RouteDecision
    safety: SafetyDecisionRef
    result: dict[str, JsonValue] | None = None
    attempt_ids: tuple[Identifier, ...] = ()
    credit_reservation: CreditReservationRef | None = None
    ledger_event_refs: tuple[Identifier, ...] = ()
    policy_version_refs: dict[str, Identifier] = Field(
        min_length=1,
        max_length=32,
    )
    provenance_refs: tuple[Identifier, ...] = Field(min_length=1)
    error: AIErrorDetail | None = None
    may_commit_business_transaction: bool = False

    @model_validator(mode="after")
    def outcome_correlation_is_consistent(self) -> "AIOrchestratorResponse":
        if self.safety.feature_key != self.feature_key:
            raise ValueError("Safety Decision feature_key must match response")
        if self.credit_reservation is not None:
            if self.credit_reservation.request_id != self.request_id:
                raise ValueError("credit reservation request_id must match response")
            if self.credit_reservation.idempotency_key != self.idempotency_key:
                raise ValueError("credit reservation idempotency_key must match response")
        if self.route_decision is RouteDecision.PROVIDER_EXECUTION:
            if self.execution_mode is not AIExecutionMode.PROVIDER:
                raise ValueError("provider route requires provider execution mode")
            if not self.attempt_ids:
                raise ValueError("provider route requires at least one attempt reference")
        elif self.execution_mode is AIExecutionMode.PROVIDER:
            raise ValueError("provider execution mode requires provider route")
        if self.status is AIRequestStatus.DENIED and self.route_decision is not RouteDecision.DENY:
            raise ValueError("denied status requires a deny route")
        if (
            self.status is AIRequestStatus.DETERMINISTIC_ONLY
            and self.execution_mode is not AIExecutionMode.DETERMINISTIC_ONLY
        ):
            raise ValueError("deterministic-only status requires deterministic-only mode")
        successful_statuses = {
            AIRequestStatus.COMPLETED,
            AIRequestStatus.CACHED,
            AIRequestStatus.DETERMINISTIC_ONLY,
        }
        error_statuses = {
            AIRequestStatus.DENIED,
            AIRequestStatus.FAILED,
            AIRequestStatus.UNAVAILABLE,
            AIRequestStatus.INVALID,
        }
        if self.status in successful_statuses:
            if self.result is None or self.error is not None:
                raise ValueError("successful outcome requires a result and no error")
        if self.status in error_statuses:
            if self.error is None or self.result is not None:
                raise ValueError("error outcome requires an error and no result")
        if self.may_commit_business_transaction and self.status is not AIRequestStatus.COMPLETED:
            raise ValueError("only a completed outcome may permit a product commit")
        return self
