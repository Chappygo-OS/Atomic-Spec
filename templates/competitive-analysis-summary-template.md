# Competitive Analysis Summary

**Feature**: [FEATURE_NAME]
**Analysis Date**: [DATE]
**Competitors Analyzed**: [COUNT]
**Status**: [DRAFT | APPROVED | REJECTED]

<!--
  This document summarizes competitive intelligence gathered via /atomicspec.AnalyzeCompetitors.

  DOWNSTREAM USAGE:
  - /atomicspec.plan checks for this file's existence
  - If present, AI uses wedge/patterns to inform tech decisions
  - If absent (user rejected or never ran), AI proceeds without competitive context

  GATE CRITERIA (Station 03.4.5):
  - >= 5 direct competitors benchmarked
  - >= 10 distinct user pain statements (with source + severity)
  - Paywall/upgrade triggers summarized
  - 2-3 wedge candidates written
  - 1 recommended wedge selected
-->

## Search Frame

| Category | Examples |
|----------|----------|
| Primary | [phrase ICP would search - e.g., "construction site reporting SaaS"] |
| Adjacent | [alternatives - e.g., "field service management", "project documentation"] |
| Substitutes | [manual workflows - e.g., "Google Drive + templates + WhatsApp"] |

## Competitors Analyzed

| Name | Category | Key Differentiator |
|------|----------|-------------------|
| [Competitor 1] | Direct | [one-liner] |
| [Competitor 2] | Direct | [one-liner] |
| [Competitor 3] | Adjacent | [one-liner] |
| ... | ... | ... |

_Full details in `competitors/[name].md` files._

---

## Top 3 Recurring Pains

_Pains with high frequency + high severity across multiple sources._

### Pain 1: [Name/Label]

- **Complaint (verbatim)**: "[exact quote from review/forum]"
- **Underlying pain**: [what actually hurts]
- **Desired outcome**: [what they want instead]
- **Who is affected**: [Buyer / User / Both]
- **Frequency**: High
- **Severity**: [Workflow Blocker / Business Risk]
- **Sources**: [G2, Capterra, Reddit, etc.]

### Pain 2: [Name/Label]

- **Complaint (verbatim)**: "[exact quote]"
- **Underlying pain**: [what actually hurts]
- **Desired outcome**: [what they want]
- **Who is affected**: [Buyer / User]
- **Frequency**: High
- **Severity**: [severity]
- **Sources**: [sources]

### Pain 3: [Name/Label]

- **Complaint (verbatim)**: "[exact quote]"
- **Underlying pain**: [what actually hurts]
- **Desired outcome**: [what they want]
- **Who is affected**: [Buyer / User]
- **Frequency**: High
- **Severity**: [severity]
- **Sources**: [sources]

---

## Top 3 Competitor Patterns

_What everyone does (table stakes) - you must match or consciously decline._

1. **[Pattern Name]**: [Description of what competitors do]
   - _Used by_: [list competitors]
   - _Implication_: [what this means for our product]

2. **[Pattern Name]**: [Description]
   - _Used by_: [list]
   - _Implication_: [meaning]

3. **[Pattern Name]**: [Description]
   - _Used by_: [list]
   - _Implication_: [meaning]

---

## Paywall/Upgrade Triggers Summary

| Trigger | Competitors Using | How It Works | Implication for Us |
|---------|-------------------|--------------|-------------------|
| [Seat limits] | [Competitor A, B] | [Free up to 3, then paid] | [Consider similar model?] |
| [Storage caps] | [Competitor C, D] | [1GB free, upgrade for more] | [...] |
| [Feature gates] | [Competitor A, E] | [Reports in paid only] | [...] |
| [API access] | [Most] | [API only on Pro+] | [...] |

---

## Wedge Candidates

### Candidate A: [Name]

> For [ICP], we deliver [measurable outcome] by [unique mechanism], unlike [competitor pattern].

- **Ties to pain**: Pain #[N] - [name]
- **Proof points (MVP-achievable)**:
  1. [what we can ship]
  2. [what we can ship]
- **Feasibility**: [High / Medium / Low]
- **Differentiation**: [why competitors can't easily copy]
- **Risk**: [what could go wrong]

### Candidate B: [Name]

> For [ICP], we deliver [measurable outcome] by [unique mechanism], unlike [competitor pattern].

- **Ties to pain**: Pain #[N]
- **Proof points**:
  1. [...]
  2. [...]
- **Feasibility**: [...]
- **Differentiation**: [...]
- **Risk**: [...]

### Candidate C: [Name]

> For [ICP], we deliver [measurable outcome] by [unique mechanism], unlike [competitor pattern].

- **Ties to pain**: Pain #[N]
- **Proof points**:
  1. [...]
  2. [...]
- **Feasibility**: [...]
- **Differentiation**: [...]
- **Risk**: [...]

---

## Recommended Wedge

**Selected**: Candidate [A/B/C]

**Wedge Statement**:
> [Full wedge statement from selected candidate]

### Rubric Scores

| Dimension | Score (1-5) | Rationale |
|-----------|-------------|-----------|
| Outcome magnitude | [N] | [why] |
| Speed to MVP | [N] | [why] |
| Differentiation strength | [N] | [why] |
| Willingness to pay | [N] | [why] |
| Operational risk | [N] | [why] |
| **Total** | **[sum]** | |

### Why This Wedge

[2-3 sentences explaining why this wedge was selected over others]

### Non-Goals (Explicit)

_What we will NOT do in MVP, even if competitors do it:_

1. [Non-goal 1] - Reason: [why not]
2. [Non-goal 2] - Reason: [why not]

---

## Gate Checklist (Station 03.4.5)

- [ ] >= 5 direct competitors benchmarked
- [ ] >= 10 distinct user pain statements (with source + severity)
- [ ] Paywall/upgrade triggers summarized across competitors
- [ ] 2-3 wedge candidates written
- [ ] 1 recommended wedge selected with rubric scores

---

## Approval

**User Review Status**: [Pending / Approved / Rejected]
**Reviewed By**: [awaiting user]
**Review Date**: [timestamp]
**Notes**: [any user feedback or modifications requested]
