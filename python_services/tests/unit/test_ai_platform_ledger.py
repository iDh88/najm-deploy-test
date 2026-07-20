"""Unit tests for inert, append-only AI Platform ledger infrastructure."""

from __future__ import annotations

import ast
import copy
import inspect
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest

from ai_platform.contracts import (
    AIPrincipalRef,
    LedgerCreditDirection,
    LedgerEventDraft,
    LedgerEventType,
    ProviderUsage,
    ProviderUsageCertainty,
)
from ai_platform.errors import AIPlatformErrorCode
from ai_platform.ledger import (
    FirestoreLedgerWriter,
    InMemoryLedgerWriter,
    LedgerWriteStatus,
    LedgerWriter,
    PROPOSED_AI_IDEMPOTENCY_COLLECTION,
    PROPOSED_AI_USAGE_LEDGER_COLLECTION,
    serialize_ledger_event,
    validate_ledger_event_safe_for_persistence,
)


NOW = datetime(2026, 7, 16, 8, 0, tzinfo=timezone.utc)
ENVIRONMENT = "unit_test"
PYTHON_SERVICES = Path(__file__).resolve().parents[2]
AI_PLATFORM_PACKAGE = PYTHON_SERVICES / "ai_platform"


def _event(**changes: Any) -> LedgerEventDraft:
    payload: dict[str, Any] = {
        "event_id": "ledger-event-1",
        "event_type": LedgerEventType.USAGE_OUTCOME,
        "request_id": "request-1",
        "idempotency_key": "ledger-idempotency-1",
        "principal": AIPrincipalRef(
            principal_id="user-1",
            authorization_ref="authorization-decision-1",
            organization_id="organization-1",
        ),
        "feature_key": "ai.assistant",
        "task_type": "answer",
        "occurred_at": NOW,
        "reason_code": "completed",
        "source_ref": "orchestration-outcome-1",
        "schema_version": "1",
        "semantic_fingerprint": "semantic-fingerprint-1",
        "retention_class": "internal_alpha_observability",
        "attempt_id": "attempt-1",
        "provider_usage": ProviderUsage(
            certainty=ProviderUsageCertainty.KNOWN,
            input_tokens=120,
            output_tokens=30,
            cached_tokens=10,
            reasoning_tokens=5,
            embedding_tokens=0,
            reported_at=NOW,
        ),
        "policy_refs": {
            "budget": "budget-policy-v1",
            "safety": "safety-policy-v1",
        },
    }
    payload.update(changes)
    return LedgerEventDraft.model_validate(payload)


def _credit_event(**changes: Any) -> LedgerEventDraft:
    payload = _event().model_dump()
    payload.update(
        {
            "event_type": LedgerEventType.CREDIT_RECONCILIATION,
            "reason_code": "reconciled",
            "source_ref": "credit-reconciliation-1",
            "reservation_id": "reservation-1",
            "credit_transaction_ref": "credit-transaction-1",
            "credit_account_id": "credit-account-1",
            "najm_credit_amount": Decimal("2.50"),
            "credit_direction": LedgerCreditDirection.DEBIT,
        }
    )
    payload.update(changes)
    return LedgerEventDraft.model_validate(payload)


class _FakeSnapshot:
    def __init__(self, document_id: str, value: dict[str, Any] | None) -> None:
        self.id = document_id
        self.exists = value is not None
        self._value = copy.deepcopy(value)

    def to_dict(self) -> dict[str, Any] | None:
        return copy.deepcopy(self._value)


