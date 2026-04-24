---
description: Discover, create, or update the Project Defaults Registry. Scans project manifests (package.json, pyproject.toml, Cargo.toml, go.mod, etc.), batches findings for HITL confirmation, then writes specs/_defaults/registry.yaml with a full audit trail in changelog.md.
handoffs:
  - label: Create Feature Plan
    agent: atomicspec.plan
    prompt: With the registry now populated, create a plan for...
  - label: Author Constitution
    agent: atomicspec.constitution
    prompt: Now that defaults are captured, finalize the project constitution.
---

## User Input

```text
$ARGUMENTS
```

Honor the user input. Common patterns:

- `init` (default when empty) — create or populate from scratch
- `update` — re-scan and surface new decisions against the existing registry
- `audit` — read-only report of registry coverage vs. detected project signals

## Outline

You are managing `specs/_defaults/registry.yaml` — the Project Defaults Registry defined by Constitution Article IX, Directive 7. This file is the single source of truth for project-wide technical decisions. Every command that generates code reads it on entry; every phase that makes new decisions writes to it on exit (with HITL approval).

**Core guarantee**: decisions are captured once, surface everywhere, never hallucinated on the fly.

This command covers the "On Entry — file does not exist yet" case and the "periodic update" case. The plan and implement phases handle in-flight updates via their own Phase 0.9 / Phase 9 sync checkpoints.

Follow this execution flow. Do NOT skip phases.

## Phase 1 — Pre-flight State Detection

Classify `specs/_defaults/registry.yaml` into one of three states. This determines the rest of the flow.

Run:

```bash
{SCRIPT}
```

(uses `scripts/bash/check-prerequisites.sh --paths-only --json` to locate `REPO_ROOT`)

Then inspect `$REPO_ROOT/specs/_defaults/registry.yaml`:

| State | Definition | Next step |
|-------|-----------|-----------|
| **MISSING** | File does not exist | Proceed to Phase 2. Warn the user: "I will discover defaults from your project manifests, confirm with you, and create the registry." |
| **EMPTY** | File exists, every leaf value is `null` / `[]` / `~` | Proceed to Phase 2. Same user message. |
| **POPULATED** | At least one leaf has a real value | If user input was `init`, warn that the registry already has content and ask: [Re-discover + update] [Audit only] [Cancel]. If user input was `update` or `audit`, proceed accordingly. |

For the POPULATED path with "audit only", skip Phases 2–5 and go straight to Phase 6 (audit report), then stop without writing.

## Phase 2 — Static Discovery

Scan the repository for manifest files. For each one found, derive registry field values. Record findings with their source (which file revealed them) so you can show provenance to the user.

**Manifest → field mapping** (apply the ones that match; skip the rest):

### Node / JavaScript / TypeScript

Read `package.json` (and `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` for package manager detection):

- `dependencies` containing `react`, `vue`, `@angular/core`, `svelte`, `next`, `nuxt`, `remix` → `frontend.framework`
- `dependencies` containing `express`, `fastify`, `hono`, `@nestjs/core`, `koa` → `backend.framework` + `backend.language=javascript` (or `typescript` if `tsconfig.json` exists)
- `dependencies` containing `@tanstack/react-query`, `swr`, `@apollo/client` → `frontend.data_fetching`
- `dependencies` containing `react-hook-form`, `formik` → `frontend.form_library`
- `dependencies` containing `zod`, `yup`, `joi`, `valibot` → `frontend.validation_library` / `code_patterns.validation_approach=schema`
- `dependencies` containing `zustand`, `redux`, `@reduxjs/toolkit`, `jotai`, `pinia` → `frontend.state_management`
- `dependencies` containing `react-router`, `@tanstack/router`, `vue-router` → `frontend.routing`
- `dependencies` containing `prisma`, `drizzle-orm`, `typeorm`, `sequelize`, `@mikro-orm/core` → `backend.orm`
- `dependencies` containing `jsonwebtoken`, `passport`, `next-auth` → `backend.auth_method` (infer from type: jwt/session/oauth2)
- `devDependencies` containing `jest`, `vitest`, `mocha`, `ava` → `testing.unit_framework`
- `devDependencies` containing `@playwright/test`, `cypress` → `testing.e2e_framework`
- `scripts.build` mentioning `next`, `vite`, `webpack` → infer `frontend.rendering` (`next` → `ssr`/`ssg` hybrid, `vite` SPA → `spa`)

