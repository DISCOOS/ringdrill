# Proposal: collapsible master pane in the wide shell

Status: Proposed. Extends ADR-0030 (wide-screen master/detail) and DESIGN-005/006. Motivated by the DESIGN-010 coordinator work: in the wide shell the master list and the detail pane compete for width, and a content-rich detail (the coordinator, which wants its own map pane) ends up cramped on anything short of a very wide screen.

## Problem

`WideShell` renders three fixed regions side by side: the navigation rail (72), the master pane (320, or 420 when expanded), and the detail pane (the `Expanded` remainder). On a typical laptop window (~1000–1250) the detail pane is only ~430–730 wide. That is enough to read an exercise, but it leaves no room for the coordinator's wide map-right layout, and the master list — the "main" view — eats space the user often does not need once they are working inside one exercise.

Desktop tools with the same master/detail shape (Confluence, Linear, VS Code, Slack) all solve this the same way: let the user **collapse the list** to focus the detail, and bring it back with one click.

## Proposal

Add a **collapse toggle** to the master pane. Collapsed, the master (the 320/420 list column) is hidden and the detail pane fills that width; the navigation rail stays. This composes with the coordinator's pane-local breakpoint (the separate `…-pane-local-breakpoint` fix): a collapsed master widens the detail pane, which pushes the coordinator into its `expanded` map-right layout automatically — no new coordinator code.

The toggle does not get its own home in the chrome. Instead it **takes the place of the detail's close-X**: in a persistent master/detail there is no reason to "close" the selected item back to an empty pane — you switch items or collapse the list. So in the wide layout the detail's leading control becomes the sidebar toggle rather than a close button. For that to hold, the detail pane must always have content, which means **auto-selecting the first item** of the active tab's list in the wide layout.

State lives in `_MainScreenState` (next to `_currentTab`), is threaded into `WideShell`, and is persisted like other view preferences (SharedPreferences). Purely a wide-layout concern; the narrow layout is untouched.

## Decided behaviour

1. **Collapsed appearance: rail only.** Collapsed = rail (72) + detail. No thin content strip — the rail already carries tab context, and it keeps the model simple.

2. **One toggle, in the detail's leading slot (where the close-X was): `CupertinoIcons.sidebar_left`** (from `package:flutter/cupertino.dart`; `cupertino_icons` is a default dependency). A single toggle, not two directional glyphs — the Claude/Notion pattern. It replaces the detail's close-X **in the wide layout only**; there is no toggle in the rail or the master AppBar. The button is always present because the detail pane always shows something.

3. **The close-X is removed in the wide layout, kept in narrow.** In narrow the detail is a full-screen sheet and the X still closes it. So the detail's leading control is context-dependent — sidebar toggle when hosted in master/detail (`MasterDetailScope` present), close-X otherwise. Implement via one shared leading widget used by all four detail screens (coordinator, station, roleplay, team-exercise) rather than editing each ad hoc.

4. **Auto-select the first list item in the wide layout.** In medium/expanded, whenever a tab's list is non-empty and nothing appropriate is selected, select the first item so the detail is populated. On tab switch, select the first item of the new tab. Never override an explicit user selection within the same tab. Narrow does not auto-select (the user taps a row to open the sheet).

5. **Empty list keeps its own detail placeholder** ("Velg en øvelse"), and that placeholder also carries the sidebar toggle in its leading, so behaviour is uniform whether or not an item is selected.

6. **Tab switching while collapsed: stay collapsed.** Collapse is a view preference, not auto-magic; switching tabs keeps it collapsed (and, per 4, auto-selects the new tab's first item so the detail is populated when re-expanded).

7. **Persist across sessions: yes.** Remember collapsed/expanded like the other shell view prefs (SharedPreferences).

8. **Available in both medium and expanded** (whenever `useRail` is active). Collapsing is most useful in medium, where the detail is tightest.

Mockup: `docs/design/mockups/collapsible-master-pane.html` (variant A: expanded, collapsed, and the empty-list state, with the `sidebar_left` toggle drawn in the detail leading).

## Out of scope

Auto-collapse heuristics (e.g. collapse on selecting an item), animation polish beyond a simple width transition, and any narrow-layout change (the close-X stays there). The collapse is a manual, remembered toggle.
