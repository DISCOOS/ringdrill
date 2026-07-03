# Implement DESIGN-008 Stage 2

You are working in the RingDrill repository. Implement Stage 2 of DESIGN-008 ("Plan variables and the section-navigated editor"). DESIGN-008 at `docs/design/008-plan-variables-and-section-navigated-editor.md` is the authoritative UX spec and [ADR-0046](../adrs/0046-plan-variables.md) is the authoritative data-model and resolution decision. Read both, plus the Stage 1 prompt at `docs/prompts/design-008-stage-1-implementation.md`, before starting. Stage 1 has shipped: `DrillVariable`, `Program.variables`, and `variableOverrides` on `Exercise` and `Station` exist and round-trip.

Stage 2 is the **renderer resolution layer**. It teaches `BriefRenderer` to resolve `{{var.<name>}}` tokens inside markdown fields, walking the scope chain station → exercise → program, and to render an undeclared variable as a visible placeholder instead of dropping it. No editor UI (Stages 3–5), no template asset change. When this stage ships, a plan that already carries variables and overrides renders correct values in the brief.

## Feature flag: not gated in this stage

Stage 2 is the **reading path**, not an authoring surface. Variable resolution runs unconditionally, **not** behind `RINGDRILL_PLAN_VARIABLES`. The flag gates the editor surfaces in Stages 3–5. The reasons: an imported or published `.drill` can contain variables regardless of the local build's flag, and resolving them is strictly better than rendering raw `{{var.x}}`; and resolution only changes output for fields that actually contain variable tokens, which no plan has until the flagged editor ships. Do not add a flag check to the renderer.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md` and follow every rule. The non-negotiable ones for this change:

* **The renderer stays a pure function** over the in-memory `Program`. Do not call `DrillFile.fromProgram` or `program()` from inside it.
* **Mobile-safe and CLI-safe.** `lib/services/brief/` must not introduce `dart:html` or `package:web`, and must not be imported from `bin/`. Verify with `rg "package:ringdrill/services" bin/`.
* **ARB, not hardcoded strings.** The unknown-variable placeholder is user-visible and localized. Add it to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`, then run `make i18n` (`flutter gen-l10n`). `make build` does **not** regenerate `app_localizations*.dart`. Do not hand-edit `app_localizations*.dart`.
* **No template asset change.** Variables resolve inside existing markdown field content. `assets/templates/ringdrill-standard-v1.*.md.mustache` is untouched in this stage.
* **Preserve existing cross-reference behavior.** `{{station.position.utm}}` inside `situationMd` must still resolve, and a field that throws on an unresolved non-variable expression must still fall back to its (now variable-substituted) raw content, exactly as the current `resolveField` catch does.
* **No new lint suppressions.** Run `flutter analyze` and `flutter test` before claiming green. A clean run is the expected baseline.

## Resolution model (from ADR-0046)

* **Effective value** of a variable in a scope is the nearest override walking outward: station's `variableOverrides` (station fields only) → enclosing exercise's `variableOverrides` → the program's declared `DrillVariable.value`.
* **Override keys are honoured only for declared variables.** An entry in `variableOverrides` whose key is not a declared `DrillVariable.name` is ignored.
* **Declared but empty** resolves to an empty string and renders as empty. This is a valid state, not an error. Do not placeholder it.
* **Undeclared** (`{{var.x}}` where `x` is not a declared variable) renders as a visible placeholder. It is never silently dropped.

## Scope

Four steps, in order.

### Step 1. Placeholder string

Add a localized placeholder for an undeclared variable. In `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`, add:

* `briefUnknownVariable` with a `name` placeholder. Suggested `en`: `‹missing variable: {name}›`. Suggested `nb`: `‹mangler variabel: {name}›`. Include the `@briefUnknownVariable` metadata block with the `name` placeholder description, matching the ARB conventions already in the file.

Run `make i18n`. Confirm `lib/l10n/app_localizations*.dart` regenerated and that `AppLocalizations.briefUnknownVariable(name)` exists.

Files expected in this commit:

* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`
* `lib/l10n/app_localizations.dart`
* `lib/l10n/app_localizations_en.dart`
* `lib/l10n/app_localizations_nb.dart`

Run `git status`. Commit: `feat(l10n): add unknown-variable placeholder string`.

### Step 2. Effective-variables and substitution helpers

In `lib/services/brief/brief_renderer.dart`, add top-level private helpers (with `@visibleForTesting` static wrappers on `BriefRenderer`, matching the pattern the file already uses for `exerciseNumber`, `formatUtm` and so on).

1. `Map<String, String> _programVariables(Program program)` — `{ for (final v in program.variables) v.name: v.value }`.
2. `Map<String, String> _effectiveVariables(Program program, {Exercise? exercise, Station? station})` — start from `_programVariables`, then overlay `exercise?.variableOverrides` and then `station?.variableOverrides`, **filtering each overlay to keys that are declared** (present in the program map). Later scopes win.
3. `String _substituteVariables(String content, Map<String, String> vars, AppLocalizations l10n)` — replace every `{{var.<name>}}` token with its effective value, or with `l10n.briefUnknownVariable(name)` when `<name>` is not in `vars`. The token regex must tolerate inner whitespace: `RegExp(r'\{\{\s*var\.([a-z][a-z0-9_]*)\s*\}\}')`. A declared-but-empty variable substitutes the empty string. Do not touch any other `{{...}}` expression — only `var.<name>`.

