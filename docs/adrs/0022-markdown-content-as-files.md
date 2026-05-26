---
status: accepted
date: 2026-05-25
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0022: Store long-form markdown content as `.md` files in the drill archive

## Context and problem statement

[DESIGN-004](../design/brief-template.md) adds a large set of long-form fields on `Program`, `Exercise`, `Station`, `RolePlay` and `Actor` (situation, mission, role-play behaviour, leader Q&A, director notes, and so on). Each is a markdown string of arbitrary length.

Adding them as `String?` columns in the existing JSON parts of the `.drill` archive is the obvious choice but carries four costs:

* Markdown round-trips through JSON string escaping. Editors with an internal document tree (AppFlowy, super_editor) can corrupt the content along the way, and any mustache `{{...}}` cross-reference inside the markdown becomes subject to two layers of escape.
* The wiki-style catalog ([ADR-0010](./0010-live-catalog-updates.md)) diffs at field granularity. Two authors editing different paragraphs of the same field collide as one conflict and last-writer-wins discards work.
* Manifests grow from kilobytes to hundreds of kilobytes once a season of content is written.
* External tooling cannot read or edit content blocks without parsing the JSON.

The `.drill` format is already a ZIP of separate parts ([ADR-0007](./0007-drill-file-format.md)), and [ADR-0018](./0018-roleplayer-data-model.md) established one folder per entity collection. Storing markdown next to its entity as a `.md` file extends the same shape.

## Decision drivers

* Editor round-trip must preserve `{{...}}` character-for-character.
* Diff in the catalog should be able to see that two authors edited different files, even if per-line merge is deferred.
* The `.drill` archive must stay a single shareable artefact.
* Models keep their current shape so call sites do not learn a new field type.
* Schema bumps are coordinated changes across Flutter app, CLI and Netlify functions ([AGENTS.md](../../AGENTS.md) rule 8), and need a migration path.
* The PII boundary from [ADR-0018](./0018-roleplayer-data-model.md) must extend without a backend-side change.

## Considered options

* **Option A:** `String?` markdown fields in the existing JSON parts.
* **Option B (chosen):** `.md` files inside the archive, one per markdown-bodied field, organised per entity. Schema bumps to 1.2.
* **Option C:** Hybrid. Short fields in JSON, large ones in files, picked by size threshold.
* **Option D:** Files with a flat naming scheme (`content/<field>-<entity-uuid>.md`).

## Decision outcome

Chosen option: **Option B**. Each markdown-bodied field is stored as a `.md` file in a per-entity folder. Schema bumps from 1.1 to 1.2.

### Archive layout (schema 1.2)

```
.drill (zip)
  metadata.json
  program.json
  program/intro.md
  program/comms.md
  exercises/<uuid>.json
  exercises/<uuid>/method.md
  exercises/<uuid>/learning-goals.md
  exercises/<uuid>/training-focus.md
  exercises/<uuid>/order-format.md
  exercises/<uuid>/execution-tips.md
  exercises/<uuid>/comms.md
  exercises/<uuid>/stations/<index>/equipment.md
  exercises/<uuid>/stations/<index>/situation.md
  exercises/<uuid>/stations/<index>/mission.md
  exercises/<uuid>/stations/<index>/logistics.md
  exercises/<uuid>/stations/<index>/critical-questions.md
  exercises/<uuid>/stations/<index>/leader-answers.md
  exercises/<uuid>/stations/<index>/director-notes.md
  teams/<uuid>.json
  sessions/<uuid>.json
  roleplays/<uuid>.json
  roleplays/<uuid>/behavior.md            (was a JSON string in 1.1)
  roleplays/<uuid>/background.md          (was a JSON string in 1.1)
  roleplays/<uuid>/props.md
  actors/<uuid>.json
  actors/<uuid>/notes.md                  (was a JSON string in 1.1, PII)
```

Naming rules:

* Each entity's JSON manifest stays at `<type>/<uuid>.json`. Markdown for that entity lives under `<type>/<uuid>/<field>.md`.
* Stations have no UUID and are scoped to their parent exercise: `exercises/<uuid>/stations/<index>/<field>.md`.
* `Program` content lives in `program/`, alongside `program.json`.
* Field names map to kebab-case file names. The trailing `Md` is dropped (`learningGoalsMd` → `learning-goals.md`).
* A missing file means null, an empty file means an empty string. The reader does not distinguish.

### Model representation

