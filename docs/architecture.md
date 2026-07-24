# RingDrill Architecture

Reference documentation for contributors. For agent rules and day-to-day commands, see [`AGENTS.md`](../AGENTS.md). For end-user information and how to clone/run the app, see [`README.md`](../README.md). For the rationale behind specific architectural choices, see the Architecture Decision Records in [`adrs/`](./adrs/).

## Project overview

RingDrill is a Flutter application for planning, synchronizing and running station-based drills (ring exercises) used in tactical, emergency and operational training. The repo contains:

1. The Flutter app under `lib/` (Android, iOS, web/PWA, macOS, Linux, Windows targets).
2. A Dart admin CLI under `bin/ringdrill.dart`, published as the `ringdrill` executable via `pubspec.yaml`.
3. A small Netlify backend under `netlify/functions/` (Node.js) that hosts drill file storage, deep links and a market feed, served at `api.ringdrill.app`.
4. A static Astro site under `site/` (the public site at `ringdrill.app`), deployed to Cloudflare Pages.
5. A Cloudflare Worker under `workers/apex-proxy/` that reverse-proxies the dynamic apex paths (`/api`, `/d`, `/i`, `/brief`, `/.netlify/functions`) to the API subdomain, because Cloudflare Pages cannot 200-proxy to an external origin. See [ADR-0039](./adrs/0039-site-pwa-api-origins.md).
6. Generated localization, freezed and JSON serialization code (do not edit by hand).

Owner: DISCOOS (`github.com/DISCOOS/ringdrill`). Distribution channels: Google Play (Android, via Shorebird), Apple App Store (iOS), and the web PWA. Public origins are split per [ADR-0039](./adrs/0039-site-pwa-api-origins.md): the site on `ringdrill.app` and the PWA on `web.ringdrill.app` (both Cloudflare Pages), and the API on `api.ringdrill.app` (Netlify functions, Cloudflare-proxied). The dynamic apex paths are reverse-proxied to the API by the `workers/apex-proxy/` Worker.

## Tech stack

* Flutter SDK `^3.8.0`, Dart 3 with sealed classes.
* Code generation: `freezed`, `json_serializable`, `build_runner`.
* Routing: `go_router` (entry point `buildRouter` in `lib/views/main_screen.dart`).
* State: plain `ChangeNotifier`/streams plus `shared_preferences` for persistence. No Bloc, Riverpod or Provider.
* Maps: `flutter_map` with `latlong2`, `osm_nominatim` for geocoding, `proj4dart` for UTM projection.
* Telemetry: `sentry_flutter`, opt-in only (see consent handling in `lib/main.dart`).
* Local notifications: `flutter_local_notifications` (non-web only).
* OTA updates: Shorebird (`shorebird.yaml`, `shorebird_code_push`).
* Drill files: custom zipped format with MIME `application/vnd.ringdrill+zip`, extension `.drill`. See `lib/data/drill_file.dart`.

## Repository layout

```
lib/
  main.dart                  app bootstrap, themes, Sentry/consent gating
  data/                      drill file format + HTTP client + repository
  models/                    freezed/JSON models (program, exercise, station, team)
  services/                  long-lived runtime services (exercise, notifications, program, file channel)
  views/                     all UI screens and widgets (flat folder, no feature grouping)
  web/                       web-only widgets and PWA update handling
  utils/                     pure-Dart helpers (projection, time, config, sentry)
  l10n/                      .arb sources + generated AppLocalizations
bin/ringdrill.dart           admin CLI
netlify/functions/           Node.js backend (drill upload/head, deep links, admin, market feed) — api.ringdrill.app
site/                        static Astro site (ringdrill.app), deployed to Cloudflare Pages
workers/apex-proxy/          Cloudflare Worker reverse-proxying dynamic apex paths to the API (ADR-0039)
test/                        Flutter and pure-Dart tests
assets/                      app icons, splash images
android/, ios/, macos/,      platform projects
linux/, windows/, web/
```

Conditional imports follow the standard pattern, e.g. `import 'package:foo/x.dart' if (dart.library.io) 'package:foo/x_io.dart';`. Web-only code lives under `lib/web/` with stub counterparts (e.g. `pwa_update_stub.dart` vs `pwa_update_web.dart`).

