"""Immutable prompt assets and deterministic, provider-neutral rendering.

The module is inert and storage-agnostic. It does not resolve activation,
authorize variables, call providers, initialize Firebase, log prompt content,
or persist templates or rendered messages.
"""

from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from abc import ABC, abstractmethod
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, SecretStr, model_validator

from .contracts import (
    AIMessageRole,
    NormalizedMessage,
    PromptLifecycleState,
    PromptRegistryRef,
)


CANONICALIZATION_VERSION = "prompt-text-v1"
_VARIABLE_NAME = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
_FORBIDDEN_VARIABLE_NAMES = {
    "access_token",
    "api_key",
    "authorization",
    "authorization_header",
    "credential",
    "credentials",
    "firebase_token",
    "model_override",
    "password",
    "prompt_body",
    "provider_api_key",
    "provider_endpoint",
    "provider_override",
    "raw_prompt",
    "secret",
    "secret_key",
    "service_token",
}
_FORBIDDEN_VARIABLE_PARTS = {
    "credential",
    "credentials",
    "password",
    "secret",
    "token",
}


class PromptContentReadStatus(str, Enum):
    FOUND = "found"
    MISSING = "missing"


class PromptRenderErrorCode(str, Enum):
    CONTENT_MISSING = "content_missing"
    IDENTITY_MISMATCH = "identity_mismatch"
    LIFECYCLE_INELIGIBLE = "lifecycle_ineligible"
    TEMPLATE_INVALID = "template_invalid"
    CONTENT_HASH_MISMATCH = "content_hash_mismatch"
    INVALID_VARIABLE_NAME = "invalid_variable_name"
    FORBIDDEN_VARIABLE_NAME = "forbidden_variable_name"
    DUPLICATE_VARIABLE_DECLARATION = "duplicate_variable_declaration"
    DUPLICATE_VARIABLE_VALUE = "duplicate_variable_value"
    UNKNOWN_VARIABLE = "unknown_variable"
    MISSING_VARIABLE = "missing_variable"
    UNUSED_VARIABLE_DECLARATION = "unused_variable_declaration"
    VARIABLE_VALUE_TOO_LARGE = "variable_value_too_large"
    READER_FAILURE = "reader_failure"


class PromptRenderError(Exception):
    """Stable rendering failure that never contains template or variable data."""

    def __init__(self, code: PromptRenderErrorCode) -> None:
        self.code = code
        super().__init__(code.value)


class _PromptModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        frozen=True,
        str_strip_whitespace=True,
        validate_default=True,
        allow_inf_nan=False,
        hide_input_in_errors=True,
        protected_namespaces=(),
    )


class PromptVariableDefinition(_PromptModel):
    name: str = Field(min_length=1, max_length=64)
    required: bool = True
    max_length: int = Field(ge=1)

    @model_validator(mode="after")
    def variable_name_is_safe(self) -> "PromptVariableDefinition":
        _validate_variable_name(self.name)
        return self


class PromptVariableValue(_PromptModel):
    """A supplied value whose representations and serialization stay redacted.

    ``SecretStr`` protects the value only before rendering. Once substituted
    into ``NormalizedMessage.content``, the rendered prompt necessarily exists
    in plaintext for downstream execution and must not be logged or persisted.
    """

    name: str = Field(min_length=1, max_length=64)
    value: SecretStr = Field(repr=False)

    @model_validator(mode="after")
    def variable_name_is_safe(self) -> "PromptVariableValue":
        _validate_variable_name(self.name)
        return self


class PromptContentAsset(_PromptModel):
    prompt: PromptRegistryRef
    template: SecretStr = Field(repr=False)
    variables: tuple[PromptVariableDefinition, ...] = ()
    message_role: AIMessageRole
    output_contract_ref: str = Field(min_length=1, max_length=200)
    canonicalization_version: str = CANONICALIZATION_VERSION

    @model_validator(mode="after")
    def asset_contract_is_consistent(self) -> "PromptContentAsset":
        if self.canonicalization_version != CANONICALIZATION_VERSION:
            raise ValueError("unsupported canonicalization version")
        names = [item.name for item in self.variables]
        if len(names) != len(set(names)):
            raise ValueError("duplicate variable declaration")
        return self


class PromptContentReadResult(_PromptModel):
    status: PromptContentReadStatus
    prompt: PromptRegistryRef
    asset: PromptContentAsset | None = None

    @model_validator(mode="after")
    def result_is_consistent(self) -> "PromptContentReadResult":
        if self.status is PromptContentReadStatus.FOUND:
            if self.asset is None:
                raise ValueError("found prompt content requires an asset")
        elif self.asset is not None:
            raise ValueError("missing prompt content cannot expose an asset")
        return self


class PromptRenderRequest(_PromptModel):
    prompt: PromptRegistryRef
    variables: tuple[PromptVariableValue, ...] = ()


