"""Inert append-only ledger draft infrastructure for the NAJM AI Platform.

This module records normalized :class:`LedgerEventDraft` facts only when a
caller explicitly invokes a writer.  It does not initialize Firebase at
import time, register runtime services, enforce credits, or alter provider
execution.  The Firestore collection names are conceptual Phase 1 target
names, not deployed schema approval.
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
import threading
from abc import ABC, abstractmethod
from collections.abc import Callable, Mapping
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum
from typing import Any

from pydantic import AwareDatetime, BaseModel, ConfigDict, model_validator

from .contracts import LedgerEventDraft
from .errors import AIPlatformErrorCode


PROPOSED_AI_USAGE_LEDGER_COLLECTION = "aiUsageLedgerEvents"
PROPOSED_AI_IDEMPOTENCY_COLLECTION = "aiIdempotencyRecords"
_EVENT_RECORD_KIND = "ai_usage_ledger_event"
_IDEMPOTENCY_RECORD_KIND = "ai_ledger_idempotency"
_INTEGRITY_ALGORITHM = "sha256"
_PERSISTENCE_FIELDS = {
    "environment",
    "idempotency_scope_hash",
    "integrity_algorithm",
    "integrity_hash",
    "record_kind",
    "recorded_at",
}
_OPAQUE_REFERENCE_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$")
_JWT_PATTERN = re.compile(
    r"^eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$"
)
_SECRET_PREFIXES = ("AIza", "gsk_", "hf_", "sk-", "sk_", "xai-")
_MAX_CANONICAL_DECIMAL_CHARS = 100
_ALLOWED_POLICY_REF_KEYS = {
    "adapter",
    "budget",
    "burn_rate",
    "cost",
    "credit",
    "data",
    "entitlement",
    "feature",
    "feature_flag",
    "incident",
    "kill_switch",
    "memory",
    "model",
    "pricing",
    "prompt",
    "provider",
    "rag",
    "retention",
    "route",
    "safety",
    "tool",
}
_COMPACT_CODE_KEYS = {
    "environment",
    "event_type",
    "integrity_algorithm",
    "principal_type",
    "reason_code",
    "record_kind",
    "retention_class",
    "schema_version",
    "task_type",
}
_STANDARD_PROVIDER_USAGE_TOKEN_KEYS = {
    "cached_tokens",
    "embedding_tokens",
    "input_tokens",
    "output_tokens",
    "reasoning_tokens",
}


class LedgerWriteStatus(str, Enum):
    """Provider-neutral result of one append request."""

    RECORDED = "recorded"
    ALREADY_RECORDED = "already_recorded"
    CONFLICT = "conflict"
    FAILED = "failed"
    OUTCOME_UNKNOWN = "outcome_unknown"
    REJECTED = "rejected"


class LedgerWriteResult(BaseModel):
    """Compact result with no stored payload or infrastructure error text."""

    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
    )

    status: LedgerWriteStatus
    event_id: str
    canonical_event_id: str | None = None
    idempotency_key: str
    semantic_fingerprint: str
    payload_fingerprint: str
    recorded_at: AwareDatetime | None = None
    integrity_hash: str | None = None
    error_code: AIPlatformErrorCode | None = None

    @model_validator(mode="after")
    def status_matches_error(self) -> "LedgerWriteResult":
        expected_error = {
            LedgerWriteStatus.CONFLICT: AIPlatformErrorCode.IDEMPOTENCY_CONFLICT,
            LedgerWriteStatus.FAILED: AIPlatformErrorCode.LEDGER_UNAVAILABLE,
            LedgerWriteStatus.OUTCOME_UNKNOWN: AIPlatformErrorCode.LEDGER_UNAVAILABLE,
            LedgerWriteStatus.REJECTED: AIPlatformErrorCode.INVALID_LEDGER_EVENT,
        }.get(self.status)
        if expected_error is None and self.error_code is not None:
            raise ValueError("successful ledger result cannot contain an error code")
        if expected_error is not None and self.error_code is not expected_error:
            raise ValueError("ledger failure status requires its stable error code")
        if (
            self.status is LedgerWriteStatus.ALREADY_RECORDED
            and self.canonical_event_id is None
        ):
            raise ValueError("idempotent replay requires a canonical event reference")
        successful = self.status in {
            LedgerWriteStatus.RECORDED,
            LedgerWriteStatus.ALREADY_RECORDED,
        }
        if successful and (self.recorded_at is None or self.integrity_hash is None):
            raise ValueError("successful ledger result requires integrity metadata")
        if not successful and (
            self.recorded_at is not None or self.integrity_hash is not None
        ):
            raise ValueError("failed ledger result cannot claim persistence metadata")
        return self


class LedgerWriter(ABC):
    """Append-only writer boundary; deliberately exposes no mutation methods."""

    @abstractmethod
    def append(self, event: LedgerEventDraft) -> LedgerWriteResult:
        """Append one immutable draft or return an explicit replay/failure."""


_FORBIDDEN_EXACT_KEYS = {
    "access_token",
    "api_key",
    "auth_token",
    "authorization",
    "authorization_header",
    "card_number",
    "credential",
    "credentials",
    "cvv",
    "date_of_birth",
    "email",
    "firebase_token",
    "full_prompt",
    "generated_content",
    "id_token",
    "model_output",
    "passport_number",
    "password",
    "payment_credential",
    "payment_credentials",
    "phone",
    "prompt_body",
    "prompt_content",
    "prompt_text",
    "provider_api_key",
    "provider_token",
    "provider_tokens",
    "provider_output",
    "provider_payload",
    "raw_firebase_token",
    "raw_prompt",
    "raw_provider_payload",
    "raw_provider_request",
    "raw_provider_response",
    "raw_response",
    "raw_token",
    "receipt",
    "refresh_token",
    "roster_content",
    "roster_credential",
    "roster_credentials",
    "secret",
    "secret_key",
    "service_token",
    "system_prompt",
}


def _normalize_key(key: object) -> str:
    snake_key = re.sub(r"(?<!^)(?=[A-Z])", "_", str(key).strip())
    return re.sub(r"[^a-z0-9]+", "_", snake_key.lower()).strip("_")


def _key_is_forbidden(key: object) -> bool:
    normalized = _normalize_key(key)
    parts = set(normalized.split("_"))
    if normalized in _FORBIDDEN_EXACT_KEYS:
        return True
    if parts & {"password", "secret", "credential", "credentials"}:
        return True
    if "prompt" in parts and parts & {"body", "content", "full", "raw", "text"}:
        return True
    if "provider" in parts and (
        "payload" in parts
        or "output" in parts
        or "body" in parts
        or "content" in parts
        or ("raw" in parts and parts & {"request", "response"})
    ):
        return True
    if "roster" in parts and parts & {"content", "credential", "credentials", "raw"}:
        return True
    if "payment" in parts and parts & {"card", "credential", "credentials", "raw"}:
        return True
    return False


def _is_reference_key(key: object) -> bool:
    normalized = _normalize_key(key)
    return normalized.endswith(("_id", "_ids", "_key", "_ref", "_refs")) or (
        normalized
        in {
            "idempotency_key",
            "policy_refs",
            "semantic_fingerprint",
            *_COMPACT_CODE_KEYS,
        }
    )


def _validate_opaque_reference_value(value: Any) -> None:
    if isinstance(value, Mapping):
        for nested in value.values():
            _validate_opaque_reference_value(nested)
        return
    if isinstance(value, (list, tuple)):
        for nested in value:
            _validate_opaque_reference_value(nested)
        return
    if value is None:
        return
    if not isinstance(value, str):
        raise ValueError("ledger reference value must be an opaque string")
    normalized = value.strip().lower()
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        raise ValueError("ledger reference value contains control characters")
    if "://" in normalized:
        raise ValueError("ledger reference value cannot be a URL")
    if normalized.startswith(("bearer ", "basic ")):
        raise ValueError("ledger reference value cannot contain authorization data")
    if re.search(
        r"(?:^|[?&;])(?:api[_-]?key|credential|password|secret|token)=",
        normalized,
    ):
        raise ValueError("ledger reference value cannot contain credential data")
    if value.startswith("-----BEGIN") or _JWT_PATTERN.fullmatch(value):
        raise ValueError("ledger reference value cannot contain credential data")
    if value.startswith(_SECRET_PREFIXES):
        raise ValueError("ledger reference value cannot contain credential data")
    if _OPAQUE_REFERENCE_PATTERN.fullmatch(value) is None:
        raise ValueError("ledger reference value must be an opaque identifier")


def validate_ledger_event_safe_for_persistence(
    event_or_payload: LedgerEventDraft | Mapping[str, Any],
) -> None:
    """Reject sensitive or content-bearing keys before any persistence call.

    The check validates prohibited field channels and requires reference values
    to remain opaque identifiers.  It never logs or attempts to redact secret
    values.  ``LedgerEventDraft`` already forbids unknown fields; accepting
    mappings here also protects storage envelopes and future callers.
    """

    if isinstance(event_or_payload, LedgerEventDraft):
        payload: Any = event_or_payload.model_dump(mode="json")
    elif isinstance(event_or_payload, Mapping):
        payload = event_or_payload
    else:
        raise TypeError("ledger persistence validation requires a draft or mapping")

    def visit(value: Any, path: tuple[str, ...] = ()) -> None:
        if isinstance(value, Mapping):
            for key, nested in value.items():
                normalized_key = _normalize_key(key)
                if _key_is_forbidden(key):
                    raise ValueError(
                        f"forbidden ledger persistence key: {normalized_key}"
                    )
                token_key = bool(
                    set(normalized_key.split("_")) & {"token", "tokens"}
                )
                allowed_standard_token_fact = (
                    path[-1:] == ("provider_usage",)
                    and normalized_key in _STANDARD_PROVIDER_USAGE_TOKEN_KEYS
                )
                additional_native_fact = path[-2:] == (
                    "provider_usage",
                    "additional_native_units",
                )
                if token_key and not (
                    allowed_standard_token_fact or additional_native_fact
                ):
                    raise ValueError(
                        f"forbidden ledger persistence key: {normalized_key}"
                    )
                if normalized_key == "policy_refs":
                    if not isinstance(nested, Mapping):
                        raise ValueError("ledger policy references must be a mapping")
                    policy_keys = {_normalize_key(policy_key) for policy_key in nested}
                    if not policy_keys <= _ALLOWED_POLICY_REF_KEYS:
                        raise ValueError("ledger policy reference key is not approved")
                if additional_native_fact:
                    _validate_opaque_reference_value(normalized_key)
                if _is_reference_key(key):
                    _validate_opaque_reference_value(nested)
                visit(nested, (*path, normalized_key))
        elif isinstance(value, (list, tuple)):
            for nested in value:
                visit(nested, path)

    visit(payload)
    if payload.get("event_type") == "adjustment" and not payload.get(
        "related_event_ids"
    ):
        raise ValueError("adjustment ledger event requires a related event reference")
    if payload.get("credit_account_id") and payload.get("credit_pool_id"):
        raise ValueError("ledger credit effect requires one funding scope")


def serialize_ledger_event(event: LedgerEventDraft) -> dict[str, Any]:
    """Return a detached, JSON-safe representation of a validated draft."""

    if not isinstance(event, LedgerEventDraft):
        raise TypeError("serialize_ledger_event requires LedgerEventDraft")
    payload = _to_json_safe(event.model_dump(mode="python"))
    if not isinstance(payload, dict):
        raise TypeError("serialized ledger draft must be a mapping")
    validate_ledger_event_safe_for_persistence(payload)
    # Validate that no non-JSON or non-finite value escaped the explicit codec.
    json.dumps(payload, allow_nan=False)
    return payload


def _to_json_safe(value: Any) -> Any:
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, datetime):
        normalized = value.astimezone(timezone.utc).isoformat(timespec="microseconds")
        return normalized.replace("+00:00", "Z")
    if isinstance(value, Decimal):
        return _canonical_decimal(value)
    if isinstance(value, Mapping):
        return {str(key): _to_json_safe(nested) for key, nested in value.items()}
    if isinstance(value, (list, tuple)):
        return [_to_json_safe(nested) for nested in value]
    return copy.deepcopy(value)


def _canonical_decimal(value: Decimal) -> str:
    """Serialize a finite Decimal without applying the active math context."""

    if not value.is_finite():
        raise ValueError("ledger decimal must be finite")
    if value == 0:
        return "0"
    sign, digits, exponent = value.as_tuple()
    canonical_digits = list(digits)
    while exponent < 0 and canonical_digits[-1] == 0:
        canonical_digits.pop()
        exponent += 1
    digit_text = "".join(str(digit) for digit in canonical_digits) or "0"
    if exponent >= 0:
        if len(digit_text) + exponent + sign > _MAX_CANONICAL_DECIMAL_CHARS:
            raise ValueError("ledger decimal exceeds the persistence bound")
        result = digit_text + ("0" * exponent)
    else:
        decimal_position = len(digit_text) + exponent
        projected_length = (
            len(digit_text) + 1
            if decimal_position > 0
            else len(digit_text) - decimal_position + 2
        )
        if projected_length + sign > _MAX_CANONICAL_DECIMAL_CHARS:
            raise ValueError("ledger decimal exceeds the persistence bound")
        if decimal_position <= 0:
            result = "0." + ("0" * -decimal_position) + digit_text
        else:
            result = digit_text[:decimal_position] + "." + digit_text[decimal_position:]
        result = result.rstrip("0").rstrip(".")
    if "." in result:
        integer, fractional = result.split(".", maxsplit=1)
        result = (integer.lstrip("0") or "0") + "." + fractional
    else:
        result = result.lstrip("0") or "0"
    if sign:
        result = "-" + result
    if len(result) > _MAX_CANONICAL_DECIMAL_CHARS:
        raise ValueError("ledger decimal exceeds the persistence bound")
    return result


def _canonical_hash(payload: Mapping[str, Any], *, ignore_event_id: bool) -> str:
    material = copy.deepcopy(dict(payload))
    if ignore_event_id:
        material.pop("event_id", None)
    canonical = json.dumps(
        material,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _idempotency_scope_hash(event: LedgerEventDraft, *, environment: str) -> str:
    """Scope a caller key by environment and immutable event family.

    Each distinct effect within a family must receive its own server-supplied
    key.  A trusted tenant or organization boundary isolates callers; actor,
    request, funding, and policy facts remain outside the scope so changing
    them produces a conflict instead of a second append.  For an individual
    principal with no broader tenant, that principal is the tenant boundary.
    """

    if event.principal.tenant_id is not None:
        owner_scope_type = "tenant"
        owner_scope_id = event.principal.tenant_id
    elif event.principal.organization_id is not None:
        owner_scope_type = "organization"
        owner_scope_id = event.principal.organization_id
    else:
        owner_scope_type = f"principal:{event.principal.principal_type}"
        owner_scope_id = event.principal.principal_id
    scope = {
        "environment": environment,
        "event_type": event.event_type.value,
        "idempotency_key": event.idempotency_key,
        "owner_scope_id": owner_scope_id,
        "owner_scope_type": owner_scope_type,
    }
    return _canonical_hash(_to_json_safe(scope), ignore_event_id=False)


def _utc_recorded_at(clock: Callable[[], datetime]) -> datetime:
    recorded_at = clock()
    if recorded_at.tzinfo is None or recorded_at.utcoffset() is None:
        raise ValueError("ledger clock must return an aware datetime")
    return recorded_at.astimezone(timezone.utc)


def _validate_environment(environment: str) -> str:
    if not isinstance(environment, str) or not environment.strip():
        raise ValueError("ledger writer requires an environment scope")
    if len(environment) > 200:
        raise ValueError("ledger environment scope is too long")
    normalized = environment.strip()
    _validate_opaque_reference_value(normalized)
    return normalized


def _build_persisted_event(
    payload: Mapping[str, Any],
    *,
    environment: str,
    idempotency_scope_hash: str,
    recorded_at: datetime,
) -> dict[str, Any]:
    record = {
        "record_kind": _EVENT_RECORD_KIND,
        **copy.deepcopy(dict(payload)),
        "environment": environment,
        "idempotency_scope_hash": idempotency_scope_hash,
        "recorded_at": _to_json_safe(recorded_at),
        "integrity_algorithm": _INTEGRITY_ALGORITHM,
    }
    record["integrity_hash"] = _canonical_hash(record, ignore_event_id=False)
    validate_ledger_event_safe_for_persistence(record)
    return record


def _validate_persisted_event(
    record: Mapping[str, Any],
) -> tuple[dict[str, Any], datetime, str]:
    validate_ledger_event_safe_for_persistence(record)
    expected_fields = set(LedgerEventDraft.model_fields) | _PERSISTENCE_FIELDS
    if set(record) != expected_fields:
        raise ValueError("persisted ledger event has an unexpected schema")
    if record.get("record_kind") != _EVENT_RECORD_KIND:
        raise ValueError("persisted ledger event has an invalid record kind")
    if record.get("integrity_algorithm") != _INTEGRITY_ALGORITHM:
        raise ValueError("persisted ledger event has an invalid integrity algorithm")
    integrity_hash = record.get("integrity_hash")
    if not isinstance(integrity_hash, str):
        raise ValueError("persisted ledger event is missing its integrity hash")
    integrity_material = copy.deepcopy(dict(record))
    integrity_material.pop("integrity_hash", None)
    if _canonical_hash(integrity_material, ignore_event_id=False) != integrity_hash:
        raise ValueError("persisted ledger event failed integrity validation")

    recorded_value = record.get("recorded_at")
    if not isinstance(recorded_value, str):
        raise ValueError("persisted ledger event has an invalid recorded time")
    recorded_at = datetime.fromisoformat(recorded_value.replace("Z", "+00:00"))
    if recorded_at.tzinfo is None or recorded_at.utcoffset() is None:
        raise ValueError("persisted ledger event recorded time must be aware")

    draft_payload = {
        field_name: copy.deepcopy(record[field_name])
        for field_name in LedgerEventDraft.model_fields
    }
    validated_draft = LedgerEventDraft.model_validate(draft_payload)
    canonical_draft = serialize_ledger_event(validated_draft)
    if canonical_draft != draft_payload:
        raise ValueError("persisted ledger event is not canonically serialized")
    return canonical_draft, recorded_at.astimezone(timezone.utc), integrity_hash


def _document_id(namespace: str, identity: str) -> str:
    material = f"najm-ai-ledger:{namespace}:v1:{identity}".encode("utf-8")
    return hashlib.sha256(material).hexdigest()


def _result(
    event: LedgerEventDraft,
    payload_fingerprint: str,
    status: LedgerWriteStatus,
    *,
    canonical_event_id: str | None = None,
    recorded_at: datetime | None = None,
    integrity_hash: str | None = None,
) -> LedgerWriteResult:
    error_code = {
        LedgerWriteStatus.CONFLICT: AIPlatformErrorCode.IDEMPOTENCY_CONFLICT,
        LedgerWriteStatus.FAILED: AIPlatformErrorCode.LEDGER_UNAVAILABLE,
        LedgerWriteStatus.OUTCOME_UNKNOWN: AIPlatformErrorCode.LEDGER_UNAVAILABLE,
        LedgerWriteStatus.REJECTED: AIPlatformErrorCode.INVALID_LEDGER_EVENT,
    }.get(status)
    return LedgerWriteResult(
        status=status,
        event_id=event.event_id,
        canonical_event_id=canonical_event_id,
        idempotency_key=event.idempotency_key,
        semantic_fingerprint=event.semantic_fingerprint,
        payload_fingerprint=payload_fingerprint,
        recorded_at=recorded_at,
        integrity_hash=integrity_hash,
        error_code=error_code,
    )


def _rejected_result(event: LedgerEventDraft) -> LedgerWriteResult:
    def correlation_hash(namespace: str, value: str) -> str:
        digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[:24]
        return f"redacted-{namespace}-{digest}"

    return LedgerWriteResult(
        status=LedgerWriteStatus.REJECTED,
        event_id=correlation_hash("event", event.event_id),
        idempotency_key=correlation_hash("idempotency", event.idempotency_key),
        semantic_fingerprint=correlation_hash(
            "semantic",
            event.semantic_fingerprint,
        ),
        payload_fingerprint="unavailable",
        error_code=AIPlatformErrorCode.INVALID_LEDGER_EVENT,
    )


class InMemoryLedgerWriter(LedgerWriter):
    """Thread-safe test writer with the same immutable/idempotent discipline."""

    def __init__(
        self,
        *,
        environment: str,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self._events: dict[str, dict[str, Any]] = {}
        self._idempotency: dict[str, dict[str, str]] = {}
        self._lock = threading.RLock()
        self._environment = _validate_environment(environment)
        self._clock = clock or (lambda: datetime.now(timezone.utc))

    def append(self, event: LedgerEventDraft) -> LedgerWriteResult:
        try:
            payload = serialize_ledger_event(event)
            payload_fingerprint = _canonical_hash(payload, ignore_event_id=True)
            idempotency_scope_hash = _idempotency_scope_hash(
                event,
                environment=self._environment,
            )
        except (TypeError, ValueError):
            return _rejected_result(event)

        with self._lock:
            existing_identity = self._idempotency.get(idempotency_scope_hash)
            if existing_identity is not None:
                canonical_event_id = existing_identity["event_id"]
                stored_record = self._events.get(canonical_event_id)
                if stored_record is None:
                    return _result(
                        event,
                        payload_fingerprint,
                        LedgerWriteStatus.FAILED,
                    )
                try:
                    stored_payload, recorded_at, integrity_hash = (
                        _validate_persisted_event(stored_record)
                    )
                    stored_fingerprint = _canonical_hash(
                        stored_payload,
                        ignore_event_id=True,
                    )
                except (TypeError, ValueError):
                    return _result(
                        event,
                        payload_fingerprint,
                        LedgerWriteStatus.FAILED,
                    )
                matches = (
                    existing_identity["semantic_fingerprint"]
                    == event.semantic_fingerprint
                    and existing_identity["payload_fingerprint"]
                    == payload_fingerprint
                    and existing_identity["payload_fingerprint"]
                    == stored_fingerprint
                    and existing_identity["integrity_hash"] == integrity_hash
                    and stored_record.get("idempotency_scope_hash")
                    == idempotency_scope_hash
                    and existing_identity["environment"] == self._environment
                    and existing_identity["recorded_at"]
                    == stored_record.get("recorded_at")
                    and existing_identity["retention_class"]
                    == stored_payload.get("retention_class")
                )
                status = (
                    LedgerWriteStatus.ALREADY_RECORDED
                    if matches
                    else LedgerWriteStatus.CONFLICT
                )
                return _result(
                    event,
                    payload_fingerprint,
                    status,
                    canonical_event_id=canonical_event_id,
                    recorded_at=(
                        recorded_at
                        if status is LedgerWriteStatus.ALREADY_RECORDED
                        else None
                    ),
                    integrity_hash=(
                        integrity_hash
                        if status is LedgerWriteStatus.ALREADY_RECORDED
                        else None
                    ),
                )

            if event.event_id in self._events:
                return _result(
                    event,
                    payload_fingerprint,
                    LedgerWriteStatus.CONFLICT,
                    canonical_event_id=event.event_id,
                )

            try:
                recorded_at = _utc_recorded_at(self._clock)
                persisted_event = _build_persisted_event(
                    payload,
                    environment=self._environment,
                    idempotency_scope_hash=idempotency_scope_hash,
                    recorded_at=recorded_at,
                )
            except (TypeError, ValueError):
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            integrity_hash = str(persisted_event["integrity_hash"])
            self._events[event.event_id] = copy.deepcopy(persisted_event)
            self._idempotency[idempotency_scope_hash] = {
                "environment": self._environment,
                "event_id": event.event_id,
                "semantic_fingerprint": event.semantic_fingerprint,
                "payload_fingerprint": payload_fingerprint,
                "integrity_hash": integrity_hash,
                "recorded_at": str(persisted_event["recorded_at"]),
                "retention_class": event.retention_class,
            }
            return _result(
                event,
                payload_fingerprint,
                LedgerWriteStatus.RECORDED,
                canonical_event_id=event.event_id,
                recorded_at=recorded_at,
                integrity_hash=integrity_hash,
            )

    @property
    def events(self) -> tuple[dict[str, Any], ...]:
        """Return detached snapshots; callers cannot mutate stored history."""

        with self._lock:
            return tuple(copy.deepcopy(event) for event in self._events.values())

    def get_event(self, event_id: str) -> dict[str, Any] | None:
        """Return a detached event snapshot for tests and diagnostics."""

        with self._lock:
            event = self._events.get(event_id)
            return copy.deepcopy(event) if event is not None else None


class FirestoreLedgerWriter(LedgerWriter):
    """Optional create-only Firestore writer, inert until ``append`` is called.

    The writer atomically creates an immutable event and a separate
    idempotency record through a Firestore batch.  It never uses ``set``,
    ``update``, or ``delete``.  Exact production collections, indexes,
    retention, and paid-accounting transaction design remain unapproved.
    """

    def __init__(
        self,
        db: Any | None = None,
        *,
        environment: str,
        db_factory: Callable[[], Any] | None = None,
        clock: Callable[[], datetime] | None = None,
        event_collection: str = PROPOSED_AI_USAGE_LEDGER_COLLECTION,
        idempotency_collection: str = PROPOSED_AI_IDEMPOTENCY_COLLECTION,
    ) -> None:
        if db is not None and db_factory is not None:
            raise ValueError("provide either db or db_factory, not both")
        if not event_collection or "/" in event_collection:
            raise ValueError("event collection must be a direct collection name")
        if not idempotency_collection or "/" in idempotency_collection:
            raise ValueError("idempotency collection must be a direct collection name")
        self._db = db
        self._db_factory = db_factory
        self._environment = _validate_environment(environment)
        self._clock = clock or (lambda: datetime.now(timezone.utc))
        self._event_collection = event_collection
        self._idempotency_collection = idempotency_collection

    def _resolve_db(self) -> Any:
        if self._db is not None:
            return self._db
        if self._db_factory is not None:
            self._db = self._db_factory()
        else:
            # Lazy by design: importing this module never imports or initializes
            # Firebase and constructing the writer does not obtain a client.
            from utils.firebase import get_firestore

            self._db = get_firestore()
        return self._db

    @staticmethod
    def _snapshot_data(snapshot: Any) -> dict[str, Any] | None:
        if snapshot is None or not bool(getattr(snapshot, "exists", False)):
            return None
        value = snapshot.to_dict()
        if not isinstance(value, dict):
            raise ValueError("ledger snapshot is not a mapping")
        return copy.deepcopy(value)

    def _classify_existing(
        self,
        *,
        db: Any,
        event: LedgerEventDraft,
        payload_fingerprint: str,
        idempotency_scope_hash: str,
        candidate_event_ref: Any,
        idempotency_ref: Any,
    ) -> LedgerWriteResult | None:
        candidate_event_data = self._snapshot_data(candidate_event_ref.get())
        idempotency_data = self._snapshot_data(idempotency_ref.get())

        if idempotency_data is not None:
            expected_idempotency_fields = {
                "environment",
                "event_document_id",
                "event_id",
                "idempotency_key",
                "idempotency_scope_hash",
                "integrity_hash",
                "payload_fingerprint",
                "recorded_at",
                "record_kind",
                "retention_class",
                "schema_version",
                "semantic_fingerprint",
            }
            if set(idempotency_data) != expected_idempotency_fields:
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            if (
                idempotency_data.get("record_kind") != _IDEMPOTENCY_RECORD_KIND
                or idempotency_data.get("idempotency_scope_hash")
                != idempotency_scope_hash
                or idempotency_data.get("idempotency_key")
                != event.idempotency_key
                or idempotency_data.get("environment") != self._environment
            ):
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            canonical_document_id = idempotency_data.get("event_document_id")
            canonical_event_id = idempotency_data.get("event_id")
            if not isinstance(canonical_document_id, str) or not isinstance(
                canonical_event_id, str
            ):
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            canonical_ref = db.collection(self._event_collection).document(
                canonical_document_id
            )
            canonical_data = (
                candidate_event_data
                if canonical_document_id == candidate_event_ref.id
                else self._snapshot_data(canonical_ref.get())
            )
            if canonical_data is None:
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            try:
                canonical_payload, recorded_at, integrity_hash = (
                    _validate_persisted_event(canonical_data)
                )
                stored_fingerprint = _canonical_hash(
                    canonical_payload,
                    ignore_event_id=True,
                )
            except (TypeError, ValueError):
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            integrity_matches = (
                idempotency_data.get("payload_fingerprint") == stored_fingerprint
                and idempotency_data.get("semantic_fingerprint")
                == canonical_payload.get("semantic_fingerprint")
                and idempotency_data.get("integrity_hash") == integrity_hash
                and canonical_payload.get("event_id") == canonical_event_id
                and canonical_data.get("idempotency_scope_hash")
                == idempotency_scope_hash
                and canonical_data.get("environment") == self._environment
                and idempotency_data.get("recorded_at")
                == canonical_data.get("recorded_at")
                and idempotency_data.get("retention_class")
                == canonical_payload.get("retention_class")
                and idempotency_data.get("schema_version")
                == canonical_payload.get("schema_version")
            )
            if not integrity_matches:
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            candidate_matches = (
                idempotency_data.get("semantic_fingerprint")
                == event.semantic_fingerprint
                and stored_fingerprint == payload_fingerprint
            )
            status = (
                LedgerWriteStatus.ALREADY_RECORDED
                if candidate_matches
                else LedgerWriteStatus.CONFLICT
            )
            return _result(
                event,
                payload_fingerprint,
                status,
                canonical_event_id=canonical_event_id,
                recorded_at=(
                    recorded_at
                    if status is LedgerWriteStatus.ALREADY_RECORDED
                    else None
                ),
                integrity_hash=(
                    integrity_hash
                    if status is LedgerWriteStatus.ALREADY_RECORDED
                    else None
                ),
            )

        if candidate_event_data is not None:
            try:
                canonical_payload, _, _ = _validate_persisted_event(
                    candidate_event_data
                )
            except (TypeError, ValueError):
                return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)
            return _result(
                event,
                payload_fingerprint,
                LedgerWriteStatus.CONFLICT,
                canonical_event_id=str(
                    canonical_payload.get("event_id") or event.event_id
                ),
            )
        return None

    def append(self, event: LedgerEventDraft) -> LedgerWriteResult:
        try:
            payload = serialize_ledger_event(event)
            payload_fingerprint = _canonical_hash(payload, ignore_event_id=True)
            idempotency_scope_hash = _idempotency_scope_hash(
                event,
                environment=self._environment,
            )
        except (TypeError, ValueError):
            return _rejected_result(event)

        try:
            db = self._resolve_db()
            event_document_id = _document_id(
                "event",
                f"{self._environment}:{event.event_id}",
            )
            idempotency_document_id = _document_id(
                "idempotency",
                idempotency_scope_hash,
            )
            event_ref = db.collection(self._event_collection).document(event_document_id)
            idempotency_ref = db.collection(self._idempotency_collection).document(
                idempotency_document_id
            )

            existing = self._classify_existing(
                db=db,
                event=event,
                payload_fingerprint=payload_fingerprint,
                idempotency_scope_hash=idempotency_scope_hash,
                candidate_event_ref=event_ref,
                idempotency_ref=idempotency_ref,
            )
            if existing is not None:
                return existing

            recorded_at = _utc_recorded_at(self._clock)
            persisted_event = _build_persisted_event(
                payload,
                environment=self._environment,
                idempotency_scope_hash=idempotency_scope_hash,
                recorded_at=recorded_at,
            )
            integrity_hash = str(persisted_event["integrity_hash"])
            idempotency_record = {
                "record_kind": _IDEMPOTENCY_RECORD_KIND,
                "environment": self._environment,
                "event_document_id": event_document_id,
                "event_id": event.event_id,
                "idempotency_key": event.idempotency_key,
                "idempotency_scope_hash": idempotency_scope_hash,
                "semantic_fingerprint": event.semantic_fingerprint,
                "payload_fingerprint": payload_fingerprint,
                "integrity_hash": integrity_hash,
                "recorded_at": persisted_event["recorded_at"],
                "retention_class": event.retention_class,
                "schema_version": event.schema_version,
            }
            validate_ledger_event_safe_for_persistence(idempotency_record)
            batch = db.batch()
            batch.create(event_ref, copy.deepcopy(persisted_event))
            batch.create(idempotency_ref, idempotency_record)
            try:
                batch.commit()
            except Exception:
                # A lost acknowledgement or concurrent delivery may have
                # committed.  Resolve only from immutable records; never retry
                # by overwriting and never expose backend exception text.
                try:
                    existing = self._classify_existing(
                        db=db,
                        event=event,
                        payload_fingerprint=payload_fingerprint,
                        idempotency_scope_hash=idempotency_scope_hash,
                        candidate_event_ref=event_ref,
                        idempotency_ref=idempotency_ref,
                    )
                except Exception:
                    return _result(
                        event,
                        payload_fingerprint,
                        LedgerWriteStatus.OUTCOME_UNKNOWN,
                    )
                if existing is not None:
                    return existing
                return _result(
                    event,
                    payload_fingerprint,
                    LedgerWriteStatus.OUTCOME_UNKNOWN,
                )

            return _result(
                event,
                payload_fingerprint,
                LedgerWriteStatus.RECORDED,
                canonical_event_id=event.event_id,
                recorded_at=recorded_at,
                integrity_hash=integrity_hash,
            )
        except Exception:
            # Storage failures are explicit and redacted.  Runtime fail-open or
            # fail-closed behavior is intentionally outside this inert phase.
            return _result(event, payload_fingerprint, LedgerWriteStatus.FAILED)


__all__ = [
    "FirestoreLedgerWriter",
    "InMemoryLedgerWriter",
    "LedgerWriteResult",
    "LedgerWriteStatus",
    "LedgerWriter",
    "PROPOSED_AI_IDEMPOTENCY_COLLECTION",
    "PROPOSED_AI_USAGE_LEDGER_COLLECTION",
    "serialize_ledger_event",
    "validate_ledger_event_safe_for_persistence",
]
