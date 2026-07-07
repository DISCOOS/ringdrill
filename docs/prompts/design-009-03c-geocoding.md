# Implement DESIGN-009 — Prompt 3c: geocoding in the Location form

You are working in the RingDrill repository, on `design-009`. Add geocoder assist to the Location form so a `place` can set the coordinate and vice versa. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Prompt 3 built the sections; prompt 3b (the editor-UX follow-up) built the full-screen Location form with a plain `place` field and an inline position picker. This upgrades that `place` field. Read `AGENTS.md` rule 9 (test-loop discipline).

**No new dependency, no new ADR.** RingDrill already geocodes in the map search: `lib/views/map_view.dart` uses `package:osm_nominatim` (Nominatim) for place search, with `SearchResult`. Reuse that same geocoder. This is not a new external service, so [ADR-0007](../adrs/0007-drill-file-format.md)/rule 11 don't apply. The coordinate is stored as `LatLng` (WGS84) — geocoding only sets/reads that; UTM stays a render-time projection (ADR-0047).

## Behavior

* **Forward (place → position).** The `place` field becomes a search: as the author types (debounced), query the geocoder and show suggestions; picking one sets `place` to the canonical name **and** sets `position`. Reuse the map-search flow (`osm_nominatim` / `SearchResult`).
* **Reverse (position → place).** When the author sets `position` via the map picker and `place` is empty, reverse-geocode (`osm_nominatim` reverse) and fill `place` as an editable suggestion. If `place` already has text, do **not** clobber it — offer an explicit "oppdater fra kart" instead.
* **Suggestion, not authority.** The author's own entry always wins. Geocoding only auto-fills the empty counterpart; otherwise it suggests. Never overwrite a field the author has typed without an explicit action.
* **Best-effort.** Offline, an error, or no result is a silent no-op — manual entry and the map picker still work, and geocoding never blocks save. This is a field tool; assume flaky connectivity.

## Ground rules

* Reuse `map_view.dart`'s geocoding, don't duplicate it. If the search/reverse logic is inlined there, extract a small reusable geocoding service (forward `search(query)` + `reverse(latLng)`) that both the map and the Location form call. Keep it injectable so tests pass a fake (no network in tests).
* Views/services-only; no model-shape change (`Location.place`/`position` already exist).
* User-visible strings via ARB, then `make i18n` ("Søk etter sted", "Oppdater fra kart", a "fant ingen treff"/offline hint).
* Reuse the existing HTTP client pattern from `map_view.dart` (the retry client); no new network origins beyond what map search already uses.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/views/` / `test/services/`); `make i18n` only when ARB changes; full `flutter test` + `dart build cli` **once at the end**. Tests must not hit the network — inject a fake geocoder.

## Scope

Three commits.

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

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures; no test hits the network.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke (online): typing a place suggests and sets the coordinate; dropping a pin fills an empty place; a typed place is never overwritten silently. Offline: the form still works, no errors surfaced, save not blocked.
4. `git diff --stat` touches `lib/services/…`, `lib/views/…`, `lib/l10n/…`, `test/…`. No model-shape change. Map search still works (shared geocoder).
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes that the Location form now geocodes `place` both ways via the shared (reused) geocoder, best-effort and non-clobbering, with the coordinate stored as `LatLng`.

ADR-0047 and DESIGN-009 are authoritative. Reuse the existing geocoder; if extracting the shared service ripples into map behavior beyond a mechanical refactor, stop and report. No new ADR for this follow-up.