## Conventions

### Terminology

Domain vocabulary and the English-vs-Norwegian naming rule live in [`glossary.md`](./glossary.md).

### Models

* Every model in `lib/models/` is `@freezed sealed class X with _$X`. Add new models the same way and run `make build`.
* Each model has `fromJson`/`toJson` via `json_serializable`. Do not add custom serializers unless absolutely needed.
* Behavior on models is added via Dart extensions (`extension ExerciseX on Exercise { ... }`), not by inheritance or methods inside the freezed class.
* Use the project's own `SimpleTimeOfDay` (in `lib/models/exercise.dart`) instead of Flutter's `TimeOfDay` whenever the value crosses serialization or non-Flutter (CLI, isolate) boundaries. `TimeOfDay` itself is not JSON-serializable.

### Services

* Services are long-lived singletons constructed in `lib/main.dart` (e.g. `ProgramService().init()`). Keep them framework-free (no `BuildContext`) and expose streams/`ValueNotifier`s for UI.
* **`ProgramService.events` is a fire-on-every-mutation contract.** UI surfaces subscribe to the broadcast `events` stream and rebuild on *any* emission — they do not filter by `ProgramEventType`. So every mutating method must emit an event before returning (guarded on `activeProgram != null`), or dependent widgets go stale. Reuse `programRefreshed` when no specific type fits (as the reorder methods do). Entity edits that persist through `saveExercise`/`replaceProgram` inherit those events; a method that writes via `_repo` directly (e.g. `deleteRolePlay`, `saveActor`) must emit its own.
* **Consumer side: long-lived detail viewers subscribe too.** List views already do. Any screen that caches an entity (`_exercise`, `_rolePlay`, a team read in `build`) and can stay open while that entity is mutated elsewhere — `CoordinatorScreen`, `StationExerciseScreen`, `RolePlayScreen`, `TeamScreen` — must `listen(_programService.events, …)` (via the `SubscriptionBag` mixin) and re-read, not rely on local `setState` after its own actions alone. Otherwise it shows stale data in the wide master/detail layout.
* `NotificationService` is non-web only and is gated by user preferences from `AppConfig`.
* New persistent settings keys go in `lib/utils/app_config.dart` with a `keyX` constant. Use the prefix `app:<feature>`. Append a `:v<n>` suffix when the value may need a future migration (see `keyIsFirstLaunch = 'app:isFirstLaunch:v1'`).

### UI

* All screens and widgets live directly under `lib/views/`. Do not introduce a feature-folder structure without coordinating with the maintainer.
* Theming: `ringDrillTheme` and `ringDrillDarkTheme` in `main.dart` are the source of truth. Reuse `Theme.of(context).colorScheme` rather than hard-coded colors.
* All user-visible strings go through `AppLocalizations.of(context)!.<key>` and are defined in `app_en.arb` first, then translated in `app_nb.arb`. Untranslated keys are reported in `lib/l10n/untranslated-messages.json` (gitignored).
* Cross-cutting UI conventions — marker icons, row edit affordances, active-filter visibility, design tokens, map slot props, and form "Save"/"Done" labels — live in [`ui-conventions.md`](./ui-conventions.md).

### Web

* Anything that touches `dart:html`/`package:web` must live under `lib/web/` behind a conditional import with an io stub. Importing `package:web` directly from a file that is also compiled on mobile will break the Android/iOS build.

### Error reporting

* Wrap Sentry calls in `if (Sentry.isEnabled)` checks. Sentry is only initialized when the user has granted `analyticsConsent` (see `lib/main.dart`).
* Never log PII or drill content to Sentry. Errors only.

## Localization

Localization files are generated automatically by Flutter (`flutter: generate: true` in `pubspec.yaml`, configured via `l10n.yaml`). After editing `lib/l10n/app_en.arb` or `app_nb.arb`, the next `flutter run`/`flutter build`/`flutter test` will regenerate `app_localizations*.dart`.

`l10n.yaml` points at `lib/l10n/` for ARB sources, writes `app_localizations.dart` as the entry point, and emits a gitignored `untranslated-messages.json` to flag missing translations.

## Tests

