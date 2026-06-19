---
description: Pre-plan interview — resolves spec ambiguity (v0.1 contract), pins the architectural lurkers from .specify/knowledge/architectural-lurkers.yaml, fires trigger-driven probes from .specify/knowledge/triggers.yaml, walks compliance scope, and writes decisions to specs/_defaults/registry.yaml with provenance tagging.
handoffs:
  - label: Build Technical Plan
    agent: atomicspec.plan
    prompt: Create a plan for the spec. I am building with...
scripts:
   sh: scripts/bash/check-prerequisites.sh --json --paths-only
   ps: scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Identify and resolve gaps that would cause the AI to make silent decisions during `/atomicspec.plan` or `/atomicspec.implement`. Two kinds of gaps:

1. **Spec ambiguity** — things the user wrote but unclearly (v0.1 contract).
2. **Architectural lurkers + structural decisions** — things the user *didn't write* but that the project needs answered before any code is generated. This is the v0.2 hardening (per Article IX Directive 7 scope).

Output: an updated `spec.md` (Clarifications section) AND new entries in `specs/_defaults/registry.yaml` with `_provenance` tags AND `interview_completed: <today>` set if the session completes normally.

This workflow runs BEFORE `/atomicspec.plan`. `/atomicspec.plan` Phase 0 will redirect users here when `interview_completed: null` (genesis behaviour). After it's set, `/atomicspec.specify` still advertises clarify (soft nudge) but does not block.

## Six-phase flow

```
Phase 1: Mode question         (Lite vs Detailed, sets cap)
Phase 2: Spec ambiguity scan   (v0.1 contract — 11-category taxonomy)
Phase 3: Architectural lurkers (from .specify/knowledge/architectural-lurkers.yaml)
Phase 4: Trigger-driven probes (from .specify/knowledge/triggers.yaml)
Phase 5: Compliance probes     (compliance:true triggers, two-step gate)
Phase 6: Write + provenance    (batched registry write, accept-rate audit)
```

## Registry Protocol (Constitution Directive 7)

Follow `_registry-protocol.md`:

- **On entry**: Read `specs/_defaults/registry.yaml`. Load existing values so we don't re-ask fields that are already non-null.
- **During**: Track every accepted answer in working memory. Mark each as `human` (active choice) or `accepted_recommendation` (default taken) for provenance tagging.
- **On exit**: Batch-write to `registry.yaml`. Set `interview_completed` if the session completed normally. Update `_provenance` block with one entry per write.

If the registry file is absent, warn the user that `/atomicspec.registry` should be run first to scaffold it from manifests, then proceed without registry writes (graceful degradation; spec clarifications still happen).

---

## Execution

### Setup (before Phase 1)

1. Run `{SCRIPT}` from repo root **once** (combined `--json --paths-only` / `-Json -PathsOnly`). Parse minimal JSON payload fields:
   - `FEATURE_DIR`
   - `FEATURE_SPEC`
   - `REPO_ROOT`
   - If JSON parsing fails, abort and instruct user to re-run `/atomicspec.specify` or verify the feature branch environment.
   - For single quotes in args like "I'm Groot", use escape syntax: e.g. `'I'\''m Groot'` (or double-quote if possible: `"I'm Groot"`).

1.5. **Pre-flight: detect unfinished spec authoring (v0.3+)**:

   Run `stamp-lifecycle status` on `$FEATURE_SPEC`. If `state` is `authoring_in_progress`, abort:
   > "Spec authoring is incomplete (started <ts> by <provider>). Finish /atomicspec.specify before clarifying."

