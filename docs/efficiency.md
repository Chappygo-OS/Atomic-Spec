# Efficiency — advisory model-tier routing (v0.4+)

Atomic Spec v0.4 introduces **advisory** model-tier routing: consumer projects
can pin a coordinator model for coordination-heavy turns, an implementer model
for actual code generation, and a HITL model for human-in-the-loop checkpoints.
This is the config surface. Per-feature token measurement lands in v0.4.1.

> **Advisor is OFF by default.** A fresh `atomicspec init` writes
> `registry.efficiency.advisor_enabled: false`. Consumer projects on v0.3 see
> byte-for-byte identical behavior after upgrade until they explicitly flip it.

---

## The three tiers

| Phase | Default model | Typical turns |
|-------|---------------|---------------|
| `coordinator` | `claude-haiku-4-5` | Phase 0 orientation, task selection from `index.md`, gate criteria evaluation, stamp-lifecycle writes, traceability updates |
| `implementer` | `claude-sonnet-4-6` | Task-body work, code generation, verification loop |
| `hitl` | `claude-opus-4-7` | Directive 6 checkpoints (Phase 0.5 / 0.7 / 0.8 / 0.9 in `/atomicspec.plan`), ambiguous decisions, adversarial review passes |

The tier names are stable across providers. The **values** are provider-native
model IDs — you replace them via `/atomicspec.registry` for OpenAI, Google, or
any other provider. Cursor, Windsurf, Copilot, and Gemini CLI have no per-turn
model selection API, so the tier map applies advisorily to them without
mid-run switching.

---

## Where the config lives

```yaml
# specs/_defaults/registry.yaml
efficiency:
  model_tiers:
    coordinator: claude-haiku-4-5
    implementer: claude-sonnet-4-6
    hitl:        claude-opus-4-7
  advisor_enabled: false     # v0.4 default; v0.4.1 flips to true
  snapshot_recorded: null    # ISO-8601 of last `atomicspec cost snapshot`
```

Amend via `/atomicspec.registry` — the normal Directive 7 HITL protocol
applies. Direct edits work too, but the AI is required to raise
`AskUserQuestion` before committing to any structural change.

---

## Enabling the advisor

1. Open `specs/_defaults/registry.yaml`, find the `efficiency:` block.
2. Set `advisor_enabled: true`.
3. (Optional) Replace `model_tiers.*` with provider-native IDs if you're not
   on Anthropic.
4. Run any `/atomicspec.*` command. The resolved tier now appears in
   orientation evidence.

---

## What `select-model` does

```bash
$ atomicspec select-model --phase coordinator
claude-haiku-4-5
$ atomicspec select-model --phase implementer
claude-sonnet-4-6
```

When `advisor_enabled: false`, both print empty:

```bash
$ atomicspec select-model --phase coordinator
$
```

