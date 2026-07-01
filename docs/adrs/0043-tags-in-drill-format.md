---
status: accepted
date: 2026-07-01
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0043: Tags live in the `.drill` format and publish is last-write-wins

## Context and problem statement

Tags are today a catalog-only concept. They never touch the `.drill` file: the Flutter client passes them as a `?tags=` query param on publish, and the Netlify function stores them in the catalog `meta.json`. The publish handler merges them as a union:

```js
currentMeta.tags = Array.from(new Set([...(currentMeta.tags || []), ...tags]));
```

Two problems follow. First, tags are invisible to the plan owner. They cannot be seen or edited in the Program Editor, only re-sent at publish time through the "Publish as…" dialog. Second, the union is additive-only: a re-publish can add tags but never remove one. Publishing again with a smaller set silently keeps the old tags. There is no single source of truth for what a plan is tagged with.

We want tags to belong to the plan, be edited in the Program Editor, and travel with the `.drill` file. Publishing should then simply reflect what the owner wrote, for both `description` (already wired in from `program.json`) and `tags`.

The catch is compatibility. `.drill` files in the wild (schema 1.0, 1.1, 1.2) have no tags field. Both the app and the server must read those files without error, and introducing tags must not reject or corrupt older archives.

## Decision drivers

* Tags must be owner-editable and have one source of truth (the plan), not hidden catalog state.
* Publish must be able to remove a tag, not only add — fix the additive-only union.
* Files without a tags field must be handled gracefully as an empty list, in the app and on the server. No migration step, no schema-max rejection.
* Keep the coordinated schema-bump cost low (see ADR-0007: schema bumps are coordinated changes across app, CLI and functions).
* Tags are not PII, so carrying them peer-to-peer inside `.drill` is acceptable (unlike `actors/`, ADR-0018).

## Considered options

* A: Add `tags` to `Program` in `program.json` with `@Default(const [])`; publish is last-write-wins; the server reads name, description and tags from `program.json` as the single source (no query overrides for plan content).
* B: Keep tags catalog-only, just switch the server merge from union to overwrite.
* C: Store tags in a dedicated `tags.json` archive part.

## Decision outcome

Chosen option: **Option A**, because it makes the plan the single source of truth, lets the Program Editor own tags, and fixes the additive-only bug in one move.

`tags` becomes a first-class `List<String> tags` on `Program`, serialized into `program.json`, declared with `@Default(const [])` following the ADR-0018 backward-compat pattern already used for `rolePlays` and `actors`. No hard schema bump is required: the field is additive, older archives that lack the key deserialize to `[]`, and older clients ignore the unknown key. Because `json_serializable` always writes the key for a field that exists on the model, a new-app export always contains `tags` (possibly `[]`), and an old-app export never does — but both are read identically.

**Missing tags == empty list, everywhere.** A file without the field is semantically "no tags", not "unknown". We do not need a tri-state (absent vs. empty), because there are no meaningful server-side tags to protect today. The server reads `Array.isArray(p?.tags) ? p.tags : []`, and publish overwrites `currentMeta.tags` with that value.

**Plan content has one source: `program.json`.** `name`, `description` and `tags` are sourced solely from the archive — the query string no longer overrides any of them. The `?description=` override wired in on 2026-07-01 and the client's `?name=file.fileName` (an older TODO) are both removed as part of this change, so there is one source of truth, not two. `name` resolves to `program.name`, falling back to `slug` only when the program name is empty. The publish query string carries only operation parameters: `ownerId`, `programId`, `version`, `slug`, `published`.

We deliberately do **not** bump the archive schema to 1.3. `KNOWN_SCHEMA_MAX` stays at `1.2`, avoiding the reject-until-deployed coordination a bump forces. A future bump for telemetry remains possible but is not needed for correctness.

### Consequences

* Good: One source of truth. Name, description and tags are visible and editable in the Program Editor and travel with the file; the publish query string carries only operation parameters.
* Good: Publish can now remove a tag. The additive-only union is gone.
* Good: Backward compatible with schema 1.0/1.1/1.2. Missing tags read as `[]` in the app and on the server, with no migration.
* Good: No schema-max coordination. Old clients ignore the unknown key; new clients default a missing key to `[]`.
* Bad: Re-publishing an old-format file (no tags) now clears any catalog tags that were set via the old union path. Acceptable because there are no meaningful server-side tags in use.
* Bad: The server tag semantics change from union to overwrite — a behavior change worth calling out in `AGENTS.md`.
* Bad: The "Publish as…" tags entry becomes redundant with editor-owned tags and must be reconciled (write to the plan, or drop it).

## Pros and cons of the options

### Option A — tags on `Program` in `program.json` (chosen)
* Good: Single source of truth; editable in the Program Editor; fixes remove.
* Good: Backward compatible via `@Default(const [])` and key-absence == empty.
* Bad: Old-file re-publish clears catalog tags (acceptable today).

### Option B — catalog-only, union → overwrite
* Good: Smallest change; no model or format work.
* Bad: Tags stay invisible to the owner; no single source of truth; "Publish as…" remains the only way to set them.

### Option C — dedicated `tags.json` archive part
* Good: Cleanly separated from the program shell.
* Bad: Over-engineered for a handful of strings that logically belong to the program shell; another part to keep consistent on read/write.

## Links

* Related ADRs: [ADR-0007](./0007-drill-file-format.md) (`.drill` format and schema evolution), [ADR-0018](./0018-roleplayer-data-model.md) (`@Default([])` backward-compat pattern), [ADR-0008](./0008-persistent-program-library-and-catalog.md) and [ADR-0025](./0025-authorization-and-publish-policy.md) (catalog and publish policy)
* Related code: `lib/models/program.dart`, `lib/data/drill_file.dart`, `lib/data/drill_client.dart`, `netlify/functions/drills-upload.js`, `netlify/tests/drills-upload-meta.test.mjs`
* Operating rule (in [`AGENTS.md`](../../AGENTS.md)): "Drill file format is versioned" and "schema bumps are coordinated changes"
* Retires the `// TODO: Add name to Drill Program` in `lib/data/drill_client.dart` (client no longer sends `?name=file.fileName`).
* Follow-up: reconcile the "Publish as…" tags entry with editor-owned tags; consider a 1.3 schema bump for telemetry only.
