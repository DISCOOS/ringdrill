## Investigation

2026-06-07: Pre-implementation notes for stage 3.

**The stub.** `lib/views/concept_primer_screen.dart` — `onOpenExample` currently calls `_dismiss(context)` directly (with the stage-3 TODO comment). `_dismiss` writes `keyOnboardingSeen` and navigates to `routeProgram`. Stage 3 inserts the import before the dismiss.

**The right import call.** `ProgramService().installFromFile(file, activate: true)` (`lib/services/program_service.dart:534`). Confirmed it:
- Parses `file.program()` to a full `Program` (preserving uuid, name, brief, rolePlays, teams)
- Sets `ProgramSource.imported(fileName: ...)`
- Saves all exercises, teams, rolePlays, actors to the repo
- Calls `repo.setActiveProgramUuid(installed.uuid)` when `activate: true`
- Emits `ProgramEventType.programInstalled` — `MainScreen` already subscribes to `ProgramService().events` and rebuilds

`importProgram` is wrong here: it merges *exercises only* into the existing active program, losing the incoming name, brief, and rolePlays. `installFromFile` preserves the full plan as its own named, active entry.

**Asset loading.** `rootBundle.load(assetPath)` → `ByteData` → `bytes.buffer.asUint8List()` → `DrillFile.fromBytes(fileName, bytes)`. `rootBundle` already used in `brief_renderer` (`lib/services/brief/brief_renderer.dart:61`), confirmed mobile/web safe. Import: `package:flutter/services.dart`.

**Locale selection.** `Intl.getCurrentLocale()` (already used in `NotificationService`, `lib/services/notification_service.dart:207`). Extract language code with `.split('_').first`, pick `'nb'` asset for `'nb'`, else fall back to `'en'`.
- Asset paths: `assets/example/onboarding-example.nb.drill` and `assets/example/onboarding-example.en.drill`

**Schema 1.2 member layout (from `lib/data/drill_file.dart`).** `DrillFile.fromProgram` is the authoritative writer. It emits:
- `metadata.json` — `ProgramMetadata` with `schema: drillSchemaCurrent` (`'1.2'`)
- `program.json` — `Program` shell (teams/exercises/rolePlays/actors stripped to `[]`)
- `exercises/<uuid>.json` — per exercise
- `exercises/<uuid>/<field>.md` — per markdown exercise field (null → no file)
- `exercises/<uuid>/stations/<index>/<field>.md` — per station markdown field
- `teams/<uuid>.json` — per team
- `roleplays/<uuid>.json` — per roleplay
- `roleplays/<uuid>/behavior.md`, `background.md`, `props.md` — per roleplay markdown fields
- `actors/<uuid>.json` — per actor
- `program/intro.md`, `program/comms.md`, `program/before-round.md` — program brief markdown

The screenshot demo generator (`tools/screenshots/make_demo_drills.py`) omits `roleplays/`, `actors/`, and brief `.md` entries (schema 1.0 shape) — confirmed wrong for this asset.

**Generator approach.** Using `DrillFile.fromProgram` in a Dart script (`tools/generate_example_drills.dart`) rather than extending the Python generator. Reason: it's the same serialization path the app uses, handles all schema 1.2 fields automatically, and avoids reverse-engineering the JSON structure in Python. The script imports only `dart:io` + `package:ringdrill/` (no Flutter) — runs with `dart run tools/generate_example_drills.dart`.

**Numbering continuity.** Adopted option (a): two exercises. Exercise #1 (index 0 → exerciseNumber 1) is a short intro. Exercise #2 (index 1 → exerciseNumber 2) is the three-station rotation, matching the `2a`/`2b`/`2c` labels hardcoded in `RingRotationFigure` (`exerciseNumber: 2, StationNumberFormat.alpha`). The `Program.stationNumberFormat` is set to `StationNumberFormat.alpha` so the in-app station badges show `2a`/`2b`/`2c` too.
