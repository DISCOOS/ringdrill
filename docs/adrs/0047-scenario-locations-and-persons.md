---
status: proposed
date: 2026-07-03
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0047: Station-scoped scenario locations and persons, and RolePlay portrays a Person

## Context and problem statement

Two kinds of scenario data are duplicated across a station's text, its markers' text and the map today, and drift out of sync. The first is **positions**: a "last known position", a home, an observation point is typed as coordinates into the station's situation prose and again into a marker's play text, and separately the station and roleplay each carry an administrative `position` that drives their map marker. The second is **person identity**: a missing person's name, age and signalement live on the `RolePlay` that a marker enacts, but the station situation text repeats the same name, and there is no way to say "this witness / reporter / next-of-kin" as a reusable fact at all.

[ADR-0046](./0046-plan-variables.md) / [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md) solved *repeated string values* with a plan-global variable registry. Locations and persons are different: they are structured (a coordinate, a set of identity fields), they are scenario-bound rather than plan-wide, and they must also feed the map. A radio channel is plan-wide; a last-known-position belongs to one search scenario.

Note the existing distinction the app already draws for real people ([ADR-0018](./0018-roleplayer-data-model.md)): a `RolePlay` is the publishable, fictional role; an `Actor` is the real person who staffs it (the roster layer), carries PII, is stored locally and is stripped on publish. The scenario persons introduced here — the missing person, witnesses, reporters, next-of-kin — are **fictional scenario data with no PII**. The real human remains the `Actor`.

## Decision drivers

* One source of truth for a coordinate and for a scenario person's identity. Edit it once; the station text, the marker text, the brief and the map all reflect it.
* Station is the bearing element. An exercise is a grouping of stations; the mass of scenario positions is station-bounded. No central location register.
* Keep the administrative `position` (game-technical placement of the station/marker) distinct from scenario/tactical geography. They are different concerns and both stay.
* The marker who enacts a person must be able to adjust that person's name/age/gender/signalement, because the available marker pool is limited and letting the marker choose helps them play the role — without breaking the single source.
* No PII on scenario data. PII lives only in `Actor` (the roster), unchanged.
* Reuse the DESIGN-008 resolution and authoring machinery (mustache context, token fields, `PlanScope`-style provision, `RingDrillText`, the section-navigated editor). No new parser.

## Considered options

* **A: Station-owned scenario locations and persons, referenced under the derived `station.*` context; `RolePlay` mandatorily portrays a station `Person`, its identity fields acting as overrides.** (chosen)
* **B: A central (plan- or exercise-level) location/person registry** like variables.
* **C: Keep `RolePlay` owning identity; add persons only for non-enacted intel**, no `personRef`.

## Decision outcome

Chosen option: **A**. It keeps scenario data where the domain puts it (the station), gives a single source with an enactment-override layer for identity, and folds cleanly into the existing `station.*` derived context and the DESIGN-008 machinery. B contradicts the station-as-bearing-element model and the "no central register" call. C leaves the central missing person outside the scenario surface, splits "persons" across two concepts, and reproduces the drift this ADR exists to remove.

### Models (station-owned)

```dart
// Scenario geography. Station-owned. Not the administrative Station.position.
@freezed
sealed class Location with _$Location {
  const factory Location({
    required String slug,           // ^[a-z][a-z0-9_]*$, unique within the station; the stable reference
    @Default('') String label,      // display name, e.g. "Last known position"
    @Default(LocationKind.other) LocationKind kind, // drives map styling; extensible
    @Default('') String place,      // address / place description
    @NullableLatLngJsonConverter() LatLng? position,
    String? note,
  }) = _Location;
  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);
}

// Fictional scenario person (missing, witness, reporter, next-of-kin). No PII.
@freezed
sealed class Person with _$Person {
  const factory Person({
    required String slug,           // ^[a-z][a-z0-9_]*$, unique within the station; the stable reference
    @Default('') String name,       // display name, e.g. "Anne Glemsk"
    int? age,
    String? gender,
    String? signalement,
    String? homeSlug,               // references a Location.slug on the same station
    String? notes,
  }) = _Person;
  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);
}
```

On `Station`:

```dart
@Default(<Location>[]) List<Location> locations,
@Default(<Person>[]) List<Person> persons,
```

`LocationKind` drives map-marker styling and picker grouping. The enum value is the stable wire slug; its `label` and `description` are **not** hard-coded — they come from i18n, resolved per kind through an extension over `AppLocalizations` (ARB entries `locationKind<Name>Label` / `locationKind<Name>Description`). Unknown values decode to `other` (`@JsonKey(unknownEnumValue: LocationKind.other)`), so a kind added later is forward-compatible with older clients.

```dart
enum LocationKind {
  lkp,             // last known position
  ipp,             // initial planning point
  pp,              // planning point
  rendezvous,      // Oppmøtested
  commandPost,     // Kommandoplass (KO)
  home,            // Bosted
  trackFound,      // Funn av spor
  dogInterest,     // Interesse av hund
  obstacle,        // Hindring
  notSearchable,   // Ikke søkbart
  phoneTrace,      // Mobilspor
  observation,     // Observasjon
  vantagePoint,    // Utkikkspunkt
  containmentPost, // Sperrepost
  personFound,     // Funn av person
  other;           // Annet
}
```

