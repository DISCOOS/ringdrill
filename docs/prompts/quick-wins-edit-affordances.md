# Prompt: Quick-wins for edit affordances across Exercises, Stations, and Teams

You are working in RingDrill (Flutter, repo root `/Users/kengu/git/discoos/ringdrill`). Read `AGENTS.md` and `CLAUDE.md` first. No ADR is required for this work — these are pure UI affordances layered on top of existing patterns, with no new dependencies, no schema changes, and no architectural shifts.

## Goal

Reduce the click count required to edit a station or a team from within an active exercise, and make teams editable at all. To do this:

1. Expose a public `ProgramService.saveTeam` so callers outside the service can persist team edits.
2. Add a `TeamFormScreen` so a team's name, member count, and position can be edited (today there is no edit path for teams).
3. Expose editing through left-swipe (Dismissible) and a long-press gesture on rows, mirroring what is already in place on the Stations tab and the RolePlays tab.

The pattern must mirror what is already established in `lib/views/station_list_view.dart` (Dismissible + `confirmDismiss` → form, plus `onOpen` → ContextSheet for read-only view). Do not introduce new widgets or abstractions.

## Row edit-affordance convention

This PR is the first to land under [ADR-0031](../adrs/0031-row-edit-affordances.md): row edit affordances are `Dismissible(endToStart, confirmDismiss: ...)` swipe and/or `onLongPress`. Do **not** place a pencil `IconButton` inside `ListTile`, `ExpansionTile`, `ExpandableTile`, or any other row widget. `Icons.edit` is reserved for `AppBar.actions` and overflow menus on detail screens.

Implementation reminders (full rationale and site list lives in the ADR):

* For `ListTile`, use the built-in `onLongPress` parameter directly.
* For `ExpandableTile` rows, pass the handler through its built-in `onLongPress` parameter. The shared widget owns the row `InkWell`, so tap-to-expand still fires without an outer gesture wrapper.
* The same handler is used for both swipe and long-press. The disabled-state rule from `station_screen.dart:117-128` (`_isStarted` guard + `stopExerciseFirst` snackbar) applies to long-press as well.

## File-format check (already done, do not re-verify)

The `.drill` archive already round-trips `Team` objects: `lib/data/drill_file.dart:115-117` reads `teams/<uuid>.json` via `Team.fromJson`, and `:396-401` writes them via `Team.toJson()`. The `Team` model (`lib/models/team.dart`) already has `name`, `numberOfMembers`, and `position` as serializable fields. No schema bump, no new file entries, no migration needed.

## Hard constraints

