"""Inert policy-decision readers and deny-dominant composition helpers.

This module composes already-evaluated, provider-neutral decision references.
It does not authenticate callers, evaluate subscriptions, price credits,
select providers, execute prompts, initialize Firebase, or enforce policy in
any runtime route.  Missing mandatory policy never becomes an implicit allow.
"""

from __future__ import annotations

import copy
import re
from abc import ABC, abstractmethod
from collections.abc import Callable, Iterable, Mapping
from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import AwareDatetime, BaseModel, ConfigDict, model_validator

from .contracts import (
    AISafetyDecision,
    BudgetDecisionRef,
    BudgetDecisionResult,
    EntitlementDecisionRef,
    FeatureFlagDecisionRef,
    SafetyDecisionRef,
)
from .registry import RegistryLookupStatus, RegistryRouteValidationResult


class PolicyReadStatus(str, Enum):
    FOUND = "found"
    MISSING = "missing"
    UNAVAILABLE = "unavailable"
    INVALID = "invalid"


class PolicyDecisionKind(str, Enum):
    FEATURE_FLAG = "feature_flag"
    ENTITLEMENT = "entitlement"
    BUDGET = "budget"
    SAFETY = "safety"


PolicyDecisionRef = (
    FeatureFlagDecisionRef
    | EntitlementDecisionRef
    | BudgetDecisionRef
    | SafetyDecisionRef
)


class PolicyReadResult(BaseModel):
    """Read result with a stable, redacted failure surface."""

    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
    )

    status: PolicyReadStatus
    decision_kind: PolicyDecisionKind
    requested_id: str
    reason_code: str
    decision: PolicyDecisionRef | None = None

    @model_validator(mode="after")
    def result_is_consistent(self) -> "PolicyReadResult":
        if not self.requested_id or not self.reason_code:
            raise ValueError("policy lookup identity and reason are required")
        if self.status is PolicyReadStatus.FOUND:
            if self.decision is None:
                raise ValueError("found policy result requires a decision")
        elif self.decision is not None:
            raise ValueError("unresolved policy result cannot expose a decision")
        expected = {
            PolicyDecisionKind.FEATURE_FLAG: FeatureFlagDecisionRef,
            PolicyDecisionKind.ENTITLEMENT: EntitlementDecisionRef,
            PolicyDecisionKind.BUDGET: BudgetDecisionRef,
            PolicyDecisionKind.SAFETY: SafetyDecisionRef,
        }[self.decision_kind]
        if self.decision is not None and not isinstance(self.decision, expected):
            raise ValueError("policy result decision type does not match its kind")
        return self


def _read_result(
    *,
    status: PolicyReadStatus,
    kind: PolicyDecisionKind,
    requested_id: str,
    reason_code: str,
    decision: PolicyDecisionRef | None = None,
) -> PolicyReadResult:
    return PolicyReadResult(
        status=status,
        decision_kind=kind,
        requested_id=requested_id,
        reason_code=reason_code,
        decision=copy.deepcopy(decision),
    )


class FeatureFlagReader(ABC):
    @abstractmethod
    def read(self, evaluation_id: str) -> PolicyReadResult:
        """Read one existing feature-flag decision reference."""


class EntitlementReader(ABC):
    @abstractmethod
    def read(self, decision_id: str) -> PolicyReadResult:
        """Read one provider-neutral entitlement decision reference."""


class BudgetDecisionReader(ABC):
    @abstractmethod
    def read(self, decision_id: str) -> PolicyReadResult:
        """Read one request-scoped budget decision reference."""


class SafetyDecisionReader(ABC):
    @abstractmethod
    def read(self, decision_id: str) -> PolicyReadResult:
        """Read one safety decision reference."""


def _index_decisions(
    decisions: Iterable[PolicyDecisionRef],
    identity: Callable[[PolicyDecisionRef], str],
) -> dict[str, PolicyDecisionRef]:
    indexed: dict[str, PolicyDecisionRef] = {}
    for decision in decisions:
        decision_id = identity(decision)
        if decision_id in indexed:
            raise ValueError("duplicate policy decision identity")
        indexed[decision_id] = copy.deepcopy(decision)
    return indexed


