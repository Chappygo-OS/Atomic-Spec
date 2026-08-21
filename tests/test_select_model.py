"""End-to-end smoke test for the `atomicspec select-model` subcommand.

Uses Typer's CliRunner so the test exercises the full command wiring (option
parsing, exit code contract, stdout format). See `test_registry_efficiency.py`
for the underlying `_registry` module unit tests.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from typer.testing import CliRunner

from specify_cli import app

runner = CliRunner()


REGISTRY_ADVISOR_ON = """\
version: 6
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl:        claude-opus-4-7
  advisor_enabled: true
"""

REGISTRY_ADVISOR_OFF = REGISTRY_ADVISOR_ON.replace(
    "advisor_enabled: true", "advisor_enabled: false"
)


def _lay_out_project(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, registry_yaml: str
) -> None:
    (tmp_path / "specs" / "_defaults").mkdir(parents=True)
    (tmp_path / "specs" / "_defaults" / "registry.yaml").write_text(
        registry_yaml, encoding="utf-8"
    )
    monkeypatch.chdir(tmp_path)


def test_select_model_prints_model_when_advisor_on(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out_project(tmp_path, monkeypatch, REGISTRY_ADVISOR_ON)
    result = runner.invoke(app, ["select-model", "--phase", "coordinator"])
    assert result.exit_code == 0
    assert result.stdout.strip() == "claude-haiku-4-5"


def test_select_model_prints_empty_when_advisor_off(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out_project(tmp_path, monkeypatch, REGISTRY_ADVISOR_OFF)
    result = runner.invoke(app, ["select-model", "--phase", "coordinator"])
    assert result.exit_code == 0
    assert result.stdout.strip() == ""


def test_select_model_prints_empty_when_registry_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)
    result = runner.invoke(app, ["select-model", "--phase", "coordinator"])
    assert result.exit_code == 0
    assert result.stdout.strip() == ""


def test_select_model_all_three_phases_resolve(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _lay_out_project(tmp_path, monkeypatch, REGISTRY_ADVISOR_ON)
    expected = {
        "coordinator": "claude-haiku-4-5",
        "implementer": "claude-sonnet-4-6",
        "hitl": "claude-opus-4-7",
    }
    for phase, model in expected.items():
        result = runner.invoke(app, ["select-model", "--phase", phase])
        assert result.exit_code == 0, f"phase {phase} failed: {result.output}"
        assert result.stdout.strip() == model
