---
id: DESIGN-009
title: Scenario locations and persons
status: Proposed
started: 2026-07-03
owners: ["kengu"]
related_code:
  - lib/models/station.dart
  - lib/models/role_play.dart
  - lib/models/location.dart
  - lib/models/person.dart
  - lib/views/station_form_screen.dart
  - lib/views/roleplay_form_screen.dart
  - lib/views/widgets/ringdrill_text_field.dart
  - lib/views/widgets/plan_scope.dart
  - lib/services/brief/brief_renderer.dart
related_designs:
  - 008-plan-variables-and-section-navigated-editor.md
  - brief-template.md
related_adrs:
  - 0047-scenario-locations-and-persons.md
  - 0046-plan-variables.md
  - 0018-roleplayer-data-model.md
  - 0020-map-label-and-marker-clutter.md
---

# Scenario locations and persons

> This document is in English. Field, model and helper names are English throughout. Norwegian strings are the user-facing labels the app ships in `nb`.

## TL;DR

A station gains two first-class editor sections, **Locations** (named places with a coordinate) and **Persons** (fictional scenario people — the missing person, witnesses, reporters, next-of-kin). They are station-owned data, referenced in any station-and-down text as `{{station.loc.<slug>}}` and `{{station.person.<slug>}}` with facets, resolved in the brief and the live UI, and drawn on the map. They are *not* bundled under a "Scenario" heading: the scenario is the narrative — the station's Situation, Mission, and a future "What has happened" field — and Locations and Persons are the reusable data those narratives reference. A `RolePlay` now **portrays a Person** (`personRef`, required for new/edited roleplays); its identity fields carry the effective identity (inherit-or-override) so the marker can adjust name/age/gender/signalement without breaking the source. The data model, resolution and integrity rules are fixed in [ADR-0047](../adrs/0047-scenario-locations-and-persons.md); this doc specifies the authoring UX. It reuses the DESIGN-008 machinery (`PlanScope`, token fields, `RingDrillText`, the section-navigated editor).

## Rationale

Positions and person identity are retyped across a station's situation prose, its markers' play text, the brief and the map, and drift. Administrative positions (where the station/marker is placed) are game-technical and stay as they are. The new data is strategic/tactical scenario geography and intelligence: last-known-position, home, observations, and the people the scenario is about. Making these first-class, station-owned and referenceable means an author edits a place or a person once and every surface follows. See ADR-0047 for why station-owned (the station is the bearing element) rather than a central register.

## Concepts

**Location** — a named place: display `label`, `kind` (for map styling), `place` (address), an optional coordinate, a note. The token reference (`slug`, called "reference" in the UI) is auto-generated from the label at creation and hidden from typing. Station-owned.

