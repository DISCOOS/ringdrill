## Investigation

2026-06-07: Pre-implementation notes for stage 4.

**The FAB seam.** `ProgramPageControllerBase._buildExercisesFAB` (`lib/views/program_view.dart:1158`) returns the Øvelser FAB — `FloatingActionButton.extended` on medium/expanded, compact `FloatingActionButton` on phones. It is only called when `activeSegment == ProgramSegment.exercises` and not in reorder mode (line 1137). Wrapping its return value naturally satisfies "only on the Øvelser FAB, only when Øvelser is showing".

**The create event.** `ProgramEventType.exerciseAdded` is emitted from `ProgramService.saveExercise` (`lib/services/program_service.dart:334`) via `ProgramEvent.added`. This fires for any exercise creation path. The pill subscribes to `ProgramService().events` and marks itself seen on the first `exerciseAdded` event.

**Dedicated flag decision.** Using a new `AppConfig.keyStartHereSeen = 'app:startHereSeen:v1'`, not reusing `keyOnboardingSeen`. Reason: the primer writes `keyOnboardingSeen = true` on dismissal, *before* the user ever reaches the Program tab. Reusing it would make the pill born already-dismissed — it would never show.

**Tap behaviour.** Pill tap = act like the FAB: opens `_navigateToCreateExercise(context)` *and* writes the flag. A single tap to first value is preferred over "dismiss the hint, then tap the FAB separately". The spec allows either path; "act like the FAB" is explicitly the natural behaviour.

**Exercises-empty check in the controller.** `_buildExercisesFAB` lives on `ProgramPageControllerBase`, which does not hold `_exercises` (that lives on `_ProgramViewState`). However, it holds `programService` (`lib/views/program_view.dart:1107`), so `programService.loadExercises().isEmpty` reads the same source of truth synchronously, consistent with how `_ProgramViewState` loads the list.

## Closing

2026-06-07: Stage 4 landed in three commits on main.

**New files:**
- `lib/views/widgets/start_here_pill.dart` — the `StartHerePill` widget; reads `keyStartHereSeen` on mount, subscribes to `ProgramService().events` for `exerciseAdded`, dismisses permanently on tap or event.
- `test/views/widgets/start_here_pill_test.dart` — smoke test (light, dark, flag-set hidden).
- `test/views/start_here_pill_flow_test.dart` — 6 integration tests covering show, hide, and both dismissal paths.

**Modified files:**
- `lib/utils/app_config.dart` — added `keyStartHereSeen = 'app:startHereSeen:v1'`.
- `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — added `startHereCue` key ("Start here" / "Start her").
- `lib/views/program_view.dart` — `_buildExercisesFAB` now returns a `Row([StartHerePill, gap, fab])` when `programService.loadExercises().isEmpty`; bare `fab` otherwise.

**Flag:** `keyStartHereSeen = 'app:startHereSeen:v1'` (dedicated sibling, NOT `keyOnboardingSeen` which is already true by the time the user reaches the Program tab).

**Tap behaviour:** pill tap opens `_navigateToCreateExercise(context)` (same as the FAB) and writes the flag. Single tap to first value.

**Anchor:** `_buildExercisesFAB` only. The pill never appears on Spill, Poster, or Lag segment FABs.

**Stage 5 seam:** `ConceptPrimerContent` (`lib/views/widgets/concept_primer_content.dart`) is the reuse surface for the Help/FAQ ring illustration entry. No seam in stage 4's code — it is self-contained.

**Test pattern note:** `ProgramService` is a singleton; `ProgramRepository` holds a `SharedPreferences` reference captured at `init()`. Tests use a `setUpAll` that seeds prefs once, then `ProgramService().setActive(uuid)` + `SharedPreferences.getInstance().setBool/remove(...)` to control state per test — avoids stale prefs refs from repeated `setMockInitialValues` calls.
