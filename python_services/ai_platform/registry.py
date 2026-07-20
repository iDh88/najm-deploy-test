"""Inert readers for approved NAJM AI Platform registry references.

The readers in this module perform exact, provider-neutral revision lookup
only. A found revision is not active-route authorization: future orchestration
must separately resolve the governed environment/scope pointer and supply its
authorization reference to route validation. The module does not discover
candidates, choose routes, execute prompts, call providers, or initialize
Firebase. Firestore collection names are conceptual Phase 1 names, and callers
must inject client, locator, and storage-projector seams; no physical schema is
approved here.
"""

from __future__ import annotations

import copy
from abc import ABC, abstractmethod
from collections.abc import Callable, Iterable, Mapping
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, model_validator

from .contracts import (
    ModelLifecycleState,
    ModelRegistryRef,
    PromptLifecycleState,
    PromptRegistryRef,
    ProviderCapability,
    ProviderLifecycleState,
    ProviderRegistryRef,
)


PROPOSED_PROVIDER_REVISION_COLLECTION = "aiProviderRevisions"
PROPOSED_MODEL_REVISION_COLLECTION = "aiModelRevisions"
PROPOSED_PROMPT_VERSION_COLLECTION = "aiPromptVersions"


class RegistryLookupStatus(str, Enum):
    """Stable outcome for an exact registry-reference lookup."""

    FOUND = "found"
    MISSING = "missing"
    INELIGIBLE = "ineligible"
    UNAVAILABLE = "unavailable"
    INVALID = "invalid"


class RegistryEntryKind(str, Enum):
    PROVIDER = "provider"
    MODEL = "model"
    PROMPT = "prompt"


RegistryEntry = ProviderRegistryRef | ModelRegistryRef | PromptRegistryRef


class RegistryLookupResult(BaseModel):
    """Immutable lookup fact; never a provider route decision."""

    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
    )

    status: RegistryLookupStatus
    entry_kind: RegistryEntryKind
    requested_key: str
    requested_revision: str
    requested_version: str | None = None
    reason_code: str
    reference_eligible: bool = False
    entry: RegistryEntry | None = None

    @model_validator(mode="after")
    def result_is_internally_consistent(self) -> "RegistryLookupResult":
        if not self.requested_key or not self.requested_revision or not self.reason_code:
            raise ValueError("registry lookup identity and reason are required")
        if self.status is RegistryLookupStatus.FOUND:
            if self.entry is None or not self.reference_eligible:
                raise ValueError("found registry result must contain an eligible reference")
        elif self.reference_eligible:
            raise ValueError("only a found registry result may be reference-eligible")
        if self.status in {
            RegistryLookupStatus.MISSING,
            RegistryLookupStatus.UNAVAILABLE,
            RegistryLookupStatus.INVALID,
        } and self.entry is not None:
            raise ValueError("non-resolved registry result cannot expose an entry")

        expected_type = {
            RegistryEntryKind.PROVIDER: ProviderRegistryRef,
            RegistryEntryKind.MODEL: ModelRegistryRef,
            RegistryEntryKind.PROMPT: PromptRegistryRef,
        }[self.entry_kind]
        if self.entry is not None and not isinstance(self.entry, expected_type):
            raise ValueError("registry result entry type does not match its kind")
        return self


class RegistryRouteValidationResult(BaseModel):
    """Pure validation result for selected refs plus external activation evidence."""

    model_config = ConfigDict(extra="forbid", frozen=True, validate_default=True)

    status: RegistryLookupStatus
    references_valid: bool
    activation_authorization_ref: str | None = None
    provider: ProviderRegistryRef | None = None
    model: ModelRegistryRef | None = None
    prompt: PromptRegistryRef | None = None
    required_capability: ProviderCapability | None = None
    reason_codes: tuple[str, ...]

    @model_validator(mode="after")
    def route_status_matches_executable(self) -> "RegistryRouteValidationResult":
        if not self.reason_codes:
            raise ValueError("route validation requires at least one reason")
        if self.references_valid != (self.status is RegistryLookupStatus.FOUND):
            raise ValueError("only a found registry route may have valid references")
        if self.references_valid and not self.activation_authorization_ref:
            raise ValueError("valid route references require activation authorization")
        if not self.references_valid and self.activation_authorization_ref is not None:
            raise ValueError("invalid route references cannot claim activation")
        if self.references_valid and (
            self.provider is None
            or self.model is None
            or self.required_capability is None
        ):
            raise ValueError("valid route references require provider/model provenance")
        if (
            self.references_valid
            and self.required_capability is not ProviderCapability.EMBEDDINGS
            and self.prompt is None
        ):
            raise ValueError("valid generation references require prompt provenance")
        return self


