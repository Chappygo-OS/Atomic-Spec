# Station 16 — Product Analytics + Event Tracking

> Instrumentation That Drives Decisions

## 16.1 Objective

Build analytics so you can:

- Validate product-market fit signals (activation, retention, conversion)
- Identify friction in key flows (onboarding, first value, upgrade)
- Quantify feature adoption and ROI (usage vs churn)
- Support billing and limits decisions with data
- Debug user issues with safe, tenant-aware telemetry

> **Rule:** Analytics is not "page views". It's a measurement system for your product loops.

## 16.2 Scope (MVP vs Later)

**MVP (Recommended):**

- Event taxonomy + naming convention
- Core funnel events (activation + core wedge)
- Upgrade/billing funnel events (Stripe integration)
- Limits/warnings events (Part 10)
- Minimal user/session properties (tenant-safe)
- Dashboards for the top 3 product loops
- Privacy rules (no raw PII in analytics)

**Later:**

- Cohort retention analysis
- Experiment framework (A/B tests)
- Attribution (channels, campaigns)
- Advanced cost attribution (per tenant by feature)
- Product-qualified lead (PQL) scoring models

## 16.3 Analytics Principles (Non-Negotiable)

- Track outcomes, not clicks (value actions)
- Event names are contracts (versioned, reviewed)
- Tenant context always included (tenantId is mandatory)
- No sensitive data in analytics payloads
- Events must be idempotent where possible (avoid double-counts)
- A small number of high-quality events beats noisy instrumentation

## 16.4 Event Taxonomy (How You Structure Events)

### 16.4.1 Naming Convention (Recommended)

Use a consistent format: `domain.action` or `object.verb`

**Examples:**

| Event Name | Description |
|------------|-------------|
| `auth.login_succeeded` | User logged in |
| `tenant.created` | New tenant created |
| `member.invited` | Team member invited |
| `core_entity.created` | Core domain entity created |
| `export.requested` | Export initiated |
| `export.completed` | Export finished |
| `billing.checkout_started` | Checkout flow begun |
| `billing.subscription_activated` | Subscription confirmed |
| `limit.warning_triggered` | Usage limit warning |
| `limit.blocked` | Usage limit reached |

> **Rule:** Do not use UI-specific names like `button_clicked`.

### 16.4.2 Event Levels

| Level | Description |
|-------|-------------|
| Business events | Conversion, upgrade, retention drivers |
| Product events | Feature adoption |
| Operational product signals | Limits reached, blocked, errors |
| Security signals | Optional, but often better in logs than analytics |

## 16.5 What You Must Measure (SaaS Loops)

### 16.5.1 Activation Funnel (Core Wedge)

Define your "Aha moment" and instrument it.

**Example Structure:**

1. `auth.signup_completed`
2. `tenant.created` or `tenant.joined`
3. `core_entity.created` (first meaningful object)
4. `core_entity.shared` or `core_value_delivered` (true activation)

> **Rule:** Activation must be a single, explicit metric you can trend weekly.

### 16.5.2 Retention and Engagement

Track recurring value:

- `core_entity.viewed` (if meaningful)
- `core_entity.updated`
- `export.completed`
- `integration.connected`
- Weekly active tenant metric

**Define:**

- DAU/WAU/MAU at tenant and user levels (tenant is often more meaningful in B2B)

### 16.5.3 Conversion / Revenue Funnel (Stripe)

**Events:**

| Event | Description |
|-------|-------------|
| `billing.upgrade_clicked` | User initiated upgrade |
| `billing.checkout_created` | Checkout session created |
| `billing.checkout_completed` | Client-side return |
| `billing.subscription_activated` | Webhook-confirmed |
| `billing.payment_failed` | Payment failure |
| `billing.portal_opened` | Billing portal accessed |
| `billing.plan_changed` | Plan modification |
| `billing.canceled` | Subscription canceled |

> **Rule:** Only webhook-confirmed events count as revenue truth.

### 16.5.4 Limits + Cost Control Loop

**Events:**

| Event | Description |
|-------|-------------|
| `limit.warning_triggered` | 80% threshold |
| `limit.blocked` | 100% threshold |
| `limit.upgrade_prompt_shown` | Upgrade CTA displayed |
| `limit.upgrade_completed` | User upgraded from limit |

> **Rule:** Limits should be a measurable lever, not a surprise.

## 16.6 Event Schema (What Every Event Carries)

### 16.6.1 Required Fields

| Field | Description |
|-------|-------------|
| `eventName` | The event identifier |
| `timestamp` | When the event occurred |
| `tenantId` | Tenant context (mandatory) |
| `userId` | User context (nullable for some server events) |
| `planId` | Important for segmentation |
| `environment` | prod/stage |
| `requestId` | When tied to API actions |
| `source` | web/api/worker |

### 16.6.2 Optional (High Leverage)

| Field | Description |
|-------|-------------|
| `role` | Admin/Member - useful for funnels |
| `featureFlagStates` | Only if needed |
| `clientApp` | web, extension, mobile |
| `locale` | User locale |

### 16.6.3 Event-Specific Properties (Strictly Limited)

Examples:

| Event Type | Properties |
|------------|------------|
| Exports | `exportType`, `durationMs`, `sizeBytes` |
| AI | `tokenEstimate`, `modelTier` |
| Limits | `meterName`, `current`, `limit`, `resetAt` |

> **Rule:** Never include raw content (documents, prompts, emails) in analytics.

## 16.7 Privacy Rules (Must Be Explicit)

- Don't send emails, names, full IPs
- If you need user identity linkage, use internal IDs
- Document what is considered sensitive
- Provide opt-out if required by policy

> **Rule:** Analytics payloads should be safe to leak (in principle).

## 16.8 Idempotency and Double-Count Prevention

**Common Double-Count Sources:**

- Client retries
- Network retries
- User refreshes success page
- Webhook replays

**Strategies:**

- Include `eventId` (UUID) generated server-side for key events
- Dedupe on (`eventName`, `requestId`) where appropriate
- For webhook-derived events: use Stripe event id as correlation/dedup

> **Rule:** The "truth events" (billing activation, limit blocked, export completed) must be deduped.

## 16.9 Where to Emit Events (Architecture)

Emit events from:

| Source | Event Types |
|--------|-------------|
| API/service layer | Business events (reliable) |
| Worker layer | Async completion events |
| Client | UI-only interactions (use sparingly) |

> **Rule:** If it changes business state, emit it server-side.

## 16.10 Dashboards (MVP Set)

You should have dashboards for:

| Dashboard | Purpose |
|-----------|---------|
| Activation funnel | Weekly tracking |
| Core usage | Active tenants, key actions |
| Billing funnel | Upgrade -> activated |
| Limits loop | Warnings, blocks, upgrades |
| Feature adoption | Top features |

## 16.11 Deliverables

- `Analytics_Event_Taxonomy.md`
- `Core_Funnels.md`
- `Event_Schema.md`
- `Privacy_for_Analytics.md`
- `Dashboards_Spec.md`
