# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Planning Configuration

<!--
  This section is filled during the Initial Configuration phase of /speckit.plan.
  The AI interviews the user using AskUserQuestion to gather preferences.
-->

**Configured At**: [timestamp]

| Setting | Value |
|---------|-------|
| Subagents | [Enabled/Disabled] |
| Available Subagents | [list or "None"] |
| Competitive Analysis | [Yes/No/Pending] |
| Review Depth | [Full/Quick/Auto] |

**Subagent Details** (if enabled):
- [ ] api-contracts.md - API design, OpenAPI
- [ ] data-architecture.md - Database, tenancy
- [ ] auth-rbac.md - Authentication, permissions
- [ ] [custom subagents...]

<!--
  ============================================================================
  CONSTITUTION ARTICLE IX COMPLIANCE: GATE COMPLIANCE (Directive 4)

  Before this plan can proceed to task generation, the following Knowledge
  Station gates MUST be verified:

  - Station 06 (API Contracts): OpenAPI covers MVP, error schema standardized
  - Station 07 (Data Architecture): Tenancy model documented, isolation plan exists
  - Station 08 (Auth & RBAC): ADRs exist, permission matrix defined
  - Station 12 (CI/CD): Environments spec exists, release checklist defined
  - Station 13 (Security): Threat model MVP exists, security baseline checked

  This is NON-NEGOTIABLE per the Constitution.
  ============================================================================
-->

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  🛑 STOP: MANDATORY GATES - ARCHITECTURE STATIONS

  BEFORE planning the architecture, you MUST read and verify gates for ALL relevant stations:

  📋 STATION 06 - API Contracts (IF API involved)
  READ: `.specify/knowledge/stations/06-api-contracts.md`
  GATES:
  - [ ] OpenAPI/contract covers all MVP endpoints
  - [ ] Error schema is standardized (error.code, error.message, requestId)
  - [ ] Tenant scoping is consistent across all endpoints
  - [ ] Idempotency strategy defined for mutations

  📋 STATION 07 - Data Architecture (IF Database involved)
  READ: `.specify/knowledge/stations/07-data-architecture.md`
  GATES:
  - [ ] Tenancy model documented (Shared DB/Schema, Shared DB/Sep Schema, Sep DB)
  - [ ] Enforcement pattern defined (server-side only, no naked queries)
  - [ ] Baseline entities included (Tenant, User, Membership, Role, etc.)
  - [ ] Isolation test plan exists

  📋 STATION 08 - Auth & RBAC (IF Auth involved)
  READ: `.specify/knowledge/stations/08-auth-rbac.md`
  GATES:
  - [ ] ADRs exist for auth decisions (Session vs JWT)
  - [ ] Permission Matrix defined (Roles → Permissions)
  - [ ] Membership requirement documented
  - [ ] Billing/Limit integration into auth flow specified

  📋 STATION 12 - CI/CD & Release (ALWAYS)
  READ: `.specify/knowledge/stations/12-cicd-release.md`
  GATES:
  - [ ] Environments Spec defined (Local, Dev, Staging, Prod)
  - [ ] CI Pipeline Spec defined (Lint, Tests, Security scans)
  - [ ] Release Checklist exists (migrations, feature flags, monitoring)

  📋 STATION 13 - Security Baseline (ALWAYS)
  READ: `.specify/knowledge/stations/13-security.md`
  GATES:
  - [ ] Threat Model MVP defined (top threats identified)
  - [ ] Security Baseline Checklist completed
  - [ ] Rate limiting strategy defined for auth endpoints

  If ANY gate cannot be satisfied, STOP and document what's missing.
-->

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [single/web/mobile - determines source structure]
**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]
**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]
**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Tech Stack Approval

<!--
  CONSTITUTION ARTICLE IX, DIRECTIVE 6: Human-In-The-Loop Checkpoints

  This section is filled during Phase 0.5 (Tech Stack Review Checkpoint).
  The AI MUST pause after Phase 0 research and present all decisions for user approval
  before proceeding to Phase 1 (Design & Contracts).

  DO NOT proceed to Phase 1 until this section shows "Approved" status.
-->

| Decision          | Value | Source   | Approved |
|-------------------|-------|----------|----------|
| Language/Version  |       | Spec/Assumed | [ ] |
| Primary Framework |       | Spec/Assumed | [ ] |
| Storage           |       | Spec/Assumed | [ ] |
| ORM/Data Layer    |       | Spec/Assumed | [ ] |
| Testing Framework |       | Spec/Assumed | [ ] |
| Target Platform   |       | Spec/Assumed | [ ] |

