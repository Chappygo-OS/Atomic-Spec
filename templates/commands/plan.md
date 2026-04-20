---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
handoffs:
  - label: Create Tasks
    agent: atomicspec.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: atomicspec.checklist
    prompt: Create a checklist for the following domain...
scripts:
  sh: scripts/bash/setup-plan.sh --json
  ps: scripts/powershell/setup-plan.ps1 -Json
validation_scripts:
  sh: scripts/bash/validate-tech-stack.sh --json
  ps: scripts/powershell/validate-tech-stack.ps1 -Json
agent_scripts:
  sh: scripts/bash/update-agent-context.sh __AGENT__
  ps: scripts/powershell/update-agent-context.ps1 -AgentType __AGENT__
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `{SCRIPT}` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH.

2. **Load context**: Read FEATURE_SPEC and `/memory/constitution.md`. Load IMPL_PLAN template (already copied).

3. **Load Project Defaults Registry**: Read `specs/_defaults/registry.yaml` per Constitution Directive 7. Extract existing defaults to pre-populate decisions.

4. **Initial Configuration (HITL)**: Use AskUserQuestion to gather preferences before starting work.

5. **Execute plan workflow**: Follow the structure in IMPL_PLAN template with configured preferences.

6. **Registry Sync (HITL)**: After all decisions are made, sync new decisions to registry with user approval.

7. **Stop and report**: Command ends after Phase 1 planning. Report branch, IMPL_PLAN path, and generated artifacts.

## Initial Configuration

**MANDATORY: Before any planning work, interview the user using AskUserQuestion.**

### Configuration Interview

Use AskUserQuestion with the following questions:

```
Question 1: "Would you like to use specialized subagents for this planning phase?"
Header: "Subagents"
Options:
  - Label: "Yes, use specialized agents (Recommended)"
    Description: "AI will use domain-specific agents (API design, data architecture, etc.) if available in .specify/subagents/"
  - Label: "No, use general knowledge"
    Description: "AI will handle all domains with general knowledge - faster but less specialized"

Question 2: "Do you have existing competitive analysis for this feature?"
Header: "Competitive"
Options:
  - Label: "Yes, at competitive-analysis/summary.md"
    Description: "AI will use your competitive insights to inform technical decisions"
  - Label: "No competitive analysis"
    Description: "AI will make decisions based on general best practices"
  - Label: "Run /atomicspec.AnalyzeCompetitors first"
    Description: "Stop here and run competitive analysis before planning"

Question 3: "What level of detail do you want for HITL checkpoints?"
Header: "Review depth"
Options:
  - Label: "Full review (Recommended)"
    Description: "Pause for approval at each checkpoint with detailed options"
  - Label: "Quick review"
    Description: "Show summary, ask for quick approval"
  - Label: "Auto-approve with logging"
    Description: "Proceed automatically, log decisions for later review"
```

### Subagent Discovery

If user selected "Yes, use specialized agents":

1. **Scan the subagents folder** at `.specify/subagents/`:
   - Recursively list all `**/*.md` files in the folder and all subdirectories
   - **Exclude** files starting with `_` (e.g., `_index.md`, `_template.md`)

2. **For each subagent file found**, read the YAML frontmatter to extract:
   - `name`: The subagent identifier
   - `description`: What it does and when to use it
   - `model`: Which model it prefers (if specified)

3. **List discovered subagents to the user**:
   ```
   ══════════════════════════════════════════════════════════════
   📦 DISCOVERED SUBAGENTS
   ══════════════════════════════════════════════════════════════

   Found [N] specialized subagents in .specify/subagents/:

   | Subagent              | Domain                                    |
   |-----------------------|-------------------------------------------|
   | backend-architect     | REST APIs, microservices, DB schemas      |
   | api-documenter        | OpenAPI specs, SDK generation, dev docs   |
   | database-optimizer    | SQL optimization, indexes, migrations     |
   | [...]                 | [...]                                     |

   These agents will be loaded automatically when their domain
   is relevant to your feature (API design, data model, etc.)
   ══════════════════════════════════════════════════════════════
   ```

4. **If no subagents found** (empty folder), inform user:
   ```
   No subagents found in .specify/subagents/
   Falling back to general knowledge for all domains.
   ```

5. **Store discovered agents** in plan.md for later reference during Phase 1

### Record Configuration

Store configuration in plan.md:

```markdown
## Planning Configuration

**Configured At**: [timestamp]
**Detected Platform**: [web/ios/android/react-native/flutter/backend-only/both]

| Setting | Value |
|---------|-------|
| Platform | [web/ios/android/react-native/flutter/backend-only/both] |
| Subagents | [Enabled/Disabled] |
| Available Subagents | [list or "None"] |
| Competitive Analysis | [Yes/No/Pending] |
| Review Depth | [Full/Quick/Auto] |
```

## Phases

### Phase 0.0: Load Project Defaults Registry

**Per Constitution Article IX, Directive 7 - This step is MANDATORY.**

Before any planning work, load the project defaults registry:

1. **Read registry file**:
   ```
   Read: specs/_defaults/registry.yaml
   ```

