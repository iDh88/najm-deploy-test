"""Tests for immutable prompt content and deterministic rendering."""

from __future__ import annotations

import ast
import inspect
import unicodedata
from pathlib import Path

import pytest
from pydantic import ValidationError

from ai_platform.contracts import (
    AIMessageRole,
    PromptLifecycleState,
    PromptRegistryRef,
)
from ai_platform.prompt_renderer import (
    CANONICALIZATION_VERSION,
    InMemoryPromptContentReader,
    PromptContentAsset,
    PromptContentReadStatus,
    PromptRenderError,
    PromptRenderErrorCode,
    PromptRenderRequest,
    PromptRenderer,
    PromptVariableDefinition,
    PromptVariableValue,
    canonicalize_template,
    hash_canonical_template,
)


ROOT = Path(__file__).resolve().parents[3]
MODULE = ROOT / "python_services" / "ai_platform" / "prompt_renderer.py"


def _prompt(
    template: str,
    *,
    lifecycle: PromptLifecycleState = PromptLifecycleState.ACTIVE,
    content_hash: str | None = None,
) -> PromptRegistryRef:
    canonical = canonicalize_template(template)
    return PromptRegistryRef(
        prompt_family_key="assistant.render-test",
        prompt_version="prompt-v1",
        registry_revision="prompt-rev-1",
        content_hash=content_hash or hash_canonical_template(canonical),
        lifecycle=lifecycle,
        rendering_key="provider-neutral.text.v1",
    )


def _asset(
    template: str = "Hello {{name}}",
    *,
    prompt: PromptRegistryRef | None = None,
    variables: tuple[PromptVariableDefinition, ...] | None = None,
) -> PromptContentAsset:
    return PromptContentAsset(
        prompt=prompt or _prompt(template),
        template=template,
        variables=variables
        if variables is not None
        else (PromptVariableDefinition(name="name", max_length=100),),
        message_role=AIMessageRole.SYSTEM,
        output_contract_ref="output.text.v1",
    )


def _request(
    asset: PromptContentAsset,
    *values: tuple[str, str],
) -> PromptRenderRequest:
    return PromptRenderRequest(
        prompt=asset.prompt,
        variables=tuple(
            PromptVariableValue(name=name, value=value) for name, value in values
        ),
    )


def _renderer(asset: PromptContentAsset) -> PromptRenderer:
    return PromptRenderer(InMemoryPromptContentReader((asset,)))


def _assert_error(code: PromptRenderErrorCode, operation) -> PromptRenderError:
    with pytest.raises(PromptRenderError) as captured:
        operation()
    assert captured.value.code is code
    return captured.value


def test_renders_exact_placeholder_with_immutable_provenance():
    asset = _asset()
    result = _renderer(asset).render(_request(asset, ("name", "Najm")))

    assert result.prompt == asset.prompt
    assert result.message.role is AIMessageRole.SYSTEM
    assert result.message.content == "Hello Najm"
    assert result.template_content_hash == asset.prompt.content_hash
    assert len(result.render_instance_fingerprint) == 64
    assert result.canonicalization_version == CANONICALIZATION_VERSION
    assert set(result.model_fields) == {
        "prompt",
        "message",
        "template_content_hash",
        "render_instance_fingerprint",
        "canonicalization_version",
    }


def test_rendering_is_deterministic_and_fingerprint_is_structural_only():
    asset = _asset()
    renderer = _renderer(asset)
    first = renderer.render(_request(asset, ("name", "Najm")))
    replay = renderer.render(_request(asset, ("name", "Najm")))
    changed = renderer.render(_request(asset, ("name", "NAJM")))

    assert first == replay
    assert first.template_content_hash == changed.template_content_hash
    assert first.render_instance_fingerprint == changed.render_instance_fingerprint


def test_render_fingerprint_uses_structural_inputs_not_rendered_prompt():
    from ai_platform import prompt_renderer

    source = inspect.getsource(prompt_renderer._render_fingerprint)
    assert "NormalizedMessage" not in source
    assert "message.content" not in source
    assert '"content"' not in source
    assert "value_hash" not in source
    assert "values" not in source
    assert "variable_names" in source


