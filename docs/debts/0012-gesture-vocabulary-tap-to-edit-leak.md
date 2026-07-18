---
status: open
severity: medium
discovered: 2026-07-18
resolved: null
related_adrs: ["ADR-0026", "ADR-0031"]
---

# DEBT-0012: Tap-to-edit leaks past the ADR-0026/0031 gesture vocabulary

## What

ADR-0026 and ADR-0031 together define one gesture vocabulary: in rows and
lists, tap opens a read surface, edit is reached through swipe
(`Dismissible endToStart`) or `onLongPress`, and `Icons.edit` lives only in a
detail screen's `AppBar.actions`. That rule is only partly enforced. Several
list-like surfaces and detail views wire tap directly to an edit form, so
"tap" means read in some places and edit in others. On top of that,
"tap opens a surface" (a position card opening a map/location) sits in the same
gesture as tap-to-edit, so the two are visually indistinguishable to the user.

## Where

Tap wired straight to an edit form, against the tap-is-read rule:

* `lib/views/widgets/locations_section.dart:102` — `onTap: () => _openForm(...)`
  on each location row.
* `lib/views/widgets/persons_section.dart:140` — `onTap: () => _openForm(...)`
  on each person row.
* `lib/views/station_screen.dart:426` — `onTapSection: (id) => _editStation(...)`;
  tapping a section row in the detail view opens its editor.

Tap opens a surface (map/location), conflated with tap-to-edit:

* `lib/views/widgets/position_card.dart:18-20` — the whole card is one `InkWell`
  driving `onTap`; the chevron is the only signal for what the tap does.

Rows that do follow the rule, for contrast:

* `lib/views/station_list_view.dart` and `lib/views/roleplays_view.dart` —
  `Dismissible` swipe + `ExpandableTile.onLongPress`, tap opens read detail.

## Why it is debt

The vocabulary is codified (ADR-0026 "tap is reserved for read", ADR-0031
"row edit is swipe/long-press, pencil is AppBar-only") but not applied
uniformly. A contributor copying `locations_section` learns the wrong pattern
and spreads tap-to-edit further; a contributor copying `station_list_view`
learns the right one. The user-facing cost is that the same gesture (a single
tap) produces read in one list and an edit form in the next, and "open the
location on a map" cannot be told apart from "edit this". This is not a crash,
so it is debt rather than a bug, but it grows every time an editable list
section is added by analogy to the wrong precedent.

## Suggested fix

Direction agreed 2026-07-18: reframe the codified invariant rather than extend
the old one. Change ADR-0031's core rule from "tap is reserved for read" to
"swipe and long-press always edit; tap opens the row's primary surface." The
primary surface is a read view in browse contexts (station list) and the editor
itself in authoring contexts where the child entity has no separate read view
(location/person rows inside the station form). This keeps tap-to-edit where
editing is the natural primary action instead of hiding it behind a gesture,
and makes "swipe/long-press edits" a universal, transferable gesture.

1. Draft an ADR-0031 amendment (or a superseding ADR) that restates the
   invariant as above and names the authoring sub-sections explicitly in the
   "Sites bound by this rule" table instead of leaving them under "Out of
   scope."
2. Add `Dismissible(endToStart)` + `onLongPress` to the rows in
   `locations_section.dart` and `persons_section.dart` as redundant edit paths,
   and keep the existing tap-to-`_openForm` as the primary action.
3. Reclassify `position_card` as an "open a surface" affordance, not edit. Make
   the chevron read as "open" so it is not mistaken for a pencil, and note the
   distinction in the card doc.
4. Leave `station_list_view` and `roleplays_view` as they are; they already
   satisfy the reframed rule.

## Notes for the ADR-0031 amendment

Enough material to write the amendment (or a superseding ADR) later without
re-deriving it. This section is the source; the ADR is the ratified copy.

### Restated invariant

Replace ADR-0031's "tap is reserved for read" premise with:

1. Swipe (`Dismissible endToStart`, `confirmDismiss` returning `false`) and
   `onLongPress` **always mean edit**, on every editable row, in both browse
   and authoring contexts.
