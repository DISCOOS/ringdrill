# Codex CLI prompt: Implement ADR-0017

Copy everything below the line into Codex CLI. The prompt is self-contained and references files inside this repo.

---

You are working in the RingDrill repository. Implement ADR-0017 ("Decouple number of stations from number of rounds in exercise setup") end-to-end. The ADR lives at `docs/adrs/0017-decouple-stations-from-rounds.md` and is accepted. It is the authoritative spec for this change. Read it in full before you start. Also skim DESIGN-002 at `docs/design/stations-tab.md` so you understand which surface owns station structural edits today.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* Localize every user-visible string. Add the key to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. If you do not know the Norwegian translation, copy the English string and flag it in the PR description.
* CLI must stay Flutter-free. `bin/ringdrill.dart` and anything it imports (currently only `lib/data/drill_client.dart`) must not gain a `package:flutter/*` import as a side effect of this change. The new field and its validators are widget-side concerns and belong in `lib/views/`.
* Mobile-safe imports. Nothing in this change should reach `dart:html` or `package:web`.
* Match existing Dart style. Do not add new lint suppressions.
* No codegen work is expected — the `Exercise` model on disk is unchanged, the new counter is form state and a parameter on `generateSchedule`. If you find yourself editing a `@freezed` class, stop and reconsider before running `make build`; the ADR explicitly avoids a schema bump.
* Run `flutter analyze` and `flutter test` before claiming the change is green. `test/widget_test.dart` is the known-broken default-template smoke test, flag it as such rather than asserting all tests pass.

## Commits

Commit as you progress, not in one giant blob. Each step below is a natural commit boundary. The project uses Conventional Commits with a scope. The format is:

```
<type>(<scope>): <imperative subject, lowercase, no trailing period>

<wrap body at ~72 chars. Explain what changed and why, not how. Reference
ADR-0017 in the body where it adds context. Multiple paragraphs are fine.
Avoid bullet points unless the change naturally has a list.>
```

Allowed types from this repo's history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Scopes already in use that are relevant here: `exercise`, `coordinator`, `stations`. For this change use `exercise` for form and service edits, and `docs` only if you touch documentation. Examples that match the existing style:

* `feat(exercise): decouple station count from rounds in setup form`
* `refactor(exercise): rename ensureStations parameter to numberOfStations`
* `test(exercise): cover one-round-four-stations rotation case`

Do not use a single mega-commit titled "implement ADR-0017". Separate commits per step make review and bisect work.

## Scope

The implementation is five steps. Do them in order. Commit at the end of each step.

### Step 1. `ProgramService.generateSchedule` signature

Edit `lib/services/program_service.dart`.

* Add a required `int numberOfStations` parameter to `generateSchedule`. Place it next to `numberOfTeams`/`numberOfRounds` so the call site reads naturally.
* Replace the existing `assert(numberOfTeams <= numberOfRounds, ...)` with `assert(numberOfTeams <= numberOfStations, ...)`.
* Change the `ensureStations` call site from `ensureStations(localizations, numberOfRounds, stations)` to `ensureStations(localizations, numberOfStations, stations)`.
* Rename the `numberOfRounds` parameter of the `ensureStations` helper to `numberOfStations`. The body already generates N stations, just the parameter name lies today.
* The `schedule` list keeps its `numberOfRounds`-driven length. Do not change schedule generation.

Update the one call site in `lib/views/exercise_form_screen.dart` (`_saveExercise`) to pass `numberOfStations`. Until Step 2 lands the field, source the value from `int.parse(_numberOfTeamsController.text)` so the build stays green.

Verify with `flutter analyze`. Commit: `refactor(exercise): pass explicit numberOfStations through generateSchedule`.

### Step 2. Form field and follow-teams behaviour

Edit `lib/views/exercise_form_screen.dart`.

