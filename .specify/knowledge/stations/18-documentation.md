# Station 18 — Documentation System

> PRDs, ADRs, Playbooks, and Templates

## 18.1 Objective

Create a documentation system that:

- Scales across products and teams (repeatable, searchable)
- Prevents "tribal knowledge" and onboarding chaos
- Captures decisions (ADR) so you don't re-litigate architecture
- Standardizes delivery (PRD -> execution -> release)
- Supports operations (runbooks, support playbooks, security policies)

> **Rule:** Docs are not essays. They are operational artifacts.

## 18.2 Doc Types (What You Need, and Why)

### 18.2.1 PRD (Product Requirements Document)

**Purpose:** Define what and why (business + UX + constraints), not implementation details.

**Must Include:**

| Section | Description |
|---------|-------------|
| Problem statement | What problem are we solving |
| Target users + JTBD | Who and what job |
| Success metrics | Activation, retention, conversion |
| Scope (in/out) | What's included and excluded |
| User flows + key screens | Core UX |
| Non-functional requirements | Security, performance, compliance |
| Analytics events to instrument | Part 16 |
| Rollout plan + risks | Deployment strategy |

### 18.2.2 TRD / Tech Spec (Technical Requirements Document)

**Purpose:** Define how (architecture, components, data model, edge cases).

**Must Include:**

| Section | Description |
|---------|-------------|
| System overview | High-level architecture |
| APIs/contracts | OpenAPI |
| Data model + migrations | Schema changes |
| Auth/RBAC impacts | Permission changes |
| Limits/metering impacts | Usage considerations |
| Operational considerations | Observability, runbooks |
| Failure modes + retries | Error handling |
| Test plan | Testing strategy |

### 18.2.3 ADR (Architecture Decision Record)

**Purpose:** Capture a decision and its rationale.

**Must Include:**

| Section | Description |
|---------|-------------|
| Context | Why we're making this decision |
| Options considered | Alternatives evaluated |
| Decision | What we chose |
| Consequences | Tradeoffs, risks |
| Follow-ups | Next steps |

> **Rule:** ADRs are short and permanent.

### 18.2.4 Runbooks (Ops)

**Purpose:** How to respond to incidents.

**Must Include:**

| Section | Description |
|---------|-------------|
| Symptoms | How to identify the issue |
| Dashboards/log queries | Where to look |
| Mitigations | Actions to take |
| Verification steps | Confirm resolution |
| Escalation path | Who to contact |
| Postmortem checklist | Follow-up items |

### 18.2.5 Support Playbooks

**Purpose:** Resolve common customer issues fast (Part 17).

**Must Include:**

| Section | Description |
|---------|-------------|
| Symptom -> diagnosis steps | Investigation flow |
| Safe actions | What support can do |
| Escalation triggers | When to escalate |
| Templates for customer communication | Response templates |

### 18.2.6 Policies (Security, Retention, Release)

**Purpose:** Define "rules of the system" (Part 12-14).

**Examples:**

- Security baseline
- Data retention and deletion
- Release checklist
- Secrets management

## 18.3 Organization (Repo Structure)

A practical structure:

```
/docs/
├── product/           # PRDs, user flows, research, competitor notes
├── tech/              # TRDs, API schemas, data model docs
├── adr/               # ADR-0001-*.md
├── ops/               # Runbooks, on-call notes, dashboards
├── support/           # Support playbooks, macros
└── policies/          # Security, retention, release
```

> **Rule:** One place. No scattered Google Docs + Notion + random PDFs unless you have strict linking.

## 18.4 Standard Templates (Make Delivery Consistent)

### 18.4.1 PRD Template (MVP-Ready)

**Sections:**

1. Summary
2. Problem and user
3. Goals + success metrics
4. Non-goals
5. User flows
6. Requirements (functional)
7. NFRs (security, performance, privacy)
8. Analytics events
9. Rollout + migration plan
10. Risks + mitigations
11. Open questions

### 18.4.2 Tech Spec Template

**Sections:**

1. Architecture overview
2. Component responsibilities
3. Data model + migrations
4. API contracts
5. AuthZ impacts
6. Metering/limits impacts
7. Failure modes + retries
8. Observability plan
9. Test plan
10. Rollout + rollback plan

### 18.4.3 ADR Template

```markdown
# ADR-NNNN: Title

## Context

[Why we're making this decision]

## Decision Drivers

[Key factors influencing the decision]

## Options

### Option 1: [Name]
- Pros:
- Cons:

### Option 2: [Name]
- Pros:
- Cons:

## Decision

[What we chose and why]

## Consequences

[Tradeoffs, risks, what this enables/prevents]

## References

[Links to related docs, issues, discussions]
```

## 18.5 Workflow (How Docs Integrate into Your "Assembly Line")

### 18.5.1 Required Gates for New Features

| Gate | Requirement |
|------|-------------|
| PRD approved | Must be complete |
| Tech spec approved | For non-trivial features |
| ADR created | For major decisions |
| Implementation plan + milestones | Defined |
| Tests + observability included | Must be part of delivery |
| Release checklist completed | Before go-live |

> **Rule:** The "definition of ready" includes docs.

### 18.5.2 Linking Rules

**Every PR links to:**

- PRD
- Tech spec (if exists)
- ADRs (if applicable)

**Every runbook links to:**

- Dashboards
- Relevant error codes
- Relevant components

## 18.6 Maintenance Discipline (Docs Rot Prevention)

- Update docs as part of feature PRs
- Include doc changes in the same PR
- Periodic doc review (monthly/quarterly)
- Mark obsolete docs explicitly

> **Rule:** "Docs are outdated" is a process bug.

## 18.7 Deliverables

- `PRD_Template.md`
- `Tech_Spec_Template.md`
- `ADR_Template.md`
- `Runbook_Template.md`
- `Docs_Repo_Structure.md`
- `Docs_Workflow_Gates.md`
