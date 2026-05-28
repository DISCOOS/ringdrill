---
status: accepted
date: 2026-05-28
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0026: Replace push-navigation between station/team/role detail screens with replace-semantics bottom sheets

## Context and problem statement

Tapping a station, team or role from inside a tab pushes a full route onto the navigator. Once inside one of those screens, tapping a cross-reference (a team listed inside a station, a station listed inside a team, a role listed inside a station) pushes *another* route on top. The user can keep doing this indefinitely and ends up walking the same screens in a cycle, with a back-stack that does not match where they think they are.

The cycle is structural. `lib/views/team_screen.dart` (lines 67–90) already drops back to a raw `Navigator.push` instead of `context.push` because routing the station detail through GoRouter crosses branches (`/teams/...` → `/program/<uuid>/station/...`), drops `TeamScreen` from the stack, and crashed the app on system back. The comment in that file is a record of the underlying mismatch: station detail is not "under" any one tab, it is a contextual lookup reachable from several places.

The Brief view (DESIGN-004, [ADR-0023](./0023-brief-theme-tokens.md)) is already presented as a fullscreen modal bottom sheet on top of the active tab. It works well, and suggests the right shape for the other detail surfaces.

## Decision drivers

* Eliminate the circular push between station, team and role detail.
* Preserve the active tab as the user's anchor, regardless of how detail is reached.
* Keep edit/commit surfaces (forms) and the full-player overlay distinct from contextual lookups, because they have different mental models.
* Remove the cross-branch GoRouter workaround in `team_screen.dart`.
* Match the visual grammar the Brief sheet already established.

## Considered options

* **Option A: Sheet-based context navigation with replace semantics. (chosen)** Detail surfaces become modal bottom sheets. Tapping a cross-reference inside a sheet replaces the sheet's content rather than stacking. System back dismisses the sheet entirely.
* **Option B: Keep push, rewrite cross-references as `pushReplacement` when a cycle is detected.** Treats the symptom, not the cause. Cross-branch workaround stays.
* **Option C: Detail screens as child routes of the active tab.** Forces an arbitrary "owning tab" choice for stations and roles, which is exactly the question today's routing fails to answer.
* **Option D: Inline expansion in the list, never push, never sheet.** Loses the visual focus and does not fit screens with maps and dense rosters.

## Decision outcome

Chosen option: **Option A**. It cuts the cycle at the source, preserves the tab as the anchor, and reuses the Brief sheet pattern.

### Navigation grammar

The app has exactly three navigation surfaces:

1. **Tabs** — the bottom nav (or rail). Always deep-linkable.
2. **Sheets** — modal bottom sheets that sit on top of the active tab. Used for station, team, role and brief detail. At most one sheet is open at a time. Tapping a cross-reference inside a sheet *replaces* the inner content without animating dismiss/open; system back dismisses the whole sheet and returns to the tab.
3. **Pushed routes** — full-route screens with a back button. Reserved for forms (station, exercise, actor, role, settings) and the full-player overlay (DESIGN-001).

If a form is opened from inside a sheet, it pushes on top, the sheet stays mounted underneath, and popping the form returns to the still-open sheet. This is the only nested-navigation case left.

### Sheet controller

A `ContextSheetController` is mounted once by `MainScreen` and exposed via `InheritedNotifier`. It owns at most one sheet and a `ValueNotifier<ContextSheetTarget?>`. `show` opens the sheet (or swaps content if one is already open). `replace` swaps content; `close` dismisses. `ContextSheetTarget` is a sealed class with `StationSheetTarget`, `TeamSheetTarget`, `RoleSheetTarget` and `BriefSheetTarget`. The existing `BriefSheetLauncher` is folded into the controller.

### Sites being changed

| Site                                                     | Today                                  | After                                                 |
|----------------------------------------------------------|----------------------------------------|-------------------------------------------------------|
| Tap station in `StationListView`                         | `context.push('/stations/...')`        | `ContextSheet.of(context).show(StationSheetTarget)`   |
| Tap station marker in `StationsView` map                 | route push                             | `show(StationSheetTarget)`                            |
| Tap team in `TeamsView`                                  | `context.push('/teams/:teamIndex')`    | `show(TeamSheetTarget)`                               |
| Tap station from inside a team section                   | raw `Navigator.push` (workaround)      | `replace(StationSheetTarget)`                         |
| Tap team from inside a station                           | route push                             | `replace(TeamSheetTarget)`                            |
| Tap role from `RolePlaysView`                            | `context.push('/roleplays/:roleUuid')` | `show(RoleSheetTarget)`                               |
| Tap role from inside a station sheet                     | route push                             | `replace(RoleSheetTarget)`                            |
| Tap station from inside a role sheet                     | route push                             | `replace(StationSheetTarget)`                         |
| Brief action on `CoordinatorScreen` / `ProgramView`      | `context.push('/brief/...')`           | `show(BriefSheetTarget)`                              |

The raw `Navigator.push` workaround in `team_screen.dart` and its comment block are removed.