class PromptRenderResult(_PromptModel):
    prompt: PromptRegistryRef
    message: NormalizedMessage
    template_content_hash: str = Field(min_length=1, max_length=200)
    render_instance_fingerprint: str = Field(min_length=1, max_length=200)
    canonicalization_version: str = CANONICALIZATION_VERSION


class PromptContentReader(ABC):
    """Pure exact-read boundary for immutable prompt content assets."""

    @abstractmethod
    def read(self, prompt: PromptRegistryRef) -> PromptContentReadResult:
        """Return one exact asset or an explicit missing result."""


class InMemoryPromptContentReader(PromptContentReader):
    """Deterministic injected reader for tests and composition."""

    def __init__(self, assets: tuple[PromptContentAsset, ...] = ()) -> None:
        indexed: dict[tuple[str, str, str], PromptContentAsset] = {}
        for asset in assets:
            identity = _prompt_identity(asset.prompt)
            if identity in indexed:
                raise ValueError("duplicate prompt content identity")
            indexed[identity] = asset
        self._assets = indexed

    def read(self, prompt: PromptRegistryRef) -> PromptContentReadResult:
        asset = self._assets.get(_prompt_identity(prompt))
        if asset is None:
            return PromptContentReadResult(
                status=PromptContentReadStatus.MISSING,
                prompt=prompt,
            )
        return PromptContentReadResult(
            status=PromptContentReadStatus.FOUND,
            prompt=asset.prompt,
            asset=asset,
        )


class PromptRenderer:
    """Render exact immutable prompt assets without storage or authorization."""

    def __init__(self, reader: PromptContentReader) -> None:
        if not isinstance(reader, PromptContentReader):
            raise TypeError("PromptRenderer requires a PromptContentReader")
        self._reader = reader

    def render(self, request: PromptRenderRequest) -> PromptRenderResult:
        if not isinstance(request, PromptRenderRequest):
            raise TypeError("render requires a PromptRenderRequest")
        try:
            read_result = self._reader.read(request.prompt)
        except PromptRenderError:
            raise
        except Exception:
            raise PromptRenderError(PromptRenderErrorCode.READER_FAILURE) from None

        if read_result.status is not PromptContentReadStatus.FOUND:
            raise PromptRenderError(PromptRenderErrorCode.CONTENT_MISSING)
        asset = read_result.asset
        if asset is None:
            raise PromptRenderError(PromptRenderErrorCode.CONTENT_MISSING)
        if asset.prompt != request.prompt or read_result.prompt != request.prompt:
            raise PromptRenderError(PromptRenderErrorCode.IDENTITY_MISMATCH)
        if request.prompt.lifecycle is not PromptLifecycleState.ACTIVE:
            raise PromptRenderError(PromptRenderErrorCode.LIFECYCLE_INELIGIBLE)

        canonical_template = canonicalize_template(asset.template.get_secret_value())
        template_hash = hash_canonical_template(canonical_template)
        if template_hash != request.prompt.content_hash:
            raise PromptRenderError(PromptRenderErrorCode.CONTENT_HASH_MISMATCH)

        tokens, placeholder_names = _tokenize_template(canonical_template)
        definitions = _validate_definitions(asset.variables, placeholder_names)
        values = _validate_values(request.variables, definitions)
        rendered = _render_tokens(tokens, values)
        message = NormalizedMessage(role=asset.message_role, content=rendered)
        fingerprint = _render_fingerprint(
            request.prompt,
            template_hash=template_hash,
            canonicalization_version=asset.canonicalization_version,
            variable_names=tuple(definitions),
        )
        return PromptRenderResult(
            prompt=request.prompt,
            message=message,
            template_content_hash=template_hash,
            render_instance_fingerprint=fingerprint,
            canonicalization_version=asset.canonicalization_version,
        )


def canonicalize_template(template: str) -> str:
    """Canonicalize the immutable template asset, never rendered output."""

    if not isinstance(template, str) or "\x00" in template:
        raise PromptRenderError(PromptRenderErrorCode.TEMPLATE_INVALID)
    normalized_lines = template.replace("\r\n", "\n").replace("\r", "\n")
    return unicodedata.normalize("NFC", normalized_lines)


def hash_canonical_template(canonical_template: str) -> str:
    """Return the current SHA-256 digest without encoding an algorithm prefix."""

    if not isinstance(canonical_template, str):
        raise PromptRenderError(PromptRenderErrorCode.TEMPLATE_INVALID)
    return hashlib.sha256(canonical_template.encode("utf-8")).hexdigest()


def _validate_variable_name(name: str) -> None:
    if not _VARIABLE_NAME.fullmatch(name):
        raise ValueError(PromptRenderErrorCode.INVALID_VARIABLE_NAME.value)
    parts = set(name.split("_"))
    if (
        name in _FORBIDDEN_VARIABLE_NAMES
        or "api_key" in name
        or parts & _FORBIDDEN_VARIABLE_PARTS
    ):
        raise ValueError(PromptRenderErrorCode.FORBIDDEN_VARIABLE_NAME.value)


