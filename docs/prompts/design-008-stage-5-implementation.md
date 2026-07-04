# Implement DESIGN-008 Stage 5

You are working in the RingDrill repository. Implement Stage 5 of DESIGN-008 ("Plan variables and the section-navigated editor"), the final stage. DESIGN-008 at `docs/design/008-plan-variables-and-section-navigated-editor.md` is the authoritative UX spec; [ADR-0046](../adrs/0046-plan-variables.md) is the data-model decision. Read both, plus the Stage 1–4 prompts, before starting.

Shipped in Stages 1–4: the model carries `Program.variables` and per-scope `variableOverrides`; `BriefRenderer` resolves `{{var.name}}` with cascading overrides; `ProgramFormScreen` renders on the section-navigated shell behind `RINGDRILL_PLAN_VARIABLES`; `MarkdownSectionField` is token-aware (colored/boxed `{{var.name}}` tokens, blue/amber/red, via `TokenTextEditingController`), with a `/` and `{{` insertion menu and a dormant `onCreateVariable` hook.

Stage 5 is the **Variabler declaration section, the create-inline wiring, and save-time validation** — the pieces that let an author actually declare, rename and delete variables and be stopped from saving a broken reference. It completes the feature **within the Program editor scope**.

## Scope split (read this)

The per-exercise and per-station **override tables** DESIGN-008 describes are **out of scope here**, because `ExerciseFormScreen` and `StationFormScreen` are not on the section-navigated shell yet (that is the deferred Stage 3 follow-up). Overrides already resolve at render time (Stage 2), so they light up for free when those editors are later migrated and given an override section. This stage delivers the **declaration** surface on `Program`, plus everything needed to author variables end-to-end in the Program editor: declare, create-inline, rename, delete, and save-blocking on undeclared tokens.

Everything new is mounted only inside the flag-on Program editor, or is a pure helper harmless when unused. No `AppFlags` change; the flag-on editor is the only caller.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md`. Non-negotiable here:

* **User-visible strings via ARB**, then `make i18n`. Many new strings (section label "Variabler", "Ny variabel", name/value/hint labels, the invalid-slug and duplicate-name errors, the rename confirmation, the delete-blocked message with usage list, the save-blocked message, the "publiseres med planen" note, "Opprett variabel «{name}»"). Norwegian is the shipped `nb`. Section label is **"Variabler"**.
* **Rename and delete are plan-wide (ADR-0046).** A variable is plan-global and can be referenced from any markdown field and any override map. Rename must rewrite `{{var.old}}` → `{{var.new}}` in **every** markdown field of the whole `Program` (program, every exercise, every station, every roleplay) and rename the key in **every** `variableOverrides` map. Delete is blocked while the variable is referenced anywhere in the plan. These operate on the in-memory `Program`; the editor must be working on a program whose markdown fields are loaded (they are, for the sections the editor shows; nested exercise/station markdown must also be present for the rewrite to be complete — assert this and, if a field is absent, treat it as "no reference" rather than crashing).
* **Save-blocking scope is the editor's own fields (not the whole plan).** Blocking save because of an undeclared token in a station field the user cannot see or fix in this editor would be a dead end. Validate the token-aware fields this editor actually edits (the Program-level markdown sections), and block save when any contains an undeclared `{{var.x}}`. Rename/delete integrity still walks the whole plan; only save-validation is scoped to the open fields. State this split in a code comment.
* **Slug rule.** Variable `name` must match `^[a-z][a-z0-9_]*$` and be unique within the plan. Enforce on create and rename.
* **Row-affordance rule ([ADR-0031](../adrs/0031-row-edit-affordances.md)).** Rename and delete are actions in a row's overflow/menu, not a pencil.
* **No new lint suppressions.** `flutter analyze` and `flutter test` before claiming green.

## Scope

Six steps, in order.

### Step 1. Plan-wide reference helpers

Add a pure, Flutter-free helper (e.g. `lib/utils/plan_variable_refs.dart`) operating on `Program`:

* `int variableReferenceCount(Program program, String name)` — counts `{{var.<name>}}` occurrences across every markdown field (program `briefIntroMd`/`commsMd`/`beforeRoundMd`, each exercise's `*Md`, each station's `*Md`, each roleplay's `behavior`/`background`/`propsMd`) plus every appearance of `name` as a key in any `variableOverrides` map.
* `List<String> variableReferences(Program program, String name)` — human-readable locations for the delete-blocked message (e.g. "Øvelse 3 › Metode", "Post 3a › Situasjon", "Kommunikasjon"). Localize the field labels via ARB.
* `Program renameVariable(Program program, String oldName, String newName)` — returns a copy with `{{var.oldName}}` rewritten to `{{var.newName}}` in every markdown field (use the same `tokenPattern` shape), the entry in `program.variables` renamed, and the key renamed in every `variableOverrides` map. Uses `copyWith` throughout; does not mutate.

Reuse the `{{var.<name>}}` regex shape already duplicated in `token_text_editing_controller.dart` and `brief_renderer.dart` — three copies now; add a `// keep in sync` comment referencing the others.