Add a third numeric field "Number of stations" / "Antall poster" next to teams and rounds. Layout follows the existing Row that holds rounds and teams. The new field goes in the same Row, so the user sees three numeric inputs side by side. If the row gets too cramped on narrow widths, wrap onto a second row instead of shrinking type.

Behaviour:

* On `initState`, `_numberOfStationsController.text` is initialized from `widget.exercise?.stations.length` if editing, otherwise from `_numberOfTeamsController.text` (the existing default `"4"`).
* A boolean `_stationsTracksTeams` starts `true` on a new exercise and `false` when editing an existing exercise that already has a station count. While `true`, any change to the teams field updates the stations field to the same value. Wire this through `onChanged` on the teams `TextFormField`.
* When the user manually edits the stations field, set `_stationsTracksTeams = false`. From that point on, teams changes no longer overwrite stations within the current form session.

Bounded numeric input. ADR-0017 keeps the three counters as `TextFormField`s and tightens them per Material Design 3 text-field guidance. Apply to all three fields (teams, stations, rounds):

* `keyboardType: TextInputType.number` (teams and rounds already have this, add for stations).
* `inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]`. Digits only, max two characters. Import `package:flutter/services.dart`.
* `decoration` carries a persistent `helperText` showing the practical range. Teams and stations both use `"2–12"`. Rounds uses `"1–12"`. Use the same string literal across English and Norwegian, no ARB key needed — it is just digits and an en-dash.
* Validators:
  * Teams: integer in 2..12 and `<= numberOfStations`. Out-of-range gives a specific message via a new ARB key `valueMustBeBetween(min, max)` (English: "Must be between {min} and {max}"). Cross-field failure keeps the existing `mustBeEqualToOrLessThanNumberOf(localizations.station(2).toLowerCase())` message.
  * Stations: integer in 2..12 and `>= numberOfTeams`. Cross-field failure uses a new ARB key `mustBeEqualToOrGreaterThanNumberOf(arg)` mirroring the existing `mustBeEqualToOrLessThanNumberOf`.
  * Rounds: integer in 1..12. Drop the rounds-vs-teams cross-check entirely.

Update `_saveExercise` to pass `numberOfStations: int.parse(_numberOfStationsController.text)` to `ProgramService.generateSchedule`. Dispose the new controller in `dispose()`.

### Step 3. Soft notes

Below the Row of three numeric fields, render one of two helper-text notes when the configuration triggers it. The notes are informational. Save stays enabled.

* When `numberOfRounds > numberOfStations` (revisits): "Hvert lag besøker noen poster flere ganger. Med {rounds} runder og {stations} poster passerer hvert lag hver post omtrent {rounds}/{stations} ganger." New ARB key `stationsRevisitNote` with two integer placeholders.
* When `numberOfRounds < numberOfStations` (under-coverage): "Hvert lag besøker bare {rounds} av {stations} poster under denne øvelsen." New ARB key `stationsUnderCoverageNote` with two integer placeholders.
* When `numberOfRounds == numberOfStations`: no note (the common case).

Styling: a `Padding` + `Text` block using `Theme.of(context).textTheme.bodySmall` with `color: colorScheme.tertiary` (or the existing helper-text colour if there is a project convention — match what surrounding form fields use). No icon, no border. Recompute on every rebuild from the three controllers via a small derived state, mirroring how the existing validators read sibling fields through their controllers.

Add the English variants to `app_en.arb` and flag the Norwegian as already-translated above. Confirm `flutter analyze` is clean before committing.

Commit: `feat(exercise): explicit station count with soft warnings for rounds/stations mismatch`. This commit can also fold in Step 2's form changes — they share the same surface and tell one story for reviewers. Use your judgement.

### Step 4. Reducing station count must not silently drop data

`ensureStations` truncates when the new station count is smaller than the existing list. For a fresh exercise that is fine because every station is a placeholder. For an existing exercise it would silently lose user-edited names, descriptions and positions.