**Person** — a fictional scenario person: display `name`, `age`, `gender` (woman/man/other), `signalement`, `homeSlug` (a reference to one of the station's locations), notes. The reference (`slug`) is auto-generated from the name. Station-owned, no PII (ADR-0047; the real human is the `Actor`, the roster layer).

**Effective identity** — a `RolePlay` portrays a `Person` and its identity fields (`name`/`age`/`gender`/`signalement`) hold the effective identity: a field equal to the Person's value is *inherited* (and follows later Person edits), a field that differs is an *override* the marker set. The effective value is what renders everywhere and is persisted denormalized on the roleplay so any reader gets a populated marker (ADR-0047). Same default-plus-override intuition as variables, cached for forward-compat.

## The Locations and Persons sections

In the station's section-navigated editor (DESIGN-008), **Locations** and **Persons** are two first-class sections, sitting alongside the base **Station** section and the narrative markdown sections (Situation, Mission, and a future "What has happened"). Each is a list you manage directly; the narrative sections are where their slugs get referenced.

The "What has happened" markdown field is a future addition (it will seed a marker's roleplay); this design does not build it, but it is the archetypal narrative that references `station.person.*` and `station.loc.*`, and it needs nothing beyond what is specified here.

**Locations.** A row per location: `label`, `kind`, and a `place`/coordinate summary. Tapping a row opens the location form (see below); **swipe-to-dismiss deletes** it, matching the app's list pattern (ADR-0031). "+ New location" opens the form to add one. The reference is auto-generated from the label; the author never types it. Editing the display `label` is free. Delete is blocked while referenced (by a field or by a person's home), listing the usages. Changing the reference itself is a **future** action ("change reference"), which will run the station-and-down rewrite.

**Persons.** A row per person: `name` with an `age`/`gender`/`signalement` summary. Tapping opens the person form; swipe-to-dismiss deletes. "+ New person" opens the form. Reference auto-generated from the name; editing the display name is free; delete guarded as above. The location form's category picker is a show-more/less toggle (expand to all 16 kinds, collapse back).

Both lists are the single source. The reference is auto-generated and stable; the display fields (`label`, `name`) are freely editable and are what the picker shows and what facets resolve to. The word "slug" never appears in the UI — where the concept must be named it is "reference".

The Location form's `place` is geocoder-backed, reusing the existing map-search geocoder (`osm_nominatim`) — typing a place suggests and sets the coordinate, and setting the coordinate fills an empty place by reverse lookup. It is best-effort (offline/no-result is a silent no-op) and never overwrites what the author typed. The coordinate is stored as `LatLng` (WGS84); UTM and any other projection are render-time facets (ADR-0047). Detail in prompt 3c.

## Referencing in text

The token picker (slash and `{{`, from DESIGN-008) in the station's own markdown fields and in a linked roleplay's fields offers `station.loc.*` and `station.person.*` alongside the existing plan-fields and `var.*`. Facets:

* `{{station.loc.lkp}}` (place + UTM), `{{station.loc.lkp.place}}`, `{{station.loc.lkp.utm}}`, `{{station.loc.lkp.label}}`.
* `{{station.person.anne}}` (name), `.age`, `.gender`, `.signalement`, and `.home` resolving through to the location facets (`{{station.person.anne.home.utm}}`).

`RingDrillText` resolves these in the brief and the live UI; the brief renderer resolves them in generated markdown. An unresolved slug renders as the placeholder and, in the editor, as a red token that blocks save (ADR-0047).

When the picker's filter matches no existing entry, it offers **inline creation** — "Create location «x»", "Create person «x»", or "Create variable «x»", parallel to DESIGN-008's inline variable create. Selecting it creates the entity and inserts the token, so the author never has to leave the field to declare it first. A freshly created entity is empty, so it renders amber ("declared but empty") until filled in its section. Inline create is offered only where the namespace has scope: `station.loc.*` / `station.person.*` need a station (the station's own field, or a linked roleplay's field), while `var.*` is always available.

## Inline creation and write-back

Inline create writes to the **owner** of the created entity, which is not always the entity the editor is editing:

* Program editor — a `var.*` create writes to `Program.variables`, which it already holds (DESIGN-008, shipped).
* Station editor — `station.loc.*` / `station.person.*` create writes to the station's own lists it holds; a `var.*` create must reach `Program`.
* RolePlay editor — a `station.loc.*` / `station.person.*` create writes to the **linked station** (not the roleplay), and a `var.*` create must reach `Program`.

To keep this atomic, an editor resolves newly created entities against a working copy it holds (seeded from what it was given), so the chip updates immediately, and on save it returns — besides its own entity — a small write-back payload of additions targeting owners it does not directly hold: new plan variables (→ `Program`) and new station locations/persons (→ the target station). The caller that owns the plan applies the entity change and the payload together in one save. It is a Dart 3 named record (e.g. `({Exercise entity, PlanAdditions additions})`), not a bespoke result class (see ADR-0047).

This unifies inline creation across variables, locations and persons, and **un-defers** the DESIGN-008 item that parked variable creation in sub-editors: the same payload carries new variables from any sub-editor to the plan.

## RolePlay editor

The RolePlay editor gains a **person** selector: pick the `Person` this marker portrays from the linked station's list (`personRef`, required for new/edited roleplays). The identity fields — `name`, `age`, `gender` (new), `signalement` — present as **inherit or override**: a field tracking the Person shows its value and stays in sync as the Person changes; a different value is an override. On disk each field always holds the effective value (ADR-0047), so the marker never shows blank. A small effective-identity preview shows what the brief will render. `behavior`, `background`, `propsMd` and the Actor casting are unchanged.

Creating a roleplay auto-creates its Person on the station from whatever identity is typed, so there is no separate "create the person first" step and no scenario-less roleplay. Re-pointing `personRef` to a different station's person re-scopes the roleplay and flags any `station.*` token in its fields that no longer resolves.

## Map

The station's locations (and a person's home) become map markers via `MapMarkerSpec` ([ADR-0020](../adrs/0020-map-label-and-marker-clutter.md)), styled by `LocationKind`, distinct from the administrative `position` marker. The map, the brief and the editor all read the same locations — the decoupling win, made visual: an LKP is one point, shown and referenced everywhere from one source.

## Behavior

