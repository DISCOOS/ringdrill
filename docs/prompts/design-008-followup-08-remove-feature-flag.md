# DESIGN-008 follow-up 08 — remove the feature flag

You are working in the RingDrill repository. Follow-up to DESIGN-008. Read [ADR-0046](../adrs/0046-plan-variables.md) and `docs/design/008-plan-variables-and-section-navigated-editor.md` first. DESIGN-008 is being completed on the `design-008` branch, so the `RINGDRILL_PLAN_VARIABLES` build flag has done its job and is now removed.

## Current state (read — this differs from the original plan)

This step was meant to run before the editor migrations, but follow-ups 06 and 07 landed **behind the flag**. So the flag is now woven through **all four** entity editors, each carrying a dual path: a `_planVariablesOn` getter (`widget.debugPlanVariablesOverride ?? AppFlags.planVariables`), a `debugPlanVariablesOverride` test field, and a full legacy (flag-off) body alongside the section-navigated one. Confirmed in `lib/views/program_form_screen.dart`, `exercise_form_screen.dart`, `station_form_screen.dart`, `roleplay_form_screen.dart`. Controllers are also conditionally `TokenTextEditingController` vs plain `TextEditingController` on `_planVariablesOn`.

Removing the flag therefore means collapsing the dual path in **all four** editors and deleting **four** legacy bodies, not just the Program editor.

## Ground rules

* Behavior-preserving for the section-navigated (flag-on) experience: every editor keeps working exactly as it does today with the flag on, just without the gate.
* Remove, don't stub. Delete the legacy bodies and the `_planVariablesOn`/`debugPlanVariablesOverride` machinery; don't leave dead code behind an always-true condition.
* Where a controller was `_planVariablesOn ? TokenTextEditingController(...) : TextEditingController(...)`, make it unconditionally the token-aware controller.
* Update `docs/feature-flags.md` in the same change (ADR-0042 convention).
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Six steps, in order. One editor per commit keeps the review honest.

### Steps 1–4. Collapse each editor

For each of `program_form_screen.dart`, `exercise_form_screen.dart`, `station_form_screen.dart`, `roleplay_form_screen.dart`:

* Delete the `_planVariablesOn` getter and the `debugPlanVariablesOverride` constructor field.
* Delete the legacy (flag-off) body; make the section-navigated body the unconditional `build`, always wrapped in `PlanScope`.
* Make any `_planVariablesOn ? TokenTextEditingController(...) : TextEditingController(...)` unconditionally the `TokenTextEditingController`.
* Remove any `_planVariablesOn` guards on save/validation so those paths run unconditionally.

Commit per editor: `refactor(views): drop the flag path from <Entity>FormScreen`.

### Step 5. Delete the flag

Remove `AppFlags.planVariables` (the `bool.fromEnvironment` const and its `AppFlagInfo` in `AppFlags.all`) from `lib/utils/app_flags.dart`. Remove the `RINGDRILL_PLAN_VARIABLES` row from `docs/feature-flags.md`. Grep the whole repo for `planVariables`, `RINGDRILL_PLAN_VARIABLES` and `debugPlanVariablesOverride` and confirm zero references remain in `lib/`, `test/`, `docs/` and CI. (Feature strings like the unknown-variable ARB placeholder are **not** flag references — keep those; only remove genuine flag plumbing.)

Commit: `chore: remove the RINGDRILL_PLAN_VARIABLES feature flag`.

### Step 6. Trim tests

Six test files drive the flag via `debugPlanVariablesOverride`: `test/views/program_form_screen_variables_declaration_test.dart`, `program_form_screen_variables_test.dart`, `exercise_form_screen_variables_test.dart`, `station_form_screen_variables_test.dart`, `roleplay_form_screen_variables_test.dart`, and any legacy-path assertions in `test/models/drill_variable_test.dart`. For each: drop the `debugPlanVariablesOverride: true` argument (the section-navigated form is now the default), and delete tests that asserted the legacy flag-off body renders. Update the `AppFlags.all` count test.

Run `flutter analyze`. `flutter test`.

Commit: `test: drop flag-toggle and legacy editor-path tests`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. Grep: zero references to `planVariables`, `RINGDRILL_PLAN_VARIABLES` or `debugPlanVariablesOverride` anywhere.
3. `dart build cli` succeeds; `make i18n` idempotent.
4. All four editors open as their section-navigated, variable-aware forms — no legacy body reachable.
5. Clean tree gate and diff sanity.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes the flag is gone and all four editors are single-path section-navigated forms. Remaining DESIGN-008 queue: follow-up 09 (display milestone — `RingDrillText` app-wide + token-aware name/description) and follow-up 10 (end-to-end QA + flipping ADR-0046/DESIGN-008 to Accepted).

ADR-0046 and DESIGN-008 are authoritative. Contained follow-up; no new ADR.
