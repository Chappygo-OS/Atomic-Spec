# Changelog

<!-- markdownlint-disable MD024 -->

> **Note**: Versions 0.0.1–0.0.22 are the upstream changelog from [github/spec-kit](https://github.com/github/spec-kit), the project this fork is based on. Issue links below reference the upstream repository. Atomic Spec versioning begins at 0.1.0.

All notable changes to the Specify CLI and templates are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-06-21

> **v0.3 theme**: close the cross-provider AI handoff gap. When Claude crashes mid-feature and the user switches to Codex (or hits a quota cliff and falls over to Gemini), the receiving AI now self-orients from files alone — detects which artifacts are half-done, prompts the user on conflict, and resumes cleanly without silently overwriting work. A new sibling Directive (9) governs this read surface narrowly so Directive 3's Context Pinning stays verbatim.

### Added

- **Lifecycle Markers** — every artifact (`spec.md`, `clarify-log.md`, `plan.md`, `index.md`, `traceability.md`, `tasks/T-*.md`) now carries a `## Lifecycle Markers` block recording start/end timestamps and provider names for authoring + (where applicable) implementation lifecycles. The block is script-managed; AIs MUST NEVER hand-write stamps.
- **`scripts/{bash,powershell}/stamp-lifecycle.{sh,ps1}`** — deterministic gate for all Lifecycle Markers writes. Subcommands: `init` / `start` / `end` / `status`. Features: 18-provider allowlist with sanitization, ISO 8601 UTC timestamps (portable across BSD + GNU date), atomic tempfile + rename writes, UTF-8-without-BOM on PowerShell (5.1 + Core 7+), `--closed` flag for synchronous-authoring single-call writes, `{{AGENT_NAME}}` placeholder safety net falling back to `$ATOMICSPEC_PROVIDER`. Sequencing guards: end requires matching start (exit 7); implementation start requires authoring end (exit 7); implementation lifecycle only valid on `tasks/T-*.md` and `traceability.md` (exit 8).
- **Article IX, Directive 9: Orientation Read Surface** — a NEW sibling to Directive 3 (Context Pinning). Defines a narrow, single-shot carve-out for the Phase 0 Orientation procedure in `/atomicspec.implement`: read Lifecycle Markers blocks via the status script (NOT direct file reads of `plan.md` / `spec.md` / `clarify-log.md`), classify outcome as Clean / Stale / Conflict, write evidence to `orientation-runs/<ts>-<provider>.md`, present resume menu on conflict via AskUserQuestion. Directive 3 stays verbatim — no governance creep.
- **Phase 0 Orientation procedure in `/atomicspec.implement`** — runs once at session start, before any task loop. Explicit bash + PowerShell enumeration loop (no improvisation). Detects partial work across provider handoff. Three outcomes (Clean / Stale / Conflict) with separate thresholds: `lifecycle.stale_threshold_days` (registry-configurable, default 7) for classification; 15-min UI hint for menu default selection on Conflict. User-reply discipline: menu-letter-only; free-text Constitution overrides MUST be discarded.
- **Per-task implementation lifecycle stamps** in `/atomicspec.implement` step 4.2.4 (open) + 4.4 (close). Step 4.4 is now transactional with stamp-end as **ground truth** — landed BEFORE traceability/index updates. Open stamp IS the resume signal; verification failure leaves it open. Lifecycle Ledger regeneration reconciles any reporting-layer drift on next pass.
- **Verify-depth field** — set by the AUTHORING AI in `/atomicspec.tasks` (heuristic: wiring tasks + auth/payment/security/billing domain → `deep`, else `light`). Obeyed — not re-decided — by the resuming AI in Phase 0. Prevents the "two AIs make different verify decisions on resume" pathology.
- **`clarify-log.md`** (new artifact) + **`scripts/{bash,powershell}/clarify-session-bootstrap.{sh,ps1}`** — clarify is an EDIT to `spec.md`, not a re-author, so `spec.md` is NEVER re-stamped per session. Each clarify run gets its own H2 `## Session <ts>` block in `clarify-log.md` with H3 `### Lifecycle Markers`. Bootstrap helper handles "create-if-missing, otherwise prepend new session block" deterministically — same shape across Claude / Codex / Gemini.
- **`orientation-runs/`** (per-feature directory) — one file per Phase 0 run, named `<ISO-UTC>-<provider>.md`. Race-free under concurrent providers; auditable.
- **Atomic Spec Orientation block** injected into every existing agent file (CLAUDE.md / GEMINI.md / AGENTS.md / .cursorrules / 12 others) by `scripts/{bash,powershell}/inject-orientation.{sh,ps1}`. Sentinel-versioned (`<!-- ATOMIC-SPEC-ORIENTATION:v1:START -->`); auto-upgrades older blocks on every command run; never downgrades newer ones. Wired via `check-prerequisites.{sh,ps1}` so every gated command is self-healing. The orientation block is what makes a fresh provider auto-discover Atomic Spec governance + the Phase 0 procedure + stamp conventions on first read.
- **Registry schema bump (4 → 5)** — adds `lifecycle.stale_threshold_days` (default 7). Framework-level setting, no HITL gate required.
- **Cross-phase pre-flight guards** in `/clarify`, `/plan`, `/tasks` — each command checks `stamp-lifecycle status` on earlier-phase artifacts (spec.md, plan.md, clarify-log.md as applicable) and aborts if any are `authoring_in_progress`. Full Orientation (with three-outcome menu) runs only in `/atomicspec.implement`.
- **`init-project.{sh,ps1}`** now substitutes the `{{AGENT_NAME}}` placeholder in command templates with the `--ai` value at copy time, so stamp-lifecycle never receives the literal placeholder string.

### Changed

- **Directive 3 (Context Pinning) is UNCHANGED.** The new Orientation Read Surface is a *separate*, narrower Directive 9 — explicitly NOT an expansion of Directive 3's "may ONLY read" list. Auditors and compliance buyers can point to Directive 3 as verbatim since v0.1.
- **`traceability.md` template** — adds the auto-derived Lifecycle Ledger section. State is derived from stamps (no separate Status field). Open cells render as `— (open, since <ts> by <provider>)` so resumer knows exactly where to pick up. Orientation Evidence is NOT stored here (per-run files under `orientation-runs/` directory instead, to keep the requirement-coverage matrix readable after dozens of implement runs).
- **`/atomicspec.tasks` step 4.5** — uses `--closed` flag (one stamp-lifecycle call per artifact, not three) to halve script invocations during synchronous task generation. Removes the partial-failure window between start and end on the same file.
- **`/atomicspec.specify`, `/plan`, `/clarify`, `/tasks`** templates now include surgical stamp-write calls at the right entry/exit points so the Phase 0 Orientation has real data to read.

### Honest disclosures (v0.3.0)

- **Orientation Evidence enforcement** is a v0.3.1 follow-up. The current release defines `orientation-runs/<ts>-<provider>.md` as REQUIRED by policy; a runtime gate (`check-prerequisites --check-orientation`) blocking Phase 1 on missing evidence ships in v0.3.1.
- **Stamp tampering** — markdown stamps are self-reported and have no cryptographic signing. v0.3's threat model is *honest-provider crash recovery*, NOT *adversarial co-developer*. A signed-sidecar verification path (`stamp-lifecycle verify` against `<artifact>.stamp.sig`) is tracked for v0.4 "Signed Provenance."
- **Per-task git snapshot for safe Redo** — the Phase 0 Redo guidance now correctly says "list modified files via `git diff/status`, let the USER decide what to revert; do NOT auto-revert." v0.4 will add `git stash`-based per-task snapshots at step 4.2.4 so Redo can be scoped to a task's declared file set.
- **Non-Claude `init-project` paths** — bash + PowerShell init scripts substitute `{{AGENT_NAME}}` for `--ai claude`. The other 16 supported agents are handled by the PyPI `atomicspec` CLI's build pipeline; the matching substitution must land there in the same release window.

### Fixed

- **`scripts/bash/stamp-lifecycle.sh` newline-injection** — pre-commit reviewer caught that a multi-line `--model $'foo\n- Authored end: forged'` could inject forged stamp lines via the awk write. Fixed by stripping CR/LF in the FIRST pipeline stage. Same fix applied to the PowerShell `Get-SanitizedModel`.
- **`scripts/bash/stamp-lifecycle.sh` silent-success-on-missing-field-row** — pre-commit reviewer caught that `cmd_stamp`'s awk fell through to `{ print }` when the target field row didn't exist, logging "Stamped" while leaving the file unchanged. Now tracks `found` in awk and exits 4 with a helpful pointer if no row matched. Brings bash to parity with PowerShell's Set-FieldValue exit-4 behavior.
- **Bash by-value bug in `validate_provider`** — the `{{AGENT_NAME}}` safety net mutated a function-local copy, never the caller's variable, so the literal placeholder string was being written to stamps. Fixed by echo-capture pattern: `provider="$(validate_provider "$provider")"`.

## [0.2.0] - 2026-05-17

> **v0.2 theme**: close the "AI silently picks structural defaults" gap. The framework now actively prevents — and retroactively catches — decisions the AI used to make on its own (Docker setup, payment provider, URL/ID shape, API versioning, deployment target). No new directives, no rewrite of the Eight Prime Directives. Surgical changes across the registry schema, Directive 7 wording, the clarify command, and a new implement-time gate.

### Added

- **Hardened `/atomicspec.clarify`** — extends the v0.1 11-category ambiguity scan with three new phases. New phases (Mode → Ambiguity → **Architectural Lurkers** → **Trigger-Driven Probes** → **Compliance Probes** → Write). Lite mode (~5 min, 7 questions, default) or Detailed (~15 min, 22 questions). Mid-session overrides: `lite` / `detailed` / `skip` / `done` / `?`.
- **`.specify/knowledge/architectural-lurkers.yaml`** (new) — per-app-type packs (web_with_api, mobile, desktop, library) of universal must-decide / can-defer questions with opinionated defaults and one-line rationales.
- **`.specify/knowledge/triggers.yaml`** (new) — 13 declarative triggers (8 functional + 5 compliance). Keyword-match on spec text (case-insensitive substring, `re:` prefix opts into regex). Each trigger fires at most once per session.
- **Compliance probes** — GDPR / PCI / HIPAA / COPPA / SOC 2 sub-checklists with a two-step Y/N/Unsure gate. Default answer is N (skip), so paranoid prompts don't trap users who genuinely don't have scope.
- **Pre-plan interview gate** — `/atomicspec.plan` Phase 0 now checks `interview_completed` in the registry. If null, surfaces a three-option AskUserQuestion (run clarify / proceed with assumed defaults / cancel) instead of an abort wall.
- **Reverse-traceability exit gate** — new Phase 10 in `/atomicspec.implement`. Compares every changed file against `traceability.md` table rows; flags orphans (files no task referenced). Catches the "Docker without asking" failure mode after the fact. Bundled with new scripts `scripts/{bash,powershell}/check-traceability.{sh,ps1}`. **Default is warn-only on v0.2.0** (consumer projects get one release cycle to clean up legacy orphans); promoted to enforce-by-default in v0.2.1.
- **Soft-nudge footer** in `/atomicspec.specify` advertising clarify with realistic time estimates (Lite ~5 min, Detailed ~15 min) without blocking.
- **Two new subagents**:
  - `backend/metering-engineer` (~190 lines) — entitlement table schemas, usage-event ingestion, standard + two-phase enforcement algorithms, three concurrency patterns, AI / token cost controls.
  - `ux/interaction-patterns` (~210 lines) — IA / flow / state-machine templates, hide-vs-disable RBAC, tenant-mismatch deep-link handling, limit-threshold UI surfacing, billing-state UI mapping, empty/loading/error timing rules.
- **Registry schema expansion** (`templates/registry-template.yaml`, `version` field bumped 3 → 4). New top-level sections:
  - `payment.*` (provider, abstraction_pattern, billing_model, event_persistence)
  - `email.*` (transactional_provider, marketing_provider, template_strategy)
  - `domain.*` (money_representation, time_representation, identifier_exposure)
  - `integrations.*` (webhook_ingress_contract, outbound_http_policy)
  - `compliance.*` (gdpr, pci, hipaa, coppa, soc2, data_residency)
  - `_provenance` block — tracks how each non-null decision was made (`human` / `accepted_recommendation` / `manifest_scan` / `plan_phase_0_9` / `implement_phase_9` / `unknown_legacy`). Lets `/atomicspec.plan` surface "you accepted N defaults" warnings.
- New fields on existing sections: `backend.job_durability_semantics`, `frontend.i18n_posture`, `infrastructure.search`, `infrastructure.scheduling`, `infrastructure.file_storage`, `infrastructure.deployment_target` (closes the Docker-without-asking gap).
- **`interview_completed: <iso-date>`** registry metadata — clarify mandatory at genesis (null), advertised after.

### Changed

- **Directive 7 (Project Defaults Registry) — clause amendment**: now explicitly states that registry-eligible decisions include *any structural choice that pervades the codebase*, not just the fields enumerated in `registry.yaml`. Lists: containerization, deployment target, monorepo layout, file-structure pattern, framework choice, payment / email / scheduling / file storage, money / id / time primitives, auth model, observability stack, CI/CD platform, package manager + runtime pins, testing framework. Adds explicit definition of "commit" (writing config/code or recording as a fixed value, NOT discussing). Mandates `AskUserQuestion` before applying, in any phase. Eight directives stays eight — clause amendment, not new directive.
- **Directive 8 (Self-Contained Tasks) — companion row** added to the Embedded Context table: "Structural Decision Triggers" so tasks can recognize the new D7 trigger categories under Context Pinning.
- **Governance / pattern split** — 7 Knowledge Stations (05, 06, 07, 08, 09, 10, 15) gained cross-reference headers pointing readers at the matching subagent for code-level patterns. Stations remain the source of truth for gate criteria + decision frameworks; subagents now own the code patterns (schemas, function signatures, library-specific guidance).
- **Constitution mirror** — `site/src/content/docs/prime-directives.mdx` updated in lockstep with `memory/constitution.md`.

### Fixed

- **Registry classifier — Python-`lib/`-ignore false-empty regression** prevention: classifier now also excludes `interview_completed` and empty-dict `{}` placeholders (used for `_provenance: {}` default). Verified: fresh v0.2 registry still classifies as `empty`.

### Migration notes

**Fully backwards compatible.** Projects on v0.1.x keep working without changes:

- New `interview_completed` field defaults to `null`. `/atomicspec.clarify` is *advertised* (soft nudge from specify) but does NOT block for projects with already-populated registries — only blocks at `/atomicspec.plan` Phase 0 if the registry is genuinely uninterviewed.
- New registry fields default to `null` and fill in as features hit them.
- Directive 7 clause amendment clarifies existing wording; doesn't change behavior for projects that were already disciplined.
- Reverse-traceability gate is warn-only by default in v0.2.0; promote to blocking in v0.2.1.

No migration script needed. No breaking changes to the v0.1.x registry schema (additive only).

### Deferred to v0.2.1 (internal follow-ups, no user-facing impact)

- Full content migration of patterns from Stations 06, 07, 08, 09, 15 into matching subagents (cross-reference headers + the two new subagents land in v0.2.0; bulk content move is editorial-only and ships as v0.2.1).
- Reverse-traceability gate default flipped to `--enforce` (TODO marker in `check-traceability.{sh,ps1}` script header).
- Several lower-priority UX polish items on the clarify flow (interrogation-theater wording, two-pass Detailed mode split, "what you bought" recap at session end).
- Astro v5 → v6 upgrade on the public site (pre-existing CVE; latent, no `define:vars` usage).

## [0.1.1] - 2026-04-24

### Added

- **PyPI release** — Atomic Spec is now installable via `uv tool install atomic-spec` and publishes through GitHub Actions Trusted Publishing (OIDC, no long-lived secrets).
- **Automated release pipeline** — `v*` tag push triggers `release.yml` (builds 34 per-agent template zips: 17 agents × 2 script types) and auto-dispatches `publish.yml` to PyPI.
- **`cursor-agent` accepted as agent key** — Both `cursor` (legacy shell convention) and `cursor-agent` (matches the Cursor CLI executable name) are honored by `init-project.{sh,ps1}` and the `atomicspec` CLI.
- **Tech-stack gate now rejects unfilled `[placeholder]` values** — `check-prerequisites.{sh,ps1}` validate six Technical Context fields (Language/Version, Primary Dependencies, Storage, Testing, Target Platform, Project Type) against empty/leading-`[`/`NEEDS CLARIFICATION` markers.
- **Directive 7 (Project Defaults Registry) restored** in the governance chain and wired into `check-prerequisites` gate validation.
- **Dynamic Agent Discovery documented** — subagent matching is keyword-based against YAML frontmatter `description`, never hard-coded.

### Changed

- **CLI renamed** — all slash commands now use the `atomicspec.*` prefix (e.g., `/atomicspec.specify`, `/atomicspec.plan`). The PyPI executable is `atomicspec`; the package on PyPI is `atomic-spec`.
- **CLI template source** — `src/specify_cli/__init__.py` now pulls template zips from `Chappygo-OS/Atomic-Spec` GitHub Releases (overridable via `ATOMIC_SPEC_REPO` and `ATOMIC_SPEC_ASSET_PREFIX`), not upstream `github/spec-kit`.
- **Agent configuration extracted** — `AGENT_CONFIG` and `ATOMIC_SPEC_COMMANDS` moved from `__init__.py` to `src/specify_cli/_config.py` (stdlib-only) so the release workflow can enumerate agents without installing `typer`/`rich`/`httpx`.
- **Registry template de-duplicated** — `templates/registry-template.yaml` had duplicate `target_platform:` and `mobile:` keys (silent data loss under strict YAML parsers). Merged into single canonical sections preserving every field from both versions.
- **Station numbers in templates** — corrected stale references in `templates/spec-template.md` and `templates/traceability-template.md` to match authoritative numbering (01–18) in `.specify/knowledge/stations/`.

### Fixed

- **Windows cp1252 encoding crash** — CLI banner with box-drawing Unicode now reconfigures stdout/stderr to UTF-8 on Windows at module entry.
- **Article IX naming conflict** — `atomic-traceability-model.md` now describes Atomic Spec's Article IX (Eight Prime Directives), matching `memory/constitution.md` and the command templates. Upstream's "Integration-First Testing" is retained as non-normative quality guidance.
- **Upstream branding removed** from `CONTRIBUTING.md`, `docs/README.md`, `docs/installation.md`, `docs/upgrade.md`, and `AGENTS.md`.
- **Contact email** — `CODE_OF_CONDUCT.md` enforcement contact now points to the project owner instead of GitHub's upstream address.
- **README subagent claim** corrected — general-purpose domains listed accurately; mobile lifecycle agents properly scoped to the `mobile/` subtree.
- **`date -d` portability** — `validate-tech-stack.sh` now falls back from GNU `date -d` → BSD `date -j` → Python on systems without GNU coreutils (fixes silent failure on macOS).

---

## [0.1.0] - 2026-04-20

### Added

- **Atomic Traceability Model** — Eight Constitutional Prime Directives enforced across all commands
- **Atomic Injunction** — `/atomicspec.tasks` generates a `tasks/` directory with individual `T-XXX-[name].md` files; single `tasks.md` is forbidden
- **Context Pinning** — During `/atomicspec.implement`, AI may only read `index.md`, the current task file, and `traceability.md`
- **Knowledge Station Gates** — 18 procedural station guides with gate criteria that must pass before phase transitions
- **Project Defaults Registry** — `specs/_defaults/registry.yaml` with 80+ technical decisions enforced across all commands
- **Human-In-The-Loop checkpoints** — 4 mandatory pauses during `/atomicspec.plan` for tech stack, validation, UI, and registry sync
- **Mobile platform support** — 146 mobile subagents organized by lifecycle phase (iOS, Android, cross-platform, push notifications, offline sync, IAP, app store deployment)
- **Composite platform support** — Backend + mobile pipelines with platform-aware knowledge routing
- **Dynamic agent discovery** — Subagents matched by semantic similarity to feature keywords, never hard-coded
- **`/atomicspec.analyze-competitors`** — New command following Station 03 competitive analysis procedures
- **`/atomicspec.constitution`** — New command to author the project constitution (Articles I-VIII)
- **Renamed all commands** from `speckit.*` → `atomicspec.*` prefix for discoverability
- **Assembly Line mental model** — Clear explanation of Stations, Deliverables, Gates, and Context Pinning in README

### Changed

- Forked from [github/spec-kit](https://github.com/github/spec-kit) v0.0.22 as the governance foundation
- Project renamed from "Custom Speckit - Exact Assembly Line" to **Atomic Spec**
- Inspired by ["Stop Vibe Coding (Until You Do This)"](https://www.youtube.com/watch?v=020qK_L_X_w) by [Leapable](https://www.youtube.com/@Leapableai)

---

## [0.0.22] - 2025-11-07

- Support for VS Code/Copilot agents, and moving away from prompts to proper agents with hand-offs.
- Move to use `AGENTS.md` for Copilot workloads, since it's already supported out-of-the-box.
- Adds support for the version command. ([#486](https://github.com/github/spec-kit/issues/486))
- Fixes potential bug with the `create-new-feature.ps1` script that ignores existing feature branches when determining next feature number ([#975](https://github.com/github/spec-kit/issues/975))
- Add graceful fallback and logging for GitHub API rate-limiting during template fetch ([#970](https://github.com/github/spec-kit/issues/970))

## [0.0.21] - 2025-10-21

- Fixes [#975](https://github.com/github/spec-kit/issues/975) (thank you [@fgalarraga](https://github.com/fgalarraga)).
- Adds support for Amp CLI.
- Adds support for VS Code hand-offs and moves prompts to be full-fledged chat modes.
- Adds support for `version` command (addresses [#811](https://github.com/github/spec-kit/issues/811) and [#486](https://github.com/github/spec-kit/issues/486), thank you [@mcasalaina](https://github.com/mcasalaina) and [@dentity007](https://github.com/dentity007)).
- Adds support for rendering the rate limit errors from the CLI when encountered ([#970](https://github.com/github/spec-kit/issues/970), thank you [@psmman](https://github.com/psmman)).

## [0.0.20] - 2025-10-14

### Added

- **Intelligent Branch Naming**: `create-new-feature` scripts now support `--short-name` parameter for custom branch names
  - When `--short-name` provided: Uses the custom name directly (cleaned and formatted)
  - When omitted: Automatically generates meaningful names using stop word filtering and length-based filtering
  - Filters out common stop words (I, want, to, the, for, etc.)
  - Removes words shorter than 3 characters (unless they're uppercase acronyms)
  - Takes 3-4 most meaningful words from the description
  - **Enforces GitHub's 244-byte branch name limit** with automatic truncation and warnings
  - Examples:
    - "I want to create user authentication" → `001-create-user-authentication`
    - "Implement OAuth2 integration for API" → `001-implement-oauth2-integration-api`
    - "Fix payment processing bug" → `001-fix-payment-processing`
    - Very long descriptions are automatically truncated at word boundaries to stay within limits
  - Designed for AI agents to provide semantic short names while maintaining standalone usability

### Changed

- Enhanced help documentation for `create-new-feature.sh` and `create-new-feature.ps1` scripts with examples
- Branch names now validated against GitHub's 244-byte limit with automatic truncation if needed

## [0.0.19] - 2025-10-10

### Added

- Support for CodeBuddy (thank you to [@lispking](https://github.com/lispking) for the contribution).
- You can now see Git-sourced errors in the Specify CLI.

### Changed

- Fixed the path to the constitution in `plan.md` (thank you to [@lyzno1](https://github.com/lyzno1) for spotting).
- Fixed backslash escapes in generated TOML files for Gemini (thank you to [@hsin19](https://github.com/hsin19) for the contribution).
- Implementation command now ensures that the correct ignore files are added (thank you to [@sigent-amazon](https://github.com/sigent-amazon) for the contribution).

## [0.0.18] - 2025-10-06

### Added

- Support for using `.` as a shorthand for current directory in `specify init .` command, equivalent to `--here` flag but more intuitive for users.
- Use the `/atomicspec.` command prefix to easily discover Spec Kit-related commands.
- Refactor the prompts and templates to simplify their capabilities and how they are tracked. No more polluting things with tests when they are not needed.
- Ensure that tasks are created per user story (simplifies testing and validation).
- Add support for Visual Studio Code prompt shortcuts and automatic script execution.

### Changed

- All command files now prefixed with `atomicspec.` (e.g., `atomicspec.specify.md`, `atomicspec.plan.md`) for better discoverability and differentiation in IDE/CLI command palettes and file explorers

## [0.0.17] - 2025-09-22

### Added

- New `/clarify` command template to surface up to 5 targeted clarification questions for an existing spec and persist answers into a Clarifications section in the spec.
- New `/analyze` command template providing a non-destructive cross-artifact discrepancy and alignment report (spec, clarifications, plan, tasks, constitution) inserted after `/tasks` and before `/implement`.
  - Note: Constitution rules are explicitly treated as non-negotiable; any conflict is a CRITICAL finding requiring artifact remediation, not weakening of principles.

## [0.0.16] - 2025-09-22

### Added

- `--force` flag for `init` command to bypass confirmation when using `--here` in a non-empty directory and proceed with merging/overwriting files.

## [0.0.15] - 2025-09-21

### Added

- Support for Roo Code.

## [0.0.14] - 2025-09-21

### Changed

- Error messages are now shown consistently.

## [0.0.13] - 2025-09-21

### Added

- Support for Kilo Code. Thank you [@shahrukhkhan489](https://github.com/shahrukhkhan489) with [#394](https://github.com/github/spec-kit/pull/394).
- Support for Auggie CLI. Thank you [@hungthai1401](https://github.com/hungthai1401) with [#137](https://github.com/github/spec-kit/pull/137).
- Agent folder security notice displayed after project provisioning completion, warning users that some agents may store credentials or auth tokens in their agent folders and recommending adding relevant folders to `.gitignore` to prevent accidental credential leakage.

### Changed

- Warning displayed to ensure that folks are aware that they might need to add their agent folder to `.gitignore`.
- Cleaned up the `check` command output.

## [0.0.12] - 2025-09-21

### Changed

- Added additional context for OpenAI Codex users - they need to set an additional environment variable, as described in [#417](https://github.com/github/spec-kit/issues/417).

## [0.0.11] - 2025-09-20

### Added

- Codex CLI support (thank you [@honjo-hiroaki-gtt](https://github.com/honjo-hiroaki-gtt) for the contribution in [#14](https://github.com/github/spec-kit/pull/14))
- Codex-aware context update tooling (Bash and PowerShell) so feature plans refresh `AGENTS.md` alongside existing assistants without manual edits.

## [0.0.10] - 2025-09-20

### Fixed

- Addressed [#378](https://github.com/github/spec-kit/issues/378) where a GitHub token may be attached to the request when it was empty.

## [0.0.9] - 2025-09-19

### Changed

- Improved agent selector UI with cyan highlighting for agent keys and gray parentheses for full names

## [0.0.8] - 2025-09-19

### Added

- Windsurf IDE support as additional AI assistant option (thank you [@raedkit](https://github.com/raedkit) for the work in [#151](https://github.com/github/spec-kit/pull/151))
- GitHub token support for API requests to handle corporate environments and rate limiting (contributed by [@zryfish](https://github.com/@zryfish) in [#243](https://github.com/github/spec-kit/pull/243))

### Changed

- Updated README with Windsurf examples and GitHub token usage
- Enhanced release workflow to include Windsurf templates

## [0.0.7] - 2025-09-18

### Changed

- Updated command instructions in the CLI.
- Cleaned up the code to not render agent-specific information when it's generic.

## [0.0.6] - 2025-09-17

### Added

- opencode support as additional AI assistant option

## [0.0.5] - 2025-09-17

### Added

- Qwen Code support as additional AI assistant option

## [0.0.4] - 2025-09-14

### Added

- SOCKS proxy support for corporate environments via `httpx[socks]` dependency

### Fixed

N/A

### Changed

N/A
