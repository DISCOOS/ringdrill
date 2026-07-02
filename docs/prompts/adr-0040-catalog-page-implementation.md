# Implement the `/catalog` site route

You are working in the RingDrill repository. Build the public catalog browse page, `/catalog` (nb) + `/en/catalog` (en), on the Astro site under `site/`. The route is reserved by ADR-0039 (`docs/adrs/0039-site-pwa-api-origins.md`, "Site source" section) but never built. Read that ADR first, then `docs/adrs/0040-catalog-feed-schema-extension.md` **including its "Addendum (2026-07-02): map center for the public catalog" section at the end** — that addendum is authoritative for the new `mapCenter` field this prompt introduces. Then read this prompt in full before touching code.

## Rendering model — read this first

This is **not** a build-time-static page. Render it on-demand, per request, following the pattern already designed (but not yet implemented) for ADR-0044 — read `docs/prompts/adr-0044-render-preview-on-site-implementation.md` Steps 2–3 for the concrete shape: add the `@astrojs/cloudflare` adapter, keep every existing page prerendered (static) by default, and opt only the new route into on-demand rendering (`export const prerender = false`). Fetch data at request time from a configurable API base (`import.meta.env.PUBLIC_RINGDRILL_API_BASE`, default the production API origin), never a hardcoded origin.

**ADR-0044 has not been implemented yet either.** This prompt is the first to introduce the Cloudflare adapter and the `PUBLIC_RINGDRILL_API_BASE` convention. When ADR-0044's `/i/[slug]` route is built later, its own "add the adapter" step becomes a no-op confirmation that the adapter is already there and configured correctly — do not be surprised by that when it happens, and do not remove or reconfigure the adapter as part of that future work without checking this route still works.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that matter here:

* `netlify/functions/` and `site/` are separate projects with separate test runners. Netlify tests run from the repo root (`npm test` — requires Node ≥20; if the shell's default `node` is older, use a newer one via `nvm use` or equivalent before running). Site tests run from `site/` (`npm --prefix site test` or `cd site && npm test`, which is `vitest run`).
* `market-feed.js` already returns everything this page needs — `description`, `exerciseCount`, `author`, `accessPolicy`, and (after Step 1 of this prompt) `mapCenter` — alongside `name`, `tags`, `latestUrl`, `updatedAt`. Do not add a new Netlify endpoint for the catalog list.
* No feed-level filtering by `accessPolicy` (ADR-0025: the feed is public/unauthenticated, same as today). List every published item the feed returns, exactly like the in-app catalog browser does.
* `accessPolicy` stays inert in the UI — parsed if you touch it at all, never rendered — same rule ADR-0040 applies everywhere else, until ADR-0024/0025 sign-in lands.
* **`mapCenter` precision is fixed policy, not a placeholder.** One coarse centroid point per plan, never per-station pins, never a bounding box. This is a deliberate privacy choice (real search-and-rescue exercise locations, unauthenticated public page) documented in ADR-0040's addendum — do not "improve" the fidelity.
* The public map **must** show a visible "© Kartverket" attribution. The in-app map's own missing attribution is separate, pre-existing debt — do not fix it as a drive-by in this change.
* Card click-throughs go to `/i/<slug>?lang={lang}` (the human preview page), never the feed's raw `latestUrl`/`/d/<slug>` binary download link.
* Reuse the site's existing tokens/CSS (`site/src/layouts/BaseLayout.astro`'s `<style is:global>`) and copy dictionary (`site/src/i18n.ts`, `t(lang)`). Do not introduce a second token set or a parallel copy mechanism.
* Every current page (`index`, `en/index`, legal, `migrate`) must stay prerendered after the adapter lands — confirm this explicitly, do not turn the whole site server-rendered.
* Do not touch version/release steps.

## Commits

Commit as you progress, not in one blob. Conventional Commits with a scope. Scopes: `netlify`, `site`, `i18n`, `docs`. Suggested subjects:

* `feat(netlify): derive and persist mapCenter on publish`
* `feat(netlify): project mapCenter in the feed`
* `chore(site): add Cloudflare adapter for on-demand rendering`
* `feat(site): add catalog data-fetch and pagination helper`
* `feat(site): render /catalog with card grid and map previews`
* `feat(site): add Katalog/Catalog nav link`
* `chore(make): wire site-dev to the local API base`
* `docs(adr): note /catalog renders on-demand in ADR-0039`

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done.
* Each step lists the files expected in that commit. The commit must include every listed path.
* Never close a step with `git stash` or `git restore`. If it is in the working tree, it ships.
* The final Verification gate requires `git status` to print a clean tree.

