<div align="center">
    <h1>Atomic Spec</h1>
    <h3><em>Atomic Traceability Model for AI-Driven Development</em></h3>
</div>

<p align="center">
    <strong>A customized fork of Spec Kit implementing the Atomic Traceability Model - a strict governance framework that eliminates "vibe coding" through Constitutional Prime Directives, Knowledge Station Gates, and Context Pinning.</strong>
</p>

---

## What's Different in Atomic Spec?

This fork implements the **Atomic Traceability Model**, a governance upgrade that enforces:

1. **Constitutional Prime Directives** - Eight non-negotiable rules in `memory/constitution.md` (Article IX)
2. **Knowledge Station Gates** - 18 governance checkpoints that MUST pass before phase transitions
3. **Atomic Task Structure** - Individual task files instead of a single `tasks.md`
4. **Context Pinning** - During implementation, AI can ONLY read `index.md` + current task file
5. **Human-In-The-Loop** - Mandatory checkpoints for tech stack, validation, UI, and registry sync
6. **Project Defaults Registry** - Central source of truth for project-wide technical decisions
7. **Self-Contained Tasks** - All context embedded INTO task files for implementation
8. **Dynamic Agent Discovery** - 21+ specialized subagents matched by semantic similarity

### The Eight Prime Directives

| Directive | Rule |
|-----------|------|
| **1. Directory Supremacy** | Every feature MUST have an `index.md` (dashboard) and `traceability.md` (matrix) |
| **2. Atomic Injunction** | `/atomicspec.tasks` is FORBIDDEN from creating a single `tasks.md` - must create `tasks/` directory with individual `T-XXX-[name].md` files |
| **3. Context Pinning** | During `/atomicspec.implement`, AI is FORBIDDEN from reading `plan.md` - may ONLY read `index.md`, specific task file, and `traceability.md` |
| **4. Gate Compliance** | MUST follow Knowledge Station gate criteria before phase transitions |
| **5. Knowledge Routing** | When encountering unknown decisions, MUST consult Station Map first, then specific station |
| **6. Human-In-The-Loop** | During `/atomicspec.plan`, AI MUST pause at 4 checkpoints for user approval |
| **7. Project Defaults Registry** | All commands MUST read `specs/_defaults/registry.yaml` and enforce project-wide standards |
| **8. Self-Contained Tasks** | Task files MUST embed all context (registry, domain rules, gate criteria) for implementation |

---

## The Assembly Line Mental Model

Atomic Spec treats AI-driven development like a **factory assembly line**, not a freeform workshop. Every phase of your work is a **station**, and the product (your code) moves from one station to the next only when it passes inspection.

- **Stations** — each phase (specify → plan → tasks → implement) is a discrete station with a clear job. Knowledge Stations in `.specify/knowledge/stations/` extend this: 18 procedural guides covering every aspect of building a SaaS product.
- **Deliverables** — each station outputs tangible artifacts: a spec file, a plan document, atomic task files, production code. If you can't open it, read it, run it, or test it, it's not a deliverable.
- **Gates** — each station ends with objective pass/fail criteria. "Feels good" is never a gate. The spec has edge cases or it doesn't. The tenancy model is decided or it isn't.
- **Core rule** — **no gate pass → no proceeding**. You cannot enter planning without a passing spec. You cannot generate tasks without a passing plan. You cannot implement without passing gates.

This is the entire reason Atomic Spec exists: **AI coding agents produce drift when they operate without gates**. The assembly line replaces vibes with checkpoints.

---

## Table of Contents