Read `tsconfig.json`:

- `compilerOptions.strict: true` or `strictNullChecks: true` → `code_patterns.null_handling=strict_null`

### Python

Read `pyproject.toml` (or `requirements.txt`, `Pipfile`, `poetry.lock`):

- Presence of file → `backend.language=python`
- `[tool.poetry.dependencies]` / `[project.dependencies]` containing `fastapi`, `flask`, `django`, `starlette`, `litestar` → `backend.framework`
- Containing `sqlalchemy`, `sqlmodel`, `tortoise-orm`, `peewee`, `django` → `backend.orm`
- Containing `celery`, `rq`, `dramatiq` → `backend.job_queue`
- Containing `redis` client → `backend.cache=redis`
- Containing `pytest`, `unittest` → `testing.unit_framework`
- Containing `httpx`, `requests-mock` → `testing.integration_framework`
- `requires-python = ">=3.11"` → `backend.runtime_version=python:3.11` (or whatever the floor is)

### Rust

Read `Cargo.toml`:

- Presence → `backend.language=rust`
- `[dependencies]` containing `actix-web`, `axum`, `rocket`, `warp`, `tide` → `backend.framework`
- Containing `diesel`, `sqlx`, `sea-orm` → `backend.orm`
- Containing `tokio`, `async-std` → infer async pattern
- `rust-version = "..."` → `backend.runtime_version=rust:X.Y`

### Go

Read `go.mod`:

- Presence → `backend.language=go`
- Imports `github.com/gin-gonic/gin`, `github.com/labstack/echo`, `github.com/gofiber/fiber` → `backend.framework`; only map `net/http` → `backend.framework=stdlib-net-http` when none of the above third-party framework imports are present
- Imports `gorm.io/gorm`, `github.com/jmoiron/sqlx`, `entgo.io/ent` → `backend.orm`
- `go X.Y` directive → `backend.runtime_version=go:X.Y`

### Java / Kotlin

Read `pom.xml`, `build.gradle`, `build.gradle.kts`:

- Presence → `backend.language=java` or `kotlin`
- `org.springframework.boot` → `backend.framework=spring-boot`
- `io.quarkus` → `backend.framework=quarkus`
- `io.micronaut` → `backend.framework=micronaut`
- `org.hibernate` / `spring-data-jpa` → `backend.orm`

### Ruby

Read `Gemfile`:

- Presence → `backend.language=ruby`
- `gem 'rails'` → `backend.framework=rails`
- `gem 'sinatra'` → `backend.framework=sinatra`
- `gem 'sidekiq'` → `backend.job_queue=sidekiq`

### Infrastructure

Read `docker-compose.yml`, `Dockerfile`, `.github/workflows/*.yml`, `.gitlab-ci.yml`:

- `docker-compose.yml` service with `image: postgres*` → `database.type=postgresql`
- `image: mysql*` → `database.type=mysql`
- `image: mongo*` → `database.type=mongodb`
- `image: redis*` → `backend.cache=redis`
- `Dockerfile` existence → `infrastructure.container=docker`
- `.github/workflows/` → `infrastructure.ci_cd=github-actions`
- `.gitlab-ci.yml` → `infrastructure.ci_cd=gitlab-ci`
- `.circleci/` → `infrastructure.ci_cd=circleci`
- `.devcontainer/` → confirms container choice

### ORM / Database schema

Read `prisma/schema.prisma`:

- Presence → `backend.orm=prisma`
- `datasource db { provider = "postgresql" }` → `database.type=postgresql`
- `datasource db { provider = "sqlite" }` → `database.type=sqlite`

Read `drizzle.config.ts`:

- Presence → `backend.orm=drizzle`

### Mobile

Read `ios/` directory + `*.xcodeproj` → `target_platform.mobile_platforms` includes `ios`.
Read `android/` directory + `build.gradle` → `target_platform.mobile_platforms` includes `android`.
Read `pubspec.yaml` → `target_platform.mobile_framework=flutter`.
Read `app.json` + `expo` entry → `target_platform.mobile_framework=react-native` + `react_native.dev_approach=expo_managed`.