1.6. **Bootstrap clarify-log.md and stamp this session (v0.3+, per Constitution Directive 9)**:

   Clarify is an EDIT to `$FEATURE_SPEC`, not a re-author — so it does NOT re-stamp spec.md. Instead each clarify session gets its own block in `$FEATURE_DIR/clarify-log.md`. The bootstrap helper handles "create if missing, otherwise prepend new Session block" deterministically — same shape across Claude / Codex / Gemini etc.

   ```bash
   CLARIFY_LOG="$(bash scripts/bash/clarify-session-bootstrap.sh --feature-dir "$FEATURE_DIR")"
   bash scripts/bash/stamp-lifecycle.sh init  "$CLARIFY_LOG" --lifecycle authoring
   bash scripts/bash/stamp-lifecycle.sh start "$CLARIFY_LOG" --lifecycle authoring --provider {{AGENT_NAME}}
   ```
   ```powershell
   $CLARIFY_LOG = & powershell.exe -NoProfile -File scripts\powershell\clarify-session-bootstrap.ps1 -FeatureDir $FEATURE_DIR
   scripts\powershell\stamp-lifecycle.ps1 -Command init  -Artifact $CLARIFY_LOG -Lifecycle authoring
   scripts\powershell\stamp-lifecycle.ps1 -Command start -Artifact $CLARIFY_LOG -Lifecycle authoring -Provider {{AGENT_NAME}}
   ```

   The bootstrap script returns the path to `clarify-log.md` on stdout. The new session block is the topmost `## Session <ts>` in that file, with an H3 `### Lifecycle Markers` section. `init` populates the stamp lines under that H3 (stamp-lifecycle matches headings at any depth `^#{2,6}\s+Lifecycle Markers\s*$`); `start` opens the lifecycle.

   This session's end stamp is written in Phase 6 after the registry batched write succeeds. If you abort mid-clarify, the next session sees `authoring_in_progress` on clarify-log.md and offers to resume.

2. Load `$REPO_ROOT/specs/_defaults/registry.yaml`. Capture `target_platform.primary` (web / mobile / desktop / both / library) — drives Phase 3 pack selection. Also load `interview_completed` to gauge whether this is a genesis run or a re-run.

   **If `target_platform.primary` is null at this point** (genesis run, never set), ask exactly this question BEFORE entering Phase 1's mode prompt. This setup question does NOT count against the mode cap:
   ```
   target_platform.primary is not set in the registry. What are you building?
     A) Web app (with or without backend API)     [most common]
     B) Mobile app (native or cross-platform)
     C) Desktop app
     D) Library / package shipped to other devs
   ```
   Write the answer to `target_platform.primary` immediately with provenance `human`.

3. Load `$REPO_ROOT/.specify/knowledge/architectural-lurkers.yaml` and `$REPO_ROOT/.specify/knowledge/triggers.yaml`. If either is missing, fall back to the v0.1 ambiguity-scan-only flow with a one-line warning.

4. Initialise an in-memory **answer log** for the session:
   ```
   answers = [
     { phase, field_or_topic, prompt, answer, provenance, fired_in_mode }
   ]
   ```
   Provenance values: `human` | `accepted_recommendation` | `null` (skipped).

### Phase 1 — Mode question

Show the user this exactly:

```
This is the pre-plan interview. It pins decisions you'd otherwise
get asked about mid-/plan or mid-/implement.

  [L] Lite — ~5 min, ~7 questions. Sensible defaults for everything
       else. Right for most projects, especially follow-on features
       where the registry is already populated.

  [D] Detailed — ~15 min, up to ~22 questions. Walks the full
       architectural-lurker pack for your app type. Right when you
       have strong opinions, or this is a brand-new project.

  [S] Skip — bypass the interview entirely. /atomicspec.plan will
       still ask about structural decisions mid-flow, but less
       efficiently. Fine for spikes.
```

Use `AskUserQuestion` with three options. **Lite is the default** (Enter or no input picks Lite).

**Override valves (introduce these on the FIRST question after Phase 1, not buried in docs):**
Print this one line above Question 1:
```
Tip: type "?" any time to see why a question matters,
     "lite" / "detailed" to change mode forward,
     "skip" to bail with whatever's been answered so far,
     "done" to finalize the current phase early.
```

**Mode caps:**
- Lite: 7 total questions (across all phases combined)
- Detailed: 22 total questions (raised from 18 — analysis showed the web pack alone needs ~12 must-decides, plus Phase 2 ~5, plus triggers/compliance ~5)
- Hard ceiling either mode: 25