class _FakeDocumentReference:
    def __init__(self, db: "_FakeFirestore", collection: str, document_id: str):
        self._db = db
        self._collection = collection
        self.id = document_id

    @property
    def key(self) -> tuple[str, str]:
        return self._collection, self.id

    def get(self) -> _FakeSnapshot:
        with self._db.lock:
            self._db.read_count += 1
            if self._db.fail_reads:
                raise RuntimeError("simulated backend failure with service_token=secret")
            return _FakeSnapshot(self.id, self._db.documents.get(self.key))

    def set(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("immutable fake does not support set")

    def update(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("immutable fake does not support update")

    def delete(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("immutable fake does not support delete")


class _FakeCollectionReference:
    def __init__(self, db: "_FakeFirestore", name: str) -> None:
        self._db = db
        self._name = name

    def document(self, document_id: str) -> _FakeDocumentReference:
        return _FakeDocumentReference(self._db, self._name, document_id)


class _FakeBatch:
    def __init__(self, db: "_FakeFirestore") -> None:
        self._db = db
        self._creates: list[tuple[_FakeDocumentReference, dict[str, Any]]] = []

    def create(
        self,
        reference: _FakeDocumentReference,
        value: dict[str, Any],
    ) -> None:
        self._creates.append((reference, copy.deepcopy(value)))

    def set(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("immutable fake does not support set")

    def update(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("immutable fake does not support update")

    def delete(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("immutable fake does not support delete")

    def commit(self) -> None:
        with self._db.lock:
            self._db.commit_count += 1
            if self._db.fail_before_commit:
                self._db.fail_before_commit = False
                raise RuntimeError("simulated commit failure with api_key=secret")
            if any(
                reference.key in self._db.documents for reference, _ in self._creates
            ):
                raise RuntimeError("create-only conflict")
            for reference, value in self._creates:
                self._db.documents[reference.key] = copy.deepcopy(value)
                self._db.create_count += 1
            if self._db.lose_commit_acknowledgement:
                self._db.lose_commit_acknowledgement = False
                if self._db.fail_reads_after_commit:
                    self._db.fail_reads = True
                raise RuntimeError("simulated lost acknowledgement")


class _FakeFirestore:
    def __init__(self) -> None:
        self.documents: dict[tuple[str, str], dict[str, Any]] = {}
        self.read_count = 0
        self.create_count = 0
        self.commit_count = 0
        self.fail_reads = False
        self.fail_reads_after_commit = False
        self.fail_before_commit = False
        self.lose_commit_acknowledgement = False
        self.lock = threading.RLock()

    def collection(self, name: str) -> _FakeCollectionReference:
        return _FakeCollectionReference(self, name)

    def batch(self) -> _FakeBatch:
        return _FakeBatch(self)


def _imported_modules(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
    return imported


def test_serialization_is_json_safe_detached_and_provider_neutral():
    event = _credit_event()
    serialized = serialize_ledger_event(event)

    assert serialized["event_type"] == "credit_reconciliation"
    assert isinstance(serialized["occurred_at"], str)
    assert serialized["najm_credit_amount"] == "2.5"
    assert serialized["credit_direction"] == "debit"
    assert serialized["provider_usage"]["input_tokens"] == 120
    assert serialized["provider_usage"]["reasoning_tokens"] == 5
    assert "provider_tokens" not in serialized

    serialized["policy_refs"]["budget"] = "mutated"
    assert event.policy_refs["budget"] == "budget-policy-v1"


def test_decimal_serialization_is_context_free_and_collision_resistant():
    first_amount = Decimal("12345678901234567890123456789.01")
    second_amount = Decimal("12345678901234567890123456789.02")

    first = serialize_ledger_event(_credit_event(najm_credit_amount=first_amount))
    second = serialize_ledger_event(_credit_event(najm_credit_amount=second_amount))

    assert first["najm_credit_amount"] == str(first_amount)
    assert second["najm_credit_amount"] == str(second_amount)
    assert first["najm_credit_amount"] != second["najm_credit_amount"]

    equivalent = serialize_ledger_event(
        _credit_event(najm_credit_amount=Decimal("1." + ("0" * 101)))
    )
    assert equivalent["najm_credit_amount"] == "1"

    oversized = InMemoryLedgerWriter(environment=ENVIRONMENT).append(
        _credit_event(najm_credit_amount=Decimal("1E+1000"))
    )
    assert oversized.status is LedgerWriteStatus.REJECTED


def test_internal_native_token_units_and_policy_refs_are_not_secret_channels():
    usage = ProviderUsage(
        certainty=ProviderUsageCertainty.KNOWN,
        input_tokens=1,
        additional_native_units={"audio_tokens": Decimal("2")},
    )
    serialized = serialize_ledger_event(
        _event(
            provider_usage=usage,
            policy_refs={"budget": "provider-budget-policy-v1"},
        )
    )

    assert serialized["provider_usage"]["additional_native_units"] == {
        "audio_tokens": "2"
    }
    assert serialized["policy_refs"]["budget"] == "provider-budget-policy-v1"


def test_writer_adds_recorded_time_and_self_contained_integrity_metadata():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT, clock=lambda: NOW)
    result = writer.append(_event())
    stored = writer.events[0]

    assert result.recorded_at == NOW
    assert result.integrity_hash == stored["integrity_hash"]
    assert stored["record_kind"] == "ai_usage_ledger_event"
    assert stored["recorded_at"] == "2026-07-16T08:00:00.000000Z"
    assert stored["environment"] == ENVIRONMENT
    assert len(stored["idempotency_scope_hash"]) == 64
    assert stored["integrity_algorithm"] == "sha256"
    assert len(stored["integrity_hash"]) == 64


@pytest.mark.parametrize(
    "forbidden_key",
    [
        "apiKey",
        "service_token",
        "firebaseToken",
        "payment_credentials",
        "roster_credentials",
        "prompt_body",
        "raw_provider_payload",
        "provider_tokens",
    ],
)
def test_safety_validation_rejects_sensitive_or_content_keys(forbidden_key: str):
    payload = serialize_ledger_event(_event())
    payload["unsafe"] = {forbidden_key: "must-not-be-persisted"}

    with pytest.raises(ValueError, match="forbidden ledger persistence key"):
        validate_ledger_event_safe_for_persistence(payload)


def test_safety_validation_allows_internal_provider_usage_facts_and_safe_refs():
    payload = serialize_ledger_event(_event())
    payload["provider_usage"]["input_tokens"] = 999
    payload["provider_response_ref"] = "opaque-provider-response-ref"

    validate_ledger_event_safe_for_persistence(payload)


@pytest.mark.parametrize(
    "changes",
    [
        {"source_ref": "https://example.invalid/path?token=secret"},
        {"policy_refs": {"safety": "Bearer raw-firebase-token"}},
        {"source_ref": "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signature"},
        {"source_ref": "sk-proj-secret-value"},
        {"reason_code": "sk-proj-secret-value"},
        {"task_type": "eyJhbGciOiJub25lIn0.payload.signature"},
        {"retention_class": "Bearer secret-retention-token"},
        {"policy_refs": {"oauth_token": "opaque-secret-value"}},
    ],
)
def test_writer_rejects_secret_bearing_reference_values(changes: dict[str, Any]):
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)

    result = writer.append(_event(**changes))

    assert result.status is LedgerWriteStatus.REJECTED
    assert result.error_code is AIPlatformErrorCode.INVALID_LEDGER_EVENT
    assert writer.events == ()


def test_rejected_result_never_echoes_sensitive_candidate_identifiers():
    event = _event(
        event_id="sk-proj-secret-event",
        idempotency_key="Bearer secret-idempotency",
        semantic_fingerprint="eyJhbGciOiJub25lIn0.payload.signature",
    )

    result = InMemoryLedgerWriter(environment=ENVIRONMENT).append(event)
    serialized_result = result.model_dump_json()

    assert result.status is LedgerWriteStatus.REJECTED
    assert "sk-proj-secret-event" not in serialized_result
    assert "secret-idempotency" not in serialized_result
    assert "eyJhbGciOiJub25lIn0" not in serialized_result


def test_adjustment_must_link_to_the_original_immutable_event():
    unlinked = _credit_event(
        event_type=LedgerEventType.ADJUSTMENT,
        reason_code="refund_adjustment",
        related_event_ids=(),
    )
    with pytest.raises(ValueError, match="requires a related event"):
        serialize_ledger_event(unlinked)

    linked = unlinked.model_copy(update={"related_event_ids": ("original-event-1",)})
    assert serialize_ledger_event(linked)["related_event_ids"] == ["original-event-1"]


def test_credit_effect_rejects_ambiguous_dual_funding_scope():
    dual_funded = _credit_event(credit_pool_id="credit-pool-1")

    result = InMemoryLedgerWriter(environment=ENVIRONMENT).append(dual_funded)

    assert result.status is LedgerWriteStatus.REJECTED
    assert result.error_code is AIPlatformErrorCode.INVALID_LEDGER_EVENT


def test_in_memory_writer_is_append_only_and_idempotent():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    event = _event()

    first = writer.append(event)
    replay = writer.append(event)

    assert first.status is LedgerWriteStatus.RECORDED
    assert replay.status is LedgerWriteStatus.ALREADY_RECORDED
    assert replay.canonical_event_id == event.event_id
    assert len(writer.events) == 1
    assert not hasattr(writer, "update")
    assert not hasattr(writer, "delete")
    assert not hasattr(writer, "upsert")


def test_in_memory_replay_can_use_new_candidate_event_id_but_not_new_semantics():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    original = _event()
    writer.append(original)

    replay = writer.append(_event(event_id="candidate-event-2"))
    conflict = writer.append(
        _event(event_id="candidate-event-3", reason_code="different_outcome")
    )

    assert replay.status is LedgerWriteStatus.ALREADY_RECORDED
    assert replay.canonical_event_id == original.event_id
    assert conflict.status is LedgerWriteStatus.CONFLICT
    assert conflict.error_code is AIPlatformErrorCode.IDEMPOTENCY_CONFLICT
    assert len(writer.events) == 1


def test_idempotency_fingerprint_normalizes_decimal_scale_and_mapping_order():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    original = _credit_event(
        policy_refs={"safety": "safety-policy-v1", "budget": "budget-policy-v1"}
    )
    writer.append(original)

    replay = writer.append(
        _credit_event(
            event_id="candidate-credit-event-2",
            najm_credit_amount=Decimal("2.5000"),
            policy_refs={"budget": "budget-policy-v1", "safety": "safety-policy-v1"},
        )
    )

    assert replay.status is LedgerWriteStatus.ALREADY_RECORDED
    assert replay.canonical_event_id == original.event_id
    assert len(writer.events) == 1


def test_idempotency_scope_allows_distinct_event_families_for_one_request_key():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT, clock=lambda: NOW)
    usage = _event()
    audit = _event(
        event_id="audit-event-1",
        event_type=LedgerEventType.AUDIT,
        source_ref="audit-decision-1",
        reason_code="observed",
        provider_usage=None,
    )

    usage_result = writer.append(usage)
    audit_result = writer.append(audit)

    assert usage_result.status is LedgerWriteStatus.RECORDED
    assert audit_result.status is LedgerWriteStatus.RECORDED
    assert len(writer.events) == 2


def test_same_boundary_key_rejects_changed_request_source_or_transaction():
    usage_writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    usage_writer.append(_event())
    changed_request = usage_writer.append(
        _event(
            event_id="usage-event-2",
            request_id="request-2",
            source_ref="orchestration-outcome-2",
        )
    )

    credit_writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    credit_writer.append(_credit_event())
    changed_transaction = credit_writer.append(
        _credit_event(
            event_id="credit-event-2",
            credit_transaction_ref="credit-transaction-2",
        )
    )

    assert changed_request.status is LedgerWriteStatus.CONFLICT
    assert changed_transaction.status is LedgerWriteStatus.CONFLICT
    assert len(usage_writer.events) == 1
    assert len(credit_writer.events) == 1


def test_idempotency_scope_isolates_tenants_and_conflicts_on_actor_change():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    first_principal = AIPrincipalRef(
        principal_id="user-1",
        authorization_ref="authorization-decision-1",
        tenant_id="tenant-1",
        organization_id="organization-shared",
    )
    second_actor = AIPrincipalRef(
        principal_id="user-2",
        authorization_ref="authorization-decision-2",
        tenant_id="tenant-1",
        organization_id="organization-shared",
    )
    second_tenant = AIPrincipalRef(
        principal_id="user-1",
        authorization_ref="authorization-decision-3",
        tenant_id="tenant-2",
        organization_id="organization-shared",
    )
    first = _event(principal=first_principal)
    actor_changed = _event(
        event_id="ledger-event-2",
        principal=second_actor,
        request_id="request-2",
    )
    tenant_changed = _event(
        event_id="ledger-event-3",
        principal=second_tenant,
        request_id="request-3",
    )

    assert writer.append(first).status is LedgerWriteStatus.RECORDED
    assert writer.append(actor_changed).status is LedgerWriteStatus.CONFLICT
    assert writer.append(tenant_changed).status is LedgerWriteStatus.RECORDED
    assert len(writer.events) == 2


def test_in_memory_snapshots_cannot_mutate_historical_events():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    event = _event()
    writer.append(event)

    external_snapshot = writer.events[0]
    external_snapshot["reason_code"] = "tampered"
    external_snapshot["policy_refs"]["budget"] = "tampered"

    stored = writer.get_event(event.event_id)
    assert stored is not None
    assert stored["reason_code"] == "completed"
    assert stored["policy_refs"]["budget"] == "budget-policy-v1"


def test_in_memory_concurrent_duplicate_intent_has_one_effect():
    writer = InMemoryLedgerWriter(environment=ENVIRONMENT)
    event = _event()

    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(writer.append, [event] * 16))

    assert sum(result.status is LedgerWriteStatus.RECORDED for result in results) == 1
    assert all(
        result.status
        in {LedgerWriteStatus.RECORDED, LedgerWriteStatus.ALREADY_RECORDED}
        for result in results
    )
    assert len(writer.events) == 1


def test_firestore_writer_is_inert_until_explicit_append():
    db = _FakeFirestore()
    factory_calls = 0

    def db_factory() -> _FakeFirestore:
        nonlocal factory_calls
        factory_calls += 1
        return db

    writer = FirestoreLedgerWriter(environment=ENVIRONMENT, db_factory=db_factory)
    assert factory_calls == 0
    assert db.documents == {}

    result = writer.append(_event())

    assert result.status is LedgerWriteStatus.RECORDED
    assert factory_calls == 1
    assert db.create_count == 2
    assert {collection for collection, _ in db.documents} == {
        PROPOSED_AI_USAGE_LEDGER_COLLECTION,
        PROPOSED_AI_IDEMPOTENCY_COLLECTION,
    }
    idempotency_record = next(
        value
        for (collection, _), value in db.documents.items()
        if collection == PROPOSED_AI_IDEMPOTENCY_COLLECTION
    )
    assert idempotency_record["environment"] == ENVIRONMENT
    assert idempotency_record["recorded_at"].endswith("Z")
    assert idempotency_record["retention_class"] == "internal_alpha_observability"


def test_firestore_event_identity_is_isolated_by_environment():
    db = _FakeFirestore()
    test_result = FirestoreLedgerWriter(environment="test", db=db).append(_event())
    production_result = FirestoreLedgerWriter(environment="production", db=db).append(
        _event()
    )

    assert test_result.status is LedgerWriteStatus.RECORDED
    assert production_result.status is LedgerWriteStatus.RECORDED
    assert db.create_count == 4
    assert len(db.documents) == 4


def test_firestore_writer_replays_and_conflicts_without_overwrite():
    db = _FakeFirestore()
    writer = FirestoreLedgerWriter(environment=ENVIRONMENT, db=db)
    original = _event()
    first = writer.append(original)
    original_documents = copy.deepcopy(db.documents)

    replay = writer.append(original)
    conflict = writer.append(_event(reason_code="changed_outcome"))
    duplicate_event_id = writer.append(
        _event(
            idempotency_key="another-idempotency-key",
            semantic_fingerprint="another-semantic-fingerprint",
        )
    )

    assert first.status is LedgerWriteStatus.RECORDED
    assert replay.status is LedgerWriteStatus.ALREADY_RECORDED
    assert conflict.status is LedgerWriteStatus.CONFLICT
    assert duplicate_event_id.status is LedgerWriteStatus.CONFLICT
    assert db.documents == original_documents
    assert db.create_count == 2
    assert db.commit_count == 1


def test_firestore_concurrent_duplicate_intent_has_one_atomic_effect():
    db = _FakeFirestore()
    writer = FirestoreLedgerWriter(
        environment=ENVIRONMENT,
        db=db,
        clock=lambda: NOW,
    )
    event = _event()

    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(writer.append, [event] * 16))

    assert sum(result.status is LedgerWriteStatus.RECORDED for result in results) == 1
    assert all(
        result.status
        in {LedgerWriteStatus.RECORDED, LedgerWriteStatus.ALREADY_RECORDED}
        for result in results
    )
    assert db.create_count == 2
    assert len(db.documents) == 2


def test_firestore_replay_rejects_tampered_or_unknown_stored_fields():
    db = _FakeFirestore()
    writer = FirestoreLedgerWriter(
        environment=ENVIRONMENT,
        db=db,
        clock=lambda: NOW,
    )
    event = _event()
    writer.append(event)
    event_key = next(
        key for key in db.documents if key[0] == PROPOSED_AI_USAGE_LEDGER_COLLECTION
    )
    db.documents[event_key]["notes"] = "unapproved content channel"

    result = writer.append(event)

    assert result.status is LedgerWriteStatus.FAILED
    assert result.error_code is AIPlatformErrorCode.LEDGER_UNAVAILABLE
    assert db.create_count == 2


def test_firestore_untyped_commit_failure_is_unknown_and_redacted():
    db = _FakeFirestore()
    db.fail_before_commit = True
    result = FirestoreLedgerWriter(environment=ENVIRONMENT, db=db).append(_event())

    assert result.status is LedgerWriteStatus.OUTCOME_UNKNOWN
    assert result.error_code is AIPlatformErrorCode.LEDGER_UNAVAILABLE
    assert "secret" not in result.model_dump_json()
    assert db.documents == {}


def test_firestore_lost_acknowledgement_resolves_from_immutable_records():
    db = _FakeFirestore()
    db.lose_commit_acknowledgement = True
    result = FirestoreLedgerWriter(environment=ENVIRONMENT, db=db).append(_event())

    assert result.status is LedgerWriteStatus.ALREADY_RECORDED
    assert result.canonical_event_id == "ledger-event-1"
    assert db.create_count == 2


def test_firestore_ambiguous_commit_is_explicit_and_replay_remains_safe():
    db = _FakeFirestore()
    db.lose_commit_acknowledgement = True
    db.fail_reads_after_commit = True
    writer = FirestoreLedgerWriter(environment=ENVIRONMENT, db=db)

    unresolved = writer.append(_event())
    assert unresolved.status is LedgerWriteStatus.OUTCOME_UNKNOWN
    assert unresolved.error_code is AIPlatformErrorCode.LEDGER_UNAVAILABLE
    assert db.create_count == 2

    db.fail_reads = False
    replay = writer.append(_event())
    assert replay.status is LedgerWriteStatus.ALREADY_RECORDED
    assert db.create_count == 2


def test_firestore_read_failure_is_explicit_and_does_not_write():
    db = _FakeFirestore()
    db.fail_reads = True
    result = FirestoreLedgerWriter(environment=ENVIRONMENT, db=db).append(_event())

    assert result.status is LedgerWriteStatus.FAILED
    assert result.error_code is AIPlatformErrorCode.LEDGER_UNAVAILABLE
    assert db.create_count == 0


def test_ledger_writer_public_contract_has_no_mutation_or_policy_methods():
    assert inspect.isabstract(LedgerWriter)
    public_members = {
        name for name, _ in inspect.getmembers(LedgerWriter) if not name.startswith("_")
    }
    assert public_members == {"append"}


def test_ledger_write_status_values_are_stable():
    assert [status.value for status in LedgerWriteStatus] == [
        "recorded",
        "already_recorded",
        "conflict",
        "failed",
        "outcome_unknown",
        "rejected",
    ]


def test_ai_platform_has_no_provider_sdk_imports_after_ledger_addition():
    prohibited_roots = {
        "anthropic",
        "openai",
        "google",
        "zhipuai",
        "dashscope",
        "httpx",
        "requests",
        "firebase_admin",
    }
    violations: dict[str, list[str]] = {}
    for path in sorted(AI_PLATFORM_PACKAGE.rglob("*.py")):
        blocked = sorted(
            module
            for module in _imported_modules(path)
            if module.split(".", maxsplit=1)[0] in prohibited_roots
        )
        if blocked:
            violations[path.name] = blocked
    assert violations == {}


def test_firestore_dependency_is_not_imported_at_module_scope():
    tree = ast.parse(
        (AI_PLATFORM_PACKAGE / "ledger.py").read_text(encoding="utf-8")
    )
    top_level_imports = {
        node.module
        for node in tree.body
        if isinstance(node, ast.ImportFrom) and node.module is not None
    }
    assert "utils.firebase" not in top_level_imports
