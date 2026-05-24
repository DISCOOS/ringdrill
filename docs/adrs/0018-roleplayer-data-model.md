---
status: accepted
date: 2026-05-23
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0018: Introduce RolePlay and Actor entities, persist schema 1.1 in metadata

## Context and problem statement

RingDrill exercises in the SAR domain rely on *markører* (role-players) who portray missing persons, casualties or witnesses at one or more stations. Today the data model has no place for them. Authors keep that information in chat threads or paper notes, so it never travels with the `.drill` file. Catalog-shared exercises cannot include their cast, and the app has nowhere to manage one.

Two concerns must not be mixed: the *role* being portrayed (publishable character information) and the *human* portraying it (PII that must never reach the catalog). A single shared model would either leak phone numbers on upload or strip useful scenario context from published files.

The format defined in [ADR-0007](./0007-drill-file-format.md) declares a schema constant in code (`DrillFile.drillSchema1_0`) but never persists it to the archive. This ADR is the natural moment to start writing it.

## Decision drivers

* Role data must round-trip through the catalog. Personal data must not.
* The change must be backward and forward compatible at the file-parsing level so older and newer clients can open each other's files without errors.
* Names must reflect what the entities are. The publishable record is the *role*, not the player. The model uses **`RolePlay`** (the role) and **`Actor`** (the human), with "a RolePlay is enacted by an Actor" as the mental model. Folder names (`roleplays/`, `actors/`) and `Program` fields (`rolePlays`, `actors`) follow the same convention so the privacy boundary is visible in code review.
* New models follow ADR-0002 conventions (freezed, JSON, behaviour in extensions).
* The CLI must remain Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md).
* The schema marker should land now, so future evolution has something to read.

## Considered options

* **Option A:** Single `RolePlay` model holding both role and actor fields, with a `publish` flag stripped on upload.
* **Option B (chosen):** Two models, `RolePlay` and `Actor`, in distinct archive folders. The `actors/` folder is stripped server-side on catalog upload. Schema `1.1` is persisted in `metadata.json` without client-side enforcement.
* **Option C:** Option B plus refuse-to-save in the client when it sees an unknown schema.
* **Option D:** Add the folders without persisting any schema marker.

## Decision outcome

Chosen option: **Option B**. The folder boundary mirrors the privacy boundary one-to-one, the catalog-side strip is a one-liner, and the persisted schema marker buys future migrations without committing to enforcement we are not ready to ship.

### Models

```dart
// lib/models/role_play.dart
@freezed
sealed class RolePlay with _$RolePlay {
  const factory RolePlay({
    required String uuid,
    required int index,
    required String exerciseUuid,
    required String name,
    int? age,
    String? signalement,
    String? background,
    String? behavior,
    int? stationIndex,
    @NullableLatLngJsonConverter() LatLng? position,
    String? actorUuid, // links to an Actor when the role is cast
  }) = _RolePlay;

  factory RolePlay.fromJson(Map<String, dynamic> json) =>
      _$RolePlayFromJson(json);
}
```

```dart
// lib/models/actor.dart
@freezed
sealed class Actor with _$Actor {
  const factory Actor({
    required String uuid,
    required String realName,
    String? phone,
    String? notes,
  }) = _Actor;

  factory Actor.fromJson(Map<String, dynamic> json) =>
      _$ActorFromJson(json);
}
```

The link `RolePlay.actorUuid → Actor.uuid` assumes one Actor per RolePlay per exercise. The indirection is preserved so a future ADR can relax that assumption without a schema change.

`Program` gains:

```dart
required List<RolePlay> rolePlays,
required List<Actor> actors,
```

`computeContentHash` includes `rolePlays` and excludes `actors`, so local cast changes never flag the program as "ahead of remote" in catalog refresh logic ([ADR-0010](./0010-live-catalog-updates.md)). `diffPrograms` gains added/removed/modified lists for `rolePlays` only.

### Archive layout

```
.drill (zip)
  metadata.json              ProgramMetadata, now with `schema` field
  program.json
  exercises/<uuid>.json
  teams/<uuid>.json
  sessions/<uuid>.json
  roleplays/<uuid>.json      NEW. Publishable.
  actors/<uuid>.json         NEW. PII. Never published.
```

`DrillFile.fromProgram` writes both folders. `DrillFile.program()` reads them. Older clients silently ignore both, since the reader matches known prefixes only.

### Schema marker

`ProgramMetadata` gains an optional `schema` field set to `'1.1'` by 1.1-aware code. The constant becomes:

