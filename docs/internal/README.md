# Internal Documentation

These are historical and internal planning documents kept in the repository for contributor archaeology and architectural context. **They are not published to the public site at [chappygo-os.github.io/atomic-spec](https://chappygo-os.github.io/atomic-spec/).**

User-facing docs live in `site/src/content/docs/` and are rendered by Astro on every push to `main` via `.github/workflows/site.yml`.

## What's in here

- **`KNOWLEDGE-WIRING-PLAN.md`** — Knowledge Station design decisions and the Plan→Tasks gate ordering rationale (post-implementation, 2026-02).
- **`mobile-extension-audit.md`** — 31-issue gap analysis between the v0.1.0 framework and shipping mobile coverage (2026-03).
- **`mobile-extension-plan.md`** — feature-planning predecessor to the audit; superseded by the shipped implementation but useful for design-decision context.
- **`mobile-subagents-report.md`** — inventory of the 146 mobile-specific subagents organized by lifecycle phase.

## When to add a doc here

Use `docs/internal/` for:

- Historical plans and audits that explain *why* a shipped change is the way it is.
- Triage and gap analyses that aren't useful to end users.
- Notes for contributors that don't belong on the polished public docs site.

If a document is something a user installing or running Atomic Spec would benefit from, it belongs in `site/src/content/docs/` instead.
