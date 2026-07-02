---
status: accepted
date: 2026-06-29
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0039: Split the site, PWA and API across separate origins

> **Implementation correction (2026-07-02).** The apex cutover is complete, but one load-bearing assumption in this ADR was wrong. Cloudflare Pages `_redirects` **cannot** 200-proxy to an external origin — status-200 rewrites only target local paths (that is a Netlify-only feature). So the apex proxy rules in [Topology](#topology) do not work on Pages, and the decision driver "No Cloudflare Pages Functions, no Workers" (below) could not hold. The apex `/api/*`, `/.netlify/functions/*`, `/d/*`, `/i/*` and `/brief/*` paths are proxied by a standalone Worker, `workers/apex-proxy/`, deployed via `deploy-proxy.yml`. The three-origin topology, the DNS flip and the SW self-unregister stub all landed as designed; only the proxy mechanism changed. Remaining cleanup is tracked in [DEBT-0011](../debts/0011-adr-0039-post-cutover-cleanup.md).

## Context and problem statement

Today `ringdrill.app` serves the Flutter PWA shell on apex. A cold visit waits 1-3 seconds for the Flutter bootstrap before any content shows. There is no public site, no human-readable preview for install or brief links, no SEO-indexable identity for RingDrill on the web. The shared catalog at `/api/market/feed` is only browsable from inside the app, so the catalog has no presence outside the install footprint. App Store and Play submissions need a marketing URL, a support URL and a privacy URL that resolve to real HTML, not a PWA loader.

We need a public landing, a public browse of the shared catalog, and pre-rendered HTML previews for the install and brief links. We also need to leave room for ADR-0024 sign-in to land without rebuilding the topology, and we want to reduce both build minutes and bandwidth on Netlify so the platform tier stays comfortable as traffic grows.

## Decision drivers

* Cold visits to `ringdrill.app` must render real HTML immediately. No Flutter loader for first-time visitors.
* Existing URLs `/i/<slug>`, `/o/<slug>`, `/d/<slug>`, `/brief/...` stay on apex. AASA (`G2C47B233E.app.ringdrill`), assetlinks (`org.discoos.ringdrill`), already-shared links and ADR-0015/-0026 depend on it.
* PWA Service Worker on apex must retire cleanly so existing installs do not stay locked there forever.
* The site must be pure static. No new server runtime to learn or maintain on the Cloudflare side. No Cloudflare Pages Functions, no Workers.
* Slug-preview HTML rendering must read `meta.json` from the catalog blob store. Renderer lives next to the data.
* Brief pre-rendering is a real subsystem port and is deferred to ADR-0041.
* Catalog feed schema upgrade (description, exerciseCount, author, accessPolicy) is deferred to ADR-0040.
* Netlify build minutes and bandwidth should drop close to zero. Only function invocations should hit Netlify.
* Sign-in (ADR-0024) lands later. The site reserves UI and routes for it without implementing auth state today.
* Content is bilingual (Norwegian and English). URL paths are English.

## Considered options

### For the hosting topology

* Option A: Apex on Cloudflare Pages (static), PWA on `web.ringdrill.app` Cloudflare Pages, API on Netlify as `api.ringdrill.app`. Cloudflare proxies `/i/*`, `/d/*`, `/brief/*` to Netlify with `_redirects` status-200 rewrites (chosen).
* Option B: Apex on Cloudflare Pages with Pages Functions for dynamic rendering, PWA on `web.`, API on Netlify. Adds a second Node runtime.
* Option C: Apex on Cloudflare Pages, PWA stays on Netlify, API on Netlify. Loses the Netlify-bandwidth reduction.
* Option D: Path-based split on apex (`/` site, `/app/` PWA). Rejected by the maintainer before drafting.

### For the apex/PWA host

* Option E: PWA on `web.ringdrill.app` (chosen). Separate origin from the site.
* Option F: PWA on `ringdrill.app/app/`. Rejected.
* Option G: PWA on `www.ringdrill.app` and site on apex. Splits `www.` and apex as distinct surfaces. SEO-fragile.

### For locale

* Option H: Norwegian as default at `/`, English under `/en/` (chosen). Primary user base is Norwegian. Switching default is cheap if usage shifts.
* Option I: English as default at `/`, Norwegian under `/nb/`. International-SaaS pattern.

### For preview rendering

* Option J: Render previews on Netlify, proxy from Cloudflare (chosen). One Node runtime, code next to data.
* Option K: Render previews on Cloudflare Pages Functions. Requires a second Node runtime on Cloudflare.
* Option L: Pre-render every slug at publish time via webhook to Cloudflare deploy. Maximally static, but every drill upload triggers a rebuild.

## Decision outcome

Chosen options: **A + E + H + J**, applied together.

A wins because Cloudflare hosts only static assets, Netlify keeps all dynamic code in one runtime, and Cloudflare `_redirects` with status 200 preserves the apex URL across the topology change. The site becomes a pure static Cloudflare deploy, the PWA becomes a pure static Cloudflare deploy of the Flutter web build, Netlify shrinks to just functions.

E wins because separate origins give the PWA Service Worker its own isolated scope, leave the existing Flutter `--base-href=/` build untouched, and keep apex free for static-first rendering. `web.` reads clean across languages and avoids the recursive feel of `app.ringdrill.app`.

H wins because the current primary audience is Norwegian-speaking and the brand domain works as a Norwegian landing. A future switch to English-default is a redirect-and-hreflang change, not a rewrite.

J wins because the slug-preview renderer needs to read `meta.json` from the catalog blob store. Putting it on Netlify lets the new function reuse `_shared.js`, `keysFor`, `readJson` and the existing blob client. A Cloudflare-side implementation would have to call into the Netlify API to fetch the same `meta.json`, adding a roundtrip and a second place to maintain the rendering logic.

### Topology

Three origins, each with one clear responsibility:

| Origin              | Host             | Project              | Serves                                                         |
|---------------------|------------------|----------------------|----------------------------------------------------------------|
| `ringdrill.app`     | Cloudflare Pages | `ringdrill-site`     | Public site, `.well-known/*`, proxy + vanity redirects         |
| `web.ringdrill.app` | Cloudflare Pages | `ringdrill-pwa`      | Flutter web build artefact (PWA)                               |
| `api.ringdrill.app` | Netlify          | (functions only)     | All `netlify/functions/*`. No static hosting.                  |

Apex (`ringdrill.app`) proxy. **See the [implementation correction](#adr-0039-split-the-site-pwa-and-api-across-separate-origins) — the status-200 proxy below is NOT done via `_redirects` (Cloudflare Pages cannot proxy to an external origin); it is done by the `workers/apex-proxy/` Worker.** The vanity 301s below do work as `_redirects`.

```
# Proxy (status 200, URL in browser stays ringdrill.app/...) — Worker, not _redirects
/api/*                https://api.ringdrill.app/api/:splat                200
/.netlify/functions/* https://api.ringdrill.app/.netlify/functions/:splat 200
/i/*                  https://api.ringdrill.app/i/:splat                  200
/d/*                  https://api.ringdrill.app/d/:splat                  200
/brief/*              https://api.ringdrill.app/brief/:splat              200

# Vanity (status 301, URL changes) — real _redirects lines
/web       https://web.ringdrill.app/               301
/app       https://web.ringdrill.app/               301
```

Apex also serves `/flutter_service_worker.js` as a self-unregister stub, see [PWA migration on apex](#pwa-migration-on-apex).

PWA (`web.ringdrill.app`) ships the Flutter web build artefact unchanged. `_headers` ports the per-asset cache rules from `netlify.toml`. SPA fallback rewrites `/*` to `/index.html`.

`.well-known` files live in the site project as flat files:

* `/.well-known/apple-app-site-association`
* `/.well-known/assetlinks.json`

Both stay byte-identical to today's Netlify-served version. `Content-Type` and `Cache-Control` are set in `_headers`.

DNS records after migration are listed in [DNS](#dns) below.

### DNS

Today the domain `ringdrill.app` uses Netlify's NS1-based nameservers as authoritative DNS. All records (apex A/AAAA, `www.` CNAME, any verification TXT and MX records) live in the Netlify dashboard.

Target: **Cloudflare DNS as authoritative**. Cloudflare DNS integrates natively with the Cloudflare Pages projects and unlocks Cloudflare-specific features (cache rules, transform rules) that we may reach for later.

The migration is a one-time operation at the registrar:

1. Add `ringdrill.app` to Cloudflare. Cloudflare scans existing DNS and auto-imports the records it can see.
2. Compare against the Netlify DNS zone and re-create any missing records on Cloudflare. Pay particular attention to TXT records (SSL/ACME verification, email DKIM/SPF/DMARC if any) and any MX records.
3. At the registrar, switch the nameservers from Netlify's to Cloudflare's. Propagation is typically minutes to a few hours; up to 48 hours in the worst case.
4. After propagation is verified (`dig ringdrill.app NS` returns Cloudflare nameservers), the Netlify DNS zone can be deleted or left dormant as a fallback.

Records after migration:

| Record                  | Type              | Target                                                                | Set up in |
|-------------------------|-------------------|-----------------------------------------------------------------------|-----------|
| `ringdrill.app`         | CNAME (flattened) | Netlify (today) → `ringdrill-site.pages.dev` (Phase 3)                | Phase 2 / Phase 3 |
| `www.ringdrill.app`     | CNAME             | Same as apex; 301-redirects to apex via Cloudflare Pages config       | Phase 2 / Phase 3 |
| `web.ringdrill.app`     | CNAME             | `ringdrill-pwa.pages.dev`                                             | Phase 2   |
| `api.ringdrill.app`     | CNAME             | The existing Netlify site (`<site>.netlify.app`)                      | Phase 2   |

SSL certificates are managed automatically by Cloudflare (for `ringdrill.app`, `www.ringdrill.app`, `web.ringdrill.app`) and Netlify (for `api.ringdrill.app`). No manual cert handling.

The Phase 2 nameserver migration is cosmetic in the sense that all existing records continue to resolve to their current targets. The Phase 3 cutover changes only what `ringdrill.app` (and `www.`) point at — from the Netlify site to the Cloudflare site project.

### Site source

Source lives in `site/` at the repo root. Tech stack is **Astro**, picked for file-based routing, built-in i18n, Markdown content support, and zero-runtime defaults. The visual palette is the docs-site palette already locked in by ADR-0023 (`BriefTheme`) so apex and brief previews share an aesthetic.

Initial routes (Norwegian at `/`, English mirror under `/en/`):

```
/                      Landing
/catalog               Public catalog browse (reads api.ringdrill.app/api/market/feed)
/i/<slug>              Slug preview (proxied to Netlify drills-preview)
/brief/<uuid>          Brief preview (proxied; lit up by ADR-0041)
/brief/program/<uuid>  Program brief preview (proxied; lit up by ADR-0041)
/about                 About RingDrill
/faq                   FAQ, drawn from DESIGN-007 help materials
/privacy               Privacy policy (App Store and Play required)
/terms                 Terms of use
/support               Support, GitHub issues, contact
/login                 Login placeholder until ADR-0024 lands
/auth/callback         Auth callback placeholder
/account               Profile placeholder
/.well-known/*         AASA and assetlinks
```

`hreflang` tags link every page to its locale sibling. Sitemap and robots.txt are generated at build time. The Astro build is fully static. No SSR, no server functions on Cloudflare.

### New Netlify function: drills-preview

`netlify/functions/drills-preview.js` is added and serves three paths via Netlify redirects in `netlify.toml`:

* `/i/<slug>`: returns HTML with OG tags, name, description, tags, exercise count, and CTAs ("Åpne i app" / "Åpne i web"). Reads `meta.json` via `getDrillsStore()` and renders with a small template.
* `/d/<slug>`: unchanged behaviour, served by the existing `deep-link.js`.
* `/brief/<uuid>` and `/brief/program/<uuid>`: returns a 302 redirect to `https://web.ringdrill.app/brief/<uuid>` initially. ADR-0041 replaces this with real rendering.

Preview responses set `Cache-Control: public, max-age=300, s-maxage=600`. Cloudflare's edge cache layers on top, so warm previews are served from the edge after the first hit.

### CORS

`ALLOWED_ORIGIN_PATTERNS` in `netlify/functions/_shared.js` is extended to include `https://web.ringdrill.app`. `https://ringdrill.app` is already allowed. Deploy preview patterns (`*--ringdrill.netlify.app`) are kept for `netlify dev` and any preview deploys that remain.

### API client configuration

The Flutter PWA reaches the catalog backend through `DrillClient`, configured in `lib/utils/app_config.dart`. Today `AppConfig.catalogBaseUrl()` returns:

* the empty string for release web builds (same-origin)
* `https://ringdrill.app` for native and debug web builds
* `RINGDRILL_LOCAL_BASE_URL` for debug builds when set (ADR-0013)

When the PWA moves to `web.ringdrill.app`, the same-origin rule fails. `web.ringdrill.app/.netlify/functions/*` is not served. Cloudflare Pages hosts only static assets per [Topology](#topology). The catalog client must be pointed at the API origin explicitly.

`AppConfig.catalogBaseUrl()` is updated so release web builds return `https://api.ringdrill.app`. `functionsBasePath` stays at `/.netlify/functions` and `deepLinkBasePath` stays at `/d`. The PWA calls `https://api.ringdrill.app/.netlify/functions/drills-upload` directly, one network hop, with CORS allowed by the updated `ALLOWED_ORIGIN_PATTERNS`.

The alternative — routing PWA traffic through apex (`https://ringdrill.app`) and letting Cloudflare proxy to Netlify — works but adds a hop on every API call with no upside. Direct-to-API is preferred for the PWA. The apex proxy stays in place for the old cached PWA (same-origin calls during Phase 1 and Phase 3) and for external clients that already hard-code `https://ringdrill.app` as their base URL.

Path cleanup (`/.netlify/functions/*` → `/api/*` as the canonical public path) is intentionally out of scope. The two paths coexist today and we keep them both. Refactoring to a single canonical path is a separate decision, deferred to a follow-up ADR if and when the implementation-detail leak matters.

### Rollout phases

The migration is staged into three phases. There is no grace period between phases. Each phase ships when the prior is verified.

#### Phase 1: communication channel via a final Flutter release

The first deliverable is a Flutter web release shipped to the current apex (Netlify-hosted Flutter PWA). The release adds:

* Origin detection. When the PWA detects it is running on `ringdrill.app` (not `web.ringdrill.app`), it shows a persistent migration banner inside the app. The check (`isLegacyHost()`) additionally requires standalone display mode, so it fires only for an *installed* PWA. A plain browser tab on apex needs no in-app banner: after the Phase 3 cutover a fresh browser visit fails over to the Astro site and is prompted via `/migrate`. `RINGDRILL_FORCE_LEGACY_HOST` bypasses the standalone check for dev testing in an ordinary browser.
* Banner copy. Heading: "Web-appen flytter til web.ringdrill.app." Body: "Last ned planene dine her og åpne den nye appen." Primary action: "Eksporter alle planene mine". Secondary action: "Åpne den nye appen".
* Export action. Uses the existing `DrillFile.write()` pipeline (per ADR-0007) to produce one `.drill` archive per `Program`, bundled into one outer ZIP (`ringdrill-eksport-YYYY-MM-DD.zip`).
* A settings entry "Om migrasjon" with a full explanation: why we are moving, what changes for the user, how to install on the new origin, what happens to data, and a re-export button.

This release lands first. The cached SW updates within hours (entry points are no-cache per ADR-0016), so the in-app banner reaches existing installs without user action. The release is the only programmatic surface we have into cached PWAs, so it must ship before any infrastructure changes.

#### Phase 2: stand up new infrastructure in parallel

Once Phase 1 is verified in production, the new infrastructure is built out alongside the existing apex:

* Cloudflare Pages projects created: `ringdrill-site` (Astro) and `ringdrill-pwa` (Flutter web artefact).
* DNS authority moved from Netlify to Cloudflare per [DNS](#dns). Apex and `www.` records still point at Netlify during this phase, so existing apex behaviour is unchanged.
* New DNS records added on Cloudflare: `web.ringdrill.app` → `ringdrill-pwa.pages.dev`, `api.ringdrill.app` → the existing Netlify site.
* `ALLOWED_ORIGIN_PATTERNS` in `_shared.js` is extended to include `https://web.ringdrill.app`.
* Initial Astro deploy and initial PWA deploy land on Cloudflare. Both are smoke-tested end-to-end before cutover.

The existing apex (Netlify-hosted Flutter PWA + functions) keeps running. Users who acted on the Phase 1 banner can already migrate to `web.ringdrill.app`. Apex is unchanged for everyone else.

#### Phase 3: cutover apex

When Phase 2 is verified, apex is cut over in one operation:

1. The apex CNAME (and `www.`) is changed in Cloudflare DNS from the Netlify target to `ringdrill-site.pages.dev`. DNS authority itself stays at Cloudflare from Phase 2; only the record target flips.
2. The site project includes the `_redirects` proxy rules and the vanity 301s described in [Topology](#topology).
3. The site project serves `flutter_service_worker.js` as a self-unregister stub. The stub calls `self.registration.unregister()`, `caches.delete(...)` for each cached entry, then `self.skipWaiting()` and posts a message to controlled clients.
4. Existing PWAs get one final session on cache. On next reload the SW unregisters and Astro takes over.
5. The Astro landing detects Flutter localStorage on the apex origin (see [User data migration](#user-data-migration)) and shows the same two-line banner as the in-app Phase 1 banner, linked to `/migrate`.

ADR-0016's strategy is unchanged for `web.ringdrill.app`. Only the apex SW is being torn down. The self-unregister stub stays in place indefinitely so any zombie SW registration encountered later is also retired.

### User data migration

Flutter web stores `Program`, `Exercise`, `Team` and `Session` data in `localStorage` via the SharedPreferences web shim. `localStorage` is origin-scoped, so data on `ringdrill.app` cannot be read from `web.ringdrill.app`. Two complementary mechanisms cover the install base:

**In-app export (Phase 1).** Triggered from the migration banner inside the still-running Flutter PWA. Uses the existing `DrillFile.write()` pipeline so the format is byte-compatible with the new PWA's import. Output is one outer ZIP containing one `.drill` per `Program`. The user downloads it, opens `https://web.ringdrill.app/`, and imports via the existing import dialog or via the deep-linked walkthrough at `?import=guide`.

**Astro `/migrate` (Phase 3 onwards).** For users who did not act on the Phase 1 banner before cutover. The page is plain HTML/JS, no Flutter, no SW dependency. It:

1. Enumerates `localStorage` for Flutter library keys (`p:`, `pe:`, `pt:`, `ps:`, plus app-level keys from `AppConfig`).
2. If any are present, shows a primary CTA: "Last ned alle planene mine".
3. Click constructs a ZIP in the browser using `fflate` (same library Netlify functions use). One `.drill` per program, bundled into one outer ZIP.
4. Browser triggers download via `<a download>` and a Blob URL.
5. After download, a secondary CTA appears: "Åpne web-appen og importer". Links to `https://web.ringdrill.app/?import=guide`.

`/migrate` remains permanently. The only failure mode is a user who clears browser data on `ringdrill.app` before exporting. That risk is communicated in both the Phase 1 in-app banner and the Phase 3 Astro landing.

The export format is the standard `.drill` archive (ADR-0007). No "migration format" is invented. The new PWA's existing import pipeline ingests it without changes.

### Deploy pipelines

All three origins deploy from GitHub Actions. Netlify auto-publish-from-Git stays off, as today, so a stray push cannot race a workflow. The current `.github/workflows/deploy-web.yml` is replaced by three workflows, one per origin:

* `deploy-pwa.yml`: builds Flutter web (`make web`), uploads source maps to Sentry (existing step), then `wrangler pages deploy build/web --project-name=ringdrill-pwa`. Triggers: pushes touching `lib/**`, `pubspec.yaml`, `web/**`, or the workflow itself. Replaces the Netlify CLI step in the existing `deploy-web.yml`.
* `deploy-site.yml`: builds Astro under `site/`, then `wrangler pages deploy site/dist --project-name=ringdrill-site`. Triggers: pushes touching `site/**`, plus an hourly cron so the catalog index reflects new publishes without manual rebuilds.
* `deploy-functions.yml`: pushes the Netlify Functions artefact via `netlify deploy --prod --dir=. --functions=netlify/functions`. No build step; functions are pure JS. Triggers: pushes touching `netlify/functions/**` or `netlify.toml`.

`netlify.toml` is stripped to the `[functions]` block, the `/api/*` redirects, the `/i/*`, `/d/*`, `/brief/*` redirects to the new `drills-preview` and `deep-link` functions, and CORS-related directives. All static-asset header rules move to `_headers` files in the respective Cloudflare projects.

### Account-readiness

The site is fully account-unaware in this ADR's scope. The nav reserves space for a "Logg inn" element that links to `/login`. `/login`, `/auth/callback` and `/account` are placeholder pages explaining sign-in is coming. When ADR-0024 lands, the placeholders are replaced and a shared cookie on `.ringdrill.app` (parent domain) can light up auth-aware UI on apex if needed. No infrastructure decision is taken here, only routes are reserved.

### Vanity redirects

`/web` and `/app` on apex 301-redirect to `https://web.ringdrill.app/`. They are reserved paths and cannot be used for other content.

### Relation to existing ADRs

* ADR-0015 (shareable install links). Status unchanged. URL and mobile behavior unchanged. Desktop-fallback rendering moves from Flutter PWA to Netlify-rendered HTML. A small clarifying note is added to ADR-0015's consequences in the same change set.
* ADR-0026 (sheet-based context navigation). Status unchanged. `/brief/...` URLs and in-app sheet behavior unchanged. Desktop-fallback rendering is interim-redirected until ADR-0041 lands.
* ADR-0016 (PWA cache strategy). Status unchanged. The cache strategy applies on `web.ringdrill.app` from day one. The apex SW retirement is a separate one-shot, not a cache-strategy change.
* ADR-0021 (iOS bundle identifier). Status unchanged. AASA stays on apex.
* ADR-0013 (local catalog testing). Status unchanged. `netlify dev` continues to emulate the API. `RINGDRILL_LOCAL_BASE_URL` continues to work for local PWA development.

### Consequences

* Good: Cold visits to `ringdrill.app` render real HTML in well under a second instead of waiting on Flutter bootstrap.
* Good: Install and brief links get OG tags and SEO-indexable previews. Social card scrapers see meaningful content.
* Good: Netlify build minutes drop close to zero. Only function changes redeploy.
* Good: Netlify bandwidth drops drastically. PWA asset traffic moves to Cloudflare's CDN, which is free at the volumes RingDrill realistically sees.
* Good: Service Worker scopes are isolated. Site, PWA, and API responses no longer compete for the same SW scope.
* Good: Account-readiness is a placeholder, not infrastructure. ADR-0024 lands without retro-fitting topology.
* Good: Norwegian-first locale aligns with current audience. Switching default later is cheap.
* Bad: Three origins to manage and monitor. DNS, SSL and uptime now span Cloudflare and Netlify.
* Bad: Two new GHA workflows replace one. Deploy complexity rises moderately.
* Bad: Slug-preview responses pay one network hop (Cloudflare edge → Netlify origin) on the first uncached request. Edge caching mitigates after the first hit.
* Bad: A final Flutter web release (Phase 1) must ship before any infrastructure changes. It is the only programmatic surface we have into cached PWAs.
* Bad: User data on apex `localStorage` must be exported by the user. Two export surfaces (Phase 1 in-app, Phase 3 Astro `/migrate`) cover the install base, but the user must take an explicit action.
* Bad: Two locale flats (`/` and `/en/`) double the page count and the hreflang config surface. Maintenance grows linearly with content additions.

## Pros and cons of the options

### Option A: Cloudflare apex + Cloudflare PWA + Netlify API (chosen)
* Good: Pure static on both Cloudflare sites. No new runtime to learn.
* Good: Netlify becomes a single-purpose function host.
* Bad: One Cloudflare-to-Netlify proxy hop on uncached preview rendering.

### Option B: Cloudflare apex with Pages Functions + Cloudflare PWA + Netlify API
* Good: Edge-rendered previews skip the Netlify hop.
* Bad: Two Node runtimes to maintain. Explicitly rejected to avoid tech-debt growth.

### Option C: Cloudflare apex + Netlify PWA + Netlify API
* Good: Smallest change to the PWA deploy pipeline.
* Bad: Netlify bandwidth and build-minute pressure stays as-is. Misses one of the main motivations.

### Option D: Path-based split on apex
* Good: One Cloudflare site, one deploy target.
* Bad: Flutter `--base-href=/app/` rewrite and full `netlify.toml` header rewrite. Service Worker scope juggling. Maintainer rejected before drafting.

### Option E: PWA on `web.ringdrill.app` (chosen)
* Good: Separate origin, separate SW scope, cleanest split.
* Bad: One-time migration for existing apex PWA installs.

### Option F: PWA on `ringdrill.app/app/`
* Good: One origin.
* Bad: Maintainer rejected. Same drawbacks as Option D.

### Option G: PWA on apex, site on `www.`
* Good: Preserves existing PWA installs without migration.
* Bad: `www.` and apex as distinct surfaces is SEO-fragile. People drop `www.` instinctively, and search engines have to pick a canonical.

### Option H: Norwegian default at `/` (chosen)
* Good: Matches current user base.
* Bad: Less aligned with international-SaaS convention.

### Option I: English default at `/`
* Good: Future-proofs for international audience.
* Bad: Norwegian browsers land on a less-natural URL today.

### Option J: Slug preview on Netlify (chosen)
* Good: Renderer lives next to data, reuses `_shared.js` and the blob client.
* Good: One Node runtime to maintain.
* Bad: One network hop on first uncached request.

### Option K: Slug preview on Cloudflare Pages Functions
* Good: No edge-to-origin hop after first build.
* Bad: Two Node runtimes, two rendering implementations.

### Option L: Pre-render every slug at publish time
* Good: Maximum static, no runtime call at request time.
* Bad: Every drill upload triggers a Cloudflare deploy. Adds a webhook and rebuild quota concerns.

## Links

* Related ADRs: [ADR-0008](./0008-persistent-program-library-and-catalog.md), [ADR-0013](./0013-local-catalog-testing.md), [ADR-0014](./0014-server-assigned-drill-version.md), [ADR-0015](./0015-shareable-install-links.md), [ADR-0016](./0016-pwa-cache-strategy.md), [ADR-0021](./0021-ios-bundle-identifier-app-ringdrill.md), [ADR-0023](./0023-brief-theme-tokens.md), [ADR-0024](./0024-account-and-identity-model.md), [ADR-0026](./0026-sheet-based-context-navigation.md)
* Future ADRs referenced: ADR-0040 (catalog feed schema extension), ADR-0041 (brief pre-rendering port)
* Related code: `netlify/functions/_shared.js`, `netlify/functions/deep-link.js`, `netlify/functions/market-feed.js`, `netlify/functions/drills-upload.js`, `netlify.toml`, `web/index.html`, `web/manifest.json`, `.github/workflows/deploy-web.yml`, `lib/web/mobile_app_nudge.dart`
* External references: Cloudflare Pages `_redirects` proxy syntax, Astro i18n routing, Netlify Functions Blobs API