2. **If registry exists**, extract relevant sections for planning:
   - `architecture.*` - **CRITICAL**: System pattern, layers, API style, communication
   - `code_patterns.*` - Data access, DI, error handling, validation approach
   - `api.*` - API versioning, pagination, error format, resource naming
   - `backend.*` - Language, framework, ORM, auth, caching
   - `frontend.*` - Framework, rendering, UI library, state management
   - `database.*` - Type, tenancy model, migrations, naming conventions
   - `error_handling.*` - Logging format, error tracking, tracing
   - `testing.*` - Frameworks, coverage targets
   - `security.*` - CORS, CSRF, rate limiting
   - `conventions.*` - Naming conventions, commit format
   - `ui_specs.*` - Dark mode, responsive, accessibility

   **Architecture is foundational** - if `architecture.*` is null, prompt user to set it first:
   ```
   ══════════════════════════════════════════════════════════════
   ⚠️ ARCHITECTURE NOT DEFINED
   ══════════════════════════════════════════════════════════════

   The project registry has no architecture defined yet.
   Architecture decisions affect EVERYTHING else.

   We need to establish:
   - System pattern (monolith vs microservices vs serverless)
   - Code layers (clean architecture vs MVC vs vertical slice)
   - API style (REST vs GraphQL vs gRPC)
   - Communication (sync vs async vs event-driven)

   These will be set during the Tech Stack Review checkpoint.
   ══════════════════════════════════════════════════════════════
   ```

3. **If registry doesn't exist**, warn user:
   ```
   ══════════════════════════════════════════════════════════════
   ⚠️ PROJECT DEFAULTS REGISTRY NOT FOUND
   ══════════════════════════════════════════════════════════════

   No registry found at specs/_defaults/registry.yaml

   This may mean:
   - Project was initialized before registry feature was added
   - Registry was accidentally deleted

   All decisions in this plan will be feature-specific unless
   you choose to create a registry during this session.
   ══════════════════════════════════════════════════════════════
   ```

4. **Store loaded defaults** for use in subsequent phases:
   - These will pre-populate tech stack decisions
   - Any decision matching registry = Source: "Registry"
   - Any decision NOT in registry = Source: "Assumed" (candidate for registry)

**Output**: Registry defaults loaded into planning context

### Phase 0.1: Platform Detection (MANDATORY - NEVER SKIP)

**This phase runs for ALL features, including backend-only.**

**See also**: `.specify/knowledge/_platform-resolution.md` for the canonical platform resolution algorithm that ALL commands must follow.

Platform detection must happen BEFORE tech stack validation because:
- A backend FOR a mobile app is different from a backend for web
- Platform determines verification commands, subagent selection, and wiring requirements
- Tech stack validation (Phase 0.5-0.7) needs platform context

**Registry Validation (per _platform-resolution.md)**:
Before proceeding, validate the registry exists and has target_platform set. Never silently default to web.

1. **Check spec.md for Platform header**:
   ```
   Read: FEATURE_DIR/spec.md
   → Look for "Platform:" header in frontmatter or body
   ```

2. **If not in spec.md, check registry**:
   ```
   Read: specs/_defaults/registry.yaml
   → Look for target_platform.primary
   ```

3. **If still unknown, ask user**:
   ```
   Question: "What is the target platform for this feature?"
   Header: "Platform"
   Options:
     - Label: "Web (Browser)"
       Description: "React, Vue, Angular, Svelte, or similar web framework"
     - Label: "iOS (Native)"
       Description: "Swift/SwiftUI or UIKit"
     - Label: "Android (Native)"
       Description: "Kotlin/Jetpack Compose or XML Views"
     - Label: "React Native"
       Description: "Cross-platform with React Native"
     - Label: "Flutter"
       Description: "Cross-platform with Flutter/Dart"
     - Label: "Backend-only"
       Description: "API, CLI, worker, or service with no UI"
     - Label: "Mobile + Backend"
       Description: "Mobile app with its own backend/API (interviews for BOTH stacks)"
   ```

   If user selects "Mobile + Backend", ask follow-up:
   ```
   Question: "Which mobile framework for the frontend?"
   Header: "Mobile Framework"
   Options:
     - Label: "iOS (Native)"
       Description: "Swift/SwiftUI or UIKit"
     - Label: "Android (Native)"
       Description: "Kotlin/Jetpack Compose or XML Views"
     - Label: "React Native"
       Description: "Cross-platform with React Native"
     - Label: "Flutter"
       Description: "Cross-platform with Flutter/Dart"
   ```
   Store the selected mobile framework in `mobile_framework` registry field.
   Store `Detected Platform: both`.

4. **Store detected platform** in plan.md output header:
   ```markdown
   ## Planning Configuration

   **Configured At**: [timestamp]
   **Detected Platform**: [web/ios/android/react-native/flutter/backend-only/both]

   | Setting | Value |
   |---------|-------|
   | Platform | [detected value] |
   | Subagents | [Enabled/Disabled] |
   ...
   ```

**Why this matters**: Even backend-only features need platform context. A REST API for a mobile app may need different response formats, pagination styles, or authentication flows than one for web. This information propagates to:
- Tech stack validation commands (Phase 0.6)
- Subagent selection (mobile subagents vs web subagents)
- Knowledge wiring in generated tasks

**Output**: Platform detected and stored in plan.md configuration

### Phase 0.2: Load Domain Knowledge (Assembly Line Manual)

**Per Constitution Article IX, Directive 8 - This step is MANDATORY.**

Before designing, load relevant stations and subagents based on feature domains.

**⚠️ DO NOT hard-code agent names. Use dynamic discovery.**

1. **Discover available subagents**:

   a. **Scan the subagents folder** at `.specify/subagents/`:
      - Recursively list all `**/*.md` files in the folder and all subdirectories
      - **Exclude** files starting with `_` (e.g., `_index.md`, `_template.md`)

   b. **For each subagent file found**, read the YAML frontmatter to extract:
      - `name`: The subagent identifier
      - `description`: What it does and when to use it (contains matching keywords)

   c. **Build an agent catalog** with extracted descriptions:
      ```
      | Agent Name | Description (for matching) |
      |------------|---------------------------|
      | [name from frontmatter] | [description from frontmatter] |
      | ... | ... |
      ```

2. **Extract domain keywords from spec.md**:

   Scan the feature specification for domain-relevant terms:
   - Technical terms: API, database, auth, payment, UI, tests, deploy, etc.
   - User story contexts: "user can pay", "admin dashboard", "login flow"
   - Entity mentions: users, orders, subscriptions, products, etc.
   - Actions: create, update, delete, search, filter, etc.

