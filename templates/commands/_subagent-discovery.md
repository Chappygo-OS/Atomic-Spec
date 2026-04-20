# Dynamic Subagent Discovery Protocol

> **Shared sub-routine** — referenced by `/atomicspec.plan`, `/atomicspec.tasks`, and `/atomicspec.implement`.
>
> **Constitutional basis**: Per the framework's design (see `CLAUDE.md`), subagents are matched to tasks by **semantic similarity** between task keywords and each agent's `description` frontmatter. Hardcoded `folder → agent` routing tables are **FORBIDDEN** because they break when a consumer project adds new subagents, renames existing ones, or targets a platform (e.g., mobile) whose agent set differs from the web defaults.

---

## When to run this protocol

Whenever a command needs to pick a subagent for a task (planning, task generation, or implementation execution). Do not hardcode agent names in command templates. Do not assume a specific agent exists.

## The protocol

### Step 1 — Scan

List every `**/*.md` file under `.specify/subagents/` recursively. **Exclude** any file whose name starts with `_` (those are shared templates or routing hints, not agents).

### Step 2 — Extract

For every discovered file, read the YAML frontmatter and capture:

- `name` — the subagent identifier
- `description` — what it does and when to use it
- `model` (optional) — preferred model

Build an in-memory list: `[{name, description, path}]`.

### Step 3 — Derive task keywords

From the task under consideration, extract:

- **Objective verbs and nouns** from the task title and description (e.g., "create repository", "add API endpoint", "wire React component")
- **File paths** in "Files to Create / Modify" (e.g., `repositories/`, `routes/`, `components/`, `migrations/`, `workers/`)
- **Technical terms** in the implementation steps (e.g., "SQL", "WebSocket", "OAuth", "Stripe", "push notification", "Core Data")
- **Platform signals** from `plan.md` (e.g., iOS / Android / web / backend) — these narrow the candidate pool

### Step 4 — Match and score

For each candidate agent, score by keyword overlap between the task keywords and the agent `description`:

- Exact keyword match = +3
- Stem / substring match = +1
- Platform mismatch (e.g., iOS task vs. `backend-architect` description) = penalize heavily or exclude
- Tie-break by more specific descriptions (longer word count covering task-specific terms)

Pick the highest-scoring agent. If two or more agents tie within a small margin, prefer the agent whose path is nearer the task's domain folder (e.g., `.specify/subagents/data/` for repository tasks).

### Step 5 — Graceful degradation

If no agent scores above the minimum threshold, or if the subagents directory is absent:

1. Try **station fallback**: read `.specify/knowledge/stations/00-station-map.md` and pick the relevant station for the task domain. Embed station rules directly in the task.
2. If no station matches either, proceed with the task's embedded `plan.md` context alone and note `"No domain agent — using plan.md decisions"` in the task file.

**Never** fail hard because an agent is missing. **Never** guess at an agent name.

---

## Illustrative examples (non-normative)

These examples show how Step 4 resolves on a typical web project. They are NOT a routing table — they only illustrate the scoring shape. In a mobile or backend-only project, the matches will differ.

| Task signal | Likely match (example only) |
| --- | --- |
| Files in `repositories/`, verbs "query", "insert" | An agent with "database", "data access", or "repository pattern" in its description |
| Files in `routes/`, `controllers/`, "REST endpoint" | An agent with "API", "REST", or "microservice" in its description |
| Files in `components/`, `pages/`, "React", "Vue" | An agent with "frontend", "UI", or "component" in its description |
| Files in `payments/`, `stripe/`, "subscription" | An agent with "payment", "Stripe", or "billing" in its description |
| Files in `*.test.*`, "coverage", "TDD" | An agent with "testing", "TDD", or "coverage" in its description |

If a consumer project adds, removes, or renames an agent, these examples automatically stop applying and the scoring on the new description takes over. That is the entire point of dynamic discovery.
