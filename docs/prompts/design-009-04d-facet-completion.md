# Implement DESIGN-009 — Prompt 4d: facet completion for station.loc/person tokens

You are working in the RingDrill repository, on `design-009`. A **views-only** follow-up that finishes what DESIGN-009 already promised (see "Referencing in text" — the `.place` / `.utm` / `.age` / `.home.utm` facets) and pins in "Own-entity facets, facet completion, and leaf fields". Today the picker inserts only the **bare** `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`; the resolvable facets must be typed by hand. This adds facet completion to the picker. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Read `AGENTS.md` rule 9.

**No model change, no renderer change.** The facets already resolve in `BriefRenderer` (`_resolveLocationFacet` / `_resolvePersonFacet`). This is picker UX only. Protected invariant, same as 4b/4c: *the picker never offers a token the renderer can't resolve.*

## The facet sets (verified against `brief_renderer.dart`)

* **Location** (`_resolveLocationFacet`): `place`, `label`, `utm`. Bare token (no facet) is the sensible default (place + inline-code UTM).
* **Person** (`_resolvePersonFacet`): `name`, `age`, `gender`, `signalement`, `home`. Bare token is the effective name. `home` resolves the person's `homeSlug` to a location and **chains** to that location's facets, so `{{station.person.anne.home.utm}}` is valid.

Do not offer any facet outside these sets. A resolution-guard test (below) enforces it.

## Behavior

The `{{` trigger already tolerates dots (`[\w.]*`), so `{{station.person.anne.` keeps the menu open. Extend `_filteredEntries` so that, within the `station.loc.` / `station.person.` namespace (the prefix parsing 4c fixed), the part after the prefix is read as `<slug>[.<facetPath>]`:

* **Discovery (no dot yet).** When the remainder exactly equals an existing location/person slug, show the bare default entry as today **and**, beneath it, that entity's facet entries — so the author sees the facets without having to know to type `.`. This is the important discoverability piece for non-technical authors.
* **Completion (dotted).** When the remainder is `<slug>.<partial>` and `<slug>` matches an existing entity, list that kind's facets filtered by `<partial>`; selecting one inserts the full dotted token (`{{station.person.anne.signalement}}`).
* **Home chaining.** For a person, when the path is `<slug>.home.<partial>`, offer the **location** facets (`place`, `label`, `utm`) filtered by `<partial>`, inserting e.g. `{{station.person.anne.home.utm}}`. One level of chaining (`home` → location) is enough for v1.
* **Fallthrough.** When `<slug>` matches no existing entity, keep today's behaviour: filter entities by `contains`, and offer the "Create …" entry (4-behaviour) unchanged. Facet mode activates only on an exact slug match.

The bare entity entry still inserts the complete, closed `{{station.loc.<slug>}}` — facets are additive, never replacing the default.

## Ground rules

* Reuse the existing `{{`/`/` menu, `StationScope`'s `locations`/`persons` (to know which slugs exist), and the prefix parsing from 4c. Add a menu-entry kind for a resolved facet (e.g. `StationFacetMenuEntry` carrying kind + slug + facet path), or extend the existing loc/person entries — your call, keep it in `token_insertion_menu.dart`.
* Define the facet-name lists as small constants in the view layer (there is no facet enum in the renderer). The resolution-guard test is what keeps them in sync with `brief_renderer.dart`.
* Facet **labels** in the picker via ARB, then `make i18n`. Reuse the Location/Person form field labels where they exist (`place`, `label`/reference wording, `age`, `gender`, `signalement`, and the "Bopel"/home label). Add only what is missing (likely `utm` → "UTM", `place` → "Sted", `home` → "Bopel"). Natural en counterparts.
* No self-reference rule here — a facet references another entity's data, not the field being edited.
* Views-only. No `brief_renderer.dart`, model, or `refContext` change.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Three commits.

### Commit 1. Facet entries + labels

Extend `_filteredEntries`/`_select` (and add the facet menu-entry kind + tiles) so an exact loc/person slug surfaces its facet entries (discovery), a dotted path filters and completes them, and selection inserts the full dotted token. Add the facet-name constants and any missing ARB labels; `make i18n`.

Files: `lib/views/widgets/token_insertion_menu.dart`, `lib/views/widgets/editor_token.dart` (if the entry kind lives there), `lib/l10n/*.arb` + regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): complete station.loc/person facets in the token picker`.

### Commit 2. Home chaining

For a person path `<slug>.home.<partial>`, offer the location facets and insert `{{station.person.<slug>.home.<facet>}}`.

Files: `token_insertion_menu.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): chain person home to location facets in the picker`.

### Commit 3. Tests

Under `test/views/` plus a renderer round-trip guard:

* **Discovery.** With a location `lkp` and a person `anne` on the station's `StationScope`, a filter of exactly `station.loc.lkp` shows the bare entry plus `place`/`label`/`utm`; `station.person.anne` shows the bare entry plus `name`/`age`/`gender`/`signalement`/`home`.
* **Completion.** `station.person.anne.sig` narrows to `signalement`; selecting it inserts `{{station.person.anne.signalement}}`. `station.loc.lkp.ut` → `{{station.loc.lkp.utm}}`.
* **Home chaining.** `station.person.anne.home.ut` offers the location `utm` and inserts `{{station.person.anne.home.utm}}`.
* **Fallthrough.** An unknown slug offers the "Create …" entry, not facets.
* **Resolution guard (the important one).** For every offered facet (location and person, including a `home`-chained location facet), build a sample station with the entity populated, render the inserted token through `BriefRenderer`, and assert no `briefUnknownReference` placeholder. This enforces "the picker never offers an unresolvable facet" and catches drift from the renderer's facet switch.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover facet discovery, completion, home chaining and resolution`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: in a station markdown field, typing `{{station.person.` lists the people; picking one (or typing its slug) reveals `navn`/`alder`/`kjønn`/`signalement`/`bopel`; picking `signalement` inserts the full token; `…home.utm` resolves the home location's UTM in the brief; the bare token still inserts the default.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`. No model or renderer change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the picker now completes the `station.loc/person` facets (with person `home` chaining to location facets), discoverable from an exact slug match, guarded by a renderer round-trip so an offered facet can never be unresolvable.

ADR-0047 and DESIGN-009 are authoritative. Token-aware scenario leaf fields (4e) move under DESIGN-010 and are out of scope here. If facet completion needs anything beyond picker logic, facet-name constants, ARB labels, and tests, stop and report.