## Scope

Seven steps, in order.

### Step 1. Backend: derive and persist `mapCenter` on publish

Edit `netlify/functions/drills-upload.js`. The existing `countExerciseFiles(files)` helper (added when `exerciseCount` was corrected to scan archive files instead of `program.json.exercises`) only counts `exercises/<uuid>.json` entries by filename. Replace it with a combined pass that also extracts station positions, since both derivations need to open the same files:

```js
// Parse every top-level exercises/<uuid>.json entry once, returning both the
// exercise count and every finite station position found across them.
// Malformed individual exercise files are skipped, never thrown — one bad
// file must not fail the whole publish.
function parseExerciseFiles(files) {
    const result = { count: 0, positions: [] };
    if (!files) return result;
    for (const name of Object.keys(files)) {
        if (!/^exercises\/[^/]+\.json$/.test(name)) continue;
        result.count++;
        try {
            const ex = JSON.parse(strFromU8(files[name]));
            const stations = Array.isArray(ex?.stations) ? ex.stations : [];
            for (const s of stations) {
                const coords = s?.position?.coordinates;
                if (Array.isArray(coords) && coords.length === 2) {
                    const [lng, lat] = coords;
                    if (Number.isFinite(lng) && Number.isFinite(lat)) {
                        result.positions.push([lng, lat]);
                    }
                }
            }
        } catch {
            // malformed exercises/<uuid>.json — skip, don't throw
        }
    }
    return result;
}

// Centroid (simple average) of [lng, lat] pairs. null when there are none —
// never a fake (0, 0). See ADR-0040's map-center addendum for why this is a
// single coarse point, not a bounding box or per-station detail.
function computeMapCenter(positions) {
    if (!positions.length) return null;
    const [sumLng, sumLat] = positions.reduce(
        (acc, [lng, lat]) => [acc[0] + lng, acc[1] + lat],
        [0, 0],
    );
    return { lat: sumLat / positions.length, lng: sumLng / positions.length };
}
```

Update `programInfoFromArchive` to use `parseExerciseFiles` once and return `mapCenter` alongside `exerciseCount`:

```js
export function programInfoFromArchive(files) {
    const { count: exerciseCount, positions } = parseExerciseFiles(files);
    const mapCenter = computeMapCenter(positions);
    const entry = files?.["program.json"];
    if (!entry) return { name: null, description: null, tags: [], exerciseCount, mapCenter };
    try {
        const p = JSON.parse(strFromU8(entry));
        return {
            name: typeof p?.name === "string" ? p.name : null,
            description: typeof p?.description === "string" ? p.description : null,
            tags: Array.isArray(p?.tags) ? p.tags : [],
            exerciseCount,
            mapCenter,
        };
    } catch {
        return { name: null, description: null, tags: [], exerciseCount, mapCenter };
    }
}
```

Update the JSDoc above `programInfoFromArchive` to mention `mapCenter`. In the publish handler, after the existing `currentMeta.exerciseCount = program.exerciseCount;` line, add `currentMeta.mapCenter = program.mapCenter;`.

Update `netlify/tests/drills-upload-meta.test.mjs`: every existing `programInfoFromArchive`/`stripActorsAndValidate` deepEqual assertion needs its expected object to gain `mapCenter` (most will expect `null`, since those fixtures have no `exercises/` files). Add new tests:

* Two `exercises/<uuid>.json` files, each with one positioned station → `mapCenter` is the average of both.
* A station with `position: null` (or missing) among positioned ones → ignored, doesn't skew the average or throw.
* A malformed `exercises/<uuid>.json` (invalid JSON) → skipped for both `exerciseCount` and `mapCenter`, never throws (extend the existing malformed-archive test rather than adding a parallel one).
* No positioned stations anywhere → `mapCenter: null`, not `{lat: 0, lng: 0}`.
* Non-finite coordinates (e.g. `NaN`, `Infinity` if constructible via `JSON.parse` — use a string that parses to a huge/invalid number, or a coordinates array with a non-numeric entry) are excluded from the average.