* All user-visible strings go through `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. Both files must be updated together. Norwegian UI uses "post" for Station and "Lag" for Team. English strings use "station" and "team". Use the existing `editStation` / `editExercise` entries as the reference format.
* Run `make build` after any change to a `@freezed` class, a `@JsonValue` enum, or the `.arb` files. Localization will be regenerated automatically the next time `flutter run` / `flutter test` runs, so the build step is sufficient.
* `flutter analyze` and `flutter test` must both be clean before each commit. If `test/widget_test.dart` (the old counter-template test) is still removed, a clean test run is the baseline. If a test breaks, fix or flag — do not silently skip.
* Do not touch generated code (`*.freezed.dart`, `*.g.dart`, `app_localizations*.dart`).
* The master/detail conventions from ADR-0030 apply: forms open via `openFormSurface<T>(context, builder: ...)`, not `Navigator.push` directly. See `lib/views/shell/open_form_surface.dart` for the signature.
* Preserve the "disable editing while the exercise is running" behaviour from `station_screen.dart:122` (the `_isStarted` guard). The same rule applies to every new affordance you add.

## Commit discipline

Each of the seven steps below is one commit. After every commit, `git status` must be clean — no untracked or modified files left behind. Each commit body must list the files touched explicitly. Commit message format: conventional commits (`feat(...)`, `refactor(...)`, etc.). Do not bundle steps into a single commit.

After every commit: run `flutter analyze && flutter test`. If something breaks, fix it in the same commit (amend), not in a follow-up.

---

## Step 1 — Public `ProgramService.saveTeam` + `ProgramEvent.teamSaved`

Today `ProgramService` calls `_repo.saveTeam(...)` only from internal import/merge paths (`program_service.dart:328, 356`). There is no public method for callers outside the service. Without one, the `TeamFormScreen` caller in Step 3 has no clean way to persist its result.

**Files touched**

* `lib/services/program_service.dart`

**Content**

1. Extend `enum ProgramEventType` (around line 24-29) with a new `teamSaved` entry. Place it after `exerciseDeleted` to keep entity events grouped.
2. Extend the `ProgramEvent` class (around line 74-103):
   * Add a `final Team? team` field next to `final Exercise? exercise`.
   * Extend the canonical constructor to accept `{this.team}` alongside `this.file`/`this.exercise`.
   * Add a factory: `factory ProgramEvent.teamSaved(Program program, Team team) => ProgramEvent(ProgramEventType.teamSaved, program, team: team);`
3. Add the public wrapper to `ProgramService`, mirroring `saveExercise` (lines 263-274):

   ```dart
   Future<void> saveTeam(
     AppLocalizations localizations,
     Team team,
   ) async {
     await _ensureActiveProgram(localizations.defaultPlanName);
     await _repo.saveTeam(team);
     final program = activeProgram;
     if (program != null) {
       _controller.add(ProgramEvent.teamSaved(program, team));
     }
   }
   ```

Import `package:ringdrill/models/team.dart` if it is not already imported by this file.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* `grep -n "saveTeam" lib/services/program_service.dart` shows the new public method plus the two existing internal call sites.
* Confirm the new event factory is reachable from `lib/views/`: a quick `grep -n "ProgramEvent.teamSaved" lib/` should match nothing yet (it will be used in Step 3).

**Commit**: `feat(program-service): public saveTeam wrapper + teamSaved event`

---

## Step 2 — `TeamFormScreen` + localization

**Files touched**

* New: `lib/views/team_form_screen.dart`
* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`

**Content**

Create `TeamFormScreen extends StatefulWidget`, following the pattern in `lib/views/roleplay_form_screen.dart`. Fields:

* Required: `name` (text, validator: must not be empty)
* Optional: `numberOfMembers` (number, must be >= 0 when set)
* Optional: `position` via `PositionFormField` (see usage in `roleplay_form_screen.dart` and `station_form_screen.dart`)

Constructor: `TeamFormScreen({required Team team})`. The screen pops with the updated `Team` via `Navigator.pop(context, updated)` on save, or `null` on cancel. Cancel button lives in `leading` (`Icons.close`); save lives in `actions` as `ElevatedButton`. Title: `editTeam`.

Persistence stays with the caller, following the existing pattern from `_openStationForm` in `station_list_view.dart:400-422`. The caller in Step 3 will use the new `ProgramService.saveTeam` from Step 1.

**New localization keys** (both `.arb` files):

* `editTeam` → "Endre lag" / "Edit Team"
* `teamName` → "Navn på lag" / "Team name"
* `numberOfMembers` → "Antall medlemmer" / "Number of members"

First check whether these already exist (`grep -n teamName lib/l10n/`). Do not register duplicates.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual smoke check: open the form via a throwaway button or a Dart test that instantiates the widget, and confirm the validator fires on empty name.

**Commit**: `feat(team): add TeamFormScreen for editing team name, members, position`

---

## Step 3 — Edit affordances on the Teams tab

**Files touched**

* `lib/views/teams_view.dart`
* `lib/views/team_exercise_screen.dart`

**Content**

In `teams_view.dart`:

* Wrap each team `Card` / `ListTile` (around lines 62-86) in a `Dismissible(direction: DismissDirection.endToStart, confirmDismiss: ...)`, mirroring `station_list_view.dart:262-311`. The background should display `Icons.edit` + `localizations.editTeam` on the trailing edge, painted with `colorScheme.secondaryContainer`.
* `confirmDismiss` calls a private `_openTeamForm(Team team)` that opens `openFormSurface<Team>(context, builder: (_) => TeamFormScreen(team: team))`, and on a non-null return calls `ProgramService().saveTeam(localizations, updated)` (the public wrapper added in Step 1). Always return `false` from `confirmDismiss` (the row must not be removed).
* Set `ListTile.onLongPress` to the same `_openTeamForm` handler. The existing `onTap` (which opens the `TeamSheetTarget` ContextSheet) stays. Per the project rule, do **not** add a pencil `IconButton` to the row.

