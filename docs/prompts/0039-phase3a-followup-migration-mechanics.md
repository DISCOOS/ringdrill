# ADR-0039 Phase 3a follow-up — migration mechanics on the Astro site

You are working in the RingDrill repository. The initial Phase 3a run (see [0039-phase3a-implementation-prompt.md](./0039-phase3a-implementation-prompt.md)) landed the visual site (Hero, Nav, Footer, Features, Screenshots, privacy/terms/tos content, layouts) but skipped the migration-critical files. Without those, the Phase 3 apex cutover breaks everything routed through `ringdrill.app`. This prompt covers only the missing pieces.

Read [ADR-0039](../adrs/0039-site-pwa-api-origins.md) and the parent [0039-phase3a-implementation-prompt.md](./0039-phase3a-implementation-prompt.md) before starting. Details of what to build are in the parent prompt's Steps 1, 2, 3, 4 (excluding the "landing landing" scaffold that is already there) and 5.

## Scope

Site-only. Add five files under `site/`. No changes to Flutter, Netlify or GHA. Do NOT re-touch existing visual components (Hero, Nav, Footer, Features, Screenshots, layouts). If a step below already has a file in the repo, verify it matches the spec and skip if it does.

## Steps

### Step 1 — `site/public/_redirects`

Per parent prompt Step 1. Copy the block verbatim: proxy `/api/*`, `/.netlify/functions/*`, `/d/*`, `/i/*`, `/brief/*` to `api.ringdrill.app` with status 200, plus vanity 301 for `/web` and `/app` → `https://web.ringdrill.app/`.

Commit: `feat(site): add _redirects for apex proxy and vanity rules`.

### Step 2 — `site/public/_headers`

Per parent prompt Step 2 plus Step 3 (the SW stub headers). Serve `.well-known/apple-app-site-association` and `.well-known/assetlinks.json` as JSON with `Cache-Control: public, max-age=3600`. Serve `/flutter_service_worker.js` with `Cache-Control: no-cache` and `Content-Type: application/javascript`.

Commit: `feat(site): add _headers for .well-known and SW stub`.

### Step 3 — `site/public/flutter_service_worker.js` (self-unregister stub)

Per parent prompt Step 3. The stub takes over from any registered Flutter SW, clears caches, unregisters itself, and posts a `sw-retired` message to controlled clients. No `fetch` handler.

Commit: `feat(site): serve self-unregister SW stub for retired apex PWA`.

### Step 4 — `MigrationNudge` component on the landing

Per parent prompt Step 4. Add `site/src/components/MigrationNudge.astro`. Detects Flutter localStorage keys (`p:`, `pe:`, `pt:`, `ps:`, `app:librarySchema:v1`) or an existing SW registration at `/`, and shows a persistent top-of-page banner linking to `/migrate` (or `/en/migrate` on the English page). Dismissable per-session.

Include the component in both `src/pages/index.astro` and `src/pages/en/index.astro` at the top of `<main>` or wherever the layout allows it above the fold.

Copy per parent prompt: heading (bold) `Web-appen er flyttet til web.ringdrill.app` / `The web app has moved to web.ringdrill.app`, body `Klikk her for å hente ut planene dine og åpne den nye appen.` / `Click here to export your plans and open the new app.`

Commit: `feat(site): show migration nudge banner on landing for former apex PWA users`.

### Step 5 — `/migrate` page

Per parent prompt Step 5. Add `site/src/pages/migrate.astro` (nb) and `site/src/pages/en/migrate.astro` (en). Client-side JS reads Flutter localStorage, groups by program, builds one `.drill` per program via `fflate`, bundles them into an outer ZIP named `ringdrill-eksport-YYYY-MM-DD.zip`, and offers download via `<a download>`. After download, reveal a secondary CTA linking to `https://web.ringdrill.app/?import=guide`.

Extract the migration logic into `site/src/lib/migrate.ts` (or `.js`) so it is testable. Add a unit test covering fake-localStorage → outer ZIP with the expected `.drill` structure per ADR-0007.

Install `fflate` as a dev dependency in `site/package.json` if not already present:

```bash
cd site && npm install --save-dev fflate
```

Commit: `feat(site): add /migrate page with client-side .drill export`.

## Verification

* `cd site && npm run build` clean
* `cd site && npm test` clean
* Preview locally: `cd site && npm run preview`, then:
  - Seed a dummy `p:test-uuid` key in devtools localStorage, reload landing — nudge appears
  - Open `/migrate` — CTA is enabled, click downloads a ZIP with the expected structure
  - Unzip: contains one `.drill` per seeded program, each unzips to the ADR-0007 structure
* `dist/_redirects`, `dist/_headers` and `dist/flutter_service_worker.js` all present after build
* `git status` clean

## Out of scope

* Anything the initial Phase 3a run already landed (visual components, layouts, content pages)
* Manual DNS or Cloudflare configuration
* Netlify-side changes
* Flutter changes

## Definition of done

Five commits in order. Build and tests pass. Preview verification per the list above passes. `git status` clean after every commit.

## Commit message conventions

Conventional commits, lowercase, imperative present tense, English. Each step has its own commit.
