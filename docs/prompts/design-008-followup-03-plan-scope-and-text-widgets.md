# DESIGN-008 follow-up 03 — PlanScope and the RingDrill text widgets

You are working in the RingDrill repository. Architectural follow-up to DESIGN-008. Read `docs/design/008-plan-variables-and-section-navigated-editor.md` and [ADR-0046](../adrs/0046-plan-variables.md) first. Stages 1–5 shipped: the model carries variables/overrides, `BriefRenderer` resolves them, and the flag-on Program editor is section-navigated with a token-aware `MarkdownSectionField` (colored `{{var.name}}` spans via `TokenTextEditingController`, insertion menu).

This follow-up lays the foundation for **variables in names and descriptions app-wide** by consolidating three scattered pieces and introducing a shared lookup, without yet touching the live-app display surfaces (those come in a later follow-up with real callers). Concretely:

1. One shared, pure `{{var.name}}` substitution helper (today the regex is duplicated in `brief_renderer.dart`, `token_text_editing_controller.dart` and `plan_variable_refs.dart`).
2. A `PlanScope` `InheritedWidget` exposing the active plan's declared variables via `.of(context)`, so fields stop being handed the variable list through constructors.
3. A `RingDrillTextField` (single-line) / `RingDrillTextArea` (multi-line) editor widget family that reads `PlanScope`, resolves the effective variables, and drives a `TokenTextEditingController`. `RingDrillTextArea` subsumes `MarkdownSectionField`.

## Architecture decisions (settled — follow them)

* **The field widget reads context, not the controller.** `TokenTextEditingController` stays a pure `ChangeNotifier`. The widget reads `PlanScope.of(context)` and any explicit `overrides` in its own `build`, computes the effective `List<VariableToken>`, and pushes it into the controller via the existing `variables` setter. Do **not** call `PlanScope.of` from inside `TextEditingController.buildTextSpan` — mixing inherited-widget dependencies with the controller's own notification lifecycle is the thing we are avoiding.
* **Display and edit are separate, by name.** This follow-up ships only the **edit** widgets (`RingDrillTextField` / `RingDrillTextArea`). The read-only display widget (`RingDrillText`, mirroring `Text`) is deliberately deferred until a live-UI surface actually consumes it — do not build it speculatively here.
* **No `RingDrillKind` enum.** Dropped by decision. Styling is theme + explicit params; the widgets take what they need directly.
* **Flag-off stays truly plain.** When a field is not token-aware, it renders a plain `TextFormField` and performs **no** `PlanScope` lookup, so the legacy path gains zero new dependencies.
* **Behavior-preserving.** The flag-on Program editor must look and behave exactly as it does today after the refactor. This is a consolidation, not a UX change.

## Ground rules

* The shared helper is pure Dart, Flutter-free (`BriefRenderer` and the CLI path depend on it transitively). `PlanScope` and the widgets are view-layer.
* Keep `BriefRenderer` a pure function — it uses the shared helper, not `PlanScope`.
* ARB + `make i18n` for any new strings. `make build` not needed (no model changes).
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Six steps, in order.

### Step 1. Shared substitution helper

Add a pure helper (co-locate with `lib/utils/plan_variable_refs.dart`, or a new `lib/utils/plan_variables.dart`): the canonical `{{var.<name>}}` `RegExp` and `String substitutePlanVariables(String text, Map<String, String> vars, {String Function(String name)? onUnknown})`. `onUnknown` lets the caller decide what an undeclared token becomes (the renderer passes the localized placeholder; other callers may leave it raw).

Update the three current owners to use this one source: `brief_renderer.dart` (`_substituteVariables` / `_varTokenPattern`), `token_text_editing_controller.dart` (`tokenPattern`), and `plan_variable_refs.dart` (its rename/count regex). Remove the "keep in sync by hand" duplication comments — there is now one definition.

Files expected: the helper file, `brief_renderer.dart`, `token_text_editing_controller.dart`, `plan_variable_refs.dart`, and a `test/utils/` test for the helper (declared, empty, undeclared-with/without `onUnknown`, whitespace tolerance).

Run `git status`. Commit: `refactor(utils): consolidate {{var}} substitution into one shared helper`.

### Step 2. PlanScope

Add `lib/views/widgets/plan_scope.dart`: an `InheritedWidget` carrying the active plan's declared variables (a `List<DrillVariable>`, or a thin immutable view of it) with a static `PlanScope.of(BuildContext)` and a `maybeOf`. `updateShouldNotify` compares the variable list so an unrelated ancestor rebuild does not churn the subtree. Document that it is provided in two situations: by an entity editor (seeded from its working registry, updated as the author edits) and, later, around the program-scoped routes for the live app.

Files expected: `plan_scope.dart` + a `test/views/` test (of returns the provided variables; updateShouldNotify only fires on a real change; maybeOf null outside a scope).

Run `git status`. Commit: `feat(views): add PlanScope inherited widget for the active plan's variables`.

### Step 3. The RingDrill text editor widgets

Add `lib/views/widgets/ringdrill_text_field.dart` with `RingDrillTextField` (single-line) and `RingDrillTextArea` (multi-line). Shared behavior:

* Take a `TextEditingController` (the caller owns it, as forms do today), a `label`, focus node, and the usual field params. `RingDrillTextArea` keeps the `expands` / min-max-lines behavior `MarkdownSectionField` has.
* A `bool tokenAware` (default `false`). When `false`, render a plain `TextFormField` — no `PlanScope` lookup, identical to the current plain field.
* When `true`: read `PlanScope.of(context)` plus an optional `overrides` map (the entity's `variableOverrides`), compute the effective `List<VariableToken>` (declared value overlaid by overrides, filtered to declared names — same rule as `BriefRenderer._effectiveVariables`), and push it into a `TokenTextEditingController` via its `variables` setter on build. Attach the existing insertion menu and the optional `onCreateVariable`.
* The controller the caller passes may be a `TokenTextEditingController` already; if the caller passes a plain controller in token-aware mode, document that token-aware fields require a `TokenTextEditingController`.

Because the widget re-pushes the effective list on every build, a `PlanScope` change (a variable added/renamed/valued) rebuilds the field and re-resolves the chips automatically — this replaces the manual per-controller refresh the Program editor does today (removed in Step 5).

Files expected: `ringdrill_text_field.dart` + `test/views/` widget tests (plain mode is a bare field with no menu; token-aware mode renders chips from `PlanScope`; adding a variable to the scope re-resolves an amber chip to blue on rebuild; `overrides` shadow declared values).

Run `git status`. Commit: `feat(views): add RingDrillTextField and RingDrillTextArea reading PlanScope`.

### Step 4. Subsume MarkdownSectionField

Replace `MarkdownSectionField` with `RingDrillTextArea`. Either delete it and migrate call sites, or leave a thin deprecated wrapper that forwards to `RingDrillTextArea` — pick whichever keeps the diff honest, and prefer outright migration if the call sites are few. `OptionalFieldSections` (the flag-off legacy path) uses `RingDrillTextArea(tokenAware: false)`, staying a plain field with no `PlanScope` dependency.

Files expected: `optional_field_sections.dart`, the removed/rewritten `markdown_section_field.dart`, and any other call sites.

Run `git status`. Commit: `refactor(views): replace MarkdownSectionField with RingDrillTextArea`.

### Step 5. Provide PlanScope from the Program editor

In `ProgramFormScreen`'s flag-on build, wrap the section-navigated body in a `PlanScope` seeded from the working `_variables`, updated whenever `_variables` changes (create/rename/delete/value-edit). The token-aware sections become `RingDrillTextArea(tokenAware: true)` and no longer receive an explicit `variables:` list — they read the scope. Remove the now-redundant imperative "push the rebuilt `VariableToken` list into each live `TokenTextEditingController`" plumbing added in Stages 4–5; the `PlanScope`-driven rebuild does it. Wire `onCreateVariable` and `overrides` (program scope has none) as before. This must be behavior-preserving — the editor works exactly as today.

Files expected: `program_form_screen.dart`.

Run `git status`. Commit: `refactor(views): drive Program editor token fields from PlanScope`.

### Step 6. Docs

Add a short **addendum** to `docs/adrs/0046-plan-variables.md`: the resolution surface now extends to names and descriptions (rendered via the shared helper), and the live-app lookup mechanism is `PlanScope` + the shared substitution helper, with editing via the `RingDrillText*` widget family. Update DESIGN-008's implementation section so it references the widget family and `PlanScope` rather than `MarkdownSectionField` alone. Keep ADR-0046 status `Proposed` (the owner flips it later); this is a scope note, not a re-decision.

Files expected: `docs/adrs/0046-plan-variables.md`, `docs/design/008-plan-variables-and-section-navigated-editor.md`.

Run `git status`. Commit: `docs: record PlanScope and name/description resolution surface in ADR-0046`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `make i18n` idempotent; `make build` not needed.
3. `dart compile exe bin/ringdrill.dart` (or `dart build cli`) succeeds — the shared helper stayed Flutter-free.
4. **Behavior-preserving.** The flag-on Program editor renders and behaves identically to before (declare, insert, chips, create-inline, rename, delete, save-block). Confirm via the existing Stage 3–5 tests still passing unchanged, plus a `--dart-define=RINGDRILL_PLAN_VARIABLES=true` smoke run.
5. **Flag-off untouched and dependency-free.** No `PlanScope` lookup on the legacy path; the plain field is byte-identical. Confirm by test.
6. **One regex.** Grep confirms a single `{{var}}` pattern definition; the three former copies now import it.
7. Clean tree gate and diff sanity as in the stage prompts.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that this consolidates variable substitution, introduces `PlanScope` and the `RingDrillTextField`/`RingDrillTextArea` family, retires `MarkdownSectionField`, and sets up (but does not yet wire) name/description resolution and the deferred `RingDrillText` display widget. Remaining DESIGN-008 queue after this: renderer resolves variables in name/description; migrate Exercise/Station/RolePlay editors (override tables + create-global plumbing); the `RingDrillText` display widget adopted app-wide; end-to-end QA; flag sunset; flip ADR-0046 and DESIGN-008 to Accepted.

ADR-0046 and DESIGN-008 are authoritative. The one settled deviation from earlier discussion is that the controller does not read `PlanScope` — the widget does. If subsuming `MarkdownSectionField` turns out to ripple into far more call sites than expected, stop and report before pressing on. Do not write a new ADR; the addendum to ADR-0046 covers it.