`flutter test` is the canonical command. The suite under `test/` has grown to cover models, `data/`, `utils/`, services (including the brief renderer and catalog refresh), and a range of views and widgets. Mirror the layout of `lib/` under `test/` when adding new files.

* `test/projection_test.dart` covers `lib/utils/projection.dart`. Keep this passing when you touch projection or UTM code.
* The default Flutter counter-app `test/widget_test.dart` has been removed. Do not reintroduce it; add real `RingDrillApp`-level tests instead.

When adding tests, prefer pure-Dart unit tests against `models/`, `data/` and `utils/` over widget tests. Widget tests should be added only for non-trivial UI logic.

## Build and release

* Android release builds go through Shorebird (`make release-android`). The commented `flutter build appbundle` block in the Makefile is the manual fallback.
* iOS release builds go through Shorebird (`make release-ios`, with `make patch-ios` for code-push patches), mirroring the Android targets. They run only on a macOS host with Xcode and rely on the signing configured in `ios/Runner.xcodeproj` (DISCOOS team, `app.ringdrill`, automatic — see [ADR-0021](./adrs/0021-ios-bundle-identifier-app-ringdrill.md)). Shorebird drives `flutter build ipa` under the hood.
* Web is built by Netlify on every push to the configured branch using `netlify.toml`. The `flutter_service_worker.js` and `index.html` are served `no-cache`; everything else under `assets/`, `canvaskit/` and `main.dart.js` is immutable.
* `.drill` files served by Netlify are forced to `Content-Disposition: attachment` with the custom MIME type. Do not change this without also updating the share/import handlers in `lib/data/drill_file.dart` and `lib/views/shared_file_widget.dart`.
* The Shorebird `app_id` in `shorebird.yaml` is public and safe to commit. `sentry.properties` is gitignored and must not be committed.

## Backend, API and hosting

The backend runtime, hosting topology (the three ADR-0039 origins) and local dev live in [`backend.md`](./backend.md); the HTTP API reference — endpoints, auth, examples — is in [`api.md`](./api.md).

## Drill file format

The `.drill` file format and the drill library bundle format live in [`drill-file-format.md`](./drill-file-format.md).

## Briefs, templates and variables

The brief is a projection of the entities, rendered on demand through a versioned mustache template. The template format, registration and audiences live in [`template.md`](./template.md); the `{{var.*}}` and cross-reference tokens an author types inside fields — with their typed values, the copy-chip convention, the resolution pipeline and the resolve-scope model — live in [`variables.md`](./variables.md).

## Where to look first

* Bootstrap and theming: `lib/main.dart`.
* Routing: `buildRouter` and `MainScreen` in `lib/views/main_screen.dart`.
* Domain core: `lib/models/exercise.dart` (rotation math is in `teamIndex`/`stationIndex` extensions).
* Drill timer/phase engine: `lib/services/exercise_service.dart`.
* File import/export pipeline: `lib/data/drill_file.dart` plus `lib/services/shared_file_channel.dart`.
* Backend contract: `netlify.toml` for routes, `netlify/functions/*.js` for handlers, `lib/data/drill_client.dart` for the Dart-side client.

## Things that look weird but are intentional

* `lib/views/` is a single flat folder. Keep it that way unless the maintainer asks otherwise.
* `lib/web/program_page_controller.dart`, `platform_widget.dart` and `settings_page.dart` shadow files of the same name in `lib/views/`. Imports pick the right one via conditional import.
* The Makefile is intentionally tiny. Most workflows are plain `flutter`/`dart` commands; the Makefile only wraps the few non-obvious ones (codegen, Shorebird).
* `sentry.properties` is in `.gitignore`. The Sentry plugin block in `pubspec.yaml` references it for source upload during release builds. Local builds work without it.
* `untranslated-messages.json` regenerates on every build. If it shows up in `git status`, ignore it.
* `flutter_test`'s default `MediaQuery` size (~800×600) reads as `WindowSizeClass.medium` (`hasMasterDetail: true`), not compact. A widget test asserting compact-only chrome (a bottom sheet's drag handle, `find.byType(BottomSheet)`) must pin `tester.view.physicalSize` explicitly or it silently exercises the medium/expanded dialog path instead — see `ringdrill_picker_test.dart` and ADR-0049/ADR-0052.