**Priority order when the cap is hit** (apply in this strict order; lower priorities are dropped first):
1. Phase 5 compliance gates that already fired (NEVER drop — regulatory)
2. Phase 3 `tier: must` questions for the current app pack
3. Phase 4 triggered sub-checklists that fired (high-evidence — spec mentions them)
4. Phase 2 ambiguity-scan questions still queued
5. Phase 3 `tier: should` questions (Detailed only)
6. Phase 3 `tier: defer` (never asked here — falls through to /plan)

**Skip:** if the user picks Skip in Phase 1, jump to Phase 6 with an empty answer log. Phase 6 will report that nothing was set and NOT update `interview_completed`. `/atomicspec.plan` Phase 0 will redirect them back.

**Mid-session mode override:** any time the user types `lite` at a prompt, downgrade and skip remaining `tier: should` and `can_defer` questions. Typing `detailed` upgrades. Override applies forward only.

### Phase 2 — Spec ambiguity scan (v0.1 contract, preserved)

This phase is the v0.1 contract. Do NOT break or skip it; ONLY the ambiguity scan touches the spec file itself. Registry writes happen later (Phase 6).

1. Load the current spec file. Perform a structured ambiguity & coverage scan using this taxonomy. For each category, mark status: Clear / Partial / Missing. Produce an internal coverage map.

   **Functional Scope & Behavior**: core user goals, success criteria; explicit out-of-scope; roles/personas differentiation.
   **Domain & Data Model**: entities, attributes, relationships; identity/uniqueness rules; lifecycle/state transitions; data volume/scale assumptions.
   **Interaction & UX Flow**: critical user journeys; error/empty/loading states; accessibility/localization notes.
   **Non-Functional Quality Attributes**: performance, scalability, reliability/availability, observability, security/privacy, compliance/regulatory.
   **Integration & External Dependencies**: external services/APIs and failure modes; data import/export formats; protocol/versioning assumptions.
   **Edge Cases & Failure Handling**: negative scenarios; rate limiting/throttling; conflict resolution (concurrent edits).
   **Constraints & Tradeoffs**: technical constraints (language, storage, hosting); explicit tradeoffs or rejected alternatives.
   **Terminology & Consistency**: canonical glossary terms; avoided synonyms / deprecated terms.
   **Completion Signals**: acceptance criteria testability; measurable Definition of Done indicators.
   **Misc / Placeholders**: TODO markers / unresolved decisions; ambiguous adjectives ("robust", "intuitive") lacking quantification.

2. Generate (internally) a prioritized queue of candidate clarification questions. Apply these v0.1 constraints PLUS the new mode cap:
   - Cap from Phase 1 minus questions already asked. (If Lite and Phase 1 used 0 questions, you have 7 to spend across Phases 2-5.)
   - Suggested split: Phase 2 gets ~30% of the cap (~2 in Lite, ~5 in Detailed). Save the rest for Phases 3-5.
   - Each question answerable by 2-5 mutually exclusive options OR a `<=5 word` short answer.
   - Only ask questions whose answers materially impact architecture, data modeling, task decomposition, test design, UX behavior, operational readiness, or compliance validation.
   - Exclude questions already answered, trivial stylistic preferences, or plan-level execution details (unless blocking correctness).
   - Favor clarifications that reduce downstream rework risk or prevent misaligned acceptance tests.

3. Sequential questioning loop (interactive), one question at a time. Format:
   - **Recommended:** Option X — 1-2 sentence rationale.
   - Then render options as a Markdown table (A/B/C/...) plus a `Short` row when free-form is appropriate.
   - User can reply with letter, `yes` / `recommended` to accept, or short answer.
   - If `yes` / `recommended`: tag provenance `accepted_recommendation`. Otherwise: `human`.
   - Validate the answer maps to one option or fits the `<=5 word` constraint.
   - Stop early if all critical ambiguities resolved or user signals `done` / `good` / `no more`.
   - Never reveal future queued questions in advance.

