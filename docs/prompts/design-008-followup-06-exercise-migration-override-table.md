# DESIGN-008 follow-up 06 — Exercise editor on the shell + override table

You are working in the RingDrill repository. Follow-up to DESIGN-008. Read [ADR-0046](../adrs/0046-plan-variables.md) and `docs/design/008-plan-variables-and-section-navigated-editor.md` first. Stages 1–5 and follow-ups 01–05 shipped: the model carries `variableOverrides` on `Exercise`/`Station`, `BriefRenderer` resolves variables (including in names/descriptions), and the flag-on **Program** editor is section-navigated with `PlanScope`, `RingDrillTextArea` (token-aware) and a `VariablesSection` (declaration).

This is the first of two editor-migration prompts. It migrates **`ExerciseFormScreen`** onto the section-navigated shell, introduces the reusable **override table** (a `VariableOverridesSection`), and adds a shared **effective-variables** helper. Follow-up 07 then does Station (reusing the override table) and RolePlay.

## Superseding note — no feature flag

The `RINGDRILL_PLAN_VARIABLES` flag is removed in follow-up 08, which runs **before** this prompt. Ignore every flag-gating instruction below: do **not** branch on `AppFlags.planVariables` and do **not** keep a legacy body. Wherever this prompt says "flag off = legacy / flag on = section-navigated", render the section-navigated form **unconditionally** and delete the old `ExerciseFormScreen` body. `PlanScope` is always provided. Everything else in the prompt stands.

## Settled scope (from the design dialogue)

* **No variable creation in sub-editors.** Exercise can *override* declared variables and *reference* them; it cannot create, rename, delete or default-edit globals. So the override section has **no "+ Ny variabel"**, and `ExerciseFormScreen` keeps returning an `Exercise` (no result-object contract).
* **Variabler section = override table only** on Exercise. It lists the plan's declared variables with their inherited value and lets the author set a per-exercise local value. Writes only to `exercise.variableOverrides`.
* **Markdown fields become token-aware**, reading `PlanScope` + the exercise's overrides. **Names stay plain** in this step — token-aware name/description editing is held for the display milestone (names appear app-wide).
* Flag-gated exactly like the Program editor: flag off renders today's `ExerciseFormScreen` verbatim; flag on renders the section-navigated form.

## Ground rules

* User-visible strings via ARB, then `make i18n`. Reuse existing `formSection*` and the "Variabler" label; add strings for the override table (inherited-value hint, local-value label, empty state "Ingen variabler i planen ennå").
* The Exercise editor must be **given** the plan's declared variables (read-only) by its caller — it edits an Exercise, not the Program. Thread `List<DrillVariable> variables` in as a constructor param and pass it from every call site (they open the exercise editor from a program context that has the active `Program`).
* Behavior-preserving flag-off. The existing save path, `generateSchedule` regeneration and `variableOverrides` preservation (Stage 1) stay intact.
* No model changes. Views + utils + l10n + tests.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Four steps, in order.

### Step 1. Shared effective-variables helper

The override table needs, per declared variable, the value that applies at the parent scope **without** a local override (the inherited baseline), and the token fields need the full effective map. `BriefRenderer` already computes this privately (`_effectiveVariables`). Promote it to the shared pure util (`lib/utils/plan_variables.dart`): `Map<String, String> effectivePlanVariables(Program program, {Exercise? exercise, Station? station})` — program declared values overlaid by exercise then station overrides, filtered to declared names (ADR-0046). Refactor `BriefRenderer` to use it (behavior-preserving, its own tests must still pass unchanged).

Files expected: `lib/utils/plan_variables.dart`, `lib/services/brief/brief_renderer.dart`, `test/utils/` for the helper.

Run `git status`. Commit: `refactor(utils): add shared effectivePlanVariables helper`.

### Step 2. The override table

Add `lib/views/widgets/variable_overrides_section.dart` — `VariableOverridesSection`. Given the plan's declared variables, the inherited value per variable (the parent-scope effective value), and the current `variableOverrides` map, it renders one row per declared variable: the name, the inherited value shown dimmed, and a local-value field. An empty local field means "inherit" (the key is absent from the map); typing a value sets the override; clearing it reverts to inherit. No add/rename/delete. If the plan has no declared variables, show the empty state. The parent form owns the working overrides map and the `onChanged` callback.

