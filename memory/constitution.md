# [PROJECT_NAME] Constitution

<!-- Example: Spec Constitution, TaskFlow Constitution, etc. -->

> **Note to Atomic Spec users**: Articles I–VIII below are **intentionally left as `[PLACEHOLDER]` tokens**. They are filled in per consumer project by running `/atomicspec.constitution` — that command interactively authors your project's governing principles and replaces every placeholder.
>
> **Article IX (Prime Directives) is NOT a placeholder** — it is hardcoded below and encodes the eight non-negotiable rules of the Atomic Traceability Model. Do not edit Article IX unless you are deliberately changing framework governance.

## Core Principles

### [PRINCIPLE_1_NAME]

<!-- Example: I. Library-First -->

[PRINCIPLE_1_DESCRIPTION]

<!-- Example: Every feature starts as a standalone library; Libraries must be self-contained, independently testable, documented; Clear purpose required - no organizational-only libraries -->

### [PRINCIPLE_2_NAME]

<!-- Example: II. CLI Interface -->

[PRINCIPLE_2_DESCRIPTION]

<!-- Example: Every library exposes functionality via CLI; Text in/out protocol: stdin/args → stdout, errors → stderr; Support JSON + human-readable formats -->

### [PRINCIPLE_3_NAME]

<!-- Example: III. Test-First (NON-NEGOTIABLE) -->

[PRINCIPLE_3_DESCRIPTION]

<!-- Example: TDD mandatory: Tests written → User approved → Tests fail → Then implement; Red-Green-Refactor cycle strictly enforced -->

### [PRINCIPLE_4_NAME]

<!-- Example: IV. Integration Testing -->

[PRINCIPLE_4_DESCRIPTION]

<!-- Example: Focus areas requiring integration tests: New library contract tests, Contract changes, Inter-service communication, Shared schemas -->

### [PRINCIPLE_5_NAME]

<!-- Example: V. Observability, VI. Versioning & Breaking Changes, VII. Simplicity -->

[PRINCIPLE_5_DESCRIPTION]

<!-- Example: Text I/O ensures debuggability; Structured logging required; Or: MAJOR.MINOR.BUILD format; Or: Start simple, YAGNI principles -->

## [SECTION_2_NAME]

<!-- Example: Additional Constraints, Security Requirements, Performance Standards, etc. -->

[SECTION_2_CONTENT]

<!-- Example: Technology stack requirements, compliance standards, deployment policies, etc. -->

## [SECTION_3_NAME]

<!-- Example: Development Workflow, Review Process, Quality Gates, etc. -->

[SECTION_3_CONTENT]

<!-- Example: Code review requirements, testing gates, deployment approval process, etc. -->

## Governance

<!-- Example: Constitution supersedes all other practices; Amendments require documentation, approval, migration plan -->

[GOVERNANCE_RULES]

<!-- Example: All PRs/reviews must verify compliance; Complexity must be justified; Use [GUIDANCE_FILE] for runtime development guidance -->

### Article IX: Prime Directives (Atomic Traceability)

The following directives are **NON-NEGOTIABLE** and enforce the "Atomic Traceability" model:

#### Directive 1: Directory Supremacy

Every feature MUST have:

- An `index.md` entry point (the feature dashboard)
- A `traceability.md` matrix (requirement-to-task mapping)

**Violation**: Any feature lacking these files is considered incomplete and CANNOT proceed to implementation.

#### Directive 2: Atomic Injunction

The `/atomicspec.tasks` command is **FORBIDDEN** from creating a single `tasks.md` file.

It MUST create:

```
specs/[###-feature-name]/
├── index.md              # Feature dashboard
├── traceability.md       # Requirement-to-task matrix
└── tasks/                # Atomic task directory
    ├── T-001-[name].md
    ├── T-002-[name].md
    └── ...
```

Each atomic task file MUST contain:

1. **ID**: Unique task identifier
2. **Requirement Mapping**: Link to FR-XXX from spec.md
3. **Technical Implementation Detail**: Specific code actions
4. **Verification Command**: The exact test/command to verify completion

#### Directive 3: Context Pinning

During the implementation phase (`/atomicspec.implement`):

- You are **FORBIDDEN** from reading the full `plan.md`
- You may **ONLY** read:
  - `index.md` (for navigation and context)
  - The specific `T-XXX-[name].md` file assigned to the current task loop
  - `traceability.md` (to update status after completion)

