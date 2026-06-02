# DESIGN-006 Stage 4 — Handoff

## Pre-implementation investigation (before step 1)

**Router and nav touchpoints (stage-2 state).**
`buildRouter` in `lib/views/main_screen.dart` has a `ShellRoute` with two stub routes (`routeProgram` at `/program`, `routeMap` at `/map`) and passes `routes: [routeProgram, routeMap]` to `MainScreen`. The `_initTab` / `_onDestinationSelected` / `_routeForTab` / `_buildDestinations` methods all have two-entry assumptions. Roster slots in at index 2 by mirroring every Map touchpoint: same stub builder inside the program `:programUuid` sub-tree, same top-level ShellRoute stub for the bare `/roster` fallback, same `_initTab` exact-match check, same `_routeForTab` switch arm.

**`CastRosterSheet` anatomy (the model to clone).**
`lib/views/widgets/cast_roster_sheet.dart` — `StatefulWidget`, state holds `_actors`, `_rolePlays`, `ProgramService()`. Renders a `Scaffold` with its own `FloatingActionButton.extended` ("Ny markør") and a body with a title row + `ListView.builder` + `Dismissible` rows. Add/edit via `openFormSurface<ActorFormResult>` → `ActorFormScreen`. Delete blocked when cast (shows `castDeleteBlocked` SnackBar). `_reload()` calls `setState + loadActors + loadRolePlays`.

`RosterView` clones this inner list logic without the sheet `Scaffold`/title/FAB wrapper (those become the page AppBar + controller FAB). `CastRosterSheet` is left untouched — it stays as the Spill-segment inline cast affordance.

**ProgramService actor events gap.**
`saveActor` / `deleteActor` do NOT emit `ProgramService.events`. `RolePlaysView` relies on `saveRolePlay` → event for auto-refresh, so that pattern can't be reused. Fix: `RosterController` exposes a `ValueNotifier<int> _reloadTick` (as `Listenable reloadSignal`) that `_openCreate` increments after save. `_RosterViewState` also subscribes to `ProgramService.events` for plan-level events (`programOpened`, `programActivated`, etc.) that change which actors are loaded. View-initiated mutations (`_openEdit`, `_tryDelete`, `onDismissed`) call `_reload()` directly.

**ARB keys.** Neither `rosterTab` nor `detailEmptyRoster` exists yet in either arb file. Existing reused keys: `newActor` (en "New actor" / nb "Ny markør"), `noActorsInRoster`, `castDeleteBlocked`, `castedAs`, `actorRealName`, `actorPhone`, `actorNotes`, `deleteActor`, `confirmDeleteActor`. `castRoster` exists but is not needed as the tab title (the tab title uses `rosterTab`).

**`ScreenController` / `PageWidget`.** `lib/views/page_widget.dart` — abstract class, `const ScreenController()`, abstract `title()`, default-null `buildFAB` and `buildActions`. `RosterController extends ScreenController` — no `const`, provides `title` + `buildFAB` + `dispose`.

**Detail-empty pattern.** `lib/views/shell/detail_empty_pane.dart` — four stateless widgets delegating to private `_DetailEmptyPane(icon, label)`. Add `RosterDetailEmpty` as the fifth. Icon `Icons.badge`. Label `localizations.detailEmptyRoster`.

**Test infrastructure.** No `main_screen_test.dart` exists. The closest working test to mirror is `test/views/cast_roster_sheet_test.dart` (seeded SharedPreferences + real ProgramService singleton). Actor storage key prefix: `pa:` (inferred from the cast_roster_sheet_test patterns and the `pa:` prefix seen in roleplays_view_test fixtures).

---

## Post-implementation landing summary (2026-06-02)

**Three commits landed** on `main`:

1. `feat(roster)` — `RosterView` + `RosterController` in `lib/views/roster_view.dart`; ARB keys `rosterTab` / `detailEmptyRoster` added and `flutter gen-l10n` regenerated; `RosterDetailEmpty` added to `lib/views/shell/detail_empty_pane.dart`.

2. `feat(navigation)` — Roster wired as tab 2 in `lib/views/main_screen.dart` (FAB, destinations, initTab, routeForTab, emptyPaneBuilder, dispose); `programRosterPath` + `routeRoster` added to `lib/views/app_routes.dart`; `legacyProgramRedirect` maps bare `/roster` to canonical path; existing routing test updated from 2 → 3 destinations.

3. `test(roster) + docs(design)` — `test/views/roster_view_test.dart` (6 tests, all green); DESIGN-006 stage 4 section and changelog updated.

**Surprises / non-obvious decisions:**

- `tester.drag` with `Offset(-300, 0)` on the default 800 px test screen falls just short of the Dismissible 40 % threshold (320 px). Fixed by using `-400`.
- `flutter gen-l10n` is NOT run by `make build` (only `build_runner build` runs). Must be invoked separately after ARB edits.
- `ProgramService._isReady` guard means `init()` is a no-op after the first call. All test groups in `roster_view_test.dart` share a single `setUpAll` fixture — separate `setUp` seed-swaps are invisible to the singleton's already-opened repo.
- Actor CRUD (`saveActor` / `deleteActor`) emits no `ProgramService.events`. `RosterController._reloadTick` (`ValueNotifier<int>`, exposed as `reloadSignal`) is the refresh signal for FAB-initiated creates; view-initiated edits/deletes call `_reload()` directly.
