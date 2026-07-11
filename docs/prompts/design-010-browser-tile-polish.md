# Implement DESIGN-010 follow-up: browser tile polish (Poster / Spill)

You are working in the RingDrill repository, on `design-010`. Polish and complete the tabbed **browser tiles** — the expandable station tiles (Poster tab, `stations_view.dart`) and roleplay tiles (Spill tab, `roleplays_view.dart`), distinct from the 3b detail sheets: five issues, including that `{{station.*}}` tokens do not resolve there yet. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative. Read `AGENTS.md` rule 9.

**No model or schema change.** Views + l10n + test.

## Fixes

### Fix 1. Section dividers with uniform padding

Sections in the tiles run together. The Spill tile already separates its sections with horizontal dividers — carry that to the Poster tile (and the other expandable tab tiles) so every section is divided consistently. **Every divider must have equal padding above and below**; today the divider between the description and the position card has less padding than the one below the position card. Use one shared divider spacing (a single constant / a small helper) everywhere so the rhythm is uniform.

### Fix 2. Differentiate the marker header and marker row icons

In the Poster tile the "Markører (N)" section header and each marker row use the **same** masks-theater icon, which reads oddly. Differentiate: keep the masks-theater icon on the section header (the "markers" group) and give the marker **row** a person icon (or vice-versa) — the header and the row should not be the same glyph.

### Fix 3. Cast tile text (Spill tile)

In `roleplays_view.dart`'s Cast section, the actor shows as the bare name ("Nina") with the `castPrivateHint` ("Lagres lokalt") subtitle. Change to:
* "**Spilles av {realName}**" (reuse `castedByLine`, the same "Spilles av …" wording the detail sheet uses), not the bare name.
* Keep the phone number when set (the tappable `tel:` line).
* **Drop `castPrivateHint` ("Lagres lokalt")** — deprecated wording we've moved away from. If the actor has other set info (e.g. notes), that may show; otherwise nothing.

### Fix 4. Portrait overflow ellipsis

Overflow menus in these tiles use the horizontal ellipsis (`Icons.more_horiz`, ⋯). Switch to the **portrait/vertical** ellipsis (`Icons.more_vert`, ⋮), matching the rest of the app.

### Fix 5. Resolve tokens in the tiles

The Poster/Spill tiles still render `{{station.position.utm}}` and other `{{station.*}}` tokens **literally**, because the tiles resolve only `var.*`/`program.*` — each tile lists a different station, so there is no single `StationScope` in scope. Fix it: wrap **each expandable tile** in its own `StationScope`, seeded from that tile's station (Poster) or the linked station (Spill) — its `locations`/`persons` and own facets — under the existing `PlanScope`/`ExerciseScope` ancestry, and route the tile's text through `resolveScopedField` / `RingDrillText` (stage 1/3a). Then `{{station.loc/person.*}}`, `{{station.position.utm}}` and the rest resolve per tile, exactly as they do in the detail sheets. This closes the 3a multi-entity gap here — do it, don't defer it.

## Scope

Two commits.

### Commit 1. Tile polish + token resolution

Uniform section dividers (equal padding above/below, shared spacing) across the Poster/Spill tiles; distinct marker header vs row icons; the Cast tile shows "Spilles av {realName}" + phone (when set), dropping `castPrivateHint`; `more_vert` for the overflow; and **each tile wrapped in its own `StationScope`** so `{{station.*}}` resolves per tile (Fix 5). Split into two commits if cleaner (polish, then resolution), but land both.

Files: `lib/views/stations_view.dart`, `lib/views/roleplays_view.dart` (and any shared tile widget / a divider-spacing constant). ARB only if a string changes. `flutter analyze` + `flutter test test/views/`. Commit: `fix(views): polish the Poster/Spill browser tiles and resolve station tokens`.

### Commit 2. Tests

* Section dividers appear between the tile's sections with equal padding above/below (a spacing assertion, or that one shared spacing value is used).
* The marker section header and marker row use different icons.
* The Cast tile renders "Spilles av {realName}" (not the bare name), shows the phone when set, and does **not** render the `castPrivateHint` string.
* The tile overflow uses `more_vert`.
* A `{{station.position.utm}}` / `{{station.loc.*}}` token in a tile resolves (not literal), via the per-tile `StationScope` — a regression test for the closed gap.

Files: test files under `test/views/`. `flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover the browser tile polish`.

## Ground rules

* Views + l10n + test only. No model, renderer, or schema change. `make i18n` only if a string changes.
* Reuse existing pieces: `castedByLine` for the cast line, one shared divider spacing, the same person/marker icons used elsewhere.
* **Complete the goal, don't defer adjacent work.** Fix *every* instance of each issue across these tiles, and any obviously-related gap you hit in the same files — don't carve a narrow slice and leave the rest for another round.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent (if touched); `dart build cli` succeeds.
3. Manual smoke: the Poster and Spill tiles separate their sections with dividers of equal top/bottom padding; the marker header and row have different icons; the Cast tile reads "Spilles av Nina" (+ phone when set) with no "Lagres lokalt"; overflow menus use the vertical ⋮; and `{{station.position.utm}}` (and other `station.*`) now resolves in the tiles instead of showing literally.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…` (if any), `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the Poster/Spill browser tiles now use uniform section dividers, distinct marker header/row icons, a "Spilles av {actor}" cast line (phone when set, no "Lagres lokalt"), the portrait overflow ellipsis, and per-tile `StationScope` so `{{station.*}}` resolves in the tiles (closing the 3a multi-entity gap).

DESIGN-010 is authoritative. If the divider spacing or icons warrant a shared change beyond these two files, make it and note it rather than deferring.
