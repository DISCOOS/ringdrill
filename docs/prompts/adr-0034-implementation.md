# Implement ADR-0034: centralised, per-plan numbering formats

You are working in the RingDrill repository. Implement ADR-0034 ("Centralise numbering in one module and make number formats configurable per plan") end-to-end. The ADR at `docs/adrs/0034-configurable-numbering-formats.md` is the authoritative spec and is `accepted`. Read it in full before writing any code.

The change introduces one pure-Dart `Numbering` module as the single source of truth for exercise, station and markør labels, moves the labelling off five hardcoded call sites, adds two per-plan format fields to `Program`, renames the badge family, surfaces the exercise number in the exercises list, and routes the generated brief through the same formatter so the printed booklet honours the configured format.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* **CLI stays Flutter-free.** `lib/models/numbering.dart` must not import `package:flutter/*`. The CLI imports `lib/data/`, which imports models; a stray Flutter import here breaks `dart pub global activate`. Verify with `rg "package:flutter" lib/models/numbering.dart` (must print nothing) and `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli`.
* **Run codegen, not regex.** Adding fields to the `@freezed` `Program` class and the `@JsonValue` enums requires `make build`. Never hand-edit `*.freezed.dart` or `*.g.dart`.
* **Localize every user-visible string.** The plan-form picker labels go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. If you do not know the Norwegian wording, copy the English and flag it in the final commit body.
* **No raw English in widgets**, no new lint suppressions, match `dart format`.
* **Norwegian terms only in the nb template.** The brief template change is mechanical; do not introduce English into `ringdrill-standard-v1.nb.md.mustache`.
* **Verify before claiming green.** `flutter analyze` and `flutter test` must pass. Each commit must leave the tree compiling — do not land a commit that breaks `flutter analyze`.

## Commits

Commit as you progress, not in one blob. Conventional Commits with a scope. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. The steps below are the commit boundaries, in order. All commits land together as one continuous series on the same branch.

### Commit discipline (non-negotiable)

A recurring failure mode is leaving regenerated or renamed files uncommitted, or leaving the old badge files behind after a rename. Avoid this:

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure. A rename must show the old path deleted and the new path added.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognise in `git status`, inspect it, then either include it or stop and ask.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires a clean tree on the working branch.

## Scope

Six steps. Do them in order. Each step must compile on its own.

### Step 1. The Numbering module

Create `lib/models/numbering.dart`. Pure Dart, no Flutter imports. It holds two `@JsonValue` enums and a stateless formatter:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

/// How a station/markør label combines the exercise number with the
/// sub-index. Add a value plus a `switch` arm in [Numbering.station] to
/// introduce a new format — that is the whole extension surface.
enum StationNumberFormat {
  @JsonValue('dotted') dotted, // "1.2"
  @JsonValue('alpha') alpha,   // "1a"
}

/// How a standalone exercise number renders. Only [hash] exists today.
enum ExerciseNumberFormat {
  @JsonValue('hash') hash, // "#1"
}

class Numbering {
  const Numbering._();

  static String exercise(ExerciseNumberFormat f, int number) => switch (f) {
    ExerciseNumberFormat.hash => '#$number',
  };

  static String station(
    StationNumberFormat f, {
    required int exerciseNumber,
    required int stationIndex, // 0-based
  }) => switch (f) {
    StationNumberFormat.dotted => '$exerciseNumber.${stationIndex + 1}',
    StationNumberFormat.alpha => '$exerciseNumber${alpha(stationIndex)}',
  };