In `_saveExercise`, if `widget.exercise != null` and the new `numberOfStations < widget.exercise!.stations.length` and any of the to-be-dropped stations carry user-visible content (non-default `name`, non-empty `description`, or non-null `position`), show a confirmation dialog before continuing:

> "Reducing the number of stations will remove {N} stations including their names, descriptions and positions. This cannot be undone. Continue?" (Localize through new keys `confirmReduceStationsTitle` and `confirmReduceStationsBody`.)

Default-named stations with no description and no position can be dropped silently — they carry no information. Detection: a station is "default" if its name matches the pattern `${localizations.station(1)} ${index + 1}` and `description` is null/empty and `position` is null. Implement this check inline; do not add a new top-level helper unless it is reused.

If the user cancels, do not save and return from `_saveExercise`. If they confirm, proceed.

Commit: `feat(exercise): confirm before dropping user-edited stations on count reduction`.

### Step 5. Tests

Add unit tests under `test/`. Existing exercise tests live in `test/utils/exercise_share_format_test.dart`, `test/add_exercises_merge_test.dart` and `test/program_repository_migration_test.dart`. Either add to those or create a new `test/exercise_station_count_test.dart` — match whatever already exists for the area you touch.

Cover at minimum:

* `generateSchedule` with `numberOfTeams = 4`, `numberOfStations = 4`, `numberOfRounds = 1` produces an exercise with `stations.length == 4`, `schedule.length == 1`, and `stationIndex(team, 0)` returns `team` for teams 0..3.
* `generateSchedule` with `numberOfRounds > numberOfStations` does not assert and produces a valid schedule (revisits are allowed).
* `generateSchedule` asserts when `numberOfTeams > numberOfStations`.
* A loaded exercise where `stations.length != numberOfRounds` (e.g. 4 stations, 1 round) round-trips through `Exercise.toJson` / `Exercise.fromJson` unchanged.
* The form validators reject teams=1, teams=13, stations=1, stations=13, rounds=0 and rounds=13 with range-specific messages. Cross-field validation rejects teams=8 with stations=4 and accepts teams=4 with stations=8.

Run `flutter analyze` and `flutter test`. Acknowledge `test/widget_test.dart` is still broken.

Commit: `test(exercise): cover decoupled station count and rotation cases`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` — no new failures. `test/widget_test.dart` remains broken, do not try to fix it.
3. Manual QA matrix (record in the PR description):
   * Create a new exercise with 4 teams, 4 stations, 1 round. Verify the coordinator screen shows 4 stations with one round each, and that team N lands at station N.
   * Create an exercise with 4 teams, 4 stations, 6 rounds. Verify the revisits soft note appears under the rounds field, the save button stays enabled, and the rotation matrix shows each team visiting some stations twice.
   * Create an exercise with 4 teams, 6 stations, 4 rounds. Verify the under-coverage soft note appears, save stays enabled, and the team list shows each team visiting only 4 of 6 stations.
   * Try to enter 13 or 1 in any of the three counters. Verify the field shows the helper "2–12" (or "1–12" for rounds) and the validator blocks save with a range-specific error.
   * Edit an existing exercise that has stations with names, descriptions or positions filled in. Reduce the station count. Verify the confirmation dialog appears and cancelling preserves the existing data.
   * Open an exercise that was created before this change (`stations.length == numberOfRounds`). Verify it loads and renders unchanged, and that re-saving it with no changes produces an identical exercise.
4. Verify the rotation-share text (long-press on the coordinator round table, or the copy button) still includes correct counts of rounds, teams and stations on a revisits configuration.

## Deliverables

A series of commits, each following the format above, that together:

* Pass `numberOfStations` explicitly through `generateSchedule`.
* Add the form field, validators and follow-teams behaviour.
* Add the two soft notes with localized strings.
* Guard against silent data loss when reducing station count on an existing exercise.
* Cover the new behaviour with tests.

ADR-0017 is the authoritative spec for this change. If you find yourself contradicting it, stop and ask. Do not write a new ADR.
