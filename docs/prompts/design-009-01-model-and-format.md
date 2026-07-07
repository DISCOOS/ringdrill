# Implement DESIGN-009 — Prompt 1: model and format

You are working in the RingDrill repository. Implement the model-and-format layer of DESIGN-009 ("Scenario locations and persons"). [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) is the authoritative data-model decision and `docs/design/009-scenario-locations-and-persons.md` the design. Read both, and read `AGENTS.md` — rule 9 (test-loop discipline) governs how you run tests here.

This is the **data layer only**: the `Location`, `Person` and `LocationKind` types, their station-owned collections, the two new `RolePlay` fields, the content hash, and the `.drill` round-trip. No resolution (prompt 2), no editor or map (prompts 3–5). When this ships, a `.drill` can carry scenario locations and persons and round-trips, and older files still load.

## Ground rules

* **Codegen, not regex** (rule 1). New/changed `@freezed` classes and enums need `make build`; never hand-edit `*.freezed.dart` / `*.g.dart`. Batch codegen — run `make build` once after a step's model edits, not per file.
* **Additive, no schema bump** (ADR-0047, rule 8). Every new field is additive with `@Default` (or nullable). `KNOWN_SCHEMA_MAX` is unchanged. Do not touch `netlify/functions/`.
* **`personRef` is nullable** (`String?`). Mandatory is an editor invariant handled in a later prompt; the model field is nullable so legacy roleplays load. The `RolePlay` identity fields are **not** removed and **not** emptied — they keep holding the (effective) identity. Denormalization/inherit semantics are prompt 2/4; this prompt only adds the fields.
* **`LocationKind`** is an enum whose JSON value is a stable slug; decode unknown values to `other` via `@JsonKey(unknownEnumValue: LocationKind.other)` on the field. Its `label`/`description` come from i18n and are added with the editor (prompt 3) — not here.
* **Structured JSON, not `.md` files.** `Location`/`Person` are short structured data and serialize as ordinary JSON on the station (nested in `program.json`), like `tags` and `variableOverrides`. [ADR-0022](../adrs/0022-markdown-content-as-files.md) does not apply. `note`/`notes` are short JSON strings, not markdown documents.
* **Models stay Flutter-free and mobile-safe** (rules 3, 6, 7). `Location`/`Person` are reachable from `bin/ringdrill.dart` transitively; no `package:flutter/*`, `dart:html` or `package:web`. Use `SimpleTimeOfDay` conventions where relevant (positions use the existing `LatLng` + `NullableLatLngJsonConverter`).
* **Test-loop discipline (AGENTS.md rule 9).** Per commit: `flutter analyze` + only the targeted tests for what you touched (`flutter test test/models/`). Run the full `flutter test` and `dart build cli` **once at the very end**, not per commit.

## Scope

Four commits.

### Commit 1. The `Location`, `Person` and `LocationKind` types

Create `lib/models/location.dart`, `lib/models/person.dart` and the `LocationKind` enum (co-locate it in `location.dart`). Follow the freezed + `json_serializable` pattern of the other `lib/models/` files.

```dart
enum LocationKind {
  lkp, ipp, pp, rendezvous, commandPost, home, trackFound, dogInterest,
  obstacle, notSearchable, phoneTrace, observation, vantagePoint,
  containmentPost, personFound, other,
}

@freezed
sealed class Location with _$Location {
  const factory Location({
    required String slug,            // ^[a-z][a-z0-9_]*$, unique within the station
    @Default('') String label,       // display name
    @Default(LocationKind.other)
    @JsonKey(unknownEnumValue: LocationKind.other) LocationKind kind,
    @Default('') String place,       // address / place description
    @NullableLatLngJsonConverter() LatLng? position,
    String? note,
  }) = _Location;
  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
}

@freezed
sealed class Person with _$Person {
  const factory Person({
    required String slug,            // ^[a-z][a-z0-9_]*$, unique within the station
    @Default('') String name,        // display name
    int? age,
    String? gender,
    String? signalement,
    String? homeSlug,                // references a Location.slug on the same station
    String? notes,
  }) = _Person;
  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);
}
```

Do not add slug-validation or uniqueness logic to the models — that is an editor concern for a later prompt. `make build`.

