---
status: accepted
date: 2026-07-02
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

### Relation to ADR-0040 (why keep a separate meta endpoint)

[ADR-0040](./0040-catalog-feed-schema-extension.md) widens the catalog feed item to carry `description`, `exerciseCount`, `author` and `accessPolicy`, so the feed and this per-slug meta endpoint end up with nearly the same fields. That overlap raises the fair question of whether `/api/drills/:slug/meta` is still needed once the feed is widened. It is — the two serve different access patterns and are both kept deliberately:

* The feed is a **bulk browse**: published-only, paginated (`limit` 1–100, cursor), sorted. Locating one slug through it is a page scan in the worst case.
* The meta endpoint is a **point lookup**: a direct `slug → record → meta.json` blob read (O(1)), which is exactly what a single `/i/[slug]` render needs.
* Only the meta endpoint can express **clean 404 semantics** for an unpublished or missing single slug. The feed silently omits such plans, which a preview render cannot distinguish from "not on this page".

The right coupling is not to merge them but to keep the shapes from drifting: both project from the same `meta.json` via a shared helper in `_shared.js`, so a field added in one appears in the other. This ADR's step 1 already calls for matching the feed's per-item shape; ADR-0040 makes that shared projection explicit.

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

> **Update 2026-07-02 (apex cutover):** ADR-0039 originally specified the apex proxy as a status-200 `_redirects` rule. That does not work — Cloudflare Pages `_redirects` can only 200-rewrite to local paths, not to an external origin (that is a Netlify-only feature). During the apex cutover, unknown `/api/*`, `/d/*`, `/i/*` and `/brief/*` fell through to the Astro landing page. The fix was a standalone Worker, `workers/apex-proxy/`, bound to those prefixes, forwarding verbatim to `api.ringdrill.app`. The steps below have been corrected to reference the Worker instead of `_redirects`.

1. Add `GET /api/drills/:slug/meta` (Netlify function) returning the meta JSON, `404` for unpublished or missing, with `s-maxage` cache headers. Match the per-item shape `market-feed.js` returns (widened by ADR-0040), sharing one projection helper in `_shared.js` so the feed and this endpoint cannot drift. `drills-preview.js` keeps running unchanged.
2. Add the Cloudflare adapter and enable on-demand rendering for the preview route only, keeping every existing page prerendered. Build the Astro `/i/[slug]` on-demand route consuming that endpoint, porting the current preview layout into a site component that reuses site tokens and `t(lang)`. The route fetches meta from a configurable API base (`PUBLIC_RINGDRILL_API_BASE`, default production) so `make site-dev` can point it at the local `make netlify-dev` backend for debugging. Verify OG/canonical/hreflang parity with a crawler check (Slack/Facebook debugger or equivalent).
3. **The apex cutover does not require this ADR.** After the DNS flip, apex `/i/*` is proxied to `https://api.ringdrill.app/i/:splat` by the `workers/apex-proxy/` Worker, so `drills-preview` keeps rendering `/i/` with no gap. `/i/` therefore does not break at cutover, and this ADR is not a prerequisite for it. The site route is an independent optimisation that can land any time after ADR-0039.
4. This ADR's cutover = replace the apex `/i/*` proxy with the native Cloudflare route. Deploy the `/i/[slug]` route, confirm parity on the Cloudflare host, then remove the `ringdrill.app/i/*` route from `workers/apex-proxy/wrangler.toml` and redeploy the Worker so the native Astro route wins. Order matters and is now stricter than the old `_redirects` plan: **Worker routes take precedence over Pages, so the native `/i/[slug]` route is unreachable until the Worker's `/i/*` route is removed.** The route must be live before the Worker route is dropped, or there is a brief gap. (The dead `/i/*` line in `site/public/_redirects` was already removed on 2026-07-02 under [DEBT-0011](../debts/0011-adr-0039-post-cutover-cleanup.md), so nothing remains to clean up there.)
5. After parity on real traffic, retire `drills-preview.js`, its `STRINGS` dictionary and its tests.
6. `/d/<slug>` download stays a Netlify function, reached from the Cloudflare apex via the `workers/apex-proxy/` Worker (`ringdrill.app/d/*` route). This ADR does not touch it.

## Links

* Related ADRs: [ADR-0015](./0015-shareable-install-links.md) (shareable install links), [ADR-0039](./0039-site-pwa-api-origins.md) (site/PWA/API origin split), [ADR-0040](./0040-catalog-feed-schema-extension.md) (catalog feed schema extension — shares the meta projection with this endpoint), [ADR-0007](./0007-drill-file-format.md) (`.drill` format), [ADR-0008](./0008-persistent-program-library-and-catalog.md) and [ADR-0010](./0010-live-catalog-updates.md) (catalog and HEAD polling)
* Related code: `netlify/functions/drills-preview.js`, `netlify/functions/_shared.js`, `netlify/functions/market-feed.js`, `site/src/i18n.ts`, `netlify.toml`, `workers/apex-proxy/` (apex proxy that actually routes `/i/*`), `site/public/_redirects`
* Depends on: apex migration to Cloudflare (ADR-0039) landing first.