Files expected in this commit:

* `lib/utils/plan_variable_refs.dart`
* `test/utils/plan_variable_refs_test.dart` (unit-test count, references and rename across program/exercise/station/roleplay/override scopes — pure, fast)

Run `git status`. Commit: `feat(utils): add plan-wide variable reference count, list and rename`.

### Step 2. The Variabler declaration section

Add the declaration widget (e.g. `lib/views/widgets/variables_section.dart`). It edits a working `List<DrillVariable>` owned by the parent form (mirroring how `_TagsEditor` and `_activeSections` are owned by `ProgramFormScreen`).

* A row per declared variable: monospace `name`, its `value`, and a `⋮` menu with "Gi nytt navn" and "Slett".
* "+ Ny variabel" adds a variable — captures `name` (validated slug, unique), `value`, optional `hint`. On create the value is the global default (ADR-0046).
* "Gi nytt navn" edits the name; on confirm it calls back to the parent so the parent can run `renameVariable` over the whole working `Program` (Step 1) and refresh the token controllers.
* "Slett": if `variableReferenceCount > 0`, show the blocked message listing `variableReferences`; otherwise remove.
* A single amber note at the top: *"Publiseres med planen. Ikke legg inn reelle persondata."*

Match `docs/design/mockups/variables-mobile.html` state 4.

Files expected in this commit:

* `lib/views/widgets/variables_section.dart`
* ARB files + regenerated `app_localizations*.dart`

Run `make i18n`. Run `git status`. Commit: `feat(views): add Variabler declaration section`.

### Step 3. Mount the section in the flag-on Program editor

In `ProgramFormScreen`'s flag-on build, add a **Variabler** `FormSection` to the switcher, positioned between "Plan" and the markdown sections (DESIGN-008), not removable. Its body is the Step 2 widget bound to a working `_variables` list seeded from `widget.program.variables`. `_save()` writes `variables: _variables` via `copyWith` alongside the existing fields.

The token-aware markdown sections already receive `variables:` (Stage 4). Rebuild the `List<VariableToken>` passed to them from `_variables` whenever it changes (add/rename/delete/create), and push it into each live `TokenTextEditingController` via its `variables` setter so chips re-resolve without losing focus.

Files expected in this commit:

* `lib/views/program_form_screen.dart`

Run `git status`. Commit: `feat(views): mount Variabler section in the flag-on Program editor`.

### Step 4. Wire create-inline

Supply the `onCreateVariable` callback (dormant since Stage 4) to the token-aware sections. When the insertion menu's "Opprett variabel «x»" fires, add a new `DrillVariable(name: x, value: '')` to `_variables` (x already matches the slug rule since it came from a `{{var.x}}`-style filter — validate anyway), refresh the token list (Step 3), and insert the `{{var.x}}` token. A newly created variable is declared-but-empty, so it renders as an amber chip until the author gives it a value in the Variabler section — that is the intended nudge, not an error.

Files expected in this commit:

* `lib/views/program_form_screen.dart` (and the menu/field wiring if any param plumbing is needed)

