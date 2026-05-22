# Codex CLI prompt: Implement ADR-0015

Copy everything below the line into Codex CLI. The prompt is self-contained and references files inside this repo.

---

You are working in the RingDrill repository. Implement ADR-0015 ("Shareable install links open the plan in the app via `ringdrill.app/i/<slug>`") end-to-end. The ADR lives at `docs/adrs/0015-shareable-install-links.md` and is accepted. It is the authoritative spec for this change. Read it in full before you start. Also skim DEBT-0001 at `docs/debts/0001-orphan-https-app-link-for-o-path.md` so you do not accidentally touch the orphan `/o` App-Link while widening the intent filter — that is tracked separately.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* Mobile-safe imports. Anything reachable from `lib/main.dart` on a non-web platform must not transitively import `dart:html` or `package:web`. Web-only code lives under `lib/web/` behind `if (dart.library.io)` conditional imports.
* CLI must stay Flutter-free. `bin/ringdrill.dart` and anything it imports must not gain a `package:flutter/*` import as a side effect of this change. The install logic belongs in widget-side code, not in models or `drill_client.dart`.
* Localize every user-visible string. Any snackbar text you add goes into `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. If you do not know the Norwegian translation, copy the English string and flag it in the PR description.
* Respect the analytics consent gate. Do not call Sentry, analytics or any network telemetry outside the consent check in `lib/main.dart`.
* Match existing Dart style. Do not add new lint suppressions.
* Run `flutter analyze` and `flutter test` before claiming the change is green. `test/widget_test.dart` is the known-broken default-template smoke test — flag it as such rather than asserting all tests pass.

## Scope

The implementation is five steps. Do them in order. There is no codegen work in this change (no freezed/json edits expected), but if you find you do touch a `@freezed` class, run `make build` before moving on.

### Step 1. PWA manifest

Edit `web/manifest.json`. Keep the existing `scope`, `start_url`, icons and metadata untouched. Add two top-level fields:

```json
"handle_links": "preferred",
"launch_handler": {
    "client_mode": "navigate-existing"
}
```

`handle_links: "preferred"` tells Chromium-based browsers (Android WebAPK, desktop installs) that an installed RingDrill PWA should be preferred over a browser tab for in-scope URLs. `launch_handler.client_mode: "navigate-existing"` reuses the open PWA window instead of spawning a new one. Safari and Firefox ignore both fields; the link then opens in the browser and loads the same install route, which is acceptable per the ADR.

Verify the manifest still parses by running `flutter build web --release --pwa-strategy=offline-first` (or rely on `make web` if that target works locally). Lint with any JSON validator if available.

### Step 2. Catalog install helper

Create `lib/views/install_link_handler.dart` (or add to an existing file under `lib/views/` if it cleanly fits — pick whichever is closer to existing patterns; do not introduce a new package layer). Expose:

```dart
Future<void> handleInstallLink(BuildContext context, String slug);
```

Behavior:

* Build a `DrillClient` using `AppConfig.catalogBaseUrl(isWeb: kIsWeb, isRelease: kReleaseMode, isDebug: kDebugMode)` and `AppConfig.deepLinkBasePathFor(baseUrl)`. Mirror `_buildPublishClient` in `lib/views/active_plan_actions.dart` so the construction stays consistent.
* Fetch the slug as a `MarketFeedItem` via `client.marketFeed()` if needed, or, if `installFromCatalog` already accepts a slug directly, call it directly. Read `lib/services/program_service.dart` (`installFromCatalog`) and `lib/views/library_view.dart` (`_installCatalog`) and reuse the same path the "På nett" library tab uses. Do not duplicate the install logic.
* On success, the program should be activated. Show a localized snackbar using a new ARB key `installedFromLink` ("Plan lagt til fra delelenke" / "Plan installed from share link"). On failure, show `libraryErrorLoad` (existing key) or add a new `installFromLinkFailure` key if the existing one feels off — your call, but stay consistent with how library catalog errors are surfaced today.
* If the slug is empty, malformed, or `installFromCatalog` throws because the slug is unknown, show the failure snackbar and return. Do not crash the route.

### Step 3. GoRouter route

Edit `lib/views/main_screen.dart` (`buildRouter`). Add a new top-level `GoRoute` for `/i/:slug`. It must be registered *before* the existing `/o/`-prefix redirect logic so first-load resolution is deterministic — the simplest way is to add the handling inside the existing `redirect:` callback at the top of `GoRouter(...)`, alongside the `/o/`-prefix branch.

Sketch:

```dart
redirect: (context, state) {
    final location = state.matchedLocation;
    if (location.startsWith('/i/')) {
        final slug = Uri.decodeComponent(location.substring('/i/'.length));
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (key.currentContext != null) {
                handleInstallLink(key.currentContext!, slug);
            }
        });
        return routeProgram;
    }
    if (location.startsWith('/o/')) {
        // existing branch, unchanged
        ...
    }
    return null;
},
```

The redirect must always return `routeProgram` (or `null`) — never throw. The install runs in a post-frame callback so the program tab is mounted and can show the snackbar.

Slug grammar: keep it permissive. `deep-link.js` validates as `[^@/]+(@<version>)?`. Mirror that loosely here, but reject only the obvious cases (empty after decode, contains a forward slash). Do not duplicate the regex; a simple `slug.isNotEmpty && !slug.contains('/')` check is enough.

### Step 4. Share URL builder

Edit `lib/views/active_plan_actions.dart`. Change `_buildShareableUrl` to always return the canonical share URL:

```dart
String _buildShareableUrl(String slug) =>
    'https://ringdrill.app/i/$slug';
