# Codex CLI prompt: Consolidate plan and exercise actions

Copy everything below the line into Codex CLI. The prompt is self-contained and references files inside this repo.

---

You are working in the RingDrill repository. Consolidate the plan-related UI actions per the design below. Read `docs/adrs/0008-persistent-program-library-and-catalog.md` for the existing data and service contracts. Do **not** change the data layer, the repository or the `ProgramService` public surface unless this prompt explicitly says so. Follow `AGENTS.md` (codegen, l10n, mobile-safe imports, no Sentry outside the consent gate, no Flutter imports in the CLI path).

## Goal

Eliminate the confusion between today's "Open program" (install file as new plan, activate) and "Import program" (merge selected exercises from file into the active plan). Separate them into two named modals with verbs that match user intent. Remove the popup menu in `ProgramView` entirely. Move active-plan actions into the drawer.

## Modal A: "Open plan..." (existing modal, additions)

The modal already exists with tabs "My plans" and "Catalog" (see `lib/views/library_view.dart`). Add two `IconButton`s in the dialog header:

* **New plan** (`Icons.add_circle_outline`). On press, show a small dialog that prompts for a plan name (single `TextField`, "Create" / "Cancel"). On Create, call `ProgramService.createProgram(name: ...)`, then `setActive(uuid)`, then close Modal A. Block when `ExerciseService.isStarted`, with the existing `libraryCannotSwitchRunning` SnackBar.
* **From file...** (`Icons.upload_file`). On press, open the native file picker via the same platform-conditional path used today by the legacy "open" action (`OpenFileWidget` / `shared_file_channel`). After a `.drill` is picked, call `ProgramService.installFromFile(file, activate: true)`, then close Modal A. Block when `ExerciseService.isStarted`.

Localization keys (add to `lib/l10n/app_en.arb` and `app_nb.arb`):

* `newPlanAction` = "New plan" / "Ny plan"
* `newPlanNamePrompt` = "Name your new plan" / "Gi den nye planen et navn"
* `create` = "Create" / "Opprett"
* `fromFileAction` = "From file" / "Fra fil"

## Modal B: "Add exercises from..." (new modal)

Create `lib/views/add_exercises_dialog.dart` with:

```dart
Future<void> showAddExercisesDialog(BuildContext context);
```

Mobile uses `showModalBottomSheet` with `isScrollControlled: true`, drag handle, rounded top — same shape as Modal A's mobile presentation. Wide screens use `showDialog` with a constrained `Dialog` body, matching Modal A's desktop presentation.

`TabBar` with two tabs:

* **From file**: a single full-width `FilledButton` "Pick file..." that opens the native file picker. After a `.drill` is picked, read it via `DrillFile.fromFile`/`fromBytes`, then run the merge flow below using the file's `Program.exercises` as the source.
* **From another of my plans**: a `ListView` of all locally persisted programs from `ProgramService.listPrograms()` **except the active one**. Each row shows the program name, source badge and exercise count. Tap a row to run the merge flow below using `programService.loadProgram(uuid).exercises` as the source.

### Merge flow

Implemented as a shared helper inside `lib/views/add_exercises_dialog.dart`:

```dart
Future<void> _mergeIntoActivePlan(BuildContext context, Program source);
```

The `source` is a `Program` (either parsed from a `.drill` file or loaded from another local plan) so we have access to both its `exercises` and `teams`.

Steps:

1. Show the existing `ProgramPageControllerBase.selectExercises` bottom sheet to let the user pick which incoming exercises to merge. Use the existing title "Import program" (`localizations.importProgram`) for now; do not rename in this change set.
2. Determine the teams that should be merged alongside the selected exercises. For now, copy **all** teams from the source whose `uuid` is referenced by at least one selected exercise (via the exercise's team-index relationship, or if that is not directly modeled, simply copy all teams from the source — match the behavior of today's `importProgram` which copies every team).
3. Build a projected `Program` representing the active plan after the merge (active exercises union/overwrite with selected incoming exercises keyed by `uuid`; same for teams).
4. Compute `ProgramDiff` between the active plan and the projected post-merge plan using `diffPrograms` from `lib/models/program.dart`.
5. If `diff.modifiedExercises` **or** `diff.modifiedTeams` is non-empty (any collision), show a slim confirm dialog. Title: `confirmChangesTitle`. Body: the existing `_DiffGroup` widget showing exercises *and* teams adds/removes/modifies. **Extract `_DiffGroup` from `lib/views/catalog_conflict_dialog.dart` into a new file `lib/views/program_diff_widgets.dart`** so both dialogs can share it. Buttons: "Cancel" and "Apply" (`apply` key). Apply overwrites colliding exercises and teams by `uuid`.
6. If neither has modifications (only additions), apply silently.
7. On Apply, call `ProgramService.importProgram(localizations, file, onSelect: ...)` for the file case. For the "From another of my plans" case, add a new method `ProgramService.mergeFromProgram(localizations, source, selectedUuids)` that mirrors `importProgram` but takes a `Program` directly instead of a `DrillFile`. Both paths copy exercises and the relevant teams to the active plan via `_repo.saveExercise` and `_repo.saveTeam`.

### Behavior in `ProgramService.importProgram`

Keep today's behavior of copying teams alongside exercises. Sessions are **not** copied (they are operational state). Add the symmetric `mergeFromProgram` method for the "From another of my plans" case:

```dart
Future<Program?> mergeFromProgram(
  AppLocalizations localizations,
  Program source,
  List<String> selectedExerciseUuids,
);
```