3. **Match spec keywords to agent descriptions** (semantic similarity):

   For each agent in the catalog:
   a. Check if agent's `description` contains keywords from the spec
   b. Check if spec context relates to agent's stated purpose
   c. **Score match quality**:
      - Multiple keyword matches → Strong match (load this agent)
      - Single keyword match → Moderate match (consider loading)
      - No overlap → Do not load

   **Example matching**:
   - Spec mentions "REST API", "endpoints" → Agent with "REST, API, microservice" in description → Match
   - Spec mentions "payment", "subscription" → Agent with "payment, billing, stripe" → Match
   - Spec mentions "React components" → Agent with "components, UI, frontend" → Match

4. **For each matched agent**:

   a. **Load the subagent file**:
      ```
      Read: .specify/subagents/[matched-agent-name].md
      ```

   b. **Extract and store**:
      - Key patterns/rules (e.g., "Every query MUST filter by tenant_id")
      - Gate criteria checklists
      - Common pitfalls to avoid
      - Required outputs/artifacts

5. **If no subagents exist but stations might help**:

   Fall back to station discovery:
   ```
   Read: .specify/knowledge/stations/00-station-map.md
   → Find relevant station for unmatched domain
   → Read: .specify/knowledge/stations/[XX]-[domain].md
   ```

6. **If NO knowledge base exists** (no stations, no subagents):

   Use AskUserQuestion:
   ```
   Question: "No Assembly Line knowledge base found. How should we proceed?"
   Header: "Knowledge"
   Options:
     - Label: "Use general best practices (Recommended)"
       Description: "AI will use training knowledge - less SaaS-specific"
     - Label: "Set up defaults now"
       Description: "I'll answer questions to establish patterns"
     - Label: "Import from template"
       Description: "Use a standard SaaS template as starting point"
   ```

4. **Report loaded knowledge**:

   ```
   ══════════════════════════════════════════════════════════════
   📚 DOMAIN KNOWLEDGE LOADED
   ══════════════════════════════════════════════════════════════

   Detected domains from spec:
   - [domain 1]: Loaded from [subagent/station]
   - [domain 2]: Loaded from [subagent/station]
   - [domain 3]: No knowledge available - using general practices

   Key rules that will be applied:
   - [Rule 1 from domain 1]
   - [Rule 2 from domain 1]
   - [Rule 3 from domain 2]

   Gate criteria to verify:
   - [ ] [Gate from domain 1]
   - [ ] [Gate from domain 2]
   ══════════════════════════════════════════════════════════════
   ```

5. **Store loaded knowledge** for use in subsequent phases:
   - These patterns inform data model design
   - Gate criteria will be embedded in task files during `/atomicspec.tasks`
   - Rules will be applied during code review

