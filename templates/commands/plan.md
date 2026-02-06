---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
handoffs: 
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: speckit.checklist
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
  - Label: "Run /speckit.AnalyzeCompetitors first"
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
   - List all `*.md` files in the folder
   - **Exclude** files starting with `_` (e.g., `_index.md`, `_template.md`)
   - Also scan `.specify/subagents/custom/` for project-specific agents

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

| Setting | Value |
|---------|-------|
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

### Phase 0.1: Load Domain Knowledge (Assembly Line Manual)

**Per Constitution Article IX, Directive 8 - This step is MANDATORY.**

Before designing, load relevant stations and subagents based on feature domains:

1. **Detect feature domains** from `spec.md`:

   Scan the spec for domain indicators:

   | Indicator in Spec | Domain | Load From |
   |-------------------|--------|-----------|
   | API endpoints, REST, routes | API Design | `.specify/subagents/backend-architect.md` OR Station 06 |
   | Database, entities, models | Data Architecture | `.specify/subagents/data-architecture.md` OR Station 07 |
   | Login, auth, JWT, sessions | Authentication | `.specify/subagents/auth-rbac.md` OR Station 08 |
   | Payment, billing, subscription | Payments | `.specify/subagents/payment-integration.md` OR Station 09 |
   | UI, components, pages | Frontend | `.specify/subagents/frontend-developer.md` OR Station 10 |
   | Tests, coverage | Testing | `.specify/subagents/test-runner.md` OR Station 12 |
   | Deploy, CI/CD, containers | Deployment | `.specify/subagents/deployment-engineer.md` OR Station 15 |

2. **For each relevant domain**:

   a. **Try loading subagent first** (faster, distilled knowledge):
      ```
      Read: .specify/subagents/[domain].md
      ```

   b. **If subagent doesn't exist**, fall back to full station:
      ```
      Read: .specify/knowledge/stations/[XX]-[domain].md
      ```

   c. **Extract and store**:
      - Key patterns/rules (e.g., "Every query MUST filter by tenant_id")
      - Gate criteria checklists
      - Common pitfalls to avoid
      - Required outputs/artifacts

3. **If NO knowledge base exists** (no stations, no subagents):

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
   - Gate criteria will be embedded in task files during `/speckit.tasks`
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
   | Language/Version  | [value]           | Registry/Spec/Assumed |
   | Primary Framework | [value]           | Registry/Spec/Assumed |
   | Storage           | [value]           | Registry/Spec/Assumed |
   | ORM/Data Layer    | [value]           | Registry/Spec/Assumed |
   | Testing Framework | [value]           | Registry/Spec/Assumed |
   | Target Platform   | [value]           | Registry/Spec/Assumed |

   Source Legend:
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

After tech stack validation, if the feature involves frontend/UI, present context and gather UI specifications:

⚠️ **CRITICAL EXECUTION ORDER - YOU MUST FOLLOW THESE STEPS EXACTLY:**

1. **Check if UI is involved**:

   Skip this phase if:
   - Feature is backend-only (API, CLI, worker)
   - No frontend framework in tech stack
   - User explicitly marked "No UI" in spec

2. **Present UI context** (as text):

   ```
   ══════════════════════════════════════════════════════════════
   🎨 FRONTEND/UI SPECIFICATIONS - Phase 0.8 Checkpoint
   ══════════════════════════════════════════════════════════════

   Your tech stack includes frontend work. Let's define UI standards
   to ensure consistent implementation across all components.

   Detected frontend: [React/Vue/Angular/Svelte/Other]
   ══════════════════════════════════════════════════════════════
   ```

   **YOU MUST OUTPUT THIS CONTEXT TO THE USER BEFORE PROCEEDING.**

3. **THEN: Use AskUserQuestion for UI framework choices** (only AFTER showing context above):

   ```
   Question 1: "Which UI component library/framework?"
   Header: "UI Library"
   Options:
     - Label: "Tailwind CSS + Headless UI (Recommended)"
       Description: "Utility-first CSS with accessible headless components"
     - Label: "Material UI / MUI"
       Description: "Google's Material Design components for React"
     - Label: "Shadcn/ui"
       Description: "Re-usable components built with Radix and Tailwind"
     - Label: "Chakra UI"
       Description: "Simple, modular and accessible component library"

   Question 2: "Design system approach?"
   Header: "Design System"
   Options:
     - Label: "Use existing design tokens (Recommended)"
       Description: "I have design tokens/Figma variables to import"
     - Label: "Create minimal tokens"
       Description: "Define basic colors, spacing, typography from scratch"
     - Label: "No design system"
       Description: "Use library defaults, customize as needed"

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

   Question 4: "Form handling approach?"
   Header: "Forms"
   Options:
     - Label: "React Hook Form + Zod (Recommended)"
       Description: "Performant forms with schema validation"
     - Label: "Formik + Yup"
       Description: "Popular form library with Yup validation"
     - Label: "Native form handling"
       Description: "Manual form state, custom validation"
   ```

4. **Follow-up for design tokens** (if "Use existing design tokens" selected):

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
     - Label: "I'll provide the path"
       Description: "Tokens are in a custom location"
   ```

5. **Additional UI specifications** (multiSelect):

   ```
   Question: "Select additional UI requirements" (multiSelect: true)
   Header: "UI Features"
   Options:
     - Label: "Dark mode support"
       Description: "Theme switching between light and dark"
     - Label: "Responsive/mobile-first"
       Description: "Must work well on mobile devices"
     - Label: "Accessibility (WCAG 2.1 AA)"
       Description: "Full keyboard nav, screen reader support"
     - Label: "Animation/transitions"
       Description: "Smooth animations with Framer Motion or similar"
   ```

6. **Custom UI specifications prompt**:

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
     - Label: "Specific breakpoints"
       Description: "Custom responsive breakpoints (I'll specify)"
     - Label: "Icon library preference"
       Description: "Specific icon set to use (Lucide, Heroicons, etc.)"
     - Label: "Animation guidelines"
       Description: "Specific timing, easing, or motion rules"
     - Label: "Multiple specifications"
       Description: "I'll describe all additional requirements"
   ```

7. **Final UI confirmation**:

   Present summary and confirm:

   ```
   ══════════════════════════════════════════════════════════════
   📋 UI SPECIFICATIONS SUMMARY
   ══════════════════════════════════════════════════════════════

   | Setting          | Value                    |
   |------------------|--------------------------|
   | UI Library       | [selected]               |
   | Design System    | [selected]               |
   | State Management | [selected]               |
   | Form Handling    | [selected]               |
   | Dark Mode        | [Yes/No]                 |
   | Responsive       | [Yes/No]                 |
   | Accessibility    | [Yes/No]                 |
   | Animations       | [Yes/No]                 |

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

8. **Record in plan.md** `## Frontend/UI Specifications` section:
   - All selected options
   - Design token source (if applicable)
   - Additional requirements
   - Approval timestamp

9. **Skip conditions**:
   - Feature has no UI (backend-only)
   - Review Depth = "Auto-approve" (log choices automatically)

**Output**: User-approved UI specifications recorded in plan.md

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
