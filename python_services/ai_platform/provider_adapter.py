"""Abstract provider-neutral adapter boundary for the NAJM AI Platform."""

from __future__ import annotations

from abc import ABC, abstractmethod

from .contracts import (
    AIGatewayRequest,
    AIGatewayResponse,
    AIErrorDetail,
    ProviderCapability,
    ProviderCapabilityMetadata,
    ProviderConfigurationStatus,
    ProviderHealthStatus,
    ProviderRegistryRef,
)


class ProviderAdapterError(Exception):
    """Normalized adapter failure without a raw provider exception or payload."""

    def __init__(self, details: AIErrorDetail) -> None:
        if details.provider_code is None:
            raise ValueError("ProviderAdapterError requires a provider error code")
        self.details = details
        super().__init__(details.provider_code.value)


class ProviderAdapter(ABC):
    """Contract implemented later by one adapter for one provider family.

    Concrete adapters may translate and invoke only their registered provider.
    Routing, fallback, safety, entitlements, credits, and billing remain outside
    this interface.
    """

    @property
    @abstractmethod
    def adapter_key(self) -> str:
        """Return the stable NAJM adapter key."""

    @property
    @abstractmethod
    def contract_version(self) -> str:
        """Return the normalized adapter contract version."""

    @property
    @abstractmethod
    def provider(self) -> ProviderRegistryRef:
        """Return the immutable Provider Registry reference for this adapter."""

    @property
    @abstractmethod
    def capabilities(self) -> frozenset[ProviderCapability]:
        """Return capabilities the adapter can faithfully normalize."""

    @abstractmethod
    def capability_metadata(self) -> tuple[ProviderCapabilityMetadata, ...]:
        """Return modality, limit, usage, and known-limitation references."""

    @abstractmethod
    def configuration_status(self) -> ProviderConfigurationStatus:
        """Return configured/unconfigured status without exposing secret values."""

    @abstractmethod
    async def execute(self, request: AIGatewayRequest) -> AIGatewayResponse:
        """Execute one normalized Gateway attempt in a concrete adapter."""

    async def health_check(self) -> ProviderHealthStatus:
        """Optional non-billable health signal for a future concrete adapter."""

        raise NotImplementedError("health_check is optional for concrete adapters")
