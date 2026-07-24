---
status: accepted
date: 2026-07-22
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0051: Single `MapConfig.fitFor` camera-fit helper for every map surface

## Context and problem statement

RingDrill's map lives in one shared `MapView` widget, but it is instantiated in many places — mini-map previews (`StationMiniMap`, `RoleMiniMap`, `ExerciseMiniMap`), interactive sheets (`openStationMapSheet`, `openRoleMapSheet`), the full-screen `StationsView`/`CoordinatorScreen` maps, `MapPickerScreen` (via `PositionFormField`), and `MapView`'s own "centre" button (`_toggleCenter`) and search-result handler. Each of these independently computed its initial camera framing: some used a true-centroid fit (`LatlngListX.centroidFit`), others a bounding-box fit (`LatlngListX.fit`/`CameraFit.coordinates`) that drifts toward outliers; some applied `MapConfig.fitPadding`'s overlay-aware padding (reserving space for the search field/FAB column), others a flat `EdgeInsets.all(72)`, others no padding logic at all.

The result: a mini-map/sheet's initial framing routinely did not match what pressing its own "centre" button produced (different padding, sometimes a different algorithm), and previews that took multiple markers (a station's locations, a role's parent-post/portrayed-person extras) sometimes ignored all but one marker's position entirely on open, snapping into frame only once centred manually.

## Decision drivers

* One camera-fit answer per set of overlay flags, so a surface's initial view always matches what its own "centre" control would produce.
* No duplicated fit/padding logic at each of the ~8 call sites — a bug fixed in one must not need fixing again in the others.
* Preserve the two existing algorithms (`centroidFit` for the common multi-point case, `CameraFit.coordinates` as a degenerate-bounds fallback) rather than inventing a third.

## Considered options

* **A: One `MapConfig.fitFor(points, {withSearch, withZoom, withCenter, withLocate})` helper**, colocated with the existing `MapConfig.fitPadding`, used by every call site including `MapView._toggleCenter` itself. (chosen)
* **B: Document the "correct" pattern and ask each call site to hand-copy it.**
* **C: Push fitting into `MapView` itself (an internal `autoFit: bool` flag) instead of callers computing `initialFit`.**

## Decision outcome

Chosen option: **A**, because it makes the *same* code path responsible for both "the sheet's opening view" and "what centre produces" — so they cannot drift apart again — while leaving `MapView` itself domain-agnostic (ADR-0020) and each caller free to only pass the marker points it wants framed (e.g. mini-map previews that never show a centre button still get sane baseline padding).

`MapConfig.fitFor` returns `null` when fewer than two finite points are given; callers keep their existing single-point/no-point fallback (`initialCenter`/`move` at current zoom) — see `MapView._toggleCenter` for the reference shape. The `withX` flags passed to `fitFor` must be the same flags passed to the `MapView` it frames, so `fitPadding`'s overlay reserve matches.

### Consequences

* Good: every map surface's initial framing now provably matches its own centre button, because both call the identical helper with identical flags.
* Good: `RoleMiniMap`/`StationMiniMap` previews and their sheets now fit *every* marker they render (a role's extra markers, a station's scenario locations) instead of centring on one point and ignoring the rest.
* Good: the now-fully-unused bbox-only `LatlngListX.fit()`/`StationLocationX.fit()` extension methods were deleted rather than left as a second, discouraged path.
* Bad: every call site must remember to pass the *same* `withX` flags as its `MapView` — nothing enforces this at compile time; a future call site that forgets still reintroduces a padding mismatch (mitigated only by code review / this ADR).

## Pros and cons of the options

### Option A — one `MapConfig.fitFor` helper
* Good: single source of truth; smallest diff; reuses existing `centroidFit`/`fitPadding` primitives.
* Bad: flags must be kept in sync by hand at each call site (see Consequences).

### Option B — document, don't consolidate
* Good: no code change.
* Bad: does nothing to prevent the next call site from copying the wrong (bbox / flat-padding) example; the bug this ADR fixes recurs.

### Option C — `autoFit` flag on `MapView`
* Good: callers pass no fit logic at all.
* Bad: `MapView` would need to know about its caller's marker semantics to decide *when* to refit (e.g. on marker-list change vs. only on first build), reintroducing exactly the kind of domain leak ADR-0020 removed; rejected without prototyping.

## Links

* Related ADRs: [ADR-0020](./0020-map-label-and-marker-clutter.md) (`MapView`'s domain-agnostic marker spec)
* Related code: `lib/views/map_view.dart` (`MapConfig.fitFor`, `MapConfig.fitPadding`, `_toggleCenter`), `lib/utils/latlng_utils.dart` (`centroidFit`), `lib/views/stations_view.dart`, `lib/views/coordinator_screen.dart`, `lib/views/widgets/station_mini_map.dart`, `lib/views/widgets/role_mini_map.dart`, `lib/views/widgets/exercise_mini_map.dart`, `lib/views/position_form_field.dart`
