---
description: Analyze competitors following Station 03 discovery procedures. Creates structured competitive intelligence for use in downstream planning.
handoffs:
  - label: Create Specification
    agent: atomicspec.specify
    prompt: Use the competitive analysis to inform the feature spec
  - label: Create Plan
    agent: atomicspec.plan
    prompt: Use competitive insights to inform technical decisions
scripts:
  sh: scripts/bash/check-prerequisites.sh --json
  ps: scripts/powershell/check-prerequisites.ps1 -Json
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

This command creates structured competitive analysis following Station 03 (Discovery) procedures. The output is **optional** for downstream commands - if the user rejects it, delete it entirely so future commands proceed without competitive context.

## Phase 1: Setup & User Research Check

1. **Parse the script output** to get FEATURE_DIR and other paths.

2. **Create the competitive analysis directory structure**:

   ```
   FEATURE_DIR/competitive-analysis/
   ├── summary.md           # Main reference document (created at end)
   └── competitors/         # Individual competitor analyses
   ```

3. **Ask user about existing research**:

   ```
   ══════════════════════════════════════════════════════════════
   📊 COMPETITIVE ANALYSIS - Setup
   ══════════════════════════════════════════════════════════════

   Before I begin researching competitors, do you have any existing
   competitive research, market analysis, or internal documents to share?

   If yes:
   - Create a folder: competitive-analysis/user-research/
   - Add your files there (PDFs, docs, notes, screenshots, etc.)
   - Let me know when ready

   If no:
   - Reply "proceed" and I'll research from scratch

   **Why this matters**: Your existing research saves time and may
   contain insights not available publicly (sales calls, demos, etc.)

   ══════════════════════════════════════════════════════════════
   ```

4. **If user provides materials**:
   - Create `competitive-analysis/user-research/` folder
   - Wait for user to add files
   - Read and analyze user-provided materials
   - Extract competitor names, pain points, and insights to inform research

## Phase 2: Define Search Frame

Following Station 03, Section 3.4.3 Step 1:

1. **Define the search frame** (with user input if available):

   ```markdown
   | Category | Description |
   |----------|-------------|
   | Primary category | [phrase ICP would search] |
   | Adjacent categories | [substitutes and alternatives] |
   | Manual substitutes | [spreadsheets, email, manual processes] |
   ```

2. **Build competitor list** (5-15 total):
   - Direct (5): Same ICP, same job
   - Adjacent (5): Same ICP, different angle
   - Substitutes (2-5): Generic tools, manual workflows

3. **Present list to user for validation**:

   ```
   I've identified these competitors to analyze:

   **Direct:** [list]
   **Adjacent:** [list]
   **Substitutes:** [list]

   Want to add, remove, or modify this list?
   ```

## Phase 3: Benchmark Each Competitor

For each competitor, create `competitors/[competitor-name].md` with:

### Per-Competitor Template (from Station 03)

```markdown
# Competitor Analysis: [Name]

**Category**: Direct / Adjacent / Substitute
**Website**: [URL]
**Analyzed**: [DATE]

## Positioning (What They Promise)

- **Headline**: [their main claim]
- **Subheadline**: [supporting claim]
- **Proof points**:
  1. [number/compliance/integration claim]
  2. [...]
  3. [...]

## Time-to-Value (TTV) Path

- **First 3 actions after signup**:
  1. [action]
  2. [action]
  3. [action]
- **Aha moment**: [what they push you toward first]
- **Estimated TTV**: [time from signup to first value]

## Packaging & Paywalls

- **Pricing model**: [per seat / per org / per usage / per project]
- **Tier limits**:
  | Tier | Seats | Projects | Storage | Key Limits |
  |------|-------|----------|---------|------------|
  | Free | | | | |
  | Pro | | | | |
  | Enterprise | | | | |
- **Upgrade triggers**: [what forces payment]
- **Paywalled features**: [what's gated]

## Workflow & Roles

- **Team support**: [yes/no, details]
- **Permissions/RBAC**: [roles available]
- **Approvals/workflows**: [if any]
- **Audit logs**: [yes/no]
- **Org/workspace concepts**: [how they structure accounts]

## Integrations & Lock-in

- **Imports**: [what can be imported]
- **Exports**: [what can be exported]
- **API**: [public API? REST/GraphQL?]
- **Webhooks**: [available?]
- **Lock-in mechanisms**: [data structure dependencies]

## Trust Posture

- **Security page**: [exists? URL?]
- **Compliance claims**: [SOC2, ISO, GDPR, HIPAA, etc.]
- **Data hosting**: [regions, providers]

## Weak Points (from Reviews)

| Source | Complaint | Underlying Pain | Severity |
|--------|-----------|-----------------|----------|
| [G2/Capterra/etc] | [verbatim] | [actual pain] | [low/med/high] |

## Notes

[Additional observations]
```

## Phase 4: Mine User Pains

Collect pain statements from:
- App store reviews
- G2/Capterra/Trustpilot
- Community forums
- Support docs / known issues
- Feature request boards
- Competitor FAQ

