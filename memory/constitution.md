# [PROJECT_NAME] Constitution

<!-- Example: Spec Constitution, TaskFlow Constitution, etc. -->

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

The `/speckit.tasks` command is **FORBIDDEN** from creating a single `tasks.md` file.

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

During the implementation phase (`/speckit.implement`):

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

During `/speckit.plan`, the AI MUST pause for user approval at critical decision points:

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

### Article X: The Assembly Line Manual

The **Assembly Line Manual** (located in `.specify/knowledge/stations/`) is the authoritative procedural guide for all implementation details.

1.  **Supremacy**: In any conflict between the Assembly Line Manual and this Constitution, you should pause and ask the user for clarification. The problem should be well-explained.
2.  **Mandatory Reference**: Before generating any artifact (Plan, Task list, or Code), you MUST read the specific Station file corresponding to that domain (e.g., read `06-api-contracts.md` before planning APIs).
3.  **Gatekeeper**: You may not mark a task as complete until the specific "Gate Criteria" defined in that Station are met.

**Version**: [CONSTITUTION_VERSION] | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]

<!-- Example: Version: 2.1.1 | Ratified: 2025-06-13 | Last Amended: 2025-07-16 -->
