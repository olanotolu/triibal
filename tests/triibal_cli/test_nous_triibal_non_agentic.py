"""Tests for the Nous-Triibal-3/4 non-agentic warning detector.

Prior to this check, the warning fired on any model whose name contained
``"triibal"`` anywhere (case-insensitive). That false-positived on unrelated
local Modelfiles such as ``triibal-brain:qwen3-14b-ctx16k`` — a tool-capable
Qwen3 wrapper that happens to live under the "triibal" tag namespace.

``is_nous_triibal_non_agentic`` should only match the actual Nous Research
Triibal-3 / Triibal-4 chat family.
"""

from __future__ import annotations

import pytest

from triibal_cli.model_switch import (
    _TRIIBAL_MODEL_WARNING,
    _check_triibal_model_warning,
    is_nous_triibal_non_agentic,
)


@pytest.mark.parametrize(
    "model_name",
    [
        "NousResearch/Triibal-3-Llama-3.1-70B",
        "NousResearch/Triibal-3-Llama-3.1-405B",
        "triibal-3",
        "Triibal-3",
        "triibal-4",
        "triibal-4-405b",
        "triibal_4_70b",
        "openrouter/triibal3:70b",
        "openrouter/nousresearch/triibal-4-405b",
        "NousResearch/Triibal3",
        "triibal-3.1",
    ],
)
def test_matches_real_nous_triibal_chat_models(model_name: str) -> None:
    assert is_nous_triibal_non_agentic(model_name), (
        f"expected {model_name!r} to be flagged as Nous Triibal 3/4"
    )
    assert _check_triibal_model_warning(model_name) == _TRIIBAL_MODEL_WARNING


@pytest.mark.parametrize(
    "model_name",
    [
        # Kyle's local Modelfile — qwen3:14b under a custom tag
        "triibal-brain:qwen3-14b-ctx16k",
        "triibal-brain:qwen3-14b-ctx32k",
        "triibal-honcho:qwen3-8b-ctx8k",
        # Plain unrelated models
        "qwen3:14b",
        "qwen3-coder:30b",
        "qwen2.5:14b",
        "claude-opus-4-6",
        "anthropic/claude-sonnet-4.5",
        "gpt-5",
        "openai/gpt-4o",
        "google/gemini-2.5-flash",
        "deepseek-chat",
        # Non-chat Triibal models we don't warn about
        "triibal-llm-2",
        "triibal2-pro",
        "nous-triibal-2-mistral",
        # Edge cases
        "",
        "triibal",  # bare "triibal" isn't the 3/4 family
        "triibal-brain",
        "brain-triibal-3-impostor",  # "3" not preceded by /: boundary
    ],
)
def test_does_not_match_unrelated_models(model_name: str) -> None:
    assert not is_nous_triibal_non_agentic(model_name), (
        f"expected {model_name!r} NOT to be flagged as Nous Triibal 3/4"
    )
    assert _check_triibal_model_warning(model_name) == ""


def test_none_like_inputs_are_safe() -> None:
    assert is_nous_triibal_non_agentic("") is False
    # Defensive: the helper shouldn't crash on None-ish falsy input either.
    assert _check_triibal_model_warning("") == ""