**Rationale**: This prevents context pollution and ensures focused, verifiable execution.

#### Directive 4: Gate Compliance

You MUST strictly follow the "Gate Criteria" defined in `.specify/knowledge/stations/` before transitioning between phases:

| Transition        | Required Gates                                   |
| ----------------- | ------------------------------------------------ |
| Spec → Plan       | Stations 03, 04, 05 gates must pass              |
| Plan → Tasks      | Stations 06, 07, 08, 12, 13 gates must pass      |
| Tasks → Implement | All atomic tasks must have verification commands |

**Violation**: Proceeding without passing gates is a Constitution violation.

#### Directive 5: Knowledge Routing (The Map)

If you encounter a technical decision or edge case not covered by the current Task/Plan:

1. You MUST read `.specify/knowledge/stations/00-station-map.md` first.
2. Locate the correct Station ID for your problem.
3. Read ONLY that specific Station file.
4. Apply the rules found there.

**Rationale**: Do not guess. Do not read random files. Go to the authoritative source.

#### Directive 6: Human-In-The-Loop Checkpoints

During `/atomicspec.plan`, the AI MUST pause for user approval at critical decision points:

**Phase 0.5 Checkpoint (Tech Stack Review)**:

After Phase 0 (Research) completes and before Phase 1 (Design) begins:

1. **Present all resolved technical decisions** in a table format:
   - Decisions explicitly from spec (marked "Spec")
   - Decisions assumed by AI (marked "Assumed")

2. **Highlight assumptions** that were NOT explicit in the spec but were inferred from:
   - Knowledge Station defaults
   - Best practices research
   - Domain patterns

3. **PAUSE and wait for user response**:
   - `"proceed"` → Continue to Phase 1 with current decisions
   - `"revise: [specifics]"` → Update decisions and re-present checkpoint
   - Questions → Answer and re-present checkpoint

4. **Record approval** in plan.md with timestamp

**Rationale**: Tech stack decisions are expensive to change post-implementation. Explicit user approval prevents rework and ensures alignment.

**Violation**: Proceeding to Phase 1 without user confirmation is a Constitution violation.

**Skip conditions** (checkpoint may be abbreviated):
- All Technical Context fields were explicit in spec (no assumptions)
- User passes `--no-review` flag (expert mode, assumes full responsibility)

#### Directive 7: Project Defaults Registry (Consistency Enforcement)

The **Project Defaults Registry** at `specs/_defaults/registry.yaml` is the single source of truth for project-wide technical decisions.

**Scope of "registry-eligible decisions" (v0.2 clarification)**:

Registry-eligible decisions include not only the fields explicitly enumerated in `registry.yaml`, but **any structural choice that pervades the codebase**:

- Containerization (Docker / Compose / Kubernetes / none)
- Deployment target (containerized / serverless / VPS / PaaS / static)
- Monorepo vs. polyrepo layout
- File-structure pattern (feature-folder / layer-folder / domain-driven)
- Framework choice in any layer (backend, frontend, ORM, queue, cache, search, etc.)
- Cross-cutting infrastructure (payment provider, email provider, scheduling, file storage)
- Domain primitives (money representation, identifier exposure, time representation)
- Authentication / authorization model (session / JWT / OAuth2 / RBAC / ABAC / etc.)
- Logging and observability stack (structured logs, metrics, traces, error tracking)
- CI/CD platform and deployment workflow
- Package manager and runtime version pins
- Testing framework (unit / integration / E2E)

**Definition of "commit"**: writing config or code that encodes the choice (e.g., creating `docker-compose.yml`, adding a dependency to `package.json`, importing a framework module), OR recording the choice in `plan.md` or a task file as a fixed value. Drafting a comment that *discusses* options is not committing.

When the AI is about to commit to a structural decision **absent from the registry**, it MUST raise an `AskUserQuestion` before applying the decision, then offer to register the answer with provenance `human` or `accepted_recommendation`. This obligation is independent of the on-entry read step in the Protocol below — it fires whenever a qualifying decision arises, in any phase (`/atomicspec.plan`, `/atomicspec.tasks`, `/atomicspec.implement`). The "Docker-without-asking" failure mode (silently choosing a structural default) is a Directive 7 violation, not an unspecified blind spot.