The starter set aligns with the category picker in **FAKS** (Felles aksjonsstøtteverktøy) — `rendezvous`, `commandPost`, `home`, `trackFound`, `dogInterest`, `obstacle`, `notSearchable`, `phoneTrace`, `observation`, `vantagePoint`, `containmentPost`, `personFound`, `other` — plus the SAR planning reference points `lkp`, `ipp` and `pp`. The set is extensible: adding a kind is an additive enum value plus its two ARB entries.

### Namespace and resolution

Locations and persons extend the **derived `station.*` context** (the same place `{{station.position.utm}}` already lives), not the `var.*` registry. They are referenced with facets:

* `{{station.loc.<slug>}}` (default facet: place plus UTM), `{{station.loc.<slug>.place}}`, `{{station.loc.<slug>.utm}}`, `{{station.loc.<slug>.label}}`.
* `{{station.person.<slug>}}` (default: name), `.name`, `.age`, `.gender`, `.signalement`, and `.home` which resolves through `homeSlug` to the referenced location's facets (`{{station.person.anne.home.utm}}`).

Scope is **the station and down**: the station's own fields, and the fields of a `RolePlay` linked to that station. Program- and exercise-level text has no station in scope and cannot reference `station.loc.*` / `station.person.*`. A roleplay resolves against the station it belongs to.

### RolePlay portrays a Person (mandatory)

`RolePlay` gains a `personRef` naming a `Person` on its station (required by the editor for new or edited roleplays; nullable on the wire — see Format). Its identity fields (`name`, `age`, `gender` (new), `signalement`) hold the **effective identity** — the value actually played — persisted **denormalized** so any reader gets a populated marker. The `Person` is the authored source. A roleplay field that **equals** the Person's value is *inherited* and is rewritten when the Person default changes; a field that **differs** is an *override* the marker set. The effective identity is what the roster, station text and brief show. This is the default-plus-override pattern of variables and `commsMd` applied to identity, with the effective value cached on the roleplay so old clients (and any reader that ignores `personRef`) still see a correct marker. The one benign edge is a field a marker deliberately set equal to the Person's value: a later Person change carries it along, which is the intended reading of "same as the person".

Because a `Person` is station-owned, `personRef` ties the roleplay to a station; the roleplay's station is derived from the referenced person's owner, so `stationIndex` follows `personRef` rather than being set independently. There are no scenario-less ("dangling") roleplays: every marker portrays a scenario person, so identity always flows through the Person and the marker's edit always reaches the brief.

Creating a roleplay auto-creates its `Person` on the station (from whatever identity the author types), so mandatory `personRef` adds no authoring step and does not force a particular creation order.

### Inline creation and write-back

Locations, persons and variables can be created inline from a token field (the slash / `{{` picker), not only from their list section, for authoring flow. The wrinkle is that the *owner* of a created entity is often not the entity the editor edits: a `var.*` create belongs to `Program`, a `station.loc.*` / `station.person.*` create from a **roleplay** field belongs to the roleplay's *linked station*, and only the station editor owns the locations/persons it creates directly.

The mechanism: an editor resolves newly created entities against a working copy it holds (seeded from what it was given) so chips update live, and on save it returns its own entity **plus a write-back payload** of additions for owners it does not directly hold — new plan variables (→ `Program`) and new locations/persons (→ the target station). The caller that owns the plan applies the entity change and the payload atomically. The return is a Dart 3 named record (e.g. `({Exercise entity, PlanAdditions additions})`), not a bespoke `EntityEditResult<T>` class.

This is one mechanism for all three kinds. It also **un-defers** the DESIGN-008 decision that parked variable creation in sub-editors (Exercise/Station/RolePlay): the same write-back payload carries new plan variables up from any sub-editor, so `var.*` inline create now works everywhere, not just in the Program editor.

### Reference integrity

An unresolved `{{station.loc.x}}` or `{{station.person.y}}` — the (linked) station has no such slug — is an error: a red token in the editor that blocks save, and a visible placeholder in the brief, exactly as an undeclared `{{var.x}}` (ADR-0046). Moving a roleplay to a different station (a different `personRef`) re-resolves its fields and flags references that newly break. Renaming or deleting a location or person rewrites, or guards, references across the **station-and-down** set (the station's fields and its linked roleplays' fields), the same rename/delete integrity as variables but station-scoped. Deleting a `Location` referenced by a `Person.homeSlug` is likewise guarded. Note the `slug` is the stable reference: the display fields (`label`, `name`) are freely editable and never touch references; only a deliberate `slug` change is a reference-affecting rename. This is a small improvement over the variable model, where the `name` doubles as both slug and display.

### PII