def _prompt_identity(prompt: PromptRegistryRef) -> tuple[str, str, str]:
    return (
        prompt.prompt_family_key,
        prompt.prompt_version,
        prompt.registry_revision,
    )


def _tokenize_template(template: str) -> tuple[tuple[tuple[str, str], ...], tuple[str, ...]]:
    tokens: list[tuple[str, str]] = []
    names: list[str] = []
    text_start = 0
    cursor = 0
    while cursor < len(template):
        if template.startswith("}}", cursor):
            raise PromptRenderError(PromptRenderErrorCode.TEMPLATE_INVALID)
        if not template.startswith("{{", cursor):
            cursor += 1
            continue
        if cursor > text_start:
            tokens.append(("text", template[text_start:cursor]))
        close = template.find("}}", cursor + 2)
        if close < 0:
            raise PromptRenderError(PromptRenderErrorCode.TEMPLATE_INVALID)
        name = template[cursor + 2 : close]
        if "{{" in name or "}" in name or not _VARIABLE_NAME.fullmatch(name):
            raise PromptRenderError(PromptRenderErrorCode.INVALID_VARIABLE_NAME)
        try:
            _validate_variable_name(name)
        except ValueError as exc:
            code = PromptRenderErrorCode(str(exc))
            raise PromptRenderError(code) from None
        tokens.append(("variable", name))
        names.append(name)
        cursor = close + 2
        text_start = cursor
    if text_start < len(template):
        tokens.append(("text", template[text_start:]))
    return tuple(tokens), tuple(names)


def _validate_definitions(
    definitions: tuple[PromptVariableDefinition, ...],
    placeholder_names: tuple[str, ...],
) -> dict[str, PromptVariableDefinition]:
    indexed: dict[str, PromptVariableDefinition] = {}
    for definition in definitions:
        if definition.name in indexed:
            raise PromptRenderError(
                PromptRenderErrorCode.DUPLICATE_VARIABLE_DECLARATION
            )
        indexed[definition.name] = definition
    placeholders = set(placeholder_names)
    if placeholders - set(indexed):
        raise PromptRenderError(PromptRenderErrorCode.UNKNOWN_VARIABLE)
    if set(indexed) - placeholders:
        raise PromptRenderError(PromptRenderErrorCode.UNUSED_VARIABLE_DECLARATION)
    return indexed


def _validate_values(
    supplied: tuple[PromptVariableValue, ...],
    definitions: dict[str, PromptVariableDefinition],
) -> dict[str, str]:
    values: dict[str, str] = {}
    for item in supplied:
        if item.name in values:
            raise PromptRenderError(PromptRenderErrorCode.DUPLICATE_VARIABLE_VALUE)
        definition = definitions.get(item.name)
        if definition is None:
            raise PromptRenderError(PromptRenderErrorCode.UNKNOWN_VARIABLE)
        value = item.value.get_secret_value()
        if len(value) > definition.max_length:
            raise PromptRenderError(PromptRenderErrorCode.VARIABLE_VALUE_TOO_LARGE)
        values[item.name] = value
    missing = {
        name
        for name, definition in definitions.items()
        if definition.required and name not in values
    }
    if missing:
        raise PromptRenderError(PromptRenderErrorCode.MISSING_VARIABLE)
    return values


def _render_tokens(
    tokens: tuple[tuple[str, str], ...],
    values: dict[str, str],
) -> str:
    parts: list[str] = []
    for kind, value in tokens:
        if kind == "text":
            parts.append(value)
        else:
            parts.append(values.get(value, "{{" + value + "}}"))
    return "".join(parts)


def _render_fingerprint(
    prompt: PromptRegistryRef,
    *,
    template_hash: str,
    canonicalization_version: str,
    variable_names: tuple[str, ...],
) -> str:
    payload = {
        "prompt_family_key": prompt.prompt_family_key,
        "prompt_version": prompt.prompt_version,
        "registry_revision": prompt.registry_revision,
        "template_content_hash": template_hash,
        "canonicalization_version": canonicalization_version,
        "variable_names": variable_names,
    }
    serialized = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


__all__ = [
    "CANONICALIZATION_VERSION",
    "InMemoryPromptContentReader",
    "PromptContentAsset",
    "PromptContentReadResult",
    "PromptContentReadStatus",
    "PromptContentReader",
    "PromptRenderError",
    "PromptRenderErrorCode",
    "PromptRenderRequest",
    "PromptRenderResult",
    "PromptRenderer",
    "PromptVariableDefinition",
    "PromptVariableValue",
    "canonicalize_template",
    "hash_canonical_template",
]