class InMemoryFeatureFlagReader(FeatureFlagReader):
    def __init__(self, decisions: Iterable[FeatureFlagDecisionRef] = ()) -> None:
        self._decisions = _index_decisions(decisions, lambda item: item.evaluation_id)

    def read(self, evaluation_id: str) -> PolicyReadResult:
        decision = self._decisions.get(evaluation_id)
        if decision is None:
            return _read_result(
                status=PolicyReadStatus.MISSING,
                kind=PolicyDecisionKind.FEATURE_FLAG,
                requested_id=evaluation_id,
                reason_code="feature_flag_decision_missing",
            )
        assert isinstance(decision, FeatureFlagDecisionRef)
        return _read_result(
            status=PolicyReadStatus.FOUND,
            kind=PolicyDecisionKind.FEATURE_FLAG,
            requested_id=evaluation_id,
            reason_code="feature_flag_decision_found",
            decision=decision,
        )


class InMemoryEntitlementReader(EntitlementReader):
    def __init__(self, decisions: Iterable[EntitlementDecisionRef] = ()) -> None:
        self._decisions = _index_decisions(decisions, lambda item: item.decision_id)

    def read(self, decision_id: str) -> PolicyReadResult:
        decision = self._decisions.get(decision_id)
        if decision is None:
            return _read_result(
                status=PolicyReadStatus.MISSING,
                kind=PolicyDecisionKind.ENTITLEMENT,
                requested_id=decision_id,
                reason_code="entitlement_decision_missing",
            )
        assert isinstance(decision, EntitlementDecisionRef)
        return _read_result(
            status=PolicyReadStatus.FOUND,
            kind=PolicyDecisionKind.ENTITLEMENT,
            requested_id=decision_id,
            reason_code="entitlement_decision_found",
            decision=decision,
        )


class InMemoryBudgetDecisionReader(BudgetDecisionReader):
    def __init__(self, decisions: Iterable[BudgetDecisionRef] = ()) -> None:
        self._decisions = _index_decisions(decisions, lambda item: item.decision_id)

    def read(self, decision_id: str) -> PolicyReadResult:
        decision = self._decisions.get(decision_id)
        if decision is None:
            return _read_result(
                status=PolicyReadStatus.MISSING,
                kind=PolicyDecisionKind.BUDGET,
                requested_id=decision_id,
                reason_code="budget_decision_missing",
            )
        assert isinstance(decision, BudgetDecisionRef)
        return _read_result(
            status=PolicyReadStatus.FOUND,
            kind=PolicyDecisionKind.BUDGET,
            requested_id=decision_id,
            reason_code="budget_decision_found",
            decision=decision,
        )


class InMemorySafetyDecisionReader(SafetyDecisionReader):
    def __init__(self, decisions: Iterable[SafetyDecisionRef] = ()) -> None:
        self._decisions = _index_decisions(decisions, lambda item: item.decision_id)

    def read(self, decision_id: str) -> PolicyReadResult:
        decision = self._decisions.get(decision_id)
        if decision is None:
            return _read_result(
                status=PolicyReadStatus.MISSING,
                kind=PolicyDecisionKind.SAFETY,
                requested_id=decision_id,
                reason_code="safety_decision_missing",
            )
        assert isinstance(decision, SafetyDecisionRef)
        return _read_result(
            status=PolicyReadStatus.FOUND,
            kind=PolicyDecisionKind.SAFETY,
            requested_id=decision_id,
            reason_code="safety_decision_found",
            decision=decision,
        )


class KillSwitchDisposition(str, Enum):
    """Explicit response selected by a server-authoritative incident control."""

    CLEAR = "clear"
    DENY = "deny"
    DEGRADED = "degraded"
    DETERMINISTIC_ONLY = "deterministic_only"
    UNAVAILABLE = "unavailable"


