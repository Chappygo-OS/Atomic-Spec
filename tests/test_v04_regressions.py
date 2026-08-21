"""Regression tests for v0.4 review-panel findings.

Every test here covers a specific bug that shipped in the first-draft
v0.4 code and was fixed after adversarial review:

- Quoted 'false' silently flipping advisor ON (bool coercion)
- Windows path in --note corrupting the snapshot (YAML \\U escape)
- Multi-line --note collapsing to a single line
- BOM-prefixed snapshots ignored by the report
- Same-day + same-scope snapshot filename collision (silent overwrite)
- --phase typo silently succeeding with empty output
- Report sorting alphabetically by filename instead of by recorded_at
- Feature filter collision on "42" vs "042" vs "1042"
"""

from __future__ import annotations

from pathlib import Path

import pytest
from typer.testing import CliRunner

from specify_cli import app, _parse_snapshot_frontmatter
from specify_cli._registry import resolve_tier

runner = CliRunner()


# ---------------------------------------------------------------------------
# Advisor bool coercion (regression: bool("false") == True)
# ---------------------------------------------------------------------------


def _write_registry(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, yaml_text: str) -> None:
    (tmp_path / "specs" / "_defaults").mkdir(parents=True)
    (tmp_path / "specs" / "_defaults" / "registry.yaml").write_text(
        yaml_text, encoding="utf-8"
    )
    monkeypatch.chdir(tmp_path)


@pytest.mark.parametrize(
    "quoted_value",
    ["'false'", '"false"', "'no'", '"no"', "'off'"],
)
def test_advisor_enabled_quoted_string_stays_off(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, quoted_value: str
) -> None:
    """Quoted YAML strings must NOT flip advisor on regardless of Python bool()."""
    _write_registry(
        tmp_path,
        monkeypatch,
        f"""\
version: 6
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl: claude-opus-4-7
  advisor_enabled: {quoted_value}
""",
    )
    result = resolve_tier("coordinator")
    assert result.model is None, (
        f"advisor_enabled: {quoted_value} must not resolve a tier; "
        f"got {result.model!r} with reason {result.reason!r}"
    )
    assert result.advisor_enabled is False


