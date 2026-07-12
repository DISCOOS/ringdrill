# Implement: collapsible master pane + auto-select first item (wide shell)

You are working in the RingDrill repository. A wide-shell feature: let the user collapse the master (list) pane so the detail pane fills the width, toggled from a single control that **takes the place of the detail's close-X**. References: `docs/design/proposals/collapsible-master-pane.md` and the mockup `docs/design/mockups/collapsible-master-pane.html`. Read `AGENTS.md` (esp. rule 9); the shell lives in `lib/views/shell/` (ADR-0028).

This composes with the coordinator's pane-local breakpoint (`design-010-coordinator-pane-local-breakpoint.md`): collapsing the master widens the detail pane, and the coordinator's `expanded` map-right layout then appears on its own — no coordinator change here.

**Wide layout only.** Narrow (no-rail, full-screen sheet) is untouched. No model/renderer/schema change (one ARB string for the tooltip).

## Behaviour (from the proposal)

* **No toggle in the rail or an AppBar of its own.** The toggle **replaces the detail's close-X in the wide (master/detail) layout**: `CupertinoIcons.sidebar_left` in the detail's leading slot. In a persistent master/detail there is no reason to "close" the selected item to an empty pane; you switch items or collapse the list.
* **The close-X stays in narrow.** There the detail is a full-screen sheet and the X still closes it. So the detail's leading is context-dependent: sidebar toggle when a `MasterDetailScope` is present, close-X otherwise. One **shared leading widget** used by all four detail screens (coordinator, station, roleplay, team-exercise), not per-screen ad hoc code.
* **Auto-select the first list item in the wide layout** so the detail always has content (and the toggle-in-place-of-X always has a host). Medium/expanded only; on tab switch select the new tab's first item; never override an explicit in-tab selection. Narrow does not auto-select.
* **Collapsed = rail + detail.** The master column (320/420) is not rendered; `MasterDetailPane` fills the width. The rail stays. Persisted across sessions (SharedPreferences). Stay-collapsed on tab switch.
* **Empty list** keeps its "Velg en øvelse" placeholder, and that placeholder also uses the shared leading (so the toggle is present there too).
* **Not on the Map tab** (`currentTab == 1`, which has no master/detail split) and not in narrow.

## Scope — four commits

### Commit 1. Collapse state, persistence, collapsed rendering

* `main_screen.dart` (`_MainScreenState`): `bool _masterCollapsed` initialised from `SharedPreferences` (default expanded), a toggle handler that flips + persists + `setState`s, gated on `useRail`. A new `AppConfig` key (e.g. `keyMasterPaneCollapsed`).
* `master_detail_scope.dart`: expose an `onToggleMaster` (`VoidCallback?`) on `MasterDetailScope` so the detail's leading can reach the toggle. (The collapsed *bool* need not flow to the detail — the toggle icon is the same either way.)
* `wide_shell.dart`: accept `masterCollapsed` + `onToggleMaster`, pass `onToggleMaster` into `MasterDetailScope`. When collapsed, render the left region as the rail only (skip the `masterWidth` column) and let the `Expanded` `MasterDetailPane` take the rest. Move the docked mini player to span the **full bottom width** when collapsed (it currently spans only rail + master); keep today's placement when expanded. Optional light `AnimatedSize` on the master column — no heavy animation.

Commit: `feat(shell): collapsible master pane state, persistence and collapsed layout`.

### Commit 2. Shared detail leading — sidebar toggle in master/detail, close in narrow

* New shared widget (e.g. `lib/views/shell/master_detail_leading.dart`, `MasterDetailLeading`): if `MasterDetailScope.maybeOf(context)?.onToggleMaster != null`, render an `IconButton(CupertinoIcons.sidebar_left)` that calls it (tooltip from ARB); otherwise render the existing close-X (`Icons.close`) with the screen's supplied `onClose` (pop / close sheet). Import `package:flutter/cupertino.dart`; confirm `cupertino_icons` resolves (add to `pubspec.yaml` if needed).
* Adopt it as the `leading` in all four detail screens — `coordinator_screen.dart`, `station_screen.dart`, `roleplay_screen.dart`, `team_exercise_screen.dart` — replacing each hardcoded `IconButton(Icons.close …)`. Preserve the current narrow close behaviour via the widget's `onClose`. Also give the wide **empty-pane** placeholder (`_emptyPaneBuilderForCurrentTab`) a minimal top bar with the same leading.
* ARB: add the toggle tooltip to `app_en.arb` + `app_nb.arb` (e.g. `masterPaneToggle` → "Show/hide list" / "Vis/skjul liste"); run `make i18n` (not `make build`). Two languages, kept equivalent.

Commit: `feat(shell): detail sidebar toggle replaces the close button in the wide layout`.

### Commit 3. Auto-select the first list item (wide)

* Add a hook to `ScreenController` (`page_widget.dart`), e.g. `ContextSheetTarget? firstDetailTarget(BuildContext)`, returning the active tab's first list item as a target (null when the list is empty). Implement it for the four tab controllers (Øvelser/Poster/Spill/Lag).
* In `main_screen.dart`, in the wide layout: when the shared target is null or belongs to a different tab than `_currentTab`, set it to the current tab's `firstDetailTarget`. Trigger on tab switch and when a tab's list first has items. Never override an explicit selection within the same tab; never auto-select in narrow.

Commit: `feat(shell): auto-select the first list item in the wide layout`.

### Commit 4. Tests

* Toggling flips the layout: expanded shows the master column; collapsed hides it and the detail widens; the `sidebar_left` leading is present in the detail in both states.
* The preference round-trips through `SharedPreferences`.
* Detail leading is the sidebar toggle under a `MasterDetailScope` and the close-X without one (narrow).
* Auto-select: entering a wide tab with a non-empty list selects the first item; switching tabs selects the new tab's first; an explicit selection is not overridden; an empty list shows the placeholder (with the toggle leading).
* No toggle / no collapse concept on the Map tab and in narrow.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(shell): cover collapse, persistence, detail leading and auto-select`.

## Ground rules

* Wide-layout only; narrow keeps the close-X and no auto-select.
* Exactly one toggle, in the detail leading — nothing in the rail or master AppBar.
* One shared leading widget; do not fork close/toggle logic across the four detail screens.
* Two languages kept equivalent; ARB edit means `make i18n`, not `make build`.
* Behaviour-preserving when expanded and uncollapsed, apart from the leading becoming the toggle and the first item being auto-selected.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke (wide window): opening a tab auto-selects the first item; the detail's leading is the `sidebar_left` toggle (no close-X); tapping it collapses the list so the detail fills the width (coordinator reaches its map-right layout), tapping again restores it; state survives an app restart; switching tabs shows the new tab's first item. Map tab has no toggle. Narrow window: the close-X is unchanged, no auto-select, no collapse.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `lib/utils/app_config*`, `test/…` (and `pubspec.yaml` only if `cupertino_icons` had to be added).
5. Clean tree.

## Deliverables

Conventional Commits (English) on the working branch, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The proposal and mockup are authoritative. Exactly one toggle, in the detail leading, wide layout only; the close-X remains in narrow.
