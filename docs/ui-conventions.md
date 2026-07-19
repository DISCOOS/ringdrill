# UI conventions

Cross-cutting UI patterns. Domain naming lives in [`glossary.md`](./glossary.md); the general `lib/views/` layout, theming and localization rules stay in [`architecture.md`](./architecture.md) § Conventions → UI.

## Marker icons

The scenario-marker family uses three distinct icons, kept consistent everywhere:

* **Masks / theater** (`Icons.theater_comedy`) — the *markers group* (a section header or a list of markers).
* **Face** (`Icons.face`) — a *single marker/actor*; the same glyph the cast picker uses for one marker.
* **Person** (`Icons.person`) — a *scenario `Person`* (the fictional person, not the marker).

Don't reuse the group's masks icon for a single marker row, and don't use the person icon for a marker.

## Row edit affordances (ADR-0031)

List/expandable rows have **no pencil**. Editing is a row tap (and `onLongPress`); deleting is a swipe (`Dismissible`), behind a destructive confirmation. `Icons.edit` is reserved for `AppBar.actions` and overflow menus — never a per-row control. See ADR-0031.

## Active-filter visibility

When a filter is hiding items, make it obvious that a filter is active: a badge plus a banner with a "Show all" action. People forget they've hidden things, so a silently-filtered list must announce itself.

## Design tokens for repeated styling

When the same styling is hand-rolled in **three or more** places, extract a value-class (the tokens) plus an optional thin wrapper widget — e.g. `LiveAccent` / `LiveCard`. Prefer this over copying the decoration again.

## Map views are domain-agnostic (ADR-0020)

Feature-specific UI reaches `MapView` through **slot props** (`topRightCommands`, etc.), not by adding feature flags to the map. Markers are a unified `List<MapMarkerSpec<K>>` with clustering/label controls. See ADR-0020.

## Form primary-action label ("Save" vs "Done") (ADR-0030)

Editor forms open through `openFormSurface`, which provides a `FormSurfaceScope`. Set `commitsToParent` **per call site**: `false` (default) when the caller persists on return (a "Save" primary action), `true` when the result is only merged into a parent's unsaved working copy (a "Done" primary action). "Nested vs committing" is a property of the call site, not the form — the same form is a real save from a viewer but deferred from an editor. See the `FormSurfaceScope` / `openFormSurface` dartdoc for the full rule.
