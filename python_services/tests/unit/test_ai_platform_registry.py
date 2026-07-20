"""Tests for inert NAJM AI Platform registry-reference readers."""

from __future__ import annotations

import ast
import copy
import inspect
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

from ai_platform.contracts import (
    ModelLifecycleState,
    ModelRegistryRef,
    PromptLifecycleState,
    PromptRegistryRef,
    ProviderCapability,
    ProviderLifecycleState,
    ProviderRegistryRef,
)
from ai_platform.registry import (
    FirestoreModelRegistryReader,
    FirestorePromptRegistryReader,
    FirestoreProviderRegistryReader,
    InMemoryModelRegistry,
    InMemoryPromptRegistry,
    InMemoryProviderRegistry,
    ModelRegistryReader,
    PromptRegistryReader,
    ProviderRegistryReader,
    RegistryLookupStatus,
    validate_route_registry_refs,
)


PYTHON_SERVICES = Path(__file__).resolve().parents[2]
AI_PLATFORM_PACKAGE = PYTHON_SERVICES / "ai_platform"


def _provider(
    *, lifecycle: ProviderLifecycleState | None = ProviderLifecycleState.ENABLED
) -> ProviderRegistryRef:
    return ProviderRegistryRef(
        provider_key="provider.primary",
        registry_revision="provider-rev-1",
        adapter_key="adapter.primary",
        adapter_contract_version="1",
        lifecycle=lifecycle,
    )


def _model(
    *,
    lifecycle: ModelLifecycleState = ModelLifecycleState.ENABLED,
    authorization: str | None = None,
    provider_key: str = "provider.primary",
) -> ModelRegistryRef:
    return ModelRegistryRef(
        model_key="model.general",
        model_revision="model-rev-1",
        provider_key=provider_key,
        lifecycle=lifecycle,
        capabilities={ProviderCapability.TEXT_GENERATION},
        compatibility_authorization_ref=authorization,
    )


def _prompt(
    *, lifecycle: PromptLifecycleState = PromptLifecycleState.ACTIVE
) -> PromptRegistryRef:
    return PromptRegistryRef(
        prompt_family_key="assistant.general",
        prompt_version="prompt-v1",
        registry_revision="prompt-rev-1",
        content_hash="sha256-prompt-1",
        lifecycle=lifecycle,
    )


@pytest.mark.parametrize(
    ("reader", "args", "entry"),
    [
        (
            InMemoryProviderRegistry([_provider()]),
            ("provider.primary", "provider-rev-1"),
            _provider(),
        ),
        (
            InMemoryModelRegistry([_model()]),
            ("model.general", "model-rev-1"),
            _model(),
        ),
        (
            InMemoryPromptRegistry([_prompt()]),
            ("assistant.general", "prompt-v1", "prompt-rev-1"),
            _prompt(),
        ),
    ],
)
def test_in_memory_exact_lookups_are_deterministic(reader, args, entry):
    first = reader.lookup(*args)
    second = reader.lookup(*args)

    assert first == second
    assert first.status is RegistryLookupStatus.FOUND
    assert first.reference_eligible is True
    assert first.entry == entry


@pytest.mark.parametrize(
    ("reader", "args"),
    [
        (InMemoryProviderRegistry(), ("provider.missing", "provider-rev-missing")),
        (InMemoryModelRegistry(), ("model.missing", "model-rev-missing")),
        (
            InMemoryPromptRegistry(),
            ("prompt.missing", "prompt-v-missing", "prompt-rev-missing"),
        ),
    ],
)
def test_missing_registry_refs_return_explicit_missing(reader, args):
    result = reader.lookup(*args)

    assert result.status is RegistryLookupStatus.MISSING
    assert result.reference_eligible is False
    assert result.entry is None


@pytest.mark.parametrize(
    ("reader", "args"),
    [
        (
            InMemoryProviderRegistry(
                [_provider(lifecycle=ProviderLifecycleState.SUSPENDED)]
            ),
            ("provider.primary", "provider-rev-1"),
        ),
        (
            InMemoryModelRegistry(
                [_model(lifecycle=ModelLifecycleState.RETIRED)]
            ),
            ("model.general", "model-rev-1"),
        ),
        (
            InMemoryPromptRegistry(
                [_prompt(lifecycle=PromptLifecycleState.SUSPENDED)]
            ),
            ("assistant.general", "prompt-v1", "prompt-rev-1"),
        ),
    ],
)
def test_suspended_or_retired_entries_are_not_executable(reader, args):
    result = reader.lookup(*args)

    assert result.status is RegistryLookupStatus.INELIGIBLE
    assert result.reference_eligible is False
    assert result.entry is not None