Files expected: `variable_overrides_section.dart`, ARB + regenerated localizations, a `test/views/` widget test.

Run `make i18n`. Run `git status`. Commit: `feat(views): add VariableOverridesSection override table`.

### Step 3. Migrate ExerciseFormScreen behind the flag

Branch `build` on `AppFlags.planVariables`.

* **Flag off:** the existing body, verbatim.
* **Flag on:** a `SectionNavigatedForm` wrapped in a `PlanScope` seeded from the injected `variables`:
  * **Øvelse** (default, not removable): the base fields — name and the scheduling inputs (teams, rounds, stations, times) exactly as today.
  * **Variabler** (not removable): `VariableOverridesSection` bound to a working copy of `exercise.variableOverrides`, with the inherited baseline = `effectivePlanVariables(program, )` at program scope (i.e. declared defaults) and the row values from the working overrides. Icon consistent with the Program editor's Variabler section.
  * One section per **active** markdown field (`methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`), body = `RingDrillTextArea(tokenAware: true)` over the field's `TokenTextEditingController`, with `overrides:` = the working exercise overrides so chips resolve at exercise scope. `removable: true`, "Legg til seksjon" for the inactive ones.
* Save writes `variableOverrides: <working map>` alongside the existing `copyWith`, and the existing `generateSchedule`-then-reapply flow is preserved (thread the working overrides through, as Stage 1 established).
* Save-time validation, same rule as the Program editor: block on an undeclared `{{var.x}}` in the editor's token-aware fields, naming the offending section. (Undeclared can arise from a raw-typed token; creation is deferred, so the only fix is to declare it in the Program editor or remove it — surface that in the message.)

Thread `variables` from every `ExerciseFormScreen` call site (pass `program.variables`).

Files expected: `lib/views/exercise_form_screen.dart` and its call sites.

Run `git status`. Commit: `feat(views): render ExerciseFormScreen as a section-navigated form behind the flag`.

### Step 4. Tests

Widget tests under `test/views/` (make the flag testable the same way the Program editor did, e.g. a `debugPlanVariablesOverride`):

* Override table lists declared variables with inherited values; setting a local value writes it to `variableOverrides` on save; clearing reverts to inherit.
* A token-aware exercise field resolves a variable to its exercise-scope value (override shadows the program default).
* Save is blocked on an undeclared token; declaring it (seeded) or removing it unblocks.
* Flag-off renders the legacy exercise form (assert a legacy marker).
* Save round-trips: base fields + an override + a markdown field produce the expected `Exercise`, and `generateSchedule` regeneration preserves the overrides.

Run `flutter analyze`. `flutter test test/views/ test/utils/`. Then the full suite.

Files expected: test files under `test/views/`.

Run `git status`. Commit: `test(views): cover the exercise override table and token-aware fields`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `make i18n` idempotent; `make build` not needed.
3. `dart build cli` succeeds — `effectivePlanVariables` stays Flutter-free.
4. Flag-off byte-identical exercise editor (test + smoke).
5. Flag-on manual QA (`--dart-define=RINGDRILL_PLAN_VARIABLES=true`): the exercise editor is section-navigated with the bottom bar (follow-up 04), the override table shows inherited values and accepts local ones, markdown chips resolve at exercise scope, save blocks on undeclared tokens.
6. `git diff --stat` since the prior tip touches only `lib/views/…`, `lib/utils/…`, `lib/services/brief/brief_renderer.dart`, `lib/l10n/…`, `test/…`. No model changes; Station/RolePlay forms untouched (follow-up 07).
7. Clean tree gate and diff sanity.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that Exercise is migrated with an override-only Variabler section and token-aware markdown fields, that creation stays deferred (editor returns an `Exercise`), and that Station + RolePlay follow in follow-up 07, then the display milestone (names/descriptions app-wide), QA, flag sunset, and flipping ADR-0046/DESIGN-008 to Accepted.

ADR-0046 and DESIGN-008 are authoritative. Contained follow-up; no new ADR.
