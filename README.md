<div align="center">
    <img src="./media/logo_large.webp" alt="Spec Kit Logo" width="200" height="200"/>
    <h1>Custom Speckit - Exact Assembly Line</h1>
    <h3><em>Atomic Traceability Model for AI-Driven Development</em></h3>
</div>

<p align="center">
    <strong>A customized fork of Spec Kit implementing the Atomic Traceability Model - a strict governance framework that eliminates "vibe coding" through Constitutional Prime Directives, Knowledge Station Gates, and Context Pinning.</strong>
</p>

---

## What's Different in Custom Speckit - Exact Assembly Line?

This fork implements the **Atomic Traceability Model**, a governance upgrade based on the "Andre/Mable AI workflow" that enforces:

1. **Constitutional Prime Directives** - Six non-negotiable rules in `memory/constitution.md` (Article IX)
2. **Knowledge Station Gates** - 18 governance checkpoints that MUST pass before phase transitions
3. **Atomic Task Structure** - Individual task files instead of a single `tasks.md`
4. **Context Pinning** - During implementation, AI can ONLY read `index.md` + current task file
5. **Human-In-The-Loop** - Mandatory tech stack review checkpoint before design phase

### The Six Prime Directives

| Directive | Rule |
|-----------|------|
| **Directory Supremacy** | Every feature MUST have an `index.md` (dashboard) and `traceability.md` (matrix) |
| **Atomic Injunction** | `/speckit.tasks` is FORBIDDEN from creating a single `tasks.md` - must create `tasks/` directory with individual `T-XXX-[name].md` files |
| **Context Pinning** | During `/speckit.implement`, AI is FORBIDDEN from reading `plan.md` - may ONLY read `index.md`, specific task file, and `traceability.md` |
| **Gate Compliance** | MUST follow Knowledge Station gate criteria before phase transitions |
| **Knowledge Routing** | When encountering unknown decisions, MUST consult Station Map first, then specific station |
| **Human-In-The-Loop** | During `/speckit.plan`, AI MUST pause after Phase 0 to present tech stack decisions for user approval before proceeding to Phase 1 |

---

## Table of Contents