**Output**: Domain knowledge loaded into planning context, rules documented

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 0.5: Tech Stack Review Checkpoint (HITL #1)

**Per Constitution Article IX, Directive 6 - This checkpoint is MANDATORY.**

After Phase 0 completes, present the tech stack and get approval:

⚠️ **CRITICAL EXECUTION ORDER - YOU MUST FOLLOW THESE STEPS EXACTLY:**

1. **FIRST: Output the summary table as plain text** (DO NOT use AskUserQuestion yet!):

   ```
   ══════════════════════════════════════════════════════════════
   🛑 TECH STACK REVIEW - Phase 0.5 Checkpoint
   ══════════════════════════════════════════════════════════════

   Based on your spec, registry defaults, and research:

   | Decision          | Value             | Source       |
   |-------------------|-------------------|--------------|
   | Target Platform   | [from Phase 0.1]  | Phase 0.1    |
   | Language/Version  | [value]           | Registry/Spec/Assumed |
   | Primary Framework | [value]           | Registry/Spec/Assumed |
   | Storage           | [value]           | Registry/Spec/Assumed |
   | ORM/Data Layer    | [value]           | Registry/Spec/Assumed |
   | Testing Framework | [value]           | Registry/Spec/Assumed |

   Source Legend:
   - Phase 0.1 = Detected in Platform Detection phase
   - Registry = From specs/_defaults/registry.yaml (project standard)
   - Spec = Explicitly stated in feature spec
   - Assumed = Inferred by AI (candidate for registry)

   ⚠️ NEW DECISIONS (not in registry - will prompt to add):
   [list decisions with Source: "Assumed"]
   ══════════════════════════════════════════════════════════════
   ```

   **YOU MUST OUTPUT THIS TABLE TO THE USER BEFORE PROCEEDING.**
   The user cannot approve something they haven't seen.

2. **THEN: Use AskUserQuestion for approval** (only AFTER showing the table above):

   ```
   Question 1: "Do you approve this tech stack?"
   Header: "Tech Stack"
   Options:
     - Label: "Approve all (Recommended)"
       Description: "Accept all decisions as shown above"
     - Label: "Approve with changes"
       Description: "I'll specify what to change"
     - Label: "Reject - need different approach"
       Description: "Start over with different technology choices"

   Question 2: "Select your coding conventions" (multiSelect: true)
   Header: "Conventions"
   Options:
     - Label: "camelCase for variables/functions"
       Description: "JavaScript/TypeScript standard"
     - Label: "snake_case for variables/functions"
       Description: "Python/Ruby standard"
     - Label: "PascalCase for classes/components"
       Description: "Standard for class-based code"
     - Label: "kebab-case for files"
       Description: "URL-friendly file naming"
   ```

3. **Handle "Approve with changes" response**:

   If user selects "Approve with changes", use follow-up AskUserQuestion:

   ```
   Question: "What would you like to change?"
   Header: "Changes"
   Options:
     - Label: "Language/Version"
       Description: "Change programming language or version"
     - Label: "Framework"
       Description: "Change primary framework"
     - Label: "Database/Storage"
       Description: "Change database or storage solution"
     - Label: "Multiple items"
       Description: "I'll specify in detail"
   ```

   Then gather specifics and re-present checkpoint.

4. **Record approval** in plan.md `## Tech Stack Approval` section:
   - Mark all decisions as approved
   - Add approval timestamp
   - Record selected coding conventions
   - Note any revisions made

5. **Skip conditions** (if ALL are true AND Review Depth = "Auto-approve"):
   - Every Technical Context field was explicit in spec (Source = "Spec" for all)
   - No assumptions were made

**Output**: User-approved technical decisions and coding conventions recorded in plan.md

### Phase 0.6: Tech Stack Validation

**Per Constitution Article IX, Directive 6 - This validation is MANDATORY after HITL #1.**

After the user approves tech stack CHOICES (Phase 0.5), run compatibility validation:

1. **Run validation script**:

   Run `{VALIDATION_SCRIPT}` to check:
   - Package freshness (last publish date)
   - Deprecation notices
   - Peer dependency conflicts
   - Version compatibility
   - Known issues

2. **Parse validation results**:

   The script returns JSON with status and findings:
   ```json
   {
     "status": "PASS | PASS_WITH_WARNINGS | FAIL",
     "packages": [...],
     "warnings": [...]
   }
   ```

3. **Update plan.md** `## Tech Stack Validation` section with results.

**Output**: Validation results populated in plan.md

### Phase 0.7: Validation Review Checkpoint (HITL #2)

**Per Constitution Article IX, Directive 6 - This checkpoint is MANDATORY if warnings exist.**

If validation found warnings or issues, present them and get decisions:

⚠️ **CRITICAL EXECUTION ORDER - YOU MUST FOLLOW THESE STEPS EXACTLY:**

1. **FIRST: Output the validation summary as plain text** (DO NOT use AskUserQuestion yet!):

   ```
   ══════════════════════════════════════════════════════════════
   🔍 TECH STACK VALIDATION - Phase 0.7 Checkpoint
   ══════════════════════════════════════════════════════════════

   Validation Status: [PASS_WITH_WARNINGS]

   | Package       | Proposed | Validated | Status | Notes              |
   |---------------|----------|-----------|--------|--------------------|
   | [package]     | latest   | 5.7.1     | WARN   | [issue found]      |

   ⚠️ WARNINGS FOUND: [count] issues requiring decision
   ══════════════════════════════════════════════════════════════
   ```

   **YOU MUST OUTPUT THIS TABLE TO THE USER BEFORE PROCEEDING.**
   The user cannot make decisions about warnings they haven't seen.

2. **THEN: Use AskUserQuestion for each warning** (only AFTER showing the table above):

   ```
   Question: "[Package] has compatibility warning: [issue]. How should we proceed?"
   Header: "[Package]"
   Options:
     - Label: "Accept recommendation (Recommended)"
       Description: "[specific recommendation, e.g., 'Upgrade to v5.15+']"
     - Label: "Keep current version"
       Description: "I accept the risk - will be documented"
     - Label: "Use alternative package"
       Description: "I'll specify a different package"
     - Label: "Need more information"
       Description: "Explain the issue in more detail"
   ```

3. **Handle responses**:
   - "Accept recommendation" → Apply fix, continue
   - "Keep current version" → Use follow-up AskUserQuestion for reason:
     ```
     Question: "Please provide a reason for accepting this risk (for documentation)"
     Header: "Override reason"
     Options:
       - Label: "Deployment environment handles it"
         Description: "Our infrastructure mitigates this issue"
       - Label: "Will address post-MVP"
         Description: "Known tech debt, will fix later"
       - Label: "Not applicable to our use case"
         Description: "The warning doesn't affect our implementation"
     ```
   - "Use alternative package" → Ask for alternative, re-run validation
   - "Need more information" → Explain, then re-ask

4. **Record in plan.md** `## Tech Stack Validation` section:
   - Update Validation Status
   - Add any user overrides with their selected reasons
   - Add validation approval timestamp

5. **Loop handling**:
   - If user changes packages, re-run Phase 0.6 validation
   - Continue until all warnings are resolved (accepted, overridden, or fixed)

6. **Skip conditions** (validation review may be skipped if):
   - Validation status is PASS (no warnings)
   - Review Depth = "Auto-approve" (log decisions automatically)

**Output**: User-reviewed validation with documented decisions

### Phase 0.8: Frontend/UI Specifications Checkpoint (HITL #3)

**Per Constitution Article IX, Directive 6 - This checkpoint is MANDATORY if feature has UI.**

After tech stack validation, if the feature involves frontend/UI, gather UI framework specifications.

⚠️ **CRITICAL EXECUTION ORDER - YOU MUST FOLLOW THESE STEPS EXACTLY:**

---

#### Step 1: Check if UI specifications are needed

**Platform was already detected in Phase 0.1.** This phase focuses on UI FRAMEWORK specifics.

Skip this phase ONLY if:
- Platform = "backend-only" (detected in Phase 0.1)
- User explicitly marked "No UI" in spec

**DO NOT skip this phase just because it's a backend feature.** If the backend serves a mobile app, the platform context (detected in Phase 0.1) is still valuable, but UI framework questions can be skipped.

---

#### Step 1.5: COMPOSITE PLATFORM HANDLING (Platform = "both" only)

**This block ONLY triggers when Detected Platform = "both". For single platforms, skip entirely to Step 2.**

When Platform = "both", this feature targets a mobile frontend with its own backend/API. Both stacks need specification:

1. **Read mobile framework from registry/plan config**:
   ```
   Read from plan.md: "Detected Platform: both"
   Read from registry or plan config: mobile_framework → [ios/android/react-native/flutter]
   ```

2. **Run mobile platform interview branch**:
   Based on `mobile_framework`, execute the corresponding mobile platform branch questions below (iOS, Android, React Native, or Flutter) to gather UI framework specifics for the mobile frontend.
   Record results under the appropriate `mobile_*` registry fields (`mobile_framework`, `mobile_platforms`).

3. **Present backend tech stack questions**:
   ```
   Question 1: "What backend language?"
   Header: "Backend Language"
   Options:
     - Label: "TypeScript/Node.js"
     - Label: "Python"
     - Label: "Go"
     - Label: "Rust"
     - Label: "Java/Kotlin"
     - Label: "Other"
   Store → backend.language

   Question 2: "What backend framework?"
   Header: "Backend Framework"
   (Options vary by selected language, e.g., Express/Fastify/NestJS for Node, Django/FastAPI for Python, etc.)
   Store → backend.framework

   Question 3: "What ORM/database layer?"
   Header: "ORM / Database Layer"
   (Options vary by selected language, e.g., Prisma/Drizzle/TypeORM for Node, SQLAlchemy/Django ORM for Python, etc.)
   Store → backend.orm
   ```

4. **Record both stacks in plan.md**:
   ```markdown
   ### Composite Stack (Platform = both)

   **Mobile Frontend**:
   - Framework: [mobile_framework value]
   - Platforms: [mobile_platforms value]
   - UI specifications: [from mobile branch interview above]

   **Backend/API**:
   - Language: [backend.language]
   - Framework: [backend.framework]
   - ORM: [backend.orm]
   ```

After completing this composite block, skip Step 3 and Step 4 (single-platform branches) and proceed directly to Phase 0.9.

---

#### Step 2: Retrieve detected platform

The platform was detected in Phase 0.1 and stored in plan.md configuration.

```
Read from plan.md: "Detected Platform: [value]"
```

If platform is "backend-only", skip to Phase 0.9.

---

#### Step 3: Present platform-specific context

```
══════════════════════════════════════════════════════════════
🎨 FRONTEND/UI SPECIFICATIONS - Phase 0.8 Checkpoint
══════════════════════════════════════════════════════════════

Your tech stack includes frontend work. Let's define UI standards
to ensure consistent implementation across all components.

Detected Platform: [Web/iOS/Android/React Native/Flutter]
Detected Framework: [React/SwiftUI/Jetpack Compose/etc.]
══════════════════════════════════════════════════════════════
```

**YOU MUST OUTPUT THIS CONTEXT TO THE USER BEFORE PROCEEDING.**

---

#### Step 4: Platform-specific questions

**Branch to the appropriate platform section below based on Step 2 detection.**

---

### Platform Branch: WEB

**Registry prefix**: `frontend.*`

```
Question 1: "Which UI component library/framework?"
Header: "UI Library"
Options:
  - Label: "Tailwind CSS + Headless UI (Recommended)"
    Description: "Utility-first CSS with accessible headless components"
  - Label: "Shadcn/ui"
    Description: "Re-usable components built with Radix and Tailwind"
  - Label: "Material UI / MUI"
    Description: "Google's Material Design components for React"
  - Label: "Chakra UI"
    Description: "Simple, modular and accessible component library"
  - Label: "Ant Design"
    Description: "Enterprise-level React components"
  - Label: "Other"
    Description: "I'll specify a different library"
→ Store in: registry.frontend.ui_library

Question 2: "Design system approach?"
Header: "Design System"
Options:
  - Label: "Use existing design tokens (Recommended)"
    Description: "I have design tokens/Figma variables to import"
  - Label: "Create minimal tokens"
    Description: "Define basic colors, spacing, typography from scratch"
  - Label: "No design system"
    Description: "Use library defaults, customize as needed"
→ Store in: registry.ui_specs.design_tokens

Question 3: "State management approach?"
Header: "State Mgmt"
Options:
  - Label: "React Context + hooks (Recommended for MVP)"
    Description: "Built-in React state, good for small-medium apps"
  - Label: "Zustand"
    Description: "Lightweight, minimal boilerplate state management"
  - Label: "Redux Toolkit"
    Description: "Full-featured state management with dev tools"
  - Label: "TanStack Query only"
    Description: "Server state management, minimal client state"
  - Label: "Jotai"
    Description: "Primitive and flexible state management"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.frontend.state_management

Question 4: "Form handling approach?"
Header: "Forms"
Options:
  - Label: "React Hook Form + Zod (Recommended)"
    Description: "Performant forms with schema validation"
  - Label: "Formik + Yup"
    Description: "Popular form library with Yup validation"
  - Label: "TanStack Form"
    Description: "Headless, type-safe form library"
  - Label: "Native form handling"
    Description: "Manual form state, custom validation"
  - Label: "Other"
    Description: "I'll specify a different library"
→ Store in: registry.frontend.form_library
```

**Follow-up for design tokens** (if "Use existing design tokens" selected):

```
Question: "Where are your design tokens located?"
Header: "Tokens"
Options:
  - Label: "Figma Variables (will export)"
    Description: "I'll export from Figma to JSON/CSS"
  - Label: "CSS custom properties file"
    Description: "Already have :root variables defined"
  - Label: "tokens.json / design-tokens.json"
    Description: "Have a JSON token file ready"
  - Label: "Style Dictionary config"
    Description: "Using Style Dictionary for token management"
  - Label: "I'll provide the path"
    Description: "Tokens are in a custom location"
→ Store in: registry.ui_specs.design_token_source
```

---

### Platform Branch: iOS (Native)

**Registry prefix**: `ios.*`

```
Question 1: "Which UI framework?"
Header: "UI Framework"
Options:
  - Label: "SwiftUI (Recommended)"
    Description: "Modern declarative UI framework, iOS 15+"
  - Label: "UIKit"
    Description: "Imperative UI framework, broader iOS version support"
  - Label: "SwiftUI + UIKit hybrid"
    Description: "SwiftUI for new screens, UIKit for complex components"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.ios.ui_framework

Question 2: "State management approach?"
Header: "State Mgmt"
Options:
  - Label: "@Observable + SwiftUI (Recommended)"
    Description: "Modern Observation framework (iOS 17+)"
  - Label: "ObservableObject + @Published"
    Description: "Combine-based state (iOS 13+)"
  - Label: "TCA (The Composable Architecture)"
    Description: "Unidirectional data flow with Point-Free library"
  - Label: "MVVM with Combine"
    Description: "Traditional MVVM pattern"
  - Label: "Redux-like (ReSwift)"
    Description: "Centralized state with ReSwift"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.ios.state_management

Question 3: "Navigation approach?"
Header: "Navigation"
Options:
  - Label: "NavigationStack (Recommended)"
    Description: "SwiftUI navigation, iOS 16+"
  - Label: "NavigationView (Legacy)"
    Description: "Older SwiftUI navigation, iOS 13+"
  - Label: "UINavigationController"
    Description: "UIKit navigation with coordinators"
  - Label: "Coordinator pattern"
    Description: "Decoupled navigation with coordinator objects"
  - Label: "SwiftUI Router"
    Description: "Custom enum-based routing"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.ios.navigation

Question 4: "Local data persistence?"
Header: "Data"
Options:
  - Label: "SwiftData (Recommended)"
    Description: "Modern persistence framework (iOS 17+)"
  - Label: "Core Data"
    Description: "Apple's ORM, broader version support"
  - Label: "Realm"
    Description: "Third-party object database"
  - Label: "UserDefaults + Codable"
    Description: "Simple key-value storage"
  - Label: "GRDB / SQLite"
    Description: "Direct SQLite access"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.ios.local_database

Question 5: "Networking layer?"
Header: "Networking"
Options:
  - Label: "URLSession + async/await (Recommended)"
    Description: "Native networking with Swift concurrency"
  - Label: "Alamofire"
    Description: "Popular networking library"
  - Label: "Moya"
    Description: "Network abstraction layer over Alamofire"
  - Label: "URLSession + Combine"
    Description: "Reactive networking with Combine"
  - Label: "Other"
    Description: "I'll specify a different library"
→ Store in: registry.ios.networking
```

---

### Platform Branch: Android (Native)

**Registry prefix**: `android.*`

```
Question 1: "Which UI framework?"
Header: "UI Framework"
Options:
  - Label: "Jetpack Compose (Recommended)"
    Description: "Modern declarative UI toolkit"
  - Label: "XML Views"
    Description: "Traditional View system with XML layouts"
  - Label: "Compose + Views hybrid"
    Description: "Compose for new screens, Views for complex components"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.android.ui_framework

Question 2: "State management approach?"
Header: "State Mgmt"
Options:
  - Label: "ViewModel + StateFlow (Recommended)"
    Description: "Android Architecture Components with Kotlin Flow"
  - Label: "ViewModel + LiveData"
    Description: "Classic Android lifecycle-aware state"
  - Label: "MVI with Orbit"
    Description: "Model-View-Intent pattern with Orbit library"
  - Label: "Redux-like (Mobius)"
    Description: "Unidirectional data flow"
  - Label: "Compose State only"
    Description: "Simple remember/mutableStateOf for small apps"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.android.state_management

Question 3: "Navigation approach?"
Header: "Navigation"
Options:
  - Label: "Navigation Compose (Recommended)"
    Description: "Jetpack Navigation with Compose integration"
  - Label: "Navigation Component (Fragments)"
    Description: "XML-based navigation with Fragments"
  - Label: "Voyager"
    Description: "Multiplatform navigation library"
  - Label: "Decompose"
    Description: "Lifecycle-aware components for navigation"
  - Label: "Simple Activity/Fragment stack"
    Description: "Manual navigation management"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.android.navigation

Question 4: "Local data persistence?"
Header: "Data"
Options:
  - Label: "Room (Recommended)"
    Description: "SQLite abstraction with compile-time verification"
  - Label: "DataStore"
    Description: "Preferences and typed data storage"
  - Label: "Realm"
    Description: "Third-party object database"
  - Label: "SQLDelight"
    Description: "Type-safe SQL with multiplatform support"
  - Label: "SharedPreferences"
    Description: "Simple key-value storage (small data only)"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.android.local_database

Question 5: "Dependency injection?"
Header: "DI"
Options:
  - Label: "Hilt (Recommended)"
    Description: "Android-optimized DI built on Dagger"
  - Label: "Koin"
    Description: "Lightweight Kotlin DI framework"
  - Label: "Dagger 2"
    Description: "Full Dagger without Android extensions"
  - Label: "Manual DI"
    Description: "Constructor injection without framework"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.android.dependency_injection
```

---

### Platform Branch: React Native

**Registry prefix**: `react_native.*`

```
Question 1: "Which component library?"
Header: "UI Library"
Options:
  - Label: "React Native Paper (Recommended)"
    Description: "Material Design components for React Native"
  - Label: "NativeBase"
    Description: "Cross-platform UI components"
  - Label: "Tamagui"
    Description: "Universal design system with performance focus"
  - Label: "React Native Elements"
    Description: "Cross-platform UI toolkit"
  - Label: "Gluestack UI"
    Description: "Universal components with NativeWind"
  - Label: "Custom with NativeWind/Tailwind"
    Description: "Tailwind-style styling for React Native"
  - Label: "Other"
    Description: "I'll specify a different library"
→ Store in: registry.react_native.ui_library

Question 2: "State management approach?"
Header: "State Mgmt"
Options:
  - Label: "Zustand (Recommended)"
    Description: "Lightweight, works great with React Native"
  - Label: "Redux Toolkit"
    Description: "Full-featured state management"
  - Label: "Jotai"
    Description: "Atomic state management"
  - Label: "TanStack Query + Context"
    Description: "Server state with minimal client state"
  - Label: "MobX"
    Description: "Observable-based state management"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.react_native.state_management

Question 3: "Navigation solution?"
Header: "Navigation"
Options:
  - Label: "React Navigation (Recommended)"
    Description: "Most popular RN navigation library"
  - Label: "Expo Router"
    Description: "File-based routing for Expo apps"
  - Label: "React Native Navigation (Wix)"
    Description: "Native navigation with better performance"
  - Label: "Solito"
    Description: "Cross-platform navigation (web + native)"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.react_native.navigation

Question 4: "Local data persistence?"
Header: "Data"
Options:
  - Label: "AsyncStorage + MMKV (Recommended)"
    Description: "Simple storage with MMKV for performance"
  - Label: "WatermelonDB"
    Description: "Reactive database for large datasets"
  - Label: "Realm"
    Description: "Object database with sync capabilities"
  - Label: "SQLite (expo-sqlite)"
    Description: "Direct SQLite access"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.react_native.local_database

Question 5: "Development approach?"
Header: "Dev Approach"
Options:
  - Label: "Expo (Managed) (Recommended)"
    Description: "Simplified development with Expo SDK"
  - Label: "Expo (Bare)"
    Description: "Expo tools with native code access"
  - Label: "React Native CLI"
    Description: "Full native access, no Expo"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.react_native.dev_approach
```

---

### Platform Branch: Flutter

**Registry prefix**: `flutter.*`

```
Question 1: "UI approach?"
Header: "UI Approach"
Options:
  - Label: "Material 3 (Recommended)"
    Description: "Google's Material Design 3 widgets"
  - Label: "Cupertino"
    Description: "iOS-style widgets for Apple platforms"
  - Label: "Adaptive (Material + Cupertino)"
    Description: "Platform-adaptive UI switching"
  - Label: "Custom design system"
    Description: "Custom widgets matching brand design"
  - Label: "Other"
    Description: "I'll specify a different approach"
→ Store in: registry.flutter.ui_approach

Question 2: "State management approach?"
Header: "State Mgmt"
Options:
  - Label: "Riverpod (Recommended)"
    Description: "Type-safe, compile-time validated state management"
  - Label: "BLoC"
    Description: "Business Logic Component pattern"
  - Label: "Provider"
    Description: "Simple dependency injection and state"
  - Label: "GetX"
    Description: "All-in-one state, navigation, and DI"
  - Label: "MobX"
    Description: "Observable-based reactive state"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.flutter.state_management

Question 3: "Navigation approach?"
Header: "Navigation"
Options:
  - Label: "GoRouter (Recommended)"
    Description: "Declarative routing with deep linking support"
  - Label: "Navigator 2.0"
    Description: "Flutter's declarative navigation API"
  - Label: "AutoRoute"
    Description: "Code-generated type-safe routing"
  - Label: "GetX Navigation"
    Description: "Simple navigation from GetX"
  - Label: "Navigator 1.0 (imperative)"
    Description: "Classic push/pop navigation"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.flutter.navigation

Question 4: "Local data persistence?"
Header: "Data"
Options:
  - Label: "Drift (moor) (Recommended)"
    Description: "Type-safe SQLite wrapper with reactive queries"
  - Label: "Hive"
    Description: "Fast key-value database"
  - Label: "Isar"
    Description: "High-performance NoSQL database"
  - Label: "sqflite"
    Description: "Direct SQLite access"
  - Label: "SharedPreferences"
    Description: "Simple key-value storage"
  - Label: "Other"
    Description: "I'll specify a different solution"
→ Store in: registry.flutter.local_database

Question 5: "Networking approach?"
Header: "Networking"
Options:
  - Label: "Dio (Recommended)"
    Description: "Powerful HTTP client with interceptors"
  - Label: "http package"
    Description: "Dart's standard HTTP package"
  - Label: "Retrofit"
    Description: "Type-safe HTTP client generator"
  - Label: "Chopper"
    Description: "HTTP client with built-in converter"
  - Label: "Other"
    Description: "I'll specify a different library"
→ Store in: registry.flutter.networking
```

---

#### Step 5: Cross-platform UI specifications (ALL platforms)

After platform-specific questions, ask these for ALL platforms:

```
Question: "Select additional UI requirements" (multiSelect: true)
Header: "UI Features"
Options:
  - Label: "Dark mode support"
    Description: "Theme switching between light and dark"
  - Label: "Accessibility support"
    Description: "VoiceOver/TalkBack, dynamic type, high contrast"
  - Label: "Animation/transitions"
    Description: "Smooth animations and micro-interactions"
  - Label: "Tablet/iPad support"
    Description: "Optimized layouts for larger screens"
  - Label: "Landscape orientation"
    Description: "Support for landscape mode"
→ Store in: registry.ui_specs.* (dark_mode, accessibility, animations, tablet_support, landscape)
```

---

#### Step 6: Custom UI specifications prompt

After structured questions, always ask:

```
Question: "Do you have additional UI specifications to add?"
Header: "Custom UI"
Options:
  - Label: "Yes, I have more requirements"
    Description: "I'll describe additional UI rules/constraints"
  - Label: "No, these choices are complete"
    Description: "Proceed with the selections above"
```

If "Yes", use follow-up AskUserQuestion:

```
Question: "What additional UI specifications should we follow?"
Header: "Extra specs"
Options:
  - Label: "Specific design guidelines"
    Description: "Brand guidelines, spacing rules, typography"
  - Label: "Icon library preference"
    Description: "SF Symbols, Material Icons, custom icons"
  - Label: "Animation guidelines"
    Description: "Specific timing, easing, or motion rules"
  - Label: "Multiple specifications"
    Description: "I'll describe all additional requirements"
```

---

#### Step 7: Final UI confirmation

Present summary and confirm:

```
══════════════════════════════════════════════════════════════
📋 UI SPECIFICATIONS SUMMARY
══════════════════════════════════════════════════════════════

Platform: [Web/iOS/Android/React Native/Flutter]

| Setting          | Value                    | Registry Key                |
|------------------|--------------------------|------------------------------|
| UI Framework     | [selected]               | [platform].ui_framework      |
| State Management | [selected]               | [platform].state_management  |
| Navigation       | [selected]               | [platform].navigation        |
| Data Persistence | [selected]               | [platform].local_database    |
| [Platform-specific] | [selected]            | [platform].[key]             |

Cross-Platform Settings:
| Setting          | Value    | Registry Key                |
|------------------|----------|------------------------------|
| Dark Mode        | [Yes/No] | ui_specs.dark_mode           |
| Accessibility    | [Yes/No] | ui_specs.accessibility       |
| Animations       | [Yes/No] | ui_specs.animations          |
| Tablet Support   | [Yes/No] | ui_specs.tablet_support      |

Additional specifications:
[any custom specs provided]
══════════════════════════════════════════════════════════════
```

```
Question: "Confirm these UI specifications?"
Header: "Confirm UI"
Options:
  - Label: "Approve all (Recommended)"
    Description: "These specifications are correct"
  - Label: "Make changes"
    Description: "I need to modify some choices"
  - Label: "Add more specifications"
    Description: "I have additional requirements to add"
```

---

#### Step 8: Record in plan.md

Record in `## Frontend/UI Specifications` section:
- Platform detected
- All selected options with registry keys
- Design token source (if applicable)
- Additional requirements
- Approval timestamp

---

#### Step 9: Skip conditions

Skip UI framework questions (Steps 3-8) if:
- Platform = "backend-only" (detected in Phase 0.1)
- User explicitly marked "No UI" in spec
- Review Depth = "Auto-approve" AND all UI choices are in registry

**Note**: Platform detection itself is NEVER skipped - it happens in Phase 0.1 for ALL features. This phase (0.8) only handles UI framework specifics.

**Output**: User-approved UI specifications recorded in plan.md with platform-specific registry keys

### Phase 0.9: Registry Sync Checkpoint (HITL #4)

**Per Constitution Article IX, Directive 7 - This checkpoint is MANDATORY.**

After all tech decisions are approved, sync new decisions to the project registry:

1. **Collect all new decisions** that are NOT already in registry:
   - From Phase 0.5: Language, framework, ORM, database, etc.
   - From Phase 0.8: UI library, state management, form handling, etc.
   - Any conventions selected

2. **Present registry sync summary**:

   ```
   ══════════════════════════════════════════════════════════════
   📋 REGISTRY SYNC - Phase 0.9 Checkpoint
   ══════════════════════════════════════════════════════════════

   The following decisions were made in this planning session
   and are NOT yet in the project defaults registry:

   | Key                      | Value           | Add to Registry? |
   |--------------------------|-----------------|------------------|
   | backend.language         | typescript      | Candidate        |
   | backend.framework        | express         | Candidate        |
   | frontend.ui_library      | shadcn          | Candidate        |
   | frontend.state_management| zustand         | Candidate        |
   | api.versioning           | url             | Candidate        |

   Adding these to the registry means ALL future features
   will use these as defaults (with HITL override option).
   ══════════════════════════════════════════════════════════════
   ```

3. **Use AskUserQuestion for each candidate** (batch if many):

   ```
   Question: "Add these decisions to project defaults registry?"
   Header: "Registry Sync"
   Options:
     - Label: "Add all to registry (Recommended)"
       Description: "All decisions become project defaults for future features"
     - Label: "Select which to add"
       Description: "I'll choose which decisions to add individually"
     - Label: "Skip - keep feature-specific"
       Description: "Don't add any to registry, only apply to this feature"
   ```

4. **If "Select which to add"**, present each decision:

   ```
   Question: "Add [key] = [value] to project defaults?"
   Header: "[category]"
   Options:
     - Label: "Yes, add to registry"
       Description: "Future features will use this by default"
     - Label: "No, feature-specific only"
       Description: "Only this feature uses this setting"
   ```

5. **Update registry files** for approved additions:

   a. **Update `specs/_defaults/registry.yaml`**:
      - Set each approved key to its value
      - Update `last_updated` to current timestamp
      - Update `last_updated_by: human`
      - Add feature to `applied_to` list

   b. **Append to `specs/_defaults/changelog.md`**:
      ```markdown
      ### [DATE] | [key.path]
      - **Changed**: `null` → `[value]`
      - **Why**: Decided during [feature-name] planning
      - **Source**: specs/[feature-name]/plan.md
      - **Approved by**: Human (accept)
      ```

6. **Report sync results**:

   ```
   ══════════════════════════════════════════════════════════════
   ✅ REGISTRY SYNC COMPLETE
   ══════════════════════════════════════════════════════════════

   Added to registry: [count] decisions
   Kept feature-specific: [count] decisions

   Updated files:
   - specs/_defaults/registry.yaml
   - specs/_defaults/changelog.md

   Future features will inherit these project defaults.
   ══════════════════════════════════════════════════════════════
   ```

7. **Skip conditions**:
   - No new decisions were made (all came from registry)
   - Review Depth = "Auto-approve" (add all automatically, log in changelog)

**Output**: Registry updated with user-approved defaults, changelog appended

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete, Tech Stack Validation complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Agent context update**:
   - Run `{AGENT_SCRIPT}`
   - These scripts detect which AI agent is in use
   - Update the appropriate agent-specific context file
   - Add only new technology from current plan
   - Preserve manual additions between markers

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

## Key rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications
