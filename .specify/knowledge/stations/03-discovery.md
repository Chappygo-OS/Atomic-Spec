# Station 03 — Discovery Line (SaaS): Procedures + Templates

## 3.1 Objective

Discovery produces evidence-backed direction quickly, with outputs that are directly usable in PRD and architecture:

- Who we build for (ICP)
- What job we solve (JTBD) and what outcomes matter
- Why we win first (wedge) and what we explicitly won't do
- What we measure (metrics + event plan)

Discovery is not a "research project". It is a risk-reduction station to prevent expensive rework later (data model changes, API churn, mis-priced plans, missing RBAC/limits/billing edge cases).

> **Default timebox (MVP SaaS):** 2-5 working days.

---

## 3.2 Owners

| Role | Responsibility |
|------|----------------|
| **Accountable** | PO |
| **Consulted** | TL (feasibility + implications), UX (flow implications) |
| **Informed** | Ops, Sec |

---

## 3.3 Inputs (Required)

- Project folder structure exists (`/01-discovery/` created)
- Rough one-paragraph problem statement (can be wrong)
- Initial hypothesis about buyer + user (can be wrong)

### Optional But Helpful Inputs

- A list of 10 target companies you want as customers
- Any existing sales conversations / notes

---

## 3.4 Station B — Market and Competitor Benchmark

### 3.4.1 Purpose

To avoid building in a vacuum by understanding:

- What customers already buy or hack together
- How competitors package value (tiers/limits)
- Where friction appears (onboarding, integration, permissions, reporting)
- What users complain about (pains), what they ask for (gaps), and what they tolerate

This station is about system-level comparison, not feature checklists.

### 3.4.2 Outputs You Want By The End

