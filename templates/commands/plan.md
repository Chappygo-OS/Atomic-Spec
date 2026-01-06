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

1. **Setup**: Run `{SCRIPT}` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load context**: Read FEATURE_SPEC and `/memory/constitution.md`. Load IMPL_PLAN template (already copied).

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

4. **Stop and report**: Command ends after Phase 2 planning. Report branch, IMPL_PLAN path, and generated artifacts.

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

### Phase 0.5: Tech Stack Review Checkpoint (HITL)

**Per Constitution Article IX, Directive 6 - This checkpoint is MANDATORY.**

After Phase 0 completes, you MUST pause and present decisions for user approval:

1. **Present the Tech Stack Review**:

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

   | Item              | Assumed Value     | Rationale                    |
   |-------------------|-------------------|------------------------------|
   | [item]            | [value]           | [why this was assumed]       |

   **Your options:**
   - Reply "proceed" to accept all decisions and continue to Phase 1
   - Reply "revise: [specifics]" to change any decision
   - Ask questions about any decision

   ══════════════════════════════════════════════════════════════
   ```

2. **Wait for user response**:
   - `"proceed"` → Update plan.md with approval timestamp, continue to Phase 1
   - `"revise: [specifics]"` → Update the specified decisions, re-present checkpoint
   - Questions → Answer, then re-present checkpoint
   - Do NOT proceed until explicit approval received

3. **Record approval** in plan.md `## Tech Stack Approval` section:
   - Mark all decisions as approved
   - Add approval timestamp
   - Note any revisions made

4. **Skip conditions** (if ALL are true, checkpoint may be abbreviated):
   - Every Technical Context field was explicit in spec (Source = "Spec" for all)
   - No assumptions were made
   - User passed `--no-review` flag

**Output**: User-approved technical decisions recorded in plan.md

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

If validation found warnings or issues, present them for user review:

1. **Present the Validation Review**:

   ```
   ══════════════════════════════════════════════════════════════
   🔍 TECH STACK VALIDATION - Phase 0.7 Checkpoint
   ══════════════════════════════════════════════════════════════

   Validation Status: [PASS_WITH_WARNINGS]

   | Package       | Proposed | Validated | Status | Notes              |
   |---------------|----------|-----------|--------|--------------------|
   | [package]     | latest   | 5.7.1     | WARN   | [issue found]      |

   ⚠️ WARNINGS REQUIRING DECISION:

   | Package       | Issue                        | Recommendation        |
   |---------------|------------------------------|----------------------|
   | [package]     | [description of issue]       | [what to do]         |

   **Your options:**
   - Reply "accept" to proceed with current versions (warnings documented)
   - Reply "change: [package] to [alternative]" to use a different package
   - Reply "override: [package] reason: [your reason]" to accept risk with documented reason
   - Ask questions about any warning

   ══════════════════════════════════════════════════════════════
   ```

2. **Handle user response**:
   - `"accept"` → Document as PASS_WITH_WARNINGS, continue
   - `"change: X to Y"` → Update tech stack, re-run validation (return to 0.6)
   - `"override: X reason: R"` → Document override with user's reason, continue
   - Questions → Answer, then re-present checkpoint

3. **Record in plan.md** `## Tech Stack Validation` section:
   - Update Validation Status
   - Add any user overrides with their reasons
   - Add validation approval timestamp

4. **Loop handling**:
   - If user changes packages, re-run Phase 0.6 validation
   - Continue until user accepts or overrides all warnings
   - There is no cap on iterations - user must reach agreement

5. **Skip conditions** (validation review may be skipped if):
   - Validation status is PASS (no warnings)
   - User passed `--skip-validation` flag (not recommended)

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