Files expected: `lib/models/location.dart`(+ `.freezed.dart`/`.g.dart`), `lib/models/person.dart`(+ generated).

Per commit: `flutter analyze`; `flutter test test/models/` is not meaningful yet (no tests) — skip until commit 4. Commit: `feat(models): add Location, Person and LocationKind`.

### Commit 2. Station and RolePlay fields

Edit `lib/models/station.dart`:

```dart
@Default(<Location>[]) List<Location> locations,
@Default(<Person>[]) List<Person> persons,
```

Edit `lib/models/role_play.dart`:

```dart
String? personRef,   // slug of a Person on the roleplay's station (nullable; editor-enforced later)
String? gender,      // new identity field, parallel to name/age/signalement
```

Import the new models where needed. `make build`.

Files expected: `lib/models/station.dart`, `lib/models/role_play.dart` (+ generated).

Commit: `feat(models): add station locations/persons and roleplay personRef/gender`.

### Commit 3. Content hash

Extend `ProgramX.computeContentHash` (`lib/models/program.dart`) so a change to any station's `locations` or `persons`, or a roleplay's `personRef`/`gender`, produces a different hash. Follow the existing canonicalization: stations and roleplays already flow into the hash; confirm the new fields are included and not stripped by the existing denylist. Locations/persons within a station should hash deterministically (canonicalise by `slug`) so archive order never changes the hash.

Files expected: `lib/models/program.dart` (+ generated if any).

Commit: `feat(models): include scenario locations, persons and roleplay refs in the content hash`.

### Commit 4. Tests

Add tests under `test/models/`:

* `Location` / `Person` round-trip `toJson`/`fromJson`, including all fields and the empty/defaulted cases.
* `LocationKind` decodes a known value, and an **unknown** JSON value decodes to `other` (forward-compat).
* Backward compatibility: a station JSON without `locations`/`persons` deserialises to empty lists; a roleplay JSON without `personRef`/`gender` deserialises to `null`. No exception.
* Round-trip through `DrillFile` (the real archive path): a `Program` with a station carrying locations + persons, and a roleplay with `personRef`/`gender`, survives write+read unchanged. This should need **no** `DrillFile` code change — they are ordinary JSON fields nested in `program.json`, unlike the `.md` fields. If it does need a change, make it and note why.
* Content-hash sensitivity: two programs differing only in a location, a person, a `personRef`, or a `gender` hash differently; two differing only in location/person list order hash **equal**.

Run `flutter analyze`. Run `flutter test test/models/`. Then, as the single final gate, the full `flutter test` and `dart build cli` (or `dart compile exe bin/ringdrill.dart`).

Files expected: test files under `test/models/`.

Commit: `test(models): cover scenario location/person serialization, backward-compat and hashing`.

## Verification (final gate — run once)

1. `flutter analyze` clean.
2. Full `flutter test` — no new failures.
3. `make build` idempotent (re-running produces no diff — committed generated files are current).
4. `dart build cli` (or `dart compile exe bin/ringdrill.dart`) succeeds — the new models stayed Flutter-free.
5. Backward-compat: a pre-existing `.drill` fixture (no locations/persons/personRef) loads with empty collections and null refs, no exception.
6. `git diff --stat` touches only `lib/models/…` and `test/models/…` (no `lib/views/`, `lib/services/`, `netlify/`). `KNOWN_SCHEMA_MAX` unchanged.
7. Clean tree; `git ls-files --others --exclude-standard` empty; every `*.freezed.dart`/`*.g.dart` sits in the commit with its source.

## Deliverables

Four Conventional Commits (English) on the working branch, clean tree, per-commit targeted checks and a single full-suite gate at the end (AGENTS.md rule 9). The final commit body notes that the data layer carries scenario locations/persons and the two roleplay fields additively (no schema bump), and defers resolution (prompt 2), the editor sections + map (prompt 3), the token picker + RolePlay editor + inline-create/write-back (prompt 4), and integrity (prompt 5).

ADR-0047 and DESIGN-009 are authoritative. If including the new fields in the content hash forces an awkward change to the denylist, or if a schema bump seems unavoidable, stop and ask rather than deviating. Do not write a new ADR for this prompt.
