# Implement ADR-0022 Stage 1a

You are working in the RingDrill repository. Implement Stage 1a of ADR-0022 ("Store long-form markdown content as `.md` files in the drill archive") end-to-end. The ADR lives at `docs/adrs/0022-markdown-content-as-files.md` and is accepted. It is the authoritative spec for the archive format. DESIGN-004 at `docs/design/brief-template.md` ("Implementation notes" section) splits the work into stages and is the authoritative reference for *what belongs in Stage 1a*.

Stage 1a is an isolated format change. It migrates the three existing markdown-bearing string fields from inline JSON to per-entity `.md` files and bumps the schema from 1.1 to 1.2. No new model fields are added here. The new `*Md` fields on `Program`, `Exercise`, `Station` and `RolePlay` belong to Stage 1b and are out of scope for this stage.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* Coordinated schema bump. AGENTS.md rule 8 applies. The Flutter app, the CLI and `netlify/functions/drills-upload.js` must all accept `'1.2'` as part of this stage. The handler must keep accepting `'1.1'` and `'1.0'` archives.
* Codegen. After annotating freezed fields, run `make build` (or `dart run build_runner build --delete-conflicting-outputs`). Do not hand-edit `*.freezed.dart` or `*.g.dart`.
* CLI must stay Flutter-free. `bin/ringdrill.dart` imports `lib/data/drill_client.dart` and indirectly the models. Nothing in this change should add `package:flutter/*` to anything the CLI imports.
* Mobile-safe imports. `lib/data/drill_file.dart` is reachable from both native and web. Do not introduce `dart:html` or `package:web`. Use `universal_io` for `File` as the file already does.
* Match existing Dart style. No new lint suppressions.
* Run `flutter analyze` and `flutter test` before claiming the change is green. `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such rather than asserting all tests pass.

## Commits

Commit as you progress, not in one giant blob. Each step below is a natural commit boundary. The project uses Conventional Commits with a scope. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Relevant scopes already in use: `data`, `models`, `netlify`. Suggested subjects:

* `feat(data): add drillSchema1_2 constant and accept 1.2 server-side`
* `feat(models): annotate RolePlay.behavior/background and Actor.notes with @JsonKey(include*=false)`
* `feat(data): read/write markdown fields as .md files in DrillFile with legacy-inline fallback`
* `feat(data): bump drillSchemaCurrent to 1.2 and fold markdown into computeContentHash`
* `test(data): cover 1.1-to-1.2 migration of behavior, background and actor notes`

All four logical commits land together as one continuous series on the same branch. Do not push or merge commit 2 in isolation: the freezed annotations alone make RolePlay and Actor lose `behavior`, `background` and `notes` on serialization, and commit 3 is what restores them.

### Commit discipline (non-negotiable)

A recurring failure mode in past rounds has been agents leaving regenerated files, new test files or l10n changes uncommitted in the working tree. Avoid this:

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Regenerated files from `make build` (`*.freezed.dart`, `*.g.dart`, `app_localizations*.dart`) are part of the commit that triggered them. Do not park them in a "regen" follow-up commit.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Scope

Five steps. Do them in order.

### Step 1. Schema constant and Netlify acceptance

Edit `lib/data/drill_file.dart`. Add a third schema constant alongside the existing two:

```dart
static const drillSchema1_2 = '1.2';
```

Leave `drillSchemaCurrent` pointing at `drillSchema1_1` for now. The pointer flips in Step 5 after the read/write logic is in place. This keeps Step 1 isolated and trivially reviewable.

Edit `netlify/functions/drills-upload.js`. Bump `KNOWN_SCHEMA_MAX` from `"1.1"` to `"1.2"`. The `actors/`-strip rule on line ~56 already uses `name.startsWith("actors/")`, which transparently covers the new `actors/<uuid>/notes.md` path. Do not touch the strip logic.

Mirror the bump in `netlify/functions/__tests__/drills-upload-strip.test.mjs`. The test file reimplements the helper verbatim, so update its local `KNOWN_SCHEMA_MAX` constant in the same commit. Change the existing `rejects schema higher than 1.1` test to assert `"1.3"` instead of `"1.2"`. Add a new test `accepts schema 1.2` mirroring the existing `accepts schema 1.1`. Add a new test verifying that `actors/<uuid>/notes.md` is stripped while `roleplays/<uuid>/behavior.md` survives.

Files expected in this commit:

* `lib/data/drill_file.dart`
* `netlify/functions/drills-upload.js`
* `netlify/functions/__tests__/drills-upload-strip.test.mjs`

Run `git status`. Confirm the tree is clean apart from those three paths. Commit: `feat(data): add drillSchema1_2 constant and accept 1.2 server-side`.

### Step 2. Model annotations

Edit `lib/models/role_play.dart`. Annotate `behavior` and `background` with `@JsonKey(includeFromJson: false, includeToJson: false)`. Leave every other field untouched.

Edit `lib/models/actor.dart`. Annotate `notes` with the same annotation.

Run `make build`. Inspect the regenerated `role_play.g.dart` and `actor.g.dart` to confirm that `behavior`, `background` and `notes` no longer appear in either the `fromJson` or `toJson` generated code.

At this point, the existing roundtrip test in `test/data/drill_file_roleplay_test.dart` will start to lose any inline markdown content on roundtrip. That is expected. Step 3 fixes it. Do not patch the test yet.

Files expected in this commit:

* `lib/models/role_play.dart`
* `lib/models/actor.dart`
* `lib/models/role_play.freezed.dart` (regenerated)
* `lib/models/role_play.g.dart` (regenerated)
* `lib/models/actor.freezed.dart` (regenerated)
* `lib/models/actor.g.dart` (regenerated)

The four regenerated files MUST be in this commit. They are not a separate follow-up. Run `git status` and verify all six paths are staged. Commit: `feat(models): annotate RolePlay.behavior/background and Actor.notes with @JsonKey(include*=false)`.

### Step 3. DrillFile read/write rewrite

Edit `lib/data/drill_file.dart`.

**Writer (`fromProgram`).** For each `RolePlay`, keep writing `roleplays/<uuid>.json` as today. The freezed `toJson` from Step 2 no longer contains `behavior` and `background`. In addition, write two new entries iff the corresponding string is non-null:

* `roleplays/<uuid>/behavior.md` with UTF-8 content of `rolePlay.behavior!`.
* `roleplays/<uuid>/background.md` with UTF-8 content of `rolePlay.background!`.

An empty string writes an empty file. A null value writes no file. The reader must distinguish these two.

For each `Actor`, keep writing `actors/<uuid>.json`. In addition, write `actors/<uuid>/notes.md` iff `actor.notes` is non-null. Use `path.join` so paths stay portable across platforms, matching the existing code.

**Reader (`program()`).** Refactor the single-pass loop into two passes.

Pass 1 indexes every archive entry in a `Map<String, List<int>>` keyed by `file.name`. Do not deserialize during this pass.

Pass 2 iterates the indexed entries and classifies them by exact path shape. Use full-path checks, not prefix matches, so that `roleplays/<uuid>/behavior.md` does not get misclassified as a JSON manifest under `startsWith('roleplays')`. The classification rules:

* `metadata.json` -> `ProgramMetadata.fromJson`.
* `program.json` -> `Program.fromJson`.
* `teams/<uuid>.json` -> `Team.fromJson`.
* `sessions/<uuid>.json` -> `Session.fromJson`.
* `exercises/<uuid>.json` -> `Exercise.fromJson`.
* `roleplays/<uuid>.json` -> `RolePlay.fromJson` with legacy-inline fallback (see below).
* `roleplays/<uuid>/<field>.md` -> defer to the corresponding `RolePlay` after construction.
* `actors/<uuid>.json` -> `Actor.fromJson` with legacy-inline fallback.
* `actors/<uuid>/notes.md` -> defer to the corresponding `Actor` after construction.

**Legacy-inline fallback.** A 1.1 archive on disk has `behavior`, `background` and `notes` inlined in its JSON manifest. After Step 2, freezed `fromJson` ignores those keys. Without an explicit fallback the 1.2 reader silently drops the content on import, which is data loss for every existing user. To prevent that, in pass 2, after `jsonDecode` and before `RolePlay.fromJson`, capture the raw inline values:

```text
legacyBehavior   = json['behavior']   as String?
legacyBackground = json['background'] as String?
legacyNotes      = json['notes']      as String?   // for actor manifests
```

Build the freezed entity, then patch with `copyWith` using the precedence: `.md`-file content first, otherwise legacy inline value, otherwise null. This makes the first read of a 1.1 archive populate the string fields correctly. On the next write, the writer produces a 1.2 archive with `.md` files, and the JSON manifest no longer carries the inline keys.

**Empty vs missing files.** If the field-level `.md` file is present, decode UTF-8 and assign the result, including the empty string. If the file is absent, fall through to the legacy fallback. Lock this distinction down in a unit test in Step 4.

Update the existing tests in `test/data/drill_file_roleplay_test.dart` to reflect the new behavior. The 1.1 roundtrip test should now assert that schema is still `'1.1'` (since `drillSchemaCurrent` has not flipped yet) but that the archive `.md` files are produced when the writer sees populated string fields. Or, equivalently, hold off on adjusting the existing tests until Step 5 and rely on the new tests added in Step 4 to validate Step 3 in isolation. Either is acceptable so long as the suite is green at every commit boundary.

Files expected in this commit:

* `lib/data/drill_file.dart`
* `test/data/drill_file_roleplay_test.dart` (if you adjusted existing tests; otherwise this file lands in Step 4)

Run `git status` and verify only these paths are staged. Commit: `feat(data): read/write markdown fields as .md files in DrillFile with legacy-inline fallback`.

### Step 4. Tests

Add tests to `test/data/drill_file_roleplay_test.dart`. Keep the existing 1.0-bakoverkompat test untouched.

Add a private helper `_build1_1Archive({ String? behavior, String? background, String? notes })` that constructs a synthetic 1.1 archive in-memory using `ZipEncoder`, with the three fields inlined in their respective JSON manifests. This is the input to the migration tests below. The existing 1.0 test already shows the pattern for building archives by hand.

Add these tests:

* `writes markdown as .md files in archive`. Build a program with one RolePlay (non-null `behavior`, non-null `background`) and one Actor (non-null `notes`). Run `DrillFile.fromProgram`. Decode the zip manually. Assert that `roleplays/<uuid>/behavior.md`, `roleplays/<uuid>/background.md` and `actors/<uuid>/notes.md` exist with the expected UTF-8 content. Assert that the matching `.json` manifests do not contain the `behavior`, `background` or `notes` keys.

* `reads back 1.1 archive with inline markdown fields`. Use `_build1_1Archive` to construct an archive with all three legacy inline values populated. Decode via `DrillFile.program()`. Assert that `behavior`, `background` and `notes` are preserved on the entities. This is the critical migration test.

* `prefers .md file over legacy inline JSON when both present`. Hand-build an archive that has *both* an inline JSON value and a `.md` file with different content. Decode and assert that `.md` content wins.

* `empty md file roundtrips as empty string, missing as null`. Build a program with `behavior: ''` and `background: null`, write, read back, assert that `behavior == ''` and `background == null`. The writer should emit a zero-byte `behavior.md` and no `background.md`.

* `roundtrip preserves content hash`. Build a program with populated `behavior`, `background` and `notes`. Compute its `computeContentHash`. Run `fromProgram` then `program()`. Compute the decoded program's `computeContentHash`. Assert equality. This test will pass at Step 5 and is the regression guard against the hashing gap.

Update the existing `round-trips program with rolePlays and actors, schema is 1.1` test. After Step 5 it should expect `'1.2'`. Add `behavior` and `background` to the rolePlays it constructs, and `notes` to the actor, so the test now exercises markdown roundtrip end-to-end.

Files expected in this commit:

* `test/data/drill_file_roleplay_test.dart`

Run `git status` and verify only this path is staged. Commit: `test(data): cover 1.1-to-1.2 migration of behavior, background and actor notes`.

### Step 5. Flip the schema pointer and fix the content hash

Edit `lib/data/drill_file.dart`. Change `drillSchemaCurrent` to `drillSchema1_2`. Every `.drill` written by this client from now on is stamped `'1.2'`.

Edit `lib/models/program.dart` `ProgramX.computeContentHash`. Today the hash is computed over each entity's `toJson`. After Step 2, RolePlay's `toJson` no longer includes `behavior` and `background`, which means these fields silently fall out of the content hash and every program with populated values appears unchanged to the catalog regardless of edits. Fix this by folding the markdown string fields back into the canonical map before hashing.

The cleanest place is the existing canonical-map builder. For rolePlays specifically, replace the generic `_sortedCanonical(rolePlays, (r) => r.uuid)` call with a path that sorts on uuid, calls `toJson` per item, then injects the markdown values from the in-memory entity into the resulting map (`map['behavior'] = rp.behavior; map['background'] = rp.background;`) before canonicalization. Keep the rest of the hash inputs untouched. Actor stays excluded from the hash entirely per ADR-0018, so `actor.notes` does not need similar treatment.

Verify the hash test from Step 4 (`roundtrip preserves content hash`) goes green. Additionally, add a test that mutating `behavior` on a rolePlay changes the hash, and that two programs with identical content but different archive-entry orders produce equal hashes.

Run `flutter analyze`. Run `flutter test test/data/drill_file_roleplay_test.dart`. Run the Netlify test suite (`make netlify-test` if that target exists, otherwise `node --test netlify/functions/__tests__/drills-upload-strip.test.mjs`).

Files expected in this commit:

* `lib/data/drill_file.dart`
* `lib/models/program.dart`
* `test/data/drill_file_roleplay_test.dart` (the hash-stability and mutation-changes-hash tests)

Run `git status` and verify only these paths are staged. Commit: `feat(data): bump drillSchemaCurrent to 1.2 and fold markdown into computeContentHash`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken. Do not try to fix it.
3. `node --test netlify/functions/__tests__/` is green.
4. `make build` completes cleanly. Re-run `git status` after it: if any regenerated file is suddenly dirty after analyze and test passes, that file was missing from an earlier commit. Stop and amend the relevant commit before continuing.
5. **Clean tree gate.** `git status` on the working branch prints `nothing to commit, working tree clean`, and `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. The stage is not complete until this is true. Do not invoke `git stash` or `git restore` to satisfy it.
6. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended. If a regenerated `.freezed.dart` shows up two commits later than the annotation that triggered it, fix the history with `git rebase -i` before declaring the stage done.
7. Manual QA matrix (record the result in the final commit body or a `docs/notes/` file, whichever matches existing convention):
   * **CLI import.** Take a `.drill` archive produced by a pre-Stage-1a build of the app (schema 1.1, has populated `behavior`, `background` and `notes`). Pass it through `dart bin/ringdrill.dart upload ...` and verify the catalog receives the bytes without error. Re-download the archive from the catalog and verify the actors are stripped, `roleplays/<uuid>/behavior.md` is present, and the JSON manifests no longer carry the inline `behavior`/`background` keys.
   * **Netlify upload against `netlify dev`.** Run `make netlify-dev` and POST a Stage-1a-built archive (schema 1.2) to `/drills/upload`. Verify 200 OK. POST a hand-built archive with `schema: '1.3'` and verify 415 with `error: unsupported_schema`. POST a legitimate 1.1 archive and verify 200 OK (backward acceptance still works).
   * **Round-trip a 1.1 archive in the app.** On a device with the previous app version installed, export a program that has populated `behavior`, `background` and `notes`. Install the Stage-1a build over it. Open the program, verify the three fields are populated on screen. Save or publish. Inspect the saved `.drill` (it should now have `.md` files and be stamped 1.2). Open it again and verify content is preserved.
   * **Shared-file channel.** On macOS, share the same 1.1 archive to the app via Finder. Verify the import lands the user on the program with markdown content intact.
8. Confirm the orphan `.dev` bug from ADR-0021 is *not* touched. Stage 1a only changes archive format and schema, not bundle IDs.

## Deliverables

A series of four to five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A short summary of what migrated and what did not (Stage 1b new fields are explicitly deferred).
* The manual QA matrix filled out.
* A note that the 1.1 reader meets 1.2 archive risk is unchanged from ADR-0018's deferred mitigation class. No code change for it in this stage.

ADR-0022 is the authoritative spec for the archive format. DESIGN-004 is the authoritative spec for the staging. If you find yourself contradicting either, stop and ask. Do not write a new ADR.
