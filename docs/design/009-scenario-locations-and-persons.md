---
id: DESIGN-009
title: Scenario locations and persons
status: Accepted
started: 2026-07-03
accepted: 2026-07-10
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

**Location** — a named place: display `label`, `kind` (for map styling), `place` (address), an optional coordinate, a note. The token reference (`slug`, called "reference" in the UI) is a short random id generated at creation and hidden from typing — it is not derived from any editable field, so changing the `label`, `kind` or coordinate never affects it. Station-owned.

**Person** — a fictional scenario person: display `name`, `age`, `gender` (woman/man/other), `signalement`, `locSlug` (a reference to one of the station's locations), notes. The reference (`slug`) is a short random id generated at creation, not derived from the name or any editable field. Station-owned, no PII (ADR-0047; the real human is the `Actor`, the roster layer).

**Effective identity** — a `RolePlay` portrays a `Person` and its identity fields (`name`/`age`/`gender`/`signalement`) hold the effective identity: a field equal to the Person's value is *inherited* (and follows later Person edits), a field that differs is an *override* the marker set. The effective value is what renders everywhere and is persisted denormalized on the roleplay so any reader gets a populated marker (ADR-0047). Same default-plus-override intuition as variables, cached for forward-compat.

## The Locations and Persons sections

In the station's section-navigated editor (DESIGN-008), **Locations** and **Persons** are two first-class sections, sitting alongside the base **Station** section and the narrative markdown sections (Situation, Mission, and a future "What has happened"). Each is a list you manage directly; the narrative sections are where their references get used. Switcher order in the station editor is: Post (base) → Persons → Locations → narrative markdown → Variabler. Two rules hold in every editor's switcher: **Variabler is always the last section** (Program, Exercise, Station), and **Persons is always above Locations**.

The "What has happened" markdown field is a future addition (it will seed a marker's roleplay); this design does not build it, but it is the archetypal narrative that references `station.person.*` and `station.loc.*`, and it needs nothing beyond what is specified here.

**Locations.** A row per location: `label`, `kind`, and a `place`/coordinate summary. Tapping a row opens the location form (see below); **swipe-to-dismiss deletes** it, matching the app's list pattern (ADR-0031). "+ New location" opens the form to add one. The reference is a random id generated at creation; the author never types it. Editing the display `label`, `kind` or coordinate is free and never affects the reference. Delete is blocked while referenced (by a field or by a person's `locSlug`), listing the usages. There is no rename of the reference — it is opaque and stable, so nothing ever needs rewriting.

**Persons.** A row per person: `name` with an `age`/`gender`/`signalement` summary. Tapping opens the person form; swipe-to-dismiss deletes. "+ New person" opens the form. Reference is a random id; editing the display name is free and never touches it; delete guarded as above. The location form's category picker is a show-more/less toggle (expand to all 16 kinds, collapse back).

Both lists are the single source. The reference is a random, opaque, stable id; the display fields (`label`, `name`) are freely editable and are what the picker shows and what facets resolve to. The word "slug" never appears in the UI — where the concept must be named it is "reference". Each list keeps its chrome light: a single bottom row holds the search field and the "+ Ny …" action, with no sort control (the lists are short), and the search matches the app's standard search-field idiom. Across the station editor, the AppBar header shows the station's name on every section except the base "Post" section, so the author always sees which station they are in.

The Location form's `place` is geocoder-backed, reusing the existing map-search geocoder (`osm_nominatim`) — typing a place suggests and sets the coordinate, and setting the coordinate fills an empty place by reverse lookup. It is best-effort (offline/no-result is a silent no-op) and never overwrites what the author typed. The coordinate is stored as `LatLng` (WGS84); UTM and any other projection are render-time facets (ADR-0047). Detail in prompt 3c.

## Referencing in text

The token picker (slash and `{{`, from DESIGN-008) in the station's own markdown fields and in a linked roleplay's fields offers `station.loc.*` and `station.person.*` alongside the existing plan-fields and `var.*`. Facets:

* `{{station.loc.lkp}}` (place + UTM), `{{station.loc.lkp.place}}`, `{{station.loc.lkp.utm}}`, `{{station.loc.lkp.label}}`.
* `{{station.person.anne}}` (name), `.age`, `.gender`, `.signalement`, and `.loc` resolving through to the location facets (`{{station.person.anne.loc.utm}}`).

`RingDrillText` resolves these in the brief and the live UI; the brief renderer resolves them in generated markdown. An unresolved slug renders as the placeholder and, in the editor, as a red token that blocks save (ADR-0047).

When the picker's filter matches no existing entry, it offers **inline creation** — "Create location «x»", "Create person «x»", or "Create variable «x»", parallel to DESIGN-008's inline variable create. Selecting it creates the entity and inserts the token, so the author never has to leave the field to declare it first. A freshly created entity is empty, so it renders amber ("declared but empty") until filled in its section. Inline create is offered only where the namespace has scope: `station.loc.*` / `station.person.*` need a station (the station's own field, or a linked roleplay's field), while `var.*` is always available.

### Own-entity facets, facet completion, and leaf fields (follow-ups 4c–4e)

The picker also offers each in-scope entity's **own** scalar facets, not just cross-references. Prompt 4b added `program.*` and `exercise.*`; the same treatment applies to the station and the roleplay:

* **Station own facets** (station and roleplay fields): `station.name`, `station.stationCode`, `station.position.utm`, `station.variantSuffix`. These resolve in `BriefRenderer`'s station context but were not offered until follow-up 4c.
* **RolePlay own facets** (roleplay fields): `roleplay.name`, `roleplay.age`, `roleplay.signalement`, `roleplay.position.utm`.

**Self-reference rule.** A field never offers a token that reads the same free-text field it is editing, since that value contains the token being typed and would recurse through the fixpoint pass. So `station.description` is withheld from the station's own description field and `program.description` from the program's, and a roleplay's own `name`/`signalement` are withheld from those same fields. The short, derived facets (`name`, `stationCode`, `position.utm`) are safe and always offered.

**Facet completion.** The `.place` / `.utm` / `.age` / `.loc.utm` facets promised above are reached by continuing to type after a chosen entity: once the filter reads `station.loc.<slug>.` or `station.person.<slug>.`, the picker lists that kind's facet names as selectable entries (loc: `place`, `label`, `utm`; person: `name`, `age`, `gender`, `signalement`, `loc`), inserting the full dotted token. The bare entity entry still inserts the sensible default (place + UTM for a location, effective name for a person).

**Leaf fields are token hosts too.** The scenario leaf fields themselves accept tokens: a `Location`'s `place` and `note`, and a `Person`'s `name`, `signalement` and `notes`. So a recurring subject name or a shared place string can be a `{{var.*}}`, and a leaf may reference `{{station.loc.*}}` / other facets. These forms open as their own surface (`openFormSurface`), a separate route from the station editor, so they re-provide `PlanScope` and `StationScope` seeded from the same working data — an inherited scope does not cross the `Navigator` boundary. No renderer change is needed: a token injected through a leaf value is caught by the next pass of the fixpoint loop (`_resolveField`, bounded by `_maxResolvePasses`). The self-reference rule applies here too — a `Person`'s name field does not offer `station.person.<self>.name`.

## Inline creation and write-back

Inline create writes to the **owner** of the created entity, which is not always the entity the editor is editing:

* Program editor — a `var.*` create writes to `Program.variables`, which it already holds (DESIGN-008, shipped).
* Station editor — `station.loc.*` / `station.person.*` create writes to the station's own lists it holds; a `var.*` create must reach `Program`.
* RolePlay editor — a `station.loc.*` / `station.person.*` create writes to the **linked station** (not the roleplay), and a `var.*` create must reach `Program`.

To keep this atomic, an editor resolves newly created entities against a working copy it holds (seeded from what it was given), so the chip updates immediately, and on save it returns — besides its own entity — a small write-back payload of additions targeting owners it does not directly hold: new plan variables (→ `Program`) and new station locations/persons (→ the target station). The caller that owns the plan applies the entity change and the payload together in one save. It is a Dart 3 named record (e.g. `({Exercise entity, PlanAdditions additions})`), not a bespoke result class (see ADR-0047).

This unifies inline creation across variables, locations and persons, and **un-defers** the DESIGN-008 item that parked variable creation in sub-editors: the same payload carries new variables from any sub-editor to the plan.

## RolePlay editor

**Visual reference:** [`docs/design/mockups/roleplay-editor.html`](./mockups/roleplay-editor.html) (four frames: before, the inherited/collapsed card, the "Tilpass" panel expanded, and an override).

The RolePlay editor packs the identity fields — `name`, `age`, `gender`, `signalement` — into one **effective-identity card** (prompt 4i), replacing an earlier interleaved-fields layout. The card's header is the **person** selector (`personRef`, required for new/edited roleplays): pick the `Person` this marker portrays from the linked station's list, rendered as the card's own live effective-identity summary rather than a plain name. Collapsed, the card reads as what the marker actually presents — name, "age · gender", and signalement (or, when the name itself is overridden, "Tilpasset fra {person}" so the reader still knows who). A "Tilpass" disclosure — a chevron that opens and closes the panel — reveals the override panel (Navn+Alder on one row, Kjønn on its own row, Signalement). There is **no "Følger person(en)" text and no per-facet label anywhere**: a field the author does not touch simply reads as it is, and a single **"Tilbakestill"** at the panel foot resets *all* overrides at once (not per field). Inherit-or-override is decided by equality against the Person's current value: a field tracking the Person stays in sync as the Person changes, a different value is an override, and the panel auto-expands on open when one already exists. On disk each field always holds the effective value (ADR-0047), so the marker never shows blank. `behavior`, `background`, `propsMd` and the Actor casting are unchanged.

The marker's administrative `position` gets the same inherit/override treatment against the Person's own `loc` location (prompt 4i): a **position card** shows that location by name (e.g. "Bosted") with its coordinate and a "Sett egen" action to override via the existing map picker — no "Følger …" label, since the location name already reads as the source. A person with no `loc` (or an uncoordinated one) falls back to the plain picker unchanged. `Person.locSlug` and `RolePlay.position` stay distinct fields — this only changes position's *default*, not the model. Pointing the marker at a *different* one of the station's locations is deferred; `Person → location` stays a single reference for v1.

The editor's app-bar title is the static type name — **"Endre spill" / "Nytt spill"** (reusing `editRolePlayTitle` / `newRolePlayTitle`, whose `nb` values move from "markørordre" to "spill") — not the marker's name, which already sits in the identity card. The **Post** selector is a compact card (station code, name, a discreet "Endre") rather than a full-width dropdown, since changing a marker's post after creation is rare.

A roleplay is built Post-first: the author selects the Post before any identity field is active, then picks an existing station Person or creates one via a "+ Ny person" entry in the person picker (which opens the Person form). Identity fields are overrides of the selected Person, so the "Tilpass" panel is inert until a Person is chosen, and no placeholder Person is auto-created. There is still no scenario-less roleplay. Re-pointing `personRef` to a different station's person re-scopes the roleplay and flags any `station.*` token in its fields that no longer resolves. (Amends the earlier auto-create step — see ADR-0047, amended 2026-07-10.)

**Authoring a marker from the post editor.** Markers are added from the post editor's **Persons** section, so an author never needs the read-only Post view to build one. Each person's card shows the marker inline, on the same row as the name (right-aligned, no separate line): "Spilles av {navn}" (no chevron — the row itself is the tap target) when enacted; a person without one offers **"Legg til spill"** in that same spot, which opens this editor with the post and person **pre-set** — the author lands directly on the play (behavior, background, props) and position. Saving returns to the post editor, where the person now shows the marker inline. The new roleplay is held in the post editor's working copy and written back on save through the same `PlanAdditions` mechanism as inline-created persons/locations/variables (extended to roleplays), so an aborted post edit never leaves a half-saved marker. A brand-new person-and-marker in one step is covered by the RolePlay editor's own person selector (inline create); "+ Person" then "Legg til spill" is the two-step path. Removal lives here too, not in the viewer.

## Map

The station's locations (including a person's own, via `locSlug`) become map markers via `MapMarkerSpec` ([ADR-0020](../adrs/0020-map-label-and-marker-clutter.md)), styled by `LocationKind`, distinct from the administrative `position` marker. The map, the brief and the editor all read the same locations — the decoupling win, made visual: an LKP is one point, shown and referenced everywhere from one source. The Post detail sheet draws the same markers on the shared position panel's map, with a kind legend (DESIGN-010).

