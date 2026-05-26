# Implement DESIGN-004 Stage 1b

You are working in the RingDrill repository. Implement Stage 1b of DESIGN-004 ("Exercise brief template") end-to-end. DESIGN-004 at `docs/design/brief-template.md` is the authoritative spec for the new fields and for the staging. ADR-0022 at `docs/adrs/0022-markdown-content-as-files.md` is the authoritative spec for the archive format the new markdown fields live in. Stage 1a has already shipped and is merged. Read its prompt at `docs/prompts/adr-0022-stage-1a-implementation.md` for the conventions it established.

Stage 1b extends the data model with the new fields DESIGN-004 calls for, plumbs them through `DrillFile` read and write, and folds them into the catalog content hash. It does not add a renderer, a template, a brief route, form editors or any UI surface for the new fields. Those stages come later.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* Codegen. After annotating freezed fields, run `make build` (or `dart run build_runner build --delete-conflicting-outputs`). Do not hand-edit `*.freezed.dart` or `*.g.dart`.
* CLI must stay Flutter-free. `bin/ringdrill.dart` imports `lib/data/drill_client.dart` and indirectly the models. Nothing in this change should add `package:flutter/*` to anything the CLI imports.
* Mobile-safe imports. `lib/data/drill_file.dart` is reachable from both native and web. Do not introduce `dart:html` or `package:web`. Use `universal_io` for `File` as the file already does.
* No new lint suppressions. Match existing Dart style.
* Run `flutter analyze` and `flutter test` before claiming the change is green. `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such rather than asserting all tests pass.
* The schema is already `'1.2'` after Stage 1a. Do not bump it again. Do not touch `netlify/functions/drills-upload.js`.

## Commits

Commit as you progress, not in one giant blob. Each step below is a natural commit boundary. The project uses Conventional Commits with a scope. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Relevant scopes already in use: `data`, `models`. Suggested subjects:

* `feat(models): add templateId on Exercise and variantSuffix on Station`
* `feat(models): add brief markdown fields on Program, Exercise, Station, RolePlay`
* `feat(data): read/write Stage 1b markdown fields as .md files in DrillFile`
* `feat(data): fold Stage 1b markdown fields into ProgramX.computeContentHash`
* `test(data): cover Stage 1b field roundtrip and content-hash stability`

All five logical commits land together as one continuous series on the same branch. Do not push or merge commit 2 in isolation. The freezed annotations on their own make the new markdown fields disappear from the JSON manifests, and commit 3 is what restores them via `.md` files.

### Commit discipline (non-negotiable)

A recurring failure mode in past rounds has been agents leaving regenerated files, new test files or l10n changes uncommitted in the working tree. Avoid this:

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Regenerated files from `make build` (`*.freezed.dart`, `*.g.dart`, `app_localizations*.dart`) are part of the commit that triggered them. Do not park them in a "regen" follow-up commit.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Field inventory

All new fields are nullable and additive. The full list, grouped by entity:

**Program** (storage: `program/<field>.md`)

* `briefIntroMd` -> `program/intro.md`
* `commsMd` -> `program/comms.md`

**Exercise** (storage: `exercises/<uuid>/<field>.md` for markdown, JSON for structural)

* `methodMd` -> `exercises/<uuid>/method.md`
* `learningGoalsMd` -> `exercises/<uuid>/learning-goals.md`
* `trainingFocusMd` -> `exercises/<uuid>/training-focus.md`
* `orderFormatMd` -> `exercises/<uuid>/order-format.md`
* `executionTipsMd` -> `exercises/<uuid>/execution-tips.md`
* `commsMd` -> `exercises/<uuid>/comms.md`
* `templateId` -> stays in `exercises/<uuid>.json` (no annotation)

**Station** (storage: `exercises/<uuid>/stations/<index>/<field>.md` for markdown, JSON for structural)

Stations have no UUID. They are scoped by their parent exercise and their `index`. Path keying matches the convention introduced in Stage 1a for nothing because Stage 1a touched no station files. ADR-0022 calls this out as a known fragility under reorder. Do not invent a station UUID in this stage.

* `variantSuffix` -> stays in the station block inside `exercises/<uuid>.json` (no annotation)
* `equipmentMd` -> `exercises/<uuid>/stations/<index>/equipment.md`
* `situationMd` -> `exercises/<uuid>/stations/<index>/situation.md`
* `missionMd` -> `exercises/<uuid>/stations/<index>/mission.md`
* `logisticsMd` -> `exercises/<uuid>/stations/<index>/logistics.md`
* `criticalQuestionsMd` -> `exercises/<uuid>/stations/<index>/critical-questions.md`
* `leaderAnswersMd` -> `exercises/<uuid>/stations/<index>/leader-answers.md`
* `directorNotesMd` -> `exercises/<uuid>/stations/<index>/director-notes.md`

**RolePlay** (storage: `roleplays/<uuid>/<field>.md`)

* `propsMd` -> `roleplays/<uuid>/props.md`

Naming rules from ADR-0022 apply unchanged. Drop the `Md` suffix, kebab-case the rest. A missing file means null. An empty file means an empty string. The reader does not distinguish.

## Scope

Five steps. Do them in order.

### Step 1. Add structural fields

Edit `lib/models/exercise.dart`. Add a new field:

```dart
String? templateId,
```

Place it next to the other top-level descriptive fields. It stays in JSON and needs no `@JsonKey` annotation. Do not pick a default. Null falls through to the system default template at render time, which is Stage 2 work.

Edit `lib/models/station.dart`. Add a new field:

```dart
String? variantSuffix,
```

Place it next to `name`. It stays in JSON and needs no `@JsonKey` annotation.

Run `make build`. Inspect the regenerated `exercise.g.dart` and `station.g.dart` to confirm `templateId` and `variantSuffix` appear in both `fromJson` and `toJson` generated code.

Files expected in this commit:

* `lib/models/exercise.dart`
* `lib/models/exercise.freezed.dart` (regenerated)
* `lib/models/exercise.g.dart` (regenerated)
* `lib/models/station.dart`
* `lib/models/station.freezed.dart` (regenerated)
* `lib/models/station.g.dart` (regenerated)

Run `git status`. Confirm the tree is clean apart from those six paths. Commit: `feat(models): add templateId on Exercise and variantSuffix on Station`.

### Step 2. Add markdown fields with @JsonKey suppression

Edit each model to add the new markdown fields. Every `*Md` field gets the annotation:

```dart
@JsonKey(includeFromJson: false, includeToJson: false) String? <fieldName>Md,
```

Match the exact list under "Field inventory" above.

* `lib/models/program.dart` -> `briefIntroMd`, `commsMd`
* `lib/models/exercise.dart` -> `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`
* `lib/models/station.dart` -> `equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd`, `directorNotesMd`
* `lib/models/role_play.dart` -> `propsMd`

Run `make build`. Inspect the regenerated `.g.dart` files to confirm none of the new `*Md` fields appear in `fromJson` or `toJson`. The structural `templateId` from Step 1 must still be present in `exercise.g.dart`. The structural `variantSuffix` must still be present in `station.g.dart`.

At this point, the existing roundtrip tests in `test/data/drill_file_roleplay_test.dart` continue to pass because none of the new fields are populated by the test fixtures. New tests in Step 5 exercise the new fields end-to-end.

Files expected in this commit:

* `lib/models/program.dart`
* `lib/models/program.freezed.dart` (regenerated)
* `lib/models/program.g.dart` (regenerated)
* `lib/models/exercise.dart`
* `lib/models/exercise.freezed.dart` (regenerated)
* `lib/models/exercise.g.dart` (regenerated)
* `lib/models/station.dart`
* `lib/models/station.freezed.dart` (regenerated)
* `lib/models/station.g.dart` (regenerated)
* `lib/models/role_play.dart`
* `lib/models/role_play.freezed.dart` (regenerated)
* `lib/models/role_play.g.dart` (regenerated)

The regenerated files MUST be in this commit. They are not a separate follow-up. Run `git status` and verify all twelve paths are staged. Commit: `feat(models): add brief markdown fields on Program, Exercise, Station, RolePlay`.

### Step 3. DrillFile read/write for new markdown fields

Edit `lib/data/drill_file.dart`.

**Writer (`fromProgram`).** Extend the writer so each new field produces an entry iff the value is non-null. Empty string writes a zero-byte file. Null writes no file. Use `path.join` for portability, matching existing code.

Program-level writes (next to `program.json`):

* `program/intro.md` from `program.briefIntroMd`
* `program/comms.md` from `program.commsMd`

Exercise-level writes (per exercise):

* `exercises/<uuid>/method.md` from `exercise.methodMd`
* `exercises/<uuid>/learning-goals.md` from `exercise.learningGoalsMd`
* `exercises/<uuid>/training-focus.md` from `exercise.trainingFocusMd`
* `exercises/<uuid>/order-format.md` from `exercise.orderFormatMd`
* `exercises/<uuid>/execution-tips.md` from `exercise.executionTipsMd`
* `exercises/<uuid>/comms.md` from `exercise.commsMd`

Station-level writes (per station, per parent exercise):

* `exercises/<exerciseUuid>/stations/<index>/equipment.md` from `station.equipmentMd`
* `exercises/<exerciseUuid>/stations/<index>/situation.md` from `station.situationMd`
* `exercises/<exerciseUuid>/stations/<index>/mission.md` from `station.missionMd`
* `exercises/<exerciseUuid>/stations/<index>/logistics.md` from `station.logisticsMd`
* `exercises/<exerciseUuid>/stations/<index>/critical-questions.md` from `station.criticalQuestionsMd`
* `exercises/<exerciseUuid>/stations/<index>/leader-answers.md` from `station.leaderAnswersMd`
* `exercises/<exerciseUuid>/stations/<index>/director-notes.md` from `station.directorNotesMd`

The index is `station.index` (the integer position inside its exercise), serialized as a decimal string with no padding. Match what `Station.toJson` puts in the manifest. If the manifest uses a different shape, follow the manifest, not this prompt.

RolePlay-level writes:

* `roleplays/<uuid>/props.md` from `rolePlay.propsMd`

**Reader (`program()`).** Extend the existing pass-2 classifier introduced in Stage 1a with the new path shapes. Keep using full-path checks. Suggested classification rules:

* `program/intro.md`, `program/comms.md` -> assign to the `Program` after construction.
* `exercises/<uuid>/<field>.md` (where `<field>` is one of the six exercise fields) -> defer to the corresponding `Exercise` after construction.
* `exercises/<uuid>/stations/<index>/<field>.md` -> defer to the corresponding `Station` after construction. Look up the station by `(exerciseUuid, index)`.
* `roleplays/<uuid>/props.md` -> defer to the corresponding `RolePlay` after construction. The existing `roleplays/<uuid>/behavior.md` and `roleplays/<uuid>/background.md` rules from Stage 1a still apply.

When an entity carries multiple `.md` files (every new entity does), apply them with `copyWith` in a single pass to avoid rebuilding the same entity many times. The same is true for stations, which sit inside an exercise. The cleanest pattern is:

1. Construct every entity from its JSON manifest first, with all `*Md` fields null.
2. Collect markdown content into a `Map<String, Map<String, String>>` keyed by `(entityKey, fieldName)` where `entityKey` is the entity uuid (or `(exerciseUuid, index)` for stations) and `fieldName` is the Dart field name (e.g. `methodMd`).
3. Walk the entity tree once and apply each map entry via `copyWith`.

Reuse the helpers Stage 1a introduced where possible. If Stage 1a's classifier is hard-coded for behavior, background and notes only, refactor it to a small dispatch table that takes the entity type and field name. The Step 2 commit in Stage 1a's prompt anticipated this. Do not introduce a new code path that bypasses the legacy-inline fallback Stage 1a built for `roleplay.behavior`, `roleplay.background` and `actor.notes`.

**Empty vs missing files.** Same rule as Stage 1a. Empty `.md` file decodes to `''`. Missing file leaves the field at null.

**Stations under reorder.** Stage 1b uses `(exerciseUuid, index)` as the station key. ADR-0022 calls out this fragility. Do not try to handle reorder migration here. A follow-up ADR will introduce station UUIDs if it matters.

Files expected in this commit:

* `lib/data/drill_file.dart`

Run `git status` and verify only this path is staged. Commit: `feat(data): read/write Stage 1b markdown fields as .md files in DrillFile`.

### Step 4. Content hash

Edit `lib/models/program.dart` `ProgramX.computeContentHash`. Stage 1a's commit 5 already folded `roleplay.behavior` and `roleplay.background` back into the canonical map. Extend that approach to every new markdown field listed under "Field inventory" except actor fields.

* For `program`, after `Program.toJson`, inject `briefIntroMd` and `commsMd` into the canonical map.
* For each `Exercise`, after `Exercise.toJson`, inject `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd` and `commsMd`. The structural `templateId` is already in the manifest, so it is hashed by default.
* For each `Station` inside an exercise, after `Station.toJson`, inject all seven `*Md` fields. The structural `variantSuffix` is already in the manifest, so it is hashed by default.
* For each `RolePlay`, extend the existing injection to also include `propsMd` alongside `behavior` and `background`.
* Actors stay excluded from the hash entirely per ADR-0018. `actor.notes` is the only actor markdown field and is correctly out of scope here.

Order is the determinism risk. Stations inside an exercise must be sorted by `index`. Exercises in a program must be sorted by a stable key (uuid is the safest. If the existing canonical builder sorts by some other field, follow that, but document the choice in a comment). RolePlays must be sorted by uuid as today.

Files expected in this commit:

* `lib/models/program.dart`

Run `git status` and verify only this path is staged. Commit: `feat(data): fold Stage 1b markdown fields into ProgramX.computeContentHash`.

### Step 5. Tests

Add tests to `test/data/drill_file_roleplay_test.dart` (or split off a new file `test/data/drill_file_brief_fields_test.dart` if the existing file gets unwieldy past ~600 lines. Match whichever pattern the repo already uses).

Tests to add:

* `writes Stage 1b markdown fields as .md files in archive`. Build a program with one exercise, two stations, one rolePlay. Populate every new `*Md` field with distinct content. Run `DrillFile.fromProgram`. Decode the zip manually. Assert every expected `.md` path exists with the expected UTF-8 content. Assert the JSON manifests do not contain any `*Md` keys.

* `reads back Stage 1b markdown fields from archive`. Take the archive produced above and run it through `DrillFile.program()`. Assert every `*Md` field roundtrips with byte-identical content.

* `writes templateId and variantSuffix into JSON manifests`. Same as the first test but assert `exercises/<uuid>.json` contains `templateId` and the station block inside it contains `variantSuffix`. These are structural fields and must travel in JSON, not as `.md` files.

* `Stage 1b empty md file roundtrips as empty string, missing as null`. Pick three fields (one program-level, one exercise-level, one station-level). For each, set one instance to `''`, one to `null`. Write, read, assert. The writer should emit zero-byte files only for the `''` instances.

* `Stage 1b content hash includes new markdown fields`. Build two programs with identical structure but different `methodMd` on the same exercise. Compute `computeContentHash` for each. Assert they differ. Repeat for `briefIntroMd`, `equipmentMd`, `directorNotesMd` and `propsMd`. Repeat for `variantSuffix` and `templateId` to confirm structural fields contribute too.

* `Stage 1b content hash is deterministic across archive entry order`. Build a program, run `fromProgram` to produce an archive, decode it, reshuffle the `ZipEncoder` entry order (or do it via two writers that happen to enumerate in different orders if the writer ordering is itself non-deterministic), then read both back. Assert the resulting programs hash to the same value.

* `Stage 1b content hash is stable across save/load roundtrip`. Build a program with every new field populated. Compute hash A. Run `fromProgram` then `program()`. Compute hash B on the decoded program. Assert A == B. This is the regression guard against hashing-order drift.

* `actor.notes still excluded from content hash`. Build two programs with identical structure but different `actor.notes`. Assert hashes are equal. This protects the ADR-0018 boundary against an accidental hash extension.

Run `flutter analyze`. Run `flutter test test/data/`. Run the Netlify test suite (no changes are expected there, but run it to confirm nothing regressed).

Files expected in this commit:

* `test/data/drill_file_roleplay_test.dart` (and/or `test/data/drill_file_brief_fields_test.dart`)

Run `git status` and verify only the test path(s) are staged. Commit: `test(data): cover Stage 1b field roundtrip and content-hash stability`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken. Do not try to fix it.
3. `node --test netlify/functions/__tests__/` is green. No changes expected.
4. `make build` completes cleanly. Re-run `git status` after it. If any regenerated file is suddenly dirty after analyze and test pass, that file was missing from an earlier commit. Stop and amend before continuing.
5. **Clean tree gate.** `git status` on the working branch prints `nothing to commit, working tree clean`, and `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. The stage is not complete until this is true. Do not invoke `git stash` or `git restore` to satisfy it.
6. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended. If a regenerated `.freezed.dart` shows up two commits later than the annotation that triggered it, fix the history with `git rebase -i` before declaring the stage done.
7. Manual QA matrix (record the result in the final commit body or a `docs/notes/` file, whichever matches existing convention):
   * **CLI roundtrip.** Build a fixture program in Dart (via a one-off script or an existing test helper) with every new `*Md` field populated. Write it to `.drill` via `DrillFile.fromProgram`. Unpack the archive with `unzip` and inspect the file tree. Confirm every expected `.md` path is present with the expected content. Confirm no `*Md` keys appear in any JSON manifest.
   * **App import.** On a device, import the fixture archive built above. Open the program. The new fields are not surfaced in the UI yet (Stage 4 work), so the QA is to confirm the program loads without error and the catalog content hash matches what was computed before upload.
   * **Stage 1a archive backward compatibility.** Take a `.drill` archive produced by a Stage 1a build (no new `*Md` fields populated). Open it in this Stage 1b build. Verify the program loads correctly and that all new `*Md` fields read back as null.
   * **Reorder safety check.** Build a program with stations populated. Save. Reorder the stations on the same exercise. Save again. Open the archive. Confirm the on-disk content reflects the new order. A station whose content was at `stations/0/` is now at `stations/1/` and vice versa. This is the path-keying fragility ADR-0022 calls out. Document the behavior. Do not try to fix it in this stage.
8. Confirm Stage 2 surfaces (renderer, template, brief route) and Stage 4 surfaces (form editors) are untouched. Stage 1b is data-model and storage only.

## Deliverables

A series of five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A short summary of what fields landed and what surfaces are still missing (Stages 2 through 5 are explicitly deferred).
* The manual QA matrix filled out, including the reorder-safety observation.
* A note that station path keying by `(exerciseUuid, index)` remains the known fragility from ADR-0022 and is not addressed here.

DESIGN-004 is the authoritative spec for the field list. ADR-0022 is the authoritative spec for the archive format. If you find yourself contradicting either, stop and ask. Do not write a new ADR.
