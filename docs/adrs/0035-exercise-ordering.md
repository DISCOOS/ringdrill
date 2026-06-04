---
status: accepted
date: 2026-06-04
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0035: Give exercises an explicit order field and user-driven reordering

## Context and problem statement

Until [ADR-0034](./0034-configurable-numbering-formats.md), exercise numbers lived inside the exercise name ("1 Førstehjelp", "2 Bæring"). Sorting exercises alphabetically by name therefore produced the intended numeric order, and [`ProgramRepository.loadExercises`](../../lib/data/program_repository.dart) does exactly that:

```dart
items.sort((a, b) => a.name.compareTo(b.name)); // loadExercises()
```

The exercise number rendered everywhere is just the 1-based position in that list, computed the same way in `brief_renderer.dart`, `station_list_view.dart`, `roleplays_view.dart`, `drill_mini_player.dart` and now the exercises list.

ADR-0034 made the number automatic and took it out of the name. The alphabetical sort is now arbitrary: "Bæring" sorts before "Førstehjelp" regardless of the sequence the director intends, and the auto-number reflects that arbitrary order rather than any real running order. There is no way for a user to say "this exercise comes third". Unlike `Station` and `RolePlay`, which already carry an `index` field and sort on it, `Exercise` has no notion of order beyond its name.

This ADR gives exercises an explicit, user-controlled order and the means to change it.

## Decision drivers

* The exercise number is derived from list position, so the list order has to be meaningful and stable, not a side effect of names.
* `Station` and `RolePlay` already solve the same problem with an `index` field sorted by `a.index.compareTo(b.index)`. A third pattern would be inconsistent.
* The order must round-trip through the drill file without breaking existing plans ([ADR-0007](./0007-drill-file-format.md)), and existing plans must migrate to a sensible order rather than losing their current one.
* Reordering must work on touch, on wide-screen master/detail ([ADR-0030](./0030-wide-screen-master-detail-layout.md)), and for keyboard and screen-reader users. A drag-only solution fails the last two.
* Row edit affordances are reserved: swipe and long-press mean "edit", and the pencil is for the AppBar ([ADR-0031](./0031-row-edit-affordances.md)). Reordering needs its own affordance that does not collide with those.

## Considered options

* **Option A: Explicit `index` on `Exercise`, sorted on, with several reorder mechanisms (chosen).** Mirrors `Station`/`RolePlay`. The list order becomes data the user owns.
* **Option B: Sort by `startTime`.** Exercises already have a start time, and `Session` sorts chronologically. No new field.
* **Option C: Keep the name sort and the manual number in the title.** Reverts the relevant half of ADR-0034.

## Decision outcome

Chosen option: **Option A**, because it makes order first-class data the user controls, matches the existing `Station`/`RolePlay` pattern exactly, and keeps the auto-number meaningful. Option B cannot express a manual order and is unstable when two exercises share a start time; Option C undoes ADR-0034.

### Model and ordering

`Exercise` gains a non-null field, consistent with `Station`/`RolePlay`:

```dart
@Default(0) int index,
```

`ProgramRepository.loadExercises` sorts on `a.index.compareTo(b.index)` instead of name. Every other call site already reads exercises through `loadExercises`, so they inherit the new order for free, including the ADR-0034 number.

### Migration of existing plans

Old archives have no `index`, so every exercise deserializes to `0`. A `0`-collision is the signal that a plan predates this field. `loadExercises` normalises before returning: when the indices are not a valid permutation (duplicates, or all-default with more than one exercise), it re-derives them from the **current name order** and assigns `0..n-1`. This reproduces today's visual order exactly, so an upgraded plan looks unchanged until the user reorders it. The normalised indices persist on the next `saveExercise`. New exercises append at `max(index) + 1`; imported or copied exercises are renumbered into the target plan's sequence.

### Schema

`index` is additive and optional with a default, and the migration is deterministic, so no `drillSchema` bump is required (same tactic as [ADR-0017](./0017-decouple-stations-from-rounds.md) and ADR-0034). Older app versions reading a new file ignore the key and fall back to their name sort, which is a graceful, if unordered, degradation.

