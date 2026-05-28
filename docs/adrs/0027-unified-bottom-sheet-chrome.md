---
status: accepted
date: 2026-05-28
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0027: Unify all bottom sheets behind two `showRingdrillSheet` variants with shared surface, corners and drag-handle

## Context and problem statement

The app has four visually distinct bottom-sheet designs:

1. **ContextSheet host** ([ADR-0026](./0026-sheet-based-context-navigation.md)) — transparent outer, inner `Material(surface)`, custom 40×4 drag-handle pill, close-X, `DraggableScrollableSheet`.
2. **Standard form sheet** — `showDragHandle: true` (Material default handle), explicit `shape: top 16`, no close-X.
3. **Filter sheet** — same as 2 but no `shape`, no `useSafeArea`.
4. **Brief TOC sheet** — explicit `backgroundColor: theme.surfaces.sidebar`, no drag-handle, no close-X.

Drag-handle, surface tint and chrome all drift between sites.

## Decision drivers

* One visual identity across every sheet in the app.
* Keep [ADR-0026](./0026-sheet-based-context-navigation.md) semantics for station/team/role/brief (full-height, draggable, closable).
* Lighter sheets (pickers, filters, action lists) need a compact, wrap-content shell, not a full draggable host.
* No third-party packages.

## Considered options

* **Option A: One helper, two entry points (`showRingdrillViewerSheet` and `showRingdrillActionSheet`). (chosen)** Shared chrome, two height/affordance modes.
* **Option B: One single helper with flags.** Fewer entry points, more conditional plumbing inside.
* **Option C: Leave it as-is.** Status quo. Rejected.

## Decision outcome

Chosen option: **Option A**.

### Shared chrome (both variants)

* Outer `showModalBottomSheet`: `backgroundColor: Colors.transparent`, `useSafeArea: true`, `isScrollControlled: true`, `shape: null` (the inner `ClipRRect` owns the corners).
* Inner: `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(16))) → Material(color: Theme.of(context).colorScheme.surface)`.
* Drag-handle: centered 40×4 pill in `Theme.of(context).dividerColor`, 12 px top padding, 8 px bottom padding. No `showDragHandle: true` flag anywhere (it ships its own Material handle that does not match ours).

### Variants

`showRingdrillViewerSheet<T>` — full-height, draggable, closable:

* `DraggableScrollableSheet(initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 1.0, expand: false)`.
* No header row at the helper level. The body owns its own AppBar with title, actions and the close affordance. See Revisions below.
* Body builder receives the `ScrollController` from the draggable sheet.
* Wide-screen: body centred and constrained to `maxWidth: 720` when `MediaQuery.sizeOf(context).width >= 600`.

`showRingdrillActionSheet<T>` — compact, wrap-content:

* No `DraggableScrollableSheet`. Body wraps its own content.
* Body builder is a plain `WidgetBuilder`.
* No close-X. Drag-handle + body only.
* `SafeArea` wraps the body internally so call sites stop doing it themselves.

### Migration

* **Viewer** callers (today's ContextSheet host stays the only place that opens this variant): `ContextSheetController.show` is rewritten to call `showRingdrillViewerSheet` instead of `showModalBottomSheet` directly. Same behaviour.
* **Action** callers: every other site listed above migrates to `showRingdrillActionSheet`. That covers `dialog_widgets.dart`, `feedback.dart`, `add_exercises_dialog.dart`, `library_view.dart` (both `_LibraryBody` and `_showPlanActions`), `main_screen.dart` `_showOpenFileBottomSheet`, `station_screen.dart` and `roleplays_view.dart` cast pickers, `roleplays_view.dart` cast roster, `station_mini_map.dart` and `role_mini_map.dart` map sheets, the three filter sheets (`stations_view.dart`, `station_list_view.dart`, `roleplays_view.dart`), and `brief_screen.dart` `_openTocSheet`.
* `brief_screen.dart` `_openTocSheet` drops `backgroundColor: theme.surfaces.sidebar`. If a visual link to the brief sidebar is still wanted, it moves to a 1 px top-stripe inside the body, not a full sheet tint.
* `showDragHandle: true` is removed from every call site. `shape:` is removed from every call site. Both are now owned by the helper.
* `useSafeArea: true` is removed from action-sheet call sites since the helper wraps `SafeArea` internally.

### Consequences

* Good: One visual grammar everywhere.
* Good: Drag-handle and surface are defined in exactly one place.
* Good: Brief TOC sheet stops being a unique design island.
* Bad: Map sheets and the cast roster, which today rely on `FractionallySizedBox(heightFactor: 1.0)` to fill, move to the viewer variant — slightly different gesture model (draggable) than today.
* Bad: One-time touch of every sheet call site (≈ 15 files).

## Revisions

### 2026-05-28 (post-implementation)

The initial viewer variant rendered a slim header row (title + actions + close-X) on top of the body. Every body that the viewer surfaces (`StationExerciseScreen`, `TeamExerciseScreen`, `RolePlayScreen`, `BriefSheetBody`) already has its own AppBar with title, audience selector and action icons, plus a leading `Icons.arrow_back`. The result was two stacked headers and two close-ish affordances (X in the helper header, back-arrow in the body's AppBar) for the same action.

Resolution: the helper drops its header row entirely. The viewer variant supplies only the drag-handle pill and the body. Each body's AppBar replaces its leading `Icons.arrow_back` with `Icons.close` so the dismiss affordance lives where the title and actions already live. "Back" carries no meaning inside a modal sheet anyway — there is no previous route to return to, only the sheet to close.

`showRingdrillViewerSheet` consequently loses its `title`, `actions` and `onClose` parameters. They were never needed once the body owns the chrome.

* Related ADRs:
  * [ADR-0026](./0026-sheet-based-context-navigation.md) — viewer variant is the existing ContextSheet host, formalised here.
  * [ADR-0023](./0023-brief-theme-tokens.md) — Brief TOC sheet's sidebar tint is dropped in favour of the shared chrome.
* Related code:
  * `lib/views/widgets/ringdrill_sheet.dart` (new) — `showRingdrillViewerSheet`, `showRingdrillActionSheet`, drag-handle widget.
  * `lib/views/widgets/context_sheet.dart` — host delegates to `showRingdrillViewerSheet`.
  * All sites listed under "Migration" above.
