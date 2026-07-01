---
status: proposed
date: 2026-07-01
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0044: Render the shareable preview on the site and expose plan meta as JSON from the API

## Context and problem statement

The shareable install link `ringdrill.app/i/<slug>` (ADR-0015) is served today by a Netlify function, `netlify/functions/drills-preview.js`. That function reads the plan's catalog meta from Netlify Blobs and renders a full HTML page: `<head>` with OG/canonical/hreflang tags for link unfurling, and a branded body with its own CSS and its own copy.

Two duplications have grown out of this. The function carries its own `STRINGS` dictionary that repeats wording already maintained in `site/src/i18n.ts`, and it carries its own brand CSS that repeats the design tokens used across the site. The English tagline had already drifted once ("Rotation without spreadsheets" vs. the site's "Rotation without the spreadsheet.") precisely because the copy lives in two places.

The preview is, by nature, a public, branded, SEO- and unfurl-facing page. Under ADR-0039 that is a *site* concern (Cloudflare/Astro), not an *API* concern (Netlify functions). The function placement is a historical artefact that predates the origin split. The apex migration in ADR-0039 forces the question anyway: `/i/*` is routed to the function through a `netlify.toml` redirect, and that redirect has to be reconsidered when the apex moves to Cloudflare.

## Decision drivers

* One source of truth for site copy and design. Kill the `i18n` and CSS duplication.
* The preview must unfurl for crawlers (Slack, iMessage, Facebook), which do not run JavaScript, so it must be server-rendered HTML with correct `og:*`, `canonical` and `hreflang`.
* Align with ADR-0039: public branded pages belong to the site, data belongs to the API.
* Keep data access simple and cacheable. Published plans are public, so no auth is needed to read their meta.
* Do not destabilise the in-flight apex migration.

## Considered options

* A: Render `/i/[slug]` on the site (Astro on-demand rendering on Cloudflare), consuming a new JSON meta endpoint from the API. The function keeps a thin role: the meta JSON endpoint and the `/d/<slug>` download.
* B: Keep the SSR in the Netlify function, but extract the copy and CSS into shared modules.
* C: Pre-render every `/i/` page at build time on the site.
* D: Serve a single static HTML shell for `/i/` and fetch the plan meta client-side with JavaScript.

## Decision outcome

Chosen option: **Option A**. The site owns `/i/[slug]` via Astro on-demand rendering and reuses the same components, design tokens and `t(lang)` dictionary as the rest of the site. The API exposes a small JSON endpoint, `GET /api/drills/:slug/meta`, returning `{ name, description, tags, exerciseCount, versions, published }`, reusing `keysFor`/`readJson` from `_shared.js`. This removes both duplications in one move and puts the preview behind the same design system as the site.

The Netlify side retains a thin, correct role: the meta JSON endpoint, and the `/d/<slug>` download (an asset/API concern that stays a function). `drills-preview.js` is retired once the site route is live and the `/i/*` routing flips.

Sequencing matters. This lands **after** the apex is on Cloudflare per ADR-0039, so we are not flipping `/i/*` routing mid-migration.

### Consequences

* Good: One copy dictionary and one design system. The preview matches the site, and drift like the tagline bug cannot recur.
* Good: Origins align with ADR-0039 — the branded page is on the site, the data on the API.
* Good: The catalog stays dynamic. On-demand rendering handles slugs unknown at build time, unlike a pre-render.
* Bad: One extra hop (site render fetches meta JSON from the API) versus the function's direct blob read. Mitigated by `s-maxage` on the endpoint and Cloudflare edge caching.
* Bad: The Astro page must reproduce the exact `<head>` the function emits (`og:title`/`description`/`url`/`type`/`locale`/`site_name`, `og:image` with 1200×630 dimensions, the `twitter:*` card tags, `canonical`, `hreflang`). Parity is a real risk during the port and must be verified with a crawler check. `og:image` is load-bearing: without it, Messenger/Facebook render only the bare domain with no card.
* Bad: The route now depends on API availability. A meta `404`/`5xx` must render a graceful not-found, matching today's function behaviour.
* Bad: The site ships today as a fully static Astro build with no adapter. This introduces on-demand rendering (a Cloudflare adapter) for the first time, while keeping every existing page prerendered. That is a non-trivial addition to the site's build and deploy.
* Bad: Sequencing couples this to the apex migration.

## Pros and cons of the options

### Option A — render on the site, meta JSON from the API (chosen)
* Good: Single source of truth for copy and design; aligns origins.
* Good: Dynamic slugs handled by on-demand rendering.
* Bad: Extra hop and OG-parity risk during the port.

### Option B — keep the function, extract shared modules
* Good: Smallest change; no new route or endpoint.
* Bad: Sharing modules across two deploy targets (Netlify functions vs. Cloudflare/Astro) is awkward and fragile.
* Bad: Leaves the origin split violated — a branded site page still lives in an API function.

### Option C — pre-render all `/i/` pages at build time
* Good: Pure static output, fastest possible serve.
* Bad: The catalog is dynamic; slugs are unknown at build time, and every publish would require a rebuild.

### Option D — static shell + client-side fetch
* Good: No server-side rendering on the site at all; the page is a plain static asset.
* Bad: Breaks link unfurling and SEO. Social crawlers (Slack, iMessage, Messenger, WhatsApp, LinkedIn, X) do not run JavaScript, so they read only the initial HTML. Per-slug `og:*`/`<title>` injected by JS is invisible to them, and the preview unfurls as an empty or generic card — which defeats the page's whole purpose. Per-slug OG tags must be in the server-rendered HTML at request time, which this option cannot provide.

## Migration and sequencing

1. Add `GET /api/drills/:slug/meta` (Netlify function) returning the meta JSON, `404` for unpublished or missing, with `s-maxage` cache headers. Match the per-item shape `market-feed.js` already returns for consistency. `drills-preview.js` keeps running unchanged.
2. Add the Cloudflare adapter and enable on-demand rendering for the preview route only, keeping every existing page prerendered. Build the Astro `/i/[slug]` on-demand route consuming that endpoint, porting the current preview layout into a site component that reuses site tokens and `t(lang)`. The route fetches meta from a configurable API base (`PUBLIC_RINGDRILL_API_BASE`, default production) so `make site-dev` can point it at the local `make netlify-dev` backend for debugging. Verify OG/canonical/hreflang parity with a crawler check (Slack/Facebook debugger or equivalent).
3. After the apex is on Cloudflare (ADR-0039), flip `/i/*` routing from the Netlify function to the site route. Once traffic confirms parity, retire `drills-preview.js`, its `STRINGS` dictionary and its tests.
4. `/d/<slug>` download stays a function.

## Links

* Related ADRs: [ADR-0015](./0015-shareable-install-links.md) (shareable install links), [ADR-0039](./0039-site-pwa-api-origins.md) (site/PWA/API origin split), [ADR-0007](./0007-drill-file-format.md) (`.drill` format), [ADR-0008](./0008-persistent-program-library-and-catalog.md) and [ADR-0010](./0010-live-catalog-updates.md) (catalog and HEAD polling)
* Related code: `netlify/functions/drills-preview.js`, `netlify/functions/_shared.js`, `netlify/functions/market-feed.js`, `site/src/i18n.ts`, `netlify.toml`
* Depends on: apex migration to Cloudflare (ADR-0039) landing first.
