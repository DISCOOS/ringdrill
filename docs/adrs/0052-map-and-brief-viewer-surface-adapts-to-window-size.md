---
status: accepted
date: 2026-07-22
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0052: Map and brief viewer overlays adapt to window size like ADR-0049's selectors

## Context and problem statement

ADR-0030 promotes editors to a modal dialog on medium/expanded windows and keeps them a bottom sheet on compact; ADR-0049 applies the identical `WindowSizeClass.hasMasterDetail` split to "pick one from a list" selectors. Regular `ContextSheet` viewer targets (station, team, role, exercise) already get an equivalent treatment for free: on medium/expanded, `MasterDetailScope` renders them inline in the detail pane instead of opening any overlay at all.

Two surfaces never got either treatment and stayed hard-coded to `showRingdrillActionSheet`/`showRingdrillViewerSheet` (a bottom sheet) regardless of window size:

* The interactive single-station/-role map (`openStationMapSheet`, `openRoleMapSheet`), opened by tapping a `StationMiniMap`/`RoleMiniMap` thumbnail.
* The brief (`BriefSheetTarget`), which by design always opens as its own modal overlay rather than docking into the detail pane (a brief being read should not silently replace whatever the user had selected there) — its own comment states it "always opens its own modal sheet, even in wide layout".

On a medium/expanded window this meant a bottom sheet sliding up from the bottom edge of an otherwise fully wide-screen master/detail layout — inconsistent with every editor (ADR-0030) and every selector (ADR-0049) on the same screen.

## Decision drivers

* One predictable rule, already established twice (ADR-0030, ADR-0049): compact → bottom sheet, medium/expanded → dialog.
* Reuse `showRingdrillDialogShell` (the shared rounded-dialog chrome) rather than inventing a fourth surface style.
* The brief's internal wide-layout TOC sidebar (a `LayoutBuilder` split that only appears once its body has ~900px of width, see `_ViewerBody`) must keep working — a dialog capped at the standard 720px form-dialog width would silently disable it.

## Considered options

* **A: Branch both map sheets and the brief sheet on `WindowSizeClass.hasMasterDetail`**, routing to `showRingdrillDialogShell` on medium/expanded and keeping `showRingdrillActionSheet`/`showRingdrillViewerSheet` on compact — mirroring `showRingdrillPicker` (ADR-0049). The brief's dialog uses a near-full-bleed `maxWidth` (the current viewport width) instead of the standard 720px, to preserve the TOC split. (chosen)
* **B: Leave both as sheets on every window size.**
* **C: Fold the map sheets into `MasterDetailScope` as an inline detail-pane target instead of an overlay.**

## Decision outcome

Chosen option: **A**, because it costs one `if (WindowSizeClass.of(context).hasMasterDetail)` branch per call site, reuses chrome that already exists, and brings the last two sheet-only surfaces in line with every other modal surface in the app.

### Consequences

* Good: a map thumbnail tap and a brief tap now open a centred dialog on medium/expanded, matching editors and selectors on the same screen.
* Good: the brief's TOC sidebar still triggers on medium/expanded, because its dialog is sized to (nearly) the full viewport width rather than the 720px form-dialog default.
* Bad: `showRingdrillDialogShell`'s `maxWidth` parameter is a fixed `double`, not a fraction of the viewport — the brief passes `MediaQuery.sizeOf(context).width` as a "no real cap" value, which is a slightly awkward way to say "size to the dialog's own `insetPadding`, not a caller-chosen width"; a future dialog with the same "let the content decide its own wide-layout breakpoint" need will want the same trick.
* Bad: widget tests that assert `find.byType(BottomSheet)` around these two surfaces now must either pin a compact `tester.view.physicalSize` or assert `find.byType(Dialog)` instead — flutter_test's own default ~800×600 `MediaQuery` already reads as `WindowSizeClass.medium` (`hasMasterDetail`), which is easy to miss (see `ringdrill_picker_test.dart`'s existing note on this).

## Pros and cons of the options

### Option A — adaptive branch, mirroring ADR-0049
* Good: consistent with the rest of the app; small diff; reuses existing chrome.
* Bad: the brief's viewport-width-as-maxWidth workaround (see Consequences).

### Option B — leave as sheets always
* Good: no work.
* Bad: leaves the exact inconsistency this ADR exists to remove.

### Option C — fold map sheets into the detail pane
* Good: one fewer overlay concept.
* Bad: a map thumbnail sits inside whatever detail pane is already showing a station/role; docking its *own* map inline would either replace that pane's content (losing context) or require a second, nested pane — more invasive than the adaptive-dialog fix and out of scope here.

## Links

* Related ADRs: [ADR-0026](./0026-sheet-based-context-navigation.md), [ADR-0027](./0027-unified-bottom-sheet-chrome.md), [ADR-0030](./0030-wide-screen-master-detail-layout.md), [ADR-0049](./0049-adaptive-selector-surface.md)
* Related code: `lib/views/widgets/station_mini_map.dart` (`openStationMapSheet`), `lib/views/widgets/role_mini_map.dart` (`openRoleMapSheet`), `lib/views/widgets/context_sheet.dart` (`ContextSheetController.show`, `BriefSheetTarget` branch), `lib/views/widgets/ringdrill_sheet.dart` (`showRingdrillDialogShell`)
