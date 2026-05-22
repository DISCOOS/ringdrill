---
status: accepted
date: 2026-05-22
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0015: Shareable install links open the plan in the app via `ringdrill.app/i/<slug>`

## Context and problem statement

The drawer entry "Del aktiv plan" (calls [`shareActivePlan`](../../lib/views/active_plan_actions.dart)) copies `https://ringdrill.netlify.app/d/<slug>` to the clipboard. `/d/` is the raw `.drill` download endpoint, so a recipient who opens the link gets a binary file with `Content-Disposition: attachment` and must locate it and import it manually. The PWA is never loaded and `ProgramService.installFromCatalog` is never invoked.

Two host inconsistencies compound the problem. The Android App Link intent filter in [`AndroidManifest.xml`](../../android/app/src/main/AndroidManifest.xml) declares `android:host="ringdrill.app"`, but the shared URL points at `ringdrill.netlify.app`, so verification never triggers. The same filter declares `android:pathPattern="/o"` (exact), so even on the right host only the literal `/o` would match. `https://ringdrill.app/.well-known/assetlinks.json` is served correctly today, so the verification infrastructure exists but is unused.

The feature should behave as wiki-style sharing per [ADR-0008](./0008-persistent-program-library-and-catalog.md): anyone with the link lands on the plan inside RingDrill, installed in the local library and activated, regardless of which device or app combination they have.

## Decision drivers

* One share link must work for native Android, installed PWA, and plain browser without RingDrill.
* On Android with the native app installed, the native app should win without prompting the user.
* Reuse `installFromCatalog`, the catalog source model (ADR-0008) and the ETag-driven refresh path (ADR-0010). No backend contract changes.
* The link is wiki-style: no auth, no signing, no expiry.
* Must not break ADR-0013's local catalog dev loop.

## Considered options

* **A. Keep `/d/<slug>`.** Status quo. Recipient downloads a `.drill` file and imports manually.
* **B. Reuse `/o/<slug>` as the share link.** Repurpose the existing App-Link landing path to serve the SPA for browser traffic. Collapses App-Link capture and SPA install onto one path.
* **C. Introduce `/i/<slug>` as a dedicated SPA route** (mirroring the existing `/d/` download and `/o/` open notation). App Link captures it on Android via a widened intent filter; the PWA captures it via manifest-level link handling; the Netlify SPA catch-all serves `index.html` so the Flutter router runs `installFromCatalog`. `/d/` and `/o/` keep their current roles.

## Decision outcome

Chosen option: **C — `ringdrill.app/i/<slug>`**, because it separates App-Link capture (`/o/`), raw download (`/d/`) and PWA install (`/i/`) onto three paths that each do one thing, and because it requires no change to `deep-link.js`.

### Canonical share host

The canonical share host is **`ringdrill.app`**. `_buildShareableUrl` is changed to always emit `https://ringdrill.app/i/<slug>`, independent of what `AppConfig.catalogBaseUrl(...)` returns for backend traffic. Backend traffic still resolves per ADR-0013 (same-origin for the PWA, production for native, localhost for dev). The share URL is a separate concept from the API base URL.

Reasons: Android App Link verification is bound to one host, `assetlinks.json` is already verified there, and `.netlify.app` is a hosting artefact, not a brand identifier.

### Routing roles

| Path              | Role                                                                                          |
|-------------------|-----------------------------------------------------------------------------------------------|
| `/i/<slug>` | Share link. Netlify SPA catch-all serves `index.html`. Flutter route triggers `installFromCatalog` and redirects to `routeProgram`. |
| `/o/<slug>`       | Android App-Link landing. Unchanged. No `netlify.toml` rewrite; browser fallback serves the SPA, which routes the path to the existing `SharedFileChannel` Flutter handler. |
| `/d/<slug>`       | Raw `.drill` download. Used by `DrillClient.download` and the `.drill` MIME intent filter. Unchanged. |

### Android intent filter

Widen the existing `autoVerify="true"` filter for `https://ringdrill.app` to `pathPrefix="/i/"` alongside the existing `/o/` path. The native deep-link handler routes `/i/<slug>` to the same Dart entry point as the new GoRoute, so native and web converge on one install path.

### PWA manifest

`web/manifest.json` gets two fields that govern how installed PWAs handle in-scope URLs:

```
"handle_links": "preferred"
"launch_handler": { "client_mode": "navigate-existing" }
```

`handle_links: "preferred"` makes supporting Chromium browsers (Android WebAPK, desktop install) prefer the installed PWA over the browser tab for in-scope URLs. `navigate-existing` reuses the open PWA window instead of spawning a new one. Safari and Firefox ignore both fields; the link then opens in the browser, which loads the same install route.

### Flutter route

A new top-level `GoRoute('/i/:slug')` in `buildRouter` calls a helper that wraps `ProgramService().installFromCatalog(...)` with a `DrillClient` from `AppConfig.catalogBaseUrl(...)`, then redirects to `routeProgram`. Failures surface through the same snackbar path the library "På nett" tab already uses.

### Consequences

* Good: one share link works across native, PWA-only, and browser-only recipients.
* Good: no change to `deep-link.js` or the `.drill` pipeline. Native and web reuse `installFromCatalog`, so source tracking and ETag refresh (ADR-0010) stay aligned.
* Good: native always wins on Android once App Link is verified, with no chooser.
* Bad: `handle_links` and `launch_handler` are Chromium-only today. Firefox/Safari recipients see the PWA load inside a browser tab. Functional outcome is the same.
* Bad: `ringdrill.app` becomes a hard runtime dependency for share links. If DNS for the custom domain breaks while Netlify keeps working, share links break.
* Bad: dev builds running against `localhost` produce share links that point at production. Acceptable: a dev share link is rarely useful to a recipient.

## Pros and cons of the options

### Option A — keep `/d/<slug>`
* Good: zero change.
* Bad: feature does not deliver what it is named after.
* Bad: a recipient who imports the downloaded file does not get `ProgramSource.catalog`, so ADR-0010 refresh stops working for them.

### Option B — reuse `/o/<slug>`
* Good: one path to widen on the intent filter.
* Bad: `/o/` already has a Flutter router handler in `buildRouter` designed for `SharedFileChannel` (Android OS file-share intents), which treats the path tail as a device filesystem path. Sharing the same prefix with a catalog-install route forces the handler to disambiguate slug vs filesystem path, or to accept that one consumer breaks the other.
* Bad: collapses App-Link landing and SPA install onto one path.

### Option C — `/i/<slug>` (chosen)
* Good: each path has a single role; future changes to either are independent.
* Good: follows the existing `/d/` and `/o/` single-letter prefix notation.
* Good: SPA catch-all already serves unknown paths from `index.html`; no `netlify.toml` change.
* Bad: a second App-Link path to keep covered by the intent filter.

## Migration plan

1. Add `handle_links` and `launch_handler` to `web/manifest.json`.
2. Add the `/i/:slug` `GoRoute` in `lib/views/main_screen.dart`, calling a helper that wraps `installFromCatalog` and redirects to `routeProgram`.
3. Change `_buildShareableUrl` in `lib/views/active_plan_actions.dart` to always return `https://ringdrill.app/i/<slug>`.
4. Broaden the Android App Link intent filter in `android/app/src/main/AndroidManifest.xml` to `pathPrefix="/i/"` (and keep `/o/`).
5. Manual QA: share from device A, open on device B (native), device C (PWA only), device D (browser only).

## Links

* Related ADRs: [ADR-0007](./0007-drill-file-format.md), [ADR-0008](./0008-persistent-program-library-and-catalog.md), [ADR-0010](./0010-live-catalog-updates.md), [ADR-0013](./0013-local-catalog-testing.md)
* Related debts: [DEBT-0001](../debts/0001-orphan-https-app-link-for-o-path.md) (orphan `/o` App-Link declaration, orthogonal to this ADR but worth knowing about when reading the intent filter)
* Related code: `lib/views/active_plan_actions.dart` (`_buildShareableUrl`), `lib/views/main_screen.dart` (`buildRouter`), `lib/services/program_service.dart` (`installFromCatalog`), `android/app/src/main/AndroidManifest.xml`, `web/manifest.json`, `web/.well-known/assetlinks.json`
* External references: [Web App Manifest `handle_links`](https://github.com/WICG/manifest-incubations/blob/gh-pages/handle_links-explainer.md), [Web App Launch Handler API](https://wicg.github.io/web-app-launch/), [Android App Links verification](https://developer.android.com/training/app-links/verify-android-applinks)