class KillSwitchDecisionRef(BaseModel):
    """Compact incident-control provenance; not a client-controlled flag."""

    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
    )

    evaluation_id: str
    switch_key: str
    switch_version: str
    disposition: KillSwitchDisposition
    reason_code: str
    source_ref: str
    evaluated_at: AwareDatetime
    valid_until: AwareDatetime | None = None

    @model_validator(mode="after")
    def required_identifiers_are_not_blank(self) -> "KillSwitchDecisionRef":
        fields = (
            self.evaluation_id,
            self.switch_key,
            self.switch_version,
            self.reason_code,
            self.source_ref,
        )
        if any(not value.strip() for value in fields):
            raise ValueError("kill-switch identifiers and provenance are required")
        return self


class PolicyDecisionStatus(str, Enum):
    ALLOW = "allow"
    DENY = "deny"
    DEGRADED = "degraded"
    DETERMINISTIC_ONLY = "deterministic_only"
    UNAVAILABLE = "unavailable"


class PolicyEvaluationSnapshot(BaseModel):
    """Immutable decision provenance without prompt bodies or secret channels."""

    model_config = ConfigDict(extra="forbid", frozen=True, validate_default=True)

    request_id: str
    feature_key: str
    evaluated_at: AwareDatetime
    feature_flag: FeatureFlagDecisionRef | None = None
    entitlement: EntitlementDecisionRef | None = None
    safety: SafetyDecisionRef | None = None
    budget: BudgetDecisionRef | None = None
    kill_switch: KillSwitchDecisionRef | None = None
    registry_route: RegistryRouteValidationResult | None = None

    @model_validator(mode="after")
    def decision_feature_keys_match(self) -> "PolicyEvaluationSnapshot":
        if not self.request_id or not self.feature_key:
            raise ValueError("policy snapshot request and feature identities are required")
        if self.entitlement is not None:
            for key in self.entitlement.limits:
                snake_key = re.sub(r"(?<!^)(?=[A-Z])", "_", key.strip())
                normalized = re.sub(
                    r"[^a-z0-9]+", "_", snake_key.lower()
                ).strip("_")
                parts = set(normalized.split("_"))
                if parts & {
                    "credential",
                    "credentials",
                    "password",
                    "secret",
                    "token",
                } or "api_key" in normalized:
                    raise ValueError("policy snapshot contains a forbidden metadata key")
        return self


class PolicyCompositionResult(BaseModel):
    """Pure policy outcome; it performs no runtime enforcement."""

    model_config = ConfigDict(extra="forbid", frozen=True, validate_default=True)

    status: PolicyDecisionStatus
    provider_execution_allowed: bool
    entitlement_allowed: bool
    reason_codes: tuple[str, ...]
    snapshot: PolicyEvaluationSnapshot

    @model_validator(mode="after")
    def outcome_is_consistent(self) -> "PolicyCompositionResult":
        if not self.reason_codes:
            raise ValueError("policy composition requires a stable reason")
        if self.provider_execution_allowed != (self.status is PolicyDecisionStatus.ALLOW):
            raise ValueError("provider execution flag does not match policy status")
        return self


def build_policy_snapshot(
    *,
    request_id: str,
    feature_key: str,
    evaluated_at: datetime,
    feature_flag: FeatureFlagDecisionRef | None,
    entitlement: EntitlementDecisionRef | None,
    safety: SafetyDecisionRef | None,
    budget: BudgetDecisionRef | None,
    kill_switch: KillSwitchDecisionRef | None,
    registry_route: RegistryRouteValidationResult | None,
) -> PolicyEvaluationSnapshot:
    """Build a frozen, provider-neutral provenance snapshot."""

    return PolicyEvaluationSnapshot(
        request_id=request_id,
        feature_key=feature_key,
        evaluated_at=evaluated_at,
        feature_flag=copy.deepcopy(feature_flag),
        entitlement=copy.deepcopy(entitlement),
        safety=copy.deepcopy(safety),
        budget=copy.deepcopy(budget),
        kill_switch=copy.deepcopy(kill_switch),
        registry_route=copy.deepcopy(registry_route),
    )