- [The Assembly Line Mental Model](#the-assembly-line-mental-model)
- [Quick Start (Atomic Spec)](#quick-start-atomic-spec)
- [Project Defaults Registry](#project-defaults-registry)
- [Self-Contained Tasks (Knowledge Wiring)](#self-contained-tasks-knowledge-wiring)
- [Dynamic Agent Discovery](#dynamic-agent-discovery)
- [Atomic Traceability Workflow](#atomic-traceability-workflow)
- [Knowledge Stations](#knowledge-stations)
- [Feature Directory Structure](#feature-directory-structure)
- [Available Commands](#available-commands)
- [Original Spec Kit Documentation](#original-spec-kit-documentation)

---

## Quick Start (Atomic Spec)

### Option 1: Initialize Script (Recommended)

Use the initialization scripts to bootstrap a new project with Atomic Spec:

**PowerShell (Windows):**
```powershell
.\init-project.ps1 -TargetPath "D:\MyNewProject" -AIAgent "claude"
```

**Bash (macOS/Linux):**
```bash
./init-project.sh /path/to/new/project --ai claude
```

**Supported AI Agents (via local installer):** `claude`, `gemini`, `copilot`, `cursor`, `windsurf`

### AI agent support tiers (PyPI distribution)

When installed via PyPI (`uv tool install atomic-spec`), Atomic Spec ships template bundles for **17 AI coding agents** across two tiers:

| Agent | `--ai` value | Tier | Notes |
|-------|--------------|------|-------|
| Claude Code | `claude` | **Supported** | Reference implementation; validated end-to-end |
| GitHub Copilot | `copilot` | **Supported** | VS Code chat modes; may require pointing Copilot at the installed command folder |
| Gemini CLI | `gemini` | **Supported** | |
| Cursor | `cursor-agent` | **Supported** | |
| Windsurf | `windsurf` | **Supported** | |
| Qwen Code | `qwen` | Experimental | |
| opencode | `opencode` | Experimental | |
| Codex CLI | `codex` | Experimental | |
| Kilo Code | `kilocode` | Experimental | |
| Auggie CLI | `auggie` | Experimental | |
| CodeBuddy | `codebuddy` | Experimental | |
| Qoder CLI | `qoder` | Experimental | |
| Roo Code | `roo` | Experimental | |
| Amazon Q Developer CLI | `q` | Experimental | |
| Amp | `amp` | Experimental | |
| SHAI | `shai` | Experimental | |
| IBM Bob | `bob` | Experimental | |

**What "Experimental" means:** command templates are installed into the agent's conventional `{folder}commands/` path. The **Eight Prime Directives still apply** — they are enforced by the templates themselves. However, agent-specific wiring has not been validated end-to-end. If you hit issues, file them with the `experimental` label; PRs to promote an agent to Supported tier are welcome. See [SUPPORT.md](./SUPPORT.md) for triage policy.

### Option 2: Manual Setup

1. Copy these directories to your project:
   - `.specify/` - Knowledge stations and governance
   - `templates/` - Spec templates including atomic task structure
   - `memory/` - Constitution with Article IX
   - `scripts/` - Utility scripts

2. For Claude Code, create `.claude/commands/` and copy command files from `templates/commands/` with `atomicspec.` prefix.

### After Initialization

```bash
cd "your-project"
git checkout -b 001-your-feature-name

# Then use Claude Code commands:
/atomicspec.specify "Your feature description"
/atomicspec.plan
/atomicspec.tasks
/atomicspec.implement
```

---

## Project Defaults Registry

**Constitution Directive 7** introduces a central source of truth for project-wide technical decisions.

### What It Does

The **Project Defaults Registry** at `specs/_defaults/registry.yaml` stores all project-wide technical decisions:

```yaml
# specs/_defaults/registry.yaml
version: 2
architecture:
  pattern: monolith          # or microservices, serverless
  layers: clean              # or mvc, vertical_slice
  api_style: rest            # or graphql, grpc
code_patterns:
  data_access: repository    # or active_record, query_builder
  error_handling: result_type # or exceptions, error_codes
  validation_approach: schema # or manual, decorator
backend:
  language: typescript
  framework: express
database:
  type: postgresql
  tenancy_model: shared_db_tenant_id
# ... 80+ configurable decisions
```

### How It Works

| Phase | Action |
|-------|--------|
| **On Entry** | Every command reads registry, applies existing defaults |
| **During Work** | New decisions prompt user: "Add to project defaults?" |
| **On Exit** | Registry sync checkpoint collects all new decisions with HITL approval |
| **Deviation** | Using a different value requires explicit DEVIATION block + approval |

### HITL Requirements

Every registry change requires Human-In-The-Loop approval:

```
══════════════════════════════════════════════════════════════
📋 REGISTRY SYNC - Phase 0.9 Checkpoint
══════════════════════════════════════════════════════════════

The following decisions were made in this planning session
and are NOT yet in the project defaults registry:

| Key                      | Value           | Add to Registry? |
|--------------------------|-----------------|------------------|
| backend.language         | typescript      | Candidate        |
| backend.framework        | express         | Candidate        |

Adding these to the registry means ALL future features
will use these as defaults.
══════════════════════════════════════════════════════════════
```

### Audit Trail

All changes are logged in `specs/_defaults/changelog.md`:

```markdown
### 2026-02-06 | backend.language
- **Changed**: `null` → `typescript`
- **Why**: Decided during user-auth feature planning
- **Source**: specs/001-user-auth/plan.md
- **Approved by**: Human (accept)
```

---

## Self-Contained Tasks (Knowledge Wiring)

**Constitution Directive 8** ensures task files contain ALL context needed for implementation.

### The Problem

During `/atomicspec.implement`, **Context Pinning** (Directive 3) prevents reading:
- `plan.md`, `spec.md`
- `.specify/knowledge/stations/*`
- `.specify/subagents/*`
- Other task files

This meant subagents were "blind" to project patterns and had to guess.

### The Solution

During `/atomicspec.tasks`, ALL context is **embedded INTO each task file**:

```markdown
# T-025-create-user-repository

## 📋 Embedded Context (READ THIS FIRST)

### Project Standards (from registry)
| Key | Value |
|-----|-------|
| `architecture.layers` | clean |
| `code_patterns.data_access` | repository |
| `database.tenancy_model` | shared_db_tenant_id |

### Domain Rules (from data-architecture subagent)
- **Tenancy**: Every query MUST filter by `tenant_id`
- **No naked queries**: All DB access through repository methods only
- **Audit columns**: Include `created_at`, `updated_at`, `created_by`

### Gate Criteria (from data-architecture subagent)
- [ ] Repository interface defined with tenant-scoped methods
- [ ] No direct ORM calls outside repository
- [ ] All queries filter by tenant_id

---

## 🎯 Objective
Create the UserRepository class implementing the repository pattern...
```

### Graceful Degradation

Not all projects have all knowledge sources:

| Missing Source | Action |
|----------------|--------|
| Registry | Embed: "No registry - using plan.md decisions" |
| Subagent | Check for full station file, extract key rules |
| Station | Embed: "No domain knowledge available" |
| Everything | Embed plan.md decisions directly, note limited context |

**Tasks are NEVER blocked by missing knowledge sources.**

---

## Dynamic Agent Discovery

**21 specialized subagents** are available in `.specify/subagents/`, matched dynamically based on feature needs.

### How It Works

Agent selection is **NOT hard-coded**. Instead:

1. **Scan available agents**: Read all `*.md` files in `.specify/subagents/` (excluding `_*` files)
2. **Extract metadata**: Parse YAML frontmatter for `name` and `description`
3. **Match by similarity**: Compare spec/task keywords against agent descriptions
4. **Load relevant agents**: Only agents whose description matches the feature's needs

### Example Matching

```
Spec mentions "REST API", "endpoints"
  → Agent description: "Design RESTful APIs, microservice boundaries..."
  → Match: backend-architect ✓

Spec mentions "payment", "subscription"
  → Agent description: "Integrate Stripe, PayPal, and payment processors..."
  → Match: payment-integration ✓
```

### Available Subagents

| Agent | Domain |
|-------|--------|
| `backend-architect` | REST APIs, microservices, database schemas |
| `data-architecture` | Database design, tenancy models, migrations |
| `frontend-developer` | React components, responsive layouts, state management |
| `payment-integration` | Stripe, PayPal, checkout flows, subscriptions |
| `database-optimizer` | SQL optimization, indexes, query performance |
| `deployment-engineer` | CI/CD, Docker, Kubernetes, infrastructure |
| `code-reviewer` | Code quality, security, maintainability |
| `typescript-pro` | Advanced TypeScript, generics, strict typing |
| `python-pro` | Idiomatic Python, decorators, async/await |
| `sql-pro` | Complex SQL, CTEs, window functions |
| `ui-ux-designer` | Interface design, wireframes, accessibility |
| `performance-engineer` | Profiling, bottlenecks, caching strategies |
| `prompt-engineer` | LLM prompts, AI features, agent orchestration |
| ... and 8 more | See `.specify/subagents/` for full list |

### Adding Custom Agents

Create `.specify/subagents/custom/your-agent.md`:

```yaml
---
name: your-agent
description: Your agent's purpose and keywords for matching
model: opus  # or sonnet, haiku
---

Agent instructions here...
```

The agent will be automatically discovered and matched when features mention keywords from its description.

---

## Atomic Traceability Workflow

### Phase Flow

```
/atomicspec.specify  -->  /atomicspec.AnalyzeCompetitors (optional)  -->  /atomicspec.plan  -->  /atomicspec.tasks  -->  /atomicspec.implement
     |                           |                                       |                    |                     |
     v                           v                                       v                    v                     v
  spec.md                  competitive-analysis/                   Phase 0.0: Registry    tasks/               Execute with
  + Gates 03-05            summary.md + competitors/               Phase 0.1: Domain      T-XXX-*.md           Context Pinning
  + Registry check         🛑 User review                          Phase 0: Research      index.md             + Registry
                           (accept/revise/reject)                  Phase 0.5: HITL #1     traceability.md      as reference
                                                                   Phase 0.6: Validate    + Embedded Context
                                                                   Phase 0.7: HITL #2     (from registry,
                                                                   Phase 0.8: HITL #3     subagents, gates)
                                                                   Phase 0.9: HITL #4
                                                                   Phase 1: Design
                                                                   + Gates 06-13
```

### Planning Phases Explained

| Phase | Name | Purpose |
|-------|------|---------|
| 0.0 | **Load Registry** | Read project defaults, pre-populate tech decisions |
| 0.1 | **Load Domain Knowledge** | Dynamically discover and load relevant subagents/stations |
| 0 | **Research** | Resolve unknowns, research best practices |
| 0.5 | **HITL #1: Tech Stack** | User approves language, framework, database choices |
| 0.6 | **Validation** | Check package compatibility, deprecation, conflicts |
| 0.7 | **HITL #2: Validation Review** | User reviews warnings, approves overrides |
| 0.8 | **HITL #3: UI Specs** | User selects UI library, state management, design system |
| 0.9 | **HITL #4: Registry Sync** | User approves adding new decisions to project defaults |
| 1 | **Design** | Generate data models, API contracts, architecture |

### Competitive Analysis (Optional)

The `/atomicspec.AnalyzeCompetitors` command is **optional** but recommended for customer-facing products. It follows Station 03 (Discovery) procedures:

1. **User Research Check** - Asks if you have existing competitive research to share
2. **Search Frame** - Defines primary, adjacent, and substitute categories
3. **Competitor Benchmarking** - Analyzes 5-15 competitors on positioning, pricing, workflows, integrations, and weak points
4. **Pain Mining** - Extracts user complaints from reviews, forums, and support docs
5. **Synthesis** - Produces wedge candidates and recommends a differentiation strategy

**Output Structure:**
```
specs/[feature]/competitive-analysis/
├── summary.md              # Main reference for downstream commands
├── user-research/          # Your existing research (if provided)
└── competitors/
    ├── competitor-1.md
    ├── competitor-2.md
    └── ...
```

**HITL Review:** After analysis, you review the summary and can:
- **Accept** - Keep for use in `/atomicspec.plan`
- **Revise** - Request changes
- **Reject** - Delete entirely (downstream commands proceed without competitive context)

**Why "Reject" Deletes Everything:** If you don't want competitive analysis influencing decisions, the folder is deleted. This signals to `/atomicspec.plan` that no competitive context exists, so it makes decisions based on general knowledge only. This is intentional - no analysis means no competitive influence.

### Human-In-The-Loop Checkpoint (Phase 0.5)

During `/atomicspec.plan`, after Phase 0 (Research) completes, the AI **MUST PAUSE** and present all tech stack decisions for user approval:

```
══════════════════════════════════════════════════════════════
🛑 TECH STACK REVIEW - Phase 0.5 Checkpoint
══════════════════════════════════════════════════════════════

| Decision          | Value             | Source   |
|-------------------|-------------------|----------|
| Language/Version  | Python 3.11       | Spec     |
| Storage           | PostgreSQL        | Assumed  |

⚠️ ASSUMPTIONS: Storage was assumed based on SaaS patterns.

Reply "proceed", "revise: [changes]", or ask questions.
══════════════════════════════════════════════════════════════
```

**Why this matters:** Tech stack decisions are expensive to change post-implementation. This checkpoint prevents AI from making assumptions that lead to rework.

### Gate Checkpoints

Each phase requires passing specific Knowledge Station gates:

| Phase | Command | Required Gates |
|-------|---------|----------------|
| Specification | `/atomicspec.specify` | Station 03 (Discovery), 04 (PRD), 05 (User Flows) |
| Planning | `/atomicspec.plan` | Station 06 (API), 07 (Data), 08 (Auth), 12 (CI/CD), 13 (Security) |
| Task Generation | `/atomicspec.tasks` | Validates all prior gates, creates atomic structure |
| Implementation | `/atomicspec.implement` | Context Pinning enforced - reads only current task |

### Context Pinning (Implementation Phase)

During `/atomicspec.implement`, the AI operates under strict constraints:

**ALLOWED to read:**
- `index.md` - Feature dashboard (entry point)
- Current `T-XXX-*.md` task file only
- `traceability.md` - For marking completion

**FORBIDDEN from reading:**
- `plan.md` - Contains too much context, causes drift
- Other task files - One task at a time
- `spec.md` - Already distilled into tasks

This prevents "kitchen sink" implementations and ensures focused, atomic execution.

---

## Knowledge Stations

Atomic Spec includes 18 Knowledge Stations in `.specify/knowledge/stations/`:

| # | Station | Purpose | Gate Phase |
|---|---------|---------|------------|
| 01 | Introduction | Manual overview, Assembly Line concept | Foundation |
| 02 | Roles & Ownership | RACI matrix, Gate responsibilities | Foundation |
| 03 | Discovery | ICP, Wedge, JTBD, Competitors | Specify |
| 04 | PRD Spec | MVP scope, SaaS rules, Acceptance criteria | Specify |
| 05 | User Flows | Edge states, RBAC, Information Architecture | Specify |
| 06 | API Contracts | OpenAPI, error schema, Idempotency | Plan |
| 07 | Data Architecture | Tenancy model, isolation, ADRs | Plan |
| 08 | Auth & RBAC | Session/JWT, permissions, Security hardening | Plan |
| 09 | Billing | Stripe integration, Webhooks, State machine | Plan |
| 10 | Metering & Limits | Usage tracking, Quotas, Cost control | Plan |
| 11 | Observability | Logging, tracing, Alerting, Runbooks | Plan |
| 12 | CI/CD & Release | Environments, pipelines, Migrations | Plan |
| 13 | Security | Threat model, baseline, AppSec workflow | Plan |
| 14 | Data Lifecycle | Retention, GDPR, Backups, Deletion | Plan |
| 15 | Performance | Latency targets, Caching, Load testing | Scale |
| 16 | Analytics | Event tracking, Funnels, Dashboards | Scale |
| 17 | Admin Tooling | Support panel, Playbooks, Audit logging | Scale |
| 18 | Documentation | PRD/ADR templates, Repo structure | Scale |

---

## Feature Directory Structure

After running the full workflow, your project looks like:

```
your-project/
│
│   PROJECT-WIDE DEFAULTS (/atomicspec.plan creates, all commands use):
│
├── specs/_defaults/
│   ├── registry.yaml    # Source of truth for project-wide tech decisions
│   ├── changelog.md     # Audit trail (what/when/why/who)
│   └── README.md        # Registry documentation
│
│   FEATURE-SPECIFIC FILES:
│
├── specs/001-feature-name/
│   ├── spec.md              # Feature specification (/atomicspec.specify)
│   │
│   │   COMPETITIVE ANALYSIS (optional, /atomicspec.AnalyzeCompetitors):
│   │
│   ├── competitive-analysis/
│   │   ├── summary.md       # Main reference doc (patterns, pains, wedge)
│   │   ├── user-research/   # User's custom materials (if provided)
│   │   └── competitors/     # Individual competitor analyses
│   │       ├── competitor-1.md
│   │       └── ...
│   │
│   │   IMPLEMENTATION PLANNING (/atomicspec.plan):
│   │
│   ├── plan.md              # Implementation plan
│   ├── research.md          # Technical research
│   ├── data-model.md        # Database schema
│   ├── quickstart.md        # Dev setup guide
│   ├── contracts/           # API contracts (OpenAPI)
│   │
│   │   ATOMIC TRACEABILITY STRUCTURE (/atomicspec.tasks):
│   │
│   ├── index.md             # Feature dashboard - THE entry point
│   ├── traceability.md      # Requirement-to-task mapping matrix
│   └── tasks/               # Atomic task directory (NOT tasks.md!)
│       ├── T-001-setup-project.md     # Each task has Embedded Context:
│       ├── T-010-create-user-model.md # - Project Standards (from registry)
│       ├── T-020-implement-endpoint.md# - Domain Rules (from subagents)
│       ├── T-021-add-validation.md    # - Gate Criteria (from stations)
│       └── ...
│
│   SUBAGENTS (21 specialized agents, dynamically discovered):
│
└── .specify/subagents/
    ├── backend-architect.md
    ├── data-architecture.md
    ├── frontend-developer.md
    └── ... (18 more)
```

### Task File Naming Convention

Tasks follow a numbering scheme by phase:

| Range | Phase |
|-------|-------|
| T-001 to T-009 | Setup & Configuration |
| T-010 to T-019 | Foundation (models, core) |
| T-020 to T-036 | User Story 1 - Features |
| T-037 to T-039 | **User Story 1 - Wiring** (routes, nav, stores) |
| T-040 to T-056 | User Story 2 - Features |
| T-057 to T-059 | **User Story 2 - Wiring** |
| T-060 to T-076 | User Story 3 - Features |
| T-077 to T-079 | **User Story 3 - Wiring** |
| T-080 to T-089 | Cross-cutting concerns |
| T-090 to T-099 | Final verification |

**⚠️ Wiring Tasks are MANDATORY** - Every user story must include wiring tasks that:
- Register backend routes in the main app file
- Add frontend routes to the app router
- Add navigation links to sidebar/nav components
- Connect frontend stores/hooks to backend endpoints

---

## Available Commands

### Core Workflow Commands

| Command | Description |
|---------|-------------|
| `/atomicspec.specify` | Create feature specification with Knowledge Station gates |
| `/atomicspec.AnalyzeCompetitors` | **Optional** - Analyze competitors following Station 03 discovery procedures |
| `/atomicspec.plan` | Create implementation plan with architecture gates |
| `/atomicspec.tasks` | Generate atomic task files (index.md, traceability.md, tasks/) |
| `/atomicspec.implement` | Execute tasks with Context Pinning |
| `/atomicspec.cleanup` | Detect and remove orphaned code, unused components, dead routes |

### Supporting Commands

| Command | Description |
|---------|-------------|
| `/atomicspec.constitution` | View/update project constitution |
| `/atomicspec.clarify` | Clarify underspecified requirements |
| `/atomicspec.analyze` | Cross-artifact consistency analysis |
| `/atomicspec.checklist` | Generate quality validation checklists |
| `/atomicspec.taskstoissues` | Convert tasks to GitHub issues |

### Cleanup Command Details

The `/atomicspec.cleanup` command helps maintain a clean codebase by detecting:

- **Frontend**: Orphan components, dead routes, unused stores
- **Backend**: Unregistered routes, unused services, dead endpoints
- **Database**: Orphan tables, unused columns, stale migrations

**Key Features:**
- **Tech-stack adaptive** - Detects your stack (React, FastAPI, etc.) and offers appropriate tools
- **Per-domain control** - Choose detection method for each domain independently
- **External tools optional** - Use tools like `knip` (JS/TS) or `vulture` (Python), or AI-based detection
- **Feature history aware** - AI-based detection uses previous SpecKit features to boost confidence (e.g., "file created in 001, spec says 003 replaces it")
- **Report first, delete later** - Never auto-deletes; generates report, asks for approval
- **Database schema audit** - Compares schema against codebase to find unused tables/columns

**Workflow:**
1. Detect project structure (frontend/backend/database)
2. For each domain: ask user to choose detection method (tool / AI / skip)
3. Run detection and categorize findings (SAFE / REVIEW / KEEP)
4. Generate `cleanup-report.md` with findings
5. User reviews and approves deletions
6. Execute cleanup with test verification

---

## Two-Tier Governance System

Atomic Spec implements a two-tier governance hierarchy:

### Tier 1: Constitution (`memory/constitution.md`)
- Immutable project principles
- Article IX: Prime Directives (Atomic Traceability)
- Cannot be overridden by any phase

### Tier 2: Assembly Line Manual (`.specify/knowledge/`)
- Knowledge Stations with gate criteria
- Templates that enforce gates
- Scripts that validate compliance

---

## Original Spec Kit Documentation

<details>
<summary>Click to expand the original Spec Kit documentation</summary>

## What is Spec-Driven Development?

Spec-Driven Development **flips the script** on traditional software development. For decades, code has been king - specifications were just scaffolding we built and discarded once the "real work" of coding began. Spec-Driven Development changes this: **specifications become executable**, directly generating working implementations rather than just guiding them.

## Get Started

### 1. Install Atomic Spec into your project

The primary and supported installation path is the `init-project` script in this repo. It copies the framework (`.specify/`, `templates/`, `.claude/commands/`, registry scaffolding) directly into your target project.

```bash
# Clone this repo once
git clone https://github.com/Chappygo-OS/Atomic-Spec.git
cd atomic-spec

# Initialize a new project with Atomic Spec
# Bash (macOS / Linux / WSL)
./init-project.sh /path/to/new/project --ai claude

# PowerShell (Windows)
.\init-project.ps1 -TargetPath "D:\path\to\new\project" -AIAgent "claude"
```

Supported `--ai` values: `claude`, `gemini`, `copilot`, `cursor`, `windsurf`.

After initialization, the four slash commands are available in your AI assistant: `/atomicspec.specify`, `/atomicspec.plan`, `/atomicspec.tasks`, `/atomicspec.implement` (plus optional `/atomicspec.clarify`, `/atomicspec.analyze-competitors`, `/atomicspec.checklist`, `/atomicspec.constitution`, `/atomicspec.cleanup`, `/atomicspec.analyze`, `/atomicspec.taskstoissues`).

### 2. (Planned) PyPI install

Once `v0.1.0` is published, a PyPI install path will be available:

```bash
# Coming soon — v0.1.0
uv tool install atomic-spec
atomicspec init <PROJECT_NAME>
```

Track the release on the [Chappygo-OS/Atomic-Spec releases page](https://github.com/Chappygo-OS/Atomic-Spec/releases).

## Supported AI Agents

| Agent                                                                                | Support | Notes                                                                                                                                     |
| ------------------------------------------------------------------------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| [Qoder CLI](https://qoder.com/cli)                                                   | Yes     |                                                                                                                                           |
| [Amazon Q Developer CLI](https://aws.amazon.com/developer/learning/q-developer-cli/) | Partial | Amazon Q Developer CLI [does not support](https://github.com/aws/amazon-q-developer-cli/issues/3064) custom arguments for slash commands. |
| [Amp](https://ampcode.com/)                                                          | Yes     |                                                                                                                                           |
| [Auggie CLI](https://docs.augmentcode.com/cli/overview)                              | Yes     |                                                                                                                                           |
| [Claude Code](https://www.anthropic.com/claude-code)                                 | Yes     |                                                                                                                                           |
| [CodeBuddy CLI](https://www.codebuddy.ai/cli)                                        | Yes     |                                                                                                                                           |
| [Codex CLI](https://github.com/openai/codex)                                         | Yes     |                                                                                                                                           |
| [Cursor](https://cursor.sh/)                                                         | Yes     |                                                                                                                                           |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli)                            | Yes     |                                                                                                                                           |
| [GitHub Copilot](https://code.visualstudio.com/)                                     | Yes     |                                                                                                                                           |
| [IBM Bob](https://www.ibm.com/products/bob)                                          | Yes     | IDE-based agent with slash command support                                                                                                |
| [Jules](https://jules.google.com/)                                                   | Yes     |                                                                                                                                           |
| [Kilo Code](https://github.com/Kilo-Org/kilocode)                                    | Yes     |                                                                                                                                           |
| [opencode](https://opencode.ai/)                                                     | Yes     |                                                                                                                                           |
| [Qwen Code](https://github.com/QwenLM/qwen-code)                                     | Yes     |                                                                                                                                           |
| [Roo Code](https://roocode.com/)                                                     | Yes     |                                                                                                                                           |
| [SHAI (OVHcloud)](https://github.com/ovh/shai)                                       | Yes     |                                                                                                                                           |
| [Windsurf](https://windsurf.com/)                                                    | Yes     |                                                                                                                                           |

## Specify CLI Reference

The `specify` command supports the following options:

### Commands

| Command | Description                                                                                                                                             |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `init`  | Initialize a new Specify project from the latest template                                                                                               |
| `check` | Check for installed tools (`git`, `claude`, `gemini`, `code`/`code-insiders`, `cursor-agent`, `windsurf`, `qwen`, `opencode`, `codex`, `shai`, `qoder`) |

### `specify init` Arguments & Options

| Argument/Option        | Type     | Description                                                                                                                                                                                  |
| ---------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<project-name>`       | Argument | Name for your new project directory (optional if using `--here`, or use `.` for current directory)                                                                                           |
| `--ai`                 | Option   | AI assistant to use: `claude`, `gemini`, `copilot`, `cursor-agent`, `qwen`, `opencode`, `codex`, `windsurf`, `kilocode`, `auggie`, `roo`, `codebuddy`, `amp`, `shai`, `q`, `bob`, or `qoder` |
| `--script`             | Option   | Script variant to use: `sh` (bash/zsh) or `ps` (PowerShell)                                                                                                                                  |
| `--ignore-agent-tools` | Flag     | Skip checks for AI agent tools like Claude Code                                                                                                                                              |
| `--no-git`             | Flag     | Skip git repository initialization                                                                                                                                                           |
| `--here`               | Flag     | Initialize project in the current directory instead of creating a new one                                                                                                                    |
| `--force`              | Flag     | Force merge/overwrite when initializing in current directory (skip confirmation)                                                                                                             |
| `--skip-tls`           | Flag     | Skip SSL/TLS verification (not recommended)                                                                                                                                                  |
| `--debug`              | Flag     | Enable detailed debug output for troubleshooting                                                                                                                                             |
| `--github-token`       | Option   | GitHub token for API requests (or set GH_TOKEN/GITHUB_TOKEN env variable)                                                                                                                    |

### Examples

```bash
# Basic project initialization
specify init my-project

# Initialize with specific AI assistant
specify init my-project --ai claude

# Initialize with Cursor support
specify init my-project --ai cursor-agent

# Initialize in current directory
specify init . --ai copilot
# or use the --here flag
specify init --here --ai copilot

# Force merge into current (non-empty) directory without confirmation
specify init . --force --ai copilot

# Skip git initialization
specify init my-project --ai gemini --no-git

# Enable debug output for troubleshooting
specify init my-project --ai claude --debug
```

### Environment Variables

| Variable          | Description                                                                                                                                                                                                                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SPECIFY_FEATURE` | Override feature detection for non-Git repositories. Set to the feature directory name (e.g., `001-photo-albums`) to work on a specific feature when not using Git branches.<br/>**Must be set in the context of the agent you're working with prior to using `/atomicspec.plan` or follow-up commands.** |

## Core Philosophy

Spec-Driven Development is a structured process that emphasizes:

- **Intent-driven development** where specifications define the "*what*" before the "*how*"
- **Rich specification creation** using guardrails and organizational principles
- **Multi-step refinement** rather than one-shot code generation from prompts
- **Heavy reliance** on advanced AI model capabilities for specification interpretation

## Development Phases

| Phase                                    | Focus                    | Key Activities                                                                                                                                                     |
| ---------------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **0-to-1 Development** ("Greenfield")    | Generate from scratch    | <ul><li>Start with high-level requirements</li><li>Generate specifications</li><li>Plan implementation steps</li><li>Build production-ready applications</li></ul> |
| **Creative Exploration**                 | Parallel implementations | <ul><li>Explore diverse solutions</li><li>Support multiple technology stacks & architectures</li><li>Experiment with UX patterns</li></ul>                         |
| **Iterative Enhancement** ("Brownfield") | Brownfield modernization | <ul><li>Add features iteratively</li><li>Modernize legacy systems</li><li>Adapt processes</li></ul>                                                                |

## Prerequisites

- **Linux/macOS/Windows**
- [Supported](#supported-ai-agents) AI coding agent.
- [uv](https://docs.astral.sh/uv/) for package management
- [Python 3.11+](https://www.python.org/downloads/)
- [Git](https://git-scm.com/downloads)

If you encounter issues with an agent, please open an issue so we can refine the integration.

</details>

---

## Troubleshooting

### PowerShell Execution Policy (Windows)

If the init script doesn't run, use:
```powershell
powershell -ExecutionPolicy Bypass -File ".\init-project.ps1" -TargetPath "D:\MyProject" -AIAgent "claude"
```

### Git Credential Manager on Linux

If you're having issues with Git authentication on Linux, you can install Git Credential Manager:

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

### Commands Not Available in Claude Code

If `/atomicspec.*` commands don't appear:
1. Ensure `.claude/commands/` directory exists in your project
2. Verify command files are named `atomicspec.*.md` (e.g., `atomicspec.specify.md`)
3. Restart Claude Code after adding commands

---

## License

This project is licensed under the terms of the MIT open source license. Please refer to the [LICENSE](./LICENSE) file for the full terms.

---

## Credits

- **Original Spec Kit**: [GitHub](https://github.com/github/spec-kit) by Den Delimarsky and John Lam
- **Atomic Traceability Model**: Inspired by ["Stop Vibe Coding (Until You Do This)"](https://www.youtube.com/watch?v=020qK_L_X_w) by [Leapable](https://www.youtube.com/@Leapableai)