4. Integration after EACH accepted answer (writes to **spec.md**, NOT registry):
   - Ensure a `## Clarifications` section exists.
   - Ensure `### Session YYYY-MM-DD` subheading for today exists.
   - Append `- Q: <question> → A: <final answer>`.
   - Apply the clarification to the most appropriate section(s):
     - Functional ambiguity → Functional Requirements
     - User interaction / actor distinction → User Stories or Actors
     - Data shape / entities → Data Model (add fields, types, relationships)
     - Non-functional constraint → Non-Functional / Quality Attributes (convert vague adjectives to metrics)
     - Edge case / negative flow → Edge Cases / Error Handling
     - Terminology conflict → normalize the term across spec; mark original with `(formerly "X")` if necessary.
   - If clarification invalidates an earlier ambiguous statement, REPLACE it; do not duplicate.
   - Save spec.md atomically after each integration to minimize context loss.
   - Append to in-memory `answers` log with provenance.

5. Phase 2 ends when: cap-portion is reached, user signals done, or coverage is complete.

### Phase 3 — Architectural lurker pack

1. Determine the pack name from `target_platform.primary`:
   - `web` or `both` → `web_with_api`
   - `mobile` → `mobile`
   - `desktop` → `desktop`
   - `library` → `library`
   - If `target_platform.primary` is null → ask the user once which kind of app this is, then pick the pack. This is a meta-question; it counts against the cap.

2. Load the pack from `.specify/knowledge/architectural-lurkers.yaml`. Walk `must_decide` first, then `can_defer` (Detailed mode only).

3. For each question, check if the registry field is already **non-null**. If yes, skip the question and tally it under "Pre-existing decisions honored: N" in the Phase 6 report.

   **Definition of "non-null" for this check** (apply identically in Phase 4):
   - YAML `null`, missing key, empty string `""`, and the literal string `"null"` all count as **null** (NOT a decision — ask).
   - Anything else — including the literal string `"none"` (a deliberate "no, we don't use this") — counts as **non-null** (a real decision — skip).

4. Ask each remaining question one at a time. Format identical to Phase 2:
   ```
   [Q N/Cap] <prompt>

     Recommended: <default>
     Rationale: <rationale>

     A) <option 1>      ← default (press Enter)
     B) <option 2>
     ...
     S) Short answer (≤5 words)

     > _   (Enter to accept, letter to choose, "?" for why-this-matters)
   ```

5. If user types `?`: show the `expander` text from the YAML (if present), then re-prompt. The `?` does NOT count against the cap.

6. Apply mode override: in Lite, skip `can_defer` and `tier: should` questions entirely. The `tier: defer` items NEVER get asked in clarify — they fall through to plan.

7. Each answer is appended to the in-memory `answers` log with provenance (Enter / `recommended` / `yes` → `accepted_recommendation`; anything else → `human`). Writes are deferred to Phase 6.

8. Stop Phase 3 when: pack exhausted, cap reached, user types `skip`, OR user types a free-form `done`.

### Phase 4 — Trigger-driven probes

1. Load `.specify/knowledge/triggers.yaml`. Filter to triggers WITHOUT `compliance: true` (those are Phase 5).

2. Scan `spec.md` + the original `/atomicspec.specify` `$ARGUMENTS` text for trigger keywords (case-insensitive substring; or regex if the entry uses `re:` prefix).

3. For each trigger that fires:
   - Output a one-line notice: `> Spec mentions <id> — running <id> sub-checklist (N questions).`
   - Walk the `sub_checklist`. Skip questions whose `field` is already non-null in the registry.
   - In Lite mode, skip `tier: should` sub-checklist items.
   - Ask remaining questions one at a time (same format as Phases 2-3).
   - Append each accepted answer to the in-memory log with provenance.

4. Each trigger fires at most once per session, regardless of how many keywords hit. Triggers run in declaration order (deterministic).

5. Stop Phase 4 when: all matching triggers handled, cap reached, or user types `done`.

### Phase 5 — Compliance probes

Compliance probes are flagged in `triggers.yaml` with `compliance: true`. They use a **two-step confirmation** with three answer states (Y / N / U) to dampen false positives without trapping users who genuinely don't know.

