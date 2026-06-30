# ADR-0039 Phase 2b — Astro site scaffold

You are working in the RingDrill repository. Implement Phase 2b of [ADR-0039](../adrs/0039-site-pwa-api-origins.md). ADR-0039 is accepted and authoritative. Read the "Topology" and "Site source" sections before starting.

Phase 2b creates a minimal Astro project at `site/` that can be deployed to Cloudflare Pages later (Phase 2c). The scaffold has bilingual landing pages and serves the `.well-known/*` files needed for Universal Links and App Links to survive the apex move in Phase 3.

## Scope

A new top-level `site/` directory with an Astro project. No changes to existing Flutter, Netlify, or other code. The site is deployable but not yet wired to a Cloudflare project — that comes in Phase 2c.

Phase 2b is intentionally minimal. Catalog browse, slug previews, brief previews, privacy, terms and the full visual design are iterated on in later prompts. Phase 2b just needs a buildable deployable artifact.

## Steps

### Step 1 — Astro project scaffold

Create `site/` at the repo root with:

```
site/
  astro.config.mjs
  package.json
  package-lock.json (committed)
  tsconfig.json
  public/
    .well-known/
      assetlinks.json
      apple-app-site-association
  src/
    layouts/
      BaseLayout.astro
    pages/
      index.astro          # nb landing
      en/
        index.astro        # en landing
```

`astro.config.mjs` configures i18n:

```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://ringdrill.app',
  i18n: {
    defaultLocale: 'nb',
    locales: ['nb', 'en'],
    routing: {
      prefixDefaultLocale: false,
    },
  },
});
```

`package.json` pins Astro to a recent stable major version (`^5` or whatever is current and known good). Include `astro` as a dev dependency. No additional UI libraries for now — plain CSS is fine.

`tsconfig.json` extends `astro/tsconfigs/strict`.

Commit: `feat(site): scaffold Astro project with bilingual i18n routing`. Verify `git status` is clean.

### Step 2 — `.well-known` files

Copy `web/.well-known/assetlinks.json` to `site/public/.well-known/assetlinks.json`, byte-identical. Astro serves anything under `public/` verbatim into `dist/`, so the deploy will preserve the exact bytes.

`apple-app-site-association` does not exist under `web/.well-known/` yet (see ADR-0021). If it is missing in the repo, write a placeholder note in the prompt context and skip. Otherwise copy it the same way.

Verify after `npm run build` that `site/dist/.well-known/assetlinks.json` is byte-identical to the source. A small Node script or a `cmp` invocation in the verification step is fine.

Commit: `feat(site): copy .well-known files into Astro public directory`. Verify `git status` is clean.

### Step 3 — `BaseLayout.astro`

Build a minimal layout component at `site/src/layouts/BaseLayout.astro` that:

* Sets `<html lang>` from a `lang` prop
* Includes `<meta charset>`, `<meta viewport>`, basic `<meta description>` (passed as prop)
* Adds `<link rel="alternate" hreflang>` entries linking the page to its locale sibling
* Has a single slot for page body
* Imports a global CSS file with reset and brand-neutral typography

Keep it under 80 lines. No nav, no footer for Phase 2b — those come later.

Commit: `feat(site): add BaseLayout with hreflang and basic meta`. Verify `git status` is clean.

### Step 4 — Landing pages

`site/src/pages/index.astro` (Norwegian default) and `site/src/pages/en/index.astro` (English) render the landing.

Content for each — minimal viable, hand-written for Phase 2b:

* App name as `<h1>`
* One-line pitch ("Effektiv stasjonsbasert trening. Planlegg, kjør og følg opp øvelser uten klissete regneark." / "Efficient station-based training. Plan, run and track drills without spreadsheet glue.")
* Two CTA links:
  - "Last ned" / "Download" → hard-coded link to the Google Play page (the one in the existing README at the repo root)
  - "Åpne web-versjonen" / "Open the web version" → `https://web.ringdrill.app/`

No images, no fancy styling. Visual polish is iterated on in later prompts.

Use `BaseLayout` from Step 3 for both pages. Each page passes the right `lang` prop and a locale-appropriate `description`.

Commit: `feat(site): add bilingual landing pages with download and web CTAs`. Verify `git status` is clean.

### Step 5 — Verification

* `cd site && npm install && npm run build` produces `site/dist/` without errors
* `cd site && npm run preview` serves the pages locally and both routes render
* `diff site/dist/.well-known/assetlinks.json web/.well-known/assetlinks.json` is empty
* `git status` clean

## Out of scope

* GHA workflow to deploy `site/dist` — Phase 2c
* Cloudflare project setup — manual, separate
* Catalog browse, slug previews, brief previews — later prompts
* Privacy, terms, FAQ, support pages — later prompts
* Visual design and brand palette — later prompts
* Any change to Flutter, Netlify, or existing code

## Definition of done

Four commits in order: `feat(site)` × 4. `npm run build` is clean. `git status` clean after every commit.
