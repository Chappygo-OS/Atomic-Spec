---
description: Execute implementation by processing atomic task files one at a time with Context Pinning (Atomic Traceability Model)
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks --check-gates --gate-context implement
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks -CheckGates -GateContext implement
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## ⛔ CONTEXT PINNING RULES

**STOP. Read this section before reading ANY files.**

Per Constitution Article IX, Directive 3, during implementation you are:

| Action | Allowed | Forbidden |
|--------|---------|-----------|
| Read for navigation | `index.md` | N/A |
| Read for current task | `T-XXX-[name].md` (ONE file only) | Other task files |
| Update after completion | `traceability.md` | N/A |
| Read project defaults | `specs/_defaults/registry.yaml` | N/A |
| Read full specs | ❌ NEVER | `plan.md`, `spec.md` |
| Phase 0 Orientation (v0.3+) | Lifecycle Markers blocks (via `stamp-lifecycle status` ONLY) of every artifact in the feature folder — see Directive 9 | Body content of `plan.md`, `spec.md`, `clarify-log.md` — even during orientation |

**If you are about to read `plan.md`, `spec.md`, or `clarify-log.md`, STOP. You are violating Context Pinning.**

**Phase 0 Orientation is a one-shot carve-out (Directive 9):** runs ONCE at session start, before any task loop. After Phase 0 completes (or finds the feature clean), normal Context Pinning resumes in full.

**You MUST NOT invoke the Read tool on `plan.md`, `spec.md`, or `clarify-log.md` at any point during Phase 0.** The ONLY permitted access to those artifacts in Phase 0 is via `scripts/{bash,powershell}/stamp-lifecycle.{sh,ps1} status --json`, which extracts the Lifecycle Markers block and returns JSON. Justifications such as "I need the heading first" or "just to find the block" are explicitly rejected — the status script already returns the structured block. Reading the body content of any of these three files during Phase 0 is a Constitution violation regardless of intent.

## Outline

### 0. Orientation — Detect Partial Work (v0.3+, Directive 9)

**This phase ONLY runs at session start.** Its job: detect whether prior work on this feature was interrupted (Claude session crashed → Codex resumes; quota cut → Gemini picks up). If yes, present options and STOP for user confirmation. NEVER silently resume.

The orientation is the cross-provider handoff substrate. Skipping it is a Constitution violation.

#### 0.0 Phase 1 Prelude — Efficiency Hint (v0.4+) _(advisory)_

Run: `atomicspec select-model --phase coordinator`

If a non-empty model name is printed, the project has configured an advisory tier for coordinator-role turns like this Phase 0 Orientation sweep; agents that support per-turn model selection (Claude Code subagent `Task` tool) MAY honor it. When Phase 1 begins and actual task work starts, re-run with `--phase implementer` for the implementer tier. If the command prints nothing, `advisor_enabled` is `false` (v0.4 default) — proceed with default behavior; byte-for-byte v0.3 compatibility is preserved.

**This surface is advisory only.** It does not widen Directive 3 pinning, does not permit reading `plan.md` / `spec.md` / `clarify-log.md` body content, and does not affect the stamp-lifecycle enumeration below. `atomicspec select-model` reads ONLY `specs/_defaults/registry.yaml`, which is not a Directive-3-restricted artifact. Record the resolved model in §0.6's Orientation Evidence file under the `## Efficiency` section. Per-feature measurement lands in v0.4.1.

#### 0.1 Locate the active feature folder

```bash
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
FEATURE_DIR="specs/$BRANCH"
```
```powershell
$BRANCH = git rev-parse --abbrev-ref HEAD
$FEATURE_DIR = "specs/$BRANCH"
```

If the branch doesn't match `NNN-feature-name` or `specs/$BRANCH` doesn't exist, exit Phase 0 and proceed to Phase 1 — this isn't an implementation context with feature artifacts.

#### 0.2 Read navigation artifacts (Directive 3 carve-out, allowed)

Read ONLY `index.md` and `traceability.md` from `$FEATURE_DIR`. These are explicitly permitted by Directive 3.

**DO NOT** read `plan.md`, `spec.md`, or `clarify-log.md` body content — even now. The orientation reads ONLY their Lifecycle Markers via the status script.

#### 0.3 Run `stamp-lifecycle status` on every artifact

Run the EXACT enumeration loop below — do NOT improvise a shorter version (the orientation must inspect every artifact, missing any one breaks Directive 9).

```bash
for f in \
    "$FEATURE_DIR/spec.md" \
    "$FEATURE_DIR/plan.md" \
    "$FEATURE_DIR/clarify-log.md" \
    "$FEATURE_DIR/index.md" \
    "$FEATURE_DIR/traceability.md" \
    "$FEATURE_DIR"/tasks/T-*.md
do
    [ -f "$f" ] || continue
    scripts/bash/stamp-lifecycle.sh status "$f" --json
done
```
```powershell
$artifacts = @(
    "$FEATURE_DIR\spec.md",
    "$FEATURE_DIR\plan.md",
    "$FEATURE_DIR\clarify-log.md",
    "$FEATURE_DIR\index.md",
    "$FEATURE_DIR\traceability.md"
) + (Get-ChildItem -Path "$FEATURE_DIR\tasks" -Filter 'T-*.md' -ErrorAction SilentlyContinue |
     ForEach-Object { $_.FullName })
foreach ($f in $artifacts) {
    if (Test-Path $f -PathType Leaf) {
        & scripts\powershell\stamp-lifecycle.ps1 -Command status -Artifact $f -Json
    }
}
```

Collect every JSON result into the orientation evidence record. Each emits `state` ∈ `{ legacy_closed | empty | authoring_in_progress | authored | implementing | done }`.

**Performance note**: for features with 50-100 tasks, this is 50-100 script spawns (~5-15 seconds on Linux, possibly 30-60 seconds on Windows PowerShell where process spawn is slower). Acceptable for a once-per-session orientation. A batch mode (`stamp-lifecycle status --feature-dir <path>`) is tracked for v0.4.

#### 0.4 Classify outcome (exactly three per Directive 9)

Read `lifecycle.stale_threshold_days` from `specs/_defaults/registry.yaml` (default 7 if absent).

