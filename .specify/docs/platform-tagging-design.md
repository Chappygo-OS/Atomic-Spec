# Platform Tagging for Subagents

## Problem Statement

When building a React Native app, the keyword "React" matches `frontend-developer` (a web React specialist). The agent provides web-only patterns like CSS-in-JS, Tailwind, and browser-specific APIs that do not work on mobile.

**Current matching logic** (keyword similarity only):
```
Spec: "React Native payment screen"
Matches: frontend-developer (has "React" in description)
Result: Wrong patterns, broken code
```

## Solution: Platform-First Filtering

Add a `platform:` field to frontmatter. Filter by platform FIRST, then match by keywords.

---

## 1. Updated Frontmatter Schema

```yaml
---
name: string              # Required. Unique identifier
description: string       # Required. Keywords for matching
model: opus | sonnet      # Required. Model tier
platform:                 # Optional. Omit = universal
  - web                   # Browser-based web apps
  - mobile                # React Native, Flutter, native iOS/Android
  - desktop               # Electron, Tauri, native desktop
  - backend               # Server-side, APIs, databases
  - cli                   # Command-line tools
  - infra                 # CI/CD, deployment, cloud infrastructure
---
```

### Platform Values (Exhaustive List)

| Value | Scope | Examples |
|-------|-------|----------|
| `web` | Browser-based frontend | React (web), Vue, Angular, Next.js SSR |
| `mobile` | Mobile apps | React Native, Flutter, Swift, Kotlin |
| `desktop` | Desktop apps | Electron, Tauri, WPF, macOS native |
| `backend` | Server-side | Node.js APIs, Python services, databases |
| `cli` | Command-line tools | Shell scripts, CLI apps |
| `infra` | Infrastructure | Docker, K8s, CI/CD, Terraform |

### Platform Array Behavior

- **Empty/omitted**: Agent is universal (matches any platform)
- **Single value**: `platform: [web]` - only matches web specs
- **Multiple values**: `platform: [web, mobile]` - matches either

---

## 2. Updated Matching Algorithm

```
FUNCTION match_agents(spec_text, spec_platform):
    agents = scan(".specify/subagents/*.md")

    # STEP 1: Platform filtering (FIRST)
    IF spec_platform is set:
        candidates = []
        FOR agent IN agents:
            IF agent.platform is empty/omitted:
                # Universal agent - always included
                candidates.append(agent)
            ELSE IF spec_platform IN agent.platform:
                # Platform matches
                candidates.append(agent)
            # Otherwise: skip agent (wrong platform)
    ELSE:
        # No platform specified - all agents are candidates
        candidates = agents

    # STEP 2: Keyword matching (on filtered candidates only)
    scored = []
    FOR agent IN candidates:
        score = keyword_similarity(spec_text, agent.description)
        scored.append((agent, score))

    # STEP 3: Return top matches
    scored.sort(by=score, descending=True)
    RETURN scored[:MAX_AGENTS]

FUNCTION keyword_similarity(spec_text, description):
    spec_keywords = extract_keywords(spec_text)
    desc_keywords = extract_keywords(description)
    overlap = intersection(spec_keywords, desc_keywords)
    RETURN len(overlap) / len(spec_keywords)
```

### Platform Detection in Specs

The spec text or metadata should indicate platform:

```yaml
# In spec.md frontmatter
---
platform: mobile
---

# Or detected from keywords in spec text:
# "React Native" -> mobile
# "iOS app" -> mobile
# "browser extension" -> web
# "REST API" -> backend
```

**Keyword-to-platform mapping** (for auto-detection):

| Keywords | Detected Platform |
|----------|-------------------|
| React Native, Expo, mobile app, iOS, Android, Flutter | `mobile` |
| browser, web app, CSS, Tailwind, Next.js (client), Vue, Angular | `web` |
| API, REST, GraphQL, database, server, microservice | `backend` |
| Electron, Tauri, desktop app | `desktop` |
| CI/CD, Docker, Kubernetes, Terraform, deploy | `infra` |
| CLI, command line, terminal, shell | `cli` |

---

## 3. Example: "React Native Payment Screen"

**Spec text**: "Build a payment screen for React Native app with Stripe checkout"

### Step 1: Platform Detection
- Keywords: "React Native" -> platform = `mobile`

### Step 2: Platform Filtering
| Agent | Platform | Included? |
|-------|----------|-----------|
| `frontend-developer` | `[web]` | NO |
| `mobile-developer` | `[mobile]` | YES |
| `payment-integration` | `[backend]` | NO |
| `typescript-pro` | (universal) | YES |
| `ui-ux-designer` | (universal) | YES |

