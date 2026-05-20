# CLAUDE.md

This file is read by Claude Code on startup. The authoritative project context lives in [`AGENTS.md`](./AGENTS.md). Read that first.

## TL;DR for Claude Code

* This is a Flutter app (Dart 3, SDK `^3.8.0`) plus a small Dart CLI and a Node Netlify backend. Repo layout, conventions and the backend contract live in [`docs/architecture.md`](./docs/architecture.md).
* Run `make build` after any change to a `@freezed` class, a `json_serializable` model, or an enum with `@JsonValue` annotations. Never hand-edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.
* Run `flutter analyze` and `flutter test` before claiming a task is done. `test/widget_test.dart` is a known-broken default-template smoke test, do not assert that all tests pass without flagging it.
* User-visible strings go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. No raw English in widgets.
* Web-only code lives in `lib/web/` behind `if (dart.library.io)` conditional imports. Do not import `package:web` or `dart:html` from anything that is also compiled on Android or iOS.
* The CLI (`bin/ringdrill.dart`) and everything it transitively imports must stay free of `package:flutter/*` imports.
* Sentry calls must be inside the analytics consent gate set up in `lib/main.dart`. Default is opt-out.

## Useful slash-command targets

* `/init` will offer to refresh this file. If you run it, keep the section above (the pointer to `AGENTS.md`) at the top, then update the bullets to match any architectural shifts.
* `/review` and `/security-review` are appropriate for changes that touch `lib/data/`, `lib/services/exercise_service.dart`, `bin/ringdrill.dart`, or anything under `netlify/functions/`.

## When `AGENTS.md` and `CLAUDE.md` disagree

`AGENTS.md` wins. This file is only allowed to be more specific, never to contradict.
