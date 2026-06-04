# Implement ADR-0035: explicit exercise ordering and reordering

You are working in the RingDrill repository. Implement ADR-0035 ("Give exercises an explicit order field and user-driven reordering") end-to-end. The ADR at `docs/adrs/0035-exercise-ordering.md` is the authoritative spec and is `accepted`. Read it in full before writing any code. It builds directly on ADR-0034 (auto-numbering), which is already implemented.

The change gives `Exercise` an explicit `index` field, sorts exercises on it instead of by name, migrates existing plans deterministically from their current name order, and ships three ways to change the order: drag-to-reorder, move up/down in the row overflow, and one-shot sort actions.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* **Run codegen, not regex.** Adding the `index` field to the `@freezed` `Exercise` class requires `make build`. Never hand-edit `*.freezed.dart` or `*.g.dart`.
* **CLI stays Flutter-free.** `lib/models/exercise.dart` is in the CLI's transitive import graph via `lib/data/drill_client.dart`. Do not add a Flutter import to it. Verify with `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli`.
* **Localize every user-visible string.** The move and sort action labels go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. If you do not know the Norwegian wording, copy the English and flag it in the final commit body.
* **Do not collide with edit affordances.** Per ADR-0031, swipe and long-press on a row mean "edit". The reorder drag handle must be a distinct hit target (a trailing handle driven by `ReorderableDragStartListener`), never the row body.
* **No raw English in widgets**, no new lint suppressions, match `dart format`.
* **Verify before claiming green.** `flutter analyze` and `flutter test` must pass, and each commit must leave the tree compiling.

## Commits

Conventional Commits with a scope. Allowed types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. The steps below are the commit boundaries, in order, all on one branch.

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognise, inspect it, then include it or stop and ask.
* Never close a step with `git stash` or `git restore`.
* The final Verification gate requires a clean tree.

## Scope

Six steps. Do them in order. Each step must compile on its own.

### Step 1. The `index` field on Exercise

Edit `lib/models/exercise.dart`. Add a non-null field to the `Exercise` factory, mirroring `Station` and `RolePlay`:

```dart
@Default(0) int index,
```

Run `make build`. Confirm `exercise.freezed.dart` and `exercise.g.dart` regenerated.

Files expected in this commit:

* `lib/models/exercise.dart`
* `lib/models/exercise.freezed.dart`
* `lib/models/exercise.g.dart`

Run `flutter analyze`. Run `git status` and confirm only the regenerated model files moved. Commit: `feat(models): add index field to Exercise for explicit ordering`.

### Step 2. Order by index, with deterministic migration

Edit `lib/data/program_repository.dart`. In `loadExercises`, replace the name sort with an index sort plus a normalisation step that migrates legacy plans:

* Read the items as today.
* Detect an invalid order: the set of `index` values is not exactly `{0 .. n-1}` — i.e. there are duplicates, gaps, or (the common legacy case) more than one exercise all at the default `0`.
* When invalid, sort the items by `name` (today's behaviour) and reassign `index` `0..n-1` in memory. This reproduces the current visible order for any pre-ADR-0035 plan.
* When valid, sort by `index`.
* Return the normalised list. This is a pure read-path transform — do not write back here. The normalised indices persist the next time any exercise is saved (Step 3).

Add `test/data/program_repository_test.dart` coverage (extend the existing file if present):

* A plan whose exercises all have `index == 0` (legacy) loads in name order with indices `0..n-1`.
* A plan with a valid permutation loads in index order, untouched.
* A hand-edited plan with duplicate or gapped indices is renormalised by name.
* A single-exercise plan with `index == 0` is treated as already valid (not a collision).

Files expected in this commit:

* `lib/data/program_repository.dart`
* `test/data/program_repository_test.dart`

Run `flutter analyze` and `flutter test test/data/program_repository_test.dart`. Run `git status`. Commit: `feat(data): order exercises by index with deterministic legacy migration`.

### Step 3. Index assignment and reorder persistence

Edit `lib/services/program_service.dart`:

* When creating a new exercise (`saveExercise` for an exercise not already in the program), assign `index = max(existing indices) + 1` so it appends at the end. Leave an edit of an existing exercise's index untouched.
* When copying or importing exercises into a program (`copyExercises` / the import path that calls `saveExercise` in a loop), renumber the incoming exercises into the target plan's sequence so indices stay a dense permutation.
* Add a `reorderExercises(List<String> orderedUuids)` method (or `moveExercise(String uuid, int newIndex)` — pick one and use it for all three UI mechanisms). It rewrites `index` by position and persists each changed exercise through the existing save path.

Add service-level tests for append-on-create and for `reorderExercises` producing a dense `0..n-1` permutation.

Files expected in this commit:

* `lib/services/program_service.dart`
* `test/services/program_service_test.dart` (extend if it exists)

Run `flutter analyze` and `flutter test test/services/`. Run `git status`. Commit: `feat(services): assign exercise index on create/copy/import and add reorder`.

### Step 4. Drag to reorder

Edit `lib/views/program_view.dart`. In the Øvelser segment, convert the exercises `ListView.builder` to a `ReorderableListView.builder`. Requirements:

* Each row needs a stable `Key` (use the exercise uuid).
* The drag affordance is an explicit trailing handle wrapped in `ReorderableDragStartListener`, not the row body. The row keeps its existing tap (open), swipe and long-press (edit) behaviour untouched, per ADR-0031.
* `onReorder` computes the new uuid order and calls the Step 3 `reorderExercises` / `moveExercise`, then refreshes the list (`setState(_initExercises)` or the existing refresh path).
* The exercise-number badge added in ADR-0034 must update to reflect the new order after a reorder.

If the wide-screen master/detail layout (ADR-0030) renders its own exercises list, apply the same treatment there or, if dragging in the narrow master column is impractical, rely on the Step 5 move actions there and document the choice in a code comment.

Files expected in this commit:

* `lib/views/program_view.dart`
* any caller touched to thread the reorder callback

Run `flutter analyze`. Run `git status`. Commit: `feat(views): drag to reorder exercises in the Øvelser segment`.

### Step 5. Move up/down and one-shot sort actions

Edit `lib/views/program_view.dart` again:

* Add "Flytt opp" / "Flytt ned" to each exercise row's overflow menu, disabled at the ends. Each calls the Step 3 reorder method. This is the keyboard- and screen-reader-reachable path and the precise option in the wide master column.
* Add "Sorter etter starttid" and "Sorter alfabetisk" to the Øvelser segment AppBar overflow. Each rewrites all indices once (by `startTime`, then by `name`) via the reorder method, after which the order is manual again.

Add the l10n keys for all four actions to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together.

Files expected in this commit:

* `lib/views/program_view.dart`
* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`

Run `flutter analyze` and `flutter test`. Run `git status`. Commit: `feat(views): add move up/down and one-shot sort actions for exercises`.

### Step 6. Widget tests and verification pass

Add `test/views/program_view_exercise_order_test.dart` (or extend an existing program-view test):

* Reordering via the move-down action persists the new order and updates the rendered exercise numbers.
* A one-shot "sort by start time" reorders rows chronologically and renumbers them.
* The drag callback (`onReorder`) maps a from/to index pair to the correct persisted order.

Files expected in this commit:

* `test/views/program_view_exercise_order_test.dart`

Run `flutter analyze` and the full `flutter test`. Run `git status`. Commit: `test(views): cover exercise reordering and renumbering`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures.
3. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds — confirms no Flutter import leaked into `exercise.dart`.
4. `rg "a.name.compareTo\(b.name\)" lib/data/program_repository.dart` prints nothing — the exercise name sort is gone (other entities may still sort by their own keys).
5. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean` and `git ls-files --others --exclude-standard` prints nothing.
6. **Diff sanity.** `git log --stat origin/main..HEAD` — walk every changed path and confirm each is in the intended commit.
7. Manual QA matrix (record the result in the final commit body):
   * Open a plan saved before this change. Confirm the exercise order and numbers are unchanged from before, i.e. the migration preserved the old name order.
   * Drag an exercise to a new position. Confirm the number badges renumber and the order survives a navigate-away-and-back.
   * Use "Flytt opp"/"Flytt ned" and confirm they match the drag result and are disabled at the ends.
   * Run "Sorter etter starttid" and "Sorter alfabetisk" and confirm each renumbers correctly, then that individual rows can still be nudged afterwards.
   * Confirm swipe-to-edit and long-press-to-edit still work on a row and never trigger a reorder.

## Deliverables

A series of six Conventional Commits as outlined, all on one branch, clean tree at the end. The final commit body includes the manual QA matrix and a note on any open question the implementation answered (in particular, how reordering behaves in the wide-screen master column).

ADR-0035 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR unless something forces a structural deviation.
