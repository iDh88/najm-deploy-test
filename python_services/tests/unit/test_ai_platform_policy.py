"""Tests for inert, deny-dominant AI Platform policy scaffolding."""

from __future__ import annotations

import ast
import copy
import inspect
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pytest

from ai_platform.contracts import (
    AISafetyDecision,
    AISafetyLevel,
    BudgetDecisionRef,
    BudgetDecisionResult,
    EntitlementDecisionRef,
    FeatureFlagDecisionRef,
    ModelLifecycleState,
    ModelRegistryRef,
    PromptLifecycleState,
    PromptRegistryRef,
    ProviderCapability,
    ProviderLifecycleState,
    ProviderRegistryRef,
    SafetyDecisionRef,
)
from ai_platform.policy import (
    BudgetDecisionReader,
    EntitlementReader,
    FeatureFlagReader,
    FirestoreBudgetDecisionReader,
    FirestoreEntitlementReader,
    FirestoreFeatureFlagReader,
    FirestoreSafetyDecisionReader,
    InMemoryBudgetDecisionReader,
    InMemoryEntitlementReader,
    InMemoryFeatureFlagReader,
    InMemorySafetyDecisionReader,
    KillSwitchDecisionRef,
    KillSwitchDisposition,
    PolicyDecisionStatus,
    PolicyReadStatus,
    SafetyDecisionReader,
    build_policy_snapshot,
    compose_ai_policy_decision,
)
from ai_platform.registry import RegistryLookupStatus, RegistryRouteValidationResult


NOW = datetime(2026, 7, 16, 8, 0, tzinfo=timezone.utc)
LATER = NOW + timedelta(minutes=5)
PYTHON_SERVICES = Path(__file__).resolve().parents[2]
AI_PLATFORM_PACKAGE = PYTHON_SERVICES / "ai_platform"


def _feature(*, allowed: bool = True, reason: str = "feature_allowed"):
    return FeatureFlagDecisionRef(
        evaluation_id="feature-eval-1",
        flag_key="ai.assistant",
        feature_key="ai.assistant",
        flag_version="feature-v1",
        allowed=allowed,
        reason_code=reason,
        source_ref="feature-policy-v1",
        evaluated_at=NOW,
    )


def _entitlement(*, allowed: bool = True, reason: str = "entitlement_allowed"):
    return EntitlementDecisionRef(
        decision_id="entitlement-1",
        feature_key="ai.assistant",
        policy_version="entitlement-v1",
        allowed=allowed,
        reason_code=reason,
        evaluated_at=NOW,
        source_ref="entitlement-source-1",
    )


def _safety(
    *,
    decision: AISafetyDecision = AISafetyDecision.ALLOWED,
    reasons: tuple[str, ...] = ("safety_allowed",),
):
    return SafetyDecisionRef(
        decision_id="safety-1",
        feature_key="ai.assistant",
        policy_version="safety-v1",
        level=AISafetyLevel.GENERAL_ASSISTANCE,
        decision=decision,
        evaluated_at=NOW,
        reason_codes=reasons,
    )


def _budget(*, result: BudgetDecisionResult = BudgetDecisionResult.ALLOW):
    return BudgetDecisionRef(
        decision_id="budget-1",
        request_id="request-1",
        feature_key="ai.assistant",
        policy_version="budget-v1",
        result=result,
        evaluated_at=NOW,
        expires_at=LATER,
        reason_codes=(
            "budget_allowed"
            if result is not BudgetDecisionResult.DENY
            else "cap_reached",
        ),
    )


def _kill_switch(
    disposition: KillSwitchDisposition,
    *,
    valid_until: datetime | None = LATER,
):
    return KillSwitchDecisionRef(
        evaluation_id="kill-switch-eval-1",
        switch_key="ai.global",
        switch_version="kill-switch-v1",
        disposition=disposition,
        reason_code=f"incident_{disposition.value}",
        source_ref="incident-policy-1",
        evaluated_at=NOW,
        valid_until=valid_until,
    )


