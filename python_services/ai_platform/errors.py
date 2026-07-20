"""Stable, provider-neutral AI Platform error semantics.

This module contains contract vocabulary only. It performs no retries, provider
calls, configuration loading, or runtime initialization.
"""

from __future__ import annotations

from enum import Enum


class AIPlatformErrorCode(str, Enum):
    """Stable error codes exposed across internal AI Platform boundaries."""

    FEATURE_DISABLED = "feature_disabled"
    ENTITLEMENT_DENIED = "entitlement_denied"
    BUDGET_DENIED = "budget_denied"
    CREDIT_RESERVATION_DENIED = "credit_reservation_denied"
    SAFETY_DENIED = "safety_denied"
    PROMPT_UNAVAILABLE = "prompt_unavailable"
    MODEL_UNAVAILABLE = "model_unavailable"
    PROVIDER_UNAVAILABLE = "provider_unavailable"
    PROVIDER_TIMEOUT = "provider_timeout"
    MALFORMED_PROVIDER_RESPONSE = "malformed_provider_response"
    UNSUPPORTED_CAPABILITY = "unsupported_capability"
    IDEMPOTENCY_CONFLICT = "idempotency_conflict"
    INVALID_LEDGER_EVENT = "invalid_ledger_event"
    LEDGER_UNAVAILABLE = "ledger_unavailable"
    CONFIGURATION_UNAVAILABLE = "configuration_unavailable"


class ProviderErrorCode(str, Enum):
    """Stable provider-attempt errors normalized at the adapter boundary."""

    CONFIGURATION_UNAVAILABLE = "configuration_unavailable"
    AUTHENTICATION_OR_CREDENTIAL_REJECTED = "authentication_or_credential_rejected"
    MODEL_OR_CAPABILITY_UNAVAILABLE = "model_or_capability_unavailable"
    INVALID_NORMALIZED_REQUEST = "invalid_normalized_request"
    PROVIDER_INVALID_REQUEST_AFTER_TRANSLATION = (
        "provider_invalid_request_after_translation"
    )
    CONTENT_BLOCKED = "content_blocked"
    RATE_LIMITED_OR_QUOTA_EXHAUSTED = "rate_limited_or_quota_exhausted"
    TIMEOUT = "timeout"
    PROVIDER_UNAVAILABLE = "provider_unavailable"
    TRANSPORT_FAILURE = "transport_failure"
    CONTRACT_OR_RESPONSE_SHAPE_VIOLATION = "contract_or_response_shape_violation"
    OUTPUT_INCOMPLETE_OR_STREAMING_INTERRUPTED = (
        "output_incomplete_or_streaming_interrupted"
    )
    USAGE_OR_BILLING_FACTS_UNCERTAIN = "usage_or_billing_facts_uncertain"
    CANCELLED = "cancelled"
    UNKNOWN_PROVIDER_FAILURE = "unknown_provider_failure"


class AIPlatformError(Exception):
    """Lightweight exception carrying only a stable platform error code."""

    def __init__(self, code: AIPlatformErrorCode) -> None:
        self.code = code
        super().__init__(code.value)