def test_overlapping_and_repeated_placeholders_resolve_as_complete_tokens():
    template = "{{a}}{{ab}}/{{a}}"
    asset = _asset(
        template,
        variables=(
            PromptVariableDefinition(name="a", max_length=10),
            PromptVariableDefinition(name="ab", max_length=10),
        ),
    )

    result = _renderer(asset).render(
        _request(asset, ("a", "X"), ("ab", "YZ"))
    )

    assert result.message.content == "XYZ/X"


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("مرحبا {{name}}", "مرحبا نجم"),
        ("Crew status: {{name}} ✈️", "Crew status: جاهز ✈️"),
        ("こんにちは {{name}}", "こんにちは ナジム"),
    ],
)
def test_arabic_emoji_and_japanese_render_after_nfc_template_normalization(
    text,
    expected,
):
    decomposed = unicodedata.normalize("NFD", text)
    asset = _asset(decomposed)
    value = expected.split(" ")[-1]
    if text.startswith("Crew"):
        value = "جاهز"
    result = _renderer(asset).render(_request(asset, ("name", value)))

    assert result.message.content == unicodedata.normalize("NFC", expected)


def test_template_canonicalization_normalizes_unicode_and_line_endings_only():
    raw = "  Cafe\u0301\r\n{{name}}  \r"
    canonical = canonicalize_template(raw)

    assert canonical == "  Café\n{{name}}  \n"
    assert canonical.startswith("  ")
    assert "  \n" in canonical


def test_rendered_variable_value_is_not_canonicalized():
    asset = _asset()
    decomposed = "Cafe\u0301"
    result = _renderer(asset).render(_request(asset, ("name", decomposed)))

    assert result.message.content.endswith(decomposed)
    assert not result.message.content.endswith(unicodedata.normalize("NFC", decomposed))


def test_content_hash_has_no_algorithm_prefix_and_mismatch_fails_closed():
    template = "Hello {{name}}"
    assert len(hash_canonical_template(canonicalize_template(template))) == 64
    assert ":" not in hash_canonical_template(canonicalize_template(template))
    asset = _asset(template, prompt=_prompt(template, content_hash="incorrect-hash"))

    _assert_error(
        PromptRenderErrorCode.CONTENT_HASH_MISMATCH,
        lambda: _renderer(asset).render(_request(asset, ("name", "secret-value"))),
    )


def test_missing_content_and_reader_failure_are_explicit_and_redacted():
    asset = _asset()
    missing = PromptRenderer(InMemoryPromptContentReader())
    _assert_error(
        PromptRenderErrorCode.CONTENT_MISSING,
        lambda: missing.render(_request(asset, ("name", "private-value"))),
    )

    class FailingReader(InMemoryPromptContentReader):
        def read(self, *_args):
            raise RuntimeError("storage leaked private-value")

    error = _assert_error(
        PromptRenderErrorCode.READER_FAILURE,
        lambda: PromptRenderer(FailingReader()).render(
            _request(asset, ("name", "private-value"))
        ),
    )
    assert "private-value" not in str(error)


def test_only_active_prompt_reference_is_renderable():
    template = "Hello {{name}}"
    prompt = _prompt(template, lifecycle=PromptLifecycleState.STAGED)
    asset = _asset(template, prompt=prompt)

    _assert_error(
        PromptRenderErrorCode.LIFECYCLE_INELIGIBLE,
        lambda: _renderer(asset).render(_request(asset, ("name", "Najm"))),
    )


def test_duplicate_asset_identity_is_rejected():
    asset = _asset()
    with pytest.raises(ValueError, match="duplicate prompt content identity"):
        InMemoryPromptContentReader((asset, asset))


def test_reader_is_exact_and_read_only():
    asset = _asset()
    reader = InMemoryPromptContentReader((asset,))
    found = reader.read(asset.prompt)
    missing = reader.read(
        asset.prompt.model_copy(update={"prompt_family_key": "other"})
    )

    assert found.status is PromptContentReadStatus.FOUND
    assert found.asset == asset
    assert missing.status is PromptContentReadStatus.MISSING
    assert "render" not in type(reader).__dict__


def test_duplicate_declarations_are_rejected_without_template_disclosure():
    secret_template = "Private {{name}}"
    with pytest.raises(ValidationError) as captured:
        _asset(
            secret_template,
            variables=(
                PromptVariableDefinition(name="name", max_length=10),
                PromptVariableDefinition(name="name", max_length=20),
            ),
        )

    assert secret_template not in str(captured.value)