For each pain, extract:

| Field | Description |
|-------|-------------|
| Complaint | Verbatim short phrase |
| Underlying pain | What actually hurts |
| Desired outcome | What they want |
| Who is affected | Buyer vs user |
| Frequency | low / medium / high |
| Severity | annoyance / workflow blocker / business risk |
| Source | Where found |

## Phase 5: Synthesize & Create Summary

Create `competitive-analysis/summary.md`:

```markdown
# Competitive Analysis Summary

**Feature**: [feature name]
**Analysis Date**: [DATE]
**Competitors Analyzed**: [count]

## Search Frame

| Category | Examples |
|----------|----------|
| Primary | [phrase ICP searches] |
| Adjacent | [alternatives] |
| Substitutes | [manual workflows] |

## Top 3 Recurring Pains

Pains with high frequency + high severity:

### Pain 1: [Name]
- **Complaint**: [verbatim]
- **Underlying pain**: [what actually hurts]
- **Desired outcome**: [what they want]
- **Frequency**: high
- **Severity**: [workflow blocker / business risk]
- **Sources**: [list]

### Pain 2: [Name]
[...]

### Pain 3: [Name]
[...]

## Top 3 Competitor Patterns

What everyone does (table stakes):

1. **Pattern**: [description]
2. **Pattern**: [description]
3. **Pattern**: [description]

## Paywall/Upgrade Triggers Summary

| Trigger | Competitors Using | Implications |
|---------|-------------------|--------------|
| [trigger] | [who] | [what it means] |

## Wedge Candidates

### Candidate A: [Name]
> For [ICP], we deliver [measurable outcome] by [unique mechanism], unlike [competitor pattern].

- **Ties to pain**: [which pain]
- **Feasibility**: [MVP-achievable?]
- **Differentiation**: [why unique]

### Candidate B: [Name]
[...]

### Candidate C: [Name]
[...]

## Recommended Wedge

**Selected**: [Candidate letter]

**Rationale**: [why this wedge]

| Dimension | Score (1-5) |
|-----------|-------------|
| Outcome magnitude | |
| Speed to MVP | |
| Differentiation strength | |
| Willingness to pay | |
| Operational risk | |

## Gate Checklist (Station 03)

- [ ] >= 5 direct competitors benchmarked
- [ ] >= 10 distinct user pain statements (with source + severity)
- [ ] Paywall/upgrade triggers summarized
- [ ] 2-3 wedge candidates written
- [ ] 1 recommended wedge selected
```

## Phase 6: Quality Check

Validate against Station 03.4.5 Gate Criteria:

1. **>= 5 direct competitors benchmarked**
2. **>= 10 distinct user pain statements** (with source + severity)
3. **Paywall/upgrade triggers summarized** across competitors
4. **2-3 wedge candidates written**
5. **1 recommended wedge selected**

If any gate fails, iterate to fill gaps before presenting to user.

## Phase 7: HITL - User Review

Present the summary to user:

```
══════════════════════════════════════════════════════════════
📊 COMPETITIVE ANALYSIS - Review
══════════════════════════════════════════════════════════════

I've completed the competitive analysis. Here's the summary:

[Show summary.md content or key highlights]

**Gate Status**:
- [x] 5+ competitors analyzed
- [x] 10+ pain statements captured
- [x] Paywall triggers documented
- [x] 3 wedge candidates identified
- [x] 1 recommended wedge selected

**Your options:**

1. "accept" - Keep this analysis for use in /atomicspec.plan and downstream
2. "revise: [instructions]" - I'll update based on your feedback
3. "reject" - Delete the entire competitive-analysis/ folder

**Important**: If you choose "reject", this analysis will be deleted.
Future commands (/atomicspec.plan, /atomicspec.tasks) will proceed WITHOUT
competitive context - they'll make decisions based on general knowledge
only. This is by design - no analysis means no competitive influence.

══════════════════════════════════════════════════════════════
```

## Phase 8: Handle User Response

- **"accept"** → Keep all files, report success
- **"revise: [instructions]"** → Update summary/competitors per user feedback, re-present
- **"reject"** → Delete entire `competitive-analysis/` folder, explain mechanism:

  ```
  ══════════════════════════════════════════════════════════════
  ✓ Competitive analysis deleted.

  **What this means for future commands:**

  - /atomicspec.plan will make tech decisions based on general knowledge
  - /atomicspec.tasks will not reference competitor patterns
  - No wedge/positioning guidance will be available

  This is intentional - you chose not to use competitive analysis,
  so downstream commands won't assume competitive context exists.

  You can always re-run /atomicspec.AnalyzeCompetitors later if needed.
  ══════════════════════════════════════════════════════════════
  ```

## Key Rules

- Follow Station 03 procedures exactly
- Create individual competitor files for traceability
- Summary must pass all gate criteria before user review
- If user rejects, DELETE everything - no partial state
- Downstream commands check for `competitive-analysis/summary.md` existence