```

Remove the `catalogBaseUrl` / `deepLinkBasePathFor` resolution from this function — those still belong in `_buildPublishClient` for API traffic, but the share URL is intentionally decoupled per the ADR's "Canonical share host" section. Backend traffic continues to resolve per ADR-0013.

Do not add a `kDebugMode` branch. A dev share link pointing at production is fine per the ADR.

### Step 5. Android intent filter

Edit `android/app/src/main/AndroidManifest.xml`. Find the existing App-Link intent filter for `https://ringdrill.app` (lines around 98–106). It currently declares `android:pathPattern="/o"`. Replace it with two `<data>` elements: one for `/i/` and one for `/o/`, both using `android:pathPrefix`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="ringdrill.app" android:pathPrefix="/i/" />
    <data android:scheme="https" android:host="ringdrill.app" android:pathPrefix="/o/" />
</intent-filter>
```

Two notes:

* `flutter_deeplinking_enabled` is already set; the Flutter engine will deliver `/i/<slug>` to GoRouter directly, so no native MainActivity change is needed. The new GoRoute from Step 3 handles both web and native flows.
* Do not touch the orphan literal `/o` declaration mentioned in DEBT-0001 if it has been resolved — at the time of writing, the intent filter uses `pathPattern="/o"`. Replacing that with `pathPrefix="/o/"` *also* resolves DEBT-0001 incidentally because `/o/` is then captured and dispatched to the existing `SharedFileChannel` Flutter handler. If you do this, update `docs/debts/0001-orphan-https-app-link-for-o-path.md`: set `status: resolved`, `resolved: <today>`, add a brief note in the file linking to this commit, and update the index row in `docs/debts/README.md`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` — assert no new failures. `test/widget_test.dart` remains broken; do not try to fix it as part of this change.
3. Manual QA matrix (record the result in the PR description):
   * Share a published plan from device A. Open the URL on device B (native Android app installed): verify the native app opens and the plan lands in "Mine planer" activated, with no chooser shown.
   * Open the URL on device C (Android with only RingDrill PWA installed via Chrome): verify the PWA opens and runs the install.
   * Open the URL on device D (desktop browser, no install): verify the PWA loads in the browser and runs the install.
   * Open a malformed URL (`https://ringdrill.app/i/`) and verify the snackbar fires and the user lands on the program page without a crash.
4. Confirm Android App-Link verification still passes after the change: `adb shell pm get-app-links org.discoos.ringdrill` should show `ringdrill.app` as `verified` for both `/i/` and `/o/` prefixes.

## Deliverables

A single PR with:

* The code changes above.
* Updated `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` for any new snackbar keys.
* If DEBT-0001 was resolved as part of Step 5: updated `docs/debts/0001-orphan-https-app-link-for-o-path.md` and `docs/debts/README.md`.
* Manual QA matrix filled in the PR description.

Do not create a new ADR. ADR-0015 is the authoritative spec for this change; if you find yourself contradicting it, stop and ask.
