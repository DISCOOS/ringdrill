---
status: accepted
date: 2026-07-02
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0040: Extend the catalog feed schema with description, exercise count, author and access policy

## Context and problem statement

The shared catalog feed at `GET /api/market/feed` (`netlify/functions/market-feed.js`) returns a deliberately thin per-item shape: `programId`, `slug`, `name`, `tags`, `latestUrl` and `updatedAt`. That was enough while the only consumer was the in-app catalog browser, which opens each plan for the rest of its detail.

ADR-0039 changes the audience. It reserves a public catalog browse at `/catalog` on the site, reading the same feed — not yet built (the site today ships only the landing, `/migrate` and the legal pages), but it is the next site route and this ADR defines the contract it will consume. Unlike the in-app browser, a public `/catalog` has no app to fall back on: whatever the feed carries is all a browser sees. A card that shows only a name and a tag list is thin for a public listing. It cannot show a one-line description, how many exercises a plan holds, who published it, or whether the plan is open for wiki-style collaboration or locked to an account.

Two of these fields are already half-wired and inconsistent. `meta.json` has stored `description` since ADR-0043, but the feed never projects it. The slug-preview renderer (`drills-preview.js`) already reads `meta.exerciseCount` and renders "N øvelser / N exercises", yet nothing ever writes that field — the upload path computes neither the count nor persists it, so the preview line is dead today. ADR-0044's promised meta endpoint `GET /api/drills/:slug/meta` is specified to return `exerciseCount`, which likewise has no source. And ADR-0024/0025 introduce a per-plan `accessPolicy` (`account | shared | public`) that catalog UIs will need to surface once sign-in lands, but there is nowhere in the catalog contract to carry it.

We need to decide what the catalog contract carries, and — critically — where the derived fields are computed so the feed stays a cheap, CDN-cached list.

## Decision drivers

* The planned public `/catalog` (ADR-0039) is the reason to widen the contract now. Its cards will need a description snippet, an exercise count and an author to be useful outside the app, and the feed shape should be right before that route is built. The in-app catalog browser is the only consumer today.
* The feed is a hot, cacheable list path (`cache-control: public, max-age=30`). It must not open every `.drill` archive per request to derive a count. Derived fields must be precomputed and stored.
* `exerciseCount` must have exactly one source of truth and be consistent across the feed, the per-slug meta endpoint (ADR-0044) and the slug preview. Today the preview reads a field nobody writes.
* Prepare for ADR-0024/0025 without blocking on auth. `author` and `accessPolicy` must be carriable now and resolve to richer values once accounts land, degrading gracefully until then.
* Backward compatibility. Existing `meta.json` blobs predate these fields. The feed and every client must tolerate their absence with sane defaults, and no bulk backfill may be required — a re-publish repopulates.
* This is a catalog *contract* change, not a `.drill` format change. `KNOWN_SCHEMA_MAX` (1.2) stays put; `exerciseCount` is derived from `program.json`, not a new stored `.drill` field.

## Considered options

* A: Persist the derived fields into `meta.json` at publish time (`drills-upload.js` computes `exerciseCount` from `program.json` and stores `author` and `accessPolicy`), then widen `market-feed.js` and the ADR-0044 meta endpoint to project `description`, `exerciseCount`, `author` and `accessPolicy`.
* B: Leave `meta.json` alone and compute `exerciseCount` on the fly in the feed by fetching and unzipping each plan's `.drill`.
* C: Add a separate per-plan sidecar blob (e.g. `feed.json`) holding the extended fields, written alongside `meta.json`.
* D: Extend only the per-slug meta endpoint (ADR-0044), leaving the feed at its current shape and letting the site fan out one request per listed slug.

## Decision outcome

Chosen option: **Option A**. The publish path is the one place that already unzips and inspects `program.json`, so it is the natural place to derive `exerciseCount` (the length of `program.json.exercises`) and record it. `author` and `accessPolicy` are written from the same upload metadata. `description` is already persisted; the only change on the read side is to project it. `market-feed.js` and the ADR-0044 meta endpoint then read straight from `meta.json` with no extra I/O, keeping the feed cheap and cacheable.

The catalog feed item shape goes from:

```
{ programId, slug, name, tags, latestUrl, updatedAt }
```

to:

```
{ programId, slug, name, description, tags, exerciseCount, author, accessPolicy, latestUrl, updatedAt }
```

Field semantics and defaults:

* `description` — the plan description already stored in `meta.json` (ADR-0043). Carried in full; clients truncate for card display. Absent → `""`.
* `exerciseCount` — integer, `program.json.exercises.length` at publish time. Computed and written by `drills-upload.js`. Absent on legacy blobs → `null`; clients omit the count line rather than showing `0`.
* `author` — a display-oriented author reference. Today it mirrors `ownerId`, which is opaque and usually `"anon"`; ADR-0024 resolves it to an account display name. Field is reserved and populated best-effort. Absent → `null`.
* `accessPolicy` — one of `account | shared | public` per ADR-0025. Written when known. Absent on legacy blobs → treated as `public` for `ownerId="anon"` plans (matching ADR-0025's rule that pre-account plans default `public`), otherwise `account`.

`meta.json` is an internal server blob with no client-facing schema version, so adding fields to it is additive and safe. The `.drill` archive schema is untouched. Old blobs keep working; the first re-publish of any plan repopulates its new fields. No migration job is written.

### Consequences

* Good: The public catalog can render meaningful cards — description, exercise count, author — from one cached list request, with no per-item fan-out.
* Good: `exerciseCount` gets a single source of truth. The dead preview line in `drills-preview.js` lights up, and the ADR-0044 meta endpoint's `exerciseCount` becomes real, all from the same stored value.
* Good: The feed stays a cheap, CDN-cacheable projection. No archive reads on the hot path.
* Good: `author` and `accessPolicy` are in the contract before ADR-0024/0025 land, so lighting up sign-in and lock indicators later is a value-population change, not a schema change.
* Good: Fully backward compatible. Legacy blobs degrade to sane defaults and self-heal on the next publish.
* Bad: Values are as fresh as the last publish. A plan published before this ADR shows `exerciseCount: null` until re-published; there is no backfill.
* Bad: `exerciseCount` is a snapshot written at publish time. If the derivation logic ever changes, counts stay stale until re-publish. Acceptable for a display hint, not for anything load-bearing.
* Bad: Exposing `author`/`ownerId` in a public feed is an identity surface. Today it is `"anon"` or an opaque id, so no real name leaks, but ADR-0024 must decide deliberately what display name resolves here before real identities exist.
* Bad: A wider feed item means the Dart `MarketFeedItem` model and its JSON parsing grow, and the site catalog card gains fields — coordinated but minor client work.

## Pros and cons of the options

### Option A — persist derived fields in `meta.json`, project them in the feed (chosen)
* Good: One computation site (publish), one storage site (`meta.json`), cheap reads everywhere.
* Good: Reuses the unzip the upload path already does; no new blob or write coordination.
* Bad: Snapshot semantics — values are only as fresh as the last publish, and no backfill.

### Option B — compute `exerciseCount` on the fly in the feed
* Good: Always exact; no snapshot staleness.
* Bad: Fetch + unzip per item turns a cheap list into N archive reads. Destroys the `max-age` list path and blows up feed latency and cost.

### Option C — separate sidecar blob per plan
* Good: Keeps `meta.json` untouched.
* Bad: A second blob to write transactionally alongside `meta.json` and keep in sync, for fields `meta.json` can hold directly. Extra storage and a new consistency failure mode for no benefit.

### Option D — extend only the per-slug meta endpoint
* Good: Smallest change; the feed contract is unchanged.
* Bad: The site catalog would issue one meta request per listed slug — an N+1 fan-out from a list page, exactly what a feed exists to avoid. The fields belong in the bulk feed.

## Migration and sequencing

1. `drills-upload.js`: compute `exerciseCount` from the already-unzipped `program.json` (`Array.isArray(exercises) ? exercises.length : null`) and write it to `meta.json`. Write `author` (from the upload's owner/account context; `ownerId` today) and `accessPolicy` (default per ADR-0025) into `meta.json`. `description` already lands here.
2. `market-feed.js`: project `description`, `exerciseCount`, `author` and `accessPolicy` into each feed item, reading straight from `meta.json`. No new I/O. Keep the existing `cache-control`.
3. ADR-0044 meta endpoint (`GET /api/drills/:slug/meta`): return the same fields, so the feed and the per-slug endpoint agree.
4. `drills-preview.js`: no change required — it already reads `meta.exerciseCount`; the field is now populated, so the count line renders for freshly published plans.
5. Flutter `MarketFeedItem` (`lib/data/drill_client.dart`): add nullable `description`, `exerciseCount`, `author` and `accessPolicy`, parsed with graceful defaults. The in-app catalog browser surfaces them; the site `/catalog` card consumes them when that route is built (ADR-0039). `accessPolicy` stays inert in the UI until ADR-0024/0025 land.
6. No backfill. Legacy blobs repopulate on their next publish. Optionally, an admin re-publish sweep can be run later if the catalog looks sparse, but it is not required by this ADR.

## Links

* Related ADRs: [ADR-0039](./0039-site-pwa-api-origins.md) (site/PWA/API origin split, which references this ADR), [ADR-0043](./0043-tags-in-drill-format.md) (name/description/tags live in `program.json`, publish is last-write-wins), [ADR-0044](./0044-render-preview-on-site.md) (meta JSON endpoint that returns `exerciseCount`), [ADR-0008](./0008-persistent-program-library-and-catalog.md) and [ADR-0010](./0010-live-catalog-updates.md) (catalog and HEAD polling), [ADR-0024](./0024-account-and-identity-model.md) and [ADR-0025](./0025-authorization-and-publish-policy.md) (Account/Identity and `accessPolicy`)
* Related code: `netlify/functions/market-feed.js`, `netlify/functions/drills-upload.js`, `netlify/functions/drills-preview.js`, `netlify/functions/_shared.js`, `lib/data/drill_client.dart` (`MarketFeedItem`), `lib/views/widgets/catalog_browser.dart`, `site/` catalog route (planned, ADR-0039)

## Addendum (2026-07-02): map center for the public catalog

The site `/catalog` route (ADR-0039) is being implemented next, with a small map preview per card (Leaflet.js, same tile provider as the in-app map). That needs one more derived field. This addendum extends the schema decided above; it does not change or reopen it.

**Field.** `mapCenter: { lat: number, lng: number } | null`, added to the feed item shape. The full shape is now:

```
{ programId, slug, name, description, exerciseCount, author, accessPolicy, mapCenter, tags, latestUrl, updatedAt }
```

**Semantics.** The centroid — a simple average — of every positioned station's coordinates across every exercise in the plan. `null` when the plan has no positioned stations, or if computation fails for any reason at publish time. Never a fake `(0, 0)` — same "omit, don't fake" rule `exerciseCount` already follows.

**Precision is deliberately coarse.** A single approximate point, not a bounding box, not per-station pins. Station coordinates are real-world locations — often actual search-and-rescue exercise sites — and `/catalog` is unauthenticated and public. The in-app map shows exact per-station positions to someone who already has the plan open; the public catalog card shows only "roughly here." This is an intentional, permanent precision gap between the two surfaces, not a placeholder to later sharpen.

**Derivation.** Computed in `drills-upload.js` at publish time, extending the same unzip pass `exerciseCount` uses: for each `exercises/<uuid>.json` archive entry, read `stations[].position` (present when set, GeoJSON `{"coordinates":[lng, lat]}` — note the GeoJSON longitude-first order, matching the Flutter side's `NullableLatLngJsonConverter` in `lib/models/lat_lng_converter.dart`). Collect every finite coordinate across every exercise and average. Persisted into `meta.json` as `mapCenter`, projected through `metaToFeedItem` in `_shared.js` exactly like the other fields this ADR added. Legacy blobs (no `mapCenter` key) project as `null` and self-heal on next publish, same as `exerciseCount`.

**Tile provider and attribution.** The public map reuses the same tile provider as the in-app map (`lib/views/map_view.dart`): Kartverket, the Norwegian Mapping Authority, `https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png`. Confirmed acceptable for this public, higher-traffic origin. Unlike the in-app map — which renders no attribution today, a separate pre-existing gap not addressed here — the public map **must** show a visible "© Kartverket" attribution.

**Consequences.** One more field that must keep degrading gracefully for legacy blobs. A small new Node-side average calculation (plain arithmetic, no new backend dependency). The site gains its first third-party JS dependency (Leaflet) and its first third-party network dependency beyond its own API origin (Kartverket tiles), both scoped to the `/catalog` page.