In `team_exercise_screen.dart`:

* Add an `IconButton(Icons.edit)` to `AppBar.actions` (currently lines 39-57). Mirror the layout from `station_screen.dart:117-128`, including the disable rule when `ExerciseService().isStarted` is true. Tooltip when enabled: `localizations.editTeam`. Tooltip when disabled: `localizations.stopExerciseFirst(widget.exercise.name)`.
* `onPressed` resolves the `Team` via `ProgramService().loadTeams()[widget.teamIndex]` and opens the same form. On a non-null return, call `ProgramService().saveTeam(localizations, updated)` and `setState({})`.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual: swipe a team row → form → save; long-press a team row → form → save; tap the pencil in the detail sheet's app bar → form → save. Confirm the name updates in the list and in the sheet title without a tab switch.

**Commit**: `feat(teams): edit team via swipe, long-press, and detail-sheet action`

---

## Step 4 — Swipe-to-edit on station rows inside CoordinatorScreen

**Files touched**

* `lib/views/coordinator_screen.dart`

**Content**

In `_buildStationList` (around lines 1000-1060, before the `_buildStationDetail` call):

* Wrap each station `ExpandableTile` row in `Dismissible(direction: DismissDirection.endToStart, confirmDismiss: ...)`. Use `ValueKey('coordinator-station-dismiss-$stationIndex')` to avoid collision with the tile's own key.
* Background: mirror `station_list_view.dart:268-284`.
* `confirmDismiss` calls a new private `_editStation(int stationIndex)` that:
  1. Returns immediately if `_isStarted` is `true`, surfacing a snackbar with `localizations.stopExerciseFirst(_exercise!.name)`.
  2. Opens `openFormSurface<Station>(context, builder: (_) => StationFormScreen(station: _exercise!.stations[stationIndex], markers: _programService.getLocations().toMarkerSpecs()))`.
  3. On a non-null return, persists using the same pattern as `station_list_view.dart:412-422`: build a new `stations` list, swap the entry, then call `_programService.saveExercise(localizations, updatedExercise)`. Reuse any existing helper in `program_service` if one is already there.
* Always return `false` from `confirmDismiss`.

Note: the Dismissible must wrap *around* the `ExpandableTile` so the swipe gesture does not interfere with the tile's tap-to-expand behaviour.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual: open an exercise (tap its card from the Exercises tab), swipe a station row in the station list, confirm the form opens, saving updates the row inline, and no tab switch occurs.
* Check that swipe is inert while the exercise is running (start it, attempt swipe, confirm snackbar and no form).

**Commit**: `feat(coordinator): swipe-to-edit station rows in exercise overview`

---

## Step 5 — Long-press to edit station and team rows inside CoordinatorScreen

**Files touched**

* `lib/views/coordinator_screen.dart`

**Content**

For both `_buildStationList` (around lines 1000-1060) and `_buildTeamList` (around lines 1121-1269), the per-row affordance is a long-press gesture passed through `ExpandableTile.onLongPress`. Per the project rule, do **not** add a pencil `IconButton` inside the tile.

Implementation pattern (apply to both lists):

```dart
ExpandableTile(
  onLongPress: () => _editStation(stationIndex), // or _editTeam(teamIndex)
  // existing tile content unchanged
  ...
)
```

`ExpandableTile` owns the row `InkWell`, so the built-in callback handles the hold gesture while a regular tap still routes through to expansion.

For station rows: reuse the `_editStation` handler introduced in Step 4. The Step 4 swipe and the long-press call the same code path.

For team rows: add a new private `_editTeam(int teamIndex)` that:

1. Resolves the team via `_programService.loadTeams()[teamIndex]`.
2. If `_isStarted`, surfaces `localizations.stopExerciseFirst(_exercise!.name)` as a snackbar and returns without opening the form (mirrors `_editStation`).
3. Opens `openFormSurface<Team>(context, builder: (_) => TeamFormScreen(team: team))`.
4. On a non-null return, calls `_programService.saveTeam(localizations, updated)` and `setState({})`.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual: open an exercise; long-press a station row → form opens directly (no intermediate sheet); long-press a team row → form opens directly. Confirm that a regular tap on the row still expands the tile.
* Long-press while the exercise is running surfaces the `stopExerciseFirst` snackbar and does not open the form.

