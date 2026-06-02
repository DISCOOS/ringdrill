# DESIGN-006 follow-up #13 — addable-field form pattern (handoff)

## Reference shape (RolePlayFormScreen)

`lib/views/roleplay_form_screen.dart` already implements the pattern that the
rest of the entity forms must adopt. Anatomy:

- `_Section` enum (one value per optional field).
- `_activeSections` set, seeded from the entity's non-null optional fields in
  `initState`.
- One `TextEditingController` + `FocusNode` per section, owned by the form
  state.
- `_addSection(section)` → mutates `_activeSections` and requests focus on the
  next frame.
- Each active section renders a multi-line `TextFormField` (minLines: 2,
  maxLines: 8) labelled via `_labelFor` with a `suffixIcon` close button that
  removes the section and clears the controller.
- A trailing `Wrap` of `OutlinedButton.icon(Icons.add, ...)` for every section
  not yet active.
- Save reads the controller only when the section is active, otherwise stores
  `null` on the model (so removed sections fall back to "section omitted").

## Entry points and persistence

- Entity forms are opened via `lib/views/shell/open_form_surface.dart`
  (`openFormSurface<T>`) — wide layouts show a dialog, narrow layouts push a
  route. They pop with the updated entity.
- `RolePlayFormScreen` is opened from `roleplays_view.dart`,
  `station_screen.dart`, `roleplay_screen.dart`; callers persist via
  `ProgramService.saveRolePlay`.
- `ExerciseFormScreen` (`program_view.dart`, `coordinator_screen.dart`)
  persists via `ProgramService.saveExercise`.
- `StationFormScreen` (`program_view.dart`, `station_screen.dart`,
  `station_list_view.dart`, `coordinator_screen.dart`) is opened with the
  station, and the caller (per call site) writes the updated `Exercise` back
  via `saveExercise` (stations live inside exercises).
- For program-level editing today the only path is `renamePlan` in
  `lib/views/active_plan_actions.dart` (name only) plus
  `ProgramService.replaceProgram` for the broader save. The collapsing
  `_ProgramOverview` in `program_view.dart` is read-only and shows
  `program.description` + `program.briefIntroMd` first paragraph. This is the
  intended entry point for `ProgramFormScreen` (tap the overview).
- Sidecar `*Md` fields are `@JsonKey(includeFromJson:false, includeToJson:false)`
  on the freezed models. `DrillFile` reads/writes them to `.md` files inside
  the archive. `ProgramRepository` serialises with `toJson()`, so locally-created
  programs do not persist `*Md` content beyond the running session yet — that
  is DESIGN-004 Stage 1a/1b. Item 7 in `DESIGN-006-followups.md` explicitly
  acknowledges this; item 13's job is the UI seam, not repository hydration.

## Labels (Norwegian booklet)

From DESIGN-004 field-mapping tables:

- Program: `briefIntroMd` = "Generelt om spill og øvingsledelse",
  `commsMd` = "Talegrupper", `beforeRoundMd` = "Før hver post".
- Exercise: `methodMd` = "Metode", `learningGoalsMd` = "Læringsmål",
  `trainingFocusMd` = "Øvingsmomenter", `orderFormatMd` = "Ordreformat",
  `executionTipsMd` = "Tips til gjennomføring", `commsMd` = "Samband".
- Station: `equipmentMd` = "Utstyrsbehov", `situationMd` = "Situasjon",
  `missionMd` = "Oppdrag", `logisticsMd` = "Administrasjon og forsyninger",
  `criticalQuestionsMd` = "Kritiske spørsmål",
  `leaderAnswersMd` = "Forslag til svar", `directorNotesMd` = "Notater".

English copies mirror the booklet glosses already in DESIGN-004 (`Method`,
`Learning goals`, `Training focus`, `Order format`, `Execution tips`,
`Comms`, etc.). I will use the existing DESIGN-004 English wording where it
exists.

## Plan

- Step 1: extract `OptionalFieldSections` widget in
  `lib/views/widgets/optional_field_sections.dart`. Refactor
  `RolePlayFormScreen` to use it (no behaviour change).
- Step 2: add `ProgramFormScreen`; wire entry from `_ProgramOverview`.
- Step 3: extend `ExerciseFormScreen`.
- Step 4: extend `StationFormScreen`.
- Step 5: tests + DESIGN-004 + followups status updates.

## Closing notes (2026-06-03)

All five steps landed on `main` across five commits:

1. `refactor(widget): extract OptionalFieldSections from RolePlayFormScreen`
2. `feat(program): add ProgramFormScreen and wire it from the overview`
3. `feat(exercise): addable brief sections on ExerciseFormScreen`
4. `feat(station): addable brief sections on StationFormScreen`
5. `test(forms): cover OptionalFieldSections + brief-field round-trips`

Tests added under `test/views/`:

- `widgets/optional_field_sections_test.dart` (add/remove flow on the shared widget)
- `program_form_screen_test.dart` (base + brief field round-trip, remove clears)
- `exercise_form_screen_brief_test.dart` (seeded `methodMd` round-trip, remove clears)
- `station_form_screen_brief_test.dart` (seeded `equipmentMd` round-trip, remove clears)

DESIGN-004 "Where the data is edited" updated from *amend planned* to
*implemented 2026-06-03* with a one-line changelog entry; items 7 and 13 in
`DESIGN-006-followups.md` marked resolved.

### Off-scope finding (worth a future follow-up)

`StationFormScreen` already has an English-locale layout overflow: the
fixed 230 px position panel + `PositionFormField`'s `Row(Text(label) +
Spacer + Text("Pick a Location") + ...)` outgrows the panel. The
station-form brief tests work around it by draining the
`RenderFlex overflowed` exception from `tester.takeException()`. This
pre-existed this change set; recording it here so a future pass can fix
the panel (e.g. ellipsize the label, or widen the panel on wide screens)
and drop the test workaround.
