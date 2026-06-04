---
status: accepted
date: 2026-06-04
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0034: Centralise numbering in one module and make number formats configurable per plan

## Context and problem statement

RingDrill labels three kinds of entity with a number: the exercise (`#1`), the station inside an exercise (`1.2`), and the markør / role inside an exercise (`1.2`). Today that labelling is hardcoded and duplicated across at least five call sites, with no shared abstraction:

* [`station_list_view.dart`](../../lib/views/station_list_view.dart) — `_stationCode()` returns `'$exerciseNumber.${station.index + 1}'`. This is the only place that produces the documented "X.Y" format.
* [`roleplays_view.dart`](../../lib/views/roleplays_view.dart) — inlines the same `'$exerciseNumber.${rolePlay.index + 1}'` for markører.
* [`station_mini_map.dart`](../../lib/views/widgets/station_mini_map.dart) — its own variant of the same expression, with a fallback to `'${station.index + 1}'` when the exercise is not found.
* [`brief_renderer.dart`](../../lib/services/brief/brief_renderer.dart) — `_exerciseNumber()` computes the 1-based exercise position, and `_stationLetter()` already produces an "X{a-z}" style letter (`'a' + index`) for anchor ids. This logic exists only in the brief layer and is not reused by the UI.
* [`exercise_number_badge.dart`](../../lib/views/widgets/exercise_number_badge.dart) — `ExerciseNumberBadge` takes an `int` and hardcodes `'#$number'` internally, so the `#` prefix is baked into the widget rather than chosen by a format.

Three concrete problems follow from this:

1. **Exercise numbers are not surfaced where users expect them.** The number is already computed (1-based index in `program.exercises`) but only rendered in the drill mini-player. The exercises list (`ExerciseCard` in [`program_view.dart`](../../lib/views/program_view.dart)) shows only `exercise.name`, so users have to bake the number into the title by hand. The request is to number exercises automatically.

2. **Only one station format exists.** The app supports "X.Y" and nothing else. We want at least a second format, "X{a-z}" (for example `1a`, `1b`), and the format should be configurable per plan, so a whole program reads with one consistent convention rather than mixing styles between its exercises.

3. **Formats are not extensible.** Adding a format today means editing several unrelated files. The format set itself should be cheap to grow.

A secondary defect: `_stationLetter()` computes `'a'.codeUnitAt(0) + station.index` with no handling beyond index 25, so a 27th station (`index == 26`) produces the character `{` instead of a letter.

## Decision drivers

* Adding a new format should touch one place, not five.
* The numbering logic must be usable from the CLI path, so it must stay free of `package:flutter/*` imports per [ADR-0005](./0005-cli-must-remain-flutter-free.md).
* Per-plan configuration has to round-trip through the drill file without breaking existing plans ([ADR-0007](./0007-drill-file-format.md)).
* The format set is small, app-internal and known at compile time. We do not need third-party or runtime-registered formats today.
* The fix should fold in the existing brief-layer letter logic (and its overflow bug) rather than leaving two parallel implementations.

## Considered options

* **Option A: One pure-Dart `Numbering` module with `@JsonValue` enums and a central formatter (chosen).** A `lib/models/numbering.dart` exposes `ExerciseNumberFormat` and `StationNumberFormat` enums plus static format functions. All call sites route through it. New fields on `Program` select the formats for the whole plan.
* **Option B: Sealed-class strategy objects in a runtime registry.** A `NumberingStrategy` interface with a `Map<String, NumberingStrategy>` registry, looked up by id. Maximally open for extension, including plugin-defined formats.
* **Option C: Keep formatting at the call sites, just add a second branch.** Add an `if`/`switch` for the alpha format in each of the five places.

## Decision outcome

Chosen option: **Option A**, because it removes the duplication, keeps the formatter CLI-safe, fits the existing freezed + `@JsonValue` codegen convention ([ADR-0002](./0002-freezed-models-with-extensions.md)), and makes adding a format a one-enum-value, one-switch-arm change. Option B's runtime registry buys flexibility we have no use for yet, and Option C entrenches the duplication this ADR exists to remove.

### The `Numbering` module

A new pure-Dart file `lib/models/numbering.dart` (no Flutter imports) holds the format enums and the formatter:

