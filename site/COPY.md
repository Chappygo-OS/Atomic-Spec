# Atomic Spec Site — Copy Spec

> Per-component copy for the marketing landing port. Source: `webpage/OLD/components/`. Locked: 2026-04-29.

This document is the single source of truth for all on-page text. Frontend devs porting each React component into Astro should treat the **English target** blocks below as the strings to render. The French source is preserved verbatim for reference and review.

---

## Glossary

| French / Boss term | Atomic Spec term |
|---|---|
| Custom SpecKit | **Atomic Spec** |
| Chaîne de Montage / Chaîne de Montage IA de Précision | Assembly Line |
| Sous-agents / Sous-Agents Spécialisés | Subagents |
| Traçabilité Atomique / Modèle de Traçabilité Atomique | Atomic Traceability Model |
| Point de Contrôle HITL / Checkpoint | HITL checkpoint |
| Vibe Coding / Arrêtez le Vibe Coding | Vibe coding (the slogan is "Stop your AI from vibe-coding") |
| Stations de Connaissance | Knowledge Stations |
| Bouclier Anti-Pollution | Pollution Shield |
| dérive | drift |
| oeillères / œillères | blinders |
| chaîne de montage de précision | precision assembly line |
| Ingénierie IA de Précision | Precision AI Engineering |
| Directives Primaires | Prime Directives (specifically: the **Eight Prime Directives**, Article IX of the constitution) |
| Pollution de Contexte | context pollution |
| Reprise | rework |

---

## Brand voice rules

- **Direct, slightly punchy, anti-fluff.** Match the README. Every sentence earns its place.
- **Name the problem precisely.** Use "drift", "hallucination", "kitchen-sink PRs", "context pollution" — not vague hand-waves.
- **Use concrete numbers.** Eight Prime Directives, four phases, four HITL checkpoints, 18 Knowledge Stations, 21 subagents. Numbers earn credibility; round-ups don't.
- **Technically credible, not preachy.** We're talking to engineers who've reviewed an AI PR and felt the pain. Skip the marketing grandeur.
- **Confident, not hyped.** Avoid "revolutionary", "game-changing", "AI-powered" filler. Make the promise concrete instead: "the agent is *architecturally prevented* from reading `plan.md`".
- **Architect/contract metaphors over magic.** Atomic Spec *enforces* — it doesn't "empower" or "unlock".

---

## Composition order

