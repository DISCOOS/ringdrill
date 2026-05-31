# Prompt: Quick-wins for edit affordances across Exercises, Stations, and Teams

You are working in RingDrill (Flutter, repo root `/Users/kengu/git/discoos/ringdrill`). Read `AGENTS.md` and `CLAUDE.md` first. No ADR is required for this work — these are pure UI affordances layered on top of existing patterns, with no new dependencies, no schema changes, and no architectural shifts.

## Goal

Reduce the click count required to edit a station or a team from within an active exercise, and make teams editable at all. To do this:

1. Expose a public `ProgramService.saveTeam` so callers outside the service can persist team edits.
2. Add a `TeamFormScreen` so a team's name, member count, and position can be edited (today there is no edit path for teams).
3. Expose editing through left-swipe (Dismissible) and a visible inline pencil button on rows, mirroring what is already in place on the Stations tab and the RolePlays tab.

The pattern must mirror what is already established in `lib/views/station_list_view.dart` (Dismissible + `confirmDismiss` → form, plus `onOpen` → ContextSheet for read-only view). Do not introduce new widgets or abstractions.

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

Each of the six steps below is one commit. After every commit, `git status` must be clean — no untracked or modified files left behind. Each commit body must list the files touched explicitly. Commit message format: conventional commits (`feat(...)`, `refactor(...)`, etc.). Do not bundle steps into a single commit.

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
* Add a trailing `IconButton(Icons.edit)` to the `ListTile.trailing` slot that calls the same `_openTeamForm`. Tooltip: `localizations.editTeam`.

In `team_exercise_screen.dart`:

* Add an `IconButton(Icons.edit)` to `AppBar.actions` (currently lines 39-57). Mirror the layout from `station_screen.dart:117-128`, including the disable rule when `ExerciseService().isStarted` is true. Tooltip when enabled: `localizations.editTeam`. Tooltip when disabled: `localizations.stopExerciseFirst(widget.exercise.name)`.
* `onPressed` resolves the `Team` via `ProgramService().loadTeams()[widget.teamIndex]` and opens the same form. On a non-null return, call `ProgramService().saveTeam(localizations, updated)` and `setState({})`.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual: swipe a team row → form → save; tap the inline pencil → form → save; tap the pencil in the detail sheet's app bar → form → save. Confirm the name updates in the list and in the sheet title without a tab switch.

**Commit**: `feat(teams): edit team via swipe, inline pencil, and detail-sheet action`

---

## Step 4 — Swipe-to-edit on station rows inside CoordinatorScreen

**Files touched**

* `lib/views/coordinator_screen.dart`

**Content**

In `_buildStationList` (around lines 1000-1060, before the `_buildStationDetail` call):

* Wrap each station `Card` / `ExpansionTile` row in `Dismissible(direction: DismissDirection.endToStart, confirmDismiss: ...)`. Use `ValueKey('coordinator-station-dismiss-$stationIndex')` to avoid collision with the expansion controller's own key.
* Background: mirror `station_list_view.dart:268-284`.
* `confirmDismiss` calls a new private `_editStation(int stationIndex)` that:
  1. Returns immediately if `_isStarted` is `true`, surfacing a snackbar with `localizations.stopExerciseFirst(_exercise!.name)`.
  2. Opens `openFormSurface<Station>(context, builder: (_) => StationFormScreen(station: _exercise!.stations[stationIndex], markers: _programService.getLocations().toMarkerSpecs()))`.
  3. On a non-null return, persists using the same pattern as `station_list_view.dart:412-422`: build a new `stations` list, swap the entry, then call `_programService.saveExercise(localizations, updatedExercise)`. Reuse any existing helper in `program_service` if one is already there.
* Always return `false` from `confirmDismiss`.

Note: the expansion controller in `_stationControllers` must not be triggered by the swipe — the Dismissible must wrap *around* the `ExpansionTile`, not sit as a `child` inside it.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual: open an exercise (tap its card from the Exercises tab), swipe a station row in the station list, confirm the form opens, saving updates the row inline, and no tab switch occurs.
* Check that swipe is inert while the exercise is running (start it, attempt swipe, confirm snackbar and no form).

**Commit**: `feat(coordinator): swipe-to-edit station rows in exercise overview`

---

## Step 5 — Inline pencil on station and team rows inside CoordinatorScreen

**Files touched**

* `lib/views/coordinator_screen.dart`

**Content**

In `_buildStationList`'s `ExpansionTile.title` Row (around lines 1020-1055): add an `IconButton(Icons.edit, ...)` as the last child, before the round-indicator columns. Tooltip and disabled-state mirror `station_screen.dart:117-128`. Click handler: the same `_editStation` introduced in Step 4.

In `_buildTeamList`'s `ExpansionTile.title` Row (around lines 1185-1262): add an `IconButton(Icons.edit, ...)` as the last child, before the round columns. Click handler: a new private `_editTeam(int teamIndex)` that:

1. Resolves the team via `_programService.loadTeams()[teamIndex]`.
2. Opens `openFormSurface<Team>(context, builder: (_) => TeamFormScreen(team: team))`.
3. On a non-null return, calls `_programService.saveTeam(localizations, updated)` and `setState({})`.
4. Disabled with the same `_isStarted` rule as the station pencil.

Make sure the `IconButton` does not steal taps from the `ExpansionTile`. Either move the button into `ExpansionTile.trailing` if that slot is currently free (check), or keep it in the Row and rely on `IconButton`'s own hit area, which stops tap propagation by default.

**Verification**

* `flutter analyze` clean.
* `flutter test` clean.
* Manual: open an exercise; tap the pencil on a station row → form opens directly (no intermediate sheet); tap the pencil on a team row → form opens directly. Confirm that tapping the row itself still expands the tile as before.

**Commit**: `feat(coordinator): inline edit pencil on station and team rows`

---

## Step 6 — Final verification

* Run `flutter analyze && flutter test` one last time.
* Run `git log --oneline -6` and confirm the five feature commits above are in order, each with an explicit file list in the body.
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