```dart
class DrillFile {
  static const drillSchema1_0 = '1.0';
  static const drillSchema1_1 = '1.1';
  static const drillSchemaCurrent = drillSchema1_1;
  ...
}
```

No client-side enforcement in this ADR. Older clients drop the field on deserialization; newer clients treat its absence as 1.0. The marker only needs to exist on disk so a later ADR can act on it.

### Backend

`netlify/functions/drills-upload.js` strips `actors/` from the archive before storage, and rejects uploads whose `metadata.json` declares a `schema` higher than the highest version it knows about (currently `1.1`). Stripping happens server-side because the same `.drill` may legitimately carry `actors/` peer-to-peer (USB stick, AirDrop, email); the only boundary that matters is the catalog. `drills-head.js` and `deep-link.js` are unchanged.

### Consequences

* Good: Role data round-trips through `.drill` and the catalog without leaking PII.
* Good: Class names, folder names and the privacy boundary all line up. "A RolePlay is enacted by an Actor" reads the same in prose, in code, and in a zip inspector.
* Good: A schema marker now exists on disk. Future migrations have something to read.
* Bad: An older client that opens, edits and saves a newer file silently drops `roleplays/` and `actors/`. Mitigation is deferred to a follow-up ADR.
* Bad: Coordinated change across Flutter app, models and Netlify upload handler ([AGENTS.md](../../AGENTS.md) flags this as the standard cost of a schema bump).
* Bad: `actors` is the only collection on `Program` that does not contribute to the content hash. Future contributors need to be told this rather than infer it from the type signature.
* Bad: The class name `Actor` overlaps lexically with the Actor Model concurrency pattern. RingDrill does not use that paradigm anywhere, but contributors arriving from Erlang or Akka may need a moment to reorient.

## Pros and cons of the options

### Option A — Single model with a `publish` flag

* Good: Simplest schema, one folder, one model.
* Bad: Mixes publishable and private fields in the same object. PII leakage becomes a procedural concern instead of a structural one.
* Bad: The upload handler has to inspect every field of every record instead of dropping a folder.

### Option B — Two models, two folders, schema persisted (chosen)

* Good: Privacy boundary is a folder boundary.
* Good: Server-side strip is a one-liner.
* Good: Persists the schema marker without committing to enforcement.
* Bad: Two new top-level collections on `Program`.
* Bad: The `actorUuid` indirection pays off only when the one-Actor-per-RolePlay assumption is later relaxed.

### Option C — Option B plus refuse-to-save enforcement now

* Good: Closes the silent-data-loss window immediately.
* Bad: Ships enforcement logic and end-user UX (refusal dialog, explanation, possibly an export-to-old-format path) in the same change set as the model work.
* Bad: Premature. The infrastructure is the valuable part; enforcement can land once mixed-version files actually exist in the wild.

### Option D — Folders without a schema marker

* Good: Zero coordination overhead.
* Bad: Wastes the natural moment to start persisting a schema. The next versioning need would introduce both the marker and its own change at once.

## Links

* Related ADRs:
  * [ADR-0002](./0002-freezed-models-with-extensions.md) — model conventions.
  * [ADR-0005](./0005-cli-must-remain-flutter-free.md) — CLI constraint the new models must satisfy.
  * [ADR-0007](./0007-drill-file-format.md) — file format. This ADR extends the archive and persists `schema` for the first time.
  * [ADR-0008](./0008-persistent-program-library-and-catalog.md) — catalog publication model.
  * [ADR-0010](./0010-live-catalog-updates.md) — content hash and catalog refresh logic.
  * [ADR-0014](./0014-server-assigned-drill-version.md) — upload contract. The natural home for the `actors/` strip.
  * Planned ADR-0019 — `roleplayer` as a third participant role in the realtime/session model. Extends [ADR-0009](./0009-realtime-transport-and-session-model.md), [ADR-0011](./0011-synchronized-exercise-control.md) and [ADR-0012](./0012-position-sharing-and-team-aggregation.md).
* Related designs:
  * Planned DESIGN-003 — Markører-fanen og roleplayer-mini-spilleren.
* Related code:
  * `lib/models/program.dart` — new collections, hash and diff updates.
  * `lib/models/role_play.dart`, `lib/models/actor.dart` — new models.
  * `lib/data/drill_file.dart` — read/write of `roleplays/` and `actors/`, new schema constant.
  * `netlify/functions/drills-upload.js` — strip `actors/`, reject unknown future schemas.