Run `npm test` (Node ≥20).

Files expected in this commit: `netlify/functions/drills-upload.js`, `netlify/tests/drills-upload-meta.test.mjs`.

### Step 2. Backend: project `mapCenter` in the feed

Edit `netlify/functions/_shared.js`'s `metaToFeedItem`. Add, alongside the existing `accessPolicy` line:

```js
mapCenter: (meta.mapCenter && Number.isFinite(meta.mapCenter.lat) && Number.isFinite(meta.mapCenter.lng))
    ? { lat: meta.mapCenter.lat, lng: meta.mapCenter.lng }
    : null,
```

Update the function's doc comment to mention `mapCenter` and its "absent on legacy blobs → null" default. Update `netlify/tests/_shared-feed-item.test.mjs`: add `mapCenter` to the "full modern blob" fixture and its expected output; add a case for a legacy blob with no `mapCenter` key (→ `null`); add a case where `meta.mapCenter` is present but malformed (e.g. `{lat: "not a number"}`) → `null`, never thrown. Update `netlify/tests/market-feed.test.mjs`'s fixtures/assertions the same way (widened-shape item now includes `mapCenter`, legacy-blob-defaults test covers `mapCenter: null` too).

Run `npm test`.

Files expected in this commit: `netlify/functions/_shared.js`, `netlify/tests/_shared-feed-item.test.mjs`, `netlify/tests/market-feed.test.mjs`.

### Step 3. Site: enable on-demand rendering

