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

All ordering controls live in a **contextual list header** — a slim toolbar between the segment's `SegmentedButton` row and the exercises list, shown only for the Øvelser segment. They are deliberately not in the global AppBar (where they competed with the publish and overflow actions) and not in an overflow menu (where the one-shot sorts read as hidden, and exposing both there felt heavy). Per-row controls are also rejected: cluttering every row with a drag handle and an overflow menu is noisy, and a per-row overflow contradicts [ADR-0031](./0031-row-edit-affordances.md), which keeps row editing on swipe / long-press.

The header holds three controls, all visible, none nested in a menu:

* **Two one-shot sort actions**, "Starttid" and "Alfabetisk", grouped under a "Sorter etter" label. Each rewrites all indices once, after which the order is manual again. Chronological order is the most common starting intent, so this gets a user most of the way there before they nudge individual rows.
* **A manual-reorder toggle** ("Omorganiser") at the trailing end, visually distinct from the one-shot sorts because it enters a sticky mode rather than firing once. Activating it becomes "Ferdig" to exit.

**Default view stays clean.** Each row shows only the number badge, title, subtitle and the expand chevron. Tap to open, swipe or long-press to edit, exactly as before.

**Reorder mode.** While the toggle is active the list is a `ReorderableListView`: the chevron is swapped for a trailing drag handle (`ReorderableDragStartListener`), and the row body's tap/swipe/long-press are suspended so gestures do not fight the drag. This is the familiar iOS/Material edit-mode pattern and keeps the handle on screen only while it is wanted.

**Accessibility comes for free.** `ReorderableListView` exposes "move up" / "move down" semantic actions on the drag handle, so keyboard and screen-reader users can reorder without a pointer and without a separate move menu.

Reordering and the sort actions both write the new indices through `saveExercise`, so the change persists immediately.

The list-header slot is scoped to the Øvelser segment for now but is a natural home for per-segment controls generally (the Poster filter, for example), should that consolidation be wanted later.

Considered and deferred: ordering controls in the global AppBar or an overflow menu (rejected above), long-press-to-drag without a handle (collides with long-press-to-edit and would force changing the ADR-0031 convention for this one list), a separate full-screen "Sorter øvelser" surface (adds a navigation step), editing the number inline to jump to a position, and "flytt til topp/bunn" shortcuts.

### Consequences

* Good: Exercise order is explicit, user-owned data, and the ADR-0034 number finally means something.
* Good: One ordering pattern across `Exercise`, `Station` and `RolePlay`.
* Good: Existing plans migrate to their current visible order with no surprise reshuffle.
* Good: A contextual list header keeps the controls discoverable and out of the global AppBar, the default rows stay clean, drag and screen-reader move actions both work, and a chronological sort bootstraps the order.
* Bad: A new field on `Exercise` plus codegen, a new list-header slot, and a reorder-mode toggle plus sort actions to build and localize.
* Bad: The `0`-collision migration heuristic is implicit. It is robust for real data but has to be covered by tests, including the edge case of a hand-edited file with partial indices.
* Bad: Reorder mode is extra view state to manage (enter/exit, suspend row gestures while active), though it avoids the gesture conflict a persistent in-row handle would create with swipe/long-press editing.

## Pros and cons of the options

### Option A — Explicit `index` field with multiple reorder mechanisms

* Good: First-class, user-controlled order; consistent with `Station`/`RolePlay`.
* Good: Deterministic migration preserves current order.
* Good: Reorder mode covers touch and pointer-free input while keeping the default list clean.
* Bad: New field, codegen, and a reorder mode plus sort actions.
* Bad: Migration heuristic and reorder-mode state need test coverage.

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
  * `lib/views/program_view.dart` — the Øvelser-segment list header (sort actions + reorder toggle) and the `ReorderableListView` reorder mode.
  * `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — strings for the move and sort actions.
</content>
