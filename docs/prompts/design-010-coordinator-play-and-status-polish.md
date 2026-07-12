# Implement DESIGN-010 follow-up: coordinator play-mode layout + status-card polish

You are working in the RingDrill repository, on `design-010`. One combined follow-up with three connected parts: (A) a visual polish on the just-landed player status card (`player_status_card.dart`), (B) reworking the **coordinator** play-mode body so it uses the same status-card + schedule-card composition as the players in every window size, plus a proper compact/medium/expanded layout, and (C) fixing a stray "Rekkefølge" reorder label that shows during play (a real bug in `ReorderableSection` today).

References: `docs/design/010-inline-preview-and-resolve-scope.md`, and the mockups `docs/design/mockups/running-status-post-lag.html` (the status card's two states) and `docs/design/mockups/coordinator-play-breakpoints.html` (the coordinator layout across the three window classes). Read `AGENTS.md` rule 9.

**No model, renderer, or schema change.** Layout / styling / widget-composition only.

---

## Part A — Status-card polish (`player_status_card.dart`)

### Fix 1. Consistent padding across surfaces

The status card is too **wide** on the **Coordinator** surface — nearly edge-to-edge, tighter than the Post/Lag/Spill players. Give the card the **same comfortable horizontal padding on every surface** (Coordinator, Post, Lag, Spill). Prefer **one shared value** — a default padding baked into `PlayerStatusCard`, or one constant applied at all call sites — so they can't drift; don't double up if a surface already pads. Part B removes the coordinator's bespoke placement, which is the main cause here, so verify the card sits on the same left/right edge as the schedule card below it once B lands.

### Fix 2. Meta cell text: larger, numbers bold

The meta cell ("Runde N av M" / "ferdig HH:MM") is a bit small. Bump its size slightly, and **number-format** (bold) the numeric parts — the round number `N`, the total `M`, and the finish time `HH:MM` — while the words ("Runde", "av", "ferdig") stay regular weight. (Mockup: the meta words sit at ~13 px, the numbers/time bold and a step larger.)

### Fix 3. First row less dense

The card's first row (countdown + phase + meta) is a bit too dense. Increase its height / vertical padding for more reading room.

### Fix 4. Now/next cell bodies vertically centered

In the now/next strip, both cell bodies must be **vertically centered**. Today (visible in the Lag status) the left ("Nå") cell's badge+text is vertically centered while the right ("Neste") cell is top-aligned — they look misaligned. Center both cells' content vertically so they match, on all surfaces.

### Fix 5. Make the now/next cell icon optional

`PlayerStatusCell.icon` is `required` and `_buildCell` always renders it in the label row. Make it **nullable** (`IconData?`) and render the leading `Icon` (and its spacer) only when non-null. The Post/Lag/Spill cells keep passing their role icons — this only lets a surface omit the icon. (Part B's coordinator cells use it: no icon there.)

---

## Part B — Coordinator play-mode: shared composition + breakpoint layout

Two problems, one cause. The coordinator's top section is **bespoke**: a fixed-width status card (`_kHeroSidebarWidth = 260`) sitting beside an `IntrinsicWidth`, shrink-wrapped round table (`ScheduleTable(fillWidth: false)`), with a separate two-column body gated on raw pixel widths (`_kCoordinatorTwoColumnViewportWidth`/`…ContentWidth`, `_kCoordinatorWideTopSectionHeight`). That's why the coordinator's status card and schedule look different from the players (which use full-width `PlayerStatusCard` + `ScheduleCard`), and why the wide layout reads poorly in play mode.

### B1. Adopt the players' shared composition (all window sizes)

Make the coordinator's top section the **same two blocks the players use**, stacked, full width of their container:

* the coordinator's `PlayerStatusCard` (keep `_buildCombinedHeroCard` and its `_coordinatorNowNext` "Neste fase"/"Neste runde" cells — only its placement changes), then
* a `ScheduleCard(title: localizations.stationTimingCardTitle, headerLabel: localizations.schedule, …)` — the same card `TeamExerciseScreen._buildScheduleCard` and the Post/Spill viewers build.

Delete the bespoke path: `_kHeroSidebarWidth`, `_kCoordinatorWideTopSectionHeight`, `_kCoordinatorTwoColumnViewportWidth`, `_kCoordinatorTwoColumnContentWidth`; the wide/narrow branching in `_buildTopSectionContent`; and `_buildRoundTable`'s `IntrinsicWidth` + `fillWidth: false` shrink-wrap. Preserve the **copy-to-clipboard** affordances (the top-right copy `IconButton` in `_buildBody` and the long-press-to-copy gesture — move the long-press onto the schedule card if it was on the old table). Before-start (no `showHero`) still shows just the schedule card, full width.

### B2. Breakpoint layout via `WindowSizeClass`

Drive the layout off `WindowSizeClass.of(context)` (`lib/views/shell/window_size_class.dart`: compact `<600`, medium `600–839`, expanded `≥840`) instead of raw pixel constants. Match `docs/design/mockups/coordinator-play-breakpoints.html`:

* **compact** — one scrolling column: status card → schedule card → segment (`Poster | Lag | Kart`) → the selected list; the map is reached via the `Kart` segment (today's `_buildSingleColumnMap`). `includeMap: true`.
* **medium** — still stacked, but free to place the status card and schedule card **side by side** in the top row (both standard cards, no shrink-wrap) when they fit; segment (`Poster | Lag | Kart`) and list full width below. No permanent map pane — `Kart` stays in the segment. `includeMap: true`.
* **expanded** — a two-pane `Row`: a **left column at a fixed/capped width** (~380–420, sized for the compact stack — it must **not** grow) holding status card → schedule card → segment → the selected list; the **map fills all remaining width, full height** (clearly wider than the left column). The segment drops the map: `Poster | Lag` only (`includeMap: false`), since the map is always shown. The left column scrolls independently; the map pane is fixed. Live pins on the map keep the existing "current round assigns a team" accent test.

The map's live/normal pins, the segment's `_viewWithoutMap` stale-selection guard, and all rotation/copy behaviour are unchanged — only arrangement and which segment options show.

### B3. Now/next cell labels: "Neste", no icon

`_coordinatorNowNext` currently builds two cells labelled `statusNextPhase` ("Neste fase") / `statusNextRound` ("Neste runde") with `Icons.arrow_forward` / `Icons.repeat`. The long labels **plus** the icons overflow the half-card (the screenshots show "→ Neste fase · 1…"). Change both cells to label `localizations.nextLabel` ("Neste") and pass **no icon** (`icon: null`, via Fix 5). The phase/round distinction is carried by the value ("EVAL" vs "Runde 2") and the inline "· HH:MM" time, not the label. Leave the now/next cells on the players (Post/Lag/Spill) untouched — their labels are already short "Nå"/"Neste" and their role icons stay. The `statusNextPhase`/`statusNextRound` ARB keys may fall unused; leave them (no ARB change here).

---

## Part C — Hide the "Rekkefølge" label when nothing is reorderable (`reorderable_section.dart`)

`ReorderableSection`'s sort bar shows the muted `orderLabel` ("Rekkefølge"/"Order") whenever `itemCount >= 2`, regardless of whether anything is actionable. When `enabled` is false (an exercise is running) the reorder toggle is correctly hidden, but the bare `orderLabel` is left behind — a lonely "Rekkefølge" with nothing to do above the coordinator's station/team list during play (visible in the screenshots). It's a real bug in the current implementation.

Fix it generally: in `_buildHeader` (or `_buildSortBar`), when there is nothing actionable — `!widget.enabled && widget.sortActions.isEmpty` — collapse the whole header to `SizedBox.shrink()`, the same way `itemCount < 2` already does. The label must still show when there is a control to anchor (reorder enabled, or at least one sort action). This is a shared widget (Exercises, Stations, Coordinator all use it); the fix applies uniformly and is what every caller wants during play.

---

## Scope — one prompt, five commits

### Commit 1. Status-card polish

`player_status_card.dart` (+ the four call sites where padding is applied): one shared horizontal padding (Fix 1); larger meta with bold numeric parts (Fix 2); taller/less-dense first row (Fix 3); vertically centered now/next cell bodies (Fix 4); nullable, conditionally-rendered cell icon (Fix 5).

Commit: `fix(views): consistent padding, bolder meta, roomier first row and centered now/next on the status card`.

### Commit 2. Coordinator adopts the shared status + schedule composition

`coordinator_screen.dart`: `PlayerStatusCard` (full width) + `ScheduleCard` replace the bespoke sidebar card + shrink-wrapped table; delete the dead constants and the wide/narrow branching in `_buildTopSectionContent`/`_buildRoundTable`; keep `_buildCombinedHeroCard`/`_coordinatorNowNext` and the copy affordances. Also apply B3: `_coordinatorNowNext`'s two cells become `nextLabel` ("Neste") with no icon.

Commit: `refactor(views): coordinator reuses the shared status and schedule cards`.

### Commit 3. Coordinator compact/medium/expanded layout

`coordinator_screen.dart`: `WindowSizeClass`-driven body per B2 — map as a fixed right pane in expanded (segment `Poster | Lag`), stacked in compact/medium (segment keeps `Kart`).

Commit: `feat(views): coordinator play-mode layout for compact, medium and expanded`.

### Commit 4. Reorder header — hide when nothing is actionable

`reorderable_section.dart` (Part C): the sort bar collapses to `SizedBox.shrink()` when `!enabled && sortActions.isEmpty`, so the bare "Rekkefølge" label no longer shows above the coordinator's lists during play.

Commit: `fix(views): hide the reorder label when nothing is reorderable`.

### Commit 5. Tests

* Status card: same horizontal padding on the coordinator as on a player (left-edge inset matches — locks the too-wide regression); meta numeric parts render bold; now/next cell bodies vertically centered (both cells share a vertical center); a cell built with `icon: null` renders no leading icon.
* Coordinator: uses `ScheduleCard` (not a bare `fillWidth: false` `ScheduleTable`); at expanded width the map pane is shown and the segment has **no** `Kart` option; at compact/medium the `Kart` segment is present; the running now/next cells read "Neste" (not "Neste fase"/"Neste runde").
* `ReorderableSection`: with `enabled: false` and no `sortActions`, the header (and its `orderLabel`) is absent; with `enabled: true` (or a sort action) it is present.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover status-card polish, coordinator layout and reorder-label fixes`.

## Ground rules

* Views + test only (`reorderable_section.dart` is under `lib/views/widgets/`). No model, renderer, ARB, or schema change (bolding is styling; reuse existing l10n keys — `stationTimingCardTitle`, `schedule`, `nextLabel` — add none; `statusNextPhase`/`statusNextRound` may fall unused but stay).
* One shared padding value; don't hard-code drifting numbers. Layout thresholds come from `WindowSizeClass`, not new pixel constants.
* Behaviour-preserving otherwise: the card's two states, the rotation/copy behaviour, and the map's live pins are unchanged — only padding, sizing, weight, alignment, widget composition, and arrangement per window size.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: status card has the same comfortable side margins on Coordinator, Post, Lag, Spill; meta reads larger with bold numbers/time; first row has more breathing room; now/next cells both vertically centered. Coordinator: status card + schedule card match the players; the running now/next cells read "Neste · HH:MM" with no icon (no overflow, no "Neste fase"/"Neste runde"); **compact** stacks with a `Kart` segment; **medium** stacks (status/schedule may be side by side) with a `Kart` segment; **expanded** shows the map as a wide fixed right pane with a `Poster | Lag` segment and a capped left column that doesn't stretch. During play there is no stray "Rekkefølge" label above the station/team list.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). DESIGN-010 and the two mockups are authoritative. If any part needs restructuring beyond composition/arrangement (e.g. the copy-button placement reads badly over the expanded map pane), note it rather than expanding scope silently.
