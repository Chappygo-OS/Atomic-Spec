# Atomic Spec — Site

This is the public website for [Atomic Spec](https://github.com/Chappygo-OS/Atomic-Spec), built with [Astro 5](https://astro.build/), [Tailwind 4](https://tailwindcss.com/), and [MDX](https://mdxjs.com/).

It is deployed at:

> **https://chappygo-os.github.io/atomic-spec/**

The repository root is the framework itself; this `site/` folder contains only the marketing + docs frontend that consumes it.

---

## Local development

Requires Node 20+ and npm 10+.

```bash
# from the repo root
cd site
npm install
npm run dev          # http://localhost:4321/atomic-spec/
```

## Other scripts

| Script           | What it does                                      |
| ---------------- | ------------------------------------------------- |
| `npm run dev`    | Astro dev server with HMR                         |
| `npm run build`  | Static build to `site/dist/`                      |
| `npm run preview`| Preview the production build locally              |
| `npm run check`  | Type-check via `astro check` (no emitted output)  |

## Deployment

Pushed builds of `main` are published to GitHub Pages at the URL above (workflow lands in Phase 4). The `base: '/atomic-spec/'` in `astro.config.mjs` is what makes Pages routing work — never hardcode site paths; use the `withBase()` helper in `src/lib/url.ts`.

## Phase status

- **Phase 1 — scaffold + animated background + base layout** &nbsp;|&nbsp; current
- Phase 2 — port marketing landing from `webpage/`
- Phase 3 — wire technical docs into the site
- Phase 4 — GitHub Pages deploy workflow
- Phase 5 — cleanup + verification

`webpage/` at the repo root is **read-only source** for the future Phase 2 port; nothing inside it is committed or built from `site/`.