- **Clean state**: every artifact reports `closed | done | legacy_closed | authored`. → Print one-line summary, append the Orientation Evidence block (step 0.6), then proceed to Phase 1.
- **Stale state**: at least one artifact has `authoring_in_progress` or `implementing` with `start` timestamp older than `stale_threshold_days`. → Informational, not blocking. Show the user: "Open block on <artifact> since <ts> (<N> days ago) — appears abandoned. Resume or discard?" then proceed only with confirmation.
- **Conflict state**: at least one artifact has `authoring_in_progress` or `implementing` with `start` timestamp NEWER than `stale_threshold_days`. → STOP. Present the menu in 0.5.

#### 0.5 On conflict, present options (and STOP)

**Before** invoking AskUserQuestion, enrich the prompt with context the user needs to decide at 11 PM under stress. You already have everything from 0.3's JSON + the task file:

- Compute **elapsed minutes**: `(now - start_ts) / 60` — rounded.
- Read the open artifact's **verify-depth** field from the same JSON.
- Run `git diff --name-only HEAD` AND `git status --porcelain` (read-only); scope output to files matching the task's declared "Files to modify" / "Files to Update" sections (read those from the task file's body — Directive 3 ALLOWS reading the current task file).
- Estimate verification cost from depth (`light` = "quick", `deep` = "may take a minute or more").

Invoke AskUserQuestion with this exact prompt shape (substitute the bracketed values):

```
Resume detected on <task-filename>
  Started:        <ts> by <provider>  (<N> minutes ago)
  Verify-depth:   <light|deep>  (set by author; <quick|may take a minute+>)
  Files touched:  <comma-separated list scoped to task's declared file set,
                  or "none detected" if working tree is clean>

  A) Resume — re-run the embedded verification (depth as above), and if it
              passes, close the lifecycle and proceed
  B) Redo   — print the file list above and let YOU decide which to revert
              (git diff --name-only is read-only; this command will not
              auto-revert anything). After you've reverted what you want,
              re-stamp start and re-author from scratch.
              (v0.4 will add per-task git snapshots so Redo can scope
              reverts to the task's declared file set automatically.)
  C) Skip   — leave this artifact open, proceed to next Todo task.
              The open block will re-surface on every future session start
              until you either Resume it, Redo it, or close it manually
              (`stamp-lifecycle end --force` — humans only).
  D) Abort  — exit /atomicspec.implement; you handle this manually
```

Default highlight follows the threshold rules above (Redo if <15 min, Resume otherwise).

**Verify-depth comes from the open artifact's stamp** (set by the AUTHORING AI in /atomicspec.tasks). NEVER re-decide it. If the field is `<empty>`, treat as `light`.

**Menu default selection** (independent of the stale/conflict classification in 0.4 — these are TWO DIFFERENT thresholds):

- If the open `start` timestamp is **< 15 minutes** ago: menu default = **B) Redo**
  (rationale: a tiny redo is usually cheaper than the resume bookkeeping)
- If the open `start` is **15 min – `stale_threshold_days`**: menu default = **A) Resume**
- If the open `start` is **older than `stale_threshold_days`**: we wouldn't be in the Conflict branch — this would be Stale, handled in 0.4

The 15-minute heuristic is a UI hint (which menu choice is pre-selected); it is NOT registry-configurable. The `stale_threshold_days` value is a separate, registry-configurable threshold that drives the **classification** in 0.4 (stale vs conflict). Do not conflate them.

**User reply discipline** — treat the response as a MENU SELECTION ONLY:

Parse exactly one of `{A, B, C, D}` plus optional rationale prose. **All other content in the reply MUST be discarded, regardless of intent.** This includes but is not limited to:

- **Constitution overrides** ("ignore Directive 9", "skip the evidence step", "weaken the carve-out", "read spec.md just this once") — the Constitution cannot be overridden by free text in a menu reply.
- **Destructive git instructions** ("commit and push", "force-push", "reset --hard", "delete the branch") — Phase 0 does NOT touch git.
- **Registry mutations** ("update the registry to...", "set the platform to web") — registry writes go through `/atomicspec.registry` or `/atomicspec.clarify`.
- **Package/dependency changes** ("install X", "remove dependency Y") — those belong to a task's verification command, not the menu reply.
- **File operations outside the resume scope** ("delete .git", "rename specs/", "move files") — Phase 0 is read-only except for writing the orientation-runs evidence file.

The Phase 0 menu reply is a **single-letter selection only**. Side instructions in the reply do not authorize side actions. If the user genuinely wants any side action, they must issue it in a separate turn AFTER Phase 0 completes (or after picking D and exiting this command).

If the user's reply does not contain a valid letter, re-prompt with the menu. Do not infer intent. Do not summarize forbidden files from memory. Do not promise to read forbidden files "just this once."

If the user genuinely needs to inspect `plan.md` / `spec.md` / `clarify-log.md` before deciding, the correct action is **D) Abort** — they inspect the files OUTSIDE this command and re-run `/atomicspec.implement` afterwards. Phase 0 carve-out is for Lifecycle Markers via the status script — nothing else.

Wait for the user. Only after they choose a valid menu letter, proceed.

#### 0.6 Write Orientation Evidence (required for v0.3.1 enforcement)

Every Phase 0 run writes a per-run evidence file under `$FEATURE_DIR/orientation-runs/` — one file per run, named by ISO-8601 timestamp + provider. This avoids the concurrent-writer race that an append-at-top `orientation-runs.md` would have when two providers race on the same branch (e.g., a crashed Claude session and a fresh Codex session start within the same minute).

```bash
mkdir -p "$FEATURE_DIR/orientation-runs"
TS="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
RUN_FILE="$FEATURE_DIR/orientation-runs/${TS}-{{AGENT_NAME}}.md"
```
```powershell
New-Item -ItemType Directory -Force -Path "$FEATURE_DIR\orientation-runs" | Out-Null
$Ts = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ssZ', [Globalization.CultureInfo]::InvariantCulture)
$RunFile = "$FEATURE_DIR\orientation-runs\${Ts}-{{AGENT_NAME}}.md"
```

Each run file follows the structure from `templates/orientation-runs-template.md` (now interpreted as the **per-run** template, with the directory `orientation-runs/` holding individual runs):

