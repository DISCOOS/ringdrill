# Implement DESIGN-010 follow-up: browser tile polish (Poster / Spill)

You are working in the RingDrill repository, on `design-010`. Four visual issues in the tabbed **browser tiles** — the expandable station tiles (Poster tab, `stations_view.dart`) and roleplay tiles (Spill tab, `roleplays_view.dart`), distinct from the 3b detail sheets. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative. Read `AGENTS.md` rule 9.

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

## Scope

Two commits.

### Commit 1. The four fixes

Uniform section dividers (equal padding above/below, shared spacing) across the Poster/Spill tiles; distinct marker header vs row icons; the Cast tile shows "Spilles av {realName}" + phone (when set), dropping `castPrivateHint`; `more_vert` for the overflow.

Files: `lib/views/stations_view.dart`, `lib/views/roleplays_view.dart` (and any shared tile widget / a divider-spacing constant). ARB only if a string changes (none expected beyond dropping `castPrivateHint` usage). `flutter analyze` + `flutter test test/views/`. Commit: `fix(views): polish the Poster/Spill browser tiles (dividers, icons, cast, overflow)`.

### Commit 2. Tests

* Section dividers appear between the tile's sections with equal padding above/below (a spacing assertion, or that one shared spacing value is used).
* The marker section header and marker row use different icons.
* The Cast tile renders "Spilles av {realName}" (not the bare name), shows the phone when set, and does **not** render the `castPrivateHint` string.
* The tile overflow uses `more_vert`.

Files: test files under `test/views/`. `flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover the browser tile polish`.

## Ground rules

* Views + l10n + test only. No model, renderer, or schema change. `make i18n` only if a string changes.
* Reuse existing pieces: `castedByLine` for the cast line, one shared divider spacing, the same person/marker icons used elsewhere.
* Do not touch token resolution here (the Poster tile's literal `{{station.position.utm}}` is the known multi-entity-list limitation from 3a — out of scope for this polish).
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent (if touched); `dart build cli` succeeds.
3. Manual smoke: the Poster and Spill tiles separate their sections with dividers of equal top/bottom padding; the marker header and row have different icons; the Cast tile reads "Spilles av Nina" (+ phone when set) with no "Lagres lokalt"; overflow menus use the vertical ⋮.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…` (if any), `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the Poster/Spill browser tiles now use uniform section dividers, distinct marker header/row icons, a "Spilles av {actor}" cast line (phone when set, no "Lagres lokalt"), and the portrait overflow ellipsis.

DESIGN-010 is authoritative. Token resolution in the multi-entity tiles is out of scope. If the divider spacing or icons need a shared change beyond these two files, note it.