## Behavior

Editing any editable field of a location or person (`label`, `name`, `kind`, coordinate, …) never affects its references, because the `slug` is a random id fixed at creation and derived from none of them. Delete is blocked while referenced (including a person's `locSlug` pointing at a location, and a roleplay's `personRef`), with the usages listed. Save is blocked when a station or roleplay field contains an unresolved `station.*` token. The effective identity means the brief always shows what the marker actually presents, updating as casting firms up.

**There is no reference rename, and none is needed.** The `slug` is a random, opaque id that reflects nothing editable, so it never goes stale and never needs rewriting across references. This removes a whole class of drift — the reference can never disagree with a name or kind — and means the station-and-down rewrite machinery is never required. The delete-guard (stage 6) is the only reference-integrity surface.

## The station description as the brief lead

`Station.description` (the "Postbeskrivelse") stops being UI-only and starts rendering in the brief as the station's **lead paragraph** (no heading). It **stays in the base section**, alongside name and position — it is not moved into the section switcher and is not a removable section. So a simple station needs only this one field and it reaches the brief, while a rich station adds the labeled, sometimes audience-gated sections (Situasjon, Oppdrag, `directorNotes`, …) that render with headings below the lead.

The `description` field is **reused as-is** — no new field, no migration, no schema bump; an absent/empty description renders no lead paragraph. When empty in the editor it collapses to a "Legg til beskrivelse" affordance that expands on focus, so a section-rich station shows no empty box in the base section. This resolves the earlier overlap where narrative could sit either in the description or a section: description is the unstructured lead, sections are the structured blocks. The in-app summary surfaces (station list subtitle, coordinator, program view, detail sheet) keep reading `description`, now resolved via the DESIGN-010 scope cascade; the station detail sheet becomes the DESIGN-010 rollup (lead + sections). The brief-template lead paragraph is a small [DESIGN-004](./brief-template.md) change.

