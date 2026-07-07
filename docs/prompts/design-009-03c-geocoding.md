# Implement DESIGN-009 — Prompt 3c: geocoding in the Location form

You are working in the RingDrill repository, on `design-009`. Add geocoder assist to the Location form so a `place` can set the coordinate and vice versa. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Prompt 3 built the sections; prompt 3b (the editor-UX follow-up) built the full-screen Location form with a plain `place` field and an inline position picker. This upgrades that `place` field. Read `AGENTS.md` rule 9 (test-loop discipline).

**No new dependency, no new ADR.** RingDrill already geocodes in the map search: `lib/views/map_view.dart` uses `package:osm_nominatim` (Nominatim) for place search, with `SearchResult`. Reuse that same geocoder. This is not a new external service, so [ADR-0007](../adrs/0007-drill-file-format.md)/rule 11 don't apply. The coordinate is stored as `LatLng` (WGS84) — geocoding only sets/reads that; UTM stays a render-time projection (ADR-0047).

## Behavior

* **Forward (place → position).** The `place` field becomes a search: as the author types (debounced), query the geocoder and show suggestions; picking one sets `place` to the canonical name **and** sets `position`. Reuse the map-search flow (`osm_nominatim` / `SearchResult`).
* **Reverse (position → place).** When the author sets `position` via the map picker and `place` is empty, reverse-geocode (`osm_nominatim` reverse) and fill `place` as an editable suggestion. If `place` already has text, do **not** clobber it — offer an explicit "oppdater fra kart" instead.
* **Suggestion, not authority.** The author's own entry always wins. Geocoding only auto-fills the empty counterpart; otherwise it suggests. Never overwrite a field the author has typed without an explicit action.
* **Best-effort.** Offline, an error, or no result is a silent no-op — manual entry and the map picker still work, and geocoding never blocks save. This is a field tool; assume flaky connectivity.

## Also in this prompt (editor-UX review)

Two small refinements folded in with the geocoding work:

* **Section header shows the station name.** In the station's `SectionNavigatedForm`, the AppBar title shows the **station's display name** on every section *except* the base "Post" section (so you can see which station you're in from Locations, Persons, Variabler and the markdown sections). The base section keeps the generic edit title (the name is edited there). Implement as an opt-in on the shell (e.g. an `entityName` the caller passes; non-default sections show it, the default section shows the static `title`) and have the station editor pass the station name — so other editors can adopt it later without change.
* **Simpler list chrome.** In the Locations and Persons sections: drop the category/sort control (lists are short — not worth it), and put the search field and the "+ Ny lokasjon" / "+ Ny person" action on **one row at the bottom** of the list. Restyle the search to match RingDrill's existing search-field idiom (e.g. the map search field) rather than the current bespoke look.

## Ground rules

* Reuse `map_view.dart`'s geocoding, don't duplicate it. If the search/reverse logic is inlined there, extract a small reusable geocoding service (forward `search(query)` + `reverse(latLng)`) that both the map and the Location form call. Keep it injectable so tests pass a fake (no network in tests).
* Views/services-only; no model-shape change (`Location.place`/`position` already exist).
* User-visible strings via ARB, then `make i18n` ("Søk etter sted", "Oppdater fra kart", a "fant ingen treff"/offline hint).
* Reuse the existing HTTP client pattern from `map_view.dart` (the retry client); no new network origins beyond what map search already uses.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/views/` / `test/services/`); `make i18n` only when ARB changes; full `flutter test` + `dart build cli` **once at the end**. Tests must not hit the network — inject a fake geocoder.

## Scope

Six commits (three geocoding, three UX-review).

### Commit 1. Reusable geocoding service

Extract a small geocoding abstraction (forward `search`, reverse `reverse`) from the map-search path, backed by the existing `osm_nominatim` usage, injectable (an interface + the real impl + a way for tests to substitute a fake). Refactor `map_view.dart` to use it so there is one geocoder, not two. Behavior-preserving for the map.

Files: a new geocoding service under `lib/services/` (or `lib/data/` if it must stay Flutter-free — it likely can live in services), `lib/views/map_view.dart`. `flutter analyze` + `flutter test test/views/ test/services/`. Commit: `refactor: extract a reusable geocoding service from map search`.

### Commit 2. Wire geocoding into the Location form

In the Location form (prompt 3b), turn `place` into a geocoder-backed search (debounced suggestions → sets `place` + `position`), and add reverse: setting `position` when `place` is empty fills `place` as a suggestion, with an explicit "oppdater fra kart" when `place` is non-empty. All best-effort and non-blocking per the behavior above.

Files: the Location form widget, ARB + regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): geocode place in the Location form (forward and reverse)`.

### Commit 3. Tests

With an injected fake geocoder (no network):

* Forward: typing a query shows suggestions; picking one sets `place` (canonical) and `position`.
* Reverse: setting `position` with an empty `place` fills `place`; with a non-empty `place` it does not clobber (the "oppdater fra kart" path does).
* Best-effort: a geocoder that returns nothing or throws leaves the form usable and does not block save.
* The map still geocodes through the shared service (a small regression check).

`flutter analyze`, `flutter test test/views/ test/services/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/`. Commit: `test: cover Location-form geocoding (forward, reverse, offline-graceful)`.

### Commit 4. Section header shows the station name

In `section_navigated_form.dart`, add an opt-in so the AppBar title shows a caller-supplied entity name on non-default sections while the default (first) section keeps the static `title`. Wire `StationFormScreen` to pass the station's name, so Locations/Persons/Variabler/markdown sections show the station name and the "Post" base section shows the generic edit title. Behavior-preserving for editors that don't pass an entity name.

Files: `lib/views/widgets/section_navigated_form.dart`, `lib/views/station_form_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): show the station name as the section header off the base section`.

### Commit 5. Simpler list chrome

In the Locations and Persons sections: remove the sort/category control; render a single bottom row holding the search field and the "+ Ny …" action; restyle the search to RingDrill's existing search-field idiom (match the map search field rather than the bespoke look). Keep search filtering behavior.

Files: the two section widgets, ARB if any string changes. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): move list search and add-action to one bottom row, drop the sort control`.

### Commit 6. Section ordering

Two ordering rules that hold in every editor's switcher:

* **Variabler is always the last section**, in all selectors (Program, Exercise and Station editors). Make it a guarantee, not per-editor discipline — either pin it last in the shell (e.g. a `FormSection` ordering hint the shell renders last) or ensure every editor builds its list with Variabler last. This also moves the Program editor's Variabler section (currently just after the base) to the bottom.
* **In the station editor, Persons comes before Locations**, and both come before the narrative markdown sections. So the station order is: Post (base) → Persons → Locations → markdown sections → Variabler.

Files: `lib/views/widgets/section_navigated_form.dart` (if pinning in the shell), `program_form_screen.dart`, `exercise_form_screen.dart`, `station_form_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): pin Variabler last and order Persons above Locations`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures; no test hits the network.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke (online): typing a place suggests and sets the coordinate; dropping a pin fills an empty place; a typed place is never overwritten silently. Offline: the form still works, no errors surfaced, save not blocked. Also: the station name shows as the header on Locations/Persons (and other non-base sections) but not on the base "Post" section; the list search + "+ Ny …" sit on one bottom row with no sort control, styled like the app's other search fields; Variabler is the last section in every editor's switcher and Persons sits above Locations in the station editor.
4. `git diff --stat` touches `lib/services/…`, `lib/views/…`, `lib/l10n/…`, `test/…`. No model-shape change. Map search still works (shared geocoder).
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes that the Location form now geocodes `place` both ways via the shared (reused) geocoder, best-effort and non-clobbering, with the coordinate stored as `LatLng`.

ADR-0047 and DESIGN-009 are authoritative. Reuse the existing geocoder; if extracting the shared service ripples into map behavior beyond a mechanical refactor, stop and report. No new ADR for this follow-up.
