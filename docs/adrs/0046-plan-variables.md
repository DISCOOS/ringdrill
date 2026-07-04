---
status: accepted
date: 2026-07-03
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0046: Plan-scoped variables with cascading value overrides

## Context and problem statement

The brief renderer already substitutes data into markdown at render time. A field such as `station.situationMd` can contain inline mustache like `{{station.position.utm}}`, resolved against the entity context ([DESIGN-004](../design/brief-template.md)). What it cannot express is an author-defined value that repeats across the plan: a radio channel, an operation name, a meeting point. Today those are typed by hand into every field that mentions them. When one changes, the author edits three to five places, the same fragmentation the brief was meant to remove.

We want author-defined **variables**: a value declared once and referenced from any markdown field, so editing it in one place updates every brief that uses it. A value that is usually the same across the plan but occasionally differs for one exercise (a channel that changes for the night exercise, say) must also be expressible without duplicating the variable.

This decision covers where variables live, how they are namespaced against the existing derived context, how per-exercise and per-station differences are modelled, how the format evolves, and what happens to references when a variable is renamed, deleted, or unresolved. The authoring surface (the section-navigated editor, the slash-menu insertion, the token chips) is specified in [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md); this ADR fixes the data model and the resolution and validation rules the UI relies on.

## Decision drivers

* One source of truth per variable. A reader of the plan should never have to reconcile two competing declarations of the same name.
* Simple, scope-independent validation. Whether a token is known must not depend on which entity's field it sits in.
* Support "usually X, sometimes Y" without a second variable, matching the `commsMd` program/exercise override already in DESIGN-004.
* Backward compatible with `.drill` schema 1.0–1.2, no migration, following the additive `@Default` pattern from [ADR-0043](./0043-tags-in-drill-format.md) and [ADR-0018](./0018-roleplayer-data-model.md).
* Variables are not PII. Carrying them inside `.drill` and publishing them is acceptable; keeping real personal data out is the author's responsibility (unlike `actors/`, ADR-0018).
* No new parser. Reuse the mustache engine already in `BriefRenderer`.

## Considered options

* **A: Global declaration on `Program`, per-scope value overrides on `Exercise`/`Station`.** A variable's *identity* exists only at plan level. Exercise and station may override its *value* for their subtree. Referenced as `{{var.<name>}}`.
* **B: Declaration at any scope.** Exercise and station may declare their own variables, visible only within their subtree.
* **C: Flat plan-level variables, no overrides.** One value per variable, no per-exercise difference.

## Decision outcome

Chosen option: **Option A**, because it delivers the "defaults plus local override" behaviour without the scoping machinery that option B forces on validation, autocomplete, and rename integrity.

### The model

A variable is declared once on `Program`:

```dart
@freezed
sealed class DrillVariable with _$DrillVariable {
  const factory DrillVariable({
    required String name,   // slug: ^[a-z][a-z0-9_]*$, unique within the plan
    @Default('') String value,   // the global default value
    String? hint,           // optional description shown in the picker
  }) = _DrillVariable;

  factory DrillVariable.fromJson(Map<String, dynamic> json) =>
      _$DrillVariableFromJson(json);
}
```

On `Program`, alongside `tags`:

```dart
@Default(<DrillVariable>[]) List<DrillVariable> variables,
```

`Exercise` and `Station` carry value-only overrides, keyed by variable name:

```dart
@Default(<String, String>{}) Map<String, String> variableOverrides,
```

An override key that does not name a declared variable is meaningless and is dropped on load. There is no declaration at exercise or station scope.

### Namespace

User variables are referenced as `{{var.<name>}}`. The `var.` prefix is what keeps them separate from the derived context (`{{exercise.name}}`, `{{station.position.utm}}`, `{{program.name}}`). A user variable can therefore never collide with a derived field, and the renderer can route a `var.*` lookup through the variable resolver while everything else stays on the existing entity context. The slash-menu picker offers both groups (see DESIGN-008), but only `var.*` names participate in the registry.

### Resolution

`{{var.frekvens}}` resolves at render time by walking the scope chain from the field outward: the station's `variableOverrides` if the field belongs to a station and the key is present, else the enclosing exercise's `variableOverrides`, else the program's declared `value`. The chain is built n-level from the start (program → exercise → station) so exposing a new override scope later is a UI change, not a model change.