ALL commands, agents, and phases MUST obey this protocol.

**Registry Location**:
```
specs/_defaults/
├── registry.yaml     # Source of truth (structured defaults)
├── changelog.md      # Audit trail (what/when/why/who)
└── README.md         # Documentation
```

**Protocol - On Entry (Before Any Work)**:

1. **Read** `specs/_defaults/registry.yaml`
2. **Filter** to relevant sections (backend work → `api`, `backend`, `database`)
3. **Apply** registry values as non-negotiable defaults

**Protocol - During Work (Decision Detection)**:

| Situation | Action |
|-----------|--------|
| Decision EXISTS in registry | Use it. No deviation without HITL approval. |
| Decision NOT in registry (null) | Ask via `AskUserQuestion`: "Add to project defaults?" |
| Need to DEVIATE from registry | Ask via `AskUserQuestion`: "Approve deviation?" + document |

**Protocol - On Exit (After Phase Completes)**:

1. **Scan** output for new project-wide decisions
2. **Prompt** user for each: "Add as project default?"
3. **Update** registry.yaml AND changelog.md if approved

**Exemption — `/atomicspec.constitution`**:

The `/atomicspec.constitution` command is formally **exempt from the on-entry read step** of this Directive. Rationale: the constitution authors the governance values that the registry later enforces — reading the registry before authoring them would be circular. Constitution MAY still write to the registry on exit if the user approves seeding default governance values (e.g., `governance.quality_gates`, `governance.personas`).

**HITL Requirements for Registry Updates**:

Every registry change MUST:
1. Go through `AskUserQuestion` - no silent updates
2. Provide clear explanation: what's changing, why, impact
3. Allow user to: Accept / Reject / Provide custom value
4. Log in `changelog.md` with full audit trail:
   - **Changed**: old → new
   - **Why**: rationale
   - **Source**: which spec/phase
   - **Approved by**: Human (accept/custom/reject)

**Deviation Documentation**:

If a spec deviates from registry defaults, it MUST include:

```markdown
DEVIATION from project-registry:
- Key: [key.path]
- Default: [registry_value]
- This spec uses: [different_value]
- Reason: [justification]
- Approved: Human (YYYY-MM-DD)
```

**Violation**: Using a value different from registry without explicit DEVIATION block and HITL approval is a Constitution violation.

**Rationale**: Prevents inconsistency (e.g., some APIs versioned, some not). Ensures all technical decisions are intentional and traceable.

#### Directive 8: Self-Contained Tasks (Knowledge Wiring)

Task files generated by `/atomicspec.tasks` MUST be **self-contained**. During implementation, Context Pinning (Directive 3) prevents reading plan.md, spec.md, stations, and subagents. Therefore, ALL context must be embedded INTO each task file.

**Required Embedded Context Section**:

Every task file MUST include an "Embedded Context" section containing:

| Element | Source | When Required |
|---------|--------|---------------|
| **Project Standards** | `specs/_defaults/registry.yaml` | Always (or note "No registry") |
| **Domain Rules** | `.specify/subagents/[domain].md` OR Station files | When task domain matches |
| **API Context** | `FEATURE_DIR/contracts/*.yaml` | When task involves API endpoints |
| **Feature Summary** | `plan.md` (extracted during task generation) | Always |
| **Gate Criteria** | Subagent/Station gate checklists | When domain knowledge exists |
| **Structural Decision Triggers** (v0.2+) | Directive 7 scope list | When the task may commit to containerization, deployment, framework, infrastructure provider, or domain primitive — so the implementer recognizes the AskUserQuestion trigger under Context Pinning |

**Graceful Degradation**:

Not all knowledge sources may exist. Handle gracefully:

| Missing Source | Action |
|----------------|--------|
| Registry | Embed: "No registry - using plan.md decisions" + extract patterns from plan.md |
| Subagent | Check for full station file, extract key rules |
| Station | Embed: "No domain knowledge available" |
| Contracts | Skip API Context section |
| Everything | Embed plan.md decisions directly, note limited context |

**NEVER fail task generation due to missing knowledge. Always produce tasks with whatever context is available.**

**Violation**: Generating task files WITHOUT an Embedded Context section is a Constitution violation. The implementer must have EVERYTHING needed to complete the task without reading forbidden files.

