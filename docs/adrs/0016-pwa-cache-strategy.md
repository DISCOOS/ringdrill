---
status: accepted
date: 2026-05-23
deciders: ["Kenneth Gulbrandsøy"]
consulted: []
informed: []
---

# ADR-0016: Non-fingerprinted Flutter web entry points are served with `no-cache`

## Context and problem statement

RingDrill's PWA is hosted on Netlify and built with `flutter build web --release --pwa-strategy=offline-first`. The earlier Netlify cache policy treated `/main.dart.js` the same way as `/assets/*` and `/canvaskit/*`, sending `Cache-Control: public, max-age=31536000, immutable`. That assumes the URL changes when the content changes.

That assumption is wrong for the Flutter web entry-point bundle. The release output emits files with stable, non-fingerprinted names (`main.dart.js`, `flutter_bootstrap.js`, `flutter.js`, `manifest.json`). When users had the file pinned in HTTP cache as `immutable`, the browser would not even ask the origin for up to a year, so freshly deployed JavaScript did not reach the running app.

The PWA-update flow in `lib/web/pwa_update_web.dart` and the snackbar in `lib/main.dart` rely on the service worker noticing a new `flutter_service_worker.js` and pulling the new bundle. With the entry-point files marked `immutable`, the service worker's update probe is effectively neutralized for any client whose browser still has the old `main.dart.js` cached - which is most returning users.

## Decision drivers

* Updates to the PWA must reach users within hours, not months, after a Netlify deploy.
* Offline-first behavior must be preserved; users who lose connectivity should still get the cached app.
* Fingerprinted assets (`/assets/*`, `/canvaskit/*`) should keep their long-lived cache so first-paint stays cheap.
* The fix should sit at one layer (the Netlify config) and not require app-side coordination.

## Considered options

* **A**: Keep `immutable` on `main.dart.js` and document the staleness as a known limitation.
* **B**: Switch the non-fingerprinted entry-point files to `Cache-Control: no-cache` so the browser always revalidates with the origin and the service worker can see a new build.
* **C**: Drop `--pwa-strategy=offline-first` and rely solely on HTTP cache headers.
* **D**: Manually fingerprint `main.dart.js` in a post-build step (rename + rewrite references in `index.html`/`flutter_bootstrap.js`).

## Decision outcome

Chosen option: **Option B**, because it removes the staleness without touching the build pipeline, keeps the existing service worker flow intact, and preserves offline support via the SW Cache Storage which is independent of HTTP cache headers.

`/main.dart.js`, `/flutter_bootstrap.js`, `/flutter.js`, `/manifest.json` and `/flutter_service_worker.js` are served `Cache-Control: no-cache`. Fingerprinted folders (`/assets/*`, `/canvaskit/*`) keep `public, max-age=31536000, immutable`.

### Consequences

* Good: Returning users pick up new builds on the next visit; the snackbar in `lib/main.dart` actually has new code to install.
* Good: Offline behavior is unchanged - the service worker keeps serving from Cache Storage, which is independent of HTTP-cache headers.
* Good: First-paint cost stays low because the large fingerprinted asset bundles remain immutable.
* Bad: Every revisit incurs a small revalidation roundtrip for ~5 files (304 in the common case). Acceptable; it matters less than getting updates delivered.
* Bad: A future contributor cleaning up "duplicated" `no-cache` lines could re-introduce the bug. This ADR exists to make that mistake visible.

## Pros and cons of the options

### Option A: Keep `immutable`

* Good: No deploy or config change.
* Bad: Users keep running stale builds for up to a year. This is the bug we just fixed.

### Option B: `no-cache` on non-fingerprinted entry points

* Good: Single-layer fix, no build pipeline change, offline still works through SW Cache Storage.
* Good: Service worker's existing update flow becomes effective again.
* Bad: Small revalidation cost per visit on 4-5 files.

### Option C: Drop offline-first

* Good: Cache behavior becomes simpler to reason about.
* Bad: Loses offline use, which is a core PWA promise for field use of RingDrill. Non-starter.

### Option D: Manually fingerprint `main.dart.js`

* Good: Allows real `immutable` headers and instant revalidation via URL change.
* Bad: Requires a custom post-build step, ties the deploy to it, and risks drift from upstream Flutter web tooling. Disproportionate for the benefit.

## Links

* Related code: [`netlify.toml`](../../netlify.toml), [`lib/web/pwa_update_web.dart`](../../lib/web/pwa_update_web.dart), [`lib/main.dart`](../../lib/main.dart)
* Related ADRs: none directly; this complements the general web/PWA distribution discussed in [`docs/architecture.md`](../architecture.md).
* External references:
  * Flutter web service worker source: <https://github.com/flutter/flutter/blob/main/packages/flutter_tools/lib/src/web/file_generators/flutter_service_worker_js.dart>
  * MDN, "Service Worker API: caching strategies": <https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Tutorials/CycleTracker/Service_workers>
