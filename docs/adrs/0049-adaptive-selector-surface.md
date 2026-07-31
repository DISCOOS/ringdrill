---
status: accepted
date: 2026-07-10
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0049: Selectors adapt to window size behind one picker primitive — bottom sheet on compact, dialog on medium/expanded

## Context and problem statement

The app picks entities in several places: swapping the bound exercise, choosing a marker's cast (Actor), and — new in DESIGN-009/ADR-0047 — choosing or re-pointing a roleplay's **Post** and its portrayed **Person**. These selectors are inconsistent about their surface. The exercise and cast pickers are always bottom sheets (via `showRingdrillActionSheet`, ADR-0027); the roleplay Post and Person pickers are plain `SimpleDialog`s opened with `showDialog`, always dialogs regardless of window size. Some carry a search field (the cast picker), most do not. The result feels arbitrary: the same *kind* of task (pick one from a list) presents as a sheet in one place and a bare dialog in another.

Forms already resolved this exact split: [ADR-0030](./0030-wide-screen-master-detail-layout.md) promotes an editor to a modal **dialog** on medium/expanded and keeps it a **bottom sheet** on compact, routed through `openFormSurface`. Selectors have no equivalent, so each call site chose a surface ad hoc.

## Decision drivers

* One predictable rule for where a "pick one from a list" surface appears, matching the forms rule already in force (ADR-0030).
* Reuse existing chrome — the Ringdrill sheet surface (ADR-0027) and the form dialog shell — rather than a third bespoke style. A selector dialog should not look like a bare `SimpleDialog`.
* Long lists (markers, persons, posts, exercises) need a search field; short ones should not carry a needless one.
* Minimise duplicated selector code across call sites.

## Considered options

* **A: One adaptive picker primitive** — a single `showRingdrillPicker` that renders a bottom sheet on compact and a dialog on medium/expanded (`WindowSizeClass.hasMasterDetail`), with an optional (threshold-gated) search field, and a consistent title/list/selected-check body. (chosen)
* **B: Always a bottom sheet**, on every window size.
* **C: Always a dialog**, on every window size.
* **D: Leave each call site as it is.**

## Decision outcome

Chosen option: **A**, because it applies the same window-size rule selectors' sibling (forms) already uses, reuses both existing surfaces, and removes the ad hoc per-call-site choice — while adding search where lists are long.

The primitive lives beside the existing sheet helpers and is the single entry point for one-of-a-list selection. Compact routes to the existing `showRingdrillActionSheet` chrome; medium/expanded routes to a dialog reusing the form dialog's rounded chrome (not `SimpleDialog`), width-capped for a list (~480) and height-capped (~70% viewport), with a title header, a close affordance, and — when the list exceeds a small threshold — a search field styled like the rest of the app (the cast picker's existing filter UX, generalised). Titles read "Velg …" ("Velg post", "Velg person", "Velg øvelse", "Velg markør").

### Consequences

* Good: selectors behave consistently and predictably, matching ADR-0030's forms rule; the arbitrary sheet-vs-dialog split disappears.
* Good: the roleplay Post/Person `SimpleDialog`s are replaced with the shared, searchable, properly-themed surface; search reaches every long-list selector.
* Good: one place owns selector chrome, search and the adaptive switch; call sites shrink to data + item builder.
* Bad: a search field inside a bottom sheet raises the keyboard, so the compact path needs viewport-inset handling and a test — one more thing to get right.
* Bad: the "show search only past N items" threshold is a small per-selector rule to tune.
* Bad: a migration touches four call sites at once.

## Pros and cons of the options

### Option A — one adaptive picker primitive
* Good: consistent with forms (ADR-0030); reuses ADR-0027 sheet chrome and the form dialog shell; search where it helps; least duplicated code long-term.
* Bad: needs keyboard-in-sheet handling; a threshold rule per selector; a multi-call-site migration.

### Option B — always a bottom sheet
* Good: simplest; one surface; matches most of today's selectors.
* Bad: a bottom sheet on a wide desktop window wastes the screen and diverges from forms, which are dialogs there — reintroducing an inconsistency, just the other way.

### Option C — always a dialog
* Good: one surface; dialogs read well on wide.
* Bad: a modal dialog on a phone is worse than a bottom sheet for reach and dismissal; regresses the compact experience the sheets were chosen for.

### Option D — leave as is
* Good: no work.
* Bad: the arbitrariness the change set out to fix remains; new selectors keep choosing ad hoc.

## Links

* Related ADRs: [ADR-0027](./0027-unified-bottom-sheet-chrome.md) (sheet chrome reused on compact), [ADR-0030](./0030-wide-screen-master-detail-layout.md) (forms → dialogs on medium/expanded; same window-size rule), [ADR-0026](./0026-sheet-based-context-navigation.md), [ADR-0031](./0031-row-edit-affordances.md)
* Related code: `lib/views/widgets/ringdrill_sheet.dart` (`showRingdrillActionSheet`, `showRingdrillFormDialog`), `lib/views/shell/window_size_class.dart`, `lib/views/drill_player/exercise_picker_sheet.dart`, `lib/views/widgets/cast_picker_sheet.dart`, `lib/views/roleplay_form_screen.dart` (`_showStationPicker`, `_showPersonPicker`)
* Mockup: [`docs/design/mockups/adaptive-selector-picker.html`](../design/mockups/adaptive-selector-picker.html)
* Prompt: `docs/prompts/adr-0049-adaptive-selector-picker.md`