```dart
enum StationNumberFormat {
  @JsonValue('dotted') dotted, // "1.2"
  @JsonValue('alpha')  alpha,  // "1a"
}

enum ExerciseNumberFormat {
  @JsonValue('hash') hash,     // "#1"  — more may be added later
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
  static String alpha(int index) { /* implemented in the change set */ }
}
```

Adding a format is then: add one enum value (with `@JsonValue`), one `switch` arm, one localized label for the picker, and run `make build`. That is the whole "easy to extend" requirement.

### Per-plan configuration

`Program` gains two fields:

```dart
@Default(ExerciseNumberFormat.hash) ExerciseNumberFormat exerciseNumberFormat,
@Default(StationNumberFormat.dotted) StationNumberFormat stationNumberFormat,
```

Both are plan-wide knobs, set once in `ProgramFormScreen` (the Plan form) and applied to every exercise, station and markør in that plan. This keeps a whole program reading with one convention instead of mixing styles row to row. Markører / roles follow the plan's `stationNumberFormat` rather than carrying their own, so a station and its markør read as the same family. `exerciseNumberFormat` only has `hash` today, so its picker can stay hidden until a second value exists, but the field lives on `Program` now so adding one is purely additive.

The fields live on `Program` rather than `ProgramMetadata`; metadata holds bookkeeping (timestamps, schema marker), while these are user-facing content choices that belong next to `name` and `description`.

### Schema and versioning

Both fields are additive, optional, with defaults. Old drill files that lack them load as `hash` / `dotted`, and older app versions reading a new file ignore the unknown keys. This matches the additive-field handling used in [ADR-0019](./0019-roleplayer-participant-role.md), so no `drillSchema` bump is required. The maintainer should confirm this call when accepting the ADR, since the drill file format is versioned and bumping it is a coordinated change ([ADR-0007](./0007-drill-file-format.md), AGENTS rule 8).

### Badge family becomes pure presentation

The three sibling badges are renamed for consistency with the format enums and reduced to dumb presentation widgets that render a string handed to them:

* `StationCodeBadge` -> `StationNumberBadge` (`station_code_badge.dart` -> `station_number_badge.dart`).
* `RoleCodeBadge` -> `RoleNumberBadge` (`role_code_badge.dart` -> `role_number_badge.dart`).
* `ExerciseNumberBadge` keeps its name but **stops hardcoding `#`**. It currently takes an `int` and builds `'#$number'` internally; it changes to take the already-formatted string from `Numbering.exercise(...)`, so the chosen format fully determines what is rendered. With that change all three badges share one `label`-style string parameter and none of them know anything about formats.

Call sites then read, for example:

```dart
StationNumberBadge(
  label: Numbering.station(
    program.stationNumberFormat,
    exerciseNumber: exerciseNumber,
    stationIndex: station.index,
  ),
)
```

### Surfacing the exercise number

The exercises list must show the number automatically. `ExerciseCard` in `program_view.dart` gains an `ExerciseNumberBadge` (fed by `Numbering.exercise`) so the user no longer prefixes the title manually. The drill mini-player keeps its badge but switches to the formatted-string API.

The badge goes in the `leading` slot, matching `StationNumberBadge` and `RoleNumberBadge`, so the number token always reads first in the row and the three badges stay a visual family. The `leading` slot today holds `accent.indicator`, a `play_circle` icon that only appears when the exercise is live (otherwise `null`). The badge replaces it: it sits in `leading` unconditionally and carries the live state through `highlight: true` when the exercise is running. The `LiveAccent` background plus the highlighted pill already signal "live", so the separate play icon is dropped — the same reasoning the mini-player uses when it passes `highlight: false`. `trailing` is left untouched for row actions.

### The brief honours the plan format

The generated brief currently hardcodes the alpha style. `ringdrill-standard-v1.nb.md.mustache` emits `{{exerciseNumber}}{{stationLetter}}` (always "1a") in three places — the in-doc TOC link text, the station heading, and the position label — and `brief_renderer.dart` derives the heading anchor from the same string. This means the printed booklet ignores the configured format.

The brief is routed through the same `Numbering` module so it matches the app. The renderer computes a single `stationCode` via `Numbering.station(program.stationNumberFormat, exerciseNumber: …, stationIndex: …)` and exposes it to the template, which replaces the three `{{exerciseNumber}}{{stationLetter}}` occurrences with `{{stationCode}}`. The exercise's raw number is still used inside `stationCode`; the `#` prefix from `exerciseNumberFormat` is a badge-only concern and does not appear in brief headings.