- [Quick Start (Custom Speckit - Exact Assembly Line)](#quick-start-custom-speckit---exact-assembly-line)
- [Atomic Traceability Workflow](#atomic-traceability-workflow)
- [Knowledge Stations](#knowledge-stations)
- [Feature Directory Structure](#feature-directory-structure)
- [Available Commands](#available-commands)
- [Original Spec Kit Documentation](#original-spec-kit-documentation)

---

## Quick Start (Custom Speckit - Exact Assembly Line)

### Option 1: Initialize Script (Recommended)

Use the initialization scripts to bootstrap a new project with Custom Speckit - Exact Assembly Line:

**PowerShell (Windows):**
```powershell
.\init-project.ps1 -TargetPath "D:\MyNewProject" -AIAgent "claude"
```

**Bash (macOS/Linux):**
```bash
./init-project.sh /path/to/new/project --ai claude
```

**Supported AI Agents:** `claude`, `gemini`, `copilot`, `cursor`, `windsurf`

### Option 2: Manual Setup

1. Copy these directories to your project:
   - `.specify/` - Knowledge stations and governance
   - `templates/` - Spec templates including atomic task structure
   - `memory/` - Constitution with Article IX
   - `scripts/` - Utility scripts

2. For Claude Code, create `.claude/commands/` and copy command files from `templates/commands/` with `speckit.` prefix.

### After Initialization

```bash
cd "your-project"
git checkout -b 001-your-feature-name

# Then use Claude Code commands:
/speckit.specify "Your feature description"
/speckit.plan
/speckit.tasks
/speckit.implement
```

---

## Atomic Traceability Workflow

### Phase Flow

```
/speckit.specify  -->  /speckit.AnalyzeCompetitors (optional)  -->  /speckit.plan  -->  /speckit.tasks  -->  /speckit.implement
     |                           |                                       |                    |                     |
     v                           v                                       v                    v                     v
  spec.md                  competitive-analysis/                   Phase 0: Research      tasks/               Execute with
  + Gates 03-05            summary.md + competitors/               Phase 0.5: HITL #1     T-XXX-*.md           Context Pinning
                           🛑 User review                          Phase 0.6: Validate    index.md
                           (accept/revise/reject)                  Phase 0.7: HITL #2     traceability.md
                                                                   Phase 1: Design
                                                                   + Gates 06-13
```

### Competitive Analysis (Optional)

The `/speckit.AnalyzeCompetitors` command is **optional** but recommended for customer-facing products. It follows Station 03 (Discovery) procedures:

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
- **Accept** - Keep for use in `/speckit.plan`
- **Revise** - Request changes
- **Reject** - Delete entirely (downstream commands proceed without competitive context)

**Why "Reject" Deletes Everything:** If you don't want competitive analysis influencing decisions, the folder is deleted. This signals to `/speckit.plan` that no competitive context exists, so it makes decisions based on general knowledge only. This is intentional - no analysis means no competitive influence.

### Human-In-The-Loop Checkpoint (Phase 0.5)

During `/speckit.plan`, after Phase 0 (Research) completes, the AI **MUST PAUSE** and present all tech stack decisions for user approval:

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
| Specification | `/speckit.specify` | Station 03 (Discovery), 04 (PRD), 05 (User Flows) |
| Planning | `/speckit.plan` | Station 06 (API), 07 (Data), 08 (Auth), 12 (CI/CD), 13 (Security) |
| Task Generation | `/speckit.tasks` | Validates all prior gates, creates atomic structure |
| Implementation | `/speckit.implement` | Context Pinning enforced - reads only current task |

### Context Pinning (Implementation Phase)

During `/speckit.implement`, the AI operates under strict constraints:

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

Custom Speckit - Exact Assembly Line includes 18 Knowledge Stations in `.specify/knowledge/stations/`:

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

After running the full workflow, your feature directory looks like:

```
specs/001-feature-name/
├── spec.md              # Feature specification (/speckit.specify)
│
│   COMPETITIVE ANALYSIS (optional, /speckit.AnalyzeCompetitors):
│
├── competitive-analysis/
│   ├── summary.md       # Main reference doc (patterns, pains, wedge)
│   ├── user-research/   # User's custom materials (if provided)
│   └── competitors/     # Individual competitor analyses
│       ├── competitor-1.md
│       └── ...
│
│   IMPLEMENTATION PLANNING (/speckit.plan):
│
├── plan.md              # Implementation plan
├── research.md          # Technical research
├── data-model.md        # Database schema
├── quickstart.md        # Dev setup guide
├── contracts/           # API contracts (OpenAPI)
│
│   ATOMIC TRACEABILITY STRUCTURE (/speckit.tasks):
│
├── index.md             # Feature dashboard - THE entry point
├── traceability.md      # Requirement-to-task mapping matrix
└── tasks/               # Atomic task directory (NOT tasks.md!)
    ├── T-001-setup-project.md
    ├── T-010-create-user-model.md
    ├── T-020-implement-endpoint.md
    ├── T-021-add-validation.md
    └── ...
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
| `/speckit.specify` | Create feature specification with Knowledge Station gates |
| `/speckit.AnalyzeCompetitors` | **Optional** - Analyze competitors following Station 03 discovery procedures |
| `/speckit.plan` | Create implementation plan with architecture gates |
| `/speckit.tasks` | Generate atomic task files (index.md, traceability.md, tasks/) |
| `/speckit.implement` | Execute tasks with Context Pinning |
| `/speckit.cleanup` | Detect and remove orphaned code, unused components, dead routes |

### Supporting Commands

| Command | Description |
|---------|-------------|
| `/speckit.constitution` | View/update project constitution |
| `/speckit.clarify` | Clarify underspecified requirements |
| `/speckit.analyze` | Cross-artifact consistency analysis |
| `/speckit.checklist` | Generate quality validation checklists |
| `/speckit.taskstoissues` | Convert tasks to GitHub issues |

### Cleanup Command Details

The `/speckit.cleanup` command helps maintain a clean codebase by detecting:

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

Custom Speckit - Exact Assembly Line implements a two-tier governance hierarchy:

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

## Get Started (Original Method)

### 1. Install Specify CLI

Choose your preferred installation method:

#### Option 1: Persistent Installation (Recommended)

Install once and use everywhere:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

Then use the tool directly:

```bash
# Create new project
specify init <PROJECT_NAME>

# Or initialize in existing project
specify init . --ai claude
# or
specify init --here --ai claude

# Check installed tools
specify check
```

To upgrade Specify, see the [Upgrade Guide](./docs/upgrade.md) for detailed instructions. Quick upgrade:

```bash
uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git
```

#### Option 2: One-time Usage

Run directly without installing:

```bash
uvx --from git+https://github.com/github/spec-kit.git specify init <PROJECT_NAME>
```

**Benefits of persistent installation:**

- Tool stays installed and available in PATH
- No need to create shell aliases
- Better tool management with `uv tool list`, `uv tool upgrade`, `uv tool uninstall`
- Cleaner shell configuration

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
| `SPECIFY_FEATURE` | Override feature detection for non-Git repositories. Set to the feature directory name (e.g., `001-photo-albums`) to work on a specific feature when not using Git branches.<br/>**Must be set in the context of the agent you're working with prior to using `/speckit.plan` or follow-up commands.** |

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

If `/speckit.*` commands don't appear:
1. Ensure `.claude/commands/` directory exists in your project
2. Verify command files are named `speckit.*.md` (e.g., `speckit.specify.md`)
3. Restart Claude Code after adding commands

---

## License

This project is licensed under the terms of the MIT open source license. Please refer to the [LICENSE](./LICENSE) file for the full terms.

---

## Credits

- **Original Spec Kit**: [GitHub](https://github.com/github/spec-kit) by Den Delimarsky and John Lam
- **Atomic Traceability Model**: Based on the "Andre/Mable AI workflow" methodology