def _result(
    *,
    status: RegistryLookupStatus,
    kind: RegistryEntryKind,
    key: str,
    revision: str,
    version: str | None = None,
    reason_code: str,
    entry: RegistryEntry | None = None,
) -> RegistryLookupResult:
    return RegistryLookupResult(
        status=status,
        entry_kind=kind,
        requested_key=key,
        requested_revision=revision,
        requested_version=version,
        reason_code=reason_code,
        reference_eligible=status is RegistryLookupStatus.FOUND,
        entry=entry,
    )


def _provider_result(entry: ProviderRegistryRef) -> RegistryLookupResult:
    status = (
        RegistryLookupStatus.FOUND
        if entry.lifecycle is ProviderLifecycleState.ENABLED
        else RegistryLookupStatus.INELIGIBLE
    )
    reason = (
        "provider_revision_enabled"
        if status is RegistryLookupStatus.FOUND
        else "provider_lifecycle_ineligible"
    )
    return _result(
        status=status,
        kind=RegistryEntryKind.PROVIDER,
        key=entry.provider_key,
        revision=entry.registry_revision,
        reason_code=reason,
        entry=entry,
    )


def _model_result(
    entry: ModelRegistryRef,
    *,
    compatibility_authorized: bool = False,
) -> RegistryLookupResult:
    enabled = entry.lifecycle is ModelLifecycleState.ENABLED
    compatibility = (
        entry.lifecycle is ModelLifecycleState.DEPRECATED
        and entry.compatibility_authorization_ref is not None
        and compatibility_authorized
    )
    status = (
        RegistryLookupStatus.FOUND
        if enabled or compatibility
        else RegistryLookupStatus.INELIGIBLE
    )
    if enabled:
        reason = "model_revision_enabled"
    elif compatibility:
        reason = "model_deprecated_compatibility_resolved"
    elif entry.lifecycle is ModelLifecycleState.DEPRECATED:
        reason = "model_deprecated_without_compatibility_authorization"
    else:
        reason = "model_lifecycle_ineligible"
    return _result(
        status=status,
        kind=RegistryEntryKind.MODEL,
        key=entry.model_key,
        revision=entry.model_revision,
        reason_code=reason,
        entry=entry,
    )


def _prompt_result(entry: PromptRegistryRef) -> RegistryLookupResult:
    status = (
        RegistryLookupStatus.FOUND
        if entry.lifecycle is PromptLifecycleState.ACTIVE
        else RegistryLookupStatus.INELIGIBLE
    )
    reason = (
        "prompt_version_active"
        if status is RegistryLookupStatus.FOUND
        else "prompt_lifecycle_ineligible"
    )
    return _result(
        status=status,
        kind=RegistryEntryKind.PROMPT,
        key=entry.prompt_family_key,
        revision=entry.registry_revision,
        version=entry.prompt_version,
        reason_code=reason,
        entry=entry,
    )


class ProviderRegistryReader(ABC):
    @abstractmethod
    def lookup(self, provider_key: str, registry_revision: str) -> RegistryLookupResult:
        """Read one exact provider revision without selecting a route."""


class ModelRegistryReader(ABC):
    @abstractmethod
    def lookup(self, model_key: str, model_revision: str) -> RegistryLookupResult:
        """Read one exact model revision without selecting a route."""


class PromptRegistryReader(ABC):
    @abstractmethod
    def lookup(
        self,
        prompt_family_key: str,
        prompt_version: str,
        registry_revision: str,
    ) -> RegistryLookupResult:
        """Read prompt reference metadata; never render or execute its body."""


def _index_unique(
    entries: Iterable[RegistryEntry],
    identity: Callable[[RegistryEntry], tuple[str, ...]],
) -> dict[tuple[str, ...], RegistryEntry]:
    indexed: dict[tuple[str, ...], RegistryEntry] = {}
    for entry in entries:
        key = identity(entry)
        if key in indexed:
            raise ValueError("duplicate registry identity")
        indexed[key] = copy.deepcopy(entry)
    return indexed