def compose_ai_policy_decision(
    *,
    request_id: str,
    feature_key: str,
    evaluated_at: datetime,
    feature_flag: FeatureFlagDecisionRef | None,
    entitlement: EntitlementDecisionRef | None,
    safety: SafetyDecisionRef | None,
    budget: BudgetDecisionRef | None,
    kill_switch: KillSwitchDecisionRef | None,
    registry_route: RegistryRouteValidationResult | None,
) -> PolicyCompositionResult:
    """Compose mandatory controls with safe, deny-dominant semantics.

    A no-incident outcome is an explicit ``CLEAR`` kill-switch decision. An
    omitted or unreadable mandatory control is always unavailable and can
    never become provider execution. ``registry_route`` must include the
    activation evidence produced outside the revision reader.
    """

    snapshot = build_policy_snapshot(
        request_id=request_id,
        feature_key=feature_key,
        evaluated_at=evaluated_at,
        feature_flag=feature_flag,
        entitlement=entitlement,
        safety=safety,
        budget=budget,
        kill_switch=kill_switch,
        registry_route=registry_route,
    )
    entitlement_allowed = entitlement is not None and entitlement.allowed

    # Safety refusal is evaluated first so no commercial or availability fact
    # can obscure the safety-dominant reason.
    if safety is not None and safety.decision in {
        AISafetyDecision.ABSTAINED,
        AISafetyDecision.REFUSED,
        AISafetyDecision.ESCALATED,
    }:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("safety_denied", *safety.reason_codes),
            snapshot=snapshot,
        )
    if kill_switch is not None and kill_switch.disposition is KillSwitchDisposition.DENY:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("kill_switch_denied", kill_switch.reason_code),
            snapshot=snapshot,
        )
    if feature_flag is not None and not feature_flag.allowed:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("feature_disabled", feature_flag.reason_code),
            snapshot=snapshot,
        )
    if entitlement is not None and not entitlement.allowed:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=False,
            reason_codes=("entitlement_denied", entitlement.reason_code),
            snapshot=snapshot,
        )

    core_missing = tuple(
        name
        for name, decision in (
            ("feature_flag", feature_flag),
            ("entitlement", entitlement),
            ("safety", safety),
            ("kill_switch", kill_switch),
        )
        if decision is None
    )
    if core_missing:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=tuple(f"{name}_policy_missing" for name in core_missing),
            snapshot=snapshot,
        )
    assert feature_flag is not None
    assert entitlement is not None
    assert safety is not None
    assert kill_switch is not None

    decision_feature_keys = {
        decision.feature_key
        for decision in (feature_flag, entitlement, safety, budget)
        if decision is not None
    }
    if decision_feature_keys != {feature_key}:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("policy_feature_scope_mismatch",),
            snapshot=snapshot,
        )
    if entitlement.valid_until is not None and entitlement.valid_until <= evaluated_at:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=False,
            reason_codes=("entitlement_expired",),
            snapshot=snapshot,
        )
    if kill_switch.valid_until is not None and kill_switch.valid_until <= evaluated_at:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("kill_switch_decision_expired",),
            snapshot=snapshot,
        )
    if safety.decision is AISafetyDecision.UNAVAILABLE:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("safety_policy_unavailable", *safety.reason_codes),
            snapshot=snapshot,
        )
    if kill_switch.disposition is KillSwitchDisposition.UNAVAILABLE:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("kill_switch_policy_unavailable", kill_switch.reason_code),
            snapshot=snapshot,
        )
    if safety.decision is AISafetyDecision.DETERMINISTIC_ONLY or (
        kill_switch.disposition is KillSwitchDisposition.DETERMINISTIC_ONLY
    ):
        reasons = ["deterministic_only"]
        if safety.decision is AISafetyDecision.DETERMINISTIC_ONLY:
            reasons.extend(safety.reason_codes)
        if kill_switch.disposition is KillSwitchDisposition.DETERMINISTIC_ONLY:
            reasons.append(kill_switch.reason_code)
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DETERMINISTIC_ONLY,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=tuple(reasons),
            snapshot=snapshot,
        )

    provider_missing = tuple(
        name
        for name, decision in (
            ("budget", budget),
            ("registry_route", registry_route),
        )
        if decision is None
    )
    if provider_missing:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=tuple(f"{name}_policy_missing" for name in provider_missing),
            snapshot=snapshot,
        )
    assert budget is not None
    assert registry_route is not None
    if budget.result is BudgetDecisionResult.DENY:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("budget_denied", *budget.reason_codes),
            snapshot=snapshot,
        )
    if budget.request_id != request_id:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("budget_request_mismatch",),
            snapshot=snapshot,
        )
    if budget.expires_at <= evaluated_at:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("budget_decision_expired",),
            snapshot=snapshot,
        )
    if (
        registry_route.status is not RegistryLookupStatus.FOUND
        or not registry_route.references_valid
    ):
        reasons = registry_route.reason_codes or ("registry_route_unavailable",)
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.UNAVAILABLE,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=reasons,
            snapshot=snapshot,
        )

    degraded = safety.decision is AISafetyDecision.DEGRADED or (
        kill_switch.disposition is KillSwitchDisposition.DEGRADED
    )
    if degraded:
        reasons = ["policy_degraded"]
        if safety.decision is AISafetyDecision.DEGRADED:
            reasons.extend(safety.reason_codes)
        if kill_switch.disposition is KillSwitchDisposition.DEGRADED:
            reasons.append(kill_switch.reason_code)
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DEGRADED,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=tuple(reasons),
            snapshot=snapshot,
        )
    if safety.decision not in {AISafetyDecision.ALLOWED, AISafetyDecision.GROUNDED}:
        return PolicyCompositionResult(
            status=PolicyDecisionStatus.DENY,
            provider_execution_allowed=False,
            entitlement_allowed=entitlement_allowed,
            reason_codes=("safety_not_permitting", *safety.reason_codes),
            snapshot=snapshot,
        )
    return PolicyCompositionResult(
        status=PolicyDecisionStatus.ALLOW,
        provider_execution_allowed=True,
        entitlement_allowed=entitlement_allowed,
        reason_codes=("all_mandatory_controls_allow",),
        snapshot=snapshot,
    )