Add the `@astrojs/cloudflare` adapter to `site/` (matching the installed Astro major version — check `site/package.json`'s current `astro` version first). Configure `site/astro.config.mjs` for mixed static/on-demand output: the adapter is added, but every existing page keeps rendering statically by default; only pages that explicitly opt out (`export const prerender = false`) become on-demand. Confirm `npm --prefix site run build` still emits the existing pages (`index.html`, `en/index.html`, `migrate.html`, legal pages) as static files, unchanged.

If the adapter cannot be added for a structural reason (version mismatch, incompatible config), stop and report — do not swap in a different hosting/rendering model without checking back.

Files expected in this commit: `site/package.json`, `site/package-lock.json`, `site/astro.config.mjs`, any new adapter config file.

### Step 4. Site: catalog data-fetch helper

Add `site/src/lib/catalog.ts`, mirroring the pure-function-plus-vitest style of `site/src/lib/migrate.ts` (fully independent of Astro rendering, so it's testable without rendering a page):

```ts
export interface CatalogItem {
  programId: string;
  slug: string;
  name: string;
  description: string;
  exerciseCount: number | null;
  tags: string[];
  mapCenter: { lat: number; lng: number } | null;
  latestUrl: string;
  updatedAt: string | null;
}

export interface FetchCatalogOptions {
  apiBase: string;
  fetchImpl?: typeof fetch;
  maxPages?: number;
  maxItems?: number;
}

export interface FetchCatalogResult {
  items: CatalogItem[];
  truncated: boolean;   // a cap was hit — surfaced so the caller can log it
  failed: boolean;      // the fetch itself failed — surfaced so the page can show the right empty state
}
```

`fetchCatalog({ apiBase, fetchImpl = fetch, maxPages = 3, maxItems = 300 })`:

* Calls `${apiBase}/api/market-feed?limit=100&cursor=...`, paging through `nextCursor`.
* Stops when there's no `nextCursor`, or `maxPages`/`maxItems` is reached (set `truncated: true` and `console.warn(...)` when a cap stops an otherwise-nonempty pagination — never truncate silently).
* Concatenates every page's `items`, then **re-sorts the full list by `updatedAt` descending itself**, using the same comparator `market-feed.js` uses (`String(b.updatedAt).localeCompare(String(a.updatedAt))`). The feed only guarantees sort order *within* one call; concatenating multiple calls loses the global order without this.
* Wraps the whole thing in try/catch: a network error or non-2xx response returns `{ items: [], truncated: false, failed: true }` — never throws past the function. An API blip must degrade to an empty state, not crash the route.

Add `site/src/lib/catalog.test.ts` (vitest, `migrate.test.ts` style, mock `fetchImpl`) covering: single-page fetch, multi-page fetch via `nextCursor` with the cross-page sort verified, the `maxPages`/`maxItems` caps (with the warning logged — spy on `console.warn`), and a mocked fetch rejection/non-2xx → `{ items: [], failed: true }`.

Run `npm --prefix site test`.

Files expected in this commit: `site/src/lib/catalog.ts`, `site/src/lib/catalog.test.ts`.

### Step 5. Site: the catalog route, card grid and map previews

Add `site/src/components/CatalogCard.astro` — one card per `CatalogItem`:

* Heading with the plan `name`, linking to `` `/i/${item.slug}?lang=${lang}` `` (not `item.latestUrl`).
* Truncated `description` (CSS `-webkit-line-clamp: 3` or similar — no JS truncation needed).
* `exerciseCount` and `tags` as small badges/chips — omit the exercise-count badge entirely when `exerciseCount` is `null`, never show "0" for "unknown."
* Formatted `updatedAt` (skip if `null`).
* An explicit "Download"/"Last ned" button (`.btn .btn--primary .btn--sm`, reusing `BaseLayout`'s button classes), linking to the **same** `/i/<slug>?lang={lang}` target as the heading. This is deliberate: it mirrors the site's own existing idiom (the hero's "Last ned for Android" button links to a Play Store page, not an APK) — `/i/<slug>` is the front door that owns the real "open in app"/"download .drill" CTAs. Two links to the same place on one card (title + button) is intentional redundancy for scanability in a grid, not a bug to dedupe.
* A map preview **only when `item.mapCenter` is non-null** — omit the map slot entirely otherwise (do not render an empty/broken map container). Fixed height (~140px), Leaflet map centered on `mapCenter` at a fixed, fairly zoomed-out level (e.g. zoom 9–10 — far enough out that a single point reads as "this general area," not "this exact spot"). **Do not drop a marker/pin at the center point** — a visible pin reads as "the exact station," which defeats the entire point of using a coarse centroid instead of real per-station positions. Just a centered, static-looking tile view. Use the Kartverket `topo` tile layer (`https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png`, same as `lib/views/map_view.dart`), and enable Leaflet's attribution control with the text "© Kartverket" (visible, not suppressed — required by the tile terms and a hard requirement of ADR-0040's addendum).
* `author`/`accessPolicy` are on `CatalogItem` if you choose to add them, but are not rendered — same inert-for-now rule as everywhere else this ADR touches.

Add `leaflet` to `site/package.json` (plus `@types/leaflet` if the project finds it useful — check how strict the existing `tsconfig` is). This is a genuine precedent break worth being explicit about: the site has been vanilla-script-only until now (`MigrateApp.astro`/`MigrationNudge.astro` use plain `<script>` blocks, no framework, no client-side library). Leaflet is a mapping library, not a UI framework, so it doesn't contradict "no client framework" — but don't add it silently; note it in the commit body. Mount each card's map from a small `<script>` block (same "progressively enhance server-rendered markup" convention as `MigrateApp.astro`), reading the center coordinates off a `data-lat`/`data-lng` attribute on the card's map container, one `L.map(...)` instance per card that has one.

Add `site/src/pages/catalog.astro` (nb) and `site/src/pages/en/catalog.astro` (en), both starting with `export const prerender = false;`. Each:

* Calls `fetchCatalog({ apiBase: import.meta.env.PUBLIC_RINGDRILL_API_BASE || 'https://api.ringdrill.app' })`.
* Sets `Astro.response.headers.set('Cache-Control', 'public, max-age=30, s-maxage=60')` — mirrors `market-feed.js`'s own `max-age=30`; without this, every visit re-fetches the feed with no edge caching.
* Renders `BaseLayout` → `Nav` → `<main><section class="section">` (eyebrow/title/lead from the new i18n block below) → the card grid (or an empty state) → `Footer`, matching `index.astro`'s composition.
* Card grid: `.catalog__grid` (`display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 20px;`, mirroring `Features.astro`'s `.features__grid`) and `.catalog-card` (mirror `.feature`'s border/radius/shadow/hover-lift, tokens `--canvas-elev`, `--border`, `--radius-lg`, `--shadow-card`/`--shadow-lift`).
* Empty state, mirroring `404.astro`'s `.section`/`.container`/`.prose`/`.lead`/`.btn` pattern, with **two distinct copy variants**: `result.items.length === 0 && !result.failed` → "no plans published yet"; `result.failed` → "catalog temporarily unavailable" (never conflate the two — a real outage must not read as "there's simply nothing here").
* No client-side search/filter/pagination controls in this first cut. One full list per request. Note this as deferred, not silently dropped, if you add a code comment about future work.

Files expected in this commit: `site/src/components/CatalogCard.astro`, `site/src/pages/catalog.astro`, `site/src/pages/en/catalog.astro`, `site/package.json`, `site/package-lock.json`.

### Step 6. Site: i18n and nav link

Add a `catalog` block to `site/src/i18n.ts` for both `nb` and `en`, alongside the existing `hero`/`features`/`footer` blocks: `eyebrow`, `title`, `lead`, `emptyNoPlans`, `emptyUnavailable`, `updated` (label), `download` (button label — nb "Last ned", en "Download", matching the hero's existing wording for the same "go get it" idiom), and an exercise-count string if `CatalogCard` needs one beyond what already exists.

Add "Katalog"/"Catalog" to `Nav.astro`'s `.nav__links`, linking to `/catalog` (nb) / `/en/catalog` (en) via the existing `home`-relative pattern already used for `#features`.

Files expected in this commit: `site/src/i18n.ts`, `site/src/components/Nav.astro`.

### Step 7. Local dev wiring and docs

Update the `site-dev` Makefile target to export `PUBLIC_RINGDRILL_API_BASE=$(LOCAL_BASE_URL)` before `astro dev`, so local runs talk to the locally running functions instead of production by default when paired with `make netlify-dev`. Keep the default (unset → production origin) when a contributor runs `make site-dev` on its own. Document the two-shell workflow in the Makefile comment: `make netlify-dev` + `make catalog-seed` in one shell, `make site-dev` in another, then `http://localhost:4321/catalog`. Note that the checked-in seed fixture (`test/fixtures/test-7x.drill`) may or may not have positioned stations — if it doesn't, the correct result is cards with no map slot, not a bug to chase.

Append a short, dated implementation note to ADR-0039's "Site source" section (`docs/adrs/0039-site-pwa-api-origins.md`), matching its own established convention (the 2026-07-02 apex-proxy correction note at the top of that file): record that `/catalog` renders on-demand via the Cloudflare adapter and a request-time feed fetch, rather than the build-time-static approach the ADR originally sketched, and that this introduces the on-demand-rendering infrastructure ADR-0044 also depends on. Do not rewrite the ADR's original text — append only.

Files expected in this commit: `Makefile`, `docs/adrs/0039-site-pwa-api-origins.md`.

## Verification gate

Do not claim done until all of these pass:

* Repo-root `npm test` green (Netlify suites, including the two updated backend test files), run with Node ≥20.
* `npm --prefix site run build` succeeds; existing pages (`index`, `en/index`, legal, `migrate`) remain static/prerendered; `catalog`/`en/catalog` build as on-demand routes.
* `npm --prefix site test` green, including the new `catalog.test.ts`.
* Local debug works end to end: `make netlify-dev` + `make catalog-seed` in one shell, `make site-dev` in another, `http://localhost:4321/catalog` renders real cards from local data (map present or absent depending on the seed fixture's station positions — both are correct outcomes).
* Every `/catalog` card whose `mapCenter` is present shows a visible "© Kartverket" attribution.
* `git status` shows a clean tree — no untracked or unstaged files.

## Out of scope

* ADR-0044's own cutover (`/i/[slug]` native route, deleting `drills-preview.js`) — this prompt only introduces the shared on-demand-rendering infrastructure that work will reuse.
* Client-side search, filter, or "load more" pagination on `/catalog` — one full list per request for now.
* Any change to `mapCenter` precision (bounding boxes, per-station pins, zoom-to-fit) — the centroid-only, no-marker design is fixed policy per ADR-0040's addendum, not a first draft to refine.
* Fixing the in-app map's own missing Kartverket attribution — separate, pre-existing debt.
* Any backfill of existing `meta.json` blobs missing `mapCenter` — they self-heal on next publish, same as every other ADR-0040 field.
* Adding `mapCenter` to the Flutter `MarketFeedItem` — optional, not required for this prompt; the in-app catalog browser has no map view to feed it into today.