class InMemoryProviderRegistry(ProviderRegistryReader):
    """Deterministic exact-reference provider reader for tests."""

    def __init__(self, entries: Iterable[ProviderRegistryRef] = ()) -> None:
        self._entries = _index_unique(
            entries,
            lambda entry: (entry.provider_key, entry.registry_revision),
        )

    def lookup(self, provider_key: str, registry_revision: str) -> RegistryLookupResult:
        entry = self._entries.get((provider_key, registry_revision))
        if entry is None:
            return _result(
                status=RegistryLookupStatus.MISSING,
                kind=RegistryEntryKind.PROVIDER,
                key=provider_key,
                revision=registry_revision,
                reason_code="provider_revision_missing",
            )
        assert isinstance(entry, ProviderRegistryRef)
        return _provider_result(entry)


class InMemoryModelRegistry(ModelRegistryReader):
    """Deterministic exact-reference model reader for tests."""

    def __init__(
        self,
        entries: Iterable[ModelRegistryRef] = (),
        *,
        compatibility_authorizer: Callable[[ModelRegistryRef], bool] | None = None,
    ) -> None:
        self._entries = _index_unique(
            entries,
            lambda entry: (entry.model_key, entry.model_revision),
        )
        self._compatibility_authorizer = compatibility_authorizer

    def lookup(self, model_key: str, model_revision: str) -> RegistryLookupResult:
        entry = self._entries.get((model_key, model_revision))
        if entry is None:
            return _result(
                status=RegistryLookupStatus.MISSING,
                kind=RegistryEntryKind.MODEL,
                key=model_key,
                revision=model_revision,
                reason_code="model_revision_missing",
            )
        assert isinstance(entry, ModelRegistryRef)
        compatibility_authorized = False
        if entry.lifecycle is ModelLifecycleState.DEPRECATED:
            if self._compatibility_authorizer is None:
                return _model_result(entry)
            try:
                compatibility_authorized = bool(self._compatibility_authorizer(entry))
            except Exception:
                return _result(
                    status=RegistryLookupStatus.UNAVAILABLE,
                    kind=RegistryEntryKind.MODEL,
                    key=model_key,
                    revision=model_revision,
                    reason_code="model_compatibility_authorization_unavailable",
                )
        return _model_result(
            entry,
            compatibility_authorized=compatibility_authorized,
        )


class InMemoryPromptRegistry(PromptRegistryReader):
    """Deterministic prompt-reference reader; prompt bodies are not accepted."""

    def __init__(self, entries: Iterable[PromptRegistryRef] = ()) -> None:
        self._entries = _index_unique(
            entries,
            lambda entry: (
                entry.prompt_family_key,
                entry.prompt_version,
                entry.registry_revision,
            ),
        )

    def lookup(
        self,
        prompt_family_key: str,
        prompt_version: str,
        registry_revision: str,
    ) -> RegistryLookupResult:
        entry = self._entries.get(
            (prompt_family_key, prompt_version, registry_revision)
        )
        if entry is None:
            return _result(
                status=RegistryLookupStatus.MISSING,
                kind=RegistryEntryKind.PROMPT,
                key=prompt_family_key,
                revision=registry_revision,
                version=prompt_version,
                reason_code="prompt_revision_missing",
            )
        assert isinstance(entry, PromptRegistryRef)
        return _prompt_result(entry)


def validate_route_registry_refs(
    *,
    provider: ProviderRegistryRef | None,
    model: ModelRegistryRef | None,
    prompt: PromptRegistryRef | None,
    required_capability: ProviderCapability,
    activation_authorization_ref: str | None,
    deprecated_model_compatibility_authorized: bool = False,
) -> RegistryRouteValidationResult:
    """Validate a selected route without discovering or falling back to one."""

    prompt_required = required_capability is not ProviderCapability.EMBEDDINGS
    if provider is None or model is None or (prompt_required and prompt is None):
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.MISSING,
            references_valid=False,
            reason_codes=("provider_model_prompt_reference_required",),
        )
    if not activation_authorization_ref:
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.MISSING,
            references_valid=False,
            reason_codes=("route_activation_authorization_required",),
        )
    if provider.lifecycle is not ProviderLifecycleState.ENABLED:
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.INELIGIBLE,
            references_valid=False,
            reason_codes=("provider_lifecycle_ineligible",),
        )
    model_eligible = model.lifecycle is ModelLifecycleState.ENABLED or (
        model.lifecycle is ModelLifecycleState.DEPRECATED
        and model.compatibility_authorization_ref is not None
        and deprecated_model_compatibility_authorized
    )
    if not model_eligible:
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.INELIGIBLE,
            references_valid=False,
            reason_codes=("model_lifecycle_ineligible",),
        )
    if prompt is not None and prompt.lifecycle is not PromptLifecycleState.ACTIVE:
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.INELIGIBLE,
            references_valid=False,
            reason_codes=("prompt_lifecycle_ineligible",),
        )
    if provider.provider_key != model.provider_key:
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.INVALID,
            references_valid=False,
            reason_codes=("provider_model_binding_mismatch",),
        )
    if required_capability not in model.capabilities:
        return RegistryRouteValidationResult(
            status=RegistryLookupStatus.INVALID,
            references_valid=False,
            reason_codes=("model_capability_unavailable",),
        )
    return RegistryRouteValidationResult(
        status=RegistryLookupStatus.FOUND,
        references_valid=True,
        activation_authorization_ref=activation_authorization_ref,
        provider=provider,
        model=model,
        prompt=prompt,
        required_capability=required_capability,
        reason_codes=("registry_route_refs_valid",),
    )


