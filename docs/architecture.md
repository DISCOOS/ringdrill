# RingDrill Architecture

Reference documentation for contributors. For agent rules and day-to-day commands, see [`AGENTS.md`](../AGENTS.md). For end-user information and how to clone/run the app, see [`README.md`](../README.md). For the rationale behind specific architectural choices, see the Architecture Decision Records in [`adrs/`](./adrs/).

## Project overview

RingDrill is a Flutter application for planning, synchronizing and running station-based drills (ring exercises) used in tactical, emergency and operational training. The repo contains:

1. The Flutter app under `lib/` (Android, iOS, web/PWA, macOS, Linux, Windows targets).
2. A Dart admin CLI under `bin/ringdrill.dart`, published as the `ringdrill` executable via `pubspec.yaml`.
3. A small Netlify backend under `netlify/functions/` (Node.js) that hosts drill file storage, deep links and a market feed.
4. Generated localization, freezed and JSON serialization code (do not edit by hand).

Owner: DISCOOS (`github.com/DISCOOS/ringdrill`). Distribution channels: Google Play (Android, via Shorebird), Netlify-hosted PWA at `ringdrill.netlify.app`.

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
netlify/functions/           Node.js backend (drill upload/head, deep links, admin, market feed)
test/                        Flutter and pure-Dart tests
assets/                      app icons, splash images
android/, ios/, macos/,      platform projects
linux/, windows/, web/
```

Conditional imports follow the standard pattern, e.g. `import 'package:foo/x.dart' if (dart.library.io) 'package:foo/x_io.dart';`. Web-only code lives under `lib/web/` with stub counterparts (e.g. `pwa_update_stub.dart` vs `pwa_update_web.dart`).

## Conventions

### Models

* Every model in `lib/models/` is `@freezed sealed class X with _$X`. Add new models the same way and run `make build`.
* Each model has `fromJson`/`toJson` via `json_serializable`. Do not add custom serializers unless absolutely needed.
* Behavior on models is added via Dart extensions (`extension ExerciseX on Exercise { ... }`), not by inheritance or methods inside the freezed class.
* Use the project's own `SimpleTimeOfDay` (in `lib/models/exercise.dart`) instead of Flutter's `TimeOfDay` whenever the value crosses serialization or non-Flutter (CLI, isolate) boundaries. `TimeOfDay` itself is not JSON-serializable.

### Services

* Services are long-lived singletons constructed in `lib/main.dart` (e.g. `ProgramService().init()`). Keep them framework-free (no `BuildContext`) and expose streams/`ValueNotifier`s for UI.
* `NotificationService` is non-web only and is gated by user preferences from `AppConfig`.
* New persistent settings keys go in `lib/utils/app_config.dart` with a `keyX` constant. Use the prefix `app:<feature>`. Append a `:v<n>` suffix when the value may need a future migration (see `keyIsFirstLaunch = 'app:isFirstLaunch:v1'`).

### UI

* All screens and widgets live directly under `lib/views/`. Do not introduce a feature-folder structure without coordinating with the maintainer.
* Theming: `ringDrillTheme` and `ringDrillDarkTheme` in `main.dart` are the source of truth. Reuse `Theme.of(context).colorScheme` rather than hard-coded colors.
* All user-visible strings go through `AppLocalizations.of(context)!.<key>` and are defined in `app_en.arb` first, then translated in `app_nb.arb`. Untranslated keys are reported in `lib/l10n/untranslated-messages.json` (gitignored).

### Web

* Anything that touches `dart:html`/`package:web` must live under `lib/web/` behind a conditional import with an io stub. Importing `package:web` directly from a file that is also compiled on mobile will break the Android/iOS build.

### Error reporting

* Wrap Sentry calls in `if (Sentry.isEnabled)` checks. Sentry is only initialized when the user has granted `analyticsConsent` (see `lib/main.dart`).
* Never log PII or drill content to Sentry. Errors only.

## Localization

Localization files are generated automatically by Flutter (`flutter: generate: true` in `pubspec.yaml`, configured via `l10n.yaml`). After editing `lib/l10n/app_en.arb` or `app_nb.arb`, the next `flutter run`/`flutter build`/`flutter test` will regenerate `app_localizations*.dart`.

`l10n.yaml` points at `lib/l10n/` for ARB sources, writes `app_localizations.dart` as the entry point, and emits a gitignored `untranslated-messages.json` to flag missing translations.

## Tests

`flutter test` is the canonical command. Two test files exist:

* `test/projection_test.dart` covers `lib/utils/projection.dart`. Keep this passing when you touch projection or UTM code.
* `test/widget_test.dart` is the default Flutter counter-app smoke test and is stale (it expects a `+` button that does not exist in `RingDrillApp`). Treat it as a known-broken placeholder. If you have spare cycles, replace it with a real `RingDrillApp` smoke test.

When adding tests, prefer pure-Dart unit tests against `models/`, `data/` and `utils/` over widget tests. Widget tests should be added only for non-trivial UI logic.

## Build and release

* Android release builds go through Shorebird (`make release-android`). The commented `flutter build appbundle` block in the Makefile is the manual fallback.
* iOS releases use the standard `flutter build ipa` flow plus Xcode signing in `ios/`. There is no Makefile target for this yet.
* Web is built by Netlify on every push to the configured branch using `netlify.toml`. The `flutter_service_worker.js` and `index.html` are served `no-cache`; everything else under `assets/`, `canvaskit/` and `main.dart.js` is immutable.
* `.drill` files served by Netlify are forced to `Content-Disposition: attachment` with the custom MIME type. Do not change this without also updating the share/import handlers in `lib/data/drill_file.dart` and `lib/views/shared_file_widget.dart`.
* The Shorebird `app_id` in `shorebird.yaml` is public and safe to commit. `sentry.properties` is gitignored and must not be committed.

## Backend (Netlify functions)

Endpoints (see `netlify.toml` for the redirect map):

| Method | Path | Handler | Purpose |
|--------|------|---------|---------|
| POST | `/api/drills/upload` | `drills-upload.js` | Multipart `.drill` upload, returns versioned URL |
| GET | `/api/drills/head/:slug` | `drills-head.js` | Metadata lookup for a slug |
| GET | `/d/:slug` | `deep-link.js` | Deep-link redirector for the mobile apps |
| GET | `/api/market/feed` | `market-feed.js` | Public market feed |
| * | `/api/admin` | `drills-admin.js` | Token-gated admin operations, used by the CLI |

The CLI in `bin/ringdrill.dart` talks to these endpoints using `RINGDRILL_ADMIN_TOKEN` and `RINGDRILL_BASE_URL`.

### Running the backend locally

The full Netlify stack (functions plus an emulated blob store) can be run on a contributor machine without touching production. The intended workflow and the architectural rationale are captured in [ADR-0013](./adrs/0013-local-catalog-testing.md). The short version follows.

Prerequisites: Node 20+ and the [Netlify CLI](https://docs.netlify.com/cli/get-started/) (`npx netlify` will fetch it on first use).

Start the backend:
```bash
make netlify-dev
```
The target runs `npm install` and `ADMIN_TOKEN=dev-token npx netlify dev`. Override the token with `make netlify-dev LOCAL_ADMIN_TOKEN=<token>`. Functions are now reachable at `http://localhost:8888`. The blob store is emulated under `.netlify/blobs-serve/`.

