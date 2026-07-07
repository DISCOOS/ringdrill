# Implement DESIGN-009 — Prompt 3: Locations and Persons sections + map

You are working in the RingDrill repository, on the `design-009` branch. Implement the editor sections and map markers of DESIGN-009. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Prompts 1 (model) and 2 (resolution) have shipped. Read those, `AGENTS.md` rule 9 (test-loop discipline), [ADR-0031](../adrs/0031-row-edit-affordances.md) (row affordances) and [ADR-0020](../adrs/0020-map-label-and-marker-clutter.md) (`MapMarkerSpec`).

This prompt adds the two first-class **Locations** and **Persons** sections to the station editor, the `LocationKind` i18n, and the map markers. It does **not** include the token picker / inline-create / RolePlay editor (prompt 4) or rename/delete reference integrity (prompt 5). No feature flag (DESIGN-009 is additive).

## What this builds

`StationFormScreen` is already a `SectionNavigatedForm` (DESIGN-008). Add two first-class `FormSection`s, **Locations** and **Persons**, after the base **Station** section and the Variabler override section, before the markdown sections. They are the management surface for the station's `locations` and `persons` (single source; the narrative md fields reference them). Their rows reuse the `VariableOverridesSection`-style row look and the section shell.

## Ground rules

* Reuse `SectionNavigatedForm` / `FormSection`, the existing coordinate/map-pick affordance used for `Station.position`, and `MapMarkerSpec` (ADR-0020). Do not invent new navigation or marker plumbing.
* Row edit affordances follow ADR-0031: actions in a `⋮` overflow, never a per-row pencil.
* The form owns a working copy of `station.locations` / `station.persons`; `_save` writes them via `copyWith`.
* **Scope boundary:** this prompt does add / edit-fields / plain delete on the two lists. **Slug rename and the reference-rewrite/guard are prompt 5** — do not implement them here. Slug is set at creation; editing changes non-slug fields; delete just removes (the reference guard comes in prompt 5). Note this in a code comment so the gap is intentional, not forgotten.
* User-visible strings via ARB, then `make i18n`. This includes the `LocationKind` `label` and `description` per kind.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/views/` or `test/models/` for the resolver); `make i18n` only in the commit that changes ARB; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Four commits.

### Commit 1. LocationKind i18n

Add `label` and `description` for every `LocationKind` value to `app_en.arb` / `app_nb.arb` (`locationKind<Name>Label` / `locationKind<Name>Description`), with the Norwegian labels from DESIGN-009's "Norwegian labels (nb)" table (lkp → "Sist kjent posisjon (LKP)", ipp → "Initielt planleggingspunkt (IPP)", pp → "Planleggingspunkt (PP)", rendezvous → "Oppmøtested", commandPost → "Kommandoplass", home → "Bosted", trackFound → "Funn av spor", dogInterest → "Interesse av hund", obstacle → "Hindring", notSearchable → "Ikke søkbart", phoneTrace → "Mobilspor", observation → "Observasjon", vantagePoint → "Utkikkspunkt", containmentPost → "Sperrepost", personFound → "Funn av person", other → "Annet"). Add a `LocationKindX` extension (`label(AppLocalizations)`, `description(AppLocalizations)`) resolving each value to its ARB entry. Run `make i18n`.

Files expected: `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated localizations, the `LocationKindX` extension (co-locate with the enum or a small `lib/models/location_kind_labels.dart` — keep it Flutter-free if in `lib/models/`; if it depends on `AppLocalizations`, put it under `lib/views/`).

Per commit: `flutter analyze`. Commit: `feat(l10n): add LocationKind labels and descriptions`.

### Commit 2. Locations and Persons sections

Add `VariableOverridesSection`-style section widgets and mount them as first-class `FormSection`s in `StationFormScreen`.

* **Locations** section: a row per location showing `label`, its `kind` (with the localized label), `place`, and the coordinate with the existing map-pick affordance. `⋮` per row → Edit (fields, not slug), Delete (plain). "+ New location" adds one (author gives a slug + label; a blank kind defaults to `other`).
* **Persons** section: a row per person showing `name`, `age`, `gender`, `signalement`, a **home** picker (a selector over the station's locations, setting `homeSlug`; empty when none), and `notes`. `⋮` → Edit, Delete. "+ New person" adds one.

Bind both to the form's working `locations`/`persons`; `_save` persists via `copyWith`.

Files expected: the two section widgets under `lib/views/widgets/`, `lib/views/station_form_screen.dart`, ARB for the section labels / actions + regenerated localizations (`make i18n` if strings added).

Per commit: `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): add Locations and Persons sections to the station editor`.

### Commit 3. Map markers

Render the station's `locations` (and each person's `home`, resolved via `homeSlug`) as `MapMarkerSpec` markers (ADR-0020), styled by `LocationKind` (a distinct glyph/tone per kind is enough — a full icon set can follow), visually distinct from the administrative `Station.position` marker. The map, the brief and the editor now read the same locations.

Files expected: the map view / marker-building files, plus any small styling map for `LocationKind`.

Per commit: `flutter analyze` + targeted tests. Commit: `feat(views): show station locations and person homes on the map`.

### Commit 4. Tests

Widget tests under `test/views/` (make the flag-free editor testable by pumping the section widgets / station form directly):

* Adding a location writes it to `locations` on save; editing its fields persists; deleting removes it.
* Adding a person writes it to `persons`; the home picker sets `homeSlug` to a station location; editing/deleting persists.
* `LocationKindX.label` returns the localized string for each value.
* A map test (or a marker-spec builder unit test) asserts a location and a person home produce markers styled by kind, distinct from the position marker.

Run `flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files expected: test files under `test/views/`.

Commit: `test(views): cover Locations/Persons sections and map markers`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent after commit; `dart build cli` succeeds.
3. Manual smoke: the station editor shows Locations and Persons as their own sections (bottom-bar switcher on compact, rail on wide); adding/editing/deleting works; a location with a coordinate and a person's home show on the map, styled by kind, distinct from the station position.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `lib/models/…` (if the `LocationKindX` extension lands there), `test/…`. No model-shape changes, no `lib/services/`.
5. Clean tree; generated localizations committed with the ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit and one full-suite gate at the end (rule 9). The final commit body notes that Locations and Persons are first-class station sections with map markers, that slug rename and the reference-rewrite/delete-guard are prompt 5, and that the token picker + RolePlay editor + inline-create/write-back are prompt 4.

ADR-0047 and DESIGN-009 are authoritative. If reusing the existing coordinate/map-pick affordance or `MapMarkerSpec` needs a structural change, make the minimal one and note it; if it needs a larger change, stop and ask. No new ADR for this prompt.