def test_advisor_enabled_int_1_stays_off(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Integer 1 in the switch position must not enable the advisor either."""
    _write_registry(
        tmp_path,
        monkeypatch,
        """\
version: 6
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl: claude-opus-4-7
  advisor_enabled: 1
""",
    )
    result = resolve_tier("coordinator")
    assert result.model is None


def test_advisor_enabled_real_true_still_works(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Sanity check: an unquoted `true` still enables the advisor."""
    _write_registry(
        tmp_path,
        monkeypatch,
        """\
version: 6
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl: claude-opus-4-7
  advisor_enabled: true
""",
    )
    result = resolve_tier("coordinator")
    assert result.model == "claude-haiku-4-5"
    assert result.advisor_enabled is True


# ---------------------------------------------------------------------------
# select-model --phase validation (regression: typo silently returned empty)
# ---------------------------------------------------------------------------


def test_select_model_rejects_unknown_phase(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A typo in --phase must fail with non-zero exit + Typer error, not silent empty."""
    monkeypatch.chdir(tmp_path)
    result = runner.invoke(app, ["select-model", "--phase", "coord"])
    assert result.exit_code != 0, (
        f"expected non-zero exit for typo phase; got {result.exit_code} "
        f"with stdout={result.stdout!r}"
    )
    combined = (result.stdout + (result.stderr or "")).lower()
    assert (
        "coord" in combined
        or "invalid" in combined
        or "choose from" in combined
        or "not one of" in combined
    ), f"expected helpful error, got {result.output!r}"


# ---------------------------------------------------------------------------
# cost snapshot: Windows paths and multiline notes (regression: YAML escape)
# ---------------------------------------------------------------------------


def _run_snapshot(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, note: str
) -> Path:
    monkeypatch.chdir(tmp_path)
    result = runner.invoke(
        app,
        [
            "cost",
            "snapshot",
            "--amount",
            "1.50",
            "--provider",
            "anthropic",
            "--source",
            "paste",
            "--feature",
            "042",
            "--note",
            note,
        ],
    )
    assert result.exit_code == 0, f"snapshot failed: {result.output}"
    files = list((tmp_path / ".specify" / "efficiency-snapshots").glob("*.md"))
    assert len(files) == 1, f"expected one snapshot, got {files}"
    return files[0]


def test_cost_snapshot_windows_path_in_note_round_trips(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A Windows-style path in --note must serialize and parse back cleanly."""
    windows_note = r"pasted from C:\Users\dev\Downloads\anthropic-usage.csv"
    snapshot_path = _run_snapshot(tmp_path, monkeypatch, windows_note)
    parsed = _parse_snapshot_frontmatter(snapshot_path.read_text(encoding="utf-8"))
    assert parsed, f"frontmatter unparseable: {snapshot_path.read_text(encoding='utf-8')}"
    assert parsed.get("note") == windows_note, (
        f"note round-trip failed; sent {windows_note!r}, got {parsed.get('note')!r}"
    )
    assert parsed.get("amount_usd") == 1.5
    assert parsed.get("provider") == "anthropic"


def test_cost_snapshot_multiline_note_preserved(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A multi-line --note must not collapse to a single line."""
    multiline_note = "line one\nline two\nline three"
    snapshot_path = _run_snapshot(tmp_path, monkeypatch, multiline_note)
    body = snapshot_path.read_text(encoding="utf-8")
    parsed = _parse_snapshot_frontmatter(body)
    assert parsed.get("note") == multiline_note
    # Prose rendering must keep the lines as separate lines (fenced code block)
    assert "line one" in body and "line two" in body and "line three" in body
    assert "line one line two line three" not in body


# ---------------------------------------------------------------------------
# cost snapshot: filename collision (regression: same-day+same-scope overwrote)
# ---------------------------------------------------------------------------


def test_two_snapshots_same_day_same_scope_do_not_overwrite(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Second snapshot on the same day for the same feature must not clobber the first."""
    monkeypatch.chdir(tmp_path)
    for run_idx in (1, 2):
        result = runner.invoke(
            app,
            [
                "cost",
                "snapshot",
                "--amount",
                f"{run_idx}.50",
                "--provider",
                "anthropic",
                "--feature",
                "042",
                "--note",
                f"run {run_idx}",
            ],
        )
        assert result.exit_code == 0, f"snapshot {run_idx} failed: {result.output}"
    files = sorted((tmp_path / ".specify" / "efficiency-snapshots").glob("*.md"))
    assert len(files) == 2, (
        f"expected two distinct snapshot files, got {[f.name for f in files]}"
    )


# ---------------------------------------------------------------------------
# _parse_snapshot_frontmatter: BOM tolerance (regression: silent empty parse)
# ---------------------------------------------------------------------------


def test_parse_snapshot_frontmatter_tolerates_bom() -> None:
    """A BOM-prefixed snapshot file must still parse correctly."""
    body = "\ufeff---\nkind: efficiency-snapshot\nfeature: '042'\namount_usd: 1.5\n---\n\n# heading\n"
    parsed = _parse_snapshot_frontmatter(body)
    assert parsed, "BOM-prefixed frontmatter parsed as empty"
    assert parsed.get("kind") == "efficiency-snapshot"
    assert parsed.get("feature") == "042"
    assert parsed.get("amount_usd") == 1.5


def test_parse_snapshot_frontmatter_ignores_non_frontmatter() -> None:
    """A body without a leading `---` returns {} (not a crash)."""
    assert _parse_snapshot_frontmatter("just prose, no frontmatter") == {}


def test_parse_snapshot_frontmatter_unclosed_delimiter_returns_empty() -> None:
    """A `---` open without a matching close returns {} (not a crash)."""
    assert _parse_snapshot_frontmatter("---\nkey: value\n") == {}


# ---------------------------------------------------------------------------
# efficiency report: feature filter must not collide on numeric suffix
# ---------------------------------------------------------------------------


def test_efficiency_report_feature_filter_does_not_collide(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """`--feature 42` must not match snapshots for feature `042` or `142`."""
    monkeypatch.chdir(tmp_path)
    for feature in ("42", "042", "142"):
        result = runner.invoke(
            app,
            [
                "cost",
                "snapshot",
                "--amount",
                "1.00",
                "--provider",
                "anthropic",
                "--feature",
                feature,
                "--note",
                f"snap for {feature}",
            ],
        )
        assert result.exit_code == 0
    result = runner.invoke(
        app, ["efficiency", "report", "--advisory", "--feature", "42"]
    )
    assert result.exit_code == 0
    stdout = result.stdout
    # Must show feature 42, NOT 042 or 142
    assert "snap for 42" not in stdout  # note is not in the report; use feature scope
    assert "feature 42" in stdout
    # Anti-collision: 042 and 142 must NOT appear as scopes in this filtered view
    assert "feature 042" not in stdout
    assert "feature 142" not in stdout
