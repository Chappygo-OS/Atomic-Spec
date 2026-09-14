# Testing Derivation (v0.5+)

Atomic Spec asks one yes/no question up front — *"Do you want automated tests for this feature?"* — and, if yes, derives the full test strategy from your tech stack at planning time. Test tasks then land alongside feature tasks, not bolted on later.

This document covers how it works, how to opt in and opt out, and where the derivation currently has coverage gaps.

---

## Why this exists

Before v0.5, `/clarify` and `/plan` never asked about testing. The `testing.*` block in `registry.yaml` existed with 6 empty fields, but nothing pulled them into the conversation for web / mobile / desktop apps. The result: coverage became accidental, testing tools got chosen mid-implementation, and regressions shipped. Tracked as G-002 in `docs/internal/known-gaps.md`.

v0.5 closes the gap with a two-moment flow:

- **Moment A — consent at `/clarify`**: one question, app-specific rationale, `Y/N` answer.
- **Moment B — derivation at `/plan` Phase 0.85**: framework reads the tech stack, matches testing subagents, emits a Test Strategy table for row-by-row HITL approval.

Consent is a hard gate: zero derivation tokens are spent without an explicit yes on file.

---

## Moment A — the consent question

At `/atomicspec.clarify`, the framework asks (rationale interpolated per app type):

```
Do you want automated tests for this feature? [Y / N]

Recommended: Y.
Rationale: You're building a web app with a FastAPI backend — tests catch
API contract drift before it hits production and cut debug time when
logic changes.
```

The rationale template swaps in per-app-type language:

| App type | Rationale wording |
|---|---|
| Web + backend | *tests catch API contract drift before it hits production* |
| React Native + mobile backend | *tests catch platform-specific regressions between iOS and Android builds* |
| Tauri / Electron desktop | *tests protect the Rust IPC surface where UI bugs become native crashes* |
| TypeScript library | *tests are your contract with downstream consumers; skipping ships breakage to their CI* |
| Native iOS | *tests catch view-model regressions before TestFlight rejects the build* |

Answering **Yes** writes `testing.enabled: true` to `registry.yaml` with `_provenance.testing.enabled: human`. Answering **No** writes `testing.enabled: false` with the same provenance. Either way, the framework never re-asks — the value persists across every subsequent `/atomicspec.*` run.

**If your spec mentions "spike", "prototype", "throwaway", "POC", "hackathon", or "scratch"** and `lifecycle.intent` is not `production`, the framework asks a follow-up first: *"This spec mentions 'spike' — skip testing setup? [Y/N]"*. It never silently omits the question. Setting `lifecycle.intent: production` in the registry bypasses this suppression check unconditionally — a payment feature with "spike" in the name still gets its testing prompt.

---

## Moment B — derivation at Phase 0.85

If consent was given (`testing.enabled: true`), `/atomicspec.plan` runs a new sub-phase between Phase 0.8 (Frontend/UI Specifications) and Phase 0.9 (Registry Sync):

