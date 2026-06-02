1. ~~`MainScreen.dispose()` does not dispose its field-held `RolePlaysController`, leaving `filterExerciseUuid` undisposed after the shell is torn down.~~ **Resolved** in the stage 1 switcher fix (`_rolePlaysController.dispose()` added to `MainScreen.dispose()`).

2. ~~**Markører segment: add a "Ny rolle" FAB (DESIGN-006).**~~ **Resolved.** `RolePlaysController` now has a "Ny rolle" `buildFAB` (exercise-picker sheet → `RolePlayFormScreen` with a blank draft) and a `buildActions` exercise filter (`Icons.filter_list`) plus the cast-roster action. The Poster filter was likewise moved from a body FAB to a `StationListController.buildActions` action, so both segments filter the same way and the FAB slot is free.

3. ~~**Brief default audience should be Øvelsesleder, not Deltaker (DESIGN-004).**~~ **Resolved.** `brief_screen.dart` defaults the audience to `BriefAudience.director` (and reads the app-user role from item 4).

4. ~~**App-user role selector, staff-only (DESIGN-004 + DESIGN-006 Roster axis).**~~ **Resolved.** `AppUserRole` (`lib/services/app_user_role.dart`) with a `briefAudience` mapping, an `AppUserRoleSettings` selector offering Øvelsesleder + Veileder (not participant) stored via `AppConfig.keyAppUserRole`, and `brief_screen.dart` reads it to set the default audience.

5. ~~**Compact detail sheet: `PhaseTile` overflows horizontally.**~~ **Resolved.** The title cell now uses `BoxConstraints(maxWidth: painter.width + 24)` (instead of a fixed `width:`) and is wrapped in `Flexible(fit: FlexFit.loose)` in the non-`titleWidth` mode. The cell renders at its natural width when the row has room and shrinks gracefully (text ellipsizes) when the row is too narrow — fixing the ~10 px overflow at ~314 px content width in the station detail sheet.

6. ~~**Stage 3: per-segment scroll/expansion state lost on segment switch.**~~ **Resolved.** The stage 3 manual-collapse rework dropped the `NestedScrollView` for a `Column` + `NotificationListener` + `IndexedStack`, so every segment stays mounted and keeps its expansion/scroll state across switches.

7. **Stage 3: `Program.briefIntroMd` / `commsMd` never populated by `ProgramService.activeProgram`.** Sidecar markdown fields are only hydrated when reading from a `.drill` archive. Locally-created programs always have them null. The `commsMd` seam in `_ProgramOverview` is ready; when DESIGN-004 populates these fields in the repository, the overview preview renders automatically.

8. **`SilentWitness` / "Tause vitner" — future Spill segment sibling.** A scenario element with description/story/purpose/info + position, no actor assignment. Publishable (lives in the Spill/Script segment alongside `RolePlay`). Distinct from `Actor` (no PII, no cast). Consider a shared `ScenarioElement` base when designing. See `docs/prompts/DESIGN-006-script-rename-handoff.md` for context.

9. **Retire the cast-roster action ("Spilles av" / `Icons.recent_actors`) from the Spill segment.** Once the Roster tab (stage 4) ships, that tab is the actor registry's home, so the cast-roster action in `RolePlaysController.buildActions` is redundant — remove it and keep only the filter action. The per-role **cast picker** (assigning an `Actor` to a `RolePlay` from the role detail) stays. Remove `RolePlaysView._openCastRoster` if nothing else uses it, and drop the cast-roster column from the Spill row of the DESIGN-006 FAB/actions table. Deferred out of stage 4 so the stage-4 run is not disturbed mid-flight.

10. ~~**Rename the Spill segment's create FAB from "Ny rolle" to "Nytt spill".**~~ **Resolved.** New `newPlay` localization key (nb "Nytt spill", en "New play" — mirrors the `scriptSegment` label) is wired into the Spill segment's create FAB. The FAB still calls `openCreateRolePlay` and creates a `RolePlay` for now; when `SilentWitness` / tause vitner lands (item 8), the handler is the seam where this becomes a choice.

11. **Roster actor subtitle does not refresh when the actor is cast in the script.** In the Roster tab, an `Actor` row's subtitle (its role-play assignment) does not update when the actor is cast to or uncast from a `RolePlay` in the Spill segment. The Roster view needs to rebuild on the relevant `ProgramService` event (rolePlay/cast change), or recompute the assignment on those events, rather than reading the assignment once.

12. ~~**PlanStatusBadge InkWell is not right.**~~ **Resolved.** The badge's `InkWell` is now wrapped in a transparent `Material` (`MaterialType.transparency`) with a matching `BorderRadius.circular(4)` and `Clip.antiAlias`, so the splash clips to the badge bounds instead of bleeding onto the AppBar.

13. **Shared addable-field form pattern for Plan, Exercise and Station forms (DESIGN-004 amendment).** `RolePlayFormScreen` already has the right pattern: base fields always shown, plus optional sections that start hidden, with an `Icons.add` button per not-yet-added section and a remove affordance on each added field (`_Section` / `_activeSections` + add-section buttons). Generalize this into a reusable form component and apply it to every entity form, each with **name** + **description** always shown and the DESIGN-004 markdown fields addable on demand:

    - **`ProgramFormScreen`** (new — no plan editor exists today beyond the name rename via `renamePlan`): addable `briefIntroMd`, `commsMd`, `beforeRoundMd`. Closes item 7.
    - **`ExerciseFormScreen`**: addable `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`.
    - **`StationFormScreen`** (today only name/description/position): addable `equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd`, `directorNotesMd`.

    DESIGN-004's "Where the data is edited" section is **amended (2026-06-02)** to this base-fields + add-on-demand pattern with the RolePlay reference; DESIGN-004 is amended, not superseded (its brief rendering, audience and markdown fields stand). This item is the implementation.