1. For each compliance trigger whose keywords matched the spec text:
   - First, ask the gate question:
     ```
     [Compliance check] The spec mentions <evidence keyword(s)>. This may put
     the project in <regime> scope (<one-line description>).

       Y) Yes, in scope — ask me the follow-up question(s)
       N) No, not in scope — skip
       U) Unsure — defer to /plan (recorded for follow-up)
       ?) Tell me what <regime> scope means here

       > _   (Enter = N, skip)
     ```
   - Default answer is **N**. If user picks N, log nothing for that trigger and move on. If user picks U (Unsure), set `_provenance.compliance.<regime>: deferred_to_plan` (do NOT set the boolean — leave it null) and add a one-line warning to the spec's `## Clarifications`: `- Compliance scope: <regime>=UNKNOWN — re-evaluate during /plan; see Station 14.` If user picks Y, proceed to the sub-checklist.

2. If gate = Y, walk the `sub_checklist` like Phase 4. **Important — same-field deduplication:** if the gate already answered the same registry field that the FIRST sub-checklist item writes to (e.g., gate=Y for GDPR sets `compliance.gdpr=true`; the sub-checklist's first item is also `compliance.gdpr`), SKIP that first sub-item and continue with the rest. Don't double-ask the same field.

3. After Phase 5 completes, if ANY compliance flag was set to `true`, append a note to the spec's `## Clarifications` section:
   ```
   - Compliance scope: <regime>=true — requires <specific gates per regime>. See Station 14 during /plan.
   ```
   (Per-regime gate notes are templated by id: gdpr → "data-deletion endpoint and consent storage", pci → "tokenization-only verification", etc.)

### Phase 6 — Write + provenance + finalize

1. **Accept-rate audit (interrogation-theater detection)**:
   - Count total registry-bound answers in the session (Phases 3-5 — Phase 2 only touches the spec).
   - Count those tagged `accepted_recommendation`.
   - If accepted_recommendation count ≥ 80% of total AND total ≥ 10, show the user:
     ```
     Notice: you accepted defaults on N of M questions.
     Quick review before /plan?

       R) Review the accepted defaults (loops back to first 'recommended' answer)
       C) Continue — write everything and proceed
     ```
   - If the user picks R, re-enter the questions tagged `accepted_recommendation` one at a time so they can revise; revised answers get re-tagged appropriately.

2. **Batched registry write** (single atomic update of `specs/_defaults/registry.yaml`):
   - **CRITICAL — Phase 2 entries DO NOT WRITE TO REGISTRY.** The answer log is unified across phases for accept-rate accounting, but only Phase 3, 4, 5 answers (and the setup-step `target_platform.primary` if it was asked) target registry fields. Phase 2 answers only update `spec.md` (already done incrementally during Phase 2). Filter the answer log to phase ∈ {3, 4, 5, setup} before writing `_provenance` entries.
   - For each filtered `answers` entry, set `<field>: <value>` in the registry.
   - Add a `_provenance.<field>: <provenance>` entry for each. Provenance values:
     - `human` — user picked a non-default option or typed a short answer
     - `accepted_recommendation` — user pressed Enter / typed `yes` / `recommended`
     - `deferred_to_plan` — user picked "Unsure" on a compliance gate
   - Update metadata:
     - `last_updated: <today ISO>`
     - `last_updated_by: clarify_session` (distinguishes from manual edits)
     - `interview_completed: <today ISO YYYY-MM-DD>` (ONLY if Phase 1 mode was NOT Skip AND at least one registry-targeting question was actually answered)
   - **Atomic write procedure** (the AI may not have a `mv` tool; this is the explicit 4-step):
     1. Hold the candidate registry YAML as a string in memory.
     2. Write that string to `specs/_defaults/registry.yaml.tmp`.
     3. Read `.tmp` back and `yaml.safe_load` it; if parse fails, abort and leave `.tmp` in place for inspection.
     4. If parse succeeds, write the SAME string to `specs/_defaults/registry.yaml`, then delete `.tmp`.

3. **Append to `specs/_defaults/changelog.md`**:
   ```markdown
   ## [YYYY-MM-DD] — /atomicspec.clarify session

   Mode: <Lite|Detailed>
   Total questions: N
   Spec clarifications: K
   Registry writes: M
   Provenance summary: H human / A accepted_recommendation / D deferred

   Changed fields:
   - <field>: <old> → <new>  (provenance: <p>)
   - ...
   ```
   - Strip newlines from user-supplied free-form values before embedding them (prevent markdown injection).
   - Truncate values longer than 200 characters with `…`.

4. **Spec final-write**: confirm the spec.md changes from Phase 2 are saved (they were saved incrementally, but verify final state matches expected).

5. **Validation pass**:
   - Spec.md `## Clarifications` section contains one bullet per accepted Phase 2 answer (no duplicates).
   - Registry YAML still parses (re-load with safe_load to confirm).
   - `interview_completed` is set IFF mode != Skip AND total questions > 0.

5.5. **Close clarify session lifecycle (v0.3+)**:

   ONLY after all Phase 6 sub-steps 1-5 succeed (registry write, changelog append, spec final-write, validation), close the authoring lifecycle on `clarify-log.md`:

   ```bash
   scripts/bash/stamp-lifecycle.sh end "$FEATURE_DIR/clarify-log.md" --lifecycle authoring --provider {{AGENT_NAME}}
   ```
   ```powershell
   scripts\powershell\stamp-lifecycle.ps1 -Command end -Artifact "$FEATURE_DIR\clarify-log.md" -Lifecycle authoring -Provider {{AGENT_NAME}}
   ```

   If you picked Skip in Phase 1 (no questions answered), still write the end stamp — the session ran to completion, just with empty output. The orientation procedure treats an empty-but-closed session as benign.

6. **Report** (always shown at end of session):
   ```
   /atomicspec.clarify — session report

   Mode:                 <Lite|Detailed|Skip>
   Total questions:      <N> (cap was <cap>)
   Spec clarifications:  <K>
   Registry writes:      <M>
   Accept-ratio:         <pct>% (<accepted_recommendation>/<total registry writes>)
   Compliance flags set: <list or "none">

   Outstanding (deferred to /plan):
   - <field> — reason: <cap reached | user said skip | tier=defer>

   Coverage:
   - Phase 2 taxonomy: <Resolved> / <Deferred> / <Clear> / <Outstanding>
   - Phase 3 must_decide answered: <N>/<M>
   - Phase 4 triggers fired: <list of ids>
   - Phase 5 compliance flags set: <list>

   Next: run /atomicspec.plan to translate the spec + registry into a buildable plan.
   ```

## Behavior rules

- If no meaningful spec ambiguities are found AND the registry is already populated (no Phase 3 questions needed) AND no triggers fire AND no compliance probes fire, respond: "No critical ambiguities or unspecified lurkers detected. Registry is healthy. Run `/atomicspec.plan` next." (Do NOT update `interview_completed` in this case — the user didn't actually answer anything.)
- If `spec.md` is missing, instruct the user to run `/atomicspec.specify` first; do not create one here.
- Respect early termination signals (`stop`, `done`, `proceed`) at any phase.
- Never exceed the mode cap (clarification retries for a single question do not count as new questions).
- Avoid speculative tech stack questions in Phase 2 — those belong in Phase 3 (architectural lurkers) where they're driven by the platform pack.
- Detected free-form answers that contradict the spec's stated platform or scope must surface a quick confirmation prompt (not a new question — a disambiguation).
- Trigger-table matches are case-insensitive substring by default; entries prefixed `re:` are regex (rare).

## Mid-session overrides (recap)

- `lite` — downgrade mode forward; cap shrinks to remaining-Lite-budget.
- `detailed` — upgrade mode forward; cap grows to remaining-Detailed-budget.
- `skip` — bail with whatever's accumulated. Spec changes from Phase 2 stay; registry writes stay; `interview_completed` is NOT set.
- `done` — finalize this phase, move on.
- `?` (during a question) — reveal the why-this-matters expander.

## Context for prioritization

{ARGS}
