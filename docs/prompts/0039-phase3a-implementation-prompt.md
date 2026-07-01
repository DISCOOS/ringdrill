# ADR-0039 Phase 3a — Apex-takeover assets on the Astro site

You are working in the RingDrill repository. Implement Phase 3a of [ADR-0039](../adrs/0039-site-pwa-api-origins.md). ADR-0039 is accepted and authoritative. Read these sections before starting:

* Topology (`_redirects` structure)
* Phase 3 (in Rollout phases)
* User data migration (`/migrate` behaviour)

Phase 1 and Phase 2 (2a + 2b + 2c) are already landed. Phase 3a adds the site-side assets that make apex ready for the DNS flip in the manual cutover step. Nothing in 3a affects production until the maintainer flips the apex CNAME from Netlify to Cloudflare Pages (`ringdrill-site`), which happens separately.

## Scope

Site-only. All work in `site/`. No changes to Flutter, Netlify functions, GHA workflows or `netlify.toml`.

## Steps

### Step 1 — `_redirects` on apex

Add `site/public/_redirects` (Cloudflare Pages picks it up at build). Content:

```
# Proxy dynamic paths to the Netlify API subdomain. Status 200 keeps the
# browser URL as ringdrill.app/... which is required for App-Links,
# Universal Links and stable share links (ADR-0015, ADR-0021, ADR-0039).
/api/*                  https://api.ringdrill.app/api/:splat                  200
/.netlify/functions/*   https://api.ringdrill.app/.netlify/functions/:splat   200
/d/*                    https://api.ringdrill.app/d/:splat                    200
/i/*                    https://api.ringdrill.app/i/:splat                    200
/brief/*                https://api.ringdrill.app/brief/:splat                200

# Vanity redirects for people who type these paths from muscle memory.
# 301 so the browser URL updates.
/web                    https://web.ringdrill.app/                            301
/app                    https://web.ringdrill.app/                            301
```

`/i/*` and `/brief/*` will 404 at the Netlify side until Phase 3b lands the `drills-preview` function. That is expected — the manual cutover step happens after 3b, so the gap is closed by the time apex flips.

Commit: `feat(site): add _redirects for apex proxy and vanity rules`. Verify `git status` is clean.

### Step 2 — `_headers` for `.well-known/*`

Add `site/public/_headers` (Cloudflare Pages picks it up at build). Content:

```
/.well-known/apple-app-site-association
  Content-Type: application/json
  Cache-Control: public, max-age=3600

/.well-known/assetlinks.json
  Content-Type: application/json; charset=utf-8
  Cache-Control: public, max-age=3600
```

`apple-app-site-association` has no extension; Cloudflare's default `Content-Type` guessing gets it wrong without this. The current Netlify-served version is served identically per `netlify.toml`.

Commit: `feat(site): add _headers for .well-known content types`. Verify `git status` is clean.

### Step 3 — Self-unregister Service Worker stub

Add `site/public/flutter_service_worker.js`. Old apex PWAs check this URL for SW updates on each open; the stub replaces itself, clears caches, unregisters, and posts a message to any controlled client so the next reload lands on the Astro site.

```js
// ADR-0039 Phase 3 self-unregister stub.
// Old Flutter service workers on ringdrill.app fetch this file on their
// next update check. Installing it takes them out of service; the next
// reload falls through to the Astro site and the migration UI kicks in.
self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map((n) => caches.delete(n)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      client.postMessage({ type: 'sw-retired' });
    }
  })());
});
```

No `fetch` handler — with no handler and unregister complete, the browser falls back to network for every request, which is exactly what we want.

Also add a `Cache-Control: no-cache` header for this file in `_headers` so browsers do not stick with a stale stub:

```
/flutter_service_worker.js
  Cache-Control: no-cache
  Content-Type: application/javascript
```

Commit: `feat(site): serve self-unregister SW stub for retired apex PWA`. Verify `git status` is clean.

### Step 4 — Landing banner for retiring PWA users

The Astro landing (`site/src/pages/index.astro` and `site/src/pages/en/index.astro`) should detect two signals on the client and show a persistent banner nudging the visitor to `/migrate`:

1. **Flutter localStorage keys present.** Enumerate `localStorage` for keys starting with `p:`, `pe:`, `pt:`, `ps:` (per ADR-0008) or `app:librarySchema:v1`. If any are found, the visitor is a former apex-PWA user with local data.
2. **Existing SW registration on `/`.** `navigator.serviceWorker.getRegistration('/')` resolves to something non-null on old installs even after the stub has unregistered on that session.

Show the banner if either signal is true.

Banner layout: fixed to the top of the page, above the fold, above any hero. Two lines:

* Heading (bold): `Web-appen er flyttet til web.ringdrill.app` (nb) / `The web app has moved to web.ringdrill.app` (en)
* Body: `Klikk her for å hente ut planene dine og åpne den nye appen.` (nb) / `Click here to export your plans and open the new app.` (en)

The whole banner is a link to `/migrate` (or `/en/migrate` for the English page).

Style: `Theme.of(context).colorScheme.secondaryContainer` equivalent — a muted accent background so it does not scream but is unmissable. Small close (`×`) icon on the right that dismisses the banner for this session (does not need to survive reloads).

Extract the logic into a shared Astro component `site/src/components/MigrationNudge.astro` so both landing pages can include it with one line.

Commit: `feat(site): show migration nudge banner on landing for former apex PWA users`. Verify `git status` is clean.

### Step 5 — `/migrate` page

Add `site/src/pages/migrate.astro` (nb) and `site/src/pages/en/migrate.astro` (en). Client-side JS reads Flutter localStorage, constructs a ZIP of `.drill` archives, and offers a download. No server calls.

Content requirements:

* Heading and short intro (nb/en) explaining what the page does. Wording aligned with the Phase 1 in-app explainer where relevant.
* On load, count Flutter localStorage entries. If none, show a friendly "nothing to migrate" state with a link back to the landing.
* If entries found, show a primary CTA `Last ned alle planene mine` / `Download all my plans`. Report how many programs were found.
* Click handler:
  1. Enumerate localStorage.
  2. Group by program using the `p:<uuid>` key pattern to find program shells, then collect matching `pe:<uuid>:*`, `pt:<uuid>:*`, `ps:<uuid>:*` entries.
  3. For each program, build a `.drill` archive using `fflate`. The archive format is a ZIP containing `metadata.json`, `program.json`, and per-entity folders as described in ADR-0007 and ADR-0022. Refer to `lib/data/drill_file.dart` for the exact structure — the Astro implementation must produce archives that the new PWA's existing import pipeline can ingest without modification.
  4. Bundle all `.drill` files into one outer ZIP named `ringdrill-eksport-YYYY-MM-DD.zip` (local date).
  5. Trigger download via a hidden `<a download>` and `URL.createObjectURL(blob)`.
* After download, reveal a secondary CTA `Åpne web-appen og importer` / `Open the web app and import` pointing to `https://web.ringdrill.app/?import=guide`.
* At the bottom, a small note explaining that data on `ringdrill.app` stays in the browser until cleared, and this page can be reopened later to re-export.

Add `fflate` as a dev dependency in `site/package.json`:

```bash
cd site && npm install --save-dev fflate
```

Extract the migration logic into a small module `site/src/lib/migrate.ts` (or `.js`) so it is testable and reusable. The Astro page imports the module and wires up the UI.

Add a unit test for the migration module. It builds a minimal fake localStorage (three programs, each with one exercise), runs the ZIP builder, and asserts:

* Outer ZIP contains three files with `.drill` extension
* Each `.drill` unzips to the expected structure per ADR-0007
* Filenames are sanitised versions of program names

Use whatever test runner Astro's scaffold has (vitest is the usual pick). Add it to `site/package.json` scripts if not already there.

Commit: `feat(site): add /migrate page with client-side .drill export`. Verify `git status` is clean.

### Step 6 — Verification

* `cd site && npm run build` clean
* `cd site && npm test` clean (migration module test passes)
* Preview locally: `cd site && npm run preview`, then:
  - Open `http://localhost:4321/` — landing renders. If you seed `localStorage` with a dummy `p:test-uuid` entry via devtools, the migration nudge appears.
  - Open `http://localhost:4321/migrate` — page renders. With the seeded entry, the CTA is enabled. Click triggers a ZIP download named `ringdrill-eksport-YYYY-MM-DD.zip`.
  - Unzip it and verify structure (one `.drill` per program, each unzips to `metadata.json` + `program.json` + entity folders).
* `dist/_redirects` exists after build and contains all rules (Cloudflare Pages picks up the file automatically).
* `dist/_headers` exists after build with the .well-known and SW headers.
* `dist/flutter_service_worker.js` exists and matches the source.
* `git status` clean

## Out of scope

* `drills-preview` Netlify function — Phase 3b
* Any change to `deploy-web.yml` — Phase 3c
* Flipping `MIGRATION_DISABLED` in the workflow env — Phase 3c
* Manual DNS or custom-domain steps at Cloudflare
* Any change to `netlify.toml` or existing Netlify functions
* Any change to Flutter code

## Definition of done

Five commits in order: `feat(site)` × 5. `npm run build` clean. `npm test` clean. Manual preview passes per Step 6. `git status` clean after every commit.

## Commit message conventions

Conventional commits, lowercase, imperative present tense, English. Match the style of recent commits in the repo. Each step has its own commit; do not squash.
