# DESIGN-008 end-to-end QA pass

**Date:** 2026-07-04

## Context

DESIGN-008 (plan variables + the section-navigated editor) is fully
implemented on `design-008`: model (Stage 1), renderer resolution for
markdown fields and, later, names/descriptions (Stage 2, follow-up 05),
section-navigated editors for all four entities (Stage 3, follow-ups 06/07),
token-aware fields including names/descriptions (Stage 4, follow-ups 03/09),
override tables on `Exercise`/`Station` (follow-up 07), live-UI resolution
(follow-up 09), and the `RINGDRILL_PLAN_VARIABLES` flag removed (follow-up
08). Follow-up 10 closes the work with one end-to-end pass before flipping
ADR-0046 and DESIGN-008 to `Accepted`.

## Full gate

* `flutter analyze` — clean, no issues.
* `flutter test` — **720 passing**, 0 failing.
* `dart build cli` — succeeds (`build/cli/macos_arm64/bundle/bin/ringdrill`).
* `flutter gen-l10n` (`make i18n`) — idempotent, no diff in `lib/l10n/`.

## Defect found and fixed during this pass

**Rename and delete-reference tracking never learned about
names/descriptions.** `lib/utils/plan_variable_refs.dart`'s `_hits()`
(backing both `variableReferenceCount`, the delete guard, and
`variableReferences`, the delete-blocked usage list) and `renameVariable()`
were written against Stage 2's field list — the long-form markdown fields
only. Follow-ups 05 and 09 later taught the renderer and the live UI to
resolve `{{var.<name>}}` in `Program.name`/`description`, `Exercise.name`,
`Station.name`/`description` and `RolePlay.name`, but nobody went back and
taught the reference-tracking module about that surface.

Reproduced directly: with `Exercise(name: 'Øvelse {{var.frekvens}}')` and
`frekvens` declared on the plan, `variableReferenceCount(program,
'frekvens')` returned `0` (the delete guard would not have blocked
deletion), and `renameVariable(program, 'frekvens', 'kanal')` left
`exercise.name` reading `'Øvelse {{var.frekvens}}'` untouched — an
undeclared reference to a name that no longer exists in the registry, the
exact "silent breakage" ADR-0046's Consequences section says the rename
feature exists to prevent.

**Fix:** extended `PlanVariableField` with `programName`,
`programDescription`, `exerciseName`, `stationName`, `stationDescription`,
`roleplayNameField`; wired six new cases into `_hits()` (counting/locating)
and `renameVariable()` (rewriting, via a new `_rewriteRequired` helper for
the non-nullable name fields); added matching labels to
`program_form_screen.dart`'s `_describeReference()`. Covered by new tests in
`test/utils/plan_variable_refs_test.dart` (counting, locating, rewriting for
every new field) and a widget-level regression test in
`test/views/program_form_screen_variables_declaration_test.dart` (delete
blocked when the only reference is an exercise name, exercised through the
real editor's `_workingProgram()` path, not just the pure functions).

This was found and fixed as part of this QA pass rather than deferred, per
the follow-up 10 prompt's instruction to stop and report (not patch blindly)
non-trivial defects — reported to and confirmed with the user before
fixing.

## Scripted walkthrough (one fixture plan, per follow-up 10 Step 1)

Each item below is exercised by an existing or newly-added automated test;
none of this was eyeballed only.

| Walkthrough item | Where it's covered |
|---|---|
| Declare a variable on the plan | `test/models/program_variables_test.dart`; `program_form_screen_variables_declaration_test.dart` ("declare a variable, reference it, save") |
| Reference it in a program markdown field, an exercise field, a station field, a roleplay field, and an exercise name | `brief_renderer_variables_test.dart` — "resolves a variable in program, exercise, station and roleplay fields" and "a variable in exercise.name resolves in the heading" |
| Override its value on an exercise and again on a station | `brief_renderer_variables_test.dart` — "cascades station override, exercise override and program default"; `program_variables_test.dart` hash-sensitivity tests |
| Render the brief for all three audiences and confirm the cascade resolves in both fields and names | `brief_renderer_variables_test.dart` — new test "the cascade resolves identically for all three audiences" (loops `BriefAudience.values`); the names/descriptions group already covers `participant`/`director` per-field |
| Live UI (list, coordinator, player, share) shows resolved values | `test/views/roleplays_view_variables_test.dart` (list tile in/out of `PlanScope`, exercise-scope override); `test/utils/exercise_share_format_test.dart` (share text); `test/views/widgets/ringdrill_text_test.dart` (the shared display primitive); coordinator/player adopt the same `RingDrillText`/`SheetTitle` machinery covered there — see follow-up 09's commits for the full site list |
| Rename the variable, confirm references rewrite across the plan | `plan_variable_refs_test.dart` — "renameVariable rewrites every markdown field..." plus the new "rewrites program.name/description, exercise.name, station.name/description and rolePlay.name" test; `program_form_screen_variables_declaration_test.dart` — "renaming a variable rewrites every reference in the editor" |
| Delete blocked while referenced; succeeds once unreferenced | `program_form_screen_variables_declaration_test.dart` — "delete is blocked while referenced, and removes once unreferenced" plus the new "delete is blocked when the only reference is an exercise name" regression test |
| Save blocked on an undeclared token; not blocked on an empty declared token | `program_form_screen_variables_declaration_test.dart` — "save is blocked on an undeclared token..." and "a declared-but-empty variable referenced in a field saves fine"; `roleplay_form_screen_variables_test.dart`, `program_form_screen_name_variables_test.dart` cover the same rule for names |

## `.drill` round-trip

Already exercised end-to-end by Stage 1's suite, re-confirmed passing in
this pass's full run:

* `test/models/program_variables_test.dart` — "Program registry round-trips
  through the real DrillFile archive", "Exercise and Station
  variableOverrides round-trip through the [archive]", plus backward-compat
  (`program.json` with no `variables` key deserializes to `[]`; no
  `variableOverrides` key deserializes to `{}`).
* Content hash: "changes when a variable value changes", "changes when a
  variable is added", "is stable when variables differ only in list order",
  "changes when an exercise variableOverrides entry changes", "changes when
  a station variableOverrides entry changes" — all in the same file.

## Outcome

Full gate green, the scripted walkthrough passes end-to-end on a single
fixture plan, and the one defect this pass surfaced (rename/delete-reference
tracking missing names/descriptions) is fixed and covered by regression
tests, not deferred. DESIGN-008 is ready for its docs to flip to `Accepted`.

## Related

* [ADR-0046](../adrs/0046-plan-variables.md) — the model, resolution and
  validation rules this pass verifies.
* [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md)
  — the authoring surface this pass verifies.
* `docs/prompts/design-008-followup-10-qa-and-accept.md` — the prompt this
  note satisfies Step 1 of.