  /// Bijective base-26: 0 -> a, 25 -> z, 26 -> aa, 27 -> ab, ...
  /// Replaces brief_renderer._stationLetter and fixes its overflow past 'z'.
  static String alpha(int index) {
    var i = index;
    final buf = StringBuffer();
    while (i >= 0) {
      buf.write(String.fromCharCode('a'.codeUnitAt(0) + i % 26));
      i = i ~/ 26 - 1;
    }
    return buf.toString().split('').reversed.join();
  }
}
```

Verify the `alpha` implementation against the doc comment (`26 -> aa`, `27 -> ab`, `51 -> az`, `52 -> ba`) — write the test before trusting it.

Create `test/models/numbering_test.dart` covering: both station formats, the exercise format, and `alpha` for indices 0, 25, 26, 27, 51, 52 (the overflow cases the old `_stationLetter` got wrong).

Files expected in this commit:

* `lib/models/numbering.dart`
* `test/models/numbering_test.dart`

Run `flutter analyze` and `flutter test test/models/numbering_test.dart`. Run `git status`. Commit: `feat(models): add Numbering module with exercise and station formats`.

### Step 2. Per-plan format fields on Program

Edit `lib/models/program.dart`. Add two fields to the `Program` factory, with defaults, near `name`/`description` (not in `ProgramMetadata` — these are user-facing content choices, not bookkeeping):

```dart
@Default(ExerciseNumberFormat.hash) ExerciseNumberFormat exerciseNumberFormat,
@Default(StationNumberFormat.dotted) StationNumberFormat stationNumberFormat,
```

Import `package:ringdrill/models/numbering.dart`. Both fields are additive and optional; old archives without the keys deserialize to the defaults (same backward-compat tactic as the `@Default([])` lists already in the class). No `drillSchema` bump.

Run `make build`. Confirm `program.freezed.dart` and `program.g.dart` regenerated and that the generated `fromJson` handles the new enum keys.

Files expected in this commit:

* `lib/models/program.dart`
* `lib/models/program.freezed.dart`
* `lib/models/program.g.dart`

Run `flutter analyze`. Run `git status` and confirm only the regenerated model files moved. Commit: `feat(models): add per-plan number format fields to Program`.

### Step 3. Badge family becomes format-agnostic

Three sibling badges become dumb presentation widgets that render a string handed to them. This step changes the widgets and every call site together so the tree keeps compiling.

`ExerciseNumberBadge` (`lib/views/widgets/exercise_number_badge.dart`): change the `int number` parameter to `String label` and render `label` verbatim instead of `'#$number'`. The `#` now comes from `Numbering.exercise`, so the chosen format fully determines the rendered text. Keep `highlight` and `size`.

`StationCodeBadge` -> `StationNumberBadge`: rename the class and the file (`station_code_badge.dart` -> `station_number_badge.dart`). Rename the `code` parameter to `label`. Keep `highlight` and `hasRoles`.

`RoleCodeBadge` -> `RoleNumberBadge`: rename the class and the file (`role_code_badge.dart` -> `role_number_badge.dart`). Rename the `code` parameter to `label`. Keep `highlight`.

Update every call site to route through `Numbering`. Find them all with `rg "ExerciseNumberBadge|StationCodeBadge|RoleCodeBadge|station_code_badge|role_code_badge"`. Expected sites:

* `lib/views/drill_player/drill_mini_player.dart` (2 occurrences) — wrap the computed `exerciseNumber` with `Numbering.exercise(program.exerciseNumberFormat, exerciseNumber)`. The program is already resolved as `ProgramService().activeProgram`; when it is null keep the existing fallback number and use `ExerciseNumberFormat.hash`.
* `lib/views/station_list_view.dart` — replace `_stationCode` with `Numbering.station(program.stationNumberFormat, exerciseNumber: exerciseNumber, stationIndex: station.index)`. Resolve the owning program via `ProgramService` the same way the view already loads exercises. Delete `_stationCode`.
* `lib/views/widgets/station_mini_map.dart` — same substitution. Preserve the existing fallback (`'${station.index + 1}'`) for the case where the exercise is not found in the program.
* `lib/views/roleplays_view.dart` — replace the inline `'$exerciseNumber.${rolePlay.index + 1}'` with `Numbering.station(program.stationNumberFormat, exerciseNumber: exerciseNumber, stationIndex: rolePlay.index)`.
* `lib/views/roleplay_form_screen.dart` — update the `RoleCodeBadge(code: code)` call to `RoleNumberBadge(label: …)`, routing the existing code computation through `Numbering.station` with the owning program's format.

Files expected in this commit (verify against `git status`; the two renamed files must show as delete + add):

* `lib/views/widgets/exercise_number_badge.dart`
* `lib/views/widgets/station_number_badge.dart` (was `station_code_badge.dart`)
* `lib/views/widgets/role_number_badge.dart` (was `role_code_badge.dart`)
* `lib/views/drill_player/drill_mini_player.dart`
* `lib/views/station_list_view.dart`
* `lib/views/widgets/station_mini_map.dart`
* `lib/views/roleplays_view.dart`
* `lib/views/roleplay_form_screen.dart`

Run `flutter analyze`. Run `git status`. Commit: `refactor(views): rename badge family to *NumberBadge and make them format-agnostic`.

### Step 4. Surface the exercise number in the exercises list