def test_deprecated_model_requires_explicit_compatibility_authorization():
    denied = InMemoryModelRegistry(
        [_model(lifecycle=ModelLifecycleState.DEPRECATED)]
    ).lookup("model.general", "model-rev-1")
    allowed = InMemoryModelRegistry(
        [
            _model(
                lifecycle=ModelLifecycleState.DEPRECATED,
                authorization="compatibility-policy-v1",
            )
        ],
        compatibility_authorizer=lambda entry: (
            entry.compatibility_authorization_ref == "compatibility-policy-v1"
        ),
    ).lookup("model.general", "model-rev-1")

    assert denied.status is RegistryLookupStatus.INELIGIBLE
    assert allowed.status is RegistryLookupStatus.FOUND
    assert "compatibility" in allowed.reason_code


def test_registry_route_validation_requires_complete_eligible_refs():
    valid = validate_route_registry_refs(
        provider=_provider(),
        model=_model(),
        prompt=_prompt(),
        required_capability=ProviderCapability.TEXT_GENERATION,
        activation_authorization_ref="route-activation-v1",
    )
    missing = validate_route_registry_refs(
        provider=_provider(),
        model=_model(),
        prompt=None,
        required_capability=ProviderCapability.TEXT_GENERATION,
        activation_authorization_ref="route-activation-v1",
    )
    mismatched = validate_route_registry_refs(
        provider=_provider(),
        model=_model(provider_key="provider.other"),
        prompt=_prompt(),
        required_capability=ProviderCapability.TEXT_GENERATION,
        activation_authorization_ref="route-activation-v1",
    )
    unsupported = validate_route_registry_refs(
        provider=_provider(),
        model=_model(),
        prompt=_prompt(),
        required_capability=ProviderCapability.TOOL_CALLING,
        activation_authorization_ref="route-activation-v1",
    )
    inactive = validate_route_registry_refs(
        provider=_provider(),
        model=_model(),
        prompt=_prompt(),
        required_capability=ProviderCapability.TEXT_GENERATION,
        activation_authorization_ref=None,
    )

    assert valid.status is RegistryLookupStatus.FOUND
    assert valid.references_valid is True
    assert missing.status is RegistryLookupStatus.MISSING
    assert mismatched.status is RegistryLookupStatus.INVALID
    assert unsupported.status is RegistryLookupStatus.INVALID
    assert inactive.status is RegistryLookupStatus.MISSING
    assert (
        not missing.references_valid
        and not mismatched.references_valid
        and not unsupported.references_valid
        and not inactive.references_valid
    )


def test_prompt_lookup_identity_includes_prompt_version():
    reader = InMemoryPromptRegistry([_prompt()])

    found = reader.lookup("assistant.general", "prompt-v1", "prompt-rev-1")
    wrong_version = reader.lookup(
        "assistant.general", "prompt-v2", "prompt-rev-1"
    )

    assert found.status is RegistryLookupStatus.FOUND
    assert wrong_version.status is RegistryLookupStatus.MISSING


def test_embedding_registry_validation_does_not_invent_a_prompt_requirement():
    model = ModelRegistryRef(
        model_key="model.embedding",
        model_revision="embedding-rev-1",
        provider_key="provider.primary",
        lifecycle=ModelLifecycleState.ENABLED,
        capabilities={ProviderCapability.EMBEDDINGS},
    )
    result = validate_route_registry_refs(
        provider=_provider(),
        model=model,
        prompt=None,
        required_capability=ProviderCapability.EMBEDDINGS,
        activation_authorization_ref="route-activation-embedding-v1",
    )

    assert result.status is RegistryLookupStatus.FOUND
    assert result.references_valid is True
    assert result.prompt is None


def test_prompt_reader_exposes_reference_metadata_not_prompt_body_execution():
    result = InMemoryPromptRegistry([_prompt()]).lookup(
        "assistant.general", "prompt-v1", "prompt-rev-1"
    )
    serialized = result.model_dump(mode="json")

    assert result.status is RegistryLookupStatus.FOUND
    assert "prompt_body" not in str(serialized)
    assert "execute" not in PromptRegistryReader.__dict__
    assert "render" not in PromptRegistryReader.__dict__


class _FakeSnapshot:
    def __init__(self, value: dict[str, Any] | None) -> None:
        self.exists = value is not None
        self._value = copy.deepcopy(value)

    def to_dict(self) -> dict[str, Any] | None:
        return copy.deepcopy(self._value)


class _FakeDocument:
    def __init__(self, db: "_StrictReadOnlyFake", collection: str, doc_id: str):
        self._db = db
        self._key = (collection, doc_id)

    def get(self) -> _FakeSnapshot:
        self._db.reads.append(self._key)
        if self._db.fail_reads:
            raise RuntimeError("simulated read failure with service_token=redacted")
        return _FakeSnapshot(self._db.documents.get(self._key))

    def set(self, *_args: Any, **_kwargs: Any) -> None:
        raise AssertionError("registry reader must not write")

    update = set
    delete = set


class _FakeCollection:
    def __init__(self, db: "_StrictReadOnlyFake", name: str):
        self._db = db
        self._name = name

    def document(self, doc_id: str) -> _FakeDocument:
        if not doc_id:
            raise AssertionError("empty document ID")
        return _FakeDocument(self._db, self._name, doc_id)

    def stream(self):
        raise AssertionError("registry reader must not scan")