def _registry_route(
    status: RegistryLookupStatus = RegistryLookupStatus.FOUND,
) -> RegistryRouteValidationResult:
    if status is not RegistryLookupStatus.FOUND:
        return RegistryRouteValidationResult(
            status=status,
            references_valid=False,
            reason_codes=("route_not_available",),
        )
    provider = ProviderRegistryRef(
        provider_key="provider.primary",
        registry_revision="provider-rev-1",
        adapter_key="adapter.primary",
        adapter_contract_version="1",
        lifecycle=ProviderLifecycleState.ENABLED,
    )
    model = ModelRegistryRef(
        model_key="model.general",
        model_revision="model-rev-1",
        provider_key="provider.primary",
        lifecycle=ModelLifecycleState.ENABLED,
        capabilities={ProviderCapability.TEXT_GENERATION},
    )
    prompt = PromptRegistryRef(
        prompt_family_key="assistant.general",
        prompt_version="prompt-v1",
        registry_revision="prompt-rev-1",
        content_hash="sha256-prompt-1",
        lifecycle=PromptLifecycleState.ACTIVE,
    )
    return RegistryRouteValidationResult(
        status=RegistryLookupStatus.FOUND,
        references_valid=True,
        activation_authorization_ref="route-activation-v1",
        provider=provider,
        model=model,
        prompt=prompt,
        required_capability=ProviderCapability.TEXT_GENERATION,
        reason_codes=("registry_route_refs_valid",),
    )


def _compose(**changes: Any):
    values: dict[str, Any] = {
        "request_id": "request-1",
        "feature_key": "ai.assistant",
        "evaluated_at": NOW,
        "feature_flag": _feature(),
        "entitlement": _entitlement(),
        "safety": _safety(),
        "budget": _budget(),
        "kill_switch": _kill_switch(KillSwitchDisposition.CLEAR),
        "registry_route": _registry_route(),
    }
    values.update(changes)
    return compose_ai_policy_decision(**values)


def test_all_mandatory_allows_produce_provider_allow():
    result = _compose()

    assert result.status is PolicyDecisionStatus.ALLOW
    assert result.provider_execution_allowed is True
    assert result.entitlement_allowed is True


def test_feature_and_entitlement_denials_are_separate_and_deny_dominant():
    feature_denied = _compose(feature_flag=_feature(allowed=False))
    entitlement_denied = _compose(entitlement=_entitlement(allowed=False))

    assert feature_denied.status is PolicyDecisionStatus.DENY
    assert feature_denied.entitlement_allowed is True
    assert feature_denied.reason_codes[0] == "feature_disabled"
    assert entitlement_denied.status is PolicyDecisionStatus.DENY
    assert entitlement_denied.entitlement_allowed is False
    assert entitlement_denied.reason_codes[0] == "entitlement_denied"


def test_safety_deny_dominates_every_other_allow_or_deny():
    result = _compose(
        feature_flag=_feature(allowed=False),
        entitlement=_entitlement(allowed=False),
        safety=_safety(decision=AISafetyDecision.REFUSED, reasons=("unsafe",)),
        budget=_budget(result=BudgetDecisionResult.DENY),
        kill_switch=_kill_switch(KillSwitchDisposition.DENY),
    )

    assert result.status is PolicyDecisionStatus.DENY
    assert result.provider_execution_allowed is False
    assert result.reason_codes[0] == "safety_denied"


@pytest.mark.parametrize(
    ("disposition", "expected", "may_execute"),
    [
        (KillSwitchDisposition.DENY, PolicyDecisionStatus.DENY, False),
        (
            KillSwitchDisposition.DETERMINISTIC_ONLY,
            PolicyDecisionStatus.DETERMINISTIC_ONLY,
            False,
        ),
        (KillSwitchDisposition.DEGRADED, PolicyDecisionStatus.DEGRADED, False),
        (KillSwitchDisposition.UNAVAILABLE, PolicyDecisionStatus.UNAVAILABLE, False),
    ],
)
def test_server_kill_switch_has_explicit_deny_or_degrade_semantics(
    disposition, expected, may_execute
):
    result = _compose(kill_switch=_kill_switch(disposition))

    assert result.status is expected
    assert result.provider_execution_allowed is may_execute


def test_budget_deny_blocks_execution_without_revoking_entitlement():
    result = _compose(budget=_budget(result=BudgetDecisionResult.DENY))

    assert result.status is PolicyDecisionStatus.DENY
    assert result.provider_execution_allowed is False
    assert result.entitlement_allowed is True
    assert result.reason_codes[0] == "budget_denied"


