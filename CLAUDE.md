# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is **not a runtime application**. It is a **governance framework for AI-driven development** — a customized fork of GitHub's Spec Kit that implements the **Atomic Traceability Model**. The deliverables are templates, prompts, knowledge stations, and a thin Python CLI. Consumers install this framework into *their own* projects to constrain how AI coding agents (Claude Code, Gemini, Copilot, Cursor, Windsurf, and ~13 others) generate code.

Inspired by Leapable's "Stop Vibe Coding (Until You Do This)" video. The core premise: AI agents produce drift unless forced through gated, atomic, context-pinned phases.

## The Eight Prime Directives (memory/constitution.md, Article IX)

These are the non-negotiable rules that every command in this framework enforces. When working in this repo, **never weaken or bypass them** — they are the entire value proposition:

1. **Directory Supremacy** — every feature gets `index.md` + `traceability.md`
2. **Atomic Injunction** — `/atomicspec.tasks` is FORBIDDEN from creating a single `tasks.md`. It must create a `tasks/` directory with individual `T-XXX-[name].md` files
3. **Context Pinning** — during `/atomicspec.implement`, the AI may ONLY read `index.md`, the current task file, and `traceability.md`. Reading `plan.md` or `spec.md` during implementation is forbidden
4. **Gate Compliance** — Knowledge Station gate criteria must pass before phase transitions
5. **Knowledge Routing** — unknown decisions consult the Station Map first, then the specific station
6. **Human-In-The-Loop** — `/atomicspec.plan` pauses at 4 mandatory checkpoints (tech stack, validation, UI, registry sync)
7. **Project Defaults Registry** — all commands read `specs/_defaults/registry.yaml` and enforce project-wide standards
8. **Self-Contained Tasks** — task files embed all context (registry values, domain rules, gate criteria) needed for execution under Context Pinning

## Architecture — The Phase Pipeline

The framework is a four-phase assembly line. Each phase has a corresponding command template in `templates/commands/` that ends up in the consumer's `.claude/commands/` (prefixed `atomicspec.`):

```
/atomicspec.specify → /atomicspec.plan → /atomicspec.tasks → /atomicspec.implement
     │                 │                 │                  │
   spec.md         plan.md +         index.md +         code (under
   + Gates         Phase 0.0-0.9     tasks/T-XXX-*.md   Context Pinning
   03-05           + Gates 06-13     + traceability.md  + registry as
                   + HITL x4         + embedded context   reference)
```

Optional: `/atomicspec.AnalyzeCompetitors` runs between specify and plan (follows Station 03 procedures).

Key architectural components that span multiple files:

- **`.specify/knowledge/stations/`** — 18 procedural guides (01-introduction through 18-documentation). Commands look up station gate criteria here before allowing phase transitions.
- **`.specify/subagents/`** — 21+ base subagents plus 146 mobile-specific ones organized by lifecycle phase (01-Discovery through 14-Documentation). Matched dynamically by **semantic similarity** between feature keywords and YAML frontmatter `description`, NOT hard-coded.
- **`specs/_defaults/registry.yaml`** — the Project Defaults Registry. 80+ technical decisions (architecture pattern, data access style, tenancy model, etc.). Every command reads this on entry and offers to update it on exit (with HITL approval).
- **`memory/constitution.md`** — Article IX hardcodes the 8 Prime Directives. Articles I-VIII are `[PLACEHOLDER]` sections filled in by `/atomicspec.constitution` in consumer projects.
- **`src/specify_cli/__init__.py`** — the `specify` Python CLI. Thin wrapper that downloads template releases from `github/spec-kit` and sets up agent-specific command directories. **Note:** it downloads from upstream, not this fork — if you make breaking template changes, this is relevant.

## Critical Conventions

**Atomic task naming** — tasks follow a strict numbering scheme by phase (see README "Task File Naming Convention" table). Ranges like T-037/T-039 are reserved for **wiring tasks** (routes, nav, stores) which are mandatory per user story.

**Agent discovery is dynamic** — when adding a new subagent, you add a file to `.specify/subagents/<domain>/<name>.md` with YAML frontmatter (`name`, `description`, `model`). The description is what drives keyword matching. Never hard-code agent lists in command templates.

**Template changes ripple** — edits to `templates/commands/*.md` don't affect this repo's behavior. They affect the templates that get copied into consumer projects. Similarly for `templates/*.md` and `.specify/*`. Work in templates land, not in live code.

**Context Pinning is load-bearing** — during implementation, tasks must be self-contained. If you're changing task generation (`templates/commands/tasks.md`), make sure all context the implementer needs is embedded in the task file, not linked.

**Graceful degradation** — commands handle missing knowledge sources (no registry, no subagents, no stations) by embedding fallback context. Never fail hard if a knowledge source is absent.

## Common Commands

This repo doesn't build or test in the traditional sense — it's a framework distributed as files. Common operations:

**Initialize a consumer project with this framework:**
```bash
# Bash (macOS/Linux)
./init-project.sh /path/to/new/project --ai claude

# PowerShell (Windows)
.\init-project.ps1 -TargetPath "D:\MyNewProject" -AIAgent "claude"
```

Supported agents: `claude`, `gemini`, `copilot`, `cursor`, `windsurf`. The init scripts currently support only these five — the Python CLI supports ~18 more.

**Python CLI (for distribution via PyPI):**
```bash
# Install
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Initialize
specify init <project-name> --ai claude
specify init . --here --ai claude
specify check  # verify installed tools
```

**Scripts invoked by command templates** (not called directly by humans):
- `scripts/bash/check-prerequisites.sh` — validates gates before phase transitions
- `scripts/bash/create-new-feature.sh` — bootstraps `specs/NNN-feature-name/` with auto-numbering
- `scripts/bash/setup-plan.sh` — prepares planning phase
- `scripts/bash/update-agent-context.sh` — updates agent-specific context files (CLAUDE.md, GEMINI.md, etc. in consumer projects)
- `scripts/bash/validate-tech-stack.sh` — queries npm/PyPI for compatibility and freshness. Known issue: uses GNU `date -d` which fails silently on macOS.

All scripts have PowerShell equivalents in `scripts/powershell/`.

## When Editing This Repo

- **Never edit `memory/constitution.md` Article IX** unless explicitly changing framework governance. Articles I-VIII are intentional placeholders.
- **Templates carry `{{placeholder}}` tokens** that get resolved at copy time. Don't "fix" them thinking they're bugs.
- **Remotes are clean** — only `origin` points to `Airchitekt/atomic-spec`. Any stale `upstream`/duplicate remotes have been removed.
- **`src/specify_cli/__init__.py` downloads templates from `github/spec-kit`** (upstream), not from this fork. Changes to templates in this repo are not picked up by `specify init` until reconciled with upstream or the CLI is patched to point here.
- **Avoid adding new `tasks.md` references** anywhere. The atomic `tasks/` directory is the only correct output. Some stale references still exist in `spec-driven.md` and `templates/commands/analyze.md` — these are bugs to fix, not patterns to follow.
