1. ~~`MainScreen.dispose()` does not dispose its field-held `RolePlaysController`, leaving `filterExerciseUuid` undisposed after the shell is torn down.~~ **Resolved** in the stage 1 switcher fix (`_rolePlaysController.dispose()` added to `MainScreen.dispose()`).

2. ~~**Markører segment: add a "Ny rolle" FAB (DESIGN-006).**~~ **Resolved.** `RolePlaysController` now has a "Ny rolle" `buildFAB` (exercise-picker sheet → `RolePlayFormScreen` with a blank draft) and a `buildActions` exercise filter (`Icons.filter_list`) plus the cast-roster action. The Poster filter was likewise moved from a body FAB to a `StationListController.buildActions` action, so both segments filter the same way and the FAB slot is free.

3. ~~**Brief default audience should be Øvelsesleder, not Deltaker (DESIGN-004).**~~ **Resolved.** `brief_screen.dart` defaults the audience to `BriefAudience.director` (and reads the app-user role from item 4).

4. ~~**App-user role selector, staff-only (DESIGN-004 + DESIGN-006 Roster axis).**~~ **Resolved.** `AppUserRole` (`lib/services/app_user_role.dart`) with a `briefAudience` mapping, an `AppUserRoleSettings` selector offering Øvelsesleder + Veileder (not participant) stored via `AppConfig.keyAppUserRole`, and `brief_screen.dart` reads it to set the default audience.

5. **Compact detail sheet: `PhaseTile` overflows horizontally.** Rendering a station detail sheet at a 700 px viewport leaves a 314 px content width and overflows the `Row` in `lib/views/phase_tile.dart` by 10 px. Keep this separate from the routing migration.

6. ~~**Stage 3: per-segment scroll/expansion state lost on segment switch.**~~ **Resolved.** The stage 3 manual-collapse rework dropped the `NestedScrollView` for a `Column` + `NotificationListener` + `IndexedStack`, so every segment stays mounted and keeps its expansion/scroll state across switches.

7. **Stage 3: `Program.briefIntroMd` / `commsMd` never populated by `ProgramService.activeProgram`.** Sidecar markdown fields are only hydrated when reading from a `.drill` archive. Locally-created programs always have them null. The `commsMd` seam in `_ProgramOverview` is ready; when DESIGN-004 populates these fields in the repository, the overview preview renders automatically.

8. **`SilentWitness` / "Tause vitner" — future Spill segment sibling.** A scenario element with description/story/purpose/info + position, no actor assignment. Publishable (lives in the Spill/Script segment alongside `RolePlay`). Distinct from `Actor` (no PII, no cast). Consider a shared `ScenarioElement` base when designing. See `docs/prompts/DESIGN-006-script-rename-handoff.md` for context.

9. **Retire the cast-roster action ("Spilles av" / `Icons.recent_actors`) from the Spill segment.** Once the Roster tab (stage 4) ships, that tab is the actor registry's home, so the cast-roster action in `RolePlaysController.buildActions` is redundant — remove it and keep only the filter action. The per-role **cast picker** (assigning an `Actor` to a `RolePlay` from the role detail) stays. Remove `RolePlaysView._openCastRoster` if nothing else uses it, and drop the cast-roster column from the Spill row of the DESIGN-006 FAB/actions table. Deferred out of stage 4 so the stage-4 run is not disturbed mid-flight.

10. **Rename the Spill segment's create FAB from "Ny rolle" to "Nytt spill".** The label should match the segment name ("Spill"). It still creates a `RolePlay` for now; when `SilentWitness` / tause vitner lands (item 8), "Nytt spill" likely becomes a choice between a rolle and a tause vitne. Label/l10n change only.

11. **Roster actor subtitle does not refresh when the actor is cast in the script.** In the Roster tab, an `Actor` row's subtitle (its role-play assignment) does not update when the actor is cast to or uncast from a `RolePlay` in the Spill segment. The Roster view needs to rebuild on the relevant `ProgramService` event (rolePlay/cast change), or recompute the assignment on those events, rather than reading the assignment once.