Editing a location or person updates every reference on save. Rename rewrites `{{station.loc.old}}` / `{{station.person.old}}` across the station's fields and its linked roleplays' fields (station-and-down), behind a confirmation. Delete is blocked while referenced (including a person's `homeSlug` pointing at a location), with the usages listed. Save is blocked when a station or roleplay field contains an unresolved `station.*` token. The effective identity means the brief always shows what the marker actually presents, updating as casting firms up.

## Deferred / non-goals

* No central (plan/exercise) location or person registry — station-owned only (ADR-0047).
* No PII handling on scenario data — that stays in `Actor` (the roster).
* Multiple roleplays portraying the same person: v1 assumes one portraying roleplay per person for override resolution; if several, the primary/first wins.
* Rich per-location metadata beyond place/coordinate/kind is out of scope for v1.

## Open questions

1. `LocationKind` marker styling — the value set is decided (FAKS-aligned, see the model in ADR-0047 and the label table below); the open piece is the marker glyph/colour per kind. Labels and descriptions come from i18n, not hard-coded.
2. Whether the roleplay's `stationIndex` is fully derived from `personRef`'s owner or kept explicit and validated in sync (ADR-0047 leans derived).
3. Whether the Locations/Persons data also surfaces on the exercise/program level as a read-only roll-up of its stations' scenario data (deferred).

## Implementation notes

Staged, each a separate PR. The format stays additive (no schema bump, `KNOWN_SCHEMA_MAX` unchanged — ADR-0047):

1. **Model + format.** `Location`, `Person`, `Station.locations`/`persons` (additive `@Default`), `RolePlay.personRef` (nullable) and `gender`. No schema bump; legacy roleplays load with null `personRef` and render inline identity, upgrading lazily when edited. `make build`; content hash; `DrillFile` read/write.
2. **Resolution.** Extend the `station.*` derived context in `BriefRenderer` (and the shared resolver) with `loc.*` and `person.*` facets and effective identity. Unit-test the cascade and facets.
3. **Locations and Persons sections.** Two first-class station-editor sections with their list rows, reusing `VariableOverridesSection`-style rows and the section shell.
4. **Token picker + RolePlay editor.** Offer `station.loc.*`/`station.person.*` in the picker; the `personRef` selector and override/inherit identity fields with effective preview.
5. **Map.** Locations and homes as `MapMarkerSpec`, styled by kind.
6. **Integrity.** Rename/delete rewrite and guards over the station-and-down set; save-blocking on unresolved `station.*` tokens; re-link handling.

All user-facing strings in `app_en.arb` / `app_nb.arb`; run `make i18n`.

## Norwegian labels (nb)

The design and ADR use English concept names throughout. The `nb` UI ships these translations (existing terms in the last rows are for context, unchanged by this design). The `LocationKind` rows align with the FAKS (Felles aksjonsstøtteverktøy) category picker plus the SAR planning points; each kind also has a `description` in i18n, not shown here:

| English concept | Norwegian UI label |
|-----------------|--------------------|
| Locations (section) | Lokasjoner |
| Persons (section) | Personer |
| Location / Locations | Lokasjon / Lokasjoner |
| Person / Persons | Person / Personer |
| New location | Ny lokasjon |
| New person | Ny person |
| home (`Person.homeSlug`) | Bopel |
| reference (the `slug`, UI-facing) | Referanse |
| change reference (future) | Endre referanse |
| gender: woman / man / other | Kvinne / Mann / Annet |
| `LocationKind.lkp` | Sist kjent posisjon (LKP) |
| `LocationKind.ipp` | Initielt planleggingspunkt (IPP) |
| `LocationKind.pp` | Planleggingspunkt (PP) |
| `LocationKind.rendezvous` | Oppmøtested |
| `LocationKind.commandPost` | Kommandoplass |
| `LocationKind.home` | Bosted |
| `LocationKind.trackFound` | Funn av spor |
| `LocationKind.dogInterest` | Interesse av hund |
| `LocationKind.obstacle` | Hindring |
| `LocationKind.notSearchable` | Ikke søkbart |
| `LocationKind.phoneTrace` | Mobilspor |
| `LocationKind.observation` | Observasjon |
| `LocationKind.vantagePoint` | Utkikkspunkt |
| `LocationKind.containmentPost` | Sperrepost |
| `LocationKind.personFound` | Funn av person |
| `LocationKind.other` | Annet |
| Station (base section) | Post |
| RolePlay (editor) | Spill / Rolle |
| Actor (roster) | Markør / Bemanning |

Only these labels are Norwegian. Model, field, facet and code names (`Location`, `Person`, `station.loc.*`, `station.person.*`, `personRef`, `slug`, `homeSlug`) stay English everywhere.

## References

* [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) — data model, `station.loc.*`/`station.person.*`, effective identity, integrity, additive format (no schema bump) with lazy roleplay upgrade.
* [DESIGN-008](./008-plan-variables-and-section-navigated-editor.md) — the token fields, `RingDrillText`, `PlanScope` and section-navigated editor reused here.
* [DESIGN-004](./brief-template.md) — brief renderer and `station.*` cross-references.
* [ADR-0018](../adrs/0018-roleplayer-data-model.md) — RolePlay/Actor split and the PII boundary.
* [ADR-0020](../adrs/0020-map-label-and-marker-clutter.md) — `MapMarkerSpec`, the map consumer.