DocumentIdResolver = Callable[..., str]
RegistryRecordProjector = Callable[
    [Mapping[str, Any], type[RegistryEntry]],
    Mapping[str, Any],
]


class _FirestoreExactRegistryReader:
    """Read-only Firestore-like seam, inert until an explicit lookup."""

    collection_name: str
    entry_kind: RegistryEntryKind
    model_type: type[RegistryEntry]

    def __init__(
        self,
        db: Any | None = None,
        *,
        db_factory: Callable[[], Any] | None = None,
        document_id_resolver: DocumentIdResolver | None = None,
        record_projector: RegistryRecordProjector | None = None,
        collection_name: str | None = None,
    ) -> None:
        if db is not None and db_factory is not None:
            raise ValueError("provide either db or db_factory, not both")
        self._db = db
        self._db_factory = db_factory
        self._document_id_resolver = document_id_resolver
        self._record_projector = record_projector
        self._collection_name = collection_name or self.collection_name
        if not self._collection_name or "/" in self._collection_name:
            raise ValueError("registry collection must be a direct collection name")

    def _resolve_db(self) -> Any:
        if self._db is not None:
            return self._db
        if self._db_factory is None:
            raise RuntimeError("registry client is not configured")
        self._db = self._db_factory()
        if self._db is None:
            raise RuntimeError("registry client factory returned no client")
        return self._db

    def _lookup_exact(
        self,
        key: str,
        revision: str,
        *,
        version: str | None = None,
        locator_parts: tuple[str, ...] | None = None,
    ) -> RegistryLookupResult:
        if self._document_id_resolver is None:
            return _result(
                status=RegistryLookupStatus.UNAVAILABLE,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code="registry_document_locator_unconfigured",
            )
        if self._record_projector is None:
            return _result(
                status=RegistryLookupStatus.UNAVAILABLE,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code="registry_record_projector_unconfigured",
            )
        try:
            parts = locator_parts or (key, revision)
            document_id = self._document_id_resolver(*parts)
        except Exception:
            return _result(
                status=RegistryLookupStatus.INVALID,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code="registry_document_locator_invalid",
            )
        if not isinstance(document_id, str) or not document_id or "/" in document_id:
            return _result(
                status=RegistryLookupStatus.INVALID,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code="registry_document_locator_invalid",
            )
        try:
            snapshot = (
                self._resolve_db()
                .collection(self._collection_name)
                .document(document_id)
                .get()
            )
        except Exception:
            return _result(
                status=RegistryLookupStatus.UNAVAILABLE,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code="registry_read_unavailable",
            )
        if not bool(getattr(snapshot, "exists", False)):
            return _result(
                status=RegistryLookupStatus.MISSING,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code=f"{self.entry_kind.value}_revision_missing",
            )
        try:
            raw = snapshot.to_dict()
            if not isinstance(raw, Mapping):
                raise ValueError("registry document is not a mapping")
            # Exact physical serialization and integrity envelopes remain
            # unapproved. The injected projector owns that future validation;
            # this reader returns only its compact, detached reference output.
            projected = copy.deepcopy(
                dict(self._record_projector(copy.deepcopy(raw), self.model_type))
            )
            entry = self.model_type.model_validate(projected)
            if self.entry_kind is RegistryEntryKind.PROVIDER:
                assert isinstance(entry, ProviderRegistryRef)
                if (entry.provider_key, entry.registry_revision) != (key, revision):
                    raise ValueError("provider registry identity mismatch")
                return _provider_result(entry)
            if self.entry_kind is RegistryEntryKind.MODEL:
                assert isinstance(entry, ModelRegistryRef)
                if (entry.model_key, entry.model_revision) != (key, revision):
                    raise ValueError("model registry identity mismatch")
                return self._resolved_model_result(entry)
            assert isinstance(entry, PromptRegistryRef)
            if (
                entry.prompt_family_key,
                entry.prompt_version,
                entry.registry_revision,
            ) != (key, version, revision):
                raise ValueError("prompt registry identity mismatch")
            return _prompt_result(entry)
        except Exception:
            return _result(
                status=RegistryLookupStatus.INVALID,
                kind=self.entry_kind,
                key=key,
                revision=revision,
                version=version,
                reason_code="registry_record_invalid",
            )

    def _resolved_model_result(self, entry: ModelRegistryRef) -> RegistryLookupResult:
        return _model_result(entry)


