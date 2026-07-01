# Implement ADR-0044: render the shareable preview on the site

You are working in the RingDrill repository. Implement ADR-0044 ("Render the shareable preview on the site and expose plan meta as JSON from the API"). The ADR at `docs/adrs/0044-render-preview-on-site.md` is the authoritative spec — read it first, then read this prompt in full before touching code. ADR-0015 (shareable links), ADR-0039 (origin split) and ADR-0007 (drill format) are the relevant background.

The goal: move `/i/<slug>` rendering from the Netlify function `netlify/functions/drills-preview.js` to an Astro on-demand route on the site (`site/`), and expose plan meta from the API as JSON. This removes the i18n and CSS duplication between the function and `site/src/i18n.ts`, and puts the branded preview behind the site's own design system.

## Sequencing — read this first

The final cutover (routing `/i/*` to the site and deleting `drills-preview.js`) is gated on the apex migration to Cloudflare (ADR-0039). **Do not flip routing or delete the function in this change.** Build the API endpoint and the site route so they run *alongside* the existing function, verify parity, and stop. Step 6 (cutover) is documented but explicitly deferred until apex is on Cloudflare. If you believe apex has already migrated, confirm with the requester before touching `netlify.toml`'s `/i/*` redirect.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

* The site is a separate project under `site/` (Astro, `site/package.json`). Run its scripts from `site/`. The Netlify functions live under `netlify/functions/` with their own tests run by the repo-root `npm test`.
* The site currently ships as a **fully static** build (no adapter in `site/astro.config.mjs`). This change introduces on-demand rendering for the preview route only. Every existing page (`index`, `en/index`, legal, migrate) must stay prerendered — do not turn the whole site server-rendered.
* Copy lives in `site/src/i18n.ts` (`t(lang)`), design tokens in the site's CSS. Reuse both. Do not introduce a second copy dictionary or a parallel token set. Any new preview strings are added to `site/src/i18n.ts` under both `nb` and `en`.
* Locale routing follows the existing Astro config: `defaultLocale: 'nb'`, `prefixDefaultLocale: false`. So the Norwegian preview is `/i/[slug]` and the English one is `/en/i/[slug]`. The shared link stays `/i/<slug>` (ADR-0015), which is the nb route.
* The preview `<head>` must reproduce exactly what `drills-preview.js` emits today: `<title>`, `meta description`, `og:title`, `og:description`, `og:url`, `og:type`, `og:locale`, `og:site_name`, `canonical`, and `hreflang` alternates (`nb`, `en`, `x-default`). Crawlers do not run JS, so this must be server-rendered. Parity is the acceptance bar.
* Published plans are public; the meta endpoint needs no auth. Never expose unpublished plans (return 404).
* Do not touch version/release steps.

## Commits

Conventional Commits with a scope. Scopes: `functions`/`netlify`, `site`, `docs`. Commit messages in English. Suggested subjects:

* `feat(netlify): add GET drills/:slug/meta JSON endpoint`
* `chore(site): add Cloudflare adapter and on-demand rendering`
* `feat(site): render /i/[slug] preview from plan meta`
* `chore(make): point site-dev at the local API for preview debugging`
* `test(site): cover preview head parity and not-found`
* `docs(adr): mark ADR-0044 accepted`

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat`; no untracked or unstaged paths before claiming the step done.
* Each step lists the files expected in its commit. Generated files (lockfiles, adapter config) ship with the source change that introduced them.
* Never close a step with `git stash`/`git restore`. The final Verification gate requires a clean tree.

## Scope

### Step 1. API: plan-meta JSON endpoint

Add `netlify/functions/drills-meta.js`. Mirror the structure of `drills-preview.js` but return JSON, not HTML. Reuse `getSlugRecord`, `keysFor`, `readJson`, `corsPreflight`, `withCors` from `_shared.js`. Given a slug:

* Look up the slug record; if missing → 404 JSON.
* Read `meta.json`; if missing or `!meta.published` → 404 JSON (never leak unpublished plans).
* On success return `{ slug, name, description, tags, exerciseCount, versions }` — `versions` trimmed to what the preview needs (`updatedAt` per version is enough; the preview derives "last updated" from the max). Set `content-type: application/json`, `cache-control: public, max-age=300, s-maxage=600`, and CORS.

Follow `drills-preview.js`'s `createHandler({ getSlugRecord, readJson })` injection pattern so the endpoint is testable without a blobs context. Add `netlify/tests/drills-meta.test.mjs` covering: published slug → 200 with the expected shape; unknown slug → 404; unpublished slug → 404; cache headers present. Register the route in `netlify.toml` (e.g. `/api/drills/:slug/meta` → `/.netlify/functions/drills-meta?slug=:slug`), matching how the existing function routes are declared.

Run the repo-root `npm test`.

Files expected in this commit: `netlify/functions/drills-meta.js`, `netlify/tests/drills-meta.test.mjs`, `netlify.toml`.

### Step 2. Site: enable on-demand rendering

Add the Cloudflare adapter to `site/` (`@astrojs/cloudflare`, matching the project's Astro major version) and configure `site/astro.config.mjs` for per-route on-demand rendering while keeping existing pages static. Concretely: set the output mode the project's Astro version uses for mixed static/on-demand, and mark every current page to stay prerendered (either the global default stays static and only the preview opts out with `export const prerender = false`, or the equivalent for the installed Astro version). Confirm `astro build` still emits the existing static pages unchanged.

If the adapter cannot be added for a structural reason, stop and report — do not swap in a different hosting model.

Files expected in this commit: `site/package.json`, `site/package-lock.json`, `site/astro.config.mjs`, and any adapter config file.

### Step 3. Site: the preview route

Add a `Preview.astro` component (in `site/src/components/`) that ports the current preview layout — the ring mark, kicker, title, tag chips, meta row (exercise count + last-updated), description, primary CTA ("open the plan" → `web.ringdrill.app/i/<slug>`), download link (`ringdrill.app/d/<slug>`), and the brand footer. Reuse the site's existing tokens/CSS and `Footer`/brand components where they fit rather than re-declaring styles. Light/dark follows the site's existing scheme.

Add preview strings to `site/src/i18n.ts` under `nb` and `en` (`preview.kicker`, `preview.updated`, `preview.about`, and reuse the existing `hero.title`/footer tagline for the tagline). Norwegian kicker is "Delt øvingsplan"; keep the wording already agreed for the function version.

Add the routes `site/src/pages/i/[slug].astro` (nb) and `site/src/pages/en/i/[slug].astro` (en), both on-demand (`prerender = false`). Each fetches the plan meta from a **configurable API base**, not a hard-coded origin: read `import.meta.env.PUBLIC_RINGDRILL_API_BASE` (works identically under `astro dev` and in the Cloudflare build, and avoids depending on Cloudflare runtime bindings in dev), defaulting to the production API origin when unset, and request `${apiBase}/api/drills/${slug}/meta`. On success render `Preview` inside the site's base layout with a per-plan `<head>`. Set `<title>` = `${name} · RingDrill`, the meta/OG description = `[name, tags.join(", ")].filter(Boolean).join(" · ")` truncated at ~200 chars (match the function's `ogDesc`), `og:url`/`canonical` = `https://ringdrill.app/i/<slug>`, `og:locale` = `nb_NO`/`en_US`, `og:site_name` = `RingDrill`, and `hreflang` alternates for `nb`, `en`, `x-default` all pointing at the canonical. On a 404/5xx from the endpoint, render a graceful not-found with a 404 status, matching the function's `notFoundHtml`.

Files expected in this commit: `site/src/components/Preview.astro`, `site/src/pages/i/[slug].astro`, `site/src/pages/en/i/[slug].astro`, `site/src/i18n.ts`.

