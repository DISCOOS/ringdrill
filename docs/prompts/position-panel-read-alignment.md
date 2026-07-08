# Align the read-only position panels with the PositionCard layout

You are working in the RingDrill repository. Follow-up to
`docs/prompts/position-card-reflow.md`, which reflowed the **edit** surfaces
(`PositionFormField` → `lib/views/widgets/position_card.dart`). This prompt
brings the **read-only detail** panels into the same visual language. Read
`AGENTS.md` rule 9 (test-loop discipline) and
[ADR-0031](../adrs/0031-row-edit-affordances.md).

**Visual reference:** `docs/design/mockups/position-card.html`, section **C**
(Station detail + RolePlay detail) and the "Delt komponent" note.

## The problem

`StationPositionPanel` (`lib/views/widgets/station_position_panel.dart`) and
`RolePositionPanel` (`lib/views/widgets/role_position_panel.dart`) still render
the old layout: a top label row (`position` label + `Spacer` + a floating
`Icons.place` pin + right-aligned `PositionWidget`) with the mini-map below.
Against the new `PositionCard`, the floating pin reads as orphaned and the
coordinate placement is inconsistent. The two panels feed every station/role
detail surface (`station_screen.dart`, `station_list_view.dart`,
`program_view.dart`, `coordinator_screen.dart`, `roleplay_screen.dart`,
`roleplays_view.dart`), so fixing the two widgets updates all of them.

## Target (per mockup section C)

Both panels become a bordered card: the mini-map on top, a coordinate bar
below (muted `position` label on the left, `PositionWidget` on the right, a
trailing `chevron_right`). No floating pin in a separate header row. The bar's
chevron signals "tap opens a surface" (ADR-0031) — but this stays **read-only**:
the tap opens the existing interactive map view (the `StationMiniMap` /
`RoleMiniMap` full-screen/bottom-sheet), **not** the picker.

## What changes

1. **Shared shell.** The pick card (`PositionCard`, `card` variant) and both
   read panels now share one stacked layout — three call sites, so extract the
   shell instead of duplicating it (the app's established pattern for styling
   repeated 3+ places). Add e.g. `PositionCardShell` in
   `lib/views/widgets/position_card.dart` (or a sibling): a bordered
   `ClipRRect` containing a thumbnail slot (with an optional top-right
   `overlayActions` `Stack`) above a coordinate bar (optional leading `label`,
   a coordinate/child slot, a trailing widget), wrapped in one `InkWell(onTap)`.
   Refactor `PositionCard`'s `card` path to build on it; keep the `row` variant
   as-is (it is station-form-only).
2. **`StationPositionPanel`** renders the shell: `StationMiniMap` as the
   thumbnail, the `position` label + `PositionWidget` (unchanged, `wrapped:
   false`) in the bar, `chevron_right` trailing, `onTap` = whatever opens the
   interactive map today (reuse `StationMiniMap`'s existing tap path; do not
   invent a new route). Keep the no-position fallback (`noLocation` text, no
   map). Drop the old top label row and the floating `Icons.place`.
3. **`RolePositionPanel`** does the same with `RoleMiniMap` and the role label.

## Out of scope (do not touch)

- The coordinate text/order stays exactly as `UtmWidget`/`PositionWidget`
  render it today. No format change.
- The picker (`MapPickerScreen`) and the edit surfaces from the previous prompt.
- The interactive map behavior itself (`StationMiniMap`/`RoleMiniMap` internals,
  base-layer switch, markers) — only how the panel frames them changes.
- The "Post: …" station-reference chip above the RolePlay panel — leave it.

## Ground rules

- No raw English in widgets; reuse `position` / `noLocation`. This change should
  need **no new ARB keys**; if you add one, run `make i18n`, never hand-edit
  `app_localizations*.dart`.
- Reuse the existing mini-map tap/open path; do not add a new navigation route.
- Commit messages in English, conventional-commits.
- **Test-loop discipline (rule 9):** per commit `flutter analyze` +
  `flutter test test/views/`; full `flutter test` + `dart build cli` **once at
  the end**. Each commit lists its files and ends with a clean `git status`.

## Scope

Two commits.

### Commit 1. Extract the shared shell

Add `PositionCardShell` and refactor `PositionCard`'s `card` variant onto it. No
behavior change to the edit surfaces — same rendering, same picker tap.

Files: `lib/views/widgets/position_card.dart` (+ sibling if you split the
shell), its test. `flutter analyze` + `flutter test test/views/`. Commit:
`refactor(views): extract PositionCardShell shared by the position card`.

### Commit 2. Reframe the read panels

Rebuild `StationPositionPanel` and `RolePositionPanel` on the shell: mini-map
thumbnail, coordinate bar with label + `PositionWidget` + chevron, read-only tap
to the interactive map, no floating pin. Keep the no-position fallback.

Files: `lib/views/widgets/station_position_panel.dart`,
`lib/views/widgets/role_position_panel.dart`, their tests. `flutter analyze` +
`flutter test test/views/`. Commit:
`refactor(views): station/role position panels on the shared card shell`.

### Final gate

`flutter analyze`, full `flutter test`, `dart build cli` once. Fix or flag any
failure. Confirm `git status` clean.

## Acceptance

- Station and RolePlay detail panels render as a card (mini-map on top,
  coordinate bar below, trailing chevron); no floating pin in a header row.
- Tapping a panel still opens the interactive read-only map, not the picker.
- No-position stations still show the `noLocation` fallback without a map.
- Coordinate text unchanged; no new ARB keys (or `make i18n` run if any added).
- `flutter analyze` clean, `flutter test` green, CLI builds.
