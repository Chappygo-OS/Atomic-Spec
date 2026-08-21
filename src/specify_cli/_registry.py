"""Registry reader for the v0.4+ efficiency block.

Reads `specs/_defaults/registry.yaml` and exposes two helpers used by the
`select-model`, `cost snapshot`, and `efficiency report` subcommands:

- `load_registry()`: safe YAML parse of the project's Defaults Registry.
- `resolve_tier()`: given a phase (coordinator/implementer/hitl), return the
   configured model name or None when the advisor is disabled or missing.

Design constraints (baked in, not opt-in):
- `yaml.safe_load` ONLY. Never `yaml.load`. Every 2024-2026 PyYAML CVE is a
  `yaml.load()` deserialization attack; `safe_load` is immune.
- Read-only. Writes to the registry stay in shell (atomic-write pattern
  documented at `templates/commands/_registry-protocol.md`). A future
  `ruamel.yaml` migration for roundtrip-safe writes is a v0.5+ decision.
- Graceful degradation. Missing file / missing block / malformed YAML never
  raises to callers - it returns an empty view. Directive 7's protocol says
  commands must handle missing knowledge sources without failing hard.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import yaml

Phase = Literal["coordinator", "implementer", "hitl"]

# Ordered by v0.4 promotion path. Update in lockstep with the registry
# template if new tiers are added.
VALID_PHASES: tuple[str, ...] = ("coordinator", "implementer", "hitl")

REGISTRY_RELATIVE_PATH = Path("specs") / "_defaults" / "registry.yaml"


@dataclass(frozen=True)
class TierResolution:
    """Result of resolving a phase against the efficiency block.

    `model` is None when `advisor_enabled: false`, the block is missing, or
    the specific phase key is unset. `reason` is a human-readable diagnostic
    used by `atomicspec efficiency report --advisory`.
    """

    phase: str
    model: str | None
    advisor_enabled: bool
    reason: str


def _find_registry_path(start: Path | None = None) -> Path | None:
    """Walk upward from `start` (default: cwd) looking for `specs/_defaults/registry.yaml`.

    Returns the resolved path or None. Matches the resolution strategy used
    by the shell `check-prerequisites` helpers, but pure Python.
    """
    current = (start or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        target = candidate / REGISTRY_RELATIVE_PATH
        if target.is_file():
            return target
    return None


def load_registry(start: Path | None = None) -> dict:
    """Return the parsed registry as a dict, or {} if missing / malformed.

    Uses `yaml.safe_load` exclusively. Graceful on every failure mode:
    missing file, empty file, malformed YAML, or non-mapping root. The
    caller downstream distinguishes "no registry" from "no efficiency
    block" via presence of `efficiency` key.
    """
    path = _find_registry_path(start)
    if path is None:
        return {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    try:
        parsed = yaml.safe_load(text)
    except yaml.YAMLError:
        return {}
    if not isinstance(parsed, dict):
        return {}
    return parsed


def resolve_tier(phase: str, registry: dict | None = None) -> TierResolution:
    """Resolve a phase name to the configured model, honoring `advisor_enabled`.

    Returns a `TierResolution` regardless of outcome so callers can render a
    diagnostic table without special-casing missing state.

    Contract:
      - Unknown phase → model=None, reason="unknown-phase"
      - No registry file → model=None, reason="registry-missing"
      - No efficiency block → model=None, reason="efficiency-block-missing"
      - `advisor_enabled: false` → model=None, reason="advisor-disabled"
      - Phase key null / empty → model=None, reason="tier-unset"
      - Advisor on, phase set → model=<string>, reason="resolved"
    """
    if phase not in VALID_PHASES:
        return TierResolution(
            phase=phase, model=None, advisor_enabled=False, reason="unknown-phase"
        )
    reg = registry if registry is not None else load_registry()
    if not reg:
        return TierResolution(
            phase=phase, model=None, advisor_enabled=False, reason="registry-missing"
        )
    efficiency = reg.get("efficiency")
    if not isinstance(efficiency, dict):
        return TierResolution(
            phase=phase,
            model=None,
            advisor_enabled=False,
            reason="efficiency-block-missing",
        )
    # Strict bool check — NOT `bool(...)`. If a user quoted the value in YAML
    # (`advisor_enabled: 'false'`), pyyaml returns the STRING "false", and
    # `bool("false")` is True — which would silently flip the master switch ON
    # for a user who typed the config intending to keep it off. Only accept
    # a real YAML boolean.
    raw_advisor = efficiency.get("advisor_enabled", False)
    advisor_enabled = raw_advisor is True
    if not advisor_enabled:
        return TierResolution(
            phase=phase,
            model=None,
            advisor_enabled=False,
            reason="advisor-disabled",
        )
    tiers = efficiency.get("model_tiers")
    if not isinstance(tiers, dict):
        return TierResolution(
            phase=phase,
            model=None,
            advisor_enabled=True,
            reason="tier-map-missing",
        )
    model = tiers.get(phase)
    if not isinstance(model, str) or not model.strip():
        return TierResolution(
            phase=phase,
            model=None,
            advisor_enabled=True,
            reason="tier-unset",
        )
    return TierResolution(
        phase=phase,
        model=model.strip(),
        advisor_enabled=True,
        reason="resolved",
    )
