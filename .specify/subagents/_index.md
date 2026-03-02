# Subagent Registry

This folder contains specialized subagent prompts for domain-specific tasks. Subagents are curated, distilled versions of Knowledge Station content (~50-100 lines) that provide focused expertise without context pollution.

## How Subagents Work

1. During `/speckit.plan` Initial Configuration, user is asked if they want subagents
2. If enabled, this registry is checked for available agents
3. **Platform filtering**: Agents are filtered by platform FIRST, then matched by keywords
4. Commands load relevant subagent prompts as context for specific tasks
5. Each subagent knows its domain deeply without needing the full station

## Platform Matching

Agents can specify which platforms they support. Matching algorithm:

1. **Filter by platform**: Only agents matching the spec's platform are candidates
2. **Match by keywords**: Keyword similarity on filtered candidates
3. **Universal agents**: Agents without `platform:` field match any platform

### Platform Values

| Value | Scope | Examples |
|-------|-------|----------|
| `web` | Browser-based frontend | React (web), Vue, Angular, Next.js SSR |
| `mobile` | Mobile apps | React Native, Flutter, Swift, Kotlin |
| `desktop` | Desktop apps | Electron, Tauri, WPF, macOS native |
| `backend` | Server-side | Node.js APIs, Python services, databases |
| `cli` | Command-line tools | Shell scripts, CLI apps |
| `infra` | Infrastructure | Docker, K8s, CI/CD, Terraform |

## Available Subagents

| Agent | File | Platform | Domain | Use When |
|-------|------|----------|--------|----------|
| API Contracts | `api-contracts.md` | backend | API design, OpenAPI, error handling | Phase 1 of /speckit.plan (API involved) |
| Data Architecture | `data-architecture.md` | backend | Database, tenancy, migrations | Phase 1 of /speckit.plan (DB involved) |
| Auth & RBAC | `auth-rbac.md` | backend | Authentication, permissions | Phase 1 of /speckit.plan (auth involved) |
| Frontend Developer | `frontend-developer.md` | web | React (web), CSS, Tailwind | Web UI components |
| Mobile Developer | `mobile-developer.md` | mobile | React Native, Flutter | Mobile app development |
| Backend Architect | `backend-architect.md` | backend | APIs, microservices | Backend services |
| TypeScript Pro | `typescript-pro.md` | universal | Advanced TypeScript | TypeScript architecture |
| Payment Integration | `payment-integration.md` | backend | Stripe, billing | Payment features |
| Deployment Engineer | `deployment-engineer.md` | infra | CI/CD, Docker, K8s | Deployments |

## Custom Subagents

Project-specific subagents go in `.specify/subagents/custom/`:

| Agent | File | Domain | Use When |
|-------|------|--------|----------|
| (none yet) | | | |

To add a custom subagent:
1. Create a file in `custom/` following `_template.md`
2. Add an entry to this table
3. The agent will be discovered automatically

## Subagent File Format

Each subagent file should contain:

```markdown
# [Agent Name] Subagent

**Domain**: [What this agent specializes in]
**Source Stations**: [Which stations this distills]
**Use When**: [Trigger conditions]

## Core Knowledge

[Distilled essential content - 50-100 lines max]
[Focus on decisions, patterns, and gate criteria]
[Remove procedural steps that aren't needed at runtime]

## Gate Criteria

[What must be satisfied before moving on]

## Output Format

[What this agent should produce]
```

## Usage by Commands

Commands that use subagents:

### /speckit.plan

```markdown
If subagents enabled AND api involved:
  Load .specify/subagents/api-contracts.md
  Use for Phase 1 API design

If subagents enabled AND database involved:
  Load .specify/subagents/data-architecture.md
  Use for Phase 1 data model design
```

### /speckit.tasks

```markdown
If subagents enabled:
  Reference coding standards from plan.md
  Apply conventions to task file generation
```

### /speckit.implement

```markdown
If subagents enabled AND task involves [domain]:
  Load relevant subagent for context
  Apply domain-specific patterns
```

## Feature-Specific Subagents

For feature-specific agents, create them in the feature folder:

```
specs/[feature]/subagents/
├── payment-flow.md      # Only for this feature
└── custom-integration.md
```

These take priority over project-wide subagents when there's overlap.