def test_expired_or_wrong_request_authorization_cannot_allow_execution():
    expired_entitlement = EntitlementDecisionRef.model_validate(
        {**_entitlement().model_dump(), "valid_until": NOW}
    )
    expired_budget = BudgetDecisionRef.model_validate(
        {**_budget().model_dump(), "expires_at": NOW}
    )
    wrong_request_budget = BudgetDecisionRef.model_validate(
        {**_budget().model_dump(), "request_id": "request-other"}
    )
    expired_kill_switch = _kill_switch(
        KillSwitchDisposition.CLEAR,
        valid_until=NOW,
    )

    entitlement_result = _compose(entitlement=expired_entitlement)
    budget_result = _compose(budget=expired_budget)
    request_result = _compose(budget=wrong_request_budget)
    kill_switch_result = _compose(kill_switch=expired_kill_switch)

    assert entitlement_result.status is PolicyDecisionStatus.DENY
    assert entitlement_result.entitlement_allowed is False
    assert entitlement_result.reason_codes == ("entitlement_expired",)
    assert budget_result.status is PolicyDecisionStatus.UNAVAILABLE
    assert budget_result.reason_codes == ("budget_decision_expired",)
    assert request_result.status is PolicyDecisionStatus.UNAVAILABLE
    assert request_result.reason_codes == ("budget_request_mismatch",)
    assert kill_switch_result.status is PolicyDecisionStatus.UNAVAILABLE
    assert kill_switch_result.reason_codes == ("kill_switch_decision_expired",)


def test_policy_decisions_are_bound_to_the_requested_feature():
    other_feature = FeatureFlagDecisionRef.model_validate(
        {**_feature().model_dump(), "feature_key": "ai.other"}
    )

    result = _compose(feature_flag=other_feature)

    assert result.status is PolicyDecisionStatus.UNAVAILABLE
    assert result.provider_execution_allowed is False
    assert result.reason_codes == ("policy_feature_scope_mismatch",)


@pytest.mark.parametrize(
    "registry_status",
    [
        RegistryLookupStatus.MISSING,
        RegistryLookupStatus.INELIGIBLE,
        RegistryLookupStatus.UNAVAILABLE,
        RegistryLookupStatus.INVALID,
    ],
)
def test_registry_unavailability_is_execution_unavailable_not_entitlement_denied(
    registry_status,
):
    result = _compose(
        registry_route=_registry_route(registry_status),
    )

    assert result.status is PolicyDecisionStatus.UNAVAILABLE
    assert result.provider_execution_allowed is False
    assert result.entitlement_allowed is True
    assert result.reason_codes == ("route_not_available",)


@pytest.mark.parametrize(
    "missing",
    [
        "feature_flag",
        "entitlement",
        "safety",
        "budget",
        "kill_switch",
        "registry_route",
    ],
)
def test_missing_mandatory_policy_is_safe_unavailable(missing):
    result = _compose(**{missing: None})

    assert result.status is PolicyDecisionStatus.UNAVAILABLE
    assert result.provider_execution_allowed is False
    assert any("policy_missing" in reason for reason in result.reason_codes)


@pytest.mark.parametrize(
    ("decision", "expected", "may_execute"),
    [
        (AISafetyDecision.DETERMINISTIC_ONLY, PolicyDecisionStatus.DETERMINISTIC_ONLY, False),
        (AISafetyDecision.DEGRADED, PolicyDecisionStatus.DEGRADED, False),
        (AISafetyDecision.UNAVAILABLE, PolicyDecisionStatus.UNAVAILABLE, False),
    ],
)
def test_safety_response_modes_remain_explicit(decision, expected, may_execute):
    result = _compose(safety=_safety(decision=decision))

    assert result.status is expected
    assert result.provider_execution_allowed is may_execute


def test_deterministic_only_mode_does_not_depend_on_provider_budget_or_registry():
    result = _compose(
        safety=_safety(decision=AISafetyDecision.DETERMINISTIC_ONLY),
        budget=None,
        registry_route=None,
    )
    budget_denied = _compose(
        safety=_safety(decision=AISafetyDecision.DETERMINISTIC_ONLY),
        budget=_budget(result=BudgetDecisionResult.DENY),
    )

    assert result.status is PolicyDecisionStatus.DETERMINISTIC_ONLY
    assert budget_denied.status is PolicyDecisionStatus.DETERMINISTIC_ONLY
    assert not result.provider_execution_allowed
    assert not budget_denied.provider_execution_allowed