2. **Tap opens the row's primary surface.** The primary surface is whatever the
   row is fundamentally for:
   * Browse context (a row in a list whose job is to navigate): the primary
     surface is a read/detail view. Edit is secondary, so it lives on
     swipe/long-press and on the detail screen's `AppBar` pencil.
   * Authoring context (a child-entity row inside a form, where the entity has
     no separate read view): the primary surface **is** the editor. Tap opens
     it directly. Swipe/long-press are redundant accelerators for the same
     edit, present only so the gesture is uniform across the app.
3. `Icons.edit` stays `AppBar.actions`/overflow only (unchanged from ADR-0031).
4. "Open a surface" is not "edit." A row whose tap opens a map or location
   (`position_card`) is a browse tap, and its trailing chevron must read as
   "open," never as a pencil.

The invariant that is now universal is gesture-for-edit (swipe/long-press),
not the meaning of tap. That is the one-line change from ADR-0031.

### Decision drivers (delta from ADR-0031)

* ADR-0031 assumed every editable row also has a read surface that tap can own.
  Child-entity rows in the station form break that assumption: their detail is
  the form, so "tap = read" degenerates to "tap does nothing useful before you
  edit."
* Hiding the primary action of an authoring row behind long-press regresses
  discoverability, which ADR-0031 already names as its main con.
* A gesture ("swipe/long-press edits") that holds everywhere is more learnable
  than a rule ("tap reads") that only holds where a read surface exists.

### Sites bound by the amended rule

| Site | Context | Tap | Swipe / long-press |
|------|---------|-----|--------------------|
| `station_list_view.dart` rows | browse | opens `station_screen` (read) | edit — already present |
| `roleplays_view.dart` rows | browse | opens read detail | edit — already present |
| `locations_section.dart` rows (`:102`) | authoring | opens editor (`_openForm`) — keep | **add** `Dismissible` + `onLongPress` → same `_openForm` |
| `persons_section.dart` rows (`:140`) | authoring | opens editor (`_openForm`) — keep | **add** `Dismissible` + `onLongPress` → same `_openForm` |
| `station_screen.dart` section rows (`:426`) | authoring | jumps into the station form at that section (`_editStation`) — keep | optional; the whole screen is already the read surface, so long-press adds little |
| `position_card.dart` (`:18-20`) | browse | opens map/location surface — keep | none; reclassify chevron as "open," not a pencil |

Out of scope, unchanged: `variables_section.dart` (swipe is delete, not edit;
tap toggles expansion; editing is inline), chart cells, table cells, map
markers, brief-view sections, settings rows.

### Consequences (delta)

* Good: one edit gesture that works everywhere; tap keeps the obvious primary
  action in authoring flows; the map-open case stops masquerading as edit.
* Cost: swipe/long-press become redundant where tap already edits. Accepted on
  purpose, for muscle-memory transfer.
* Migration: additive. No existing tap behaviour is removed, so no relearning
  and no route changes.

### Points to settle when writing the ADR

* Amendment to ADR-0031 vs a new superseding ADR. The core premise changes, so
  a superseding ADR may be cleaner, with ADR-0031 marked superseded.
* Whether `station_screen` section rows get long-press at all, or stay tap-only
  given the screen is itself the read surface.
* Exact "open" affordance for `position_card` (chevron variant vs a small map
  glyph) so it is visually distinct from an edit row.
* Confirm swipe is feasible on the `Card`/`InkWell`-wrapped section rows before
  committing to it in the table.

## Links

* Related ADRs:
  * [ADR-0026](../adrs/0026-sheet-based-context-navigation.md) — tap-opens-sheet, tap is read.
  * [ADR-0031](../adrs/0031-row-edit-affordances.md) — swipe/long-press for edit, pencil AppBar-only.
* Related code: `lib/views/widgets/locations_section.dart`,
  `lib/views/widgets/persons_section.dart`, `lib/views/station_screen.dart`,
  `lib/views/widgets/position_card.dart`, `lib/views/station_list_view.dart`.