Substitution runs **before** the mustache pass, so that `{{station.position.utm}}` and other cross-references are still handled by the existing `Template(...).renderString(...)` call, and so an undeclared `{{var.x}}` becomes a placeholder rather than throwing. Document, in a comment, that a variable *value* which itself contains `{{...}}` is inserted literally and may be re-parsed by the subsequent mustache pass — authors should not put mustache syntax in variable values in v1.

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`

Run `git status`. Commit: `feat(services): add variable resolution helpers to BriefRenderer`.

### Step 3. Apply resolution at every scope

Wire the helpers into the context builders in `brief_renderer.dart`. Today only station-level fields pass through `resolveField`; exercise- and program-level fields are emitted raw. Fix that so variables resolve everywhere a markdown field can carry them.

Generalise the field resolver so it takes the scope's effective-variable map and an optional cross-reference context:

```dart
String? resolveField(
  String? content, {
  required Map<String, String> vars,
  Map<String, dynamic> refContext = const {},
}) {
  if (content == null) return null;
  final withVars = _substituteVariables(content, vars, l10n);
  try {
    return Template(withVars, htmlEscapeValues: false).renderString(refContext);
  } catch (_) {
    return withVars;
  }
}
```

Apply it:

* **Program fields** (scope: program vars, empty refContext): `briefIntroMd`, `commsMd`. Also resolve `beforeRoundMd` at program scope **before** it is embedded inside `_organisationBlock` (the block assembles `beforeRoundMd` into a buffer today — substitute variables into that content there, threading `program` and `l10n` in).
* **Exercise fields** (scope: `_effectiveVariables(program, exercise: ex)`, empty refContext): `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, and `effectiveCommsMd`. Resolve `effectiveCommsMd` once at exercise scope and pass the resolved string down to stations (as it already is).
* **Station fields** (scope: `_effectiveVariables(program, exercise: ex, station: st)`, refContext = the existing `stationRefContext`): every `*Md` field currently going through `resolveField`.
* **RolePlay fields** (scope: the station's effective vars, since a roleplay is enacted at a station): `behavior`, `background`, `propsMd`.

Keep audience gating exactly as-is: `directorNotesMd` and actor PII visibility do not change. `effectiveCommsMd` fallback (`exercise.commsMd ?? program.commsMd`) is unchanged; only its resolution is added.

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`

Run `git status`. Commit: `feat(services): resolve plan variables across program, exercise and station fields`.

### Step 4. Tests

Extend `test/services/brief/brief_renderer_test.dart` (or add a focused `brief_renderer_variables_test.dart` alongside it — match the existing layout). Drive the real `BriefRenderer.render` path with a test `AppLocalizations`. Cover:

* **Cascade resolution.** Declare `frekvens` on the program (`Kanal 6`), override it on an exercise (`Kanal 8`), and override it again on one station (`Kanal 9`). A program field renders `Kanal 6`, an exercise field renders `Kanal 8`, that station's field renders `Kanal 9`, and a sibling station with no override renders `Kanal 8` (inherits the exercise).
* **Undeclared token placeholders.** A field containing `{{var.mangler}}` renders `‹mangler variabel: mangler›` (the `nb` string) and never the literal `{{var.mangler}}`.
* **Declared but empty.** A variable declared with an empty value renders as empty, not as a placeholder. Assert the surrounding text renders and the placeholder string is absent.
* **Undeclared override key ignored.** An exercise `variableOverrides` entry whose key is not declared on the program does not leak into the output and does not shadow anything.
* **Coexists with cross-references.** A `situationMd` containing both `{{var.frekvens}}` and `{{station.position.utm}}` resolves both.
* **Resolution reaches every scope.** One test asserting a variable resolves in a program field, an exercise field, a station field and a roleplay field, since Stage 2 newly extends resolution beyond stations.
* **No-variable plans are unchanged.** A fixture with no variables and no overrides renders byte-for-byte identically to the pre-Stage-2 output for the same input (guards against the new exercise/program `resolveField` pass altering existing briefs). Reuse the DESIGN-004 fixture if a golden exists.

Run `flutter analyze`. Run `flutter test test/services/brief/`. Then the full suite once.

Files expected in this commit:

* the new/edited test file(s) under `test/services/brief/`

Run `git status`. Commit: `test(services): cover variable resolution, cascade and unknown/empty states`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures.
3. `make i18n` leaves no diff when run again after committing (proves the committed generated localizations are current). `make build` is not needed in this stage — no `@freezed`/`json_serializable`/enum changes.
4. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds. Catches any accidental Flutter import in the service or its new deps.
5. **No-variable regression.** The DESIGN-004 director/participant/instructor briefs for the standard fixture are unchanged from before this stage. If a golden test exists, it still passes untouched; if not, diff the rendered output manually before and after.
6. **Reading-path only.** Grep confirms the renderer contains no `AppFlags.planVariables` reference — Stage 2 is not flag-gated by design.
7. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`, and `git ls-files --others --exclude-standard` prints nothing.
8. **Diff sanity.** `git log --stat origin/main..HEAD` — walk every changed path and confirm each file sits in the commit you intended, generated localizations included.

## Deliverables

A series of Conventional Commits (English) on the `design-008` branch, clean tree at the end. The final commit body summarises that the renderer now resolves `{{var.name}}` across all scopes with cascading overrides and a visible placeholder for undeclared names, and defers Stages 3–5 (section-navigated editor, token-aware field, variables section). Note whether the no-variable regression check was done against a golden test or a manual diff.

ADR-0046 and DESIGN-008 are authoritative. If resolution forces a change to the template asset, or if the substitute-before-mustache ordering causes a real problem with variable values containing braces, stop and ask rather than deviating. Do not write a new ADR for this stage.