Run `git status`. Commit: `feat(views): wire inline create-variable from the insertion menu`.

### Step 5. Save-time validation

Block save when any token-aware field **this editor edits** contains an undeclared `{{var.x}}`. Add a `FormField`/validator or an explicit pre-save scan over the Program-level markdown section controllers: collect every `{{var.<name>}}`, flag names not in `_variables`. On block, keep the form open, surface which section(s) offend (reuse the field labels), and do not pop. Declared-but-empty (amber) never blocks. Undeclared (red) blocks. Match the chip state semantics from Stage 4.

Files expected in this commit:

* `lib/views/program_form_screen.dart`

Run `git status`. Commit: `feat(views): block save on undeclared variable tokens in edited fields`.

### Step 6. Tests

Add widget tests under `test/views/` (the pure helper is already tested in Step 1).

* **Declare and save.** Add a variable in the Variabler section, reference it in a markdown section, save; the popped `Program` has the variable in `variables` and the raw `{{var.x}}` in the field.
* **Create-inline.** Trigger "Opprett variabel «x»" from the menu; assert `_variables` gains `x` with empty value, the token is inserted, and its chip renders amber (declared-empty).
* **Rename rewrites references.** Declare `frekvens`, reference it in two sections, rename to `kanal`; assert both fields now read `{{var.kanal}}` and the registry entry is renamed. Drive `renameVariable` through the section's rename action.
* **Delete blocked when referenced.** Referenced variable: delete shows the blocked message and the variable survives. Unreferenced variable: delete removes it.
* **Save blocked on undeclared token.** Put `{{var.mangler}}` in a section with no such declaration; Save is blocked, the form stays open, the offending section is named. Declaring `mangler` then unblocks save.
* **Empty variable does not block.** A declared, empty variable referenced in a field saves fine.
* **Slug/uniqueness.** Creating `1bad` or a duplicate name is rejected with the right error.

Run `flutter analyze`. `flutter test test/views/ test/utils/`. Then the full suite.

Files expected in this commit:

* new/edited test files under `test/views/`

Run `git status`. Commit: `test(views): cover declaration, create-inline, rename, delete and save validation`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures.
3. `make i18n` idempotent after commit. `make build` not needed (no model/enum changes — `DrillVariable` already exists).
4. `dart compile exe bin/ringdrill.dart` (or `dart build cli`) succeeds — `plan_variable_refs.dart` must stay Flutter-free.
5. **Flag-off untouched.** No `--dart-define`: no Variabler section, no validation, legacy form. Confirm by test.
6. **Flag-on manual QA** (`--dart-define=RINGDRILL_PLAN_VARIABLES=true`), recorded per convention (widget tests plus simulator where feel matters, per the Stage 3/4 note): declare a variable, insert it (chip blue once it has a value), create one inline (amber until valued), rename it and watch references update, try to delete a referenced one (blocked), try to save with an undeclared token (blocked).
7. **Blast-radius.** `git diff --stat main` (since Stage 4) touches only `lib/views/…`, `lib/utils/…`, `lib/l10n/…`, `test/…`. No `lib/models/` or `lib/services/` changes; Exercise/Station/RolePlay forms untouched.
8. **Clean tree gate** and **diff sanity** as before.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body summarises that the Program-scope variable feature is complete behind the flag (declare, create-inline, rename with plan-wide rewrite, delete with reference guard, save-blocking on undeclared tokens), and lists what remains before the flag can be removed: migrating `ExerciseFormScreen`/`StationFormScreen`/`RolePlayFormScreen` onto the section-navigated shell and adding their override tables (the deferred Stage 3 follow-ups), then an end-to-end QA pass and the flag sunset. Note that ADR-0046 and DESIGN-008 should flip from `Proposed` to `Accepted` once the owner signs off.

DESIGN-008 and ADR-0046 are authoritative. If the plan-wide rename proves unsafe because a working `Program` in the editor lacks loaded nested markdown, stop and ask rather than rewriting a partial plan. Do not write a new ADR for this stage.