def test_policy_snapshot_contains_provenance_and_no_secret_channels():
    snapshot = build_policy_snapshot(
        request_id="request-1",
        feature_key="ai.assistant",
        evaluated_at=NOW,
        feature_flag=_feature(),
        entitlement=_entitlement(),
        safety=_safety(),
        budget=_budget(),
        kill_switch=_kill_switch(KillSwitchDisposition.CLEAR),
        registry_route=_registry_route(),
    )
    payload = snapshot.model_dump(mode="json")
    serialized = snapshot.model_dump_json().lower()

    assert payload["feature_flag"]["evaluation_id"] == "feature-eval-1"
    assert payload["feature_flag"]["flag_version"] == "feature-v1"
    assert payload["entitlement"]["decision_id"] == "entitlement-1"
    assert payload["safety"]["policy_version"] == "safety-v1"
    assert payload["budget"]["reason_codes"] == ["budget_allowed"]
    assert payload["kill_switch"]["switch_version"] == "kill-switch-v1"
    assert payload["registry_route"]["provider"]["registry_revision"] == (
        "provider-rev-1"
    )
    for forbidden in (
        "api_key",
        "service_token",
        "firebase_token",
        "payment_credential",
        "roster_credential",
        "prompt_body",
        "provider_payload",
    ):
        assert forbidden not in serialized


@pytest.mark.parametrize(
    ("reader", "decision_id"),
    [
        (InMemoryFeatureFlagReader([_feature()]), "feature-eval-1"),
        (InMemoryEntitlementReader([_entitlement()]), "entitlement-1"),
        (InMemoryBudgetDecisionReader([_budget()]), "budget-1"),
        (InMemorySafetyDecisionReader([_safety()]), "safety-1"),
    ],
)
def test_in_memory_policy_readers_are_deterministic(reader, decision_id):
    first = reader.read(decision_id)
    second = reader.read(decision_id)

    assert first == second
    assert first.status is PolicyReadStatus.FOUND
    assert first.decision is not None


def test_in_memory_policy_reader_missing_is_explicit():
    result = InMemoryEntitlementReader().read("entitlement-missing")

    assert result.status is PolicyReadStatus.MISSING
    assert result.decision is None


def test_in_memory_policy_reader_returns_detached_decision_snapshots():
    entitlement = EntitlementDecisionRef.model_validate(
        {**_entitlement().model_dump(), "limits": {"daily_queries": 5}}
    )
    reader = InMemoryEntitlementReader([entitlement])
    first = reader.read("entitlement-1")
    assert isinstance(first.decision, EntitlementDecisionRef)
    first.decision.limits["daily_queries"] = 999

    second = reader.read("entitlement-1")

    assert isinstance(second.decision, EntitlementDecisionRef)
    assert second.decision.limits["daily_queries"] == 5


class _FakeSnapshot:
    def __init__(self, value: dict[str, Any] | None):
        self.exists = value is not None
        self._value = copy.deepcopy(value)

    def to_dict(self):
        return copy.deepcopy(self._value)


class _FakeDocument:
    def __init__(self, db: "_StrictReadOnlyFake", collection: str, doc_id: str):
        self._db = db
        self._key = (collection, doc_id)

    def get(self):
        self._db.reads.append(self._key)
        if self._db.fail_reads:
            raise RuntimeError("simulated backend failure with api_key=redacted")
        return _FakeSnapshot(self._db.documents.get(self._key))

    def set(self, *_args: Any, **_kwargs: Any):
        raise AssertionError("policy reader must not write")

    update = set
    delete = set


class _FakeCollection:
    def __init__(self, db: "_StrictReadOnlyFake", name: str):
        self._db = db
        self._name = name

    def document(self, doc_id: str):
        return _FakeDocument(self._db, self._name, doc_id)

    def stream(self):
        raise AssertionError("policy reader must not scan")