Edit `lib/views/program_view.dart`. In `ExerciseCard.build`, put an `ExerciseNumberBadge` in the `leading` slot, fed by `Numbering.exercise(program.exerciseNumberFormat, exerciseNumber)`. The exercise's 1-based number is its index in `program.exercises`; resolve it the same way the brief renderer does. The badge sits in `leading` unconditionally and carries the live state via `highlight: isLive`. Drop the `accent.indicator` `play_circle` from this `leading` slot — the `LiveAccent` background plus the highlighted pill already signal "live". Leave `trailing` untouched.

If `ExerciseCard` does not already have the owning `Program` in scope, thread it in from the caller rather than reaching for a global; check how the card is constructed first.

Files expected in this commit:

* `lib/views/program_view.dart`
* any caller that now has to pass the program/number into `ExerciseCard`

Run `flutter analyze`. Run `git status`. Commit: `feat(views): show the exercise number badge in exercise list rows`.

### Step 5. The brief honours the plan format

Edit `lib/services/brief/brief_renderer.dart`. Remove `_stationLetter` and its `@visibleForTesting` wrapper. Compute a single `stationCode` per station with `Numbering.station(program.stationNumberFormat, exerciseNumber: exNum, stationIndex: station.index)` and add it to the station context map. Derive `stationAnchor` from `stationCode` (plus name and variant) instead of `'$exerciseNumber$letter'`. The exercise's raw number stays inside `stationCode`; do not apply the `#` prefix in the brief.

Edit `assets/templates/ringdrill-standard-v1.nb.md.mustache`. Replace the three `{{exerciseNumber}}{{stationLetter}}` occurrences (TOC link text, station heading, position label) with `{{stationCode}}`. Leave everything else.

Update `test/services/brief/brief_renderer_test.dart`: drop any `stationLetter` test, and update fixtures/expectations that assumed the "1a" style for station headings and anchors. Add a test that rendering the same fixture under `stationNumberFormat: StationNumberFormat.dotted` produces dotted station codes ("1.1", "1.2") in the heading and a matching anchor, and under `alpha` produces "1a", "1b".

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`
* `assets/templates/ringdrill-standard-v1.nb.md.mustache`
* `test/services/brief/brief_renderer_test.dart`

Run `flutter analyze`. Run `flutter test test/services/brief/`. Run `git status`. Commit: `refactor(brief): drive station codes through Numbering and honour the plan format`.

### Step 6. The plan-form picker

Edit `lib/views/program_form_screen.dart`. Add a control to choose `stationNumberFormat` for the plan (a segmented button or dropdown matching the form's existing input style). Persist it onto the `Program` on save. Show a small live preview of a sample station code ("1.2" vs "1a") next to the control so the choice is legible.

`exerciseNumberFormat` has only one value today; do not surface a picker for it. Leave the field on the model and pass `ExerciseNumberFormat.hash` implicitly. Add a code comment noting the picker arrives when a second value does.

Add l10n keys for the control label, the option labels and the preview helper to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together.

Files expected in this commit:

* `lib/views/program_form_screen.dart`
* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`

Run `flutter analyze` and `flutter test`. Run `git status`. Commit: `feat(views): add the station number format picker to the plan form`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures.
3. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds — confirms `lib/models/numbering.dart` did not drag a Flutter import into the CLI graph.
4. `flutter build apk --debug` (or `flutter build bundle`) succeeds — confirms the template asset change did not break bundling.
5. `rg "StationCodeBadge|RoleCodeBadge|_stationLetter|stationLetter|_stationCode"` prints nothing in `lib/` — the old names and helpers are fully gone.
6. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean` and `git ls-files --others --exclude-standard` prints nothing.
7. **Diff sanity.** `git log --stat origin/main..HEAD` — walk every changed path and confirm each file is in the commit you intended, and that the two badge renames show as delete-plus-add.
8. Manual QA matrix (record the result in the final commit body):
   * Create a plan, set the station format to `alpha`, confirm the Poster and Markører lists, the exercise-card station rows, the mini-map badges and a generated brief all read "1a", "1b". Switch to `dotted`, confirm they all read "1.1", "1.2".
   * Confirm the exercises list now shows the exercise number badge in `leading`, and that a running exercise highlights the badge with no separate play icon.
   * Open an old plan saved before this change. Confirm it loads and defaults to `dotted` / `#` with no error.

## Deliverables

A series of six Conventional Commits as outlined, all on the same working branch, clean tree at the end. The final commit body should include the manual QA matrix and a note on any open question the implementation answered (in particular, whether the `dotted` station anchor proved stable in the brief TOC, since the `.` is dropped by the slug logic).

ADR-0034 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR unless something forces a structural deviation.