def test_duplicate_supplied_entries_are_rejected_and_value_is_redacted():
    asset = _asset()
    secret = "crew-private-value"
    request = _request(asset, ("name", secret), ("name", secret))
    error = _assert_error(
        PromptRenderErrorCode.DUPLICATE_VARIABLE_VALUE,
        lambda: _renderer(asset).render(request),
    )

    assert secret not in str(error)
    assert secret not in repr(error)
    assert secret not in str(request)
    assert secret not in repr(request)
    assert secret not in request.model_dump_json()


def test_missing_unknown_unused_and_oversized_variables_fail_safely():
    asset = _asset()
    _assert_error(
        PromptRenderErrorCode.MISSING_VARIABLE,
        lambda: _renderer(asset).render(_request(asset)),
    )
    _assert_error(
        PromptRenderErrorCode.UNKNOWN_VARIABLE,
        lambda: _renderer(asset).render(_request(asset, ("other", "value"))),
    )

    unused = _asset(
        variables=(
            PromptVariableDefinition(name="name", max_length=100),
            PromptVariableDefinition(name="extra", max_length=100),
        )
    )
    _assert_error(
        PromptRenderErrorCode.UNUSED_VARIABLE_DECLARATION,
        lambda: _renderer(unused).render(_request(unused, ("name", "Najm"))),
    )

    bounded = _asset(
        variables=(PromptVariableDefinition(name="name", max_length=2),)
    )
    _assert_error(
        PromptRenderErrorCode.VARIABLE_VALUE_TOO_LARGE,
        lambda: _renderer(bounded).render(
            _request(bounded, ("name", "sensitive-long-value"))
        ),
    )


def test_missing_optional_variable_preserves_complete_placeholder_token():
    template = "Hello {{name}} from {{base}}"
    asset = _asset(
        template,
        variables=(
            PromptVariableDefinition(name="name", max_length=100),
            PromptVariableDefinition(name="base", required=False, max_length=10),
        ),
    )

    result = _renderer(asset).render(_request(asset, ("name", "Najm")))

    assert result.message.content == "Hello Najm from {{base}}"


@pytest.mark.parametrize(
    "template",
    (
        "Hello {{unknown}}",
        "Hello {{bad.name}}",
        "Hello {{name}",
        "Hello }}",
        "Hello {{{{name}}}}",
    ),
)
def test_invalid_or_undeclared_complete_tokens_are_rejected(template):
    asset = _asset(template)
    expected = (
        PromptRenderErrorCode.UNKNOWN_VARIABLE
        if template == "Hello {{unknown}}"
        else PromptRenderErrorCode.INVALID_VARIABLE_NAME
        if "bad.name" in template or "{{{{" in template
        else PromptRenderErrorCode.TEMPLATE_INVALID
    )
    _assert_error(
        expected,
        lambda: _renderer(asset).render(_request(asset, ("name", "value"))),
    )


@pytest.mark.parametrize(
    "name",
    (
        "api_key",
        "access_token",
        "provider_override",
        "model_override",
        "secret_value",
        "user_password",
    ),
)
def test_forbidden_variable_names_are_rejected(name):
    with pytest.raises(ValidationError) as captured:
        PromptVariableDefinition(name=name, max_length=10)
    assert PromptRenderErrorCode.FORBIDDEN_VARIABLE_NAME.value in str(captured.value)


def test_variable_value_never_appears_in_validation_error_repr_or_str():
    secret = "highly-sensitive-variable-value"
    with pytest.raises(ValidationError) as captured:
        PromptVariableValue(name="Invalid Name", value=secret)

    serialized_error = str(captured.value)
    assert secret not in serialized_error
    assert secret not in repr(captured.value)

    valid = PromptVariableValue(name="name", value=secret)
    assert secret not in str(valid)
    assert secret not in repr(valid)
    assert secret not in valid.model_dump_json()


def test_literal_single_braces_are_not_template_expressions():
    template = '{"answer": "{{name}}", "count": 1}'
    asset = _asset(template)
    result = _renderer(asset).render(_request(asset, ("name", "Najm")))

    assert result.message.content == '{"answer": "Najm", "count": 1}'


def test_no_dynamic_execution_or_runtime_dependencies_are_imported():
    tree = ast.parse(MODULE.read_text(encoding="utf-8"), filename=str(MODULE))
    imported = set()
    called_names = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported.add(node.module)
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            called_names.add(node.func.id)

    prohibited_imports = {
        "anthropic",
        "openai",
        "firebase_admin",
        "fastapi",
        "httpx",
        "requests",
    }
    assert not {name.split(".")[0] for name in imported} & prohibited_imports
    assert called_names.isdisjoint({"eval", "exec", "compile"})
