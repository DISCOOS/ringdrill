# Implement: collapsible section cards (Post/Spill/Coordinator left column)

You are working in the RingDrill repository, on `design-010`. Make the shared titled+bordered section cards collapsible, with the collapsed/expanded state remembered per section type. Read `AGENTS.md` rule 9.

**Views only.** No model/renderer/schema change (one small persisted preference store).

## Goal

The titled section cards (built on `CardSectionHeader` — `lib/views/widgets/card_section_header.dart`) are used across the Post and Spill viewers and the coordinator left column: Postbeskrivelse (`NarrativeRollupCard`), Personer, Tidsplan / Når aktiv (`ScheduleCard`), and the inline titled cards in `station_screen.dart` / `roleplay_screen.dart`. The user wants to **fold each card open/closed** — established desktop UX, valuable on smaller panes. The **`PlayerStatusCard` is excluded** (never collapsible).

The collapsed state is **remembered per section type across sessions** (e.g. "Tidsplan" stays collapsed until reopened), defaulting to expanded.

## Behaviour

* **Header cards** (`CardSectionHeader`-based): the header becomes the collapse handle — tapping it toggles the card body, with a rotating chevron on the header showing state and an animated expand/collapse (`AnimatedSize` or similar). The header, icon, title and any trailing count/action stay visible when collapsed.
* **Position card** (`PositionCardShell`, `lib/views/widgets/position_card.dart`) — it has no `CardSectionHeader`; its content is the map thumbnail + legend + a bottom coordinate bar (`barLabel` "Posisjon" + `barChild` UTM + `barTrailing` chevron that opens the editor). Collapsing it **hides the thumbnail, overlay actions and legend, keeping only the coordinate bar** (the "UTM/Posisjon" row). The collapse handle is a **single rotating chevron at the leading edge of the coordinate bar** (the bar is the always-visible part, so the handle never moves): up = collapse the map, down = show the map. It is its own tap target and must **not** trigger the card's editor-open tap; keep `barTrailing`/the bar body opening the position editor exactly as now. Mockup: `docs/design/mockups/collapsible-position-card.html`.
* Persist per section type; default expanded; applies wherever these cards render (Post, Spill, coordinator left column).

## Implementation sketch

1. **Persisted store + shared wrapper.** A small `CollapsibleSectionStore` keyed by a stable `sectionId` string (not the localized title), backed by `SharedPreferences` (one namespaced map, or per-key), default expanded. A shared `CollapsibleSectionCard` widget wrapping `Card` + a tappable `CardSectionHeader` (chevron + rotation) + an animated collapsible body, reading/writing the store by `sectionId`.
2. **Migrate the header cards** to `CollapsibleSectionCard`, each with a stable `sectionId` (e.g. `description`, `persons`, `schedule`, `activeSchedule`, plus the roleplay context/identity/marker cards if they use `CardSectionHeader`). Grep `CardSectionHeader(` and `ScheduleCard(` to enumerate the full set; migrate all of them (Post, Spill, and the shared `ScheduleCard`/`NarrativeRollupCard`). **Do not** touch `PlayerStatusCard`.
3. **`PositionCardShell`** gains a persisted collapsed mode (same store, its own `sectionId` e.g. `position`) that hides thumbnail/overlay/legend and keeps the coordinate bar, with the collapse affordance described above.

Keep the same section order across surfaces (Kengu: unchanged). Behaviour when expanded is identical to today apart from the header now being tappable and carrying a chevron.

## Scope — four commits

### Commit 1. Collapse store + shared `CollapsibleSectionCard`

New `collapsible_section_card.dart` + the persisted store (+ `AppConfig` namespace/key). No call sites migrated yet.

Commit: `feat(views): collapsible section card with a remembered open/closed state`.

### Commit 2. Migrate the header-based section cards

`ScheduleCard`, `NarrativeRollupCard`, the Personer section, and the inline titled cards in `station_screen.dart` / `roleplay_screen.dart` adopt `CollapsibleSectionCard` with stable `sectionId`s. `PlayerStatusCard` untouched.

Commit: `feat(views): fold the titled section cards open and closed`.

### Commit 3. Collapsible position card

`PositionCardShell` collapses to the coordinate bar (map/legend/overlay hidden), persisted, via a leading rotating chevron on the coordinate bar — separate from the editor-opening `barTrailing`/bar tap (see mockup `collapsible-position-card.html`).

Commit: `feat(views): collapse the position card to its coordinate row`.

### Commit 4. Tests

* Tapping a section card's header collapses its body and hides it; the header (title/chevron) stays; tapping again expands.
* Collapsed state round-trips through `SharedPreferences` (persists across a rebuild) and is keyed per section type (collapsing "Tidsplan" does not collapse "Personer").
* The position card collapses to just the coordinate bar (thumbnail gone, UTM row and its editor-open chevron still present).
* `PlayerStatusCard` has no collapse handle.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover collapsible section cards, persistence and the position card`.

## Ground rules

* Views + test only. One shared wrapper + one store — do not fork collapse logic per card.
* Persist per stable `sectionId`, never the localized title.
* `PlayerStatusCard` is never collapsible. Section order unchanged.
* Behaviour-preserving when expanded, apart from the tappable header + chevron.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: in a Post/Spill viewer, fold Tidsplan/Postbeskrivelse/Personer closed — headers stay, bodies hide; reopen; restart the app → the folded sections are still folded. Collapse the position card → only the UTM/Posisjon row remains, its editor chevron still works, and the collapse control re-expands it. The status card has no fold control.
4. `git diff --stat` touches `lib/views/…`, `lib/utils/app_config*`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). One shared collapsible card + store; every titled section card except the status card folds; the position card collapses to its coordinate row; state remembered per section type.
