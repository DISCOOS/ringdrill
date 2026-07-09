# Implement DESIGN-009 — Prompt 4i: rename the person location to `loc`, and pack the RolePlay identity and position into inherit/override cards

You are working in the RingDrill repository, on `design-009`. This follows 4c/4g/4h and does three connected things the editor review surfaced: it renames the person's location field/facet to a location-generic name, repackages the RolePlay ("Ny markørordre") identity as a single effective-identity card, and lets the marker's position follow the person's location by default. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/roleplay-editor.html` (four frames: "Før", then the inherited/collapsed, customize/expanded, and overridden states). `docs/design/mockups/scenario-location-person-editor.html` remains the Person/Location form reference.

**Scope of change.** Unlike 4b–4g (views/l10n only), this prompt does touch the model, the brief renderer and the editor-side resolver — but it stays **additive**: no schema bump, `KNOWN_SCHEMA_MAX` unchanged. The `homeSlug` → `locSlug` rename is a **clean rename with no back-compat alias** (JSON key and facet both change outright), because **nothing is published yet** — this is the recorded decision, not an oversight. It **supersedes** 4g's roleplay-editor "Person + Kjønn on one row"; 4g's *person*-editor changes (name+age paired, gender on its own row, the "Lokasjon" label) stay.

## Background — what this consolidates

Three findings from the editor review, each with a settled solution:

1. **`homeSlug` / `.home` is misnamed.** It references an arbitrary `Location` on the station, not necessarily a residence, and it collides conceptually with `LocationKind.home` (Bosted) as one kind among many. The UI label is already "Lokasjon" (4g). Rename the field and facet to `loc`, giving `{{station.person.<slug>.loc.utm}}`, parallel to `station.loc.*`.
2. **The identity fields read as noise.** Four editable fields each captioned "Arvet fra person" make the inherit/override distinction ambiguous and blank-looking, especially for whoever reads the resulting order. Pack the effective identity into one **person card** (a readable summary of what the marker actually presents), with overrides tucked behind a "Tilpass" show-more.
3. **Position duplicates the person's location.** `RolePlay.position` (an administrative `LatLng`, where the marker stands) and the person's `loc` location often coincide, forcing a re-typed coordinate. Keep both concepts, but let position **follow the person's location by default** with the same inherit/override rule as identity.

## Changes

### 1. Rename the person location field and `.home` facet to `loc`

A straight rename, no alias. Touch every site:

* **Model** (`lib/models/person.dart`): `homeSlug` → `locSlug`. The JSON key follows the field name (no `@JsonKey`). `make build` to regenerate `person.g.dart` / `person.freezed.dart`.
* **Renderer** (`lib/services/brief/brief_renderer.dart`): `_resolvePersonFacet` `case 'home':` (~line 855) → `case 'loc':`, `person.homeSlug` → `person.locSlug`; update the doc comments naming `.home` / `Person.homeSlug` (~746, ~837).
* **Editor resolver** (`lib/utils/station_scenario_tokens.dart`): `resolvePersonFacet` `case 'home':` (~91) and `person.homeSlug`; the pattern doc `.home.utm` (~27) and the `.home` / `Person.homeSlug` doc (~74).
* **Picker** (`lib/views/widgets/token_insertion_menu.dart`): `personFacetNames` (~156) `'home'` → `'loc'`; the label map entry `'home' => l10n.personsSectionHomeLabel` (~172); the facet-completion chaining that switches on `'home'` / `homeDot` / `homePartial` and emits `facetPath: ['home', f]` (~541–557) → `'loc'` / `locDot` / `locPartial` / `['loc', f]`, and its doc comments (~65, ~478, ~541).
* **l10n**: rename `personsSectionHomeLabel` → a location-generic key (e.g. `personsSectionLocationLabel`), or reuse an existing "Lokasjon"/"Location" label key if one fits. The nb value stays "Lokasjon", en stays "Location". `make i18n`.
* **Views**: update `homeSlug` references in `person_form_screen.dart`, `station_form_screen.dart`, `locations_section.dart`.
* **Docs**: in `docs/design/009-scenario-locations-and-persons.md` and `docs/adrs/0047-scenario-locations-and-persons.md`, change `.home` → `.loc`, `homeSlug` → `locSlug`, `{{station.person.anne.home.utm}}` → `.loc.utm`, and the nb-labels table row `home (Person.homeSlug) | Lokasjon` → `loc (Person.locSlug) | Lokasjon`.
* **Tests**: update any test referencing `homeSlug` / the `home` person-facet.

After this, `git grep -n "homeSlug\|'home'"` shows no person-location remnants (the `LocationKind.home` enum value is a different thing and stays).

### 2. RolePlay editor — pack the identity into an effective-identity card