### Validation

Two distinct states, deliberately not collapsed into one:

* **Undeclared reference** — `{{var.x}}` where `x` is not a declared variable. This is an error. It renders as a red token in the editor, and the form cannot be saved while any field contains one.
* **Declared but empty** — a declared variable that resolves to an empty string everywhere in the chain. This is a soft warning, not a block, because "blank default, filled per exercise" is a valid authoring state. It renders as an amber token and, in the brief, as a visible placeholder rather than mustache's silent empty string.

Validation is plan-global: a token is known if and only if its name is declared on `Program`, regardless of which entity's field contains it. This is the property option A buys and option B would cost.

### Rename and delete

Because the name is the reference, renaming is a refactor. Renaming a variable scans every markdown field in the plan and rewrites `{{var.old}}` to `{{var.new}}`, and rewrites override keys, behind a confirmation. Deleting a variable that is still referenced is blocked, with the referencing fields listed; deleting an unreferenced variable is immediate. Overrides for a deleted variable are removed with it.

### Format

No hard schema bump. `variables` and `variableOverrides` are additive fields with `@Default`, so 1.0–1.2 archives without the keys deserialize to empty, and older clients ignore the unknown keys, exactly as `tags` did in [ADR-0043](./0043-tags-in-drill-format.md). `KNOWN_SCHEMA_MAX` stays at `1.2`. `variables` and `variableOverrides` are short structural data and live in `program.json` (and the exercise/station JSON), not as `.md` files — they are not long-form prose, so [ADR-0022](./0022-markdown-content-as-files.md) does not apply. `ProgramX.computeContentHash` must include them so a variable change produces a new version.

### Consequences

* Good: One authoritative declaration per variable. Validation and the picker never depend on scope.
* Good: The override map gives per-exercise and per-station values with no second variable, reusing the DESIGN-004 `commsMd` override intuition.
* Good: Backward compatible, no migration, no schema-max coordination — same envelope as ADR-0043.
* Good: No new syntax or parser. `var.*` extends the existing mustache context.
* Bad: A variable used in only one exercise still occupies the plan-level list (declared with a blank default, overridden locally). Local-only declarations are deferred to option B if this proves noisy.
* Bad: Rename touches every field, so it needs a whole-plan scan and a confirmation step. Acceptable because rename is rare and the alternative is silent breakage.
* Bad: Publishing exposes variable values. Mitigated by an in-editor warning; enforcement is out of scope.

## Pros and cons of the options

### Option A — global declaration, per-scope overrides (chosen)
* Good: Scope-independent validation; single source of truth; override without a second variable.
* Good: Additive format, mustache reuse.
* Bad: One-exercise variables still sit in the plan list; rename is a plan-wide refactor.

### Option B — declaration at any scope
* Good: Exercise-specific variables do not touch the plan-level list.
* Bad: Visibility rules (a program field cannot see an exercise variable), scope-aware autocomplete, cross-scope rename/delete integrity, and scope-dependent validation. A large jump in complexity for a need option A covers with a blank default.

### Option C — flat, no overrides
* Good: Simplest possible model.
* Bad: Cannot express "usually X, sometimes Y" without duplicating the variable, the exact fragmentation this feature removes.

## Links

* Related design: [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md) (authoring surface, slash-menu, token chips), [DESIGN-004](../design/brief-template.md) (brief renderer, inline mustache, `commsMd` override precedent)
* Related ADRs: [ADR-0007](./0007-drill-file-format.md) (`.drill` format and schema evolution), [ADR-0022](./0022-markdown-content-as-files.md) (markdown as files — why variables are *not* files), [ADR-0043](./0043-tags-in-drill-format.md) (additive `@Default` field, no schema bump), [ADR-0018](./0018-roleplayer-data-model.md) (`@Default([])` backward-compat pattern), [ADR-0030](./0030-wide-screen-master-detail-layout.md) (master/detail the wide editor rides on)
* Related code: `lib/models/program.dart`, `lib/models/exercise.dart`, `lib/models/station.dart`, `lib/data/drill_file.dart`, `lib/services/brief/brief_renderer.dart`, `netlify/functions/drills-upload.js`
* Operating rule (in [`AGENTS.md`](../../AGENTS.md)): "Drill file format is versioned" and "schema bumps are coordinated changes"