Implementation mirrors `importProgram` but iterates the source's exercises and teams directly. Emits `ProgramEvent.imported` with the active plan and no `DrillFile`.

Localization keys (add to both ARB files):

* `addExercisesAction` = "Add exercises from..." / "Legg til øvelser fra..."
* `addFromFile` = "From file" / "Fra fil"
* `addFromAnotherPlan` = "From another of my plans" / "Fra en annen av mine planer"
* `pickFile` = "Pick file..." / "Velg fil..."
* `confirmChangesTitle` = "Confirm changes" / "Bekreft endringer"
* `apply` = "Apply" / "Bruk"
* `noOtherLocalPlans` = "No other local plans yet" / "Ingen andre lokale planer enda"

Modal B never changes the active plan. It only mutates the active plan's exercise list.

## Drawer (`_buildDrawer` in `lib/views/main_screen.dart`)

Replace the current content with these entries, in order, with `Divider`s where shown:

```
Open plan...                -> opens Modal A
New plan                    -> name prompt + createProgram + setActive (same as Modal A header New plan)
Add exercises from...       -> opens Modal B
---
Share active plan           -> existing share() flow
Send to...                  -> existing sendTo() flow
Export as .drill            -> existing export() flow
---
Settings
About
Feedback                    -> showFeedbackSheet(context, ...)
```

Disable "New plan", "Add exercises from...", "Share active plan", "Send to...", "Export as .drill" with tooltip `requiresActivePlan` ("Open or create a plan first" / "Åpne eller opprett en plan først") when `ProgramService.activeProgramUuid == null`. "Open plan..." always works.

The drawer remains in the existing position (mobile: hamburger from AppBar; wide: opened via the NavigationRail leading button). No layout changes beyond the new list items.

Localization keys (add):

* `requiresActivePlan` = "Open or create a plan first" / "Åpne eller opprett en plan først"
* `shareActivePlan` = "Share active plan" / "Del aktiv plan"
* `sendToAction` = "Send to..." / "Send til..."
* `exportAsDrill` = "Export as .drill" / "Eksporter som .drill"

## ProgramView cleanup

In `lib/views/program_view.dart`:

* Remove the `PopupMenuButton` returned by `ProgramPageControllerBase.buildActions`. `buildActions` returns `null` after the change.
* Remove the `ProgramPageAction` enum and the abstract `open`/`save`/`sendTo`/`share` methods on `ProgramPageControllerBase` if they become unused after Step "Active plan actions helper". Keep `selectExercises` and `_promptFileName` as static helpers — Modal B and the drawer entries still call them.
* `title(BuildContext context)` continues to return the active plan name or the localized fallback.
* The AppBar tap on the plan name continues to open Modal A.

## Active plan actions helper

Create `lib/views/active_plan_actions.dart` exposing free async functions:

```dart
Future<void> openPlan(BuildContext context);           // opens Modal A
Future<void> createNewPlan(BuildContext context);      // name prompt + createProgram + setActive
Future<void> addExercises(BuildContext context);       // opens Modal B
Future<void> shareActivePlan(BuildContext context);    // existing share flow
Future<void> sendActivePlanTo(BuildContext context);   // existing sendTo flow
Future<void> exportActivePlan(BuildContext context);   // existing export flow
```

Move the current `_handleMenuAction` switch arms from `ProgramView` into these helpers. The platform-specific `ProgramPageController` files (`lib/web/program_page_controller.dart` and `lib/views/program_page_controller.dart`) keep only their existing file open/save platform branches. Expose those branches as static helpers (e.g. `static Future<DrillFile?> pickOpenFile(...)`, `static Future<bool> saveDrillFile(...)`) that the new free functions can call via the existing conditional import. Do **not** introduce `package:web` or `dart:html` outside `lib/web/`.

## Tests

* Drop or rewrite any test that exercised `ProgramView`'s popup menu.
* Add `test/add_exercises_merge_test.dart` (pure-Dart): construct an active `Program` with two exercises and two teams, an incoming `Program` with three exercises (one collision on `uuid`, two new) and two teams (one collision, one new), compute `diffPrograms` via the same projection logic Modal B will use, assert one `modifiedExercises` and two `addedExercises`, one `modifiedTeams` and one `addedTeams`. Then simulate Apply by overwriting by `uuid` and assert the resulting lists contain the union with the overridden versions.
* Keep `test/program_repository_migration_test.dart` as is. It is unrelated.

## Out of scope

* Catalog filtering, multi-plan-in-runtime, switching the storage backend.
* No backend changes.
* The catalog conflict dialog (`lib/views/catalog_conflict_dialog.dart`) stays as is for `refreshCatalogItem`. Only `_DiffGroup` is extracted for reuse.

## Verification

Run `make build`, `flutter analyze`, `flutter test`. `test/widget_test.dart` is known-broken; ignore it.

## Deliverable

A single change set that:

* Adds the two header actions to Modal A.
* Adds `lib/views/add_exercises_dialog.dart` and `lib/views/program_diff_widgets.dart`.
* Adds `lib/views/active_plan_actions.dart`.
* Rewrites the drawer in `lib/views/main_screen.dart`.
* Removes the `ProgramView` popup menu and the `ProgramPageAction` enum.
* Keeps team-copy in `ProgramService.importProgram` and adds the symmetric `mergeFromProgram` method.
* Adds the localization keys to `lib/l10n/app_en.arb` and `app_nb.arb`.
* Adds the merge test.
* Passes analyze + tests (modulo the known-broken widget test).