Replace the interleaved identity fields (and 4g's Person + Kjønn row) with one card in `lib/views/roleplay_form_screen.dart`, matching the mockup:

* **Collapsed (default).** A person card under a small "Identitet" label: the effective **name**, an **age · gender** line, and the **signalement** line (the signalement may be dropped from the summary only when vertical space is tight). The card header is the **Person selector** (tap to change `personRef`). A footer row reads "Følger personen" with a **"Tilpass ›"** disclosure.
* **Expanded ("Tilpass").** The disclosure reveals the per-facet override panel: **Navn + Alder** on one row, **Kjønn (segmented) on its own row**, **Signalement**. Each facet shows a small "Følger person" state until overridden.
* **Override.** A facet whose roleplay value differs from the person's current value renders as an accented field with a **"Tilbakestill"** action (revert = clear the override so it tracks the person again). The collapsed card then summarizes "N felt tilpasset" and marks the changed facet (small accent dot on the name, per the mockup).
* **Auto-expand** the panel on open when at least one facet is already overridden; otherwise start collapsed.
* Inherited-vs-override is decided by **comparing the roleplay field to the person's current value** — the ADR-0047 effective-identity rule already implemented as `_effectiveField` / the equality intuition in the design doc. The effective value stays **persisted denormalized** on the roleplay, so any reader gets a populated marker (never blank).
* Drop the per-field "Arvet fra person" captions entirely; the card's "Følger personen" / "N felt tilpasset" language carries the meaning once, not three times.
* `behavior`, `background`, `propsMd` and the Actor casting are unchanged, and still follow below.

### 3. RolePlay position — follow the person's location by default

Do **not** merge the fields: `Person.locSlug` (a named-location reference) and `RolePlay.position` (an administrative coordinate) answer different questions and stay distinct. Instead give position the identity pattern, in the same editor:

* **Default.** A position card reading "Følger personens lokasjon", showing the person's `loc` location label and its resolved coordinate. An **"Sett egen"** action overrides it via the existing `PositionFormField` / map picker.
* **Inherit/override by equality**, mirroring identity: `RolePlay.position` holds the effective coordinate; equal to the person's location coordinate means inherited (and follows a later change to that location), a different value is an override. Revert clears back to following.
* **No inheritable coordinate** (the person has no `loc`, or that location has no coordinate): position starts empty and is set via the existing picker exactly as today — no card, no regression.
* **Deferred / non-goal:** pointing the marker at a *different* one of the station's locations. `Person → location` stays a single reference for v1; "Sett egen" is a raw coordinate. Note it as an open question, do not build it.
* **Safety valve:** if making position honour the effective mechanism needs more than the editor plus the existing identity pattern (e.g. renderer or map-marker changes to resolve an inherited position), **stop and report** before widening scope.

## Ground rules

* Reuse existing widgets — the segmented gender control, `PositionFormField`, the Post/Person dropdowns, `RingDrillTextField`/`Area`. The only new components are the **identity card + collapsible override panel** and the **position card**, both small and matching the mockup's house style.
* All user-facing strings via `app_en.arb` / `app_nb.arb`; `make i18n` on any ARB change. New nb strings at least: "Identitet", "Følger personen", "Følger person", "Tilpass", "Tilbakestill", "{count} felt tilpasset", "Følger personens lokasjon", "Sett egen", "Portretterer {name}".
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + the targeted tests for what changed; `make build` only on the model change (commit 1), `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Four commits.

### Commit 1. Rename the person location to `loc`

Model + `make build`, renderer, editor resolver, picker + facet-completion, l10n key, the three views, docs and tests. `flutter analyze` + `flutter test test/` (renderer + views + utils touched). Commit: `refactor: rename person location field and facet from home to loc`.

### Commit 2. RolePlay identity card

The effective-identity card with the "Tilpass" override panel, gender on its own row, auto-expand on existing override, no "Arvet fra person" captions. Views + l10n. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): pack the roleplay identity into an inherit/override card`.

### Commit 3. Position follows the person's location

The position card with default-follow and "Sett egen" override, honouring the equality rule and the no-coordinate fallback. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): default the roleplay position to the person's location`.

### Commit 4. Tests + doc/mockup cross-links

Fold the per-area tests into commits 1–3 where natural; this commit backfills the gaps and links the mockup from the design doc. Commit: `test(views): cover the loc rename and the roleplay identity/position cards`.

### Tests

* **Rename.** Renderer resolves `{{station.person.<slug>.loc.utm}}` and `.loc.place` with no `.home` anywhere; the picker offers `loc` (not `home`); facet-completion chains `loc.<facet>`; the person editor round-trips `locSlug`.
* **Identity card.** The card shows the effective summary; overriding a facet surfaces it as an accented field with "Tilbakestill"; the collapsed card shows the override count; the panel auto-expands when an override exists; gender is on its own row; no "Arvet fra person" caption; the effective identity still resolves and persists denormalized.
* **Position.** Default follows the person's `loc` coordinate; "Sett egen" stores an override; a person with no `loc` shows the empty picker; changing the person's location updates an inherited position but leaves an overridden one.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make build` and `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke against `roleplay-editor.html`: the editor leads with Post, then the identity card (collapsed → "Tilpass" → override with Tilbakestill, gender on its own row), then the position card following the person's location with "Sett egen"; the picker and brief speak `station.person.*.loc.*`.
4. `git grep -n "homeSlug\|personsSectionHomeLabel"` returns nothing; the person-facet `'home'` is gone (the `LocationKind.home` enum is untouched).
5. Clean tree; generated files (`*.g.dart`, `*.freezed.dart`, `app_localizations*.dart`) committed with their sources.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body records the decisions: the person location renamed to `loc` as a clean rename with **no alias** (nothing published), the RolePlay identity and position packed into inherit/override cards with the effective value still persisted denormalized, gender moved to its own row, and "point the marker at a different station location" left deferred.

ADR-0047 and DESIGN-009 are authoritative. If the position-follows-person work needs renderer or map changes beyond the editor and the existing effective-identity mechanism, stop and report rather than expanding this prompt.
