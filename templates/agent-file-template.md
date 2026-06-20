# [PROJECT NAME] Development Guidelines

Auto-generated from all feature plans. Last updated: [DATE]

## Active Technologies

[EXTRACTED FROM ALL PLAN.MD FILES]

## Project Structure

```text
[ACTUAL STRUCTURE FROM PLANS]
```

## Commands

[ONLY COMMANDS FOR ACTIVE TECHNOLOGIES]

## Code Style

[LANGUAGE-SPECIFIC, ONLY FOR LANGUAGES IN USE]

## Recent Changes

[LAST 3 FEATURES AND WHAT THEY ADDED]

<!-- ATOMIC-SPEC-ORIENTATION:v2:START -->
## Atomic Spec Orientation

This project is governed by **Atomic Spec** (Atomic Traceability Model). Any AI
agent -- regardless of provider (Claude / Codex / Gemini / Cursor / Copilot /
Windsurf / etc.) -- MUST follow the orientation procedure below before writing
code, generating tests, or modifying specs. Skipping it causes drift, duplicate
work, and silent governance violations.

### Mandatory reading on every session start

1. `memory/constitution.md` -- Article IX defines the 9 Prime Directives. They
   are non-negotiable.
2. `specs/_defaults/registry.yaml` -- project-wide technical defaults. Treat
   as reference, not as something to re-discover.
3. `.specify/knowledge/stations/00-station-map.md` (if present) -- where to
   look when a decision is unfamiliar.

### Cross-provider handoff -- orientation procedure (Directive 9)

Run this on every session start, BEFORE picking up any task:

1. Read the current git branch (`git rev-parse --abbrev-ref HEAD`). Feature
   branches are `NNN-feature-name`.
2. If on a feature branch, the active feature folder is `specs/<branch>/`.
3. For every artifact in that folder (`spec.md`, `clarify-log.md`, `plan.md`,
   `index.md`, `traceability.md`, `tasks/T-*.md`), run:
   ```
   scripts/bash/stamp-lifecycle.sh status --artifact <path> --json
   ```
   or on Windows:
   ```
   scripts/powershell/stamp-lifecycle.ps1 -Command status -Artifact <path> -Json
   ```
4. Categorize each result by `state`: `closed | done | legacy_closed | authored`
   = OK; `authoring_in_progress | implementing` = open, needs attention.
5. Apply the three outcomes (Directive 9):
   - **Clean**: every artifact closed. Print one-line summary; proceed.
   - **Stale**: an open block whose `start` timestamp is older than the
     registry's `lifecycle.stale_threshold_days` (default 7 days). Surface as
     informational; let the user confirm resume-or-discard.
   - **Conflict**: an open block newer than the stale threshold. STOP,
     present options (resume / redo / skip / abort), await the user.
6. Write the orientation evidence (the JSON outputs + outcome + decision) as a
   **per-run file** in `specs/<branch>/orientation-runs/<ISO-UTC>-<provider>.md`
   (race-free under concurrent providers — no two timestamps collide at second
   precision). This evidence is **required by policy in v0.3.0**; a runtime gate
   (`check-prerequisites --check-orientation`) that BLOCKS Phase 1 on missing
   evidence ships in v0.3.1.

### Lifecycle Markers -- hard rules

- **NEVER write a Lifecycle Markers stamp by hand.** Always invoke
  `scripts/bash/stamp-lifecycle.sh` or `scripts/powershell/stamp-lifecycle.ps1`.
  The script guarantees format, ISO 8601 UTC timestamp, sanitized provider
  name, and atomic write. Hand-edited stamps will mis-parse or be rejected
  by the orientation procedure.
- Subcommands: `init` (initialize a block on a fresh artifact),
  `start` (begin a lifecycle event), `end` (close one), `status` (read it).
- Lifecycles: `authoring` (every artifact carries this) +
  `implementation` (only `tasks/T-*.md` and `traceability.md` carry this).
- Provider names must be in the allowlist: claude / gpt / gemini / cursor /
  copilot / codex / windsurf / qwen / opencode / kilocode / auggie / shai /
  q / bob / qoder / roo / amp.

### Phase pipeline reminder

`/atomicspec.specify -> /atomicspec.plan -> /atomicspec.tasks -> /atomicspec.implement`

Each phase has gate criteria enforced by
`scripts/{bash,powershell}/check-prerequisites.{sh,ps1}`. Do not jump phases.
If a gate fails, fix the failure -- do not work around it.

### When in doubt

1. Re-read `memory/constitution.md` Article IX.
2. Consult the Station Map for the relevant procedure.
3. Ask the user. Do NOT improvise governance.

### Forbidden actions

- Creating a single `tasks.md` (Directive 2 -- tasks live in `tasks/T-XXX-*.md`).
- Reading `plan.md` or `spec.md` body content during `/atomicspec.implement`
  (Directive 3).
- Reading body content of any artifact during Phase 0 Orientation other than
  `index.md` and `traceability.md` -- use `stamp-lifecycle status` for the
  rest (Directive 9).
- Skipping HITL checkpoints in `/atomicspec.plan` (Directive 6).
- Modifying the registry without an entry in `specs/_defaults/changelog.md`
  (Directive 7).
- Hand-writing lifecycle stamps. ALWAYS via `stamp-lifecycle` script.

<!-- ATOMIC-SPEC-ORIENTATION:v2:END -->

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
