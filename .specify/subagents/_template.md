# [Agent Name] Subagent

**Domain**: [What this agent specializes in - e.g., "API design and OpenAPI specification"]
**Source Stations**: [Which Knowledge Stations this distills - e.g., "Station 06 (API Contracts)"]
**Use When**: [Trigger conditions - e.g., "Feature involves REST/GraphQL API"]
**Priority**: [1-3, where 1 is highest - used when multiple agents could apply]

## Core Knowledge

<!--
  GUIDELINES FOR THIS SECTION:
  - Maximum 50-100 lines of content
  - Focus on DECISIONS and PATTERNS, not procedures
  - Include gate criteria that must be satisfied
  - Remove anything that's "nice to know" vs "must know"
  - Ask: "What would cause a junior dev to make the wrong choice?"
-->

### Key Decisions

[List the critical decisions that must be made in this domain]

1. **[Decision 1]**: [Options and when to choose each]
2. **[Decision 2]**: [Options and when to choose each]
3. **[Decision 3]**: [Options and when to choose each]

### Required Patterns

[Patterns that MUST be followed - non-negotiable]

- **Pattern 1**: [Description]
- **Pattern 2**: [Description]

### Common Pitfalls

[What goes wrong if you don't follow this guidance]

- **Pitfall 1**: [What happens] → **Fix**: [How to avoid]
- **Pitfall 2**: [What happens] → **Fix**: [How to avoid]

## Gate Criteria

<!--
  These are the checks that must pass before the agent's work is complete.
  Pulled from the corresponding Knowledge Station gates.
-->

- [ ] [Gate 1 - specific, checkable criterion]
- [ ] [Gate 2 - specific, checkable criterion]
- [ ] [Gate 3 - specific, checkable criterion]
- [ ] [Gate 4 - specific, checkable criterion]

## Output Format

<!--
  What this agent should produce when invoked.
-->

When this subagent is used, it should produce:

1. **[Output 1]**: [Format/location - e.g., "OpenAPI spec in contracts/api.yaml"]
2. **[Output 2]**: [Format/location]
3. **[Output 3]**: [Format/location]

## Integration Points

<!--
  How this agent's output connects to other parts of the workflow.
-->

- **Feeds into**: [What downstream uses this output]
- **Depends on**: [What must exist before this runs]
- **Validates with**: [How to verify the output is correct]
