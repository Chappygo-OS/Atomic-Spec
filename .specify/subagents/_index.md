# Subagent Registry

This folder contains specialized subagent prompts for domain-specific tasks. Subagents are curated, distilled versions of Knowledge Station content that provide focused expertise.

## Folder Structure

```
.specify/subagents/
├── _index.md           # This file
├── _template.md        # Template for new subagents
├── mobile/             # 146+ mobile development subagents
│   ├── 01-discovery/   # Discovery & Strategy (8)
│   ├── 02-requirements/# Requirements & Planning (8)
│   ├── 03-ux-ui/       # UX/UI Design (11)
│   ├── 04-architecture/# Architecture & Technical Design (12)
│   ├── 05-backend/     # Backend Development (12)
│   ├── 06-frontend-mobile/ # Frontend / Mobile Development (18)
│   ├── 07-security/    # Security (12)
│   ├── 08-testing/     # Testing (14)
│   ├── 09-devops/      # DevOps & CI/CD (11)
│   ├── 10-analytics/   # Analytics & Monitoring (9)
│   ├── 11-app-store/   # App Store Preparation & Launch (11)
│   ├── 12-maintenance/ # Post-Launch & Maintenance (14)
│   ├── 13-legal/       # Legal & Compliance (9)
│   └── 14-documentation/ # Documentation (7)
├── backend/            # Backend development
├── frontend/           # Frontend/web development
├── data/               # Data & database specialists
├── devops/             # DevOps & infrastructure
├── ai/                 # AI/ML specialists
├── review/             # Code & architecture reviewers
├── languages/          # Language-specific experts
├── business/           # Business analysis
└── custom/             # Project-specific subagents
```

## Platform Matching

Agents can specify which platforms they support:

| Value | Scope | Examples |
|-------|-------|----------|
| `web` | Browser-based frontend | React, Vue, Angular, Next.js |
| `mobile` | Mobile apps | iOS, Android, React Native, Flutter |
| `desktop` | Desktop apps | Electron, Tauri, WPF |
| `backend` | Server-side | Node.js, Python, Go |
| `cli` | Command-line tools | Shell scripts, CLI apps |
| `infra` | Infrastructure | Docker, K8s, Terraform |

## Available Subagents

### Mobile Development (146 subagents)

Complete mobile app development lifecycle coverage:

| Category | Location | Count | Covers |
|----------|----------|-------|--------|
| Discovery | `mobile/01-discovery/` | 8 | Market research, business model, MVP scoping |
| Requirements | `mobile/02-requirements/` | 8 | Functional specs, tech stack, risk assessment |
| UX/UI | `mobile/03-ux-ui/` | 11 | Wireframes, design systems, accessibility |
| Architecture | `mobile/04-architecture/` | 12 | System design, APIs, offline-first |
| Backend | `mobile/05-backend/` | 12 | Server setup, auth, background jobs |
| Frontend | `mobile/06-frontend-mobile/` | 18 | Navigation, state, IAP, deep linking |
| Security | `mobile/07-security/` | 12 | Encryption, biometrics, OWASP |
| Testing | `mobile/08-testing/` | 14 | Unit, E2E, beta testing, device matrix |
| DevOps | `mobile/09-devops/` | 11 | CI/CD, code signing, feature flags |
| Analytics | `mobile/10-analytics/` | 9 | Crash reporting, APM, user analytics |
| App Store | `mobile/11-app-store/` | 11 | ASO, screenshots, submission process |
| Maintenance | `mobile/12-maintenance/` | 14 | Bug triage, updates, A/B testing |
| Legal | `mobile/13-legal/` | 9 | GDPR, COPPA, open source licenses |
| Documentation | `mobile/14-documentation/` | 7 | API docs, runbooks, help center |

### Backend Development

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Backend Architect | `backend/backend-architect.md` | backend | API design, microservices |
| API Documenter | `backend/api-documenter.md` | backend | OpenAPI, SDK generation |
| Payment Integration | `backend/payment-integration.md` | backend | Stripe, billing |

### Frontend Development

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Frontend Developer | `frontend/frontend-developer.md` | web | React, CSS, Tailwind |
| UI/UX Designer | `frontend/ui-ux-designer.md` | web | Interface design |

### Data & Database

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Data Engineer | `data/data-engineer.md` | backend | ETL, pipelines |
| Data Scientist | `data/data-scientist.md` | backend | Analytics, SQL |
| Database Admin | `data/database-admin.md` | backend | Operations, backups |
| Database Optimizer | `data/database-optimizer.md` | backend | Query optimization |
| SQL Pro | `data/sql-pro.md` | backend | Complex queries |
| Data Architecture | `data/data-architecture.md` | backend | Schema design |

### DevOps & Infrastructure

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Deployment Engineer | `devops/deployment-engineer.md` | infra | CI/CD, Docker |
| Performance Engineer | `devops/performance-engineer.md` | infra | Optimization |

### AI & Machine Learning

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| AI Engineer | `ai/ai-engineer.md` | universal | LLM applications |
| ML Engineer | `ai/ml-engineer.md` | universal | Model deployment |
| Prompt Engineer | `ai/prompt-engineer.md` | universal | Prompt optimization |

### Code Review

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Architect Reviewer | `review/architect-reviewer.md` | universal | Architecture review |
| Code Reviewer | `review/code-reviewer.md` | universal | Code quality |
| Error Detective | `review/error-detective.md` | universal | Debugging |

### Language Specialists

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Python Pro | `languages/python-pro.md` | universal | Advanced Python |
| TypeScript Pro | `languages/typescript-pro.md` | universal | Advanced TypeScript |

### Business

| Agent | File | Platform | Use When |
|-------|------|----------|----------|
| Business Analyst | `business/business-analyst.md` | universal | Metrics, KPIs |

## Custom Subagents

Project-specific subagents go in `custom/`:

```markdown
To add a custom subagent:
1. Create a file in `custom/` following `_template.md`
2. The agent will be discovered automatically by platform and keywords
```

## Subagent File Format

```yaml
---
name: agent-name
platform: mobile|web|backend|infra|universal
description: What this agent specializes in
model: opus|sonnet|haiku
category: category/subcategory
---

# Agent Name

## Core Competencies
[What this agent knows]

## Key Concepts
[Domain knowledge with examples]

## Deliverables
[What this agent produces]

## Gate Criteria
[Quality checklist]
```

## Usage by Commands

### /speckit.plan
- Loads relevant subagents based on platform and features
- Uses for domain-specific design decisions

### /speckit.tasks
- Applies subagent knowledge to task generation
- Embeds relevant context in task files

### /speckit.implement
- Loads subagent matching task domain
- Applies domain-specific patterns
