# ADR-0017 follow-up

Two follow-ups after the ADR-0017 implementation. Same session, so ground rules, commit format and codebase context still apply. Each task is one commit.

## 1. Annotate revisits and under-coverage in the rotation-share text

ADR-0017 left this as an unaddressed "Bad" consequence. In `formatExerciseForShare`, add one informational line after the meta line when `numberOfRounds != numberOfStations`. New ARB keys `shareNoteRevisits(rounds, stations)` and `shareNoteUnderCoverage(rounds, stations)`. The rotation block below is frozen (see memory note on the share format). Update the golden strings in `exercise_share_format_test.dart`.

Commit: `feat(coordinator): annotate revisits and under-coverage in rotation-share text`.

## 2. Existing exercises with counter values above 12

A saved exercise from before the new 2..12 bounds can carry e.g. `numberOfTeams = 14`. In `ExerciseFormScreen.initState`, when any of the three counters loads a value > 12: keep the value in the field (do not clamp), and render a banner above the fields explaining that this exercise predates the current limit and that reducing it is permanent. New ARB key `legacyOversizedExerciseNotice`. The validators still block save without a manual reduction. Add a unit test for the load path.

Commit: `fix(exercise): preserve legacy counter values above the 12-cap on load`.

## Out of scope

Option D from ADR-0017 (dedicated station-management UI) needs its own design doc and is not part of this round.