PolicyDocumentIdResolver = Callable[[str], str]
PolicyRecordProjector = Callable[
    [Mapping[str, Any], type[PolicyDecisionRef]],
    Mapping[str, Any],
]


class _FirestorePolicyReader:
    """Read-only Firestore-like seam with no ambient client or schema binding."""

    decision_kind: PolicyDecisionKind
    model_type: type[PolicyDecisionRef]

    def __init__(
        self,
        db: Any | None = None,
        *,
        db_factory: Callable[[], Any] | None = None,
        collection_name: str,
        document_id_resolver: PolicyDocumentIdResolver | None = None,
        record_projector: PolicyRecordProjector | None = None,
    ) -> None:
        if db is not None and db_factory is not None:
            raise ValueError("provide either db or db_factory, not both")
        if not collection_name or "/" in collection_name:
            raise ValueError("policy collection must be a direct collection name")
        self._db = db
        self._db_factory = db_factory
        self._collection_name = collection_name
        self._document_id_resolver = document_id_resolver
        self._record_projector = record_projector

    def _resolve_db(self) -> Any:
        if self._db is not None:
            return self._db
        if self._db_factory is None:
            raise RuntimeError("policy client is not configured")
        self._db = self._db_factory()
        if self._db is None:
            raise RuntimeError("policy client factory returned no client")
        return self._db

    def _read_exact(self, requested_id: str) -> PolicyReadResult:
        if self._document_id_resolver is None:
            return _read_result(
                status=PolicyReadStatus.UNAVAILABLE,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code="policy_document_locator_unconfigured",
            )
        if self._record_projector is None:
            return _read_result(
                status=PolicyReadStatus.UNAVAILABLE,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code="policy_record_projector_unconfigured",
            )
        try:
            document_id = self._document_id_resolver(requested_id)
        except Exception:
            return _read_result(
                status=PolicyReadStatus.INVALID,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code="policy_document_locator_invalid",
            )
        if not isinstance(document_id, str) or not document_id or "/" in document_id:
            return _read_result(
                status=PolicyReadStatus.INVALID,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code="policy_document_locator_invalid",
            )
        try:
            snapshot = (
                self._resolve_db()
                .collection(self._collection_name)
                .document(document_id)
                .get()
            )
        except Exception:
            return _read_result(
                status=PolicyReadStatus.UNAVAILABLE,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code="policy_read_unavailable",
            )
        if not bool(getattr(snapshot, "exists", False)):
            return _read_result(
                status=PolicyReadStatus.MISSING,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code=f"{self.decision_kind.value}_decision_missing",
            )
        try:
            raw = snapshot.to_dict()
            if not isinstance(raw, Mapping):
                raise ValueError("policy document is not a mapping")
            projected = copy.deepcopy(
                dict(self._record_projector(copy.deepcopy(raw), self.model_type))
            )
            decision = self.model_type.model_validate(projected)
            identity = (
                decision.evaluation_id
                if isinstance(decision, FeatureFlagDecisionRef)
                else decision.decision_id
            )
            if identity != requested_id:
                raise ValueError("policy decision identity mismatch")
            return _read_result(
                status=PolicyReadStatus.FOUND,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code=f"{self.decision_kind.value}_decision_found",
                decision=decision,
            )
        except Exception:
            return _read_result(
                status=PolicyReadStatus.INVALID,
                kind=self.decision_kind,
                requested_id=requested_id,
                reason_code="policy_record_invalid",
            )


