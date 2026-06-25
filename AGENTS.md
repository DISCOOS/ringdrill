# AGENTS.md

Operating guide for AI coding agents (Claude Code, Codex, Cursor, etc.) working in this repository. Humans may also find it useful as a quick orientation.

For project background, architecture, conventions and backend details, read [`docs/architecture.md`](./docs/architecture.md) first. This file focuses on what an agent needs to do (and avoid) when changing code.

## TL;DR

RingDrill is a Flutter app (Dart 3, SDK `^3.8.0`) plus a Dart admin CLI (`bin/ringdrill.dart`) and a Node.js Netlify backend (`netlify/functions/`). Targets: Android, iOS, web/PWA, macOS, Linux, Windows. Distribution: Google Play via Shorebird, PWA via Netlify.

## Common commands

```bash
flutter pub get                                # install deps
make build                                     # one-shot codegen (freezed/json_serializable)
make watch                                     # incremental codegen watcher
make i18n                                      # regenerate Flutter localizations from ARB
flutter analyze                                # static analysis (CI gate)
flutter test                                   # run all tests
flutter run -d chrome                          # run PWA locally
make web                                       # production web build (canvaskit, offline-first)
make release-android                           # Shorebird Android release
make patch-android                             # Shorebird OTA patch
make release-tag VERSION=X.Y.Z+N               # bump pubspec, prepend CHANGELOG.md, commit, annotated tag
dart pub global activate -s path .             # install CLI from this checkout
ringdrill -h                                   # CLI usage (needs RINGDRILL_ADMIN_TOKEN)
```

Localization is regenerated automatically the next time you `flutter run`, `flutter build` or `flutter test` after editing `lib/l10n/app_en.arb` or `app_nb.arb`. Run `make i18n` (`flutter gen-l10n`) when you need an explicit regen — `make build` only covers freezed/`json_serializable` and does NOT touch `app_localizations*.dart`.

## Rules for agents

These are non-negotiable unless the maintainer says otherwise.

1. **Run codegen, not regex.** When you add or change a `@freezed` class, an enum carrying `@JsonValue`, or anything with a `part 'x.g.dart'`/`part 'x.freezed.dart'` directive, run `make build` (or `dart run build_runner build --delete-conflicting-outputs`). Never edit the generated output by hand.
2. **Never edit `*.freezed.dart`, `*.g.dart`, `app_localizations*.dart` directly.** They are regenerated and your changes will be lost. Change the source (`*.dart` model files or `*.arb` files) instead.
3. **Keep mobile-safe imports mobile-safe.** Any file imported from `lib/main.dart` on a non-web platform must not transitively import `dart:html` or `package:web`. Use the existing `if (dart.library.io)` pattern with a stub. Web-only code lives under `lib/web/`.
4. **Localize every user-visible string.** No raw English text in widgets. Add the key to `app_en.arb` and `app_nb.arb` together. If you do not know the Norwegian translation, copy the English string and flag it for review in the PR description.
5. **Respect the analytics consent gate.** Do not call Sentry, analytics or any network telemetry outside the consent check in `lib/main.dart`. The default is opt-out.
6. **Use `SimpleTimeOfDay` for stored times.** `TimeOfDay` only inside Flutter widgets. The CLI and any code under `lib/data/` or `lib/models/` must use `SimpleTimeOfDay`.
7. **CLI must stay Flutter-free.** `bin/ringdrill.dart` and anything it imports (currently only `lib/data/drill_client.dart`) must not import `package:flutter/*`. Adding a Flutter import here will break `dart pub global activate`.
8. **Drill file format is versioned.** `DrillFile.drillSchema1_0` is the current schema. Bumping it requires updating the import code in `lib/data/drill_file.dart`, the Netlify upload handler, and a migration path for existing files. Do not change the schema string without coordinating.
9. **Verify before claiming green.** Run `flutter analyze` and `flutter test` before reporting a task complete. The stale default-template `test/widget_test.dart` has been removed, so a clean run is now the expected baseline. If a test fails, fix it or flag it rather than asserting all tests pass.
10. **Match existing formatting.** This repo follows Dart's default `dart format` style and `flutter_lints`. Do not introduce new lint suppressions without a comment explaining why.
11. **Propose an ADR when you change architecture.** If your change introduces, replaces or contradicts an architectural assumption (new dependency category, new file format, new release channel, new backend endpoint, new persistence mechanism, new state-management approach, removal of an existing pattern), add an ADR file under [`docs/adrs/`](./docs/adrs/) in the same change set. Use the next free number and follow [`docs/adrs/template.md`](./docs/adrs/template.md). Update the index in [`docs/adrs/README.md`](./docs/adrs/README.md). Default status is `proposed`. Only set the status to `accepted` when the user explicitly instructs you to do so in the same conversation; otherwise leave it `proposed` for maintainer review.

## Architecture Decision Records

Before introducing a new pattern, check [`docs/adrs/`](./docs/adrs/) for an existing decision that already covers it. If one exists and your change conflicts with it, do not silently work around it. Either follow the decision, or propose a new ADR that supersedes it (set the old one's status to `superseded by ADR-NNNN` in the same change). See [ADR-0001](./docs/adrs/0001-record-architecture-decisions.md) for the process.

## Where to look first

* App bootstrap, themes, Sentry/consent gating: `lib/main.dart`.
* Routing: `buildRouter` and `MainScreen` in `lib/views/main_screen.dart`.
* Domain core: `lib/models/exercise.dart` (rotation math is in `teamIndex`/`stationIndex` extensions).
* Drill timer/phase engine: `lib/services/exercise_service.dart`.
* File import/export pipeline: `lib/data/drill_file.dart` plus `lib/services/shared_file_channel.dart`.
* Backend contract: `netlify.toml` for routes, `netlify/functions/*.js` for handlers, `lib/data/drill_client.dart` for the Dart-side client.

More detail on each of these, plus repo layout and per-layer conventions, is in [`docs/architecture.md`](./docs/architecture.md).

## Pitfalls

Read these before your first commit.

* `lib/views/` is a single flat folder. Keep it that way unless the maintainer asks otherwise.
* `lib/web/program_page_controller.dart`, `platform_widget.dart` and `settings_page.dart` shadow files of the same name in `lib/views/`. The right one is picked via conditional import.
* `sentry.properties` is gitignored. The Sentry plugin block in `pubspec.yaml` references it for source upload during release builds. Local builds work without it. Do not commit it.
* `untranslated-messages.json` regenerates on every build. If it shows up in `git status`, ignore it.
* The Shorebird `app_id` in `shorebird.yaml` is public and safe to commit.
