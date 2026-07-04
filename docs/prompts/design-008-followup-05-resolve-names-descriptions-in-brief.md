# DESIGN-008 follow-up 05 — resolve variables in names and descriptions (brief only)

You are working in the RingDrill repository. Follow-up to DESIGN-008. Read [ADR-0046](../adrs/0046-plan-variables.md) (including the follow-up-03 addendum) and `docs/design/008-plan-variables-and-section-navigated-editor.md` first. Stages 1–5 and follow-ups 01–04 shipped: variables resolve in markdown fields, and follow-up 03 consolidated substitution into `lib/utils/plan_variables.dart` (`substitutePlanVariables`, `planVariableTokenPattern`).

## What this does

Extend `BriefRenderer` so `{{var.<name>}}` also resolves inside **entity names and descriptions**, not only markdown fields. Today those are placed into the render context raw, so a variable typed into a name would appear literally in the booklet. This is the **brief/reading path only** — it does not make the editor name fields token-aware, and it does not touch the live app UI (lists, coordinator, player). Those come with the display-widget step later, which is deliberately held back because names appear app-wide (ADR-0046 addendum). This step just makes the booklet correct if a name or description already contains a variable.

## Scope of "names and descriptions"

Every entity name and description the renderer already places in its context: `program.name`, `program.description`, `exercise.name`, `station.name` (the cleaned name), and `roleplay.name`. Each resolves at **its own scope's** effective variables (program for program fields, exercise-scope for the exercise name, station-scope for station and roleplay names), using the existing `_effectiveVariables` / `_programVariables` helpers.

## Ground rules

* `BriefRenderer` stays a pure function. Use the shared `substitutePlanVariables` from `lib/utils/plan_variables.dart` — do not add a second substitution path.
* **Substitution only, not full mustache, for names.** Names are not cross-reference content; run them through `substitutePlanVariables` (the `var.*` pass), not the `Template(...).renderString(...)` mustache pass. This avoids a stray brace in a name throwing or being mis-parsed. Apply the same to descriptions in this step (keep it to variable substitution; cross-references in descriptions are out of scope).
* **Anchors follow the resolved name.** TOC anchors (`exerciseAnchor`, `stationAnchor`) must be derived from the *resolved* name so the in-doc contents links still match the rendered headings. Resolve first, then anchor.
* **Same unknown placeholder** as the markdown path: pass `onUnknown: (name) => l10n.briefUnknownVariable(name)` so an undeclared token in a name renders the visible placeholder, consistent with fields. Declared-but-empty renders empty.
* **Not flag-gated.** Like Stage 2, this is the reading path and runs unconditionally (an imported plan may carry variables regardless of the local flag).
* **Behavior-preserving for plans without variables.** A plan with no variables must render byte-identically to before.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Two steps.

### Step 1. Resolve names and descriptions

In `lib/services/brief/brief_renderer.dart`:

* Program context: run `program.name` and `program.description` through `substitutePlanVariables` at program scope (`_programVariables(program)`), with the `briefUnknownVariable` `onUnknown`. Keep the existing "empty description → null" handling after substitution.
* Exercise context: resolve `exercise.name` at exercise scope (`_effectiveVariables(program, exercise: ex)`), and derive `exerciseAnchor` from the resolved name.
* Station context: resolve the cleaned station name at station scope (`_effectiveVariables(program, exercise: ex, station: st)`), and derive `stationAnchor` from the resolved name. Leave the `Nx) ` prefix stripping as-is, just resolve after it.
* RolePlay context: resolve `rp.name` at the station's scope.

Do not change how markdown fields are resolved. Do not run names through the mustache `Template` pass.

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`

Run `git status`. Commit: `feat(services): resolve plan variables in brief names and descriptions`.

### Step 2. Tests

Extend `test/services/brief/` :

* A variable in `program.name` resolves in the H1, and the plan title reads the value.
* A variable in `program.description` resolves in the subtitle.
* A variable in `exercise.name` resolves in the heading, and the TOC anchor matches the rendered heading (follow the anchor to the heading text).
* A variable in `station.name` and in `roleplay.name` resolves at station scope, including an exercise/station override shadowing the program default.
* An undeclared `{{var.x}}` in a name renders the `briefUnknownVariable` placeholder, not the literal token.
* A declared-but-empty variable in a name renders empty.
* A plan with no variables renders identically to before (reuse the DESIGN-004 golden if present, otherwise a before/after diff).

Run `flutter analyze`. `flutter test test/services/brief/`. Then the full suite.

Files expected in this commit:

* test file(s) under `test/services/brief/`

Run `git status`. Commit: `test(services): cover variable resolution in names and descriptions`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `dart build cli` (or `dart compile exe bin/ringdrill.dart`) succeeds — the renderer and shared helper stay Flutter-free.
3. **No-variable regression.** The standard fixture's brief is unchanged from before (golden or manual diff).
4. **Reading-path only.** No `AppFlags.planVariables` reference added; grep confirms.
5. `git diff --stat` since the prior tip touches only `lib/services/brief/…` and `test/services/brief/…` (no `lib/views/`, no live-UI files — this step does not touch the app display surfaces).
6. Clean tree gate and diff sanity as in the stage prompts.

## Deliverables

Two Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that the booklet now resolves variables in names and descriptions, that this is reading-path only, and that making the editor name/description fields token-aware and resolving names in the live app UI are held for the display-widget step (because names appear app-wide). Remaining DESIGN-008 queue after this: migrate Exercise/Station/RolePlay editors onto the shell (override tables + create-global plumbing); the `RingDrillText` display widget adopted app-wide; then token-aware name/description editing; end-to-end QA; flag sunset; flip ADR-0046 and DESIGN-008 to Accepted.

ADR-0046 and DESIGN-008 are authoritative. Contained follow-up; no new ADR.
