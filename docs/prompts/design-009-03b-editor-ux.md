# Implement DESIGN-009 — Prompt 3 follow-up: editor UX for Locations and Persons

You are working in the RingDrill repository, on `design-009`. This follow-up to prompt 3 reworks the Locations/Persons editing UX to match the app's design language. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Prompt 3 shipped the two sections but with dialog-based forms on narrow, per-row embedded pickers, no search/sort/scroll, and a manual "slug" field. Fix those. Read `AGENTS.md` rule 9 (test-loop discipline), [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) (forms as full-screen on narrow / dialog on wide), and [ADR-0031](../adrs/0031-row-edit-affordances.md).

**Visual reference:** `docs/design/mockups/scenario-location-person-editor.html` (three screens: the list, the location form, the person form).

Out of scope here: geocoding of `place` (its own follow-up + ADR), and reference (slug) renaming (a **future** action — ADR-0047). No feature flag.

## What changes

1. **Forms via `openFormSurface`.** Add/edit of a Location or Person opens through `openFormSurface` — a full-screen route/sheet on narrow, a dialog on wide (ADR-0030) — never a raw `AlertDialog` on narrow. Each form has its own AppBar (close + Save).
2. **List rows become light tiles.** No per-row embedded `PositionFormField`/dropdown. A Location row is a tile: kind icon + `label` + a `place`/UTM summary. A Person row is a tile: `name` + an `age`/`gender`/`signalement` summary. Tap a row → open its edit form. `⋮` → delete. "+ Ny lokasjon" / "+ Ny person" → open the add form.
3. **Search, sort, scroll.** Each list gets a search field (filter by label/name/place) and a sort toggle (default: by kind then label for locations, by name for persons), and scrolls. Keep it simple — a `TextField` filter over the working list plus a sort control.
4. **Self-sufficient Location form.** Fields: `label`; `kind` as a **category grid** (the localized `LocationKind` cards, 2-up, with a "Vis alle 16 kategorier" expansion); `place` (plain text for now — geocoding is a later follow-up); `position` set **inside the form** via the existing map-pick affordance (`PositionFormField` / `MapPickerScreen`) with a mini-preview + "Velg på kart" + the UTM readout; `note`. The author never has to leave the form to set position.
5. **Self-sufficient Person form.** Fields: `name`; `age`; `gender` as a **segmented control** (Kvinne / Mann / Annet → stable codes `woman` / `man` / `other`, i18n labels); `signalement`; `home` picker over the station's locations that also offers **"+ Ny lokasjon"** inline — selecting it opens the Location form and, on save, returns the new location selected as home (no need to create it first); `notes`.
6. **Auto-generated reference; no manual slug.** The reference (`slug`) is generated from the `label`/`name` at creation (slugify + ensure unique within the station), for the form and for inline create. Remove the manual slug field entirely. Editing the display name is free and does not change the reference. Renaming the reference is a **future** action (ADR-0047) — do not build it here.
7. **Wording.** Replace every user-facing "slug" with "referanse" (nb) / "reference" (en). The word "slug" stays only in code/comments.

## Ground rules

* Reuse `openFormSurface`, `PositionFormField`/`MapPickerScreen`, the section shell, and the existing list/tile idioms. Do not invent new navigation.
* The segmented `gender` control writes stable codes (`woman`/`man`/`other`) with i18n labels; store on the existing `String? gender` field (no model change). Build it so prompt 4's RolePlay editor can reuse the same control.
* User-visible strings via ARB, then `make i18n` (gender labels, "referanse", search/sort labels, "Vis alle 16 kategorier", inline "Ny lokasjon").
* No model-shape changes (prompt 1 shipped the fields). No `lib/services/` changes.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only when ARB changes; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Four commits.

### Commit 1. Auto-generated reference + wording

Add a slugify helper that derives a unique-within-station reference from a label/name, and use it wherever a Location/Person is created (the forms and inline create). Remove the manual slug input from the prompt-3 forms. Replace user-facing "slug" strings with "referanse"/"reference" in ARB. `make i18n`.

Files: the section/form widgets from prompt 3, a small slugify helper, `lib/l10n/*.arb` + regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): auto-generate location/person reference and drop the manual slug field`.

### Commit 2. Location form + list

Move Location add/edit into `openFormSurface`. Build the form: label, category grid (`LocationKind` localized, expandable), place (plain text), inline position picker (`PositionFormField`/`MapPickerScreen` with mini-preview + UTM), note. Rebuild the Locations list as searchable, sortable, scrollable light tiles (kind icon + label + place/UTM), tap → edit, `⋮` → delete, "+ Ny lokasjon" → add form.

Files: Location section + form widgets, `station_form_screen.dart`, ARB if strings added. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): full-screen Location form with category grid and inline position; searchable list`.

### Commit 3. Person form + list

Move Person add/edit into `openFormSurface`. Build the form: name, age, gender segmented control, signalement, home picker (station locations + inline "Ny lokasjon" that opens the Location form and returns the new location as home), notes. Rebuild the Persons list as searchable, sortable, scrollable tiles (name + summary), tap → edit, `⋮` → delete, "+ Ny person" → add form.

Files: Person section + form widgets, the shared gender segmented control, `station_form_screen.dart`, ARB. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): full-screen Person form with segmented gender and inline home creation; searchable list`.

### Commit 4. Tests

Widget tests under `test/views/`:

* Adding a location/person auto-generates a unique reference from the name; two same-named entries get distinct references; editing the display name leaves the reference unchanged.
* The Location form sets `position` inline (via the map-pick affordance) without leaving the form; the category grid sets `kind`.
* The Person form's gender segmented control writes `woman`/`man`/`other`; the home picker's "Ny lokasjon" creates a location and selects it as `homeSlug`.
* The lists filter by search text and re-sort; forms open through `openFormSurface` (assert full-screen route on narrow, dialog on wide via `WindowSizeClass`).
* No user-facing "slug" string remains (grep-style assertion or a UI text check).

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover auto-reference, form surfaces, gender control and inline home creation`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke (narrow and wide): Location/Person add/edit open as full-screen on narrow and dialog on wide; lists search/sort/scroll; the Location form sets position inline and picks a category from the grid; the Person form uses the segmented gender and creates a home location inline; no reference/slug field is shown and no "slug" wording appears.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/views/…` (plus a small helper). No model or service changes.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the editor now matches the design language (full-screen forms on narrow, searchable lists, self-sufficient forms), that the reference is auto-generated (rename is future), and that geocoding of `place` is a separate follow-up.

ADR-0047 and DESIGN-009 are authoritative. If reusing `PositionFormField`/`openFormSurface` needs a small structural change, make it and note it; if larger, stop and ask. No new ADR for this follow-up.