### Deep links

Existing URLs (`/stations/:exerciseId/:stationIndex`, `/teams/:teamIndex`, `/roleplays/:roleUuid`, `/brief/...`) remain as deep-link entry points and open the corresponding sheet on top of the correct tab. Internal navigation does *not* update the URL when a sheet replaces; the URL only changes on tab switch and on deep-link entry.

### Brief: copy-to-share appends a viewer link

The fullscreen Brief viewer is out of scope for the navigation work itself, but the URL it will eventually live at is the same `/brief/<uuid>` route the sheet uses today. That lets us start emitting the link from day one:

The Brief sheet's "Copy" action appends a footer line `→ ringdrill.app/brief/<uuid>?audience=<a>` to the copied markdown. Audience survives the round-trip. Recipients with the app open the brief in-app via the existing deep-link wiring; recipients without the app land on `ringdrill.app` and read the brief in the browser once the standalone viewer ships. Until then, the link still resolves for app-installed recipients, so the copy action is safe to enable immediately.

### Wide-screen

On wide screens (`_wideScreen`, ≥ 600 px), the sheet is centred over the tab and constrained to 720 px max width (same as the Brief reading column, [ADR-0023](./0023-brief-theme-tokens.md)). Tab switch dismisses the sheet first.

### Consequences

* Good: The cycle disappears by construction. There is no stack the user can re-enter.
* Good: The cross-branch GoRouter workaround in `team_screen.dart` is removed.
* Good: One visual grammar for station, team, role and brief detail.
* Good: Forms and the full-player keep their natural semantics.
* Good: Brief copy-to-share gets a viewer link from day one; the future fullscreen viewer reuses the URL transparently.
* Bad: Users lose the ability to back-stack through several detail screens to compare them. The replace model fits "open the next thing I want to look at" better than "stack things to compare".
* Bad: A small one-time shim is needed so deep links open the right sheet on the right tab.
* Bad: Any descendant code that relies on `ModalRoute.of(context)?.canPop` for detail screens needs an audit.

## Pros and cons of the options

### Option A — Sheet-based context navigation with replace semantics

* Good: Eliminates the cycle at the source, removes the GoRouter workaround, reuses the Brief sheet pattern.
* Bad: Requires a small controller and a deep-link shim; loses back-stack comparison.

### Option B — Detect cycles and `pushReplacement`

* Good: Smallest diff.
* Bad: Same screens, same opaque back behaviour, workaround stays.

### Option C — Detail as child routes of the active tab

* Good: Clear per-tab hierarchy.
* Bad: Forces an arbitrary owning tab; cross-references still cross branches.

### Option D — Inline expansion only

* Good: No navigation.
* Bad: Does not fit the dense detail content (map, roster, actions).

## Revisions

### 2026-05-28 (post-implementation)

The initial decision kept `ProgramView` → `CoordinatorScreen` as a routed push, on the rationale that `CoordinatorScreen` is a working surface rather than a contextual lookup. In practice that left the Program tab as the one place in the app where a list tap pushed a full route, which read as inconsistent next to every other detail surface and reintroduced the back-stack mental model the ADR set out to remove.

`ExerciseSheetTarget(exerciseUuid)` is added to the sealed `ContextSheetTarget`. `ProgramView` taps go through `ContextSheet.of(context).show(ExerciseSheetTarget(...))`, the deep-link route `/program/:exerciseId` resolves through the same `_ContextSheetDeepLinkLauncher` shim that the other detail routes already use, and `CoordinatorScreen`'s AppBar gains a `Icons.close` leading + `SheetTitle` title in line with the other viewer-sheet bodies.

The navigation grammar tightens to: tabs + sheets + forms + the future fullscreen player. Push/back is reserved for forms (commit/cancel semantics) and the running-drill player (DESIGN-001, opens fullscreen when the coordinator taps play). The coordinator screen no longer doubles as the "running drill" surface — that role moves to the dedicated player.

## Links

* Related ADRs:
  * [ADR-0004](./0004-no-third-party-state-management.md) — controller stays within the InheritedNotifier pattern.
  * [ADR-0020](./0020-map-label-and-marker-clutter.md) — `MapMarkerSpec` tap now opens the same sheet as the list tap.
  * [ADR-0023](./0023-brief-theme-tokens.md) — reference implementation for the sheet pattern this ADR generalises.
* Related design docs:
  * [DESIGN-001](../design/exercise-player.md) — full-player overlay remains push/back.
  * [DESIGN-004](../design/brief-template.md) — copy-to-share output gains a viewer link.
* Related code:
  * `lib/views/main_screen.dart` — mounts the controller, folds in `BriefSheetLauncher`.
  * `lib/views/widgets/context_sheet.dart` (new) — controller, targets, sheet container.
  * `lib/views/team_screen.dart` — drops the workaround at lines 67–90.
  * `lib/views/station_screen.dart`, `lib/views/coordinator_screen.dart`, `lib/views/brief_screen.dart` — cross-references and Brief Copy action route through the controller.