**Assumptions Made** (items marked "Assumed" above):

| Item | Assumed Value | Rationale |
|------|---------------|-----------|
| [item] | [value] | [why assumed] |

**Approval Status**: Pending
**Approved By**: [awaiting user confirmation]
**Approved At**: [timestamp]
**Revisions**: [none / list any changes made during review]

## Coding Standards

<!--
  This section is filled during Phase 0.5 (Tech Stack Review Checkpoint).
  The user selects coding conventions via AskUserQuestion.
  These conventions MUST be followed in all task files and implementation.
-->

### Naming Conventions

| Context | Convention | Example |
|---------|------------|---------|
| Variables | [camelCase/snake_case] | `userName` / `user_name` |
| Functions | [camelCase/snake_case] | `getUserById()` / `get_user_by_id()` |
| Classes | PascalCase | `UserService` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Files (components) | [PascalCase/kebab-case] | `UserProfile.tsx` / `user-profile.tsx` |
| Files (utilities) | kebab-case | `date-utils.ts` |
| Database tables | snake_case | `user_profiles` |
| Database columns | snake_case | `created_at` |
| API endpoints | kebab-case | `/api/user-profiles` |
| CSS classes | kebab-case | `user-profile-card` |
| Environment vars | SCREAMING_SNAKE_CASE | `DATABASE_URL` |

### Tooling

| Tool | Configuration | Command |
|------|---------------|---------|
| Linter | [config file path] | `[lint command]` |
| Formatter | [config file path] | `[format command]` |
| Type Checker | [config file path] | `[type check command]` |

### Agreed Standards

- **Language Style Guide**: [link or name, e.g., "Airbnb JavaScript Style Guide"]
- **Pre-commit Hooks**: [Yes/No]
- **Enforced in CI**: [Yes/No]

**Standards Approved By**: [user]
**Standards Approved At**: [timestamp]

## Tech Stack Validation

<!--
  CONSTITUTION ARTICLE IX, DIRECTIVE 6: Human-In-The-Loop Checkpoints

  This section is filled during Phase 0.6 (Compatibility Validation).
  After the user approves tech stack CHOICES (Phase 0.5), the system validates:
  - Package freshness (last publish date)
  - Deprecation notices
  - Peer dependency conflicts
  - Version compatibility
  - Security advisories

  The user then reviews findings in Phase 0.7 and either:
  - Accepts recommendations
  - Provides alternatives
  - Overrides with documented reason

  DO NOT proceed to Phase 1 until validation is complete.
-->

**Validation Date**: [timestamp]
**Validation Status**: [NOT_RUN | PASS | PASS_WITH_WARNINGS | PASS_WITH_OVERRIDES | FAIL]

### Validation Results

| Package | Proposed | Validated | Status | Notes |
|---------|----------|-----------|--------|-------|
| [package] | [version] | [resolved] | [PASS/WARN/FAIL] | [notes] |

### Warnings

| Package | Issue | Recommendation |
|---------|-------|----------------|
| [package] | [issue found] | [what to do] |

### User Overrides

<!--
  Document any warnings the user chose to accept despite recommendations.
  This creates an audit trail for future debugging.
-->

| Package | Issue | User Decision | Reason |
|---------|-------|---------------|--------|
| [package] | [issue] | [Accept/Change to X] | [user's reason] |

**Validation Approval**: Pending
**Validated By**: [awaiting user confirmation]
**Validated At**: [timestamp]

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

[Gates determined based on constitution file]

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── spec.md              # Feature specification (/speckit.specify output)
├── plan.md              # This file (/speckit.plan output)
├── research.md          # Phase 0 output (/speckit.plan)
├── data-model.md        # Phase 1 output (/speckit.plan)
├── quickstart.md        # Phase 1 output (/speckit.plan)
├── contracts/           # Phase 1 output (/speckit.plan)
│
│   🆕 ATOMIC TRACEABILITY STRUCTURE (created by /speckit.tasks):
│
├── index.md             # Feature dashboard - entry point
├── traceability.md      # Requirement-to-task mapping matrix
└── tasks/               # Atomic task directory (NOT a single tasks.md!)
    ├── T-001-setup-project.md
    ├── T-010-create-user-model.md
    ├── T-020-implement-endpoint.md
    └── ...
```

<!--
  Per Constitution Article IX (Atomic Injunction):
  - The /speckit.tasks command MUST create a tasks/ directory
  - It is FORBIDDEN to create a single tasks.md file
  - Each task is an individual T-XXX-[name].md file
-->

### Source Code (repository root)

<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
