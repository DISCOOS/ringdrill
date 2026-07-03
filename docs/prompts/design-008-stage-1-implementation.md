# Implement DESIGN-008 Stage 1

You are working in the RingDrill repository. Implement Stage 1 of DESIGN-008 ("Plan variables and the section-navigated editor") end-to-end. DESIGN-008 at `docs/design/008-plan-variables-and-section-navigated-editor.md` is the authoritative UX spec, and [ADR-0046](../adrs/0046-plan-variables.md) is the authoritative data-model decision. Read both before starting.

Stage 1 is the **model layer only**, plus the feature flag every later stage hangs off. It registers the `RINGDRILL_PLAN_VARIABLES` flag (default off), introduces the `DrillVariable` type, adds the plan-global registry to `Program`, adds per-scope value overrides to `Exercise` and `Station`, and makes sure the new fields survive schedule regeneration and participate in the content hash. No renderer resolution (Stage 2), no editor UI (Stages 3–5). When this stage ships, a `.drill` file can carry variables and overrides round-trip, older files still load, and the whole feature is invisible until later stages light up behind the flag — so this can merge to `main` and be developed in parallel with other work.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md` and follow every rule. The non-negotiable ones for this change:

* **Regenerate after model changes.** Any edit to a `@freezed` class or a `json_serializable` model requires `make build`. Never hand-edit `*.freezed.dart` or `*.g.dart`. Commit the regenerated files alongside the source.
* **Models stay Flutter-free.** `Program`, `Exercise`, `Station` and the new `DrillVariable` are all reachable from `bin/ringdrill.dart` transitively. Do not import `package:flutter/*`, `dart:html` or `package:web` from anything under `lib/models/`. Verify with `rg "package:flutter" lib/models/`.
* **Backward compatibility, no schema bump.** `variables` and `variableOverrides` are additive fields declared with `@Default`, exactly like `tags` in [ADR-0043](../adrs/0043-tags-in-drill-format.md) and `rolePlays`/`actors` in [ADR-0018](../adrs/0018-roleplayer-data-model.md). A 1.0/1.1/1.2 archive that lacks the keys must deserialize to empty, and an older client must be able to ignore the keys. `KNOWN_SCHEMA_MAX` stays at `1.2`. Do **not** touch `netlify/functions/` in this stage.
* **Variables are JSON, not `.md` files.** They are short structured data and live in `program.json` (and the nested exercise/station JSON), not as `.md` archive parts. [ADR-0022](../adrs/0022-markdown-content-as-files.md) does not apply to them. Do not add `@JsonKey(includeFromJson: false, includeToJson: false)`.
* **Feature flag gates surfaces, not data.** The `RINGDRILL_PLAN_VARIABLES` flag (registered in Step 1) gates user-visible and rendering surfaces in Stages 2–5. It must never gate the model. `Program.variables` and `variableOverrides` are always present and always serialized regardless of the flag, so a `.drill` written by a flagged build still round-trips on an unflagged build. Follow the flag conventions in [ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md) and keep `docs/feature-flags.md` updated in the same commit.
* **No new lint suppressions.** Match existing Dart style.
* Run `flutter analyze` and `flutter test` before claiming the change is green. A clean run is the expected baseline (the old default-template `test/widget_test.dart` has been removed). If a test fails, fix it or flag it — do not assert all tests pass when they do not.

## Commits

Commit as you progress, not in one blob. Conventional Commits with a scope, written in English. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Suggested subjects:

* `feat(config): add RINGDRILL_PLAN_VARIABLES feature flag`
* `feat(models): add DrillVariable`
* `feat(models): add plan-global variable registry to Program`
* `feat(models): add variableOverrides to Exercise and Station`
* `fix(models): carry variableOverrides through schedule regeneration and content hash`
* `test(models): cover variable serialization, backward-compat and hashing`

All commits land together as one continuous series on the same branch.

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Regenerated `*.freezed.dart` / `*.g.dart` files are part of the same commit as the source that produced them. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. If you see a path you do not recognise in `git status`, inspect it, then either include it or stop and ask. Never `git stash` or `git restore` to hide working-tree changes.
* The final Verification gate requires `git status` to print a clean tree with no untracked or unstaged files.

## Scope

Six steps, in order.

### Step 1. Register the feature flag

Add the build-time flag so every user-visible surface in later stages can be gated, letting the feature merge to `main` inert. The flag gates nothing in Stage 1 — the model fields are additive and harmless on their own — but it must exist first so Stages 2–5 can hang off it.

Edit `lib/utils/app_flags.dart`:

* Add `static const planVariables = bool.fromEnvironment('RINGDRILL_PLAN_VARIABLES');`.
* Add a matching `AppFlagInfo` entry to `AppFlags.all`, `kind: AppFlagKind.temporary`, with a description that names DESIGN-008.

Add a row to `docs/feature-flags.md` following the existing table shape: name `RINGDRILL_PLAN_VARIABLES`, type `bool`, kind Temporary, default `false`, purpose "Gates the DESIGN-008 plan-variables feature (variable registry, section-navigated editor, token-aware fields) while it is built across stages", introduced by DESIGN-008, sunset "Remove when all five DESIGN-008 stages have shipped and the feature is on by default."

Do not gate any model code on the flag. The flag guards UI and rendering surfaces in later stages, not the data.

Files expected in this commit:

* `lib/utils/app_flags.dart`
* `docs/feature-flags.md`

Run `git status`. Commit: `feat(config): add RINGDRILL_PLAN_VARIABLES feature flag`.

### Step 2. Add the DrillVariable model

Create `lib/models/drill_variable.dart`. Follow the freezed + `json_serializable` pattern used by the other models in `lib/models/` (a `sealed class ... with _$...`, a `fromJson` factory, and the `part` directives).

```dart
/// An author-defined value declared once on the plan and referenced from
/// markdown fields as `{{var.<name>}}`. See ADR-0046 and DESIGN-008.
///
/// Identity is plan-global: a variable is declared only on [Program].
/// [Exercise] and [Station] override the value for their subtree via a
/// `variableOverrides` map keyed by [name]; they never declare new names.
@freezed
sealed class DrillVariable with _$DrillVariable {
  const factory DrillVariable({
    /// Slug, unique within the plan. Must match `^[a-z][a-z0-9_]*$`.
    /// This is the reference key used in `{{var.<name>}}`.
    required String name,

    /// The global default value substituted when no scope overrides it.
    @Default('') String value,

    /// Optional description shown in the insertion picker.
    String? hint,
  }) = _DrillVariable;

  factory DrillVariable.fromJson(Map<String, dynamic> json) =>
      _$DrillVariableFromJson(json);
}
```

Do not add validation logic (the slug regex, uniqueness) to the model itself — that is an editor concern for Stage 5. The doc comment records the rule; the model just holds data. Run `make build`.

Files expected in this commit:

* `lib/models/drill_variable.dart`
* `lib/models/drill_variable.freezed.dart`
* `lib/models/drill_variable.g.dart`

Run `git status`. Commit: `feat(models): add DrillVariable`.

### Step 3. Add the registry to Program

Edit `lib/models/program.dart`. Add the field next to `tags`, following the same `@Default` backward-compat comment style already there:

```dart
// @Default([]) so archives without the key deserialize to an empty
// registry (ADR-0046, additive field, no schema bump).
@Default(<DrillVariable>[]) List<DrillVariable> variables,
```

Import `drill_variable.dart`. Run `make build`.

Then wire `variables` into `ProgramX.computeContentHash` (around `lib/models/program.dart:205` and its shared canonicalization helper). A change to any variable's name, value or hint must produce a different hash, the same way a description change does. Read the existing hash code and the denylist comment carefully — add `variables` to the hashed content, canonicalised deterministically (sort by `name`) so file order never changes the hash.

Files expected in this commit:

* `lib/models/program.dart`
* `lib/models/program.freezed.dart`
* `lib/models/program.g.dart`

Run `git status`. Commit: `feat(models): add plan-global variable registry to Program`.

### Step 4. Add overrides to Exercise and Station

Edit `lib/models/exercise.dart` and `lib/models/station.dart`. Add to each:

```dart
/// Per-scope value overrides for plan-global variables, keyed by
/// DrillVariable.name. A key that does not name a declared variable is
/// meaningless and is ignored at resolution time (ADR-0046). This scope
/// never declares new variables.
@Default(<String, String>{}) Map<String, String> variableOverrides,
```

Run `make build` after each model edit (or once after both — but confirm both regenerated files are staged).

Files expected in this commit:

* `lib/models/exercise.dart`, `lib/models/exercise.freezed.dart`, `lib/models/exercise.g.dart`
* `lib/models/station.dart`, `lib/models/station.freezed.dart`, `lib/models/station.g.dart`

Run `git status`. Commit: `feat(models): add variableOverrides to Exercise and Station`.

### Step 5. Preserve overrides through regeneration and hashing

Two integrity fixes.

First, schedule regeneration. `ProgramService.generateSchedule` (`lib/services/program_service.dart:1083`) rebuilds an `Exercise`. DESIGN-004 already re-applies brief markdown via `copyWith` after this call. Confirm `variableOverrides` on the exercise (and on its stations, if `generateSchedule` also rebuilds stations) is carried through, not silently dropped. If `generateSchedule` constructs a fresh `Exercise`/`Station` rather than `copyWith`-ing the input, thread `variableOverrides` through explicitly. Trace every construction site the schedule path touches.

Second, the content hash. Station and exercise JSON already flow into `computeContentHash` via the canonicalization helper (`lib/models/program.dart` around the exercise/station maps). Confirm `variableOverrides` is included and not stripped by the existing denylist. An override change on an exercise or station must change the plan's content hash.

Files expected in this commit (whichever the fixes touch):

* `lib/services/program_service.dart`
* `lib/models/program.dart` (only if the hash canonicalization needed an edit; include regenerated files if any)

Run `git status`. Commit: `fix(models): carry variableOverrides through schedule regeneration and content hash`.

### Step 6. Tests

Add tests under `test/models/` (match the existing test layout — check where `program`, `exercise` and `station` tests live and follow suit). Cover:

* **DrillVariable round-trips.** `DrillVariable(name: 'frekvens', value: 'Kanal 6', hint: 'Sambandskanal')` survives `toJson`/`fromJson` unchanged. A JSON map with only `name` deserializes with `value == ''` and `hint == null`.
* **Program registry round-trips through the archive.** Build a `Program` with two variables, write and read it through `DrillFile` (the real archive path, not just `Program.fromJson`), and assert the variables come back identical.
* **Backward compatibility.** A `program.json` map with no `variables` key deserializes to `variables == []`. An exercise/station map with no `variableOverrides` key deserializes to an empty map. No exception, no migration.
* **Overrides round-trip.** An `Exercise` and a `Station` with `variableOverrides: {'frekvens': 'Kanal 8'}` survive an archive round-trip.
* **Content hash sensitivity.** Two programs identical except for one variable's `value` produce different `computeContentHash()` results. Same for an added variable, and for a changed `variableOverrides` entry on an exercise and on a station. Two programs whose variables differ only in list order hash **equal** (canonicalisation works).
* **Schedule regeneration preserves overrides.** Set `variableOverrides` on an exercise, run it through `ProgramService.generateSchedule`, assert the overrides survive.
* **Flag defaults off.** `AppFlags.planVariables` is `false` in a normal test run (no `--dart-define`), and an `AppFlagInfo` for `RINGDRILL_PLAN_VARIABLES` is present in `AppFlags.all`.

Run `flutter analyze`. Run `flutter test test/models/`. Run the full suite once to confirm nothing else regressed.

Files expected in this commit:

* the new/edited test files under `test/models/`

Run `git status`. Commit: `test(models): cover variable serialization, backward-compat and hashing`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures.
3. `make build` leaves no diff — running it again after committing produces no further changes to generated files (proves the committed generated files are current).
4. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds. Catches any accidental Flutter import pulled into the model layer.
5. **Flag inert.** `RINGDRILL_PLAN_VARIABLES` defaults `false`, appears in `AppFlags.all` and in `docs/feature-flags.md`, and gates no model code. Grep confirms nothing under `lib/models/` references `AppFlags.planVariables`.
6. **Backward-compat check.** Load a pre-existing `.drill` fixture that predates this change (schema 1.0/1.1/1.2, no `variables`/`variableOverrides` keys) through `DrillFile` and confirm it opens with empty registry and empty override maps, no exception. If no such fixture exists in `test/`, construct a JSON map by hand in the test.
7. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`, and `git ls-files --others --exclude-standard` prints nothing.
8. **Diff sanity.** `git log --stat origin/main..HEAD` — walk every changed path and confirm each file appears in the commit you intended. Every `*.freezed.dart`/`*.g.dart` sits with its source.

## Deliverables

A series of Conventional Commits as outlined, all on one branch, clean tree at the end. The final commit body should summarise what the model now carries and explicitly defer Stages 2–5 (renderer resolution, section-navigated editor, token-aware field, variables section). Note whether `generateSchedule` needed an explicit thread-through or already preserved the fields via `copyWith`.

ADR-0046 and DESIGN-008 are authoritative. If you find yourself contradicting either — for example, if the content-hash denylist makes including overrides awkward, or if a schema bump seems unavoidable — stop and ask rather than deviating. Do not write a new ADR for this stage.