Freezed entity classes keep their `String?` markdown fields. Each one is annotated `@JsonKey(includeFromJson: false, includeToJson: false)` so the JSON parts hold only structural data. `DrillFile.fromProgram` writes the files. `DrillFile.program()` reads them back into the String fields. Forms, services and the renderer see plain `String?` and do not learn about the archive.

### Content hash

`ProgramX.computeContentHash` ([ADR-0010](./0010-live-catalog-updates.md)) hashes the in-memory entity tree. Because markdown is eagerly loaded into the String fields on read, the hash function works as today. `Program.actors` stays excluded, so `actor.notes` is excluded transitively.

### Schema bump and migration

```dart
class DrillFile {
  static const drillSchema1_0 = '1.0';
  static const drillSchema1_1 = '1.1';
  static const drillSchema1_2 = '1.2';
  static const drillSchemaCurrent = drillSchema1_2;
}
```

`ProgramMetadata.schema` is set to `'1.2'` by 1.2-aware writers.

* **1.2 reader, 1.1 archive:** no `.md` files exist. String fields stay null. Correct.
* **1.1 reader, 1.2 archive:** `.md` files are ignored, JSON manifest has no markdown (suppressed there too), program loads without brief content. Saving from this client drops the markdown. Same silent-data-loss class as ADR-0018, same deferred mitigation.

### Backend

`netlify/functions/drills-upload.js` strips `actors/` by path prefix, so `actors/<uuid>/notes.md` is removed by the existing rule. The accepted-schema set extends to include `'1.2'`. `drills-head.js` and `deep-link.js` are unchanged.

### Consequences

* Good: Editor round-trip stays in markdown space. No JSON-escape interaction.
* Good: Catalog diff can compare file-by-file. Per-file conflict detection later does not need another format change.
* Good: Manifests stay small. Content scales independently.
* Good: External tooling can read and write markdown by unpacking the archive.
* Good: PII boundary holds with no backend-side change.
* Good: Models and call sites keep `String?`. No new field type.
* Bad: Archives gain many small entries. ZIP compresses them well, but file count grows with content volume.
* Bad: 1.1 readers silently drop markdown on save. Same class of risk as ADR-0018.
* Bad: Stations are keyed by `(exerciseUuid, index)`. Reordering renames content folders. A follow-up ADR may add station UUIDs if reorder cost matters.
* Bad: Eager-load order in `computeContentHash` must be deterministic. Tests must lock it down.

## Pros and cons of the options

### Option A — `String?` fields in JSON

* Good: No format change, no schema bump.
* Good: Diff and hash code unchanged.
* Bad: Editor round-trip exposed to two escape layers.
* Bad: Diff stays at field granularity.
* Bad: Manifests grow without bound.
* Bad: Content locked inside JSON for external tools.

### Option B — markdown as files (chosen)

* Good: All gains listed under *Consequences*.
* Bad: Schema bump and coordinated change.
* Bad: Per-station path keying is fragile under reorder.

### Option C — hybrid by size

* Good: Short fields keep the JSON shape.
* Bad: Two code paths for the same conceptual field. Every reader has to know the rule.
* Bad: The threshold is arbitrary. Crossing it on edit silently moves the field.
* Bad: Diff and hash must handle both shapes.

### Option D — flat naming under `content/`

* Good: Single conceptual folder for all content.
* Bad: Content sits far from its owning entity in the archive.
* Bad: PII strip becomes per-file rather than per-prefix.
* Bad: Stations would need a globally unique key they do not have today.

## Links

* Related ADRs:
  * [ADR-0007](./0007-drill-file-format.md) — drill archive format. Extends layout, bumps schema.
  * [ADR-0010](./0010-live-catalog-updates.md) — content hash and refresh logic. Hash inputs unchanged.
  * [ADR-0014](./0014-server-assigned-drill-version.md) — upload contract. Accepts `'1.2'`.
  * [ADR-0018](./0018-roleplayer-data-model.md) — precedent for per-entity folders and for the silent-data-loss risk class.
* Related designs:
  * [DESIGN-004](../design/brief-template.md) — the exercise brief. Drives the requirement.
* Related code:
  * `lib/data/drill_file.dart` — read/write `*.md` files, new schema constant.
  * `lib/models/program.dart`, `lib/models/exercise.dart`, `lib/models/station.dart`, `lib/models/role_play.dart`, `lib/models/actor.dart` — `String?` fields annotated `@JsonKey(includeFromJson: false, includeToJson: false)`.
  * `lib/services/brief_renderer.dart` (new) — reads the String fields, unaware of the archive.
  * `netlify/functions/drills-upload.js` — accept `'1.2'`. No PII-strip change.
