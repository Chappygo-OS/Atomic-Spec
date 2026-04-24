# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`
**Created**: [DATE]
**Status**: Draft
**Platform**: [Web | iOS | Android | React Native | Flutter | Backend-only | both]
**Input**: User description: "$ARGUMENTS"

<!--
  NOTE: The Platform field is set during /atomicspec.specify (Phase 0 - Platform Detection).
  All downstream commands (/atomicspec.plan, /atomicspec.build, etc.) will inherit this platform
  setting to ensure consistent platform context throughout the feature lifecycle.

  When Platform = "both", the single Platform field is all that is stored here.
  Do NOT add Platform-Frontend or Platform-Backend fields.
  Downstream commands read the registry for specifics:
    - mobile_framework  → which mobile SDK/framework (React Native, Flutter, etc.)
    - backend.*         → language, framework, ORM, and other backend details
  This keeps the spec contract simple while the registry carries the detail.
-->

<!--
  ============================================================================
  CONSTITUTION ARTICLE IX COMPLIANCE: GATE COMPLIANCE (Directive 4)

  Before this specification can proceed to planning, the following Knowledge
  Station gates MUST be satisfied:

  - Station 03 (Discovery): ICP defined, Wedge defined, JTBD captured
  - Station 04 (PRD): SaaS Rules defined, Acceptance Criteria complete
  - Station 05 (User Flows): Edge State Checklist covered

  This is NON-NEGOTIABLE per the Constitution.
  ============================================================================
-->

## User Scenarios & Testing _(mandatory)_

<!--
  🛑 STOP: MANDATORY GATE - STATION 03

  BEFORE writing this section, you MUST:
  1. READ: `.specify/knowledge/stations/03-discovery.md`
  2. VERIFY these Gate Criteria are addressed:
     - [ ] ICP (Ideal Customer Profile) is defined or assumed
     - [ ] Anti-ICP (who NOT to target) is considered
     - [ ] Wedge (entry point value proposition) is clear
     - [ ] JTBD (Jobs To Be Done) are captured in user stories

  If gates cannot be satisfied, STOP and document what's missing.
-->

<!--
  🛑 STOP: MANDATORY GATE - STATION 05

  BEFORE writing this section, you MUST:
  1. READ: `.specify/knowledge/stations/05-user-flows.md`
  2. VERIFY these Gate Criteria are addressed:
     - [ ] User flows cover the Edge State Checklist:
           - RBAC (who can do what)
           - Tenant boundary (multi-tenancy considerations)
           - Limit-hit behavior (what happens at quotas)
           - Billing state (trial/paid/expired impacts)
           - Empty/Error/Loading states

  If gates cannot be satisfied, STOP and document what's missing.
-->

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements _(mandatory)_

<!--
  🛑 STOP: MANDATORY GATE - STATION 04

  BEFORE writing this section, you MUST:
  1. READ: `.specify/knowledge/stations/04-prd-spec.md`
  2. VERIFY these Gate Criteria are addressed:
     - [ ] MVP scope is explicit (Goals + Non-goals defined)
     - [ ] Every "Must" story has testable Acceptance Criteria
     - [ ] SaaS Rules are defined:
           - Tenancy: Boundary definition
           - RBAC: Roles/permissions
           - Limits: Meters/tiers
           - Billing impact: Trial/payment failure behavior
     - [ ] All open questions are resolved or have owners

  If gates cannot be satisfied, STOP and document what's missing.
-->

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

_Example of marking unclear requirements:_

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Key Entities _(include if feature involves data)_

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria _(mandatory)_

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]