```markdown
# Orientation Run <ISO-8601-UTC>

## Outcome

<clean | stale | conflict>

## Artifacts

```json
{"artifact":"spec.md","state":"closed",...}
{"artifact":"plan.md","state":"closed",...}
...
```

## Decision

<Proceeded to Phase 1 | Resumed T-007 from prior session | Discarded prior work on T-007 (redo) | User aborted>

## Efficiency (v0.4+)

- advisor_enabled: <true|false>
- tier_map_source: specs/_defaults/registry.yaml
- provider_detected: {{AGENT_NAME}}
- notes: advisory only; per-feature measurement lands in v0.4.1
```

<!--
  Why only advisor state + registry pointer, not resolved tier values:
  the tier map is derived from the registry at read time by v0.4.1
  measurement tooling; persisting a snapshot of it here would guarantee
  bit-rot when the registry changes. This block's job in v0.4 is to give
  a v0.4.1 hook-based baseline reader an unambiguous "was the advisor on
  during this run, and where should I look up its tier map?" — nothing
  more. Do NOT expand this to record which model actually ran; that's
  what the hook API returns, not what the framework can honestly claim.
-->


**Status of enforcement (v0.3 honest disclosure)**: this evidence is REQUIRED by Directive 9, but the wiring that BLOCKS Phase 1 on missing evidence (`check-prerequisites.sh --check-orientation`) ships in v0.3.1, not v0.3.0. For v0.3.0, missing or stale evidence is a Constitution violation by policy but NOT a hard gate. The forthcoming v0.3.1 hardening will make this a runtime block.

Per-run files are auditable, append-free, and race-free by construction (no two timestamps collide at second precision). For aggregate views, a future `atomicspec orientation log` command can sort and merge the per-run files at read time.

#### 0.7 Phase 0 termination

After 0.6 completes successfully:
- If outcome was Clean, the menu was Resume (A), or the user explicitly proceeded after Stale — go to Phase 1.
- If the user picked Abort (D) — exit cleanly with exit code 0.

**Once Phase 1 begins, Phase 0 is over.** Subsequent reads in this session are governed by Directive 3 alone. The carve-out is single-shot, not persistent.

### 1. Setup & Structure Verification

Run `{SCRIPT}` from repo root. This script will:
1. Parse FEATURE_DIR and available documents
2. **Automatically validate gate criteria** (tasks/, index.md, traceability.md)
3. **BLOCK execution if gates fail** - you will see error output

If the script outputs gate failures, report them to the user and **DO NOT PROCEED**.

### 1.5 Load Project Defaults Registry

**Per Constitution Article IX, Directive 7 - Load registry before implementation.**

Read `specs/_defaults/registry.yaml` to get project-wide implementation standards:

1. **Extract relevant implementation defaults**:
   - `architecture.*` - System pattern, layers (determines code structure)
   - `code_patterns.*` - **CRITICAL**: Data access, DI, error handling, validation
   - `conventions.*` - Naming conventions for code
   - `backend.*` - Language, framework patterns
   - `frontend.*` - Component patterns, styling approach
   - `database.*` - Query style, naming conventions
   - `error_handling.*` - Logging format, correlation headers
   - `testing.*` - Test framework, coverage requirements

2. **Apply during implementation**:
   - Use registry naming conventions for new files/functions
   - Follow registry patterns for code structure
   - If task requires a decision not in task file, check registry first

   **Code patterns drive implementation style**:
   - `code_patterns.data_access: repository` → Use repository interfaces, not direct ORM calls
   - `code_patterns.error_handling: result_type` → Return Result<T,E>, don't throw exceptions
   - `code_patterns.dependency_injection: constructor` → Pass dependencies via constructor
   - `code_patterns.validation_approach: schema` → Use Zod/Yup schemas, not manual checks
   - `architecture.layers: clean` → Separate use cases from entities from interfaces

3. **If implementation would deviate from registry**:
   - The task file should contain explicit DEVIATION block
   - If no DEVIATION block but code pattern differs, flag for review
   - Do NOT silently deviate from registry standards

**Note**: Context Pinning still applies - registry is a reference document, not a planning document.

### 2. Check Checklists Status

If `FEATURE_DIR/checklists/` exists:
- Scan all checklist files
- Count completed vs incomplete items
- Display status table:

```text
| Checklist | Total | Completed | Incomplete | Status |
|-----------|-------|-----------|------------|--------|
| ux.md     | 12    | 12        | 0          | ✓ PASS |
| test.md   | 8     | 5         | 3          | ✗ FAIL |
```

If any incomplete: Ask user to proceed or wait.

### 3. Load Navigation Context (Context Pinning)

**🛑 CONTEXT PINNING ENFORCED**

Read ONLY these files for context:

1. **Read `index.md`** - Get:
   - Feature summary
   - Current phase
   - Task progress (Total/Completed/In Progress)
   - Active task ID
   - Task queue

2. **Read `traceability.md`** - Get:
   - Pending tasks list
   - Task → Requirement mapping
   - Current coverage status

**DO NOT READ**:
- ❌ `plan.md` - Forbidden during implementation
- ❌ `spec.md` - Forbidden during implementation
- ❌ Other task files - Only read current task

### 4. Task Execution Loop

For each pending task in order:

#### 4.1 Load Current Task