**Discovery rules:**

1. **Every field that a manifest can reveal, reveal it.** Don't guess beyond what the manifest proves.
2. **Mark each finding with provenance** — which file, which dependency/line produced it.
3. **If two manifests conflict** (e.g., both `fastify` and `express` in package.json), record both and ask the user which is primary.
4. **Do not infer fields that manifests cannot reveal** (e.g., tenancy model, architecture pattern, API versioning strategy). Those are handled in Phase 4 (interview).
5. **Redact credentials**: if a connection URL or environment reference contains a password or token (e.g., `postgres://user:PASSWORD@host/db`), record only the driver and host; never surface credentials in the discovery table or changelog.

## Phase 3 — Present Discovered Findings for Confirmation (HITL)

Present findings in a single table. Do NOT ask the user field-by-field — batch the confirmation.

**Format**:

```
Discovered project defaults from manifest scan:

┌─────────────────────────────┬─────────────────┬─────────────────────────────┐
│ Registry Field              │ Proposed Value  │ Source                      │
├─────────────────────────────┼─────────────────┼─────────────────────────────┤
│ backend.language            │ typescript      │ package.json + tsconfig.json│
│ backend.framework           │ express         │ package.json                │
│ backend.orm                 │ prisma          │ prisma/schema.prisma        │
│ database.type               │ postgresql      │ prisma/schema.prisma        │
│ frontend.framework          │ next            │ package.json                │
│ testing.unit_framework      │ vitest          │ package.json (devDeps)      │
│ testing.e2e_framework       │ playwright      │ package.json (devDeps)      │
│ infrastructure.ci_cd        │ github-actions  │ .github/workflows/          │
│ code_patterns.null_handling │ strict_null     │ tsconfig.json strict:true   │
└─────────────────────────────┴─────────────────┴─────────────────────────────┘

Conflicts detected: none
Fields with ambiguous signals: none
```

Then use `AskUserQuestion` with **exactly these four choices**:

- **Accept all** — write all findings as shown
- **Revise specific rows** — user lists row numbers to change; we ask each of those one-by-one, then accept the rest
- **Add additional fields** — user wants to fill in a field we didn't discover (jumps into Phase 4 early)
- **Discard all discoveries / interview only** — ignore all manifest findings and proceed directly to Phase 4 to fill fields manually
- **Cancel** — abort; do not write any file

If the user picks **Revise**, for each row they name, use `AskUserQuestion` with the canonical allowed values from `templates/registry-template.yaml` comments (e.g., for `backend.framework` offer the list you know). Allow `custom: <value>` as an option.

If the user picks **Accept all**, lock in the discovered values and proceed to Phase 4.

## Phase 4 — Interview for Non-Discoverable Fields

Some decisions cannot be derived from manifests. Ask about these now, but **scope aggressively** — only ask for the categories that the detected platform needs.

**Categories with ask-rules:**

| Category | Ask only if | Fields |
|----------|-------------|--------|
| Architecture | Always (backend OR frontend detected) | `architecture.pattern`, `architecture.layers`, `architecture.api_style`, `architecture.communication` |
| API conventions | Backend detected | `api.versioning`, `api.pagination`, `api.error_format`, `api.idempotency`, `api.resource_naming`, `api.auth_header`, `api.response_envelope` |
| Code patterns | Always | `code_patterns.data_access`, `code_patterns.dependency_injection`, `code_patterns.error_handling`, `code_patterns.validation_approach` |
| Database | Database detected | `database.tenancy_model`, `database.soft_delete`, `database.audit_columns`, `database.migration_strategy`, `database.naming_tables`, `database.primary_key_type` |
| Security | Backend detected | `security.cors`, `security.csrf`, `security.rate_limit_scope`, `security.password_policy` |
| Error/logging | Always | `error_handling.logging_format`, `error_handling.log_level`, `error_handling.error_tracking`, `error_handling.tracing` |
| Conventions | Always | `conventions.variables`, `conventions.files`, `conventions.classes`, `conventions.commits`, `conventions.branches` |
| Mobile platforms | Mobile framework detected | All `ios.*` / `android.*` / `react_native.*` / `flutter.*` / `mobile.*` relevant to the detected framework |
| Frontend (web) | `target_platform.primary=web` AND no frontend framework discovered | `frontend.framework`, `frontend.ui_library`, `frontend.styling`, etc. |