class _StrictReadOnlyFake:
    def __init__(self, documents: dict[tuple[str, str], dict[str, Any]]):
        self.documents = copy.deepcopy(documents)
        self.reads: list[tuple[str, str]] = []
        self.fail_reads = False

    def collection(self, name: str):
        return _FakeCollection(self, name)


def _policy_doc_id(decision_id: str) -> str:
    return f"unit-{decision_id}"


def _exact_policy_projector(raw, model_type):
    return model_type.model_validate(raw).model_dump(mode="json")


@pytest.mark.parametrize(
    ("reader_type", "collection", "decision", "decision_id"),
    [
        (
            FirestoreFeatureFlagReader,
            "unitFeatureDecisions",
            _feature(),
            "feature-eval-1",
        ),
        (
            FirestoreEntitlementReader,
            "unitEntitlementDecisions",
            _entitlement(),
            "entitlement-1",
        ),
        (
            FirestoreBudgetDecisionReader,
            "aiBudgetDecisions",
            _budget(),
            "budget-1",
        ),
        (
            FirestoreSafetyDecisionReader,
            "aiSafetyDecisions",
            _safety(),
            "safety-1",
        ),
    ],
)
def test_firestore_policy_readers_are_lazy_fakeable_and_read_only(
    reader_type, collection, decision, decision_id
):
    factory_calls = 0
    db = _StrictReadOnlyFake(
        {
            (collection, _policy_doc_id(decision_id)): decision.model_dump(
                mode="json"
            )
        }
    )

    def factory():
        nonlocal factory_calls
        factory_calls += 1
        return db

    reader = reader_type(
        db_factory=factory,
        collection_name=collection,
        document_id_resolver=_policy_doc_id,
        record_projector=_exact_policy_projector,
    )
    assert factory_calls == 0
    assert db.reads == []

    result = reader.read(decision_id)

    assert result.status is PolicyReadStatus.FOUND
    assert factory_calls == 1
    assert len(db.reads) == 1
    assert result.decision == decision


def test_firestore_policy_failure_is_explicit_redacted_and_not_fail_open():
    db = _StrictReadOnlyFake({})
    reader = FirestoreSafetyDecisionReader(
        db=db,
        collection_name="aiSafetyDecisions",
        document_id_resolver=_policy_doc_id,
        record_projector=_exact_policy_projector,
    )
    missing = reader.read("safety-1")
    db.fail_reads = True
    unavailable = reader.read("safety-1")

    assert missing.status is PolicyReadStatus.MISSING
    assert unavailable.status is PolicyReadStatus.UNAVAILABLE
    assert unavailable.decision is None
    assert "api_key" not in unavailable.model_dump_json()


def test_firestore_policy_requires_an_explicit_storage_projector():
    record = _safety().model_dump(mode="json")
    record["raw_provider_payload"] = "must-not-be-projected"
    db = _StrictReadOnlyFake(
        {("aiSafetyDecisions", _policy_doc_id("safety-1")): record}
    )
    no_projector = FirestoreSafetyDecisionReader(
        db=db,
        collection_name="aiSafetyDecisions",
        document_id_resolver=_policy_doc_id,
    ).read("safety-1")
    strict_projector = FirestoreSafetyDecisionReader(
        db=db,
        collection_name="aiSafetyDecisions",
        document_id_resolver=_policy_doc_id,
        record_projector=_exact_policy_projector,
    ).read("safety-1")

    assert no_projector.status is PolicyReadStatus.UNAVAILABLE
    assert strict_projector.status is PolicyReadStatus.INVALID


def _imported_modules(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
    return imported


def test_policy_interfaces_are_abstract_and_module_has_no_external_client_imports():
    for reader_type in (
        FeatureFlagReader,
        EntitlementReader,
        BudgetDecisionReader,
        SafetyDecisionReader,
    ):
        assert inspect.isabstract(reader_type)
        public = {
            name
            for name, _ in inspect.getmembers(reader_type)
            if not name.startswith("_")
        }
        assert public == {"read"}

    imported = _imported_modules(AI_PLATFORM_PACKAGE / "policy.py")
    prohibited = {
        "anthropic",
        "openai",
        "google",
        "zhipuai",
        "dashscope",
        "httpx",
        "requests",
        "firebase_admin",
        "utils.firebase",
    }
    assert not {
        module
        for module in imported
        if module.split(".")[0] in prohibited or module in prohibited
    }