## Scenario data in the viewers

**Visual reference:** [`docs/design/mockups/station-and-roleplay-viewers.html`](./mockups/station-and-roleplay-viewers.html).

The Post detail sheet surfaces the station's persons and locations, which have no read-only home today. Each gets a list card ("+ Person", "+ Lokasjon" to add). Because the distinction between a *person* (the scenario character) and a *marker* (the roleplay that enacts one) is opaque to the uninitiated, the two are **not** separate cards: the person is the row, and the enacting marker shows **inline on that person** ("Spilles av {actor}"), tapping through to the Spill viewer. A person not yet enacted offers "Legg til spill", which opens the RolePlay editor with the post and person pre-set — the same flow as the post editor's Persons section, which is the authoritative authoring home (see "Authoring a marker from the post editor"). Removing a marker is **not** a viewer action; it lives in the editor, with the app's swipe-to-delete ([ADR-0031](../adrs/0031-row-edit-affordances.md)).

The Spill detail sheet is the roleplay script: the effective identity, the play fields, the position, the parent post (shown first), and when the marker is active. It says **nothing** about the person relationship when the marker follows the person — there is no difference to explain — and shows "Tilpasset fra {navn}" only when the identity is overridden, naming the underlying person because the presented identity now differs. Casting ("Spilles av {actor}") is shown freely in-app; the PII boundary is a publishing concern handled at publish time, not in the viewer (ADR-0018).

