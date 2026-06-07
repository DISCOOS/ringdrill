## Investigation

2026-06-07: Pre-implementation notes for stage 4.

**The FAB seam.** `ProgramPageControllerBase._buildExercisesFAB` (`lib/views/program_view.dart:1158`) returns the Øvelser FAB — `FloatingActionButton.extended` on medium/expanded, compact `FloatingActionButton` on phones. It is only called when `activeSegment == ProgramSegment.exercises` and not in reorder mode (line 1137). Wrapping its return value naturally satisfies "only on the Øvelser FAB, only when Øvelser is showing".

**The create event.** `ProgramEventType.exerciseAdded` is emitted from `ProgramService.saveExercise` (`lib/services/program_service.dart:334`) via `ProgramEvent.added`. This fires for any exercise creation path. The pill subscribes to `ProgramService().events` and marks itself seen on the first `exerciseAdded` event.

**Dedicated flag decision.** Using a new `AppConfig.keyStartHereSeen = 'app:startHereSeen:v1'`, not reusing `keyOnboardingSeen`. Reason: the primer writes `keyOnboardingSeen = true` on dismissal, *before* the user ever reaches the Program tab. Reusing it would make the pill born already-dismissed — it would never show.

**Tap behaviour.** Pill tap = act like the FAB: opens `_navigateToCreateExercise(context)` *and* writes the flag. A single tap to first value is preferred over "dismiss the hint, then tap the FAB separately". The spec allows either path; "act like the FAB" is explicitly the natural behaviour.

**Exercises-empty check in the controller.** `_buildExercisesFAB` lives on `ProgramPageControllerBase`, which does not hold `_exercises` (that lives on `_ProgramViewState`). However, it holds `programService` (`lib/views/program_view.dart:1107`), so `programService.loadExercises().isEmpty` reads the same source of truth synchronously, consistent with how `_ProgramViewState` loads the list.