- A clear picture of how people currently solve the problem
- A "paywall map" (what's gated by plan) and "upgrade trigger map" (what forces upgrades)
- A list of pains that are repeated across multiple sources
- A credible wedge hypothesis

### 3.4.3 Procedure (Step-by-Step)

#### Step 1 — Define the Search Frame (30-45 min)

Write:

- **Primary category label** (the phrase an ICP would search)
- **Adjacent categories** (substitutes)
- **Manual substitutes** (spreadsheets, Notion, email, WhatsApp, PDFs)

**Example:**

| Category | Example |
|----------|---------|
| Primary | "construction site reporting SaaS" |
| Adjacent | "field service management", "project documentation", "quality inspections" |
| Substitutes | "Google Drive + templates + WhatsApp + email threads" |

#### Step 2 — Build the Competitor List (60-90 min)

Collect 5-15 total:

- **Direct (5):** same ICP, same job
- **Adjacent (5):** same ICP, different angle
- **Substitutes (2-5):** generic tools and manual workflows

> **Rule:** You only need enough to see patterns. If you can't articulate patterns after 10, your frame is wrong.

#### Step 3 — Benchmark the Essentials (2-3 hours)

For each competitor, capture:

**Positioning (what they promise)**
- Headline/subheadline
- 3 proof points used (numbers, compliance claims, integrations)

**Time-to-value (TTV) path**
- First 3 actions after signup
- What is the first "Aha moment" they push you toward?

> **Definition:** TTV = time from signup to the first moment the user receives tangible value.

**Packaging and paywalls**
- Pricing model (per seat / per org / per usage / per project)
- Tier limits (seats, projects, storage, exports, integrations)
- Upgrade triggers (what forces payment)

**Workflow and roles**
- Do they support teams? permissions? approvals? audit logs?
- Do they have org/workspace concepts?

**Integrations and switching costs**
- Imports/exports, API, webhooks
- Does the product "lock you in" via data structure?

**Trust posture (B2B SaaS reality)**
- Security page exists? SOC2/ISO claims? Data hosting?
- Compliance posture (if relevant)

#### Step 4 — Mine User Pains (60-120 min)

Collect pain statements from multiple sources:

- App store reviews (if relevant)
- G2/Capterra/Trustpilot
- Community forums
- Support docs / known issues
- Feature request boards
- Competitor FAQ (what they feel forced to explain)

**Extraction method:** For each pain, write:

| Field | Description |
|-------|-------------|
| Complaint | Verbatim short phrase |
| Underlying pain | What actually hurts |
| Desired outcome | What they want |
| Who is affected | Buyer vs user |

Then tag each pain:

- **Frequency:** low / medium / high
- **Severity:** annoyance / workflow blocker / business risk

#### Step 5 — Synthesize Patterns (45-60 min)

Produce:

- Top 3 recurring pains (high frequency + high severity)
- Top 3 competitor patterns (what everyone does)
- 2-3 wedge candidates
- 1 recommended wedge to test first

### 3.4.4 Deliverables

- `Competitor_Matrix.md` (or spreadsheet)
- `Discovery_Insights.md` containing:
  - Patterns
  - Pain list (tagged)
  - Paywall/upgrade triggers summary
  - Wedge candidates + recommendation

### 3.4.5 Gate (Pass Criteria)

- [ ] >= 5 direct competitors benchmarked
- [ ] >= 10 distinct user pain statements captured (with source + severity)
- [ ] Paywall/upgrade triggers summarized across competitors
- [ ] 2-3 wedge candidates written; 1 recommended

### 3.4.6 Quality Bar (What "Good" Looks Like)

- You can explain competitor differences in terms of workflow, packaging, and time-to-value, not just features
- Your pain list includes at least one pain in each category:
  - Onboarding friction
  - Collaboration/permissions
  - Reporting/exporting
  - Reliability/support

### 3.4.7 Common Failure Modes + Fixes

| Failure | Fix |
|---------|-----|
| Feature-only comparison | Always include TTV path + paywall map + upgrade triggers |
| Vague wedge ("better UX") | Tie wedge to a measurable outcome and a concrete mechanism |
| Ignoring substitutes | Map the manual workflow; your real competitor is often "status quo + templates" |

---

## 3.5 Station C — ICP + JTBD Definition

### 3.5.1 Purpose

Define a target that is specific enough to:

- Design onboarding and permissions
- Set pricing and packaging assumptions
- Choose a distribution channel
- Evaluate whether a feature is "in" or "out" for MVP

### 3.5.2 Procedure (Step-by-Step)

#### Step 1 — ICP v0 (30 min)

Write one paragraph:

- Who they are (industry + size)
- What their workflow looks like today
- What they use (tools) and what breaks

#### Step 2 — Add Constraints That Matter for SaaS (45-60 min)

Capture constraints that change product decisions:

- **Buying friction:** who approves? legal? procurement?
- **Data sensitivity:** client data, photos, contracts, PII
- **Device context:** mobile-first? offline? field conditions?
- **Collaboration:** how many roles? internal/external?

#### Step 3 — Triggers (Why Now?) (30 min)

List 3-5 triggers:

- Growth (more projects/users)
- Compliance or contract requirements
- Pain event (lost data, dispute, missed deadline)
- Leadership change / tool replacement cycle

#### Step 4 — JTBD (60-90 min)

Write 3-5 jobs in outcome language:

> When [context], I want to [job], so I can [outcome].

For each JTBD, add:

- Current workaround
- Cost of failure (time, money, risk)
- Success criteria (how they know it worked)

#### Step 5 — Prioritize JTBD (30 min)

Score each JTBD 1-5 on:

- Frequency
- Severity
- Willingness to pay
- Feasibility in MVP

Pick the top 1-2 to anchor the wedge.

#### Step 6 — Anti-ICP (20-30 min)

Define who you should avoid in v1 because:

- They require heavy customization
- Their compliance needs exceed your current posture
- They won't adopt (culture/tooling mismatch)

### 3.5.3 Deliverables

`ICP_JTBD.md` including:

- ICP + constraints + triggers
- 3-5 JTBD with outcomes
- JTBD prioritization scores
- Anti-ICP

### 3.5.4 Gate (Pass Criteria)

- [ ] ICP includes constraints (budget, environment, workflow)
- [ ] Anti-ICP exists with reasons
- [ ] >= 3 JTBD written with outcomes + current workaround
- [ ] Top 1-2 JTBD selected as "anchor jobs"

### 3.5.5 Common Failure Modes + Fixes

| Failure | Fix |
|---------|-----|
| ICP too broad ("SMBs") | Specify industry + size + workflow maturity + buying trigger |
| JTBD are features ("I want a dashboard") | Rewrite as job + outcome ("I want to track X so I can decide Y") |
| Ignoring buyer vs user | Explicitly separate buyer pain (risk/cost) from user pain (workflow) |

---

## 3.6 Station D — Wedge + Positioning Draft

### 3.6.1 Purpose

Define a first reason to choose you that is:

- Narrow enough to execute quickly
- Strong enough to differentiate
- Aligned with a clear ROI story

### 3.6.2 Wedge Definition

A wedge is your entry point, not your full roadmap. It should be:

- **Specific:** one primary job
- **Measurable:** clear outcome
- **Defensible:** mechanism is hard to copy quickly

**Examples of measurable wedges:**

- "Reduce site report production time from 45 minutes to 10 minutes."
- "Reduce errors/disputes via audit-proof reports and signatures."
- "Make onboarding 10x faster by eliminating configuration."

### 3.6.3 Procedure (Step-by-Step)

1. Select the top pain + top JTBD from Stations B/C

2. Write 2-3 wedge candidates using this format:

   > "For [ICP], we deliver [measurable outcome] by [unique mechanism], unlike [competitor pattern]."

3. For each wedge candidate, define:
   - Proof points achievable in MVP (what you can actually ship)
   - What you will explicitly not do (non-goals)
   - Risks and dependencies (e.g., offline mode, billing complexity)

4. Choose the recommended wedge using a quick rubric (1-5):
   - Outcome magnitude
   - Speed to MVP
   - Differentiation strength
   - Willingness to pay
   - Operational risk

### 3.6.4 Deliverables

`Wedge_Positioning.md` (one pager)

### 3.6.5 Gate (Pass Criteria)

- [ ] Wedge is one paragraph tied to a measurable outcome
- [ ] Proof points are plausible inside MVP timebox
- [ ] Non-goals exist and remove scope dilution
- [ ] Recommended wedge selected using an explicit rubric

### 3.6.6 Common Failure Modes + Fixes

| Failure | Fix |
|---------|-----|
| Wedge requires 12 months of build | Reduce to a single vertical slice that delivers value immediately |
| Wedge is subjective ("more modern") | Rewrite as time/error/risk reduction with mechanism |
| Wedge conflicts with SaaS fundamentals | If wedge depends on weak tenancy/RBAC/ops posture, narrow the wedge or raise the baseline |

---

## 3.7 Station E — Metrics Draft (SaaS)

### 3.7.1 Purpose

Define what you will measure to decide:

- Whether the MVP is working
- What iteration to prioritize
- Whether to invest in growth

> Metrics are part of product design. If you don't define them now, you'll optimize random things later.

### 3.7.2 Procedure (Step-by-Step)

#### Step 1 — North Star Metric (NSM) (20-30 min)

Pick one metric that best represents delivered value.

Good NSMs for B2B SaaS are often org-level:

- Weekly active organizations (WAO)
- Number of completed "value actions" per org per week

#### Step 2 — Activation (Aha Moment) (30-45 min)

Define the earliest measurable event correlated with retention.

> Activation must be an event definition, not a feeling.

**Example:**

> "First site report created and shared with at least 1 collaborator within 24 hours."

#### Step 3 — Retention (20-30 min)

Define 7-day and 30-day retention.

> For B2B, prefer org-level retention (WAO) over individual DAU.

#### Step 4 — Conversion (30-45 min)

Define:

- Trial -> paid conversion
- Upgrade triggers
- What happens when trial ends

#### Step 5 — Reliability SLO Draft (30-45 min)

At minimum:

- Uptime target
- p95 latency for core endpoints
- Error rate target

#### Step 6 — Cost-to-Serve + Limits Metrics (30-60 min)

Define:

- Meter (seats/requests/storage/tokens)
- Heavy tenant threshold
- Cost per active org

### 3.7.3 Deliverables

- `Metrics_Draft.md` with thresholds and definitions
- `Analytics_Events_Draft.md` mapping events -> metrics

### 3.7.4 Gate (Pass Criteria)

- [ ] NSM defined (with rationale)
- [ ] Activation defined as an event + time window
- [ ] Retention definitions exist
- [ ] >= 1 reliability SLO drafted
- [ ] >= 1 cost-to-serve metric drafted

### 3.7.5 Common Failure Modes + Fixes

| Failure | Fix |
|---------|-----|
| Vanity metrics (page views) | Tie metrics to delivered value and retention |
| Missing definitions (no exact event) | Every metric must specify exact event(s) and time windows |
| No thresholds | Define minimum acceptable thresholds to guide decisions |

---

## 3.8 Templates Appendix (Discovery)

### 3.8.1 Template — Competitor Matrix

**File:** `/01-discovery/Competitor_Matrix.md`

| Column | Description |
|--------|-------------|
| Competitor | Name |
| Category | Direct / Adjacent / Substitute |
| ICP target | Who they serve |
| Primary job | What they solve |
| Pricing model | Per seat / per org / per usage / per project |
| Tiers/limits | Seats, projects, storage, exports, integrations |
| Paywalled features | What's gated |
| Upgrade triggers | What forces payment |
| Onboarding steps | First actions |
| TTV (Aha moment) | Time to value |
| Collaboration/RBAC | Team features |
| Integrations/API | Connectivity |
| Security posture | Trust signals |
| Weak points | From reviews |
| Notes | Additional observations |

**Extraction prompts:**

- What is the first action after signup?
- What is paywalled, and why?
- What forces upgrades?
- What do users complain about repeatedly?
- What is their collaboration and permission model?
- Do they expose API/webhooks/import/export?

### 3.8.2 Template — Discovery Insights

**File:** `/01-discovery/Discovery_Insights.md`

```markdown
## Patterns Observed

- **Pattern 1:**
- **Pattern 2:**
- **Pattern 3:**

## Top User Pains (Tagged)

For each pain: complaint -> underlying pain -> desired outcome -> severity -> frequency -> source.

### Pain 1
- **Complaint:**
- **Underlying pain:**
- **Desired outcome:**
- **Severity:**
- **Frequency:**
- **Sources:**

## Paywall Map Summary

- **Commonly paywalled items:**
- **Typical upgrade triggers:**

## Wedge Candidates

- **Candidate A:**
- **Candidate B:**
- **Candidate C:**

## Recommended Wedge (and Why)
```

### 3.8.3 Template — ICP + JTBD (Expanded)

**File:** `/01-discovery/ICP_JTBD.md`

```markdown
## ICP v0

- **Industry:**
- **Company size:**
- **Team structure:**
- **Buyer:**
- **Users:**
- **Current workflow/tools:**
- **Constraints:** (budget, time, compliance, device, offline)
- **Trigger events:** (why now?)
- **Buying friction:** (approvals, procurement, legal, security review)

## Anti-ICP (With Reasons)

- **A1:**
- **A2:**

## Jobs To Be Done (JTBD)

### JTBD 1
> When ___, I want to ___, so I can ___.

- **Current workaround:**
- **Cost of failure:**
- **Success criteria:**
- **Score:** frequency / severity / willingness-to-pay / feasibility

## Anchor JTBD (Top 1-2)

- **Anchor 1:**
- **Anchor 2:**
```

### 3.8.4 Template — Wedge + Positioning One Pager

**File:** `/01-discovery/Wedge_Positioning.md`

```markdown
## Wedge Statement (One Paragraph)

> For [ICP], we deliver [measurable outcome] by [unique mechanism], unlike [competitor pattern].

## Why Now (Timing)

## Proof Points (MVP-Achievable)

- **P1:**
- **P2:**
- **P3:**

## Non-Goals (Explicit)

- **NG1:**
- **NG2:**

## Wedge Rubric Scores (1-5)

| Dimension | Score |
|-----------|-------|
| Outcome magnitude | |
| Speed to MVP | |
| Differentiation strength | |
| Willingness to pay | |
| Operational risk | |

## Primary Competitors to Displace
```

### 3.8.5 Template — Metrics Draft

**File:** `/01-discovery/Metrics_Draft.md`

```markdown
## North Star Metric (NSM)

- **NSM definition:**
- **Why it represents value:**
- **How it is measured (events):**

## Activation (Aha Moment)

- **Activation event definition:**
- **Time window:**
- **Target threshold:**

## Retention

- **7-day retention definition:**
- **30-day retention definition:**
- **Target thresholds:**

## Conversion

- **Trial -> paid definition:**
- **Upgrade triggers:**
- **Target thresholds:**

## Reliability (SLO Draft)

- **Uptime:**
- **Core endpoint p95 latency:**
- **Error rate:**

## Cost + Limits

- **Primary meter:** (seats/requests/storage/tokens)
- **Cost per active tenant:**
- **Heavy tenant detection threshold:**
- **Limit-hit behavior:** (product + technical)
```

### 3.8.6 Template — Analytics Events Draft

**File:** `/01-discovery/Analytics_Events_Draft.md`

For each event:

| Field | Description |
|-------|-------------|
| event_name | snake_case |
| When it fires | Trigger condition |
| Required properties | tenantId, userId, plan, source, role |
| Optional properties | Additional context |
| Why it matters | Which metric it powers |

**Example:**

```yaml
event_name: signup_completed
fires: after account creation + first tenant created
required: tenantId, userId, source
why: funnel baseline
```