## Addendum (2026-07-04): `PlanScope`, the resolution surface extends to names/descriptions, and the `RingDrillText*` widget family

DESIGN-008 follow-up 03 lays the groundwork for resolving `{{var.<name>}}` in **names and descriptions**, not just the long-form markdown fields this ADR originally scoped — a plan/exercise/station/roleplay name or a program description is just as plausible a place to reference "the operation name" as `briefIntroMd` is. This is a scope note on the *resolution surface*, not a re-decision of anything above: the model, namespace, resolution-chain and validation rules are unchanged.

**Shared substitution.** The `{{var.<name>}}` regex and substitution logic that `BriefRenderer` used were duplicated by hand into the editor's `TokenTextEditingController` and into `plan_variable_refs.dart`'s rename/count logic. All three now import one pure, Flutter-free source (`lib/utils/plan_variables.dart`): `planVariableTokenPattern`, `planVariableTokenPatternFor(name)`, and `substitutePlanVariables(text, vars, {onUnknown})`. `BriefRenderer` still resolves entirely server-side against its own scope-chain context — it does not read `PlanScope` (below); that is deliberately a view-layer mechanism only.

**`PlanScope`.** The live-app editing surface's lookup mechanism for "what variables exist, with what current values" is `lib/views/widgets/plan_scope.dart`'s `PlanScope`, an `InheritedWidget` carrying the working `List<DrillVariable>`. An entity editor provides one seeded from its own (possibly unsaved) registry, updated on every author edit; a later change will also provide one around the program-scoped live-app routes so read-only display can resolve variables too.

**Editing via `RingDrillTextField`/`RingDrillTextArea`.** `lib/views/widgets/ringdrill_text_field.dart` replaces the single-purpose `MarkdownSectionField` with a field family: `RingDrillTextField` (single-line, for names) and `RingDrillTextArea` (multi-line, subsuming `MarkdownSectionField`'s exact behavior). Both read `PlanScope` and an optional per-field `overrides` map when `tokenAware` is true, computing the effective chip states on every build instead of a caller manually pushing a rebuilt variable list into the field — and do **no** `PlanScope` lookup at all when `tokenAware` is false, so the flag-off legacy path stays exactly as before.

**Still deferred.** `RingDrillTextField` has no call site yet — actually wiring a name/description field to `tokenAware: true` (and updating `BriefRenderer` to substitute variables in `Exercise.name`/`Program.description`/etc., which it does not do today) is a later follow-up, as is the read-only display counterpart (`RingDrillText`, mirroring `Text`), deliberately not built until a live surface needs it. Migrating `Exercise`/`Station`/`RolePlay` editors onto the section-navigated shell (with override tables) is also still open.

ADR-0046's status remains `Proposed`.

## Addendum (2026-07-04): shipped on `design-008`, status Accepted

DESIGN-008 is fully implemented on `design-008`: the model above, `BriefRenderer` resolution for both markdown fields and names/descriptions, section-navigated editors for `Program`/`Exercise`/`Station`/`RolePlay` with override tables on `Exercise`/`Station`, token-aware fields including names/descriptions, live-app resolution via `PlanScope`/`RingDrillText`, and the `RINGDRILL_PLAN_VARIABLES` build flag removed. An end-to-end QA pass (`docs/notes/design-008-e2e-qa.md`) confirms the whole feature on one fixture plan, including a fix to `plan_variable_refs.dart`'s rename/delete-reference tracking, which the QA pass found had never been extended to the names/description surface the first addendum above added.

Deferred, intentionally, both revisit-if-needed rather than committed to: **local-only variables** (option B, if the plan-level list grows noisy with single-use variables) and **variable creation from sub-editors** (DESIGN-008's `VariablesSection` spec gives `Exercise`/`Station`'s override surface its own "+ Ny variabel" action with a record-based result contract; that surface-level create action was not built — the only create paths shipped are `Program`'s declaration surface and the slash-menu's inline "Opprett variabel «x»", both available everywhere including `Exercise`/`Station`/`RolePlay` fields).

This ADR's status is now `Accepted`.
