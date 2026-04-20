# Installation Guide

## Prerequisites

- **Linux / macOS / Windows** (PowerShell scripts work natively on Windows; no WSL required)
- An AI coding agent: [Claude Code](https://www.anthropic.com/claude-code), [GitHub Copilot](https://code.visualstudio.com/), [Gemini CLI](https://github.com/google-gemini/gemini-cli), [Cursor](https://cursor.sh/), or [Windsurf](https://codeium.com/windsurf)
- [Git](https://git-scm.com/downloads)
- (Planned, post-`v0.1.0`) [uv](https://docs.astral.sh/uv/) + [Python 3.11+](https://www.python.org/downloads/) — required only for the future PyPI install path

## Supported AI Agents

The init scripts currently set up commands for these five agents: `claude`, `gemini`, `copilot`, `cursor`, `windsurf`. The Python CLI (once published) will support more.

## Installation

### Step 1: Clone Atomic Spec

```bash
git clone https://github.com/Airchitekt/atomic-spec.git
cd atomic-spec
```

### Step 2: Initialize a new project

**macOS / Linux / WSL:**

```bash
./init-project.sh /path/to/<PROJECT_NAME>
# Defaults to --ai claude if omitted
./init-project.sh /path/to/<PROJECT_NAME> --ai claude
./init-project.sh /path/to/<PROJECT_NAME> --ai gemini
./init-project.sh /path/to/<PROJECT_NAME> --ai copilot
./init-project.sh /path/to/<PROJECT_NAME> --ai cursor
./init-project.sh /path/to/<PROJECT_NAME> --ai windsurf
```

**Windows PowerShell:**

```powershell
.\init-project.ps1 -TargetPath "D:\path\to\<PROJECT_NAME>"
.\init-project.ps1 -TargetPath "D:\path\to\<PROJECT_NAME>" -AIAgent "claude"
```

### Step 3: Verify

After initialization, the project directory should contain:

- `.specify/` — knowledge stations, subagents, templates
- `templates/` — spec, plan, task, registry templates
- `.claude/commands/` (for `--ai claude`) — `atomicspec.*.md` slash commands
- `specs/_defaults/registry.yaml` — Project Defaults Registry scaffold
- `memory/constitution.md` — governance constitution with Article IX hardcoded

In your AI agent, the following slash commands should now be available:

- `/atomicspec.specify` — create feature specifications
- `/atomicspec.plan` — generate implementation plans
- `/atomicspec.tasks` — generate atomic task files
- `/atomicspec.implement` — execute with Context Pinning
- `/atomicspec.clarify`, `/atomicspec.analyze`, `/atomicspec.checklist`, `/atomicspec.constitution`, `/atomicspec.analyze-competitors`, `/atomicspec.cleanup`, `/atomicspec.taskstoissues` — supporting commands

## Future: PyPI install (`v0.1.0`+)

Once Atomic Spec publishes to PyPI, the install path will shorten to:

```bash
uv tool install atomic-spec
atomicspec init <PROJECT_NAME>
atomicspec init --here
```

Track progress on [Airchitekt/atomic-spec releases](https://github.com/Airchitekt/atomic-spec/releases).

## Troubleshooting

### Git Credential Manager on Linux

If you're having issues with Git authentication on Linux, install Git Credential Manager:

```bash
#!/usr/bin/env bash
set -e
echo "Downloading Git Credential Manager v2.6.1..."
wget https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.6.1/gcm-linux_amd64.2.6.1.deb
echo "Installing Git Credential Manager..."
sudo dpkg -i gcm-linux_amd64.2.6.1.deb
echo "Configuring Git to use GCM..."
git config --global credential.helper manager
echo "Cleaning up..."
rm gcm-linux_amd64.2.6.1.deb
```

### `init-project.sh` permission denied

On macOS / Linux, make the script executable:

```bash
chmod +x init-project.sh
```

### Windows execution policy blocks `init-project.ps1`

Allow the script to run for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\init-project.ps1 -TargetPath "D:\path\to\project" -AIAgent "claude"
```
