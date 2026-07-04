# DESIGN-008 follow-up 09 — display milestone (variables in names/descriptions, app-wide)

You are working in the RingDrill repository. Follow-up to DESIGN-008. Read [ADR-0046](../adrs/0046-plan-variables.md) (including the follow-up-03 addendum) and `docs/design/008-plan-variables-and-section-navigated-editor.md`. By the time this runs, the flag is gone (08), all four editors are section-navigated (06, 07), and `BriefRenderer` already resolves variables in names and descriptions in the booklet (05). What remains is the **live app UI**: names and descriptions still show raw `{{var.x}}` in lists, the coordinator, the player, map labels and share text, and the name/description editor fields are still plain. This milestone closes both.

## What this does

1. Add the read-only display widget `RingDrillText` (mirrors `Text`): given raw text, it resolves `{{var.name}}` via `PlanScope` + optional `overrides` using the shared `substitutePlanVariables`, and renders resolved text. No token chips (that is the editor). Non-`var` `{{...}}` is left as-is.
2. Provide `PlanScope` around the program-scoped routes so the active plan's declared variables are in scope wherever names render (ADR-0032 program-scoped routing is the natural place — the program is already activated there).
3. Adopt `RingDrillText` at the live-UI surfaces that display entity names and descriptions, passing the entity's effective `overrides` where the cascade matters (`effectivePlanVariables`).
4. Make the name/description editor fields token-aware now that display resolves them everywhere: `RingDrillTextField` for single-line names, `RingDrillTextArea` for multi-line descriptions, in all four editors' base sections. This gives `RingDrillTextField` its first call sites and lets authors insert variables into names via the slash menu.

## Ground rules

* `RingDrillText` reads `PlanScope.of(context)`; if there is no `PlanScope` ancestor (surfaces outside a program context), it must degrade to plain text (`maybeOf` → render raw), never throw.
* Use the shared `substitutePlanVariables` / `effectivePlanVariables` — no new resolution logic.
* Names/descriptions in the **brief** are already handled by the renderer (05); do not double-resolve there.
* Performance: resolution is a cheap regex over short strings, but do not rebuild the whole subtree per keystroke — `PlanScope.updateShouldNotify` already gates on the variable list.
* ARB + `make i18n` for any new strings. No model changes.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Five steps, in order.

### Step 1. RingDrillText

Add `lib/views/widgets/ringdrill_text.dart`: a read-only widget taking `text`, optional `overrides`, and the usual `Text` styling params (style, maxLines, overflow, textAlign). It resolves via `PlanScope.maybeOf(context)` + `substitutePlanVariables` and renders a `Text`. With no scope or no variables, it is exactly `Text(text, …)`. Undeclared tokens render the same placeholder policy as the brief (leave raw, or a subtle marker — match `substitutePlanVariables`'s default `onUnknown`, which should be "leave raw" for display so a broken token is visible but not noisy).

Files expected: `ringdrill_text.dart` + a `test/views/` test (resolves with scope + overrides; plain Text without scope; cascade via overrides).

Run `git status`. Commit: `feat(views): add RingDrillText read-only variable-resolving text`.

### Step 2. Provide PlanScope around program-scoped routes

Wrap the program-scoped route subtree (see ADR-0032 program-scoped routing / where the active `Program` is resolved) in a `PlanScope` seeded from the active plan's `variables`, so every descendant that shows a name/description can resolve. Keep it updating when the active program changes.

Files expected: the routing/shell file that owns the active program (e.g. `lib/views/main_screen.dart` or the program-scope wrapper).

Run `git status`. Commit: `feat(views): provide PlanScope around program-scoped routes`.

### Step 3. Adopt RingDrillText on live surfaces

Grep for where entity names and descriptions are rendered as `Text` and swap the ones inside a program context to `RingDrillText`, passing the entity's effective `overrides` where relevant (exercise/station names cascade; program name has none). Prioritise the high-traffic surfaces: program/exercise/station/roleplay list tiles, the coordinator, the drill player and mini-player, map marker labels, and share/copy text. It is acceptable to miss a rarely-seen label and follow up; cover the surfaces a user sees during normal authoring and running.

For share/copy-to-clipboard text (plain strings, no widget), resolve with `substitutePlanVariables` + `effectivePlanVariables` directly rather than the widget.

Files expected: the list/coordinator/player/map/share files touched.

Run `git status`. Commit: `feat(views): resolve variables in names and descriptions across the live UI`.

### Step 4. Token-aware name/description editor fields

In all four editors' base sections, replace the plain name field with `RingDrillTextField(tokenAware: true)` and the description field (where present) with `RingDrillTextArea(tokenAware: true)`, reading `PlanScope` and the entity's `overrides`. Extend save-time validation to include these fields (an undeclared token in a name blocks save, same rule as markdown fields). The slash menu and `{{` insertion now work in names/descriptions.

Files expected: `program_form_screen.dart`, `exercise_form_screen.dart`, `station_form_screen.dart`, `roleplay_form_screen.dart`.

Run `git status`. Commit: `feat(views): make name and description fields token-aware`.

### Step 5. Tests

Widget tests under `test/views/`:

* A list tile inside a `PlanScope` shows the resolved value for a name containing `{{var.x}}`; outside a scope it shows raw text (no throw).
* An exercise name with an exercise-scope override resolves to the overridden value in the list.
* The plan name field accepts a slash-inserted variable, and save is blocked on an undeclared token in a name.
* Share/copy text resolves variables.

Run `flutter analyze`. `flutter test`. Then the full suite.

Files expected: test files under `test/views/`.

Run `git status`. Commit: `test(views): cover live-UI name resolution and token-aware name fields`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual QA: put `{{var.operasjon}}` in a plan name, give the variable a value, and confirm it resolves in the plan list, the coordinator, the player and the share text — and in the brief. Remove the value and confirm the amber/empty behavior is sane. An undeclared token in a name blocks save.
4. No `PlanScope` lookup throws outside a program context (e.g. any global list) — degrades to plain text.
5. Clean tree gate and diff sanity.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that variables now resolve in names and descriptions across the whole app and can be authored there via the slash menu, giving `RingDrillTextField` its first call sites, and that only QA + flipping ADR-0046/DESIGN-008 to Accepted (follow-up 10) remains.

ADR-0046 and DESIGN-008 are authoritative. Contained follow-up; no new ADR.