class FirestoreProviderRegistryReader(
    _FirestoreExactRegistryReader,
    ProviderRegistryReader,
):
    collection_name = PROPOSED_PROVIDER_REVISION_COLLECTION
    entry_kind = RegistryEntryKind.PROVIDER
    model_type = ProviderRegistryRef

    def lookup(self, provider_key: str, registry_revision: str) -> RegistryLookupResult:
        return self._lookup_exact(provider_key, registry_revision)


class FirestoreModelRegistryReader(
    _FirestoreExactRegistryReader,
    ModelRegistryReader,
):
    collection_name = PROPOSED_MODEL_REVISION_COLLECTION
    entry_kind = RegistryEntryKind.MODEL
    model_type = ModelRegistryRef

    def __init__(
        self,
        db: Any | None = None,
        *,
        compatibility_authorizer: Callable[[ModelRegistryRef], bool] | None = None,
        **kwargs: Any,
    ) -> None:
        super().__init__(db, **kwargs)
        self._compatibility_authorizer = compatibility_authorizer

    def _resolved_model_result(self, entry: ModelRegistryRef) -> RegistryLookupResult:
        compatibility_authorized = False
        if entry.lifecycle is ModelLifecycleState.DEPRECATED:
            if self._compatibility_authorizer is None:
                return _model_result(entry)
            try:
                compatibility_authorized = bool(self._compatibility_authorizer(entry))
            except Exception:
                return _result(
                    status=RegistryLookupStatus.UNAVAILABLE,
                    kind=RegistryEntryKind.MODEL,
                    key=entry.model_key,
                    revision=entry.model_revision,
                    reason_code="model_compatibility_authorization_unavailable",
                )
        return _model_result(
            entry,
            compatibility_authorized=compatibility_authorized,
        )

    def lookup(self, model_key: str, model_revision: str) -> RegistryLookupResult:
        return self._lookup_exact(model_key, model_revision)


class FirestorePromptRegistryReader(
    _FirestoreExactRegistryReader,
    PromptRegistryReader,
):
    collection_name = PROPOSED_PROMPT_VERSION_COLLECTION
    entry_kind = RegistryEntryKind.PROMPT
    model_type = PromptRegistryRef

    def lookup(
        self,
        prompt_family_key: str,
        prompt_version: str,
        registry_revision: str,
    ) -> RegistryLookupResult:
        return self._lookup_exact(
            prompt_family_key,
            registry_revision,
            version=prompt_version,
            locator_parts=(prompt_family_key, prompt_version, registry_revision),
        )


__all__ = [
    "FirestoreModelRegistryReader",
    "FirestorePromptRegistryReader",
    "FirestoreProviderRegistryReader",
    "InMemoryModelRegistry",
    "InMemoryPromptRegistry",
    "InMemoryProviderRegistry",
    "ModelRegistryReader",
    "PROPOSED_MODEL_REVISION_COLLECTION",
    "PROPOSED_PROMPT_VERSION_COLLECTION",
    "PROPOSED_PROVIDER_REVISION_COLLECTION",
    "PromptRegistryReader",
    "ProviderRegistryReader",
    "RegistryEntryKind",
    "RegistryLookupResult",
    "RegistryLookupStatus",
    "RegistryRouteValidationResult",
    "validate_route_registry_refs",
]
