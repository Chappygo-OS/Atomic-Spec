# Project Defaults Changelog

This file tracks ALL changes to `registry.yaml`. Every update requires Human-In-The-Loop (HITL) approval and must be logged here with full context.

**Format**: Each entry documents what changed, when, why, and who approved it.

---

## Change Log

<!--
Template for new entries (copy and fill):

### YYYY-MM-DD | [key.path]
- **Changed**: `[old_value]` → `[new_value]`
- **Why**: [Reason for the change]
- **Source**: [Which spec/phase triggered this decision]
- **Approved by**: Human ([accept | custom: "reason"])

-->

*No changes recorded yet. This registry was initialized on [DATE].*

---

## How to Read This Log

| Field | Description |
|-------|-------------|
| **Date** | When the change was approved |
| **Key** | The registry.yaml path (e.g., `api.versioning`) |
| **Changed** | Old value → New value |
| **Why** | Business or technical rationale |
| **Source** | The spec, plan, or phase where decision was made |
| **Approved by** | Always "Human" + approval type |

## Approval Types

- `accept` - User approved the suggested value as-is
- `custom: "[text]"` - User provided a custom value or modified suggestion
- `reject` - User rejected adding this to defaults (kept as feature-specific)

---

## Deviation Log

When a spec deviates from registry defaults, it should be logged here for visibility.

<!--
Template for deviation entries:

### YYYY-MM-DD | Deviation in [feature-name]
- **Key**: [key.path]
- **Registry default**: [default_value]
- **Spec uses**: [different_value]
- **Reason**: [Why this spec needs different behavior]
- **Approved by**: Human

-->

*No deviations recorded yet.*