class _StrictReadOnlyFake:
    def __init__(self, documents: dict[tuple[str, str], dict[str, Any]]):
        self.documents = copy.deepcopy(documents)
        self.reads: list[tuple[str, str]] = []
        self.fail_reads = False

    def collection(self, name: str) -> _FakeCollection:
        return _FakeCollection(self, name)


def _doc_id(*identity: str) -> str:
    return "unit-" + "-".join(identity)


def _exact_record_projector(raw, model_type):
    return model_type.model_validate(raw).model_dump(mode="json")


@pytest.mark.parametrize(
    ("reader_type", "entry", "args"),
    [
        (
            FirestoreProviderRegistryReader,
            _provider(),
            ("provider.primary", "provider-rev-1"),
        ),
        (
            FirestoreModelRegistryReader,
            _model(),
            ("model.general", "model-rev-1"),
        ),
        (
            FirestorePromptRegistryReader,
            _prompt(),
            ("assistant.general", "prompt-v1", "prompt-rev-1"),
        ),
    ],
)
def test_firestore_registry_readers_are_lazy_and_fakeable(reader_type, entry, args):
    factory_calls = 0
    collection_name = reader_type.collection_name
    record = entry.model_dump(mode="json")
    db = _StrictReadOnlyFake({(collection_name, _doc_id(*args)): record})

    def factory() -> _StrictReadOnlyFake:
        nonlocal factory_calls
        factory_calls += 1
        return db

    reader = reader_type(
        db_factory=factory,
        document_id_resolver=_doc_id,
        record_projector=_exact_record_projector,
    )
    assert factory_calls == 0
    assert db.reads == []

    result = reader.lookup(*args)

    assert factory_calls == 1
    assert result.status is RegistryLookupStatus.FOUND
    assert "prompt_body" not in result.model_dump_json()
    assert len(db.reads) == 1


def test_firestore_registry_failure_and_missing_are_explicit_and_redacted():
    db = _StrictReadOnlyFake({})
    reader = FirestoreProviderRegistryReader(
        db=db,
        document_id_resolver=_doc_id,
        record_projector=_exact_record_projector,
    )
    missing = reader.lookup("provider.primary", "provider-rev-1")
    db.fail_reads = True
    unavailable = reader.lookup("provider.primary", "provider-rev-1")
    unconfigured = FirestoreProviderRegistryReader().lookup(
        "provider.primary", "provider-rev-1"
    )

    assert missing.status is RegistryLookupStatus.MISSING
    assert unavailable.status is RegistryLookupStatus.UNAVAILABLE
    assert "service_token" not in unavailable.model_dump_json()
    assert unconfigured.status is RegistryLookupStatus.UNAVAILABLE


def test_firestore_registry_requires_an_explicit_storage_projector():
    record = _provider().model_dump(mode="json")
    record["provider_api_key"] = "must-not-be-projected"
    db = _StrictReadOnlyFake(
        {
            (
                FirestoreProviderRegistryReader.collection_name,
                _doc_id("provider.primary", "provider-rev-1"),
            ): record
        }
    )
    no_projector = FirestoreProviderRegistryReader(
        db=db,
        document_id_resolver=_doc_id,
    ).lookup("provider.primary", "provider-rev-1")
    strict_projector = FirestoreProviderRegistryReader(
        db=db,
        document_id_resolver=_doc_id,
        record_projector=_exact_record_projector,
    ).lookup("provider.primary", "provider-rev-1")

    assert no_projector.status is RegistryLookupStatus.UNAVAILABLE
    assert strict_projector.status is RegistryLookupStatus.INVALID


def _imported_modules(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
    return imported


def test_registry_contract_is_abstract_read_only_and_has_no_provider_or_firebase_imports():
    assert inspect.isabstract(ProviderRegistryReader)
    assert inspect.isabstract(ModelRegistryReader)
    assert inspect.isabstract(PromptRegistryReader)
    assert {
        name
        for name, _ in inspect.getmembers(ProviderRegistryReader)
        if not name.startswith("_")
    } == {"lookup"}

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
            if module.split(".")[0] in prohibited_roots or module in prohibited_roots
        )
        if blocked:
            violations[str(path.relative_to(PYTHON_SERVICES))] = blocked

    assert violations == {}
    assert "utils.firebase" not in _imported_modules(
        AI_PLATFORM_PACKAGE / "registry.py"
    )


def test_clean_process_import_does_not_load_firebase_or_provider_sdks():
    code = """
import sys
import ai_platform.registry
import ai_platform.policy
blocked = {'firebase_admin', 'utils.firebase', 'anthropic', 'openai'}
loaded = blocked.intersection(sys.modules)
assert not loaded, sorted(loaded)
"""
    environment = dict(os.environ)
    environment["PYTHONPATH"] = "."
    completed = subprocess.run(
        [sys.executable, "-c", code],
        cwd=PYTHON_SERVICES,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
