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

After Phase 0 completes, use AskUserQuestion to get structured approval:

1. **Present summary first** (as text, not question):

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

2. **Use AskUserQuestion for approval**:

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

If validation found warnings or issues, use AskUserQuestion for structured decisions:

1. **Present validation summary** (as text):

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

2. **Use AskUserQuestion for each warning** (or batch if similar):

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
