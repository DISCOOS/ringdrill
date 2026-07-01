# Implement ADR-0043: tags in the `.drill` format

You are working in the RingDrill repository. Implement ADR-0043 ("Tags live in the `.drill` format and publish is last-write-wins") end-to-end. The ADR at `docs/adrs/0043-tags-in-drill-format.md` is the authoritative spec — read it first, then read this prompt in full before touching code.

Context you can rely on as already shipped (merged 2026-07-01): the publish handler already reads plan-level `name` and `description` from `program.json`. The pure helpers `programInfoFromArchive` and `resolveCatalogFields` and the handler wiring live in `netlify/functions/drills-upload.js`, with tests in `netlify/tests/drills-upload-meta.test.mjs`. This change extends that same path to `tags`.

The single behavioural change: tags stop being catalog-only union-accumulated state and become an owner-editable field on the plan, carried in `program.json`. Publish becomes last-write-wins for `tags` (as it already is for `description`). Missing tags == empty list, everywhere — no migration, no schema bump.

Plan content has one source. `name`, `description` and `tags` come solely from `program.json`; the query string no longer overrides any of them. This step **removes the `?description=` override** (shipped 2026-07-01) and the client's **`?name=file.fileName`** (an older TODO). After this change the publish query string carries only operation parameters: `ownerId`, `programId`, `version`, `slug`, `published`.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* Run `make build` after any change to a `@freezed` class or `json_serializable` model. Never hand-edit `*.freezed.dart` or `*.g.dart`.
* The CLI must stay Flutter-free. `bin/ringdrill.dart` transitively imports `lib/data/`, never `lib/views/`. The model change is under `lib/models/` and is safe, but verify with `rg "package:ringdrill/views" bin/ lib/data/` if you touch anything else.
* User-visible UI strings (tags field label, hint, add/remove tooltips, validation messages) go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. No raw English in widgets. Run `make i18n` (`flutter gen-l10n`) after editing an ARB — `make build` does NOT regenerate `app_localizations*.dart`.
* Norwegian UI term for tags is "Etiketter" (field/section label) and "etikett" (singular). English is "Tags" / "tag". Keep IDs and code identifiers English (`tags`).
* Do NOT bump the archive schema. `KNOWN_SCHEMA_MAX` stays `1.2`. The field is additive; missing key reads as `[]`.
* Do NOT touch version/release steps or `pubspec.yaml` version. Releases go through the release script.
* Run `flutter analyze`, `flutter test`, and `npm test` (the Netlify suite) before claiming the change is green. `test/widget_test.dart` has been removed, so a clean run is the baseline.

## Commits

Commit as you progress, not in one blob. Conventional Commits with a scope. Types in use: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Scopes in use: `models`, `data`, `views`, `l10n`, `functions`/`netlify`, `docs`. Write commit messages in English even though this prompt is mixed-language. Suggested subjects:

* `feat(models): add tags to Program (@Default([]), backward compatible)`
* `feat(views): edit plan tags in the Program Editor`
* `feat(netlify): resolve catalog tags from program.json, overwrite on publish`
* `refactor(data): stop sending ?tags= — tags travel in program.json`
* `docs(adr): mark ADR-0043 accepted and note union→overwrite in AGENTS.md`

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the files expected in that commit. The commit must include every listed path. Regenerated files (`*.freezed.dart`, `*.g.dart`, `app_localizations*.dart`) ship in the SAME commit as the source change that triggered them — never a follow-up regen commit.
* Never close a step with `git stash` or `git restore`. If it is in the working tree, it ships.
* The final Verification gate requires `git status` to print a clean tree with no untracked or unstaged files.

## Scope

Five steps, in order.

### Step 1. Add `tags` to the Program model

Edit `lib/models/program.dart`. Add a `tags` field to the `Program` factory, next to `rolePlays`/`actors`, using the same backward-compat pattern:

```dart
// @Default(const []) so 1.0/1.1/1.2 archives without the key deserialize to
// an empty list rather than failing (ADR-0043; same pattern as ADR-0018).
@Default(<String>[]) List<String> tags,
```

`tags` is a plain JSON field, so it serializes into `program.json` automatically (unlike the markdown fields, which are `includeFromJson: false`). Do NOT add `@JsonKey(includeFromJson: false...)`.

Run `make build` to regenerate `program.freezed.dart` and `program.g.dart`. Confirm `program.g.dart` reads `tags` with a `?? const []` fallback so a missing key is safe.

Add a model test asserting the three cases: a `program.json` map without `tags` deserializes to `[]`; with `tags: []` deserializes to `[]`; with `tags: ["a","b"]` round-trips. Put it with the existing model tests (find them with `rg -l "Program.fromJson" test/`); create `test/models/program_tags_test.dart` if there is no obvious home.

Files expected in this commit: `lib/models/program.dart`, `lib/models/program.freezed.dart`, `lib/models/program.g.dart`, the model test file.

### Step 2. Edit tags in the Program Editor

Locate the Program Editor (the form that edits program name/description). Find it with `rg -l "descriptionController|Program.*Editor|editProgram" lib/views/`. Add a tags editor to the same form, next to the description field: a chip-style input where the owner can add and remove free-text tags, backed by `program.tags`. Follow existing editor conventions in that file for controllers, save wiring, and how edits flow back into the `Program` (`copyWith(tags: ...)`).

