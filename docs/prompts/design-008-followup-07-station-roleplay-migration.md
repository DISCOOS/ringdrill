# DESIGN-008 follow-up 07 — Station and RolePlay editors on the shell

You are working in the RingDrill repository. Follow-up to DESIGN-008, the second of two editor-migration prompts. Read [ADR-0046](../adrs/0046-plan-variables.md), `docs/design/008-plan-variables-and-section-navigated-editor.md`, and follow-up 06 (`docs/prompts/design-008-followup-06-exercise-migration-override-table.md`) first. Follow-up 06 migrated `ExerciseFormScreen` onto the shell, added `VariableOverridesSection` and the shared `effectivePlanVariables` helper. This prompt migrates the remaining two editors on the same pattern.

## What each editor gets

* **`StationFormScreen`** — the same treatment as Exercise: section-navigated behind the flag; base **Post** section (name, position, and today's station fields); a **Variabler** override section (`VariableOverridesSection`, no creation) writing to `station.variableOverrides`; and one token-aware `RingDrillTextArea` section per active markdown field (`equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd`, `directorNotesMd`). The station's inherited baseline for the override table and the token fields' effective values are computed at **station scope**: `effectivePlanVariables(program, exercise: parentExercise)` for the inherited baseline (program overlaid by the enclosing exercise), and the working station overrides on top for the fields.
* **`RolePlayFormScreen`** — section-navigated behind the flag; base **Rolle** section (name, age, signalement, position, and today's fields); **no Variabler section** (a roleplay declares and overrides nothing — ADR-0046); token-aware `RingDrillTextArea` sections for `behavior`, `background`, `propsMd`. A roleplay resolves at its **station's** scope, so its fields get `effectivePlanVariables(program, exercise: parentExercise, station: parentStation)` as the read-only effective set (via `PlanScope` + the merged overrides passed as the fields' `overrides`).

Names stay plain in both (token-aware name editing is the display milestone). Flag-off renders today's forms verbatim.

## Ground rules

* Reuse everything from follow-up 06: `SectionNavigatedForm`, `VariableOverridesSection`, `RingDrillTextArea`, `PlanScope`, `effectivePlanVariables`, the flag-testing hook. Do not build new variable widgets.
* Both editors are **given** the plan's declared variables (read-only) and their parent context (the enclosing exercise for a station; the enclosing exercise and station for a roleplay) so the scope math is correct. Thread these from the call sites, which open these editors from a program/exercise context that has them.
* Station keeps returning a `Station`, RolePlay a `RolePlay`. No creation, no result-object.
* ARB + `make i18n` for the two new base-section labels ("Post", "Rolle") if not already present. Reuse the rest.
* Behavior-preserving flag-off. No model changes.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Four steps, in order.

### Step 1. Migrate StationFormScreen

Branch `build` on `AppFlags.planVariables`. Flag off: existing body verbatim. Flag on: `SectionNavigatedForm` in a `PlanScope` seeded from the injected declared variables, with the **Post** base section, a **Variabler** override section (inherited baseline = `effectivePlanVariables(program, exercise: parentExercise)`, working map = `station.variableOverrides`), and token-aware `RingDrillTextArea` sections for the eight markdown fields, each with `overrides:` = the working station overrides. Save writes `variableOverrides` alongside the existing `copyWith`. Save-time validation blocks on undeclared tokens in the station's token-aware fields. Thread `variables` + `parentExercise` from call sites.

Files expected: `lib/views/station_form_screen.dart` + its call sites.

Run `git status`. Commit: `feat(views): render StationFormScreen as a section-navigated form behind the flag`.

### Step 2. Migrate RolePlayFormScreen

Flag off: verbatim. Flag on: `SectionNavigatedForm` in a `PlanScope` seeded from the declared variables, with the **Rolle** base section and token-aware `RingDrillTextArea` sections for `behavior`, `background`, `propsMd`, each resolving at the roleplay's station scope (pass the merged `effectivePlanVariables(program, exercise:, station:)` result as the fields' `overrides`, or the declared set via `PlanScope` plus that scope's overrides — match how follow-up 06 wired the field `overrides`). **No Variabler section.** Save-time validation blocks on undeclared tokens. Thread `variables` + parent exercise/station from call sites.

Files expected: `lib/views/roleplay_form_screen.dart` + its call sites.

Run `git status`. Commit: `feat(views): render RolePlayFormScreen as a section-navigated form behind the flag`.

### Step 3. (If needed) call-site plumbing

If threading the declared variables and parent context into these editors requires touching intermediate widgets (e.g. the coordinator or a stations view that opens them), do it here in one focused commit rather than scattering it. Keep it to passing the already-available `Program`/parent objects down.

Files expected: the intermediate call-site files.

Run `git status`. Commit: `refactor(views): thread plan variables and parent scope into station/roleplay editors`.

(Fold this into Steps 1–2 if the call sites are trivial; skip the commit if so.)

### Step 4. Tests

Widget tests under `test/views/`:

* Station: override table shows the inherited value at station scope (program overlaid by the enclosing exercise), a local value writes to `station.variableOverrides`, a token-aware station field resolves at station scope (station override shadows exercise override shadows program default), save blocks on undeclared tokens, flag-off legacy path renders.
* RolePlay: token-aware fields resolve at the station's scope, there is no Variabler section, save blocks on undeclared tokens, flag-off legacy path renders, save round-trips.

Run `flutter analyze`. `flutter test test/views/`. Then the full suite.

Files expected: test files under `test/views/`.

Run `git status`. Commit: `test(views): cover station override table and roleplay token fields`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `make i18n` idempotent; `make build` not needed.
3. `dart build cli` succeeds.
4. Flag-off byte-identical for both editors (tests + smoke).
5. Flag-on manual QA: Station shows the override table with station-scope inherited values and resolves chips through the full cascade; RolePlay has token-aware fields and no Variabler section; both use the bottom-bar chrome (follow-up 04).
6. **All four editors now share the shell.** `git diff --stat` since the prior tip touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`. No model changes.
7. Clean tree gate and diff sanity.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that Program, Exercise, Station and RolePlay all render on the section-navigated shell now, with override tables on Exercise/Station and token-aware markdown fields throughout, creation still deferred. Remaining DESIGN-008 queue: the display milestone (`RingDrillText` app-wide + token-aware name/description editing so variables resolve in the live UI), end-to-end QA, flag sunset, and flipping ADR-0046 and DESIGN-008 to Accepted.

ADR-0046 and DESIGN-008 are authoritative. Contained follow-up; no new ADR.