Command templates call it from bash / PowerShell blocks and record the
result in orientation evidence. Agents that support per-turn model selection
(Claude Code's subagent `Task` tool) MAY honor the hint; others record it and
continue on their default model.

Exit code is always 0 — bash / PowerShell callers branch on `[ -n "$MODEL" ]`
rather than exit code, keeping the empty-model path trivial.

---

## What `cost snapshot` does

```bash
$ atomicspec cost snapshot \
    --amount 1.50 \
    --provider anthropic \
    --source paste \
    --feature 042 \
    --tokens 45000 \
    --note "manual paste from Anthropic Console"
```

Writes `.specify/efficiency-snapshots/2026-08-21-034512123456-feature-042.md`
with YAML frontmatter (numeric fields) + prose summary. Atomic-write pattern
(`.tmp` → rename). Advisory only: not per-turn measurement, not billing-grade.

**Snapshot file naming and retention**:

- Filename format: `YYYY-MM-DD-HHMMSSuuuuuu-<scope>.md` (UTC date + time +
  microseconds + scope). The microsecond suffix is what prevents two
  same-second calls (e.g., a shell loop importing multiple lines) from
  overwriting each other.
- Scope is `feature-<id>` when `--feature` is passed, `adhoc` otherwise.
- Every `atomicspec cost snapshot` invocation writes one new file. **The
  framework never deletes snapshots.** If you want retention, roll them
  off yourself (e.g., delete files older than N days). A future
  `atomicspec efficiency prune` command may formalize this once v0.4.1
  measurement lands and snapshot volume becomes a real concern.
- The report reads snapshots by parsing YAML frontmatter, then sorting by
  the `recorded_at` field. Ordering is precise even when many snapshots
  share the same date.

**Why manual paste in v0.4?** Because every automated approach we evaluated
had P0 failure modes we weren't willing to ship. See the honest disclosures in
`CHANGELOG.md` v0.4.0. v0.4.1 lands hook-based auto-capture for Claude Code and
CSV import for Anthropic API-key users, at which point manual paste becomes a
fallback rather than the default.

**Two directories, not one**:

- `.specify/efficiency-snapshots/` (v0.4) — human-entered single-number
  cost snapshots via `atomicspec cost snapshot`. Advisory. Any provider.
- `.specify/efficiency-baselines/` (v0.4.1) — hook-captured per-feature
  token/cost baselines from `atomicspec baseline record`. Claude Code
  today; Codex CLI and Anthropic Console CSV import shortly after. Not
  present until v0.4.1.

The two are separate on purpose: snapshots are for calibration and manual
reconciliation; baselines are the falsifiability evidence that gates the
advisor-default flip.

---

## What `efficiency report --advisory` does

```bash
$ atomicspec efficiency report --advisory
```

Prints:

1. A tier resolution table (`Phase | Advisor | Configured model | Reason`) with
   a header labeled "advisory only, measurement in v0.4.1" verbatim.
2. Recent cost snapshots table if any exist in `.specify/efficiency-snapshots/`.

The `--advisory` flag is required in v0.4. Running without it prints a note
and exits 1. This is deliberate: the flag is a machine-readable marker that
you understand the output is not authoritative billing evidence.

`--feature NNN` filters the snapshot listing. `--limit N` caps the row count
(default 5).

---

## Provider-portability posture

| Provider | Coordinator | Implementer | HITL | Measurement path (v0.4.1) |
|----------|-------------|-------------|------|---------------------------|
| Anthropic (Claude Code) | Haiku 4.5 | Sonnet 4.6 | Opus 4.7 | Claude Code hook API |
| Anthropic via API key | Haiku 4.5 | Sonnet 4.6 | Opus 4.7 | Anthropic Console CSV import |
| Anthropic via Bedrock | Same model IDs | Same | Same | CSV via Bedrock billing export |
| OpenAI / Codex CLI | `gpt-5-mini` | `gpt-5` | `gpt-5` high-reasoning | Codex CLI JSONL adapter (v0.4.1) |
| Google Gemini / Antigravity | Flash | Pro | Pro (thinking-high) | No path in v0.4.x |
| Cursor / Windsurf / Copilot | Same one model | Same | Same | No path in v0.4.x |
| Single-model (Ollama, vLLM) | Same one model | Same | Same | Not applicable |
| Aggregators (OpenRouter, Portkey, LiteLLM, AgentRouter) | Provider-manifest keying in v0.5 | — | — | v0.5+ |

Consumers on providers without a measurement path see the tier config work as
advisory prose in orientation evidence. Nothing silently claims savings for
them.

---

## Naming discipline

The v0.4 orientation-adjacent surface is called **"Phase 1 Prelude — Efficiency
Hint,"** never *"Phase 0.5."* Positioning as a prelude to Phase 1 (rather than
a sibling to Phase 0) keeps the advisory-only posture consistent with the name
and avoids borrowing Directive 9's blocking authority. Directive 9 remains a
strictly narrower Orientation Read Surface; the prelude is advisory.

`registry.efficiency.model_tiers` is the **phase-tier** concept — which model
runs which kind of turn. It is semantically distinct from the per-subagent
`model:` frontmatter hint in `.specify/subagents/**/*.md`, which pins a model
for one named subagent regardless of phase. Don't collapse the two.

---

## Roadmap

- **v0.4.0 (current)**: config surface + advisory reporting.
- **v0.4.1**: `atomicspec baseline record --feature NNN` via Claude Code
  hook API (`Stop` / `PostToolUse` / `SessionEnd`) + Anthropic Console CSV
  importer + Codex CLI JSONL adapter (separate flag). Evidence bar for
  advisor default flip: ≥60% of tracked consumer projects show non-empty
  `.specify/efficiency-baselines/` across ≥2 providers; measured cost
  reduction ≥15% median across baselined features; zero P0 governance
  regressions for 4 weeks. Advisor default flips to `true` behind this
  bar.
- **v0.5**: only if v0.4.1 evidence justifies additional complexity —
  per-turn hint grammar in command templates, provider adapter layer with
  contract tests, aggregator-transport manifest keying.
- **Sunset clause**: if the v0.4 → v0.4.1 evidence bar is unmet by the
  v0.5 cut date, the efficiency layer freezes at v0.4, `advisor_enabled`
  is marked `@deprecated` in Article IX, and removal is scheduled for
  v0.7. Discipline before ambition.

---

## Frequently asked

**"Why is measurement so hard?"**
Atomic Spec is a template distributor — its CLI is not in the LLM request
path. Every observability platform (Helicone, Langfuse, LangSmith, Portkey)
either proxies the request or hooks the SDK; a template distributor cannot
do either. The two viable paths are (a) provider hook APIs (Claude Code
exposes these; other agents don't) and (b) provider Admin API / CSV
exports (Anthropic Console, OpenAI Usage — API-key users only). Both land
in v0.4.1.

**"Can I just have the agent write its own token counts into an evidence file?"**
No. Anthropic's own docs explicitly warn that `total_cost_usd` and related
client-side estimates *"are not authoritative billing data. Do not bill end
users or trigger financial decisions from these fields."* Cache-read
tokens are invisible to a model that didn't create the cache. This was
evaluated and rejected as an anti-pattern.

**"What if I run Claude Code and want cost tracking today?"**
Use [`ccusage`](https://github.com/ryoppippi/ccusage) — it tails
`~/.claude/projects/**/*.jsonl` and produces cost reports. Atomic Spec
v0.4.1 will build the same capability on Claude Code's blessed hook API
(more stable than JSONL tailing) plus feature-scoping metadata. Until
then, `atomicspec cost snapshot --source jsonl --amount <ccusage_total>`
brings a ccusage-derived number into Atomic Spec's snapshot log.