Read ONLY `tasks/T-XXX-[name].md` for the current task. Resolve the concrete filename (e.g., `T-007-create-user-model.md`) from the Todo list in `index.md` (`traceability.md`'s Lifecycle Ledger is the authoritative state). Bind it to a variable for later steps in this loop iteration:

```bash
# After resolving the next Todo task's filename:
TASK_FILE="$FEATURE_DIR/tasks/$CURRENT_TASK_FILENAME"   # e.g., specs/014-feature/tasks/T-007-create-user-model.md
```
```powershell
$TaskFile = "$FEATURE_DIR\tasks\$CurrentTaskFilename"
```

`$TASK_FILE` / `$TaskFile` is referenced in 4.2.4 (open implementation stamp) and 4.4 (close implementation stamp) — always pass the concrete path, NEVER a glob like `T-XXX-*.md` (stamp-lifecycle expects a single artifact path and will exit 3 on a missing file).

Extract from task file:
- **Task ID**: T-XXX
- **Requirement Mapping**: FR-XXX links
- **Files to modify**: Exact paths
- **Dependencies**: Prerequisite tasks
- **Implementation Steps**: Specific actions
- **Verification Command**: Exact command to run (capture into `$VERIFICATION_COMMAND` for use in 4.4)
- **Acceptance Criteria**: Checklist items

#### 4.2 Verify Dependencies

Check `traceability.md` to confirm all dependency tasks are marked "Done".

If dependencies not met: **SKIP** task, move to next, report blocked status.

#### 4.2.4 Open implementation lifecycle on this task (v0.3+, Directive 9)

Before implementing, open the implementation lifecycle stamp on the current task file (use `$TASK_FILE` bound in 4.1, NOT a glob pattern):

```bash
scripts/bash/stamp-lifecycle.sh start "$TASK_FILE" --lifecycle implementation --provider {{AGENT_NAME}}
```
```powershell
scripts\powershell\stamp-lifecycle.ps1 -Command start -Artifact $TaskFile -Lifecycle implementation -Provider {{AGENT_NAME}}
```

This is what makes resume work: if the AI crashes or quota cuts during step 4.3 / 4.4, the next session's Phase 0 Orientation sees this task as `implementing` and offers Resume/Redo/Skip/Abort.

The script enforces:
- The task must already have `Authored end` populated (exit 7 otherwise) — task generation must be complete
- Implementation lifecycle is only valid on `tasks/T-*.md` and `traceability.md` (exit 8 otherwise)
- Field already populated rejects without --force (exit 6) — see Phase 0 Resume flow for the override path

#### 4.2.5 Subagent Context Loading

**Task files contain an embedded configuration section set during task generation.**

1. **Read the Implementation Context section from the CURRENT TASK FILE**:

   ```markdown
   ## Implementation Context
   - Platform: [inherited from plan.md during task generation]
   - Subagents Enabled: [yes/no]
   - Available Subagents: [list relevant to this task's domain and platform]
   ```

   **This maintains Context Pinning compliance - DO NOT read plan.md.**

2. **If Subagents Enabled = "no"**: Skip to 4.3, implement the task yourself.

3. **If Subagents Enabled = "yes"**: Match task to an available agent from the list.

   **Extract domain from current task file**:
   - Check "Domain Rules" section header (e.g., "from data-architecture subagent")
   - Check file paths in "Files to Create" (e.g., `repositories/` → data-architecture)
   - Check task objective keywords

4. **Match to an available subagent via Dynamic Discovery**:

   **Follow `_subagent-discovery.md`** — do NOT hardcode agent names in this step. The discovery protocol scans `.specify/subagents/`, reads YAML frontmatter, and scores each agent's `description` against the task's keywords and file paths. Whichever agent scores highest is the match.

   If no agent scores above the minimum threshold, fall back to the Knowledge Station for the task's domain (via `.specify/knowledge/stations/00-station-map.md`). If neither resolves, implement the task yourself using the embedded context from the task file.

5. **Spawn the matched subagent using Task tool**:

   ```
   Task(
     subagent_type: "[matched-agent-name]",
     prompt: "Implement task T-XXX-[name].

       Read the task file at: [FEATURE_DIR]/tasks/T-XXX-[name].md

       Follow the Embedded Context section for:
       - Project Standards (registry values)
       - Domain Rules (patterns to follow)
       - Gate Criteria (must verify before done)

       Implement the code, run verification command, report result.",
     description: "Implement T-XXX with [agent-name]"
   )
   ```

6. **Handle subagent result**:
   - If subagent reports success → Proceed to 4.4 (verification already done)
   - If subagent reports failure → Report to user, ask for guidance
   - If no agent matches → Fall back to 4.3 (implement yourself)

#### 4.3 Execute Implementation (Fallback / No Subagent)

**Use this section if subagents are disabled OR no agent matches the task domain.**

Follow the Implementation Steps from the task file:
1. Create/modify files as specified
2. Follow exact paths provided
3. Implement according to acceptance criteria

#### 4.4 Run Verification (Transactional)

Execute the **Verification Command** from the task file.

```bash
# Example: Run the exact command specified in the task
npm test -- --grep "UserModel creates valid user"
```

**Transactional close (v0.3+, Directive 9)** — order matters:

The stamp-end IS the authoritative "done" record. Traceability.md and index.md are reporting layers that can be re-derived from stamps on the next read. Therefore the end-stamp lands FIRST, then traceability/index. If traceability/index updates fail AFTER the stamp closes, the task is still officially Done — only the reporting view drifts, and the orientation procedure's Lifecycle Ledger regeneration will reconcile on the next pass.

Sequence:

```bash
# 1. Run the embedded verification command (captured into $VERIFICATION_COMMAND in 4.1).
if eval "$VERIFICATION_COMMAND"; then
    # 2. Close the implementation lifecycle stamp FIRST. This is the authoritative
    #    "task done" record. If this fails (disk full, permissions), nothing
    #    downstream runs and the next session correctly sees `implementing`.
    scripts/bash/stamp-lifecycle.sh end "$TASK_FILE" --lifecycle implementation --provider {{AGENT_NAME}} || {
        echo "stamp-end failed; task remains open, traceability/index unchanged"
        # Surface the failure to the user; do NOT touch traceability/index.
        exit 1
    }
    # 3. Update traceability.md (Status=Done, Verified=Y, Verification Log entry).
    # 4. Update index.md (Completed count, move active task).
    # Both 3 and 4 are reporting-layer updates. If either fails, the stamp still
    # holds ground truth and the Ledger regeneration in the next Phase 0 will
    # reconcile.
else
    # Verification failed. Leave the implementation stamp OPEN — that IS the
    # resume signal. Touch nothing else. Report failure to the user, ask:
    # fix-and-retry, skip, or abort.
    echo "verification failed; task remains open for resume"
fi
```

```powershell
& $VERIFICATION_COMMAND
if ($LASTEXITCODE -eq 0) {
    # Close stamp first.
    & scripts\powershell\stamp-lifecycle.ps1 -Command end -Artifact $TaskFile -Lifecycle implementation -Provider {{AGENT_NAME}}
    if ($LASTEXITCODE -ne 0) {
        Write-Host "stamp-end failed; task remains open, traceability/index unchanged"
        exit 1
    }
    # Then update traceability.md + index.md (reporting layers).
} else {
    Write-Host "verification failed; task remains open for resume"
}
```

**Invariants this enforces**:

- **End-stamp is ground truth.** If it succeeds, the task is done regardless of whether traceability/index updates land.
- **An open stamp is always a real resume signal.** If verification fails OR stamp-end fails, no traceability/index update happens, so the next session's Phase 0 sees a coherent "implementing" state and presents the Resume menu correctly.
- **No snapshot/rollback needed.** Since the end-stamp lands first and nothing later can invalidate the stamp's truth, there is no failure path that requires restoring prior state.

**If verification fails**: do NOT call stamp-end. The open stamp IS the resume signal. Report failure with output. Ask user: Fix and retry, or skip?

**Recovery from traceability/index reporting drift**: if a stamp says `done` but `traceability.md` still shows the task pending (because step 3 or 4 failed), the next session's Phase 0 evidence block captures this and the Lifecycle Ledger regeneration in 4.6 corrects the report. No user intervention needed.

#### 4.5 Update Traceability

After each task completion (verification passed in 4.4), update `traceability.md`:
- Set task Status to "Done"
- Set Verified to "Y"
- Add entry to Verification Log
- Update parent Requirement status if all tasks complete

This step is INSIDE the 4.4 transaction (between the verification command and the end stamp). It's listed separately here for documentation; in the actual command flow it executes between `if eval "$VERIFICATION_COMMAND"; then` and the `stamp-lifecycle end` call.

#### 4.6 Update Index

After each task, update `index.md`:
- Increment Completed count
- Update Active Task to next in queue
- Move completed task from queue

### 5. Project Setup Verification

During first Setup phase task, create/verify ignore files:

**Detection & Creation**:
- Git repo → `.gitignore`
- Dockerfile → `.dockerignore`
- ESLint → `.eslintignore`
- Prettier → `.prettierignore`

**Common Patterns by Technology**:
- **Node.js**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
- **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `dist/`
- **Go**: `*.exe`, `*.test`, `vendor/`
- **Rust**: `target/`, `debug/`, `release/`

### 6. Error Handling

**Task Failure**:
- Report which task failed
- Show verification command output
- Offer options: Retry, Skip, Abort

**Dependency Blocked**:
- List blocked tasks
- Show which dependencies are incomplete
- Suggest completing dependencies first

**Context Pinning Violation**:
- If tempted to read plan.md or spec.md: **STOP**
- All needed context is in the current task file
- If task file is insufficient: Report as task quality issue

### 7. Progress Reporting

After each task, report:
```text
✓ T-XXX-[name] completed
  Verification: PASSED
  Progress: [X/N] tasks complete
  Next: T-YYY-[next-task]
```

### 8. Completion

When all tasks in `traceability.md` are "Done":

#### 8.1 Integration Verification (MANDATORY)

⚠️ **CRITICAL: This step prevents the #1 cause of "feature done but not working" issues.**

Before marking the feature complete, run platform-appropriate integration checks.

**Step 1: Load Platform from Task Context**

Read platform from the task file's Implementation Context section.
This was set during task generation and reflects the project's platform.

**DO NOT re-read registry - the task file is authoritative for this implementation.**

```markdown
## Implementation Context
- Platform: [web/mobile/both]
- Mobile Framework: [native/react-native/flutter] (if mobile)
- Mobile Platforms: [ios/android/both] (if mobile)
```

Based on the Implementation Context:
- If Platform = `web` → Run Web Integration checks
- If Platform = `mobile` → Check Mobile Framework:
  - `native` + `ios` → Run iOS Native checks
  - `native` + `android` → Run Android Native checks
  - `react-native` → Run React Native checks
  - `flutter` → Run Flutter checks
- If Platform = `both` → Run Web + appropriate Mobile checks

---

##### Web Integration (Default)

```bash
# Backend: Verify all routes are registered (Python/FastAPI example)
grep -r "include_router\|app.add_api_route" backend/main.py backend/app.py 2>/dev/null

# Backend: Verify API docs accessible
curl -s http://localhost:8000/api/docs | grep -q "openapi" && echo "API docs accessible"

# Frontend: Verify all pages are in router
grep -r "Route\|path:" frontend/src/App.tsx frontend/src/router 2>/dev/null

# Frontend: Verify navigation has links to new pages
grep -r "href=\|to=\|navigate(" frontend/src/components/*Nav* frontend/src/components/*Sidebar* 2>/dev/null
```

**Web Wiring Checklist:**
- [ ] All backend routes registered in main app file
- [ ] All frontend pages accessible via navigation
- [ ] All API endpoints callable from frontend stores/hooks
- [ ] No orphan components (everything rendered somewhere)
- [ ] No dead routes (all routes lead to working pages)
- [ ] Navigation reflects all user-facing features

---

##### iOS Native Integration

```bash
# Navigation: Verify views are in navigation stack
grep -rE "NavigationStack|NavigationView|NavigationLink|UINavigationController" ios/ --include="*.swift" 2>/dev/null

# Deep Links: Verify URL schemes configured
grep -rE "CFBundleURLSchemes|CFBundleURLTypes" ios/ --include="*.plist" 2>/dev/null
# OR for SwiftUI App structure
grep -rE "onOpenURL|\.onContinueUserActivity" ios/ --include="*.swift" 2>/dev/null

# Entitlements: Verify capabilities configured (if feature requires them)
grep -rE "aps-environment|com\.apple\.developer" ios/ --include="*.entitlements" 2>/dev/null

# Permissions: Verify Info.plist has required usage descriptions
grep -rE "NS.*UsageDescription" ios/ --include="*.plist" 2>/dev/null

# Build Verification: Verify project builds for simulator
xcodebuild -scheme [SCHEME] -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5

# TestFlight Readiness (if applicable)
xcodebuild -scheme [SCHEME] -configuration Release archive -archivePath build/App.xcarchive 2>&1 | grep -E "ARCHIVE SUCCEEDED|error:"
```

**iOS Wiring Checklist:**
- [ ] All views accessible via NavigationStack/NavigationView
- [ ] Tab bar items added for new top-level features
- [ ] Deep link routes registered (if URL scheme used)
- [ ] Required entitlements added (Push, IAP, etc.)
- [ ] Info.plist has all required permission descriptions
- [ ] App builds without errors for simulator
- [ ] No missing asset catalog entries
- [ ] StoreKit configuration file present (if IAP feature)

**iOS Tool Availability Handling:**
```bash
# Check if Xcode tools available
if ! command -v xcodebuild &> /dev/null; then
    echo "WARN: xcodebuild not available - skipping build verification"
    echo "Manual verification required: Open project in Xcode and build"
fi
```

---

##### Android Native Integration

```bash
# Manifest: Verify all activities/services registered
grep -rE "<activity|<service|<receiver|<provider" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Navigation: Verify composable routes (Jetpack Compose)
grep -rE "composable\(|NavHost|navController" android/ --include="*.kt" 2>/dev/null
# OR for XML navigation
grep -rE "<fragment|<action|app:destination" android/ --include="*.xml" 2>/dev/null

# Deep Links: Verify intent filters configured
grep -rE "intent-filter|android:scheme|android:host" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Permissions: Verify required permissions declared
grep -rE "uses-permission" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Build Verification: Verify project builds
./gradlew assembleDebug 2>&1 | tail -10

# Signing: Verify release signing configured (for Play Console readiness)
grep -rE "signingConfigs|storeFile|keyAlias" android/app/build.gradle* 2>/dev/null

# Play Console Readiness (if applicable)
./gradlew bundleRelease 2>&1 | grep -E "BUILD SUCCESSFUL|BUILD FAILED"
```

**Android Wiring Checklist:**
- [ ] All activities registered in AndroidManifest.xml
- [ ] Navigation graph includes all screens
- [ ] Deep link intent filters configured (if applicable)
- [ ] Required permissions declared in manifest
- [ ] Bottom navigation/drawer updated for new features
- [ ] ProGuard/R8 rules added for new dependencies
- [ ] App builds without errors (assembleDebug)
- [ ] Release signing configured (if publishing)
- [ ] Billing client configured (if IAP feature)

**Android Tool Availability Handling:**
```bash
# Check if Gradle wrapper available
if [ ! -f "./gradlew" ]; then
    echo "WARN: gradlew not found - skipping build verification"
    echo "Manual verification required: Open project in Android Studio and build"
fi
```

---

##### React Native Integration (Both Platforms)

```bash
# Navigation: Verify screens in navigation structure
grep -rE "Screen|createStackNavigator|createBottomTabNavigator|NavigationContainer" src/ --include="*.tsx" --include="*.ts" 2>/dev/null

# Deep Links: Verify linking configuration
grep -rE "linking:|prefixes:|config:" src/ --include="*.tsx" --include="*.ts" 2>/dev/null

# iOS: Verify URL schemes in Info.plist
grep -rE "CFBundleURLSchemes" ios/ --include="*.plist" 2>/dev/null

# Android: Verify intent filters in manifest
grep -rE "intent-filter|android:scheme" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Native Modules: Verify linked properly
npx react-native config 2>&1 | grep -E "dependencies|Missing"

# Metro Bundle: Verify JS bundle builds
npx react-native bundle --entry-file index.js --platform ios --dev false --bundle-output /tmp/test.bundle 2>&1 | tail -5

# iOS Build Test
npx react-native run-ios --simulator="iPhone 15" 2>&1 | grep -E "success|error|BUILD"
# OR
cd ios && xcodebuild -workspace *.xcworkspace -scheme [SCHEME] build 2>&1 | tail -5

# Android Build Test
npx react-native run-android 2>&1 | grep -E "BUILD SUCCESSFUL|BUILD FAILED"
# OR
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

**React Native Wiring Checklist:**
- [ ] All screens registered in navigation container
- [ ] Tab/drawer navigation updated for new features
- [ ] Deep linking config includes new routes
- [ ] iOS Info.plist has URL schemes (if deep links)
- [ ] Android manifest has intent filters (if deep links)
- [ ] Native modules linked (pod install + gradle sync)
- [ ] Metro bundler builds without errors
- [ ] iOS simulator build succeeds
- [ ] Android emulator build succeeds
- [ ] Environment variables in .env (if using react-native-config)

**React Native Tool Availability Handling:**
```bash
# Check for RN CLI
if ! command -v npx &> /dev/null; then
    echo "WARN: npx not available - skipping RN build verification"
fi

# Check for iOS tools (macOS only)
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "INFO: iOS verification skipped (not on macOS)"
fi
```

---

##### Flutter Integration (Both Platforms)

```bash
# Navigation: Verify routes defined
grep -rE "MaterialPageRoute|GoRoute|routes:|onGenerateRoute" lib/ --include="*.dart" 2>/dev/null

# Deep Links: Verify GoRouter or Navigator 2.0 deep link handling
grep -rE "GoRouter|redirect:|onDeepLink|uriLinkStream" lib/ --include="*.dart" 2>/dev/null

# iOS: Verify URL schemes
grep -rE "CFBundleURLSchemes" ios/ --include="*.plist" 2>/dev/null

# Android: Verify intent filters
grep -rE "intent-filter|android:scheme" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Permissions: iOS Info.plist
grep -rE "NS.*UsageDescription" ios/ --include="*.plist" 2>/dev/null

# Permissions: Android manifest
grep -rE "uses-permission" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Analyze: Check for issues
flutter analyze 2>&1 | tail -20

# Build iOS (macOS only)
flutter build ios --debug --no-codesign 2>&1 | grep -E "Built|Error"

# Build Android
flutter build apk --debug 2>&1 | grep -E "Built|Error"

# Test
flutter test 2>&1 | tail -10
```

**Flutter Wiring Checklist:**
- [ ] All routes registered in MaterialApp/GoRouter
- [ ] Bottom navigation/drawer includes new features
- [ ] Deep link routes configured (if applicable)
- [ ] iOS URL schemes in Info.plist (if deep links)
- [ ] Android intent filters in manifest (if deep links)
- [ ] iOS permission descriptions in Info.plist
- [ ] Android permissions in manifest
- [ ] `flutter analyze` passes with no errors
- [ ] iOS build succeeds (--no-codesign for CI)
- [ ] Android APK build succeeds
- [ ] Pubspec.yaml has all required dependencies

**Flutter Tool Availability Handling:**
```bash
# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "WARN: flutter not available - skipping Flutter verification"
    echo "Install Flutter: https://docs.flutter.dev/get-started/install"
fi

# Check Flutter doctor
flutter doctor --android-licenses 2>&1 | grep -E "licenses accepted|error"
```

---

##### Graceful Degradation (All Platforms)

When verification tools are unavailable:

1. **Log the skip**: `echo "WARN: [tool] not available - verification skipped"`
2. **Document manual steps**: Add to completion report what needs manual verification
3. **Do NOT fail the feature**: Missing tools = deferred verification, not blocking failure
4. **Create follow-up task**: If build tools missing, note "Verify build on CI" as pending item

**Example Graceful Output:**
```text
Integration Verification Results:
- [x] Navigation wiring: PASSED (grep found all routes)
- [ ] iOS build: SKIPPED (xcodebuild not available)
- [ ] Android build: SKIPPED (not on macOS/Linux with Android SDK)
- [x] Deep links: PASSED (URL schemes configured)

Manual verification required:
- Build and run on iOS simulator
- Build and run on Android emulator
```

---

**If ANY wiring check fails:**
1. Identify which task should have done the wiring
2. Create a fix task or update the incomplete task
3. Do NOT mark feature complete until wiring is verified

#### 8.2 Final Verification

1. **Task Verification**:
   - All verification commands passed
   - All acceptance criteria met
   - 100% task completion

2. **Update index.md**:
   - Set phase to "Complete"
   - Final task counts

3. **Report Summary**:
   - Total tasks completed
   - Total time (if tracked)
   - Any skipped/blocked tasks
   - Integration verification status
   - Feature ready for review

### 9. Registry Sync — On Exit (MANDATORY)

> ⛔ **Do NOT begin Phase 9 until all tasks in Phases 1–8 are marked `DONE` in `index.md`.** Do NOT read `plan.md` or `registry.yaml` during any task in Phases 1–8 — the Context Pinning exception below is scoped to Phase 9 only and does not activate until every preceding task is complete.

**Per Constitution Article IX, Directive 7 "Protocol — On Exit"** — feature-level registry sync is required after every successful implementation. This is what keeps the registry accurate as the codebase evolves; without it, the registry freezes at plan time and drifts over subsequent features.

This step satisfies the "On Exit" obligation for the implement phase. It runs ONCE at feature completion, not per-task. Task-loop momentum is preserved.

**Exception to Context Pinning**: this phase is the ONLY implement-phase operation permitted to read `plan.md` — specifically to extract the registry-relevant decisions recorded during planning. Scan only the Tech Stack / Decisions sections; do NOT re-read requirements or specs. This exception exists because registry sync is definitionally a cross-task operation and cannot be self-contained in a single task file.

#### 9.1 Scan the implementation for new project-wide patterns

Review the completed work for decisions that APPLY PROJECT-WIDE (not feature-specific). Signals to look for:

| Signal in code/config | Registry candidate |
|----------------------|--------------------|
| Every query filters by `tenant_id` / `org_id` | `database.tenancy_model = shared_db_tenant_id` |
| New ORM / data-access pattern used consistently | `backend.orm`, `code_patterns.data_access` |
| New auth middleware or JWT pattern | `backend.auth_method`, `backend.auth_pattern` |
| New logging format (structured JSON, correlation IDs) | `error_handling.logging_format`, `error_handling.correlation_header` |
| New error-response envelope adopted | `api.error_format`, `api.response_envelope` |
| New testing framework / helpers introduced | `testing.unit_framework`, `testing.integration_framework`, `testing.mocking` |
| New rate-limit / caching middleware | `api.rate_limiting`, `backend.cache` |
| New migration tool adopted | `database.migration_strategy` |
| New secret-management pattern | `infrastructure.secrets` |
| New CI workflow added | `infrastructure.ci_cd`, `infrastructure.deployment_strategy` |
| Consistent directory/file naming across new code | `conventions.files`, `conventions.variables` |

Compare each signal against the current registry (read `specs/_defaults/registry.yaml`). A signal is a CANDIDATE if:
- Its registry field is `null` OR
- Its registry field has a different value AND the code legitimately deviates from it (this is a deviation-documentation case, not a registry update)

Filter out feature-specific details. If something was true only for this feature, it does NOT belong in the registry.

#### 9.2 Present candidates for HITL confirmation

If there are no candidates, skip to 9.4 and report "registry sync: no new candidates."

Otherwise, present a single table:

```
Post-implementation registry sync — candidates:

┌────────────────────────────────┬────────────────────────┬──────────────────────────────────────┐
│ Registry Field                 │ Proposed Value         │ Evidence                             │
├────────────────────────────────┼────────────────────────┼──────────────────────────────────────┤
│ database.tenancy_model         │ shared_db_tenant_id    │ 7 queries in src/users/ filter tid   │
│ error_handling.logging_format  │ structured             │ logger.ts switched to pino JSON      │
│ api.error_format               │ rfc7807                │ All new endpoints return Problem+JSON│
│ testing.integration_framework  │ supertest              │ Added in T-020, used by 4 tests      │
└────────────────────────────────┴────────────────────────┴──────────────────────────────────────┘
```

Use `AskUserQuestion` with these choices:

- **Add all to registry** — accept every candidate as shown
- **Select which to add** — user lists specific row numbers
- **Skip — keep feature-specific** — mark everything as feature-scoped, no registry update

For each accepted candidate, verify the proposed value with the user if any ambiguity exists. Allow `custom: <value>` as an override per row.

#### 9.3 Atomic write + audit trail

For every accepted candidate, perform an atomic update:

1. Read current `specs/_defaults/registry.yaml`
2. Merge accepted values in memory (do NOT touch fields not in the candidate set)
3. Update metadata: `last_updated: YYYY-MM-DD`, `last_updated_by: human`, append the current feature slug to `applied_to`
4. Write to `registry.yaml.tmp`, verify it is well-formed (re-read and check for YAML syntax errors), then write `registry.yaml` from the same content and delete `registry.yaml.tmp` (AI agents may not have a rename tool; explicit write + delete achieves the same atomicity guarantee)
5. Append to `specs/_defaults/changelog.md`:

```markdown
## [YYYY-MM-DD] — Registry sync after implementing <feature-slug>

- **Changed**: `database.tenancy_model`: null → `shared_db_tenant_id`
  - **Why**: 7 queries in src/users/ filter by tenant_id; pattern is project-wide
  - **Source**: /atomicspec.implement Phase 9 sync (feature: 001-user-onboarding)
  - **Approved by**: Human (Add all, Phase 9.2)
```

#### 9.4 Report

Final summary to the user:

```
Registry sync complete.
  Candidates detected: 4
  Added to registry: 3
  Skipped (feature-specific): 1
  Registry file: specs/_defaults/registry.yaml (last_updated: 2026-04-24)
  Audit entry: specs/_defaults/changelog.md
```

If the user had the registry gate overridden via `ATOMIC_SPEC_NO_REGISTRY=1` at task-gate time, remind them: "registry override was active; consider running /atomicspec.registry to create the registry before the next feature."

### 10. Reverse-Traceability Verification (v0.2+, MANDATORY)

> ⛔ **This phase runs AFTER Phase 9 has completed.** Like Phase 9, it operates on the closed feature state — every task in Phases 1–8 must be marked `DONE` in `index.md`, AND Phase 9's registry writes (to `specs/_defaults/registry.yaml` + `specs/_defaults/changelog.md`) have already landed. Those writes are exempt from the orphan check via the `specs/*` rule and will not surface as findings. Phase 10 is a **feature-exit gate, not a per-task operation**, so Directive 8 (Self-Contained Tasks) does not apply.

**Per Constitution Article IX, Directive 7 v0.2 amendment** — the "Docker without asking" failure mode (silently creating structural files like `docker-compose.yml`, `Dockerfile`, or CI workflow files that no task required) is a Directive 7 violation. This phase catches it after the fact, *even when the in-phase AskUserQuestion gate was missed*.

#### 10.1 Run the check

Execute `scripts/bash/check-traceability.sh` (or `scripts/powershell/check-traceability.ps1` on Windows). The script:

1. Computes the merge-base of the current feature branch with `main` (or `master`, with `HEAD~1` fallback for spike branches).
2. Lists every file changed since the merge-base (`git diff --name-only`) plus any uncommitted changes (`git status --porcelain`).
3. For each changed file, skips exempt patterns (`specs/`, `.specify/`, `.claude/`, `.github/`, `memory/`, `CHANGELOG.md`, `README.md`, lockfiles).
4. For each remaining file, searches `<FEATURE_DIR>/traceability.md` for the file path or basename.
5. Files not found are reported as **orphans**.

The script defaults to **warn-only** on v0.2.0 (consumer projects get one release cycle to clean up legacy orphans). Pass `--enforce` (bash) or `-Enforce` (PowerShell) to make orphans a hard failure. This will become the default in v0.2.1.

#### 10.2 Handle orphans

If the script reports orphan files, follow this flowchart for each:

| Orphan looks like | Action |
|---|---|
| Structural config (`docker-compose.yml`, `Dockerfile`, `.github/workflows/*`, `vercel.json`) | **The AI MUST NOT auto-decide.** This is a Directive 7 v0.2 amendment violation in retrospect. **Always escalate via `AskUserQuestion`** with the three options: (a) delete it and re-do the relevant task with the missing AskUserQuestion, (b) amend `traceability.md` to map it to an existing task IF the user retroactively approves the structural choice, (c) report as a bug in the task file (Phase 8 quality gate failure). Let the user pick. |
| Application code that maps to a task but was named differently | Amend `traceability.md` to reference the new path. This is bookkeeping, not a real orphan. Confirm the rename via AskUserQuestion if uncertain. |
| Generated / scaffolded files (db migrations, build artifacts) | Add the pattern to the exempt list in `scripts/bash/check-traceability.sh` (`is_exempt()` function) AND `scripts/powershell/check-traceability.ps1` (`Test-IsExempt`). Document the addition in the next CHANGELOG. Always confirm via AskUserQuestion before extending the exempt list. |
| Files the user manually created mid-implement | Outside the scope of the gate — annotate in the report and move on. The gate covers AI-created files. |
| File was DELETED during the feature (showed up via `git diff` because it's no longer present) | Verify the deletion was intentional and corresponds to a cleanup task. If so, annotate in `traceability.md` with `[deleted]` next to the previous mapping row. |

#### 10.3 Report

Final summary section to append to the implement-phase output:

```
Reverse-traceability check (v0.2):
  Total files changed:        N
  Mapped to traceability.md:  M
  Exempt (framework/spec):    K
  Orphans:                    P
  Mode:                       warn-only | enforced
  Status:                     PASS | WARN | BLOCK
```

If status is BLOCK (orphans found AND --enforce): the implement command should NOT mark itself complete. Surface the orphan list and the per-orphan flowchart from §10.2 to the user, then halt.

If status is WARN (orphans found, warn-only): print the list and continue to the final "feature ready for review" report. The orphans become a v0.2.1 backlog item.

## Context Pinning Reminder

**During task execution (Phases 1–8), you may ONLY read**:
- `index.md` - Navigation and status
- Current `T-XXX-[name].md` - Active task details
- `traceability.md` - To update completion status

**FORBIDDEN during task execution**:
- Reading `plan.md` during implementation
- Reading `spec.md` during implementation
- Reading task files other than the current one
- Making architectural decisions not in the task file

**Carved exceptions — Phase 9 (Registry Sync on Exit) and Phase 10 (Reverse-Traceability Verification)**:

- **Phase 9** may read `plan.md` to extract the registry-relevant decisions recorded during planning, and may read `specs/_defaults/registry.yaml` to compute the diff. Phase 9 must NOT read `spec.md` or any task file other than those already completed.
- **Phase 10** may run git introspection commands (`git diff --name-only`, `git status --porcelain`, `git merge-base`) AND may write to `traceability.md` to record orphan-resolution annotations per §10.2. Phase 10 does NOT read `plan.md` or `spec.md`.

Both exceptions are scoped to their respective phase only — they exist because exit-time verification is inherently cross-task and cannot be self-contained inside one task file.

If during Phases 1–8 you need information not in the current task file, the task file is incomplete. Report this as a task quality issue rather than reading forbidden files.