The `nb` UI never labels the inherit state "Arvet" (too technical): it reads "Følger person(en)", overrides read "Tilpasset" / "Egen", and reverting reads "Tilbakestill". `inherit` / `override` stay as English concept names in the design and code only.

## Deferred / non-goals

* No central (plan/exercise) location or person registry — station-owned only (ADR-0047).
* No PII handling on scenario data — that stays in `Actor` (the roster).
* Multiple roleplays portraying the same person: v1 assumes one portraying roleplay per person for override resolution; if several, the primary/first wins.
* Rich per-location metadata beyond place/coordinate/kind is out of scope for v1.
* **Reference (`slug`) rename** — not applicable. The slug is a random opaque id, derived from no field, so it never drifts and there is nothing to rename; a reference is stable for the entity's whole life.

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

Picker/authoring follow-ups, all additive views/l10n/test work with no model or renderer change (each guarded by a render round-trip so an offered token can never be unresolvable):

* **4b (done).** Offer the already-resolvable `program.*` / `exercise.*` fields in every editor's picker, from a shared `PlanFieldTokens` source.
* **4c.** Offer the station's own facets (`station.name`, `stationCode`, `position.utm`, `variantSuffix`) in the station and roleplay editors, and the roleplay's own facets (`roleplay.name`, `age`, `signalement`, `position.utm`) in the roleplay editor. Withhold each field's own free-text facet (self-reference rule).
* **4d.** Facet completion in the picker for `station.loc.<slug>.` / `station.person.<slug>.` — list the kind's facet names as selectable entries.
* **4e (done).** Make the scenario leaf fields token-aware (`Location.place`/`note`, `Person.name`/`signalement`/`notes`), re-providing `PlanScope`/`StationScope` inside the `openFormSurface` forms. Landed as DESIGN-010 stage 4: `tokenAware: true` on `RingDrillTextField`/`RingDrillTextArea`, self-reference withholding via `SelfTokenExclusion`, and the save-time unresolved-reference block, reusing the scopes DESIGN-010 stage 1 already re-provides. Create-from-leaf is deferred — these two forms have no `PlanAdditions`-shaped write-back payload yet, so only existing-entity references are offered from these five fields for now.

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
| loc (`Person.locSlug`) | Lokasjon |
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
| Add marker (per person) | Legg til spill |
| played by (actor) | Spilles av {navn} |
| customized identity | Tilpasset fra {navn} |
| customize (disclosure) | Tilpass |
| revert an override | Tilbakestill |
| own position (override) | Egen posisjon / Sett egen |

Only these labels are Norwegian. Model, field, facet and code names (`Location`, `Person`, `station.loc.*`, `station.person.*`, `personRef`, `slug`, `locSlug`) stay English everywhere.

## References

* [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) — data model, `station.loc.*`/`station.person.*`, effective identity, integrity, additive format (no schema bump) with lazy roleplay upgrade.
* [DESIGN-008](./008-plan-variables-and-section-navigated-editor.md) — the token fields, `RingDrillText`, `PlanScope` and section-navigated editor reused here.
* [DESIGN-004](./brief-template.md) — brief renderer and `station.*` cross-references.
* [ADR-0018](../adrs/0018-roleplayer-data-model.md) — RolePlay/Actor split and the PII boundary.
* [ADR-0020](../adrs/0020-map-label-and-marker-clutter.md) — `MapMarkerSpec`, the map consumer.