**Phase 0.85 — Test Strategy Derivation (HITL #3.5)**

By this point, `frontend.framework`, `backend.framework`, `backend.language`, `target_platform.mobile_framework`, `target_platform.mobile_platforms`, `target_platform.desktop_framework`, and `database.type` are pinned in `plan.md` through Phase 0.5-0.8. Phase 0.85 reads them, matches them against testing subagents at `.specify/subagents/testing/`, consults Station 12 (`12-cicd-release.md`) for pyramid guidance, and emits a 7-column table:

```markdown
| Layer | Test Type | Tool (default) | Coverage | Task-Range Slot | Subagent / Source | Rationale |
|-------|-----------|----------------|----------|-----------------|-------------------|-----------|
| Backend Unit    | unit        | pytest         | 80%  | interleaved per US | testing/python/pytest-patterns.md    | ... |
| Backend Integration | integration | httpx + testcontainers | 60%  | T-037/057/077 | testing/python/pytest-patterns.md | ... |
| E2E             | e2e         | Playwright     | 40%  | T-090-099    | testing/web/playwright-e2e.md      | ... |
```

Then it fires an `AskUserQuestion` for each row:

- **Accept (Recommended)** — row applied as shown
- **Change tool** — pick a different framework for this layer
- **Change coverage** — raise or lower the coverage target
- **Drop this layer** — skip test scheduling for this layer entirely

Row overrides are recorded in the `## Test Strategy` section of `plan.md` alongside approval fields (`Approval:`, `Approved By:`, `Approved At:`) and any dropped-row rationale.

---

## What lands in task files (Directive 8 Test Strategy Slice)

Under Directive 3 (Context Pinning), `/atomicspec.implement` may only read the current task file plus `index.md` and `traceability.md` — never `plan.md`. So Phase 0.85's Test Strategy would be quarantined if it lived only in `plan.md`.

Directive 8 amendment (v0.5+) authorizes `/atomicspec.tasks` to slice the Test Strategy per test-writing task and embed the relevant row into the task file itself. Each test-writing T-XXX file gains a block:

```markdown
### Test Strategy Slice

- **Layer**: Backend Unit
- **Test Type**: unit
- **Tool**: pytest
- **Coverage Target**: 80%
- **Subagent Reference**: .specify/subagents/testing/python/pytest-patterns.md
- **Rationale**: pytest fits FastAPI's dependency-injection style; fixtures cover DB setup/teardown per test.
```

The implementer sees this without ever needing to read `plan.md`. Context Pinning stays clean.

---

## Task numbering

No new numbering scheme. Uses existing reserved ranges from `tasks.md`:

- **Unit + integration tests**: interleaved per feature (T-020+ per user story), respecting P1/P2/P3 slice boundaries
- **Wiring tests**: T-037 / T-057 / T-077 (existing "Wire USn" slots)
- **Cross-cutting** (a11y / perf / security): T-080–089
- **E2E**: T-090–099

If a feature already uses T-080–089 or T-090–099 for non-test cross-cutting or E2E work, `/atomicspec.tasks` probes for collision and falls back to append-at-tail. No silent overwrite.

---

## Migration from v0.4.x → v0.5.0

Consumer projects on v0.4.x upgrade to v0.5.0 with **no behavior change** unless the user opts in at the migration prompt.

**First run under v0.5** fires the Phase 0 Testing-Consent Migration hook once:

1. Framework reads `testing.enabled` from the loaded registry.
2. Key **present** (any value including `null`): skip the hook — value is respected.
3. Key **absent entirely** (v0.4-shaped registry): fire `AskUserQuestion` with Recommended: Yes and app-specific rationale.
   - **On Yes**: write `testing.enabled: true` with `_provenance: migrated_v0.5`. Phase 0.85 will fire an inline confirm-migration prompt before deriving.
   - **On No**: write `testing.enabled: false` with `_provenance: human`. Never re-ask on subsequent runs. Log to `specs/_defaults/changelog.md`.
4. Non-interactive session (`--no-review` or no TTY): skip silently. Phase 0.85 later skips too. No infinite loop.

**To opt in immediately without waiting for the migration prompt**, edit `specs/_defaults/registry.yaml`:

```yaml
testing:
  enabled: true

_provenance:
  testing.enabled: human
```

Then run `/atomicspec.plan` — Phase 0.85 fires derivation directly.

---

## Coverage gaps

Twelve testing subagents ship with v0.5. Coverage is honest and incomplete on purpose — stacks without a matching subagent fall back to `MANUAL-CONFIGURE` (visible marker in the Test Strategy table, never silent). Users on those stacks configure manually.

| Framework gap | Coverage |
|---|---|
| Python (pytest) | ✅ `testing/python/pytest-patterns.md`, `testing/python/django-tdd.md` |
| Kotlin / Android | ✅ `testing/kotlin/kotest-mockk.md`, `testing/android/adb-ui-verification.md` |
| Rust | ✅ `testing/rust/cargo-testing.md` |
| Go | ✅ `testing/go/go-testing.md` |
| C++ | ✅ `testing/cpp/googletest.md` |
| Java (Spring Boot) | ✅ `testing/java/springboot-tdd.md` |
| PHP (Laravel) | ✅ `testing/php/laravel-tdd.md` |
| Web E2E (Playwright) | ✅ `testing/web/playwright-e2e.md`, `testing/web/playwright-webapp.md` |
| Load / perf (k6) | ✅ `testing/cross-cutting/k6-load.md` |
| **Web frontend JS/TS unit** (Vitest, Jest, RTL) | ❌ MANUAL-CONFIGURE — no dedicated subagent yet |
| **Web accessibility** (axe, screen-reader) | ❌ MANUAL-CONFIGURE |
| **API security** | ❌ MANUAL-CONFIGURE (Stations 08 + 13 partially cover in prose) |
| **Native iOS** (XCTest, XCUITest) | ❌ MANUAL-CONFIGURE |
| **Desktop** (Electron, Tauri) | ❌ MANUAL-CONFIGURE |
| Ruby/Rails, Node/TS backend unit, .NET/C#, Vue/Svelte/Angular frontend unit | ❌ MANUAL-CONFIGURE |
| Contract testing (Pact/Schemathesis) | Deferred to v0.6+ |
| Visual regression (Chromatic/Percy) | Deferred to v0.6+ |
| Mutation testing (Stryker) | Deferred to v0.6+ |

Roadmap for filling gaps lives in `docs/internal/known-gaps.md` under G-003 and successor entries. Native iOS is prioritized for v0.6 given the coverage-gap impact on cross-platform teams.

---

## FAQ

**Q: I answered No at consent and now regret it. How do I re-enable?**
Edit `specs/_defaults/registry.yaml`: set `testing.enabled: true` and update `_provenance.testing.enabled: human`. Log the change in `_defaults/changelog.md`. Next `/atomicspec.plan` will run Phase 0.85 derivation.

**Q: Phase 0.85 emitted a MANUAL-CONFIGURE row for my stack. Now what?**
The row shows up in `plan.md`'s Test Strategy section with `Tool: MANUAL-CONFIGURE` and `Subagent: (none — configure manually)`. `/atomicspec.tasks` still generates test tasks for the layer — you just need to add the framework specifics manually to those task files. The Rationale column tells you what the layer needs; you supply the tool.

**Q: I want to change the derived tool for a layer after `/plan` already ran.**
Currently: hand-edit the Test Strategy section in `plan.md`, then re-run `/atomicspec.tasks` so the slice re-extracts. A dedicated `atomicspec registry update <key>` CLI for post-hoc changes is logged as G-003 in known-gaps and targets a later release.

**Q: I'm running non-interactive CI and don't want any of this to fire.**
Pass `--no-review` to `/atomicspec.plan`. All HITL checkpoints (Phase 0.5, 0.7, 0.85, 0.8, 0.9) auto-apply their recommended defaults. `testing.enabled: null` in a non-interactive session causes Phase 0.85 to skip with a logged reason.

**Q: Where do I audit consent history?**
`specs/_defaults/registry.yaml`'s `_provenance.testing.enabled` field records the source. `specs/_defaults/changelog.md` has auto-append entries for every migration decision. `plan.md`'s Test Strategy section records the derivation approval + row-level overrides.
