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

3. **Initial Configuration (HITL)**: Use AskUserQuestion to gather preferences before starting work.

4. **Execute plan workflow**: Follow the structure in IMPL_PLAN template with configured preferences.

5. **Stop and report**: Command ends after Phase 1 planning. Report branch, IMPL_PLAN path, and generated artifacts.

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

1. Check `.specify/subagents/_index.md` for available agents
2. List available subagents:
   ```
   Found subagents:
   - api-contracts.md (API design, OpenAPI)
   - data-architecture.md (Database, tenancy)
   - auth-rbac.md (Authentication, permissions)
   ```
3. If no subagents found, inform user and fall back to general knowledge

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

   Based on your spec and research, here are the resolved technical decisions:

   | Decision          | Value             | Source   |
   |-------------------|-------------------|----------|
   | Language/Version  | [value]           | Spec/Assumed |
   | Primary Framework | [value]           | Spec/Assumed |
   | Storage           | [value]           | Spec/Assumed |
   | ORM/Data Layer    | [value]           | Spec/Assumed |
   | Testing Framework | [value]           | Spec/Assumed |
   | Target Platform   | [value]           | Spec/Assumed |

   ⚠️ ASSUMPTIONS (not explicit in spec):
   [list assumptions with rationale]
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