**Rationale**: Subagents during `/atomicspec.implement` are "blind" to stations, subagents, plan.md, and spec.md. Embedding context ensures they follow project patterns instead of guessing.

#### Directive 9: Orientation Read Surface (v0.3+)

**Directive 3 (Context Pinning) is unchanged.** This Directive defines a separate, narrower control for the one-shot **Orientation Phase** that runs at the start of `/atomicspec.implement` to detect cross-provider handoff state. It exists as a sibling to Directive 3, not an expansion of it.

**Purpose**: Before any task loop begins, the implementer must detect whether prior work in this feature folder is partially completed (e.g., a Claude session crashed mid-task; a Codex session resumes). Without this detection, a resuming AI silently re-implements work or overwrites half-finished output.

**Scope — enumerated artifacts only**:

The Orientation Phase MAY inspect the following artifacts in the active feature folder, and ONLY these:

- `spec.md`
- `clarify-log.md` (if present)
- `plan.md`
- `index.md`
- `traceability.md`
- Every file matching `tasks/T-*.md`

"Any artifact" is not permitted. The list above is exhaustive.

**Permitted read mechanism**:

The Orientation Phase MUST read these artifacts ONLY through the `stamp-lifecycle status` script:

```
scripts/bash/stamp-lifecycle.sh status --artifact <path>
scripts/powershell/stamp-lifecycle.ps1 status -Artifact <path>
```

The script returns JSON describing the Lifecycle Markers block state without exposing surrounding content. **Direct `Read`-tool invocation on `spec.md`, `plan.md`, or `clarify-log.md` body content during Phase 0 is a Constitution violation, regardless of intent.** `index.md` and `traceability.md` may be read directly because Directive 3 already permits them.

**Evidence requirement**:

The Orientation Phase MUST emit its findings as a single block at the bottom of `traceability.md` under a `## Orientation Evidence` heading, containing the script's JSON output for each inspected artifact and the timestamp of the orientation run. Absence of this evidence block fails the Phase 0 gate; the implementer cannot proceed to Phase 1.

**Outcomes — exactly three**:

1. **Clean state** — every artifact reports `closed` (or `legacy_closed` for pre-v0.3 artifacts without stamps). Print a single-line summary; proceed to Phase 1. Normal Context Pinning resumes.
2. **Stale state** — one or more artifacts have an `open` block whose start timestamp is older than the registry's `lifecycle.stale_threshold` (default: 7 days). Surface as informational ("this work appears abandoned"), let the user confirm resume-or-discard. Not blocking.
3. **Conflict** — one or more artifacts have an `open` block with a start timestamp newer than the stale threshold. STOP, present options menu to user (resume / redo / skip / abort), await confirmation before proceeding.

**Termination**:

Once a task is pinned in Phase 1, the Orientation Phase is finished. Subsequent reads in the session are governed by Directive 3 alone. The Phase 0 carve-out is single-shot, not persistent.

**Violation**: Reading body content of `spec.md`, `plan.md`, or `clarify-log.md` during Phase 0; omitting the `## Orientation Evidence` block from `traceability.md`; or expanding the enumerated artifact scope without a Constitution amendment.

**Rationale**: A governance framework that prevents drift during implementation must also prevent silent failure at session start. The Orientation Phase is the one place where cross-artifact reads are necessary, and isolating it as its own narrow Directive keeps Directive 3 verbatim — preserving the "implementer reads exactly three files" guarantee that the framework's positioning depends on.

### Article X: The Assembly Line Manual

The **Assembly Line Manual** (located in `.specify/knowledge/stations/`) is the authoritative procedural guide for all implementation details.

1.  **Supremacy**: In any conflict between the Assembly Line Manual and this Constitution, you should pause and ask the user for clarification. The problem should be well-explained.
2.  **Mandatory Reference**: Before generating any artifact (Plan, Task list, or Code), you MUST read the specific Station file corresponding to that domain (e.g., read `06-api-contracts.md` before planning APIs).
3.  **Gatekeeper**: You may not mark a task as complete until the specific "Gate Criteria" defined in that Station are met.

**Version**: [CONSTITUTION_VERSION] | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]

<!-- Example: Version: 2.1.1 | Ratified: 2025-06-13 | Last Amended: 2025-07-16 -->
