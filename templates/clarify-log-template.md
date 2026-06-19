# Clarification Log: [FEATURE NAME]

**Purpose**: Append-only record of clarification sessions on `spec.md`. Each session is one stamp block plus a summary of what was resolved.

`spec.md` is the source of truth for the spec itself; this file records the **history** of how it was clarified. Stamping `spec.md` multiple times would corrupt the "one artifact = one authoring lifecycle" invariant (Article IX, Directive 9) — so clarify writes here instead.

<!--
  Created on first run of /atomicspec.clarify.

  STRUCTURAL INVARIANT (so Claude / Codex / Gemini produce identical shape):
  - Each session is exactly ONE `## Session <ISO-8601-UTC>` block at H2.
  - Children: `### Lifecycle Markers`, `### Resolved`, `### Spec.md edits`,
    `### Open questions` at H3.
  - Do NOT nest sessions. Do NOT introduce a `## Sessions` parent heading.
  - Newest session appears at the TOP of the file (reverse chronological).

  PARSER NOTE: `stamp-lifecycle status` matches `^#{2,6}\s+Lifecycle Markers\s*$`
  (any heading depth H2-H6). The H3 used INSIDE session blocks here is
  intentional and parser-compatible — do not normalize to H2.

  TEMPLATE-VS-REAL: The block below is a TEMPLATE SKELETON, not a real session.
  On FIRST clarify run, REPLACE the `[ISO 8601 UTC TIMESTAMP]` placeholder and
  fill the body in place. On SUBSEQUENT runs, APPEND a new `## Session <ts>`
  block ABOVE the previous one (most-recent-first) and leave prior sessions
  untouched.

  Script-managed: do NOT hand-edit the Lifecycle Markers sections; the body
  content under "Resolved", "Spec.md edits", and "Open questions" is filled
  by the AI during clarify.
-->

---

## Session [ISO 8601 UTC TIMESTAMP]

### Lifecycle Markers

<!--
  Script-managed. Populated by scripts/{bash,powershell}/stamp-lifecycle.{sh,ps1}
  during this clarify session. One stamp per session; sessions never re-stamp.
  H3 heading depth is intentional (nested inside the `## Session` H2) and
  parser-compatible — stamp-lifecycle matches `^#{2,6}\s+Lifecycle Markers\s*$`.
-->

### Resolved

<!--
  Bullet list of ambiguities resolved this session. Format:
  - **FR-XXX / US-XXX / area**: ambiguous "..." → clarified to "..."
-->

- [resolved item 1]
- [resolved item 2]

### Spec.md edits

<!--
  Bullet list of which sections of spec.md were amended this session.
  This is a pointer, not a duplicate of the content. Read spec.md for the
  actual text. Do NOT copy spec content here.
-->

- §[section]: [one-line summary of change]

### Open questions (carried forward)

<!--
  Anything that did NOT get resolved this session. If empty, write "None."
  These items become candidate inputs to the next clarify session or to plan.md.
-->

- None
