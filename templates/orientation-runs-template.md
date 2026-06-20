# Orientation Runs: [FEATURE NAME]

**Purpose**: Append-only log of every `/atomicspec.implement` Phase 0 (Orientation) run for this feature. Required by Constitution Article IX, Directive 9 — absence of this file when implement runs fails the Phase 0 gate.

Each Phase 0 run appends a new `## Run <ISO 8601 UTC timestamp>` block containing the JSON output of `stamp-lifecycle status` for every artifact in this feature folder, plus the resume decision the user confirmed.

<!--
  Script-managed by scripts/{bash,powershell}/stamp-lifecycle.{sh,ps1}.
  AIs MUST NOT hand-edit run blocks — append-only via the script.

  Structural invariant:
  - Each run is exactly one `## Run <ISO-8601-UTC>` block at H2.
  - Children: `### Outcome`, `### Artifacts`, `### Decision` at H3.
  - Newest run at the top (reverse chronological).
  - Never modify a prior run.

  Why this file is separate from traceability.md:
  - traceability.md hosts requirement coverage + the Lifecycle Ledger.
  - Phase 0 evidence is a high-volume append-only log; if it lived in
    traceability.md, after ~20 implement runs the matrix would drown in JSON.
  - Splitting keeps both files single-purpose and readable.
-->

---

## Run [ISO 8601 UTC TIMESTAMP]

### Outcome

<!--
  One of: clean | stale | conflict (Directive 9 §Outcomes).
  - clean: every artifact returns `closed` or `legacy_closed`. Proceed to Phase 1.
  - stale: at least one artifact has an open block older than the registry's
           `lifecycle.stale_threshold` (default 7 days). Informational only.
  - conflict: at least one artifact has an open block newer than the threshold.
           Phase 0 STOPS and presents options to the user.
-->

[clean | stale | conflict]

### Artifacts

<!--
  JSON output of `stamp-lifecycle status --artifact <path>` for every artifact
  inspected this run. Fenced code block, one JSON object per line.
-->

```json
{"artifact":"spec.md","state":"closed","authoring":{"start":"...","end":"...","by":"claude:opus-4-7"}}
{"artifact":"plan.md","state":"closed","authoring":{"start":"...","end":"...","by":"claude:opus-4-7"}}
{"artifact":"tasks/T-001-setup.md","state":"done","authoring":{"start":"...","end":"...","by":"claude:opus-4-7"},"implementation":{"start":"...","end":"...","by":"codex"}}
```

### Decision

<!--
  Required only when outcome is `conflict` or `stale`. For `clean` outcomes,
  write "Proceeded to Phase 1." If user was prompted, record the choice and
  rationale.
-->

[Proceeded to Phase 1. | Resumed T-XXX from prior session. | Discarded prior work on T-XXX (redo). | User aborted.]