### Ways to change the order

A single drag gesture is not enough on its own. The decision is to ship three complementary mechanisms, primary first:

1. **Drag to reorder (primary).** The Øvelser segment list becomes a `ReorderableListView`. The drag handle is an explicit trailing affordance, not the row body, so it does not collide with swipe-to-edit or long-press-to-edit ([ADR-0031](./0031-row-edit-affordances.md)). This is the natural touch interaction and the default on compact.
2. **Move up / Move down (accessibility and wide-screen).** Each row's overflow menu gains "Flytt opp" / "Flytt ned", disabled at the ends. This is the keyboard- and screen-reader-reachable path, and it is the precise option in the wide master column where dragging across a tall list is awkward. It is also the only reorder path that works without a pointer.
3. **One-shot sort actions (bootstrap and cleanup).** The segment AppBar overflow gains "Sorter etter starttid" and "Sorter alfabetisk". Each rewrites all indices once, then the order is manual again. Chronological order is the most common starting intent, and this lets a user get 90% of the way there before nudging individual rows.

Reordering writes the new indices through `saveExercise` so the change persists immediately, the same write path the move actions use.

Considered and deferred: editing the number inline to jump an exercise to a position (powerful but easy to fat-finger, and it competes with the badge being read-only), and "flytt til topp/bunn" shortcuts (cheap to add later if the move actions prove tedious on long lists).

### Consequences

* Good: Exercise order is explicit, user-owned data, and the ADR-0034 number finally means something.
* Good: One ordering pattern across `Exercise`, `Station` and `RolePlay`.
* Good: Existing plans migrate to their current visible order with no surprise reshuffle.
* Good: Three reorder paths cover touch, pointer-free, and wide-screen, and a chronological bootstrap.
* Bad: A new field on `Exercise` plus codegen, and three UI surfaces (drag, overflow moves, sort actions) to build and localize.
* Bad: The `0`-collision migration heuristic is implicit. It is robust for real data but has to be covered by tests, including the edge case of a hand-edited file with partial indices.
* Bad: `ReorderableListView` plus the existing swipe/long-press affordances on the same row needs care so the gestures do not fight; the drag handle must be a distinct hit target.

## Pros and cons of the options

### Option A — Explicit `index` field with multiple reorder mechanisms

* Good: First-class, user-controlled order; consistent with `Station`/`RolePlay`.
* Good: Deterministic migration preserves current order.
* Good: Reorder paths cover every input modality.
* Bad: New field, codegen, and three UI surfaces.
* Bad: Migration heuristic and gesture coexistence need test coverage.

### Option B — Sort by `startTime`

* Good: No new field; reuses the `Session` precedent.
* Bad: Cannot express a manual order independent of time.
* Bad: Unstable when two exercises share a start time.
* Bad: Forces a start time to exist and be meaningful purely to drive ordering.

### Option C — Keep the name sort and the manual number in the title

* Bad: Reverts the half of ADR-0034 that removed the number from the name.
* Bad: Leaves ordering coupled to a naming convention users must remember.

## Links

* Related ADRs:
  * [ADR-0034](./0034-configurable-numbering-formats.md) — auto-numbering; the number depends on this order being meaningful.
  * [ADR-0017](./0017-decouple-stations-from-rounds.md) — precedent for an additive field with a default and no schema bump.
  * [ADR-0007](./0007-drill-file-format.md) — versioned drill file; the additive-field decision is scoped here.
  * [ADR-0030](./0030-wide-screen-master-detail-layout.md) — wide-screen master/detail; motivates the move-up/down path.
  * [ADR-0031](./0031-row-edit-affordances.md) — swipe/long-press reserved for edit; the drag handle is a separate affordance.
* Related code:
  * `lib/models/exercise.dart` — new `index` field.
  * `lib/data/program_repository.dart` — sort on `index`, the migration/normalisation step.
  * `lib/services/program_service.dart` — index assignment on add/copy/import, persistence of reorder writes.
  * `lib/views/program_view.dart` — `ReorderableListView`, overflow move actions, AppBar sort actions in the Øvelser segment.
  * `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — strings for the move and sort actions.
</content>
