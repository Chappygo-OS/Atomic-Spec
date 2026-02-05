# Project Defaults Registry Protocol

**This protocol is MANDATORY for ALL commands, agents, and phases.**

The registry at `specs/_defaults/registry.yaml` is the single source of truth for project-wide technical decisions. You MUST follow this protocol to ensure consistency.

---

## On Entry (Before Any Work)

### Step 1: Load Registry

```
Read: specs/_defaults/registry.yaml
```

If file doesn't exist, warn user:
```
⚠️ No project defaults registry found at specs/_defaults/registry.yaml
   Consider running project initialization or creating defaults manually.
   Proceeding without defaults - all decisions will be feature-specific.
```

### Step 2: Filter to Your Domain

Only extract sections relevant to your current work:

| If you're working on... | Read these sections |
|------------------------|---------------------|
| Backend / API | `api`, `backend`, `database` |
| Frontend / UI | `frontend`, `ui_specs`, `conventions` |
| Infrastructure / DevOps | `infrastructure`, `testing` |
| Full-stack feature | All sections |

### Step 3: Apply Defaults

When generating specs, plans, or code:
- Pre-populate fields from registry values
- Mark registry-sourced values with comment: `# from: _defaults/registry.yaml`
- Never silently use a different value than what's in registry

---

## During Work (Decision Detection)

### Scenario A: Decision EXISTS in Registry

**Action**: Use it. No question. No deviation without explicit approval.

Example:
```yaml
# Registry has:
api:
  versioning: url

# Your spec/plan MUST use:
API Versioning: url-based (/api/v1/*)  # from: _defaults/registry.yaml
```

### Scenario B: Decision NOT in Registry (null or missing)

**Action**: Check if it's a project-wide concern, then ask.

1. Determine scope:
   - Project-wide: Would other features benefit from this same choice?
   - Feature-specific: Only relevant to this particular feature?

2. If project-wide, use `AskUserQuestion`:

```
┌─────────────────────────────────────────────────────────────┐
│ 📋 NEW PROJECT DEFAULT DETECTED                             │
├─────────────────────────────────────────────────────────────┤
│ Key: api.pagination                                         │
│ Proposed value: cursor                                      │
│ Context: Decided during billing feature planning            │
│                                                             │
│ This appears to be a project-wide decision.                 │
│ Future features would benefit from consistency here.        │
├─────────────────────────────────────────────────────────────┤
│ Options:                                                    │
│ ○ Add to project defaults (all features will use this)     │
│ ○ Keep as feature-specific (only this feature)             │
│ ○ Reject (don't use this value)                            │
│ ○ Other...                                                  │
└─────────────────────────────────────────────────────────────┘
```

3. Handle response:
   - "Add to project defaults" → Update registry + changelog
   - "Keep as feature-specific" → Use in current spec only, don't add to registry
   - "Reject" → Ask for alternative value
   - "Other" → Use custom response

### Scenario C: Need to DEVIATE from Registry

**Action**: Get explicit approval and document.

1. First, ask via `AskUserQuestion`:

```
┌─────────────────────────────────────────────────────────────┐
│ ⚠️ DEVIATION FROM PROJECT DEFAULTS                          │
├─────────────────────────────────────────────────────────────┤
│ Registry default: backend.orm = prisma                      │
│ This spec needs: drizzle                                    │
│                                                             │
│ Reason needed: Why does this feature require a different    │
│ ORM than the project standard?                              │
├─────────────────────────────────────────────────────────────┤
│ Options:                                                    │
│ ○ Approve deviation (I'll provide reason)                  │
│ ○ Use registry default (prisma)                            │
│ ○ Update registry (make drizzle the new default)           │
│ ○ Other...                                                  │
└─────────────────────────────────────────────────────────────┘
```

2. If "Approve deviation", follow up for reason:

```
Question: "Why does this feature need to deviate from the project default?"
Header: "Deviation reason"
Options:
  - Label: "Legacy system compatibility"
    Description: "Must integrate with existing system that requires this"
  - Label: "Performance requirements"
    Description: "Project default doesn't meet performance needs for this feature"
  - Label: "Technical constraint"
    Description: "Dependency or platform limitation requires this"
  - Label: "I'll explain"
    Description: "Custom explanation"
```

3. Document in spec/plan:

```markdown
DEVIATION from project-registry:
- Key: backend.orm
- Default: prisma
- This spec uses: drizzle
- Reason: Legacy billing system requires Drizzle for schema compatibility
- Approved: Human (YYYY-MM-DD)
```

4. Log in `specs/_defaults/changelog.md` under "Deviation Log"

---

## On Exit (After Phase Completes)

### Step 4: Scan for New Decisions

Review your output for any decisions that:
- Are project-wide (would apply to other features)
- Don't exist in registry yet
- Were made during this phase

### Step 5: HITL for Each New Decision

For each new decision detected:

```
Question: "Add [key] = [value] to project defaults?"
Header: "[category]"
Options:
  - Label: "Yes, add to defaults"
    Description: "All future features will use this setting"
  - Label: "No, feature-specific only"
    Description: "Only applies to this feature"
  - Label: "Skip"
    Description: "Don't record this decision"
```

### Step 6: Update Registry with Audit Trail

If user approves adding to registry:

1. **Update `specs/_defaults/registry.yaml`**:
   - Set the key to the new value
   - Update `last_updated` timestamp
   - Update `last_updated_by: human`

2. **Append to `specs/_defaults/changelog.md`**:

```markdown
### YYYY-MM-DD | [key.path]
- **Changed**: `null` → `[new_value]`
- **Why**: [Context from the decision - what problem does this solve?]
- **Source**: specs/[feature-name]/[phase].md
- **Approved by**: Human (accept)
```

3. **Update `applied_to` in registry**:

```yaml
applied_to:
  - feature: [feature-name]
    spec_path: specs/[feature-name]/spec.md
    applied_at: YYYY-MM-DD
```

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| Registry has value | Use it, no questions |
| Registry is null | Ask: "Add to defaults?" |
| Need different value | Ask: "Approve deviation?" + document |
| New decision made | Ask: "Add to registry?" + log if yes |

## AskUserQuestion Templates

### New Default Detected
```
Question: "New project default detected: [key] = [value]. Add to registry?"
Header: "New default"
Options:
  - "Add to project defaults" / "All features will use this"
  - "Keep feature-specific" / "Only this feature"
  - "Reject" / "Don't use this value"
```

### Deviation Request
```
Question: "This spec needs [key] = [value] but registry has [default]. Approve deviation?"
Header: "Deviation"
Options:
  - "Approve deviation" / "I'll provide justification"
  - "Use registry default" / "Use [default] instead"
  - "Update registry" / "Make [value] the new default"
```

### Registry Update Confirmation
```
Question: "Update project registry: [key] = [old] → [new]?"
Header: "Update default"
Options:
  - "Approve update" / "Change the project default"
  - "Keep current" / "Don't change registry"
  - "Different value" / "I'll specify another value"
```