The Astro `index.astro` should compose sections in this order (matches the boss's flow with one rename of "Solution" → keep):

1. **Hero**
2. **Problem**
3. **Solution**
4. **Manual** (Knowledge Stations)
5. **Agents** (Subagents)
6. **HITL**
7. **ContextPinning**
8. **Workflow**
9. **Footer**

---

## Hero section

### French source (verbatim)
- Eyebrow badge: `Ingénierie de Précision pour le Code IA`
- Headline (typewriter, two lines): `Arrêtez le Vibe Coding.\nCommencez à Construire.`
- Subhead: `Custom SpecKit transforme l'IA imprévisible en une chaîne de montage de précision — avec des points de contrôle humains, une traçabilité atomique, et 21 sous-agents spécialisés.`
- Chaos panel label: `Mode Chaos`
- Chaos panel body: `Pollution de Contexte / Hallucinations / Aucune Gouvernance`
- Order panel label: `Chaîne de Montage`
- Order panel rows: `Point de Contrôle HITL : Approuvé` · `Tâche T-001 : Isolée`
- CTA primary: `Voir Comment Ça Marche →`
- CTA secondary: `Lire le Manuel`

### English target
- Eyebrow badge: `Precision engineering for AI-written code`
- Headline (typewriter, two lines): `Stop your AI from vibe-coding.\nStart shipping atomic specs.`
- Subhead: `Atomic Spec turns unpredictable AI into a governed assembly line — eight Prime Directives, four HITL checkpoints, atomic task files, and 21 specialized subagents.`
- Chaos panel label: `Chaos mode`
- Chaos panel body: `Context pollution / Hallucinations / Zero governance`
- Order panel label: `Assembly Line`
- Order panel rows: `HITL checkpoint: approved` · `Task T-001: pinned`
- CTA primary: `See how it works →`
- CTA secondary: `Read the manual`

### Notes
- Headline mirrors the README's H1 (`Stop your AI from vibe-coding.`) instead of boss's "Stop / Start building" couplet — sharper and aligned with the canonical brand line.
- Subhead replaces "human checkpoints, atomic traceability, 21 specialized subagents" with the actual numbered promises from the README (eight directives, four checkpoints) — this is the value prop in concrete numbers.
- Typewriter effect: animate just the headline, two lines, ~50ms/char with the same blinking caret. Don't typewriter the subhead.
- Chaos panel label "Mode Chaos" → "Chaos mode" (lowercase to feel less marketing-y).
- "Tâche T-001 : Isolée" → "Task T-001: pinned" — uses "pinned" to foreshadow the Context Pinning section.

---

## Problem section

### French source (verbatim)
- Headline: `La Promesse était la Vitesse.` / `La Réalité est la Reprise.` (last word amber)
- Subhead: `"Nous avons construit Custom SpecKit pour combler le fossé entre le chaos créatif et les standards de production."`
- Card 1 — `L'IA Fait des Suppositions`: `Vous avez demandé une API simple. L'IA a décidé que vous avez besoin de PostgreSQL, Redis, Kubernetes et de microservices. Personne ne vous a demandé.`
- Card 2 — `Pollution de Contexte`: `L'IA lit toute votre base de code, est submergée et produit une fonction de 500 lignes qui fait tout et rien de bien.`
- Card 3 — `Aucune Traçabilité`: `"D'où vient ce code ? Quelle exigence remplit-il ?" ...silence. Bonne chance pour le déboguer ou l'étendre.`
- Card 4 — `Le Problème du Câblage`: `Tous les composants construits. Rien de connecté. Routes manquantes. Navigation cassée. "Fonctionnalité complète" mais rien ne fonctionne de bout en bout.`

### English target
- Headline (two lines, last word accent): `The promise was speed.` / `The reality is rework.`
- Subhead: `Atomic Spec exists because one AI-instructions file isn't enough. Soft guidance drifts. Gates don't.`
- Card 1 — `The AI invents requirements`: `You asked for a simple endpoint. The agent decided you also need PostgreSQL, Redis, Kubernetes, and microservices. Nobody asked.`
- Card 2 — `Context pollution`: `The agent reads your whole repo, drowns in it, and ships a 500-line function that does everything and nothing well.`
- Card 3 — `No traceability`: `"Where did this code come from? Which requirement does it satisfy?" Silence. Good luck debugging or extending it.`
- Card 4 — `The wiring problem`: `Every component built. Nothing connected. Missing routes. Broken nav. "Feature complete" — and nothing works end-to-end.`

### Notes
- Subhead deviates from boss's quote ("we built X to bridge the gap between creative chaos and production standards") — that's marketing-speak. The replacement uses the README's actual framing: "one AI-instructions file isn't enough. Soft guidance drifts. Gates don't."
- "Reprise" → "rework" is the standard engineering term and rhymes the cadence with "speed".
- Card titles tightened: dropped articles ("L'IA / Le Problème").

---

## Solution section

### French source (verbatim)
- Eyebrow: `LA SOLUTION`
- Headline: `Modèle de Traçabilité Atomique`
- Subhead: `Un cadre de gouvernance qui transforme l'IA d'un outil créatif imprévisible en un système de production fiable.`
- Pillar 1 — `Gouvernance Constitutionnelle`: `Chaque décision de l'IA est liée par une Constitution — des règles immuables qui ne peuvent être contournées.` Bullets: `Cohérence à travers les fonctionnalités` · `"Directives Primaires" Immuables`
- Pillar 2 — `Points de Contrôle HITL`: `L'IA propose. Les humains approuvent. Aux points de décision critiques, le système S'ARRÊTE.` Bullets: `Pas de suppositions silencieuses` · `Validation du stack technique` · `Approbation UI/UX`
- Pillar 3 — `Décomposition en Tâches Atomiques`: `Au lieu d'une liste de tâches monolithique, chaque fonctionnalité se décompose en fichiers de tâches isolés.` Bullets: `Focus sur une exigence unique` · `Commandes de vérification incluses` · `Exécution en contexte isolé`

### English target
- Eyebrow: `THE SOLUTION`
- Headline: `The Atomic Traceability Model`
- Subhead: `A governance framework that turns the AI from an unpredictable collaborator into a system that ships consistent, traceable code — feature after feature.`
- Pillar 1 — `Constitutional governance`: `Every AI decision is bound by a constitution. Article IX hardcodes the eight Prime Directives — non-negotiable rules every command enforces.` Bullets: `Consistency across features` · `Eight immutable Prime Directives` · `Project Defaults Registry as source of truth`
- Pillar 2 — `HITL checkpoints`: `The AI proposes. Humans approve. At four critical decision points, the system STOPS until you sign off.` Bullets: `No silent assumptions` · `Tech stack review` · `Validation review` · `UI/UX approval` · `Registry sync`
- Pillar 3 — `Atomic task decomposition`: `Instead of one monolithic tasks.md, every feature explodes into isolated T-XXX files. The agent reads only the current task — by design.` Bullets: `One requirement per file` · `Embedded context (registry + domain rules + gate criteria)` · `Verification command included` · `Context Pinning during implementation`

### Notes
- Pillar 1 promotes the "Eight Prime Directives" from a generic "rules immuables" — boss's component buried this; we lead with it because it's our actual differentiator.
- Pillar 2 corrects the HITL count to **4** checkpoints (boss says "critical decision points" without a number; the README and Article IX cite four: Tech Stack, Validation, UI, Registry Sync). Bullet list matches the four checkpoint names plus the "no silent assumptions" framing.
- Pillar 3 names `tasks.md` and `T-XXX` explicitly — this is the Atomic Injunction (Directive 2), and the visual specificity is part of the brand.

---

## Manual section (Knowledge Stations)

### French source (verbatim)
- Headline: `Le Manuel de la Chaîne de Montage`
- Subhead: `18 Stations de Connaissance qui capturent l'expertise du domaine. L'IA ne "devine" plus. Elle suit votre standard d'ingénierie, étape par étape.`
- Sidebar phase headers: `Fondation (01-02)` · `Spécification (03-05)` · `Architecture (06-08)` · `Fondamentaux SaaS (09-11)` · `Opérations (12-14)` · `Échelle (15-18)`
- Detail pane chrome: `Station {id}` · `Standard` · `Critères de Passage (Gate)` · `Livrables Requis` · `Pourquoi c'est vital`
- Bottom callout (per station): `Ignorer la Station {id} crée de la dette technique immédiate. L'IA sans ce contexte produira du code fonctionnel mais non-maintenable.`
- Empty state: `Sélectionnez une station pour voir les standards.`

#### Stations (ID, name, description, deliverables, gate criteria — all verbatim French)

- **01 — Rôles & Propriété**: `Définition explicite de la matrice RACI et des propriétaires techniques.` Deliverables: `roles.md`, `team_structure.yaml`. Gates: `Chaque domaine a un propriétaire unique` · `Les niveaux d'escalade sont définis` · `Les accès aux repos sont audités`.
- **02 — Objectifs Système**: `Alignement sur les KPI techniques et contraintes architecturales.` Deliverables: `goals.md`, `constraints.md`. Gates: `Budget de latence défini` · `Objectifs de disponibilité (SLA) fixés` · `Contraintes de conformité (GDPR/SOC2) listées`.
- **03 — Découverte**: `Collecte brute des exigences et définition du problème.` Deliverables: `discovery.md`, `problem_statement.md`. Gates: `Le problème utilisateur est validé` · `Les anti-objectifs (ce qu'on ne fait pas) sont listés`.
- **04 — Règles PRD**: `Conversion des besoins en spécifications techniques structurées.` Deliverables: `prd.md`, `acceptance_criteria.md`. Gates: `Aucune ambiguïté sémantique` · `Critères d'acceptation Gherkin (Given/When/Then)` · `Dépendances inter-équipes identifiées`.
- **05 — Flux Utilisateurs**: `Cartographie visuelle des parcours critiques (Happy & Unhappy paths).` Deliverables: `flows.mermaid`, `states.json`. Gates: `Tous les états d'erreur sont cartographiés` · `Pas de culs-de-sac UX` · `Diagrammes Mermaid valides`.
- **06 — Contrats API**: `Définition stricte des interfaces avant toute implémentation.` Deliverables: `openapi.yaml`, `error_catalog.md`. Gates: `Schémas de réponse d'erreur standardisés` · `Stratégie de pagination (Curseur vs Offset)` · `Versionnage d'API défini`.
- **07 — Modèles de Données**: `Conception du schéma de base de données et relations.` Deliverables: `schema.prisma`, `migrations_plan.md`. Gates: `Normalisation 3NF respectée (sauf exception documentée)` · `Indices de performance définis` · `Stratégie de suppression (Soft vs Hard delete)`.
- **08 — Auth & RBAC**: `Matrice de sécurité et contrôle d'accès basé sur les rôles.` Deliverables: `auth_policy.md`, `permissions_matrix.csv`. Gates: `Moindre privilège par défaut` · `Isolation multi-tenant validée` · `Scopes JWT définis`.
- **09 — Facturation & Quotas**: `Intégration de la monétisation et des limites d'utilisation.` Deliverables: `pricing_model.json`, `metering_hooks.ts`. Gates: `Idempotence des webhooks Stripe` · `Gestion gracieuse des échecs de paiement` · `Limitation de débit (Rate Limiting) par tiers`.
- **10 — Observabilité**: `Stratégie de journalisation, traçage et métriques.` Deliverables: `logging_config.ts`, `dashboards.json`. Gates: `Pas de PII dans les logs` · `Tracing distribué (OpenTelemetry) activé` · `Alertes de santé définies`.
- **11 — Notifications**: `Gestion des emails transactionnels et in-app.` Deliverables: `email_templates.html`, `notification_routing.json`. Gates: `Support du désabonnement (Unsubscribe)` · `Templates responsives testés` · `Gestion des files d'attente d'envoi`.
- **12 — CI/CD & GitOps**: `Pipelines de déploiement et gestion des environnements.` Deliverables: `ci.yml`, `deployment_strategy.md`. Gates: `Tests bloquants sur PR` · `Analyses statiques (Lint/Sonar) activées` · `Rollback automatique en cas d'échec`.
- **13 — Sécurité & Audit**: `Scan de vulnérabilités et conformité.` Deliverables: `audit_log_schema.json`, `security_headers.conf`. Gates: `Headers OWASP configurés` · `Dépendances scannées (Snyk/Dependabot)` · `Logs d'audit immuables`.
- **14 — Cycle de Vie Données**: `Stratégies de sauvegarde, rétention et nettoyage.` Deliverables: `backup_policy.md`, `retention_jobs.sql`. Gates: `RPO/RTO définis et testés` · `Encryption au repos activée` · `Anonymisation des environnements de staging`.
- **15 — Performance**: `Mise en cache, CDN et optimisation des requêtes.` Deliverables: `caching_strategy.md`, `cdn_rules.json`. Gates: `Stratégie d'invalidation de cache définie` · `Optimisation des images/assets` · `Requêtes N+1 détectées et résolues`.
- **16 — Analytique Produit**: `Plan de marquage et entonnoirs de conversion.` Deliverables: `tracking_plan.json`, `events_schema.ts`. Gates: `Nommage d'événements cohérent (Object-Action)` · `Propriétés utilisateur vs événement distinguées` · `Respect du consentement (Cookies)`.
- **17 — Outils Admin**: `Back-office pour le support et la gestion.` Deliverables: `admin_panel_specs.md`, `support_playbook.md`. Gates: `Audit logs sur toutes les actions admin` · `Pas de suppression directe en DB` · `Accès admin protégé par MFA`.
- **18 — Documentation**: `Documentation technique et utilisateur final.` Deliverables: `readme.md`, `api_docs.json`, `user_guide.md`. Gates: `Exemples de code testables` · `Documentation API générée automatiquement` · `Diagrammes d'architecture à jour`.

### English target
- Headline: `The Assembly Line Manual`
- Subhead: `18 Knowledge Stations encode domain expertise as gate criteria. The AI stops guessing — it follows your engineering standard, station by station.`
- Sidebar phase headers: `Foundation (01–02)` · `Specification (03–05)` · `Architecture (06–08)` · `SaaS Fundamentals (09–11)` · `Operations (12–14)` · `Scale (15–18)`
- Detail pane chrome: `Station {id}` · `Standard` · `Gate criteria` · `Required deliverables` · `Why it matters`
- Bottom callout (per station): `Skip Station {id} and you ship technical debt on day one. Without this context, the AI produces code that runs and can't be maintained.`
- Empty state: `Select a station to view its standard.`

#### Stations (English, with Atomic Spec station-name alignment)

The README's official station list uses slightly different names from boss's component. We **prefer the README names** because they match `.specify/knowledge/stations/` filenames. Boss's descriptions and gate criteria are good — port them as-is.

- **01 — Introduction**: `Manual overview, Assembly Line concept, how stations gate phase transitions.` Deliverables: `roles.md`, `team_structure.yaml` *(boss's content fits "Roles" not "Introduction" — see Open Questions)*. Gates: `Every domain has a single owner` · `Escalation paths are defined` · `Repo access is audited`.
- **02 — Roles & Ownership**: `RACI matrix, gate responsibilities, technical ownership.` Deliverables: `goals.md`, `constraints.md` *(see Open Questions — boss's "Objectifs Système" does not match station 02 in the README)*. Gates: `Latency budget set` · `SLA availability targets agreed` · `Compliance constraints (GDPR/SOC2) listed`.
- **03 — Discovery**: `ICP, JTBD, wedge, competitor pain mining — raw requirement capture.` Deliverables: `discovery.md`, `problem_statement.md`. Gates: `User problem validated` · `Anti-goals (what we won't ship) listed`.
- **04 — PRD Spec**: `Convert needs into structured technical specifications. MVP scope, SaaS rules, acceptance criteria.` Deliverables: `prd.md`, `acceptance_criteria.md`. Gates: `No semantic ambiguity` · `Gherkin acceptance criteria (Given/When/Then)` · `Cross-team dependencies identified`.
- **05 — User Flows**: `Visual mapping of critical paths — happy and unhappy. Edge states, RBAC, information architecture.` Deliverables: `flows.mermaid`, `states.json`. Gates: `Every error state mapped` · `No UX dead-ends` · `Mermaid diagrams validate`.
- **06 — API Contracts**: `Define interfaces strictly before any implementation. OpenAPI, error schema, idempotency.` Deliverables: `openapi.yaml`, `error_catalog.md`. Gates: `Standardized error response schemas` · `Pagination strategy chosen (cursor vs offset)` · `API versioning defined`.
- **07 — Data Architecture**: `Schema design, relations, tenancy model, isolation, ADRs.` Deliverables: `schema.prisma`, `migrations_plan.md`. Gates: `3NF normalization (or documented exception)` · `Performance indices defined` · `Deletion strategy (soft vs hard)`.
- **08 — Auth & RBAC**: `Security matrix and role-based access control. Session/JWT, permissions, hardening.` Deliverables: `auth_policy.md`, `permissions_matrix.csv`. Gates: `Least privilege by default` · `Multi-tenant isolation validated` · `JWT scopes defined`.
- **09 — Billing**: `Stripe integration, webhooks, state machine.` Deliverables: `pricing_model.json`, `metering_hooks.ts`. Gates: `Stripe webhooks idempotent` · `Graceful payment failure handling` · `Per-tier rate limiting`.
- **10 — Metering & Limits**: `Usage tracking, quotas, cost control.` Deliverables: *(boss merged this with Observability — port as listed but flag in Open Questions)*. Gates: TBD — see Open Questions.
- **11 — Observability**: `Logging, tracing, alerting, runbooks.` Deliverables: `logging_config.ts`, `dashboards.json`. Gates: `No PII in logs` · `Distributed tracing (OpenTelemetry) on` · `Health alerts defined`.
- **12 — CI/CD & Release**: `Pipelines, environments, migrations, blocking tests.` Deliverables: `ci.yml`, `deployment_strategy.md`. Gates: `Blocking tests on PRs` · `Static analysis (lint/Sonar) enabled` · `Automatic rollback on failure`.
- **13 — Security**: `Threat model, baseline, AppSec workflow, audit.` Deliverables: `audit_log_schema.json`, `security_headers.conf`. Gates: `OWASP headers configured` · `Dependencies scanned (Snyk/Dependabot)` · `Audit logs immutable`.
- **14 — Data Lifecycle**: `Retention, GDPR, backups, deletion.` Deliverables: `backup_policy.md`, `retention_jobs.sql`. Gates: `RPO/RTO defined and tested` · `Encryption at rest enabled` · `Staging environments anonymized`.
- **15 — Performance**: `Latency targets, caching, CDN, query optimization, load testing.` Deliverables: `caching_strategy.md`, `cdn_rules.json`. Gates: `Cache invalidation strategy defined` · `Image/asset optimization` · `N+1 queries detected and resolved`.
- **16 — Analytics**: `Event tracking, funnels, dashboards.` Deliverables: `tracking_plan.json`, `events_schema.ts`. Gates: `Consistent event naming (Object-Action)` · `User vs event properties distinguished` · `Cookie consent respected`.
- **17 — Admin Tooling**: `Support panel, playbooks, audit logging.` Deliverables: `admin_panel_specs.md`, `support_playbook.md`. Gates: `Audit logs on every admin action` · `No direct DB deletes` · `MFA on admin access`.
- **18 — Documentation**: `PRD/ADR templates, repo structure, technical and end-user docs.` Deliverables: `readme.md`, `api_docs.json`, `user_guide.md`. Gates: `Code examples are testable` · `API docs auto-generated` · `Architecture diagrams up to date`.

### Notes
- We rename phase groupings to match the README's tone: "Spécification" → "Specification" (not "Spec"), "Échelle" → "Scale".
- The "Why it matters" callout was rewritten to drop the slightly preachy "ignorer la Station X" pattern and instead state the failure mode bluntly: code that runs and can't be maintained.
- See Open Questions for station-name mismatches between boss's component and the README's canonical list.

---

## Agents section

### French source (verbatim)
- Headline: `21 Sous-Agents Spécialisés`
- Subhead: `Une IA généraliste prétend tout savoir. Nos spécialistes le savent vraiment. Chargés dynamiquement selon la tâche.`
- Bottom badge: `Et 13 autres spécialistes attendant dans .specify/subagents/`
- Cards (8 shown):
  1. `backend-architect` — Backend — `Conventions REST, isolation des tenants, schémas API.`
  2. `database-optimizer` — Database — `Normalisation de schéma, stratégies d'indexation.`
  3. `frontend-developer` — Frontend — `Composition de composants, gestion d'état.`
  4. `security-auditor` — Sécurité — `Contrôles OWASP, analyse de vulnérabilité.`
  5. `deployment-engineer` — DevOps — `Pipelines CI/CD, conteneurisation.`
  6. `ux-designer` — Frontend — `Flux utilisateurs, normes d'accessibilité.`
  7. `payment-integration` — Business — `Modèles d'intégration Stripe/LemonSqueezy.`
  8. `ai-engineer` — IA — `Systèmes RAG, prompt engineering.`

### English target
- Headline: `21 specialized subagents. Matched dynamically.`
- Subhead: `Generalist AI pretends to know every domain. Our specialists actually do. Subagents are discovered by scanning YAML frontmatter and matched to your feature's keywords — not hard-coded.`
- Bottom badge: `Plus 13 more waiting in .specify/subagents/ — and you can drop in your own.`
- Cards (8 shown — keep the same eight, English descriptions tightened):
  1. `backend-architect` — Backend — `REST conventions, tenant isolation, API schemas.`
  2. `database-optimizer` — Database — `Schema normalization, indexing strategies.`
  3. `frontend-developer` — Frontend — `Component composition, state management.`
  4. `security-auditor` — Security — `OWASP controls, vulnerability analysis.`
  5. `deployment-engineer` — DevOps — `CI/CD pipelines, containerization.`
  6. `ui-ux-designer` — Frontend — `User flows, accessibility (WCAG).`
  7. `payment-integration` — Billing — `Stripe and LemonSqueezy integration patterns.`
  8. `ai-engineer` — AI/ML — `RAG systems, prompt engineering.`

### Notes
- Boss has `ux-designer`. The actual filename in `.specify/subagents/frontend/` is **`ui-ux-designer.md`** — corrected.
- The subhead expands "loaded dynamically by task" into the actual mechanism: keyword overlap against YAML frontmatter `description`. This is a real differentiator vs. hard-coded agent lists in other tools.
- Bottom badge adds "and you can drop in your own" — emphasizes extensibility (matches the "Adding Custom Agents" section of the README).

---

## ContextPinning section

### French source (verbatim)
- Headline: `Context Pinning : Le Bouclier Anti-Pollution`
- Subhead: `La sagesse conventionnelle dit que l'IA a besoin de plus de contexte. Nous ne sommes pas d'accord. Trop de contexte cause de la dérive. Nous forçons l'IA à porter des œillères.`
- Toggle labels: `Pollué` / `Épinglé`
- Code header (off): `Contexte Pollué`
- Code header (on): `Contexte Épinglé`
- Off-state code (Python comments): `# Tâche : Créer le Modèle User / # L'IA lit TOUT le plan, voit "tableau de bord admin" mentionné plus tard / # Résultat : Sur-ingénierie Massive` followed by an oversized `User` model with `role`, `last_login`, `login_count`, `preferences`, `permissions`, `stripe_id`, "...15 colonnes de plus non nécessaires pour le moment".
- On-state code: `# Tâche : Créer le Modèle User / # L'IA lit SEULEMENT T-010-create-user-model.md / # Résultat : Implémentation Propre et Ciblée`, minimal `User` model with comments `# Rôles ajoutés dans T-015 / # Analytique ajouté dans T-020 / # Facturation ajoutée dans T-025`.
- Constraint table: `Contraintes d'Accès en Lecture` · rows: `Tâche Actuelle → T-XXX.md` (allowed) · `Spec Complète (Plan.md) → BLOQUÉ` · `Autres Tâches → BLOQUÉ`.
- Quote: `"Pourquoi interdire plan.md ? Parce que si l'IA voit 'Futur Panneau Admin', elle essaiera de le construire aujourd'hui. L'épinglage la force à construire UNIQUEMENT ce qui est nécessaire maintenant."`

### English target
- Headline: `Context Pinning — the pollution shield`
- Subhead: `Conventional wisdom says AI needs more context. We disagree. Too much context causes drift. During implementation, the agent is *architecturally prevented* from reading anything outside the current task file — by design.`
- Toggle labels: `Polluted` / `Pinned`
- Code header (off): `Context: polluted`
- Code header (on): `Context: pinned`
- Off-state code (Python comments): `# Task: Create the User model / # AI reads the FULL plan, sees "admin dashboard" mentioned later / # Result: massive over-engineering` then bloated `User` model with the same fields (`role`, `last_login`, `login_count`, `preferences`, `permissions`, `stripe_id`, `# ...15 more columns we don't need yet`).
- On-state code: `# Task: Create the User model / # AI reads ONLY T-010-create-user-model.md / # Result: clean, focused implementation`, minimal `User` model with comments `# Roles added in T-015 / # Analytics added in T-020 / # Billing added in T-025`.
- Constraint table: `Read access (Directive 3)` · rows: `Current task → T-XXX.md` (✓ allowed) · `Full plan (plan.md) → BLOCKED` · `Spec (spec.md) → BLOCKED` · `Other task files → BLOCKED`.
- Quote: `"Why forbid plan.md? Because if the AI sees 'future admin panel', it will try to build it today. Pinning forces the agent to build only what this task needs — and nothing else."`

### Notes
- Subhead replaces "we force the AI to wear blinders" with the README's actual phrasing: *architecturally prevented*. Stronger and more precise — it's not a polite request.
- Constraint table now shows **three** blocked sources (plan.md, spec.md, other tasks) to match Article IX, Directive 3 verbatim. Boss's component only listed two.
- "Read access (Directive 3)" cross-references the Eight Prime Directives — reinforces governance branding throughout the page.

---

## HITL section

### French source (verbatim)
- Headline: `Le Moment Où Tout Change`
- Subhead: `La plupart du codage IA échoue quand les modèles prennent des décisions silencieuses. Les points de contrôle HITL inversent cela. L'IA propose, puis S'ARRÊTE. Vous examinez. Vous approuvez. Seulement alors elle construit.`
- Step 1 button title: `HITL #1 : Stack Technique` — desc: `Revoir les décisions technologiques avant le début de la conception.`
- Step 2 button title: `HITL #2 : Validation` — desc: `Détecter tôt les problèmes de sécurité et de compatibilité.`
- Step 3 button title: `HITL #3 : Specs UI` — desc: `Définir les systèmes de design pour éviter la dérive UI.`
- Terminal command line: `$ speckit plan --interactive`
- Terminal step 1 body header: `🛑 REVUE DU STACK TECHNIQUE - Point de Contrôle Phase 0.5` (full content as shown in source).
- Terminal step 2 body header: `🔍 REVUE DE VALIDATION - Point de Contrôle Phase 0.7` (full content as shown).
- Terminal step 3 body header: `🎨 SPECS FRONTEND/UI - Point de Contrôle Phase 0.8` (full content as shown).
- Approve button: `Approuver & Continuer`

### English target
- Headline: `This is where the AI stops.`
- Subhead: `Most AI coding fails because the model makes silent decisions. HITL checkpoints flip that. The agent proposes, then HALTS. You review. You approve. Only then does it build.`
- Step 1 button title: `HITL #1 — Tech stack` — desc: `Review every tech decision before design begins.`
- Step 2 button title: `HITL #2 — Validation` — desc: `Catch security and compatibility issues before they ship.`
- Step 3 button title: `HITL #3 — UI specs` — desc: `Pin the design system before the AI drifts on UI choices.`
- (Add a fourth tab if room allows, see Open Questions) Step 4: `HITL #4 — Registry sync` — desc: `Promote new decisions into the Project Defaults Registry.`
- Terminal command line: `$ atomicspec plan --interactive`
- Terminal step 1 body — header: `🛑 TECH STACK REVIEW — Phase 0.5 checkpoint`
  Body:
  ```
  Resolved decisions:
  | Decision     | Value          | Source   |
  |--------------|----------------|----------|
  | Language     | Python 3.11    | Spec     |
  | Framework    | FastAPI        | Spec     |
  | Database     | PostgreSQL 15  | Assumed  |
  | ORM          | SQLAlchemy 2.0 | Assumed  |

  ⚠ ASSUMPTIONS:
  - PostgreSQL chosen over SQLite for multi-tenant support
  - SQLAlchemy chosen for async compatibility

  Your options:
  1. [Approve all] — proceed with these choices
  2. [Revise] — change Database to SQLite
  3. [Reject] — start over
  ```
- Terminal step 2 body — header: `🔍 VALIDATION REVIEW — Phase 0.7 checkpoint`
  Body:
  ```
  Status: PASS_WITH_WARNINGS

  | Package    | Version | Status | Issue                  |
  |------------|---------|--------|------------------------|
  | FastAPI    | 0.104.1 | WARN   | Security patch 0.105   |
  | Pydantic   | 2.5.2   | OK     | -                      |

  ⚠ FastAPI 0.104.1 has a known CORS vulnerability.
     Recommendation: upgrade to 0.105.0

  Your options:
  1. [Accept rec] — upgrade to 0.105.0
  2. [Ignore] — document risk and continue
  3. [More info] — explain the vulnerability
  ```
- Terminal step 3 body — header: `🎨 UI SPECS — Phase 0.8 checkpoint`
  Body:
  ```
  Frontend work detected. Let's pin the standards.

  1. UI component library?
     > Tailwind + Headless UI (recommended)
       Material UI
       Shadcn/ui
       Chakra UI

  2. State management?
     > React Context + Hooks (recommended for MVP)
       Zustand
       Redux Toolkit

  3. Additional requirements?
     [x] Dark mode support
     [ ] Accessibility (WCAG 2.1 AA)
  ```
- Approve button: `Approve & continue`

### Notes
- Headline "Le Moment Où Tout Change" was poetic; the English flips it to a load-bearing claim: "This is where the AI stops." — matches the brand's anti-fluff tone and previews the visual (terminal halt).
- Terminal command renamed `speckit plan` → `atomicspec plan` to match the actual CLI binary.
- Boss only documents 3 HITL checkpoints in this section, but the constitution mandates 4 (Phase 0.5 / 0.7 / 0.8 / 0.9). Step 4 (Registry sync) is added as optional copy if the design has room — otherwise note "+1 more: Registry sync — see the Workflow section" in the subhead. Flagged in Open Questions.

---

## Workflow section

### French source (verbatim)
- Headline: `La Chaîne de Montage Complète`
- Step 1 — `1. Spécifier` — desc: `Rôles, Objectifs, Découverte` — output: `Sortie : spec.md`
- HITL #1 badge between steps 1 and 2
- Step 2 — `2. Planifier` — desc: `Architecture & Recherche` — output: `Sortie : plan.md`
- HITL #2 badge between steps 2 and 3
- Step 3 — `3. Exécuter` — desc: `Tâches Atomiques & Tests` — output: `Sortie : Code Propre`
- Footer note: `Note : Si un rejet se produit à un point HITL, le processus boucle automatiquement vers l'étape précédente. Pas d'état corrompu.`

### English target
- Headline: `The full Assembly Line`
- Step 1 — `1. Specify` — desc: `Discovery, requirements, gates 03–05` — output: `Output: spec.md`
- HITL #1 badge between steps 1 and 2
- Step 2 — `2. Plan` — desc: `Architecture, research, registry sync` — output: `Output: plan.md`
- HITL #2 badge between steps 2 and 3
- Step 3 — `3. Tasks` — desc: `Atomic decomposition, embedded context` — output: `Output: tasks/T-XXX-*.md`
- HITL #3 badge between steps 3 and 4 *(if visual room allows — see Notes)*
- Step 4 — `4. Implement` — desc: `Context-Pinned execution, verification commands` — output: `Output: shipped code + traceability.md`
- Footer note: `Reject at any HITL checkpoint and the workflow loops back to the previous phase automatically. No corrupted state. No half-built features.`

### Notes
- Boss's component shows three steps; Atomic Spec actually has **four** phases (specify → plan → tasks → implement). The "Tasks" phase is non-trivial (Atomic Injunction lives there) and we should not collapse it into "Plan". If the visual must stay 3-up, fold tasks into Plan and rename Step 3 to "Implement" with desc `Atomic tasks + Context-Pinned execution`. Flagged in Open Questions.
- Step descriptions now include gate ranges and concrete outputs — gives engineers something to verify against.
- Footer note keeps boss's good "no corrupted state" line and adds "no half-built features" — echoes the Problem section's "wiring problem" card.

---

## Footer section

### French source (verbatim)
- Brand: `Custom SpecKit`
- Tagline: `Ingénierie IA de Précision.`
- Links: `GitHub` (https://github.com/custom-speckit) · `LinkedIn` (boss's personal LI) · `Educasium` (https://educasium.com/)
- Copyright: `© {year} Custom SpecKit. Tous droits réservés.`

### English target
- Brand: `Atomic Spec`
- Tagline: `Precision engineering for AI-written code.`
- Links:
  - `GitHub` → `https://github.com/Chappygo-OS/Atomic-Spec`
  - `PyPI` → `https://pypi.org/project/atomic-spec/`
  - `Docs` → `/docs/quickstart` (anchor or route — TBD by site IA)
  - `LinkedIn` (Pablo Nastar — keep boss's URL)
- Copyright: `© {year} Atomic Spec contributors. MIT-licensed. Forked from github/spec-kit.`

### Notes
- GitHub URL repointed to the canonical repo (`Chappygo-OS/Atomic-Spec`). The `custom-speckit` org doesn't exist publicly.
- Added PyPI link — primary install path is `uv tool install atomic-spec`, so the package page is a high-value link.
- Added Docs link as placeholder — site IA will resolve the actual route during Phase 3.
- Removed `Educasium` (boss's external brand) unless explicitly requested.
- Copyright credits the contributor base + acknowledges the upstream fork relationship per the README's Prior Art section. "All rights reserved" is wrong for an MIT-licensed project.

---

## Open questions

1. **Manual stations 01/02 mismatch.** Boss labelled stations 01 = "Rôles & Propriété" and 02 = "Objectifs Système", but the README/canonical list has 01 = "Introduction" and 02 = "Roles & Ownership". The deliverables boss listed (`roles.md`, `team_structure.yaml`) actually fit station 02 in the README. Decision needed: keep boss's content under the README's official names (which is what this spec does, but it creates content-vs-name mismatches), or write fresh content for stations 01–02 that matches the README.
2. **Station 10 missing in boss's list.** Boss has 11 stations between 01–11, then 12–18. The README has 18 stations including 10 = "Metering & Limits" and 11 = "Observability" as separate entries. Boss merged metering into observability. Decision: write fresh copy for Station 10 (Metering & Limits) before launch, or ship the manual with stations 01–09, 11–18 only.
3. **HITL count: 3 vs. 4.** Boss's HITL section shows three checkpoints; the constitution mandates four (Tech Stack 0.5, Validation 0.7, UI 0.8, Registry Sync 0.9). The English target above includes step 4 as optional. Confirm whether to add the 4th step UI to the layout or call it out only in subhead.
4. **Workflow: 3 steps vs. 4 phases.** Boss's Workflow section shows three steps (Specify / Plan / Execute), but the actual phase pipeline is four-step (specify → plan → tasks → implement). Decision: redesign visual for 4 columns (preferred), or fold tasks into the Implement step.
5. **"21 subagents" — verify count.** The README claims 21 specialized subagents (default, non-mobile). Repo scan shows ~22 base subagents distributed across `ai/`, `backend/`, `business/`, `data/`, `devops/`, `frontend/`, `languages/`, `mobile/` (top-level), `review/`. The "21" number is consistent enough across the README and the boss's component to keep. Mobile-specific count (146+) is intentionally not surfaced on the landing page.
6. **CTA destinations.** "See how it works" should anchor to `#solution` or `#workflow`. "Read the manual" should anchor to `#manual` (Knowledge Stations) — confirm with site IA.
7. **`speckit` vs `atomicspec` CLI binary.** Boss's terminal mock-up shows `$ speckit plan`. The actual binary is `atomicspec`. The English target uses `atomicspec`. Confirm before locking.
8. **"Custom SpecKit" GitHub URL is dead.** `https://github.com/custom-speckit` doesn't resolve to an existing org. Repointed to `https://github.com/Chappygo-OS/Atomic-Spec`. Confirm canonical URL.
9. **Footer LinkedIn.** Kept Pablo Nastar's personal LinkedIn from the boss's component. Confirm whether to keep, replace with a project/org LinkedIn, or drop.
10. **Solution Pillar 2 bullets.** Bullets list five items (No silent assumptions / Tech stack review / Validation review / UI/UX approval / Registry sync). If the visual is constrained to 3 bullets, drop "No silent assumptions" (covered in body) and keep the four checkpoint names.
