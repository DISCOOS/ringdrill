# DESIGN-008 follow-up 01 — edit a variable's value

You are working in the RingDrill repository. This is a small follow-up to DESIGN-008 ("Plan variables and the section-navigated editor"), after Stages 1–5 shipped on `design-008`. Read [ADR-0046](../adrs/0046-plan-variables.md) and the Stage 5 prompt (`docs/prompts/design-008-stage-5-implementation.md`) for context.

## The gap

The Variabler declaration section (`lib/views/widgets/variables_section.dart`) lets an author create, rename and delete variables, but **not edit a variable's value after creation**. The `⋮` row menu is `_VariableRowAction { rename, delete }` only. This is a dead end for the create-inline flow: "Opprett variabel «x»" makes a declared-but-empty variable (amber chip), and once that variable is referenced in a field it can neither be given a value (no value edit) nor deleted (delete is reference-guarded). It stays amber forever.

This follow-up adds value editing so the create-inline loop closes: create empty → reference → set value → chip turns blue.

## Design

Add an **"Endre verdi"** action to the row's `⋮` menu — not a per-row pencil (ADR-0031). It opens a small dialog pre-filled with the variable's current `value` and `hint`, with the `name` shown read-only (renaming stays a separate action; editing value must not change the name). On confirm, the working `DrillVariable` is replaced via `copyWith(value: …, hint: …)`, and the live `TokenTextEditingController`s are refreshed so a now-non-empty variable re-resolves from amber to blue without losing focus.

No reference rewrite is involved — the name is unchanged, so `{{var.name}}` tokens are untouched. This is purely a value/hint update. Everything stays inside the flag-on Program editor; no `AppFlags` change.

## Ground rules

* User-visible strings via ARB (`app_en.arb`, `app_nb.arb`), then `make i18n`. New strings: the "Endre verdi" menu label and the edit dialog's title. Reuse existing value/hint field labels where they already exist.
* Reuse the existing add-variable form. The summary of Stage 5 notes a shared name/value/hint form backing the "+ Ny variabel" dialog. Drive the edit dialog from the same form with the name field disabled/read-only, rather than writing a second form.
* Views + l10n + tests only. Do not touch `lib/models/`, `lib/services/`, `lib/utils/plan_variable_refs.dart`, or the flag-off path.
* No new lint suppressions. `flutter analyze` and `flutter test` before claiming green.

## Scope

Three steps, in order.

### Step 1. Add the edit action and dialog

In `lib/views/widgets/variables_section.dart`:

* Extend `_VariableRowAction` with `editValue` and add its `PopupMenuItem` ("Endre verdi"), above rename/delete or wherever reads best.
* Add an `onEditValue` callback to the section's constructor, symmetric with `onRename`/`onCreate`, carrying the variable and its new `value`/`hint` (or the updated `DrillVariable`).
* Open the shared name/value/hint form as an edit dialog: name read-only and not validated for uniqueness (it is unchanged), value and hint editable, seeded from the current variable. On confirm, invoke `onEditValue`.
* Update the class doc comment that currently says value editing is out of scope — it now is in scope.

Files expected in this commit:

* `lib/views/widgets/variables_section.dart`
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `lib/l10n/app_localizations*.dart`

Run `make i18n`. Run `git status`. Commit: `feat(views): add "Endre verdi" action to the Variabler section`.

### Step 2. Wire it into the Program editor

In `lib/views/program_form_screen.dart`, supply `onEditValue`: replace the matching entry in the working `_variables` list via `copyWith(value: …, hint: …)`, then rebuild the `List<VariableToken>` and push it into each live `TokenTextEditingController` (the same refresh path create/rename/delete already use), so chips re-resolve immediately. `_save()` already writes `_variables`, so no save-path change is needed.

Files expected in this commit:

* `lib/views/program_form_screen.dart`

Run `git status`. Commit: `feat(views): apply variable value edits and refresh token chips`.

### Step 3. Tests

Add/extend a test under `test/views/`:

* **Value edit round-trips.** Declare a variable with an empty value, reference it in a section (amber), edit its value via the row action, confirm; the popped `Program` has the new value, and the token chip re-resolves to the known (blue) state.
* **Name is untouched.** Editing value does not change the variable's `name` and does not rewrite `{{var.name}}` tokens.
* **Hint edits persist.** Editing the hint updates the stored `DrillVariable.hint`.
* **Closes the create-inline dead end.** Create-inline an empty variable, reference it, edit its value; it is no longer amber and never required a delete.

Run `flutter analyze`. `flutter test test/views/`. Then the full suite.

Files expected in this commit:

* new/edited test file(s) under `test/views/`

Run `git status`. Commit: `test(views): cover variable value editing`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures.
3. `make i18n` idempotent after commit. `make build` not needed.
4. `dart compile exe bin/ringdrill.dart` (or `dart build cli`) succeeds.
5. **Flag-off untouched.** No `--dart-define`: no Variabler section at all. Confirm by test or inspection.
6. **Blast-radius.** `git diff --stat main` (since Stage 5) touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`.
7. **Clean tree gate** and **diff sanity** as in the stage prompts.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that value editing closes the create-inline dead end and that the remaining DESIGN-008 queue is unchanged (migrate Exercise/Station/RolePlay editors onto the shell with override tables, end-to-end QA, flag sunset, then flip ADR-0046 and DESIGN-008 to Accepted).

ADR-0046 and DESIGN-008 remain authoritative. This is a contained follow-up; do not write a new ADR.