Keep it simple: lower-case-trim on add, dedupe, no empty tags, reasonable max length per tag. No server round-trip here — this only edits the in-memory/persisted plan. Publishing (Step 3/4) is what carries tags to the catalog.

Add ARB strings (`programEditorTagsLabel`, `programEditorTagsHint`, `programEditorTagRemoveTooltip`, plus any validation message) to both `app_en.arb` and `app_nb.arb`. Run `make i18n`.

Files expected in this commit: the editor widget, `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `lib/l10n/app_localizations*.dart`, and any editor test you add.

### Step 3. Resolve tags from program.json on the server

Edit `netlify/functions/drills-upload.js`, extending the helpers that already handle name/description and tightening them to a single source:

* `programInfoFromArchive`: also return `tags`, read as `Array.isArray(p?.tags) ? p.tags : []`. Missing or malformed → `[]`. Never throw.
* `resolveCatalogFields`: `name`, `description` and `tags` all come solely from the program — drop every query branch. `name` = `program.name` when non-empty, else `slug`; `description` = `program.description ?? ""`; `tags` = the program's tags (already `[]` when absent). Remove the `nameParam`/`descriptionParam` parameters and stop reading `?name=`/`?description=`. The function's inputs become `{ program, slug }`. Return `{ name, description, tags }`.
* Handler: replace the union line

  ```js
  currentMeta.tags = Array.from(new Set([...(currentMeta.tags || []), ...tags]));
  ```

  with a straight overwrite from the resolved value: `currentMeta.tags = tags;`. Delete the handler's local `?tags=` query parse (`const tags = (qs.get("tags") || ...)`) — it is dead once the program is authoritative. Do not read `?name=` or `?description=` anywhere. Note: `slug` is still derived from `qs.get("slug") || qs.get("name")` earlier in the handler — leave that derivation alone; the client always sends `?slug=`, and `name` there is only a legacy slug fallback, not the catalog name.

Update `netlify/tests/drills-upload-meta.test.mjs`. The existing tests assert "query params win over program.json" for name/description — rewrite those to assert `name`, `description` and `tags` come from `program.json` and that `?name=`/`?description=`/`?tags=` queries are ignored. Add: name falls back to `slug` when `program.name` is empty; tags read from program.json; file without tags → `[]`; file with `tags: []` → `[]` (removal); publish overwrites rather than unions (an existing larger catalog set is replaced by a smaller resolved set). Run `npm test`.

Files expected in this commit: `netlify/functions/drills-upload.js`, `netlify/tests/drills-upload-meta.test.mjs`.

### Step 4. Stop sending `?tags=` from the client

Edit `lib/data/drill_client.dart`. Name, description and tags now travel inside `program.json`, so the `_uploadOnce` query builder must stop sending plan content:

* Remove `if (tags.isNotEmpty) 'tags': tags.join(',')`.
* Remove `'name': file.fileName` and delete the `// TODO: Add name to Drill Program` comment — this ADR retires that TODO. `name` comes from `program.name` server-side.
* Keep the operation params: `ownerId`, `programId`, `version` (when set), `slug`, `published`.

Decide the `tags` parameter's fate on `upload`/`_uploadOnce`: if nothing else needs it, remove the parameter; if callers still pass it, thread it into the `Program` before export rather than into the query string. Check callers with `rg -n "\.upload\(" lib/ bin/` and update them.

Reconcile the "Publish as…" flow: its tags entry must now write onto the plan (`program.tags`) so the exported `.drill` carries them, instead of passing them as a publish-time query param. Find it with `rg -l "publish|PublishAs|tags" lib/views/`. If "Publish as…" and the Program Editor now offer the same tags editing, keep the Program Editor as the primary surface and make "Publish as…" either reuse it or drop the duplicate field — note in the commit body which you chose and why.

Files expected in this commit: `lib/data/drill_client.dart`, any view file for the "Publish as…" flow you touched, and updated/added tests.

### Step 5. Docs

Flip `docs/adrs/0043-tags-in-drill-format.md` front-matter `status:` from `proposed` to `accepted`. In `AGENTS.md`, add a one-line note under the drill-format/catalog section that catalog `tags` are now sourced from `program.json` and overwritten on publish (previously union-merged from `?tags=`). Update `docs/adrs/0007-drill-file-format.md`'s archive-layout note for `program.json` to mention `tags` if that file enumerates program fields.

Files expected in this commit: `docs/adrs/0043-tags-in-drill-format.md`, `AGENTS.md`, and `docs/adrs/0007-drill-file-format.md` if edited.

## Verification gate

Do not claim done until all of these pass:

* `flutter analyze` clean (no new warnings).
* `flutter test` green.
* `npm test` green (all Netlify suites).
* `rg "package:ringdrill/views" bin/ lib/data/` returns nothing.
* `git status` shows a clean tree — no untracked, no unstaged, all regenerated files committed alongside their source.

## Out of scope

* Schema bump to 1.3 (not needed; ADR-0043 keeps `KNOWN_SCHEMA_MAX` at 1.2).
* Any tag taxonomy, autocomplete, or suggested-tags feature. Free-text only.
* Admin tag editing.