### Step 3: Keyword Matching (on filtered candidates)
| Agent | Keywords Match | Score |
|-------|----------------|-------|
| `mobile-developer` | React Native, mobile, payment, UI | 0.85 |
| `typescript-pro` | TypeScript (implied from RN) | 0.40 |
| `ui-ux-designer` | interface, design | 0.30 |

### Result
1. `mobile-developer` (platform match + keyword match)
2. `typescript-pro` (universal + some keyword match)

**NOT matched**: `frontend-developer` (filtered out by platform)

---

## 4. Agent Platform Classification

### Agents Needing Platform Tags

| Agent | Current State | Recommended Platform | Reason |
|-------|---------------|---------------------|--------|
| `frontend-developer` | universal | `[web]` | CSS/Tailwind/browser-specific |
| `backend-architect` | universal | `[backend]` | Server APIs, databases |
| `deployment-engineer` | universal | `[infra]` | CI/CD, Docker, K8s |
| `database-admin` | universal | `[backend]` | Database operations |
| `database-optimizer` | universal | `[backend]` | Query optimization |
| `data-engineer` | universal | `[backend]` | Data pipelines |
| `payment-integration` | universal | `[backend]` | Stripe webhooks, server-side |
| `api-documenter` | universal | `[backend]` | OpenAPI specs |
| `performance-engineer` | universal | `[backend, web]` | Both server and client perf |

### Agents Staying Universal (No Platform Tag)

| Agent | Reason |
|-------|--------|
| `typescript-pro` | TS works everywhere (web, mobile, backend, desktop) |
| `python-pro` | Python works across platforms |
| `sql-pro` | SQL is platform-agnostic |
| `code-reviewer` | Reviews any code |
| `architect-reviewer` | Reviews any architecture |
| `business-analyst` | Platform-agnostic requirements |
| `ui-ux-designer` | Design principles are cross-platform |
| `error-detective` | Debugging is universal |
| `prompt-engineer` | LLM prompts are platform-agnostic |
| `ai-engineer` | AI/ML code is platform-agnostic |
| `ml-engineer` | ML code is platform-agnostic |
| `data-scientist` | Data analysis is platform-agnostic |

### New Agent Needed

A `mobile-developer` agent should be created for React Native/Flutter work:

```yaml
---
name: mobile-developer
description: Build React Native and Flutter mobile apps. Handle navigation, native modules, platform-specific code, mobile state management. Use PROACTIVELY for mobile app development.
model: opus
platform:
  - mobile
---
```

---

## 5. Updated Frontmatter Examples

### frontend-developer.md (Web-Specific)

```yaml
---
name: frontend-developer
description: Build React components, implement responsive layouts, and handle client-side state management. Optimizes frontend performance and ensures accessibility. Use PROACTIVELY when creating UI components or fixing frontend issues.
model: opus
platform:
  - web
---
```

### backend-architect.md (Backend-Specific)

```yaml
---
name: backend-architect
description: Design RESTful APIs, microservice boundaries, and database schemas for multi-tenant SaaS. Enforces tenant isolation, API contract standards, and scalable patterns. Use PROACTIVELY when creating new backend services or APIs.
model: opus
platform:
  - backend
---
```

### typescript-pro.md (Universal - No Change)

```yaml
---
name: typescript-pro
description: Master TypeScript with advanced types, generics, and strict type safety. Handles complex type systems, decorators, and enterprise-grade patterns. Use PROACTIVELY for TypeScript architecture, type inference optimization, or advanced typing patterns.
model: opus
# platform: omitted = universal
---
```

### performance-engineer.md (Multi-Platform)

```yaml
---
name: performance-engineer
description: Optimize application performance across stack. Profile, benchmark, and fix bottlenecks in frontend, backend, and database layers.
model: opus
platform:
  - web
  - backend
---
```

---

## 6. Backward Compatibility

| Scenario | Behavior |
|----------|----------|
| Agent has no `platform:` field | Treated as universal (matches any platform) |
| Spec has no platform indicator | All agents are candidates (current behavior) |
| Agent has `platform: []` (empty array) | Treated as universal |

**Migration path**: Existing agents work unchanged. Add platform tags incrementally.

---

## 7. Implementation Checklist

- [ ] Update `_template.md` with `platform:` field documentation
- [ ] Update `_index.md` with platform column in registry table
- [ ] Add platform tags to 9 agents (see table above)
- [ ] Create `mobile-developer.md` agent
- [ ] Update matching algorithm in plan.md Phase 0.1
- [ ] Add platform detection from spec keywords
- [ ] Update spec.md frontmatter schema to accept `platform:`
