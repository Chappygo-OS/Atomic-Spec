"""Pure-data configuration for Atomic Spec.

Importable without the full CLI dependency tree — used by the release workflow
to enumerate agents without installing typer/rich/httpx. Keep this module
dependency-free (standard library only).
"""

# Agent configuration with name, folder, install URL, CLI tool requirement, and support tier.
#
# Support tiers:
#   - "supported"    — wired end-to-end in init-project.{sh,ps1} and exercised on every release.
#   - "experimental" — command templates drop into {folder}/commands/ via the release workflow;
#                      governance (Prime Directives) applies because it's template-enforced, but
#                      agent-specific tailoring has not been validated. Issues triaged best-effort.
AGENT_CONFIG = {
    "copilot": {
        "name": "GitHub Copilot",
        "folder": ".github/",
        "install_url": None,  # IDE-based, no CLI check needed
        "requires_cli": False,
        "tier": "supported",
    },
    "claude": {
        "name": "Claude Code",
        "folder": ".claude/",
        "install_url": "https://docs.anthropic.com/en/docs/claude-code/setup",
        "requires_cli": True,
        "tier": "supported",
    },
    "gemini": {
        "name": "Gemini CLI",
        "folder": ".gemini/",
        "install_url": "https://github.com/google-gemini/gemini-cli",
        "requires_cli": True,
        "tier": "supported",
    },
    "cursor-agent": {
        "name": "Cursor",
        "folder": ".cursor/",
        "install_url": None,  # IDE-based
        "requires_cli": False,
        "tier": "supported",
    },
    "qwen": {
        "name": "Qwen Code",
        "folder": ".qwen/",
        "install_url": "https://github.com/QwenLM/qwen-code",
        "requires_cli": True,
        "tier": "experimental",
    },
    "opencode": {
        "name": "opencode",
        "folder": ".opencode/",
        "install_url": "https://opencode.ai",
        "requires_cli": True,
        "tier": "experimental",
    },
    "codex": {
        "name": "Codex CLI",
        "folder": ".codex/",
        "install_url": "https://github.com/openai/codex",
        "requires_cli": True,
        "tier": "experimental",
    },
    "windsurf": {
        "name": "Windsurf",
        "folder": ".windsurf/",
        "install_url": None,  # IDE-based
        "requires_cli": False,
        "tier": "supported",
    },
    "kilocode": {
        "name": "Kilo Code",
        "folder": ".kilocode/",
        "install_url": None,  # IDE-based
        "requires_cli": False,
        "tier": "experimental",
    },
    "auggie": {
        "name": "Auggie CLI",
        "folder": ".augment/",
        "install_url": "https://docs.augmentcode.com/cli/setup-auggie/install-auggie-cli",
        "requires_cli": True,
        "tier": "experimental",
    },
    "codebuddy": {
        "name": "CodeBuddy",
        "folder": ".codebuddy/",
        "install_url": "https://www.codebuddy.ai/cli",
        "requires_cli": True,
        "tier": "experimental",
    },
    "qoder": {
        "name": "Qoder CLI",
        "folder": ".qoder/",
        "install_url": "https://qoder.com/cli",
        "requires_cli": True,
        "tier": "experimental",
    },
    "roo": {
        "name": "Roo Code",
        "folder": ".roo/",
        "install_url": None,  # IDE-based
        "requires_cli": False,
        "tier": "experimental",
    },
    "q": {
        "name": "Amazon Q Developer CLI",
        "folder": ".amazonq/",
        "install_url": "https://aws.amazon.com/developer/learning/q-developer-cli/",
        "requires_cli": True,
        "tier": "experimental",
    },
    "amp": {
        "name": "Amp",
        "folder": ".agents/",
        "install_url": "https://ampcode.com/manual#install",
        "requires_cli": True,
        "tier": "experimental",
    },
    "shai": {
        "name": "SHAI",
        "folder": ".shai/",
        "install_url": "https://github.com/ovh/shai",
        "requires_cli": True,
        "tier": "experimental",
    },
    "bob": {
        "name": "IBM Bob",
        "folder": ".bob/",
        "install_url": None,  # IDE-based
        "requires_cli": False,
        "tier": "experimental",
    },
}

# Shared list of command file stems (without .md) used by the release workflow
# to populate per-agent command folders. Keep in sync with templates/commands/
# (underscore-prefixed files like _subagent-discovery.md are includes, not commands).
ATOMIC_SPEC_COMMANDS = [
    "specify",
    "plan",
    "tasks",
    "implement",
    "analyze",
    "analyze-competitors",
    "checklist",
    "clarify",
    "cleanup",
    "constitution",
    "taskstoissues",
]
