# CLAUDE.md

This file is read by Claude Code on startup. The authoritative project context lives in [`AGENTS.md`](./AGENTS.md). Read that first.

## TL;DR for Claude Code

* This is a Flutter app (Dart 3, SDK `^3.8.0`) plus a small Dart CLI and a Node Netlify backend. Repo layout, conventions and the backend contract live in [`docs/architecture.md`](./docs/architecture.md).
* Run `make build` after any change to a `@freezed` class, a `json_serializable` model, or an enum with `@JsonValue` annotations. Never hand-edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.
* Format what you touch: `dart format <the files you edited>` before committing. `lib/`, `test/` and `bin/` are formatted baselines, so any diff the formatter produces is yours — and naming files rather than a directory keeps a commit scoped (`dart format lib/` reformats files you did not touch). `make format` is the whole-tree sweep; `make format-check` fails without writing. See rule 10 in `AGENTS.md`.
* Run `flutter analyze` and `flutter test` before claiming a task is done. The old default-template `test/widget_test.dart` has been removed, so a clean run is the expected baseline; if a test fails, fix or flag it rather than asserting all tests pass.
* User-visible strings go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. No raw English in widgets. After editing an ARB run `make i18n` (`flutter gen-l10n`) — `make build` does NOT regenerate `app_localizations*.dart`. An ARB edit also feeds `make labels` → `lib/l10n/headless_labels.g.dart`, the Flutter-free subset the CLI needs; `make i18n` and `make build` both run it, and `test/l10n/headless_labels_sync_test.dart` catches drift.
* Web-only code lives in `lib/web/` behind `if (dart.library.io)` conditional imports. Do not import `package:web` or `dart:html` from anything that is also compiled on Android or iOS.
* The CLI (`bin/ringdrill.dart`) and everything it transitively imports must stay free of `package:flutter/*` imports. Its closure is now large (the source compiler, the models, the brief layer), so run `flutter test test/bin/cli_flutter_free_test.dart` when you touch `lib/data/`, `lib/models/`, `lib/utils/` or `lib/services/brief/`; `make cli-check` is the authoritative check for the final gate.
* Run `make mcp-bundle` after changing anything under `lib/data/source/`, `lib/models/`, `lib/services/brief/` or `lib/l10n/`. Those are cross-compiled to JavaScript for the hosted MCP endpoint (ADR-0060) and the bundle is committed; a stale one serves old compiler behaviour from `/mcp` while the app and CLI look fine. Changing how the function is *packaged* (`netlify.toml`, `netlify/functions/mcp.js`, `netlify/functions/lib/`, `mcp/tools.mjs`) is a different risk with the same silent failure mode — run `node --test netlify/tests/mcp-packaging.test.mjs`, and `npm run smoke:mcp` once it is deployed. Touching a `[[redirects]]` block is a third variant that no checkout test can see — `/mcp/artifact/*` (ADR-0070) is only proven by `npm run smoke:mcp`, because a broken rewrite answers 200 with the app shell. See rule 1 in `AGENTS.md`.
* A drill plan can be authored as one YAML source document and compiled: `ringdrill create | build | decompile | analyze | render | schema` (DESIGN-014). The format is described exactly once — the field table in `lib/data/source/source_fields.dart` drives every command and the generated JSON Schema — so add a field there, not in six places. `build(decompile(d))` must preserve `d`'s `contentHash`; numbering comes from list position and names are never parsed or rewritten (ADR-0059).
* Sentry calls must be inside the analytics consent gate set up in `lib/main.dart`. Default is opt-out.
* To see what a widget looks like without a browser or device, render it to a PNG via `skills/flutter-widget-preview/` (harness at `test/support/widget_preview_harness.dart`). No-browser companion to Flutter's Widget Previewer. Reach for it whenever you change a widget's appearance and want to verify before claiming done (see rule 14 in `AGENTS.md`).
* All documentation is written in English (`docs/`, ADRs, DESIGN issues, `README.md`, `AGENTS.md`, `CLAUDE.md`). Real example data (e.g. Norwegian SAR-plan content) and quoted template fields may stay in their source language. See rule 12 in `AGENTS.md`.

## Useful slash-command targets

* `/init` will offer to refresh this file. If you run it, keep the section above (the pointer to `AGENTS.md`) at the top, then update the bullets to match any architectural shifts.
* `/review` and `/security-review` are appropriate for changes that touch `lib/data/`, `lib/services/exercise_service.dart`, `bin/ringdrill.dart`, or anything under `netlify/functions/`.

## When `AGENTS.md` and `CLAUDE.md` disagree

`AGENTS.md` wins. This file is only allowed to be more specific, never to contradict.