The station anchor is derived from the formatted label rather than the letter. With the `dotted` format the `.` is dropped by the GitHub-style slug logic in `_toAnchor`, but the station name is always appended and the TOC link and heading derive from the same string, so links stay internally consistent and collisions are not a practical risk. `_stationLetter` is removed in favour of `Numbering.alpha`, which also fixes its past-`z` overflow.

### Consequences

* Good: One module owns numbering. Adding a format is a one-place change.
* Good: The CLI can format numbers without pulling in Flutter.
* Good: Brief and UI share the same formatter, so the printed booklet matches the configured format instead of being locked to the alpha style, and the past-`z` overflow bug is fixed in one place.
* Good: Exercise numbers appear in the list automatically, removing the manual-title workaround.
* Good: Badges become testable, format-agnostic presentation widgets.
* Bad: A rename touches the two badge files, their class names, and four call sites.
* Bad: Two new fields on `Program`, and a corresponding control in `ProgramFormScreen` plus l10n keys for the format picker.
* Bad: Call sites need the owning `Program` in scope to read the format. Most already have it (the station and markør lists, the brief renderer); any that only hold an `Exercise` must resolve the program first.
* Bad: Relying on additive-field tolerance instead of a schema bump is a judgement call the maintainer has to ratify.

## Pros and cons of the options

### Option A — Pure-Dart `Numbering` module with `@JsonValue` enums

* Good: Single source of truth, CLI-safe, matches existing codegen conventions.
* Good: Extending the format set is trivial and local.
* Good: Naturally folds in the brief letter logic and its bug fix.
* Bad: Formats are compile-time only; a third party cannot add one at runtime.

### Option B — Sealed-class strategy objects in a runtime registry

* Good: Open to runtime- or plugin-defined formats.
* Good: Each format is an isolated object.
* Bad: Heavier than the problem needs; `@JsonValue` / freezed do not map onto a string-keyed registry as cleanly, so persistence needs custom converters.
* Bad: Indirection with no current payoff. Can be adopted later if plugin-defined formats ever become a goal.

### Option C — Keep formatting at the call sites, add a second branch

* Bad: Entrenches the five-way duplication this ADR exists to remove.
* Bad: The alpha overflow bug would have to be fixed (or re-introduced) in each place.
* Bad: No single place to add the next format.

## Links

* Related ADRs:
  * [ADR-0002](./0002-freezed-models-with-extensions.md) — freezed + `@JsonValue` enums, the convention the format enums follow.
  * [ADR-0005](./0005-cli-must-remain-flutter-free.md) — the constraint that keeps `Numbering` Flutter-free.
  * [ADR-0007](./0007-drill-file-format.md) — versioned drill file; the additive-field decision is scoped here.
  * [ADR-0019](./0019-roleplayer-participant-role.md) — precedent for adding an optional field without a schema bump.
  * [ADR-0023](./0023-brief-theme-tokens.md) — brief rendering, source of the existing letter logic being consolidated.
* Related code:
  * `lib/models/numbering.dart` — new module (enums + formatter).
  * `lib/models/program.dart` — new `exerciseNumberFormat` and `stationNumberFormat` fields.
  * `lib/views/widgets/exercise_number_badge.dart` — takes a formatted label instead of an `int`.
  * `lib/views/widgets/station_number_badge.dart`, `lib/views/widgets/role_number_badge.dart` — renamed badges.
  * `lib/views/station_list_view.dart`, `lib/views/roleplays_view.dart`, `lib/views/widgets/station_mini_map.dart`, `lib/views/program_view.dart`, `lib/views/drill_player/drill_mini_player.dart` — route through `Numbering`.
  * `lib/services/brief/brief_renderer.dart` — drop `_stationLetter`, expose a `stationCode` via `Numbering.station` and derive the anchor from it.
  * `assets/templates/ringdrill-standard-v1.nb.md.mustache` — replace `{{exerciseNumber}}{{stationLetter}}` with `{{stationCode}}` in the TOC link, station heading and position label.
  * `lib/views/program_form_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — per-plan format picker and its strings.
</content>
</invoke>
