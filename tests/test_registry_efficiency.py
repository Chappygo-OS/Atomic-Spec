"""Smoke tests for the v0.4+ registry efficiency reader.

Scope: verify `load_registry()` returns the expected shape given a fixture
registry, and `resolve_tier()` honors `advisor_enabled` + graceful-degradation
contract. Full pytest+CI wiring is deferred to v0.4.1; these two files exist
so a maintainer can `pytest tests/` and see the invariants under test.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from specify_cli._registry import (
    VALID_PHASES,
    load_registry,
    resolve_tier,
)


REGISTRY_ADVISOR_ON = """\
version: 6
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl:        claude-opus-4-7
  advisor_enabled: true
"""

REGISTRY_ADVISOR_OFF = """\
version: 6
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl:        claude-opus-4-7
  advisor_enabled: false
"""

REGISTRY_MISSING_EFFICIENCY = """\
version: 6
architecture:
  pattern: monolith
"""

REGISTRY_MALFORMED = "this is: : malformed: yaml: [\nnot: closed"


def _lay_out(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, text: str) -> Path:
    (tmp_path / "specs" / "_defaults").mkdir(parents=True)
    (tmp_path / "specs" / "_defaults" / "registry.yaml").write_text(
        text, encoding="utf-8"
    )
    monkeypatch.chdir(tmp_path)
    return tmp_path


def test_load_registry_missing_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)
    assert load_registry() == {}


def test_load_registry_valid_shape(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_ADVISOR_ON)
    reg = load_registry()
    assert reg["version"] == 6
    assert reg["efficiency"]["advisor_enabled"] is True
    assert reg["efficiency"]["model_tiers"]["coordinator"] == "claude-haiku-4-5"
    assert reg["efficiency"]["model_tiers"]["implementer"] == "claude-sonnet-4-6"
    assert reg["efficiency"]["model_tiers"]["hitl"] == "claude-opus-4-7"


def test_load_registry_malformed_returns_empty(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_MALFORMED)
    assert load_registry() == {}


def test_resolve_tier_advisor_on(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_ADVISOR_ON)
    result = resolve_tier("coordinator")
    assert result.model == "claude-haiku-4-5"
    assert result.advisor_enabled is True
    assert result.reason == "resolved"


def test_resolve_tier_advisor_off(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_ADVISOR_OFF)
    result = resolve_tier("coordinator")
    assert result.model is None
    assert result.advisor_enabled is False
    assert result.reason == "advisor-disabled"


def test_resolve_tier_missing_efficiency_block(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_MISSING_EFFICIENCY)
    result = resolve_tier("coordinator")
    assert result.model is None
    assert result.reason == "efficiency-block-missing"


def test_resolve_tier_unknown_phase(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_ADVISOR_ON)
    result = resolve_tier("something-weird")
    assert result.model is None
    assert result.reason == "unknown-phase"


def test_resolve_tier_missing_registry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)
    result = resolve_tier("coordinator")
    assert result.model is None
    assert result.reason == "registry-missing"


def test_resolve_tier_all_valid_phases(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out(tmp_path, monkeypatch, REGISTRY_ADVISOR_ON)
    for phase in VALID_PHASES:
        result = resolve_tier(phase)
        assert result.model is not None, f"phase {phase} should resolve"
        assert result.reason == "resolved"
