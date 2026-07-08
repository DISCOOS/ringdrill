# Implement DESIGN-009 — Prompt 4b: expose plan-field tokens in the picker

You are working in the RingDrill repository, on `design-009`. This is a small, **views-only** follow-up to prompt 4. The `/` and `{{` insertion menu already offers variables, `station.loc.*`/`station.person.*` and the two program plan-fields, but it does **not** offer the `exercise.*` fields (and offers only `program.name`/`program.description`). The brief renderer already resolves all of these — the gap is purely discoverability in the picker. Close it. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative; read `AGENTS.md` rule 9 (test-loop discipline).

**No model change, no renderer change.** This wires already-resolvable fields into the picker's `planFields` list. The invariant we protect: *the picker never offers a token the renderer can't resolve at that scope.*

## What resolves where (verified against `brief_renderer.dart`)

The cross-reference `refContext` cascade is: `program.*` cascades into exercise-scope fields (`brief_renderer.dart` builds `exerciseRefContext = {...programRefContext, ..._exerciseRefContext}`), and that combined context cascades into station and roleplay fields via `_buildStationContext`. So:

* **Program editor** fields resolve `program.*` only.
* **Exercise editor** fields resolve `program.*` + `exercise.*`.
* **Station editor** and **RolePlay editor** fields resolve `program.*` + `exercise.*` (plus the `station.loc/person.*` already wired in prompt 4).

The resolvable field sets, taken directly from the renderer's `refContext` maps (do not add any facet not in these maps):

* `_programRefContext`: `program.name`, `program.description`.
* `_exerciseRefContext`: `exercise.name`, `exercise.numberOfTeams`, `exercise.numberOfRounds`, `exercise.startTime`, `exercise.endTime`, `exercise.timeLabel`, `exercise.durationLabel`, `exercise.executionTime`, `exercise.evaluationTime`, `exercise.rotationTime`, `exercise.phaseBreakdown`.

`timeLabel` (e.g. the "0900–1100" range), `durationLabel` (e.g. "2 timer (60 min pr oppdrag)") and `phaseBreakdown` (e.g. "15 | 10 | 5") are the localized composite strings the renderer already computes — offer them too, they are the most useful ones for authors.

## Ground rules

* **One source of truth.** Build the `PlanFieldToken` lists in a single shared helper (e.g. `lib/views/widgets/plan_field_tokens.dart`) with `program(l)` and `exercise(l)` builders, and have every editor pull from it. Do not hand-inline separate lists per editor — that is exactly the drift this consolidates. The program editor's current inline `program.name`/`program.description` list is replaced by the shared `program(l)`.
* Views-only. No change to models, `brief_renderer.dart`, or any `refContext` map. If you find yourself wanting to add a facet, stop — it must already be in a `refContext` map, or it doesn't belong in the picker.
* Reuse the existing `PlanFieldToken` type and the existing `planFields:` param on `RingDrillTextField`/`RingDrillTextArea`. No new picker mechanics.
* Labels via ARB, then `make i18n`. Reuse existing keys where they exist (`programName`, `programDescription`, `exerciseName`, `numberOfTeams`, `numberOfRounds`, `startTime`, `executionTime`, `evaluationTime`, `rotationTime`). Add nb+en keys only for the four without a label: `endTime` ("Sluttid"), `timeLabel` ("Tidsrom"), `durationLabel` ("Varighet"), `phaseBreakdown` ("Faseinndeling"). Pick natural en counterparts.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/views/`); `make i18n` only when ARB changes; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Three commits.

### Commit 1. Shared plan-field token builders + labels

Add `lib/views/widgets/plan_field_tokens.dart` exposing `program(AppLocalizations)` → the two program tokens and `exercise(AppLocalizations)` → the eleven exercise tokens, each `PlanFieldToken(name: '<path>', label: <l10n>)`. Add the four missing ARB labels (nb + en) and `make i18n`.

Files: the new helper, `lib/l10n/app_nb.arb`, `lib/l10n/app_en.arb`, regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): add shared program/exercise plan-field token builders`.

### Commit 2. Wire the lists into every editor

Pass the right list into each editor's token-aware fields (all `tokenAware: true` `RingDrillTextField`/`RingDrillTextArea` call sites):

* `program_form_screen.dart`: `planFields: PlanFieldTokens.program(l)` (replacing the inline list).
* `exercise_form_screen.dart`: `[...program(l), ...exercise(l)]`.
* `station_form_screen.dart` and `roleplay_form_screen.dart`: `[...program(l), ...exercise(l)]` (this is additive to the `station.loc/person` entries the `StationScope` already supplies — those come through `StationScope`, not `planFields`, so both coexist).

Files: the four editor screens. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): offer program and exercise plan-field tokens in every editor`.

### Commit 3. Tests

Under `test/views/` (and a small renderer round-trip guard):

* **Picker offers them.** In the exercise editor, opening the picker (via `/` or `{{`) lists the `exercise.*` and `program.*` entries; in the program editor it lists only `program.*` and no `exercise.*`; selecting one inserts the exact `{{exercise.startTime}}`-style token.
* **Resolution guard (the important one).** For every `PlanFieldToken` in `program(l)` and `exercise(l)`, insert `{{<name>}}` into a markdown field of a sample program/exercise, render through `BriefRenderer`, and assert the output contains **no** unknown-reference placeholder (`briefUnknownReference`) and is non-empty. This mechanically enforces "the picker never offers an unresolvable token", so a future rename in the renderer that drops a facet fails here.
* Station/roleplay editors: the plan-field entries coexist with the `station.loc/person.*` entries (both appear).

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover plan-field picker entries and their brief resolution`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: in the exercise editor, `/start` and `{{exercise.` both surface the exercise fields; inserting `{{exercise.timeLabel}}` renders the time range in the brief; the program editor offers only `program.*`; the station/roleplay editors still offer `station.loc/person.*` alongside the new plan fields.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`. No model or renderer change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes that the picker now offers the already-resolvable `program.*`/`exercise.*` fields from a single shared source, guarded by a renderer round-trip so an offered token can never be unresolvable.

ADR-0047 and DESIGN-009 are authoritative. Actual per-round times (`exercise.round.*` against `Exercise.schedule`) are **out of scope** here — that is a separate design addendum, not a wiring change. If exposing the fields needs anything beyond a `planFields` list and four ARB labels, stop and report.