**Commit**: `feat(coordinator): long-press to edit station and team rows`

---

## Step 6 — Align exercise card swipe chrome and add long-press editing

The exercise card in `program_view.dart` already has a `Dismissible(endToStart)` that opens `ExerciseFormScreen`, but it was added before ADR-0031 and uses different chrome from the rest of the listings: `colorScheme.primary` background with no label, versus the `colorScheme.secondaryContainer` + label + icon pattern used in `station_list_view.dart`, `roleplays_view.dart`, and the new `teams_view.dart`. It also lacks the corresponding long-press edit path. Bring both behaviors in line.

**Files touched**

* `lib/views/program_view.dart`
* `test/views/widgets/exercise_card_test.dart`

**Content**

In `program_view.dart` (around lines 99-110), replace the `background` `Container` with the same `Row` layout used by `station_list_view.dart:268-284`:

* `color`: `colorScheme.secondaryContainer`
* `alignment`: `Alignment.centerRight`
* `padding`: `EdgeInsets.symmetric(horizontal: 20)`
* Child: `Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(localizations.editExercise, style: TextStyle(color: colorScheme.onSecondaryContainer)), const SizedBox(width: 8), Icon(Icons.edit, color: colorScheme.onSecondaryContainer)])`

`localizations.editExercise` already exists in both `app_en.arb` ("Edit Exercise") and `app_nb.arb` ("Endre øvelse"). Do not add a new l10n key.

Extract the existing `confirmDismiss` form flow into one private `_openExerciseForm(...)` helper. Pass that same helper to `ExerciseCard.onLongPress`, and forward the optional callback from `ExerciseCard` to its underlying `ExpandableTile.onLongPress`. Keep the callback optional so exercise-picker cards remain read-only.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Widget test: long-pressing an `ExerciseCard` fires `onLongPress` without firing `onOpen`.
* Manual: swipe an exercise card on the Exercises tab and confirm the background is now muted (`secondaryContainer`) with the label "Endre øvelse" / "Edit Exercise" + pencil icon, matching the visual treatment of station, roleplay and team row swipes. Long-press the same card and confirm the edit form opens directly.

**Commit**: `fix(program): open exercise edit form on long-press`

---

## Step 7 — Final verification

* Run `flutter analyze && flutter test` one last time.
* Run `git log --oneline -7` and confirm the six feature commits above are in order, each with an explicit file list in the body.
* Run `git status` and confirm it is clean.
* Manual: replay the click-count exercise from the analysis for these four tasks.
  1. Create an exercise + set the name on its first station.
  2. Rename an existing station.
  3. Rename a team starting from the Teams tab.
  4. Rename a team starting from CoordinatorScreen.
* End-to-end persistence check (the file-format claim must actually hold):
  1. Rename a team via `TeamFormScreen`.
  2. Export the active plan as `.drill` (drawer → "Eksporter som .drill" / "Export as .drill").
  3. Delete the active plan locally.
  4. Re-open the exported `.drill`.
  5. Confirm the renamed team name survives the round-trip.

Expected after this PR (numbers in parentheses are the baseline before):

| Task | Clicks |
|---|---|
| Create + set first station name | 4 (was 6) |
| Rename existing station | 2 (was 3-4) |
| Rename team from Teams tab | 2 (was impossible) |
| Rename team from CoordinatorScreen | 2 (was impossible) |

If the numbers diverge, or the export/import round-trip drops the renamed team, escalate back with concrete observations rather than fixing blind.

## Out of scope

The following are deliberately excluded. Do not smuggle them in:

* Changing the top-level tab structure (proposal B1 in the analysis).
* Cross-links from the detail sheet back to the parent exercise (proposal B2).
* Inlining `ExerciseFormScreen` into CoordinatorScreen (proposal C1).
* Validating `numberOfMembers` against actual participant lists.
* Wide-screen master/detail tweaks beyond what `openFormSurface` already handles.
* New `ProgramEvent` factories for entities other than `Team` (no `stationSaved`, no `rolePlaySaved` in this PR).

If you notice anything else along the way that looks broken or missing, add it as a note at the end of the final commit message ("Found in passing, not fixed in this PR: ...") so it can be split into its own follow-up prompt.
