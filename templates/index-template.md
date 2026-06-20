# Feature Dashboard: [FEATURE NAME]

**Branch**: `[###-feature-name]`
**Spec**: [Link to spec.md](./spec.md)
**Plan**: [Link to plan.md](./plan.md)
**Matrix**: [Link to traceability.md](./traceability.md)

## Lifecycle Markers

<!--
  Script-managed. Do NOT hand-edit. (v0.3+)
  Populated by scripts/{bash,powershell}/stamp-lifecycle.{sh,ps1} during
  /atomicspec.tasks (when index.md is first generated). Authoring lifecycle
  only — index.md is a dashboard, not implemented code. See Article IX,
  Directive 9. Empty section = legacy / pre-v0.3 artifact, treated as
  `legacy_closed`.
-->

## 📊 Status Overview

| Metric      | Value |
| ----------- | ----- |
| Total Tasks | 0     |
| Completed   | 0     |
| Verified    | 0     |
| Coverage    | 0%    |

## 📚 Knowledge Resources

_Need guidance on specific rules?_

> **[Open the Station Map](../.specify/knowledge/stations/00-station-map.md)** to find the right rulebook (API, Billing, Auth, etc).

## 🧩 Atomic Task List

| ID                              | Story | Description       | Status  | Verification                     |
| ------------------------------- | ----- | ----------------- | ------- | -------------------------------- |
| [T-001](./tasks/T-001-setup.md) | S1    | Project Setup     | 🔴 Todo | `npm test`                       |
| [T-002](./tasks/T-002-model.md) | S1    | Create User Model | 🔴 Todo | `pytest tests/unit/test_user.py` |

<!--
  INSTRUCTIONS FOR AI AGENT (CONTEXT PINNING):
  1. This file is your HOME during `/atomicspec.implement`.
  2. Pick the next "Todo" task.
  3. READ ONLY that task file (e.g., tasks/T-001-setup.md).
  4. Execute the work.
  5. Verify using the command.
  6. Return here and mark as ✅ Done.
-->
