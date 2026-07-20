"""Boundary tests for the abstract NAJM Provider Adapter contract."""

import ast
import inspect
from pathlib import Path

import pytest

from ai_platform.contracts import (
    AIGatewayRequest,
    AIGatewayResponse,
    AIErrorDetail,
    ErrorFactState,
    ProviderCapability,
    ProviderCapabilityMetadata,
    ProviderConfigurationStatus,
    ProviderHealthStatus,
    ProviderRegistryRef,
)
from ai_platform.errors import ProviderErrorCode
from ai_platform.provider_adapter import ProviderAdapter, ProviderAdapterError


PYTHON_SERVICES = Path(__file__).resolve().parents[2]
AI_PLATFORM_PACKAGE = PYTHON_SERVICES / "ai_platform"


class _IncompleteAdapter(ProviderAdapter):
    pass


class _ContractOnlyAdapter(ProviderAdapter):
    """Test double with no SDK, secrets, network calls, or provider behavior."""

    @property
    def adapter_key(self) -> str:
        return "adapter.test"

    @property
    def contract_version(self) -> str:
        return "1"

    @property
    def provider(self) -> ProviderRegistryRef:
        return ProviderRegistryRef(
            provider_key="provider.test",
            registry_revision="provider-rev-1",
            adapter_key=self.adapter_key,
            adapter_contract_version=self.contract_version,
            lifecycle="enabled",
        )

    @property
    def capabilities(self) -> frozenset[ProviderCapability]:
        return frozenset({ProviderCapability.TEXT_GENERATION})

    def capability_metadata(self) -> tuple[ProviderCapabilityMetadata, ...]:
        return (
            ProviderCapabilityMetadata(
                capability=ProviderCapability.TEXT_GENERATION,
                limit_refs=("model-limit-policy-1",),
                usage_detail_supported=True,
            ),
        )

    def configuration_status(self) -> ProviderConfigurationStatus:
        return ProviderConfigurationStatus.CONFIGURED

    async def execute(self, request: AIGatewayRequest) -> AIGatewayResponse:
        raise NotImplementedError("contract test double does not execute providers")

def _imported_modules(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
    return imported


def test_provider_adapter_is_abstract_until_fully_implemented():
    assert inspect.isabstract(ProviderAdapter)
    assert ProviderAdapter.__abstractmethods__ == {
        "adapter_key",
        "capability_metadata",
        "capabilities",
        "configuration_status",
        "contract_version",
        "execute",
        "provider",
    }
    with pytest.raises(TypeError):
        _IncompleteAdapter()


def test_contract_only_adapter_exposes_provider_neutral_metadata():
    adapter = _ContractOnlyAdapter()
    assert adapter.adapter_key == "adapter.test"
    assert adapter.provider.provider_key == "provider.test"
    assert adapter.capabilities == frozenset({ProviderCapability.TEXT_GENERATION})
    assert adapter.capability_metadata()[0].limit_refs == ("model-limit-policy-1",)
    assert adapter.configuration_status() is ProviderConfigurationStatus.CONFIGURED
    assert not hasattr(adapter, "api_key")


def test_adapter_error_carries_only_normalized_failure_facts():
    details = AIErrorDetail(
        provider_code=ProviderErrorCode.TIMEOUT,
        same_route_retry_safe=True,
        execution_may_have_occurred=False,
        usage_state=ErrorFactState.KNOWN_ZERO,
        cost_state=ErrorFactState.KNOWN_ZERO,
        diagnostic_code="timeout_before_execution",
        provider_request_id="provider-request-1",
    )
    error = ProviderAdapterError(details)
    assert error.details == details
    assert str(error) == "timeout"
    assert error.details.provider_request_id == "provider-request-1"
    assert "safe_message" not in AIErrorDetail.model_fields


@pytest.mark.asyncio
async def test_optional_health_check_has_no_default_probe_behavior():
    with pytest.raises(NotImplementedError, match="optional"):
        await _ContractOnlyAdapter().health_check()

    assert ProviderHealthStatus.UNKNOWN.value == "unknown"


def test_new_package_has_no_provider_sdk_or_network_dependencies():
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
    # This is a Phase 2 inert-scaffold gate. A later adapter phase must scope
    # concrete provider dependencies to approved adapter modules.
    for path in sorted(AI_PLATFORM_PACKAGE.rglob("*.py")):
        imported = _imported_modules(path)
        blocked = sorted(
            module
            for module in imported
            if module.split(".", maxsplit=1)[0] in prohibited_roots
        )
        if blocked:
            violations[path.name] = blocked
    assert violations == {}


def test_existing_runtime_modules_do_not_import_ai_platform():
    # This is intentionally a Phase 2-only no-wiring assertion.
    violations: dict[str, list[str]] = {}
    for path in sorted(PYTHON_SERVICES.rglob("*.py")):
        relative = path.relative_to(PYTHON_SERVICES)
        if relative.parts[0] in {"ai_platform", "tests", ".venv"}:
            continue
        imported = _imported_modules(path)
        matches = sorted(
            module
            for module in imported
            if module == "ai_platform" or module.startswith("ai_platform.")
        )
        if matches:
            violations[str(relative)] = matches
    assert violations == {}


def test_adapter_interface_does_not_own_business_policy():
    public_members = {
        name for name, _ in inspect.getmembers(ProviderAdapter) if not name.startswith("_")
    }
    prohibited = {
        "route",
        "fallback",
        "entitlement",
        "subscription",
        "credit",
        "billing",
        "prompt",
        "tool",
    }
    assert public_members.isdisjoint(prohibited)