Verify the catalog responds:
```bash
curl http://localhost:8888/api/market/feed
```

The admin CLI honors `RINGDRILL_BASE_URL`, so the same binary works against the local backend without rebuilding:
```bash
export RINGDRILL_BASE_URL=http://localhost:8888
export RINGDRILL_ADMIN_TOKEN=dev-token
ringdrill list-all
ringdrill publish <slug>
```

Clear the local blob store and start fresh (with the backend stopped):
```bash
rm -rf .netlify/blobs-serve
```

The polished workflow described in ADR-0013 (Makefile targets `catalog-seed`, `catalog-feed`, `catalog-reset` building on `netlify-dev`, CLI commands `upload` / `feed` / `download`, and a `--dart-define=RINGDRILL_LOCAL_BASE_URL=...` switch on the Flutter side) is the target state. Those targets and CLI subcommands will be added as the implementation lands. The fixture used for `catalog-seed` is at `test/fixtures/test-7x.drill`. Override with `SEED_DRILL=<path>` to publish a different file.

Pointing the Flutter app at the local backend (once the `--dart-define` switch is implemented):
```bash
flutter run -d macos --dart-define=RINGDRILL_LOCAL_BASE_URL=http://localhost:8888
```
The override only takes effect in debug builds. Release builds cannot be coerced into talking to localhost.

## Drill file format

`DrillFile` (in `lib/data/drill_file.dart`) is a versioned zip wrapper around the program JSON.

* MIME type: `application/vnd.ringdrill+zip`
* Extension: `.drill`
* Current schema: `DrillFile.drillSchema1_0 = '1.0'`

Bumping the schema requires updating the import code in `lib/data/drill_file.dart`, the Netlify upload handler, and a migration path for existing files.

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
