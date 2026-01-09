# Subagent Registry

This folder contains specialized subagent prompts for domain-specific tasks. Subagents are curated, distilled versions of Knowledge Station content (~50-100 lines) that provide focused expertise without context pollution.

## How Subagents Work

1. During `/speckit.plan` Initial Configuration, user is asked if they want subagents
2. If enabled, this registry is checked for available agents
3. Commands load relevant subagent prompts as context for specific tasks
4. Each subagent knows its domain deeply without needing the full station

## Available Subagents

| Agent | File | Domain | Use When |
|-------|------|--------|----------|
| API Contracts | `api-contracts.md` | API design, OpenAPI, error handling | Phase 1 of /speckit.plan (API involved) |
| Data Architecture | `data-architecture.md` | Database, tenancy, migrations | Phase 1 of /speckit.plan (DB involved) |
| Auth & RBAC | `auth-rbac.md` | Authentication, permissions | Phase 1 of /speckit.plan (auth involved) |

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
