---
status: accepted
date: 2026-05-23
deciders: ["Kenneth Gulbrandsøy"]
consulted: []
informed: []
---

# ADR-0016: PWA update strategy: `no-cache` entry points, resilient SW detection, and an in-app last resort

## Context and problem statement

RingDrill's PWA is hosted on Netlify and built with `flutter build web --release --pwa-strategy=offline-first`. Three independent failure modes were producing the same symptom — users sitting on a stale build for days or weeks after a deploy — and they have to be fixed together to actually deliver updates:

1. **HTTP cache pinned non-fingerprinted entry points.** The earlier Netlify cache policy treated `/main.dart.js` the same way as `/assets/*` and `/canvaskit/*`, sending `Cache-Control: public, max-age=31536000, immutable`. That assumes the URL changes when the content changes. It does not. Flutter web's release output emits stable, non-fingerprinted names (`main.dart.js`, `flutter_bootstrap.js`, `flutter.js`, `manifest.json`). Once a browser cached `main.dart.js` as `immutable` it would not ask the origin again for up to a year.
2. **The PWA-update listener missed pre-existing waiting service workers.** `lib/web/pwa_update_web.dart`'s `wire()` only attached an `updatefound` listener and called `reg.update()`. If a previous session had already installed a new service worker into the `waiting` state — which happens whenever the user closes the tab between install and activation — no fresh `updatefound` would fire on the next visit. The listener never saw the waiting worker and the "Restart now" snackbar in `lib/main.dart` never appeared. Confirmed reproducible on the maintainer's own machine.
3. **No user-facing recovery.** When a client did get stuck, the only escape was a hard refresh, which most non-technical users do not know about and which is awkward on mobile (especially iOS Safari).

## Decision drivers

* Updates to the PWA must reach users within hours, not months, after a Netlify deploy.
* Offline-first behavior must be preserved; users who lose connectivity should still get the cached app.
* Fingerprinted assets (`/assets/*`, `/canvaskit/*`) should keep their long-lived cache so first-paint stays cheap.
* The recovery path for a stuck client must be discoverable by non-technical users without requiring a hard refresh.
* Each individual fix should sit in the layer it belongs in (Netlify config, web glue, UI) rather than smearing the workaround across layers.

## Considered options

For the HTTP cache layer:

* **A**: Keep `immutable` on `main.dart.js` and document the staleness as a known limitation.
* **B**: Switch the non-fingerprinted entry-point files to `Cache-Control: no-cache` so the browser always revalidates with the origin and the service worker can see a new build.
* **C**: Drop `--pwa-strategy=offline-first` and rely solely on HTTP cache headers.
* **D**: Manually fingerprint `main.dart.js` in a post-build step (rename + rewrite references in `index.html`/`flutter_bootstrap.js`).

For the SW update detection bug:

* **E**: Check `reg.waiting` (and any in-flight `reg.installing`) at the moment `wire()` runs, in addition to listening for future `updatefound` events.
* **F**: Force `registration.update()` more aggressively (every minute, on every route change) and hope the existing `updatefound` listener trips.

For the user-facing recovery:

* **G**: Document a hard-refresh workaround in release notes only; no UI affordance.
* **H**: Add a one-time `Clear-Site-Data: "cache"` header on `/index.html` to clear caches for everyone after a deploy.
* **I**: Ship an in-app "Force update" button under Settings that unregisters every service worker, clears Cache Storage, and reloads.

## Decision outcome

Chosen options: **B + E + I**, because each addresses a distinct failure mode and the combination removes the root cause rather than papering over symptoms.

**B (cache headers).** `/main.dart.js`, `/flutter_bootstrap.js`, `/flutter.js`, `/manifest.json` and `/flutter_service_worker.js` are served `Cache-Control: no-cache`. Fingerprinted folders (`/assets/*`, `/canvaskit/*`) keep `public, max-age=31536000, immutable`. This removes the HTTP-cache pin without touching the build pipeline.

**E (resilient SW detection).** `lib/web/pwa_update_web.dart` now calls `promptIfWaiting()` synchronously when `wire()` runs, attaches a `statechange` listener to any worker currently in `reg.installing`, and continues to listen for future `updatefound` events. Users whose previous session left a worker in the `waiting` state see the "Restart now" snackbar on their next visit instead of being stuck silently.