### Step 4. Local debug via `make site-dev`

The preview route must be debuggable locally against the local backend. Today `make site-dev` just runs `astro dev`, and `make netlify-dev` serves the functions on `$(LOCAL_BASE_URL)` (`http://localhost:8888`, functions under `/.netlify/functions/`).

* Update the `site-dev` target in `Makefile` to export `PUBLIC_RINGDRILL_API_BASE=$(LOCAL_BASE_URL)` before `astro dev`, so the on-demand `/i/[slug]` route fetches meta from the locally running functions instead of production. Keep the default (production origin) when the variable is unset, so a bare `astro dev` still works.
* The meta path must line up with what `make netlify-dev` actually serves. `netlify functions:serve` does not apply `netlify.toml` redirects, so `/api/drills/:slug/meta` will not resolve there. Either have the route target `${apiBase}/.netlify/functions/drills-meta?slug=${slug}` when `apiBase` points at the local host, or document the exact local URL — pick one and make `make site-dev` work end to end without hand-editing.
* Document the workflow in the `site-dev` Makefile comment and, if there is one, the site `README`: shell one runs `make netlify-dev` plus `make catalog-seed` (to publish a slug into the local catalog), shell two runs `make site-dev`, then open `http://localhost:4321/i/<seeded-slug>` and confirm the preview renders with real data and a correct `<head>`.

`astro dev` renders on-demand routes without wrangler, so this is the primary local-debug path. Note in the commit body that full Workers-runtime emulation (wrangler) is available but not required for preview debugging.

Files expected in this commit: `Makefile`, and the site route/config if you adjust the local meta URL handling there.

### Step 5. Verify head parity

Prove the site route emits the same crawler-visible head as the function. Add a site test (Vitest or the project's test runner under `site/`) that renders the preview head for a fixture meta and asserts the presence and values of `title`, `og:title`, `og:description`, `og:url`, `og:type`, `og:locale`, `og:site_name`, `canonical`, and the three `hreflang` alternates — the same assertions `netlify/tests/drills-preview.test.mjs` makes today. Also do one manual check with a link-unfurl debugger against a deploy preview and record the result in the PR description.

Files expected in this commit: the site test file and any fixture.

### Step 6. Cutover — DEFERRED until apex is on Cloudflare (do not execute now)

Documented for completeness, gated on ADR-0039. When apex is on Cloudflare: point `/i/*` at the site route instead of the Netlify function, confirm parity on real traffic, then delete `netlify/functions/drills-preview.js`, its `STRINGS`, `netlify/tests/drills-preview.test.mjs`, and the old `/i/*` redirect. This is a separate change with its own commit and its own verification. Do not start it in this round.

### Step 7. Docs

Set `docs/adrs/0044-render-preview-on-site.md` `status:` to `accepted` only if the requester says so in this conversation; otherwise leave it `proposed`. If any behaviour or contract note belongs in `AGENTS.md` (the new `/api/drills/:slug/meta` endpoint), add a one-liner.

Files expected in this commit: `docs/adrs/0044-render-preview-on-site.md`, `AGENTS.md` if edited.

## Verification gate

* Repo-root `npm test` green (Netlify suites, including the new meta endpoint).
* `site/` build succeeds (`npm run build` in `site/`), existing static pages unchanged, preview route renders on-demand.
* `site/` tests green, including head-parity.
* Local debug works end to end: with `make netlify-dev` + `make catalog-seed` in one shell and `make site-dev` in another, `http://localhost:4321/i/<seeded-slug>` renders the preview from local data.
* `drills-preview.js` still present and unchanged (cutover is deferred).
* `git status` clean — no untracked or unstaged files.

## Out of scope

* The routing cutover and deletion of `drills-preview.js` (Step 6, gated on apex migration).
* Any change to `/d/<slug>` download — it stays a Netlify function.
* Redesigning the preview visuals beyond porting the current layout.
* Auth on the meta endpoint — published plans are public.