class FirestoreFeatureFlagReader(_FirestorePolicyReader, FeatureFlagReader):
    decision_kind = PolicyDecisionKind.FEATURE_FLAG
    model_type = FeatureFlagDecisionRef

    def read(self, evaluation_id: str) -> PolicyReadResult:
        return self._read_exact(evaluation_id)


class FirestoreEntitlementReader(_FirestorePolicyReader, EntitlementReader):
    decision_kind = PolicyDecisionKind.ENTITLEMENT
    model_type = EntitlementDecisionRef

    def read(self, decision_id: str) -> PolicyReadResult:
        return self._read_exact(decision_id)


class FirestoreBudgetDecisionReader(_FirestorePolicyReader, BudgetDecisionReader):
    decision_kind = PolicyDecisionKind.BUDGET
    model_type = BudgetDecisionRef

    def read(self, decision_id: str) -> PolicyReadResult:
        return self._read_exact(decision_id)


class FirestoreSafetyDecisionReader(_FirestorePolicyReader, SafetyDecisionReader):
    decision_kind = PolicyDecisionKind.SAFETY
    model_type = SafetyDecisionRef

    def read(self, decision_id: str) -> PolicyReadResult:
        return self._read_exact(decision_id)


__all__ = [
    "BudgetDecisionReader",
    "EntitlementReader",
    "FeatureFlagReader",
    "FirestoreBudgetDecisionReader",
    "FirestoreEntitlementReader",
    "FirestoreFeatureFlagReader",
    "FirestoreSafetyDecisionReader",
    "InMemoryBudgetDecisionReader",
    "InMemoryEntitlementReader",
    "InMemoryFeatureFlagReader",
    "InMemorySafetyDecisionReader",
    "KillSwitchDecisionRef",
    "KillSwitchDisposition",
    "PolicyCompositionResult",
    "PolicyDecisionKind",
    "PolicyDecisionStatus",
    "PolicyEvaluationSnapshot",
    "PolicyReadResult",
    "PolicyReadStatus",
    "SafetyDecisionReader",
    "build_policy_snapshot",
    "compose_ai_policy_decision",
]