`Location` and `Person` are fictional scenario data, fully publishable, no PII, no stripping. `Actor` (the roster) remains the only PII layer, local and stripped on publish ([ADR-0018](./0018-roleplayer-data-model.md)). The triad is: `Actor` (real, PII) enacts a `RolePlay` (the how) portraying a `Person` (the who, scenario).

### Format and backward compatibility

No hard schema bump. Every new field is additive, so this stays in the same envelope as [ADR-0043](./0043-tags-in-drill-format.md) and ADR-0046, and `KNOWN_SCHEMA_MAX` stays at `1.2`. Specifically:

* `Station.locations`, `Station.persons` and `RolePlay.gender` are additive with `@Default`; archives without the keys deserialize to empty and older clients ignore them.
* `personRef` is a **nullable** field (`String?`). "Mandatory" is an editor-level invariant for newly authored or edited roleplays, not a wire constraint. A legacy roleplay with `personRef == null` still loads and renders from its `name`/`age`/`signalement`, exactly today's behaviour. Crucially, when `personRef` is set the identity fields are **not** emptied — they carry the denormalized effective identity (see "RolePlay portrays a Person"), so an old client that ignores `personRef` and `station.persons` still reads a correct, populated marker rather than a blank one. The `RolePlay` identity fields never leave the format, and are always populated, so old and new readers both render the file correctly.

Because it is not a hard requirement on the wire, there is **no forced migration on load**. A legacy roleplay is upgraded lazily: when it is edited in the new editor, a `Person` is auto-created on its station from its current identity, `personRef` is set, and the roleplay's identity fields keep their (now effective, inherited) values so nothing changes visually. Plans never opened in the new editor keep working untouched. `ProgramX.computeContentHash` includes the new station collections, `personRef` and `gender`.

A `.drill` written by a new client is therefore readable by an old one (it ignores `personRef`/`gender`/`locations`/`persons` and shows the inline identity), and a `.drill` written by an old client is readable by a new one (null `personRef`, empty collections). Should we ever want to *hard*-require `personRef` on the wire, that would be the coordinated bump — deliberately deferred, because the additive envelope already covers correctness.

### Consequences

* Good: One coordinate, one person identity, referenced by station text, marker text, brief and map. Edit once.
* Good: Administrative placement and scenario geography stay separate and legible, including on the map.
* Good: The marker adjusts identity from the roleplay editor (overrides) without breaking the source; the brief always shows the as-played identity.
* Good: No dangling roleplays; no wrong-order breakage; the "brief didn't update after I renamed the marker" failure mode is gone.
* Good: Reuses the derived-context resolution and DESIGN-008 authoring machinery; no new parser.
* Good: No schema bump. Additive fields plus a nullable, editor-enforced `personRef` keep the same backward/forward-compatible envelope as ADR-0043; legacy roleplays render unchanged and upgrade lazily.
* Bad: Markers must be station-placed (a person needs a station home). Accepted: a scenario-less marker has no real use here.
* Bad: `gender` is new on both `Person` and `RolePlay`; older archives default it empty.

## Pros and cons of the options

### Option A — station-owned locations/persons, RolePlay portrays a Person (chosen)
* Good: single source; station-centric; effective-identity override; reuses `station.*` + DESIGN-008.
* Bad: schema bump + migration; markers must be placed.

### Option B — central registry
* Good: one collection, no per-station duplication.
* Bad: contradicts station-as-bearing-element; most positions are station-bounded, so a central register is the wrong granularity; heavier scoping.

### Option C — RolePlay keeps identity; persons only for non-enacted intel
* Good: no migration, no mandatory `personRef`.
* Bad: the central missing person sits outside the scenario surface; "persons" split across two concepts; identity drift persists.

## Links

* Related design: [DESIGN-009](../design/009-scenario-locations-and-persons.md) (Locations and Persons sections + editor UX), [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md) (token fields, `RingDrillText`, `PlanScope`, section-navigated editor reused here), [DESIGN-004](../design/brief-template.md) (brief renderer and `station.*` cross-references)
* Related ADRs: [ADR-0046](./0046-plan-variables.md) (variables — the `var.*` registry this deliberately does *not* use), [ADR-0018](./0018-roleplayer-data-model.md) (RolePlay/Actor split and the PII boundary), [ADR-0019](./0019-roleplayer-participant-role.md) (roleplay participant role), [ADR-0020](./0020-map-label-and-marker-clutter.md) (`MapMarkerSpec`, the map consumer of locations), [ADR-0007](./0007-drill-file-format.md) (schema evolution — the 1.3 bump), [ADR-0022](./0022-markdown-content-as-files.md)
* Related code: `lib/models/station.dart`, `lib/models/role_play.dart`, `lib/models/location.dart` (new), `lib/models/person.dart` (new), `lib/data/drill_file.dart`, `lib/services/brief/brief_renderer.dart`, `lib/views/widgets/` (map markers)
* Operating rule (in [`AGENTS.md`](../../AGENTS.md)): "Drill file format is versioned" and "schema bumps are coordinated changes"
* Norwegian UI labels for these English concepts: see the "Norwegian labels (nb)" section in [DESIGN-009](../design/009-scenario-locations-and-persons.md).
