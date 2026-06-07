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

## Closing

2026-06-07: Stage 3 landed in three commits on main.

**New files:**
- `tools/generate_example_drills.dart` — Dart generator script; run with `dart run tools/generate_example_drills.dart` to regenerate assets
- `assets/example/onboarding-example.nb.drill` — Norwegian example plan
- `assets/example/onboarding-example.en.drill` — English example plan
- `test/data/example_drill_test.dart` — 14 tests validating shape of both bundled assets
- `test/views/concept_primer_open_example_test.dart` — 5 tests for the open-example flow (install, locale, fallback)

**Modified files:**
- `lib/views/concept_primer_screen.dart` — `onOpenExample` now loads locale-matched asset, calls `installFromFile(activate: true)`, falls back on error
- `pubspec.yaml` — declares both `.drill` assets under `assets/example/`
- `docs/prompts/DESIGN-007-stage-3-handoff.md` — this file (investigation + closing)

**Generator approach (Dart, not Python).** `tools/generate_example_drills.dart` uses `DrillFile.fromProgram` — the same serialization path as the app — to produce deterministic schema 1.2 archives. Fixed UUIDs (`onboarding-nb-v1`, `onboarding-en-v1`) make regeneration idempotent. Regenerate any time content needs to change.

**Asset shape:** each `.drill` contains:
- 2 exercises (intro ex #1, three-station rotation ex #2 with `numberOfTeams=3, numberOfRounds=2`)
- 3 teams (`Lag 1/2/3` or `Team 1/2/3`)
- 2 roleplays on exercise #2 (savnet person / vitne, or missing person / witness) with `.md` companion files
- `program/intro.md` brief

**Numbering continuity decision:** option (a) adopted — two exercises so the showcased exercise has `exerciseNumber=2`. The program sets `stationNumberFormat: StationNumberFormat.alpha` so in-app station badges read `2a`/`2b`/`2c`, matching the `RingRotationFigure` primer illustration exactly.

**Import call used:** `ProgramService().installFromFile(file, activate: true)` — preserves the incoming UUID/name/brief/rolePlays, sets the plan as active, emits `programInstalled` event (which `MainScreen` already handles). NOT `importProgram`, which merges exercises only.

**Locale selection:** `Intl.getCurrentLocale().split('_').first == 'nb'` picks the `nb` asset; all other locales fall back to `en`.

**Stage 4 seam:** the `ConceptPrimerScreen` has no TODO left. Stage 4 ("Start her" cue) adds a first-run pill on the first FAB in `ProgramView`, gated by `AppConfig.keyOnboardingSeen`. No seam needed in this file.

**Stage 5 seam:** `ConceptPrimerContent` (in `lib/views/widgets/concept_primer_content.dart`) is the reuse surface. Stage 5 mounts it directly inside the Help/FAQ screen chrome.