**Interview pattern**: batch questions by category. Present each category as a single `AskUserQuestion` with multiple choices. Allow "skip this category — leave as null for now" as an option per category. Do NOT force an answer on every field — null is a valid state; the user can fill it later via `/atomicspec.plan` Phase 0.9 or another `/atomicspec.registry update`.

For each category, after the user answers, show them the collected values before moving to the next category.

## Phase 5 — Atomic Write

Once Phase 3 + Phase 4 are complete, produce the final value map. Write it in three steps with atomic semantics:

1. **Read the current file** (if POPULATED) into memory so we can do a surgical merge. Do NOT blow away fields the user didn't touch.
2. **Merge** — apply Phase 3 + Phase 4 confirmed values; leave untouched fields as-is.
3. **Atomic write**:
   - Write the complete updated YAML to `specs/_defaults/registry.yaml.tmp`
   - Verify the temp file parses as valid YAML (the AI should mentally re-read it; if any YAML syntax concerns, reject and report)
   - Write `registry.yaml` from the same content as the temp file, then delete `registry.yaml.tmp` (AI agents may not have a rename tool; explicit write + delete achieves the same atomicity guarantee)
4. **Update metadata**: only if at least one substantive decision field was written (i.e., the user did not cancel and the merge produced actual changes), set `last_updated: YYYY-MM-DD`, `last_updated_by: human`, `applied_to: <current-project-slug>`, and if `created:` is null, set it to today. Do NOT update metadata on a cancel or a zero-change run — doing so causes the classifier to report POPULATED when no project decision has been captured.

**Changelog audit entry**: append one entry to `specs/_defaults/changelog.md` for each field changed in this session:

```markdown
## [YYYY-MM-DD] — Registry sync via /atomicspec.registry

- **Changed**: `backend.framework`: null → `express`
  - **Why**: Discovered in package.json (dependencies.express@^4.18.0)
  - **Source**: /atomicspec.registry Phase 2 discovery
  - **Approved by**: Human (Accept all, Phase 3)
- **Changed**: `database.tenancy_model`: null → `shared_db_tenant_id`
  - **Why**: Not discoverable from manifests; user stated multi-tenant SaaS
  - **Source**: /atomicspec.registry Phase 4 interview
  - **Approved by**: Human (explicit answer, Phase 4)
```

**Sanitization**: before embedding any user-supplied value in changelog entries, strip embedded newlines (`\n`, `\r`) to prevent Markdown injection. Truncate values exceeding 200 characters with `…`.

If `specs/_defaults/README.md` does not yet exist, create it from `templates/registry-readme-template.md`.

## Phase 6 — Audit Report (for `audit` subcommand, read-only)

Print a summary:

```
Registry audit — specs/_defaults/registry.yaml
===================================================

Filled: 23 / 87 fields (26%)

High-impact fields with null values:
  - architecture.pattern          (drives every command)
  - database.tenancy_model         (drives task generation)
  - backend.auth_method            (drives security tasks)

Platform-specific fields:
  - target_platform.primary = web  (mobile sections irrelevant — skipping)

Detected but not captured:
  - testing.unit_framework: vitest (in package.json, not in registry)
  - infrastructure.ci_cd: github-actions (in .github/workflows/, not in registry)

Recommendation: run /atomicspec.registry update to close these gaps.
```

Do not write any file in audit mode.

## Constitutional Compliance

This command implements Constitution Article IX, Directive 7 "Protocol — On Entry" and provides the discovery layer that the protocol assumes exists. It is exempt from reading the registry on entry for obvious reasons (it's the one authoring it).

This command MUST:

- Use `AskUserQuestion` for every decision point (Directive 6: Human-In-The-Loop)
- Produce an audit-trail entry for every field changed (Directive 7: Project Defaults Registry)
- Never write fields the user did not explicitly confirm
- Leave the file unchanged on cancel (atomic-write discipline)

## Completion

Report to the user:

- Number of fields discovered from manifests
- Number of fields confirmed by user
- Number of fields left null (to be filled later)
- Path to the updated registry and changelog
- Suggested next command (typically `/atomicspec.plan` or `/atomicspec.constitution`)
