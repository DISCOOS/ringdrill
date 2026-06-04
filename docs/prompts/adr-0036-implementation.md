# Implement ADR-0036: shared reorder section and station reordering

You are working in the RingDrill repository. Implement ADR-0036 ("Extract a shared reorder section and let stations be reordered in the Stations segment and coordinator") end-to-end. The ADR at `docs/adrs/0036-shared-reorder-and-station-ordering.md` is the authoritative spec and is `accepted`. Read it in full first. It builds on ADR-0035 (exercise reorder), which is implemented and whose reorder UI lives inline in `program_view.dart`.

The change extracts that inline reorder logic into a reusable widget, then uses it to add station reordering in the Stations segment and the coordinator, and brings the coordinator station rows in line with the Stations segment (number badge).

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

* **Run codegen, not regex.** No model field changes are expected (`Station` and `RolePlay` already have `index`). If you do change a `@freezed` class, run `make build`; never hand-edit generated files.
* **Localize every user-visible string.** Reuse the existing l10n keys where possible (`exerciseSortBy` → "Order", `exerciseReorderMode`/`exerciseReorderDone`). If a station surface needs its own label, add the key to `app_en.arb` and `app_nb.arb` together. Norwegian only in the `nb` ARB values; English everywhere else (prose, symbols, this prompt).
* **Do not collide with edit affordances.** Reorder stays a dedicated mode with a drag handle; rows keep swipe / long-press for edit (ADR-0031). No per-row overflow.
* **Preserve the deferred-commit behaviour.** Drags mutate an in-memory working copy; the order persists once on leaving reorder mode, shown synchronously from the draft. Do not regress to per-drop persistence (that caused the snap-back bug).
* **Station order drives the rotation.** Reordering stations rewrites `Station.index`, which `ExerciseX.teamIndex` / `stationIndex` and the schedule depend on. Reorder must remap every index-keyed reference in one write and must be unavailable while an exercise is running.
* **Verify before claiming green.** `flutter analyze` and `flutter test` must pass; each commit must compile.

## Commits

Conventional Commits with a scope (`feat`, `fix`, `refactor`, `chore`, `docs`, `test`). The steps below are the commit boundaries, in order, on one branch.

### Commit discipline (non-negotiable)

* After every step run `git status` and `git diff --stat`; confirm no untracked or unstaged paths before claiming the step done. A widget extraction must show the moved code removed from `program_view.dart`, not duplicated.
* Each step lists the **files expected in that commit**. Include every listed path; investigate anything unexpected before committing.
* No `git stash` / `git restore` to hide working-tree state. The final gate requires a clean tree.

## Scope

Five steps, in order. Each must compile on its own.

### Step 1. Extract the shared `ReorderableSection` widget

Create `lib/views/widgets/reorderable_section.dart`. It owns everything list-agnostic that currently lives inline in `program_view.dart`'s `_ExercisesListHeader` and the default/reorder list builders, including the ADR-0035 deferred-commit logic.

Suggested API (adjust as the refactor demands, but keep it host-driven):

```dart
class ReorderableSection<T> extends StatefulWidget {
  const ReorderableSection({
    super.key,
    required this.items,
    required this.keyOf,            // stable identity per item (uuid / index)
    required this.itemBuilder,      // (context, item, position, reordering, dragHandle)
    required this.onCommitReorder,  // (List<T> newOrder) — fired once on leaving reorder mode
    this.sortActions = const [],    // each: label + VoidCallback
    required this.orderLabel,       // left anchor text, e.g. "Order"
    this.enabled = true,            // false hides the reorder toggle (e.g. while running)
  });
  // ...
}
```

It must:

* Render the header: the muted order anchor label on the left, the optional one-shot sort actions as flat `TextButton`s, and the reorder toggle as an `OutlinedButton.icon` (`Icons.swap_vert`, rounded-rectangle shape — not a stadium) that becomes a `FilledButton.tonal` "Done" while active. Left inset matching the surrounding layout. Hide the whole strip when `items.length < 2`; hide just the reorder toggle when `enabled` is false.
* Own the reorder-mode flag and an in-memory working copy of `items`. In default mode render a plain list; in reorder mode render a `ReorderableListView` with `buildDefaultDragHandles: false` and a trailing `ReorderableDragStartListener` handle supplied to `itemBuilder`. Suspend row body gestures in reorder mode (the host's `itemBuilder` reads the `reordering` flag).
* Defer commit: drags reorder the working copy synchronously (no persistence); on leaving reorder mode call `onCommitReorder(newOrder)` once. Show the committed order from the working copy synchronously so it does not wait on the host's async save.

Refactor the Exercises segment in `program_view.dart` onto it: remove `_ExercisesListHeader`, the `_reorderDraft` field, `_onReorderModeChanged`, and the bespoke reorder list builder; pass exercises as `items`, build the `Dismissible` + `ExerciseCard` (default) and the drag-handle variant (reorder) from `itemBuilder`, wire `sortActions` to the start-time / alphabetical sorts, and `onCommitReorder` to `reorderExercises`. Exercise behaviour must be unchanged: same header, same deferred commit, badges renumber live during a drag.

Files expected in this commit:

* `lib/views/widgets/reorderable_section.dart`
* `lib/views/program_view.dart`

Run `flutter analyze` and `flutter test`. Run `git status`. Commit: `refactor(views): extract ReorderableSection from the exercises list`.

### Step 2. Station reorder in the service, with reference remapping

Add `reorderStations` to `lib/services/program_service.dart`. Given an exercise and the new station order (expressed as the stations' old indices in their new sequence), it must, in one persisted change:

* Reassign `Station.index` to the new positions and store the reordered `stations` list on the exercise.
* Remap `RolePlay.stationIndex` for every markers attached to a reordered station, using the old→new permutation, so each marker stays on its station ("markers follow their station").
* Recompute the schedule / rotation for the new order via the existing `generateSchedule` path.
* Persist the exercise and every changed `RolePlay`, then emit the refresh event.

Add `test/services/program_service_test.dart` coverage:

* Reordering stations writes a dense `0..n-1` `index` permutation in the new order.
* A `RolePlay` whose `stationIndex` pointed at a moved station ends up pointing at that same station's new index (not a different station).
* A `RolePlay` with `stationIndex == null` is left untouched.

Files expected in this commit:

* `lib/services/program_service.dart`
* `test/services/program_service_test.dart`

Run `flutter analyze` and `flutter test test/services/`. Run `git status`. Commit: `feat(services): reorder stations and remap dependent references`.

### Step 3. Station reorder in the Stations segment

Use `ReorderableSection` in `lib/views/station_list_view.dart` so the Stations segment reorders stations the same way the Exercises segment reorders exercises. The default rows keep their current badge / swipe / long-press behaviour; reorder mode shows the drag handle. `onCommitReorder` calls the Step 2 `reorderStations`. Stations need only the reorder toggle — no one-shot sort actions unless one reads cleanly (alphabetical is the only candidate; start time is not a station property).

If the segment currently filters to a single exercise, reorder applies within that exercise's stations; decide and document how reorder behaves when the list spans multiple exercises (most likely: reorder is only offered when scoped to one exercise, since cross-exercise station order is meaningless).

Files expected in this commit:

* `lib/views/station_list_view.dart`
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` (only if a new label is needed)

Run `flutter analyze` and `flutter test`. Run `git status`. Commit: `feat(views): reorder stations in the Stations segment`.

### Step 4. Coordinator: station badge and gated reorder

In `lib/views/coordinator_screen.dart`:

* Add the `StationNumberBadge` to the station rows' `leading` slot, fed by `Numbering.station(program.stationNumberFormat, exerciseNumber: …, stationIndex: station.index)`, so a station reads identically to the Stations segment. Resolve the owning exercise's number the same way the Stations segment does.
* Use `ReorderableSection` for the station list, with `enabled` wired to the live state so the reorder toggle is hidden (or disabled) whenever the exercise is running. `onCommitReorder` calls `reorderStations`. When not running, reorder works as in the Stations segment.

Files expected in this commit:

* `lib/views/coordinator_screen.dart`

Run `flutter analyze` and `flutter test`. Run `git status`. Commit: `feat(views): add the station badge and gated reorder to the coordinator`.

### Step 5. Tests and verification pass

Add or extend widget tests:

* `ReorderableSection`: entering reorder mode shows handles and hides one-shot affordances per `enabled`; a drag reorders the working copy and fires `onCommitReorder` only on leaving the mode, not per drop; `enabled: false` hides the reorder toggle.
* Station reorder through the Stations segment persists the new order and renumbers the badges; markers follow their station.
* Coordinator: reorder toggle is absent while running and present when stopped; the station badge renders.

Files expected in this commit:

* `test/views/reorderable_section_test.dart`
* any extended view tests

Run `flutter analyze` and the full `flutter test`. Run `git status`. Commit: `test(views): cover the shared reorder section and station reordering`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures.
3. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds — the new widget is UI-only and must not leak into the CLI graph.
4. `rg "_ExercisesListHeader|_reorderDraft" lib/` returns nothing — the inline reorder code is gone, not duplicated.
5. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean` and `git ls-files --others --exclude-standard` prints nothing.
6. **Diff sanity.** `git log --stat origin/main..HEAD` — confirm the widget extraction shows code removed from `program_view.dart`.
7. Manual QA matrix (record in the final commit body):
   * Exercises still reorder exactly as before (deferred commit, no snap-back, no revert on Done, live badge renumbering).
   * In the Stations segment, reorder a station; confirm the badges renumber, a marker attached to that station still points at it, and the order survives navigate-away-and-back.
   * In the coordinator while stopped, reorder stations and confirm the rotation/schedule reflects the new order; while running, confirm the reorder toggle is gone and the station badge is shown.

## Deliverables

Five Conventional Commits as outlined, one branch, clean tree at the end. The final commit body includes the manual QA matrix and a note on the resolved open question (how reorder behaves when the Stations segment spans multiple exercises).

ADR-0036 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR unless something forces a structural deviation.