**I (in-app last resort).** A "Force update" / "Tving oppdatering" tile under Settings (web-only) calls a new `forcePwaUpdate()` in `lib/web/pwa_update_web.dart` that unregisters every service worker, deletes every Cache Storage key, then `location.reload()`. Plans and settings in `IndexedDB`/`localStorage` are preserved. The tile is gated behind a confirmation dialog that says so.

### Consequences

* Good: Returning users pick up new builds on the next visit; the snackbar actually fires for users who had a waiting worker from a previous session.
* Good: Non-technical users have a discoverable recovery path inside the app, with no hard-refresh trivia required.
* Good: Offline behavior is unchanged - SW Cache Storage is independent of HTTP-cache headers.
* Good: First-paint cost stays low because the large fingerprinted asset bundles remain immutable.
* Bad: Every revisit incurs a small revalidation roundtrip for ~5 files (304 in the common case). Acceptable; it matters less than getting updates delivered.
* Bad: A future contributor cleaning up "duplicated" `no-cache` lines could re-introduce the cache bug. This ADR exists to make that mistake visible.
* Bad: A future contributor restructuring `pwa_update_web.dart` could drop the initial `promptIfWaiting()` call if they don't understand why it's there. The code is commented; this ADR reinforces.
* Bad: The "Force update" tile lives in the web-only settings page and depends on the conditional-import shadowing in `lib/web/`. New settings work that diverges between web and native must keep the tile visible on web.

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

### Option E: Check `reg.waiting`/`reg.installing` at startup

* Good: Fixes the bug at its root - the listener now sees state that exists before it was attached, not just future events.
* Good: Tiny change, isolated to `pwa_update_web.dart`.
* Bad: Adds three small code paths (initial check, in-flight track, future-event track) that all converge on the same prompt. The duplication is intentional but invites future "simplification" that could re-break the corner cases.

### Option F: Poll `registration.update()` more aggressively

* Good: No new code paths to reason about; just turn the existing knob harder.
* Bad: Doesn't actually fix the bug — a waiting worker that exists from a previous session won't generate a fresh `updatefound`, no matter how often you poll. Treats the symptom, not the cause.

### Option G: Document hard refresh only

* Good: Zero code.
* Bad: Non-discoverable. Most users won't read release notes, and on iOS Safari hard refresh is buried under Settings → Safari → Advanced → Website Data. Not acceptable for a field tool.

### Option H: One-time `Clear-Site-Data` deploy

* Good: Forcibly clears caches across all clients in one deploy.
* Bad: Risks breaking offline use for any field user who starts the app offline right after the deploy — the cached `index.html` carries the header, the browser clears Cache Storage, and the SW has nothing left to serve. Disproportionate risk for a population that uses ringdrill primarily in the field.
* Bad: Requires a follow-up deploy to remove the header, with a window in between where every visit re-downloads the whole bundle.

### Option I: In-app "Force update" button

* Good: Discoverable. Lives where users already look when something feels wrong.
* Good: Per-user, opt-in. Users who are fine don't pay any cost.
* Good: Doesn't touch any other client. Safe to ship.
* Bad: Only available once a user is running a build that contains the button. Doesn't retroactively help users already stuck on old code — they still need a one-time hard refresh or the natural SW activation that happens after closing all tabs.

## Links

* Related code: [`netlify.toml`](../../netlify.toml), [`lib/web/pwa_update_web.dart`](../../lib/web/pwa_update_web.dart), [`lib/web/pwa_update_stub.dart`](../../lib/web/pwa_update_stub.dart), [`lib/web/settings_page.dart`](../../lib/web/settings_page.dart), [`lib/main.dart`](../../lib/main.dart)
* Related ADRs: none directly; this complements the general web/PWA distribution discussed in [`docs/architecture.md`](../architecture.md).
* External references:
  * Flutter web service worker source: <https://github.com/flutter/flutter/blob/main/packages/flutter_tools/lib/src/web/file_generators/flutter_service_worker_js.dart>
  * MDN, "Updating a service worker": <https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers#updating_your_service_worker>
  * MDN, "Service Worker API: caching strategies": <https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Tutorials/CycleTracker/Service_workers>
