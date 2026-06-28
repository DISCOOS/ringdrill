---
status: accepted            # proposed | accepted | deprecated | superseded by ADR-NNNN
date: 2026-05-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0032: Prefix every program-scoped path with `/program/:uuid/` and drive activation from the URL

## Context and problem statement

RingDrill keeps exactly one *active program* (`ProgramService.activeProgram`, persisted via `keyActiveProgram`). Most routes assume that context implicitly. A deep link like `/program/:exerciseId` carries only the exercise uuid and relies on the right program already being active, and index-based paths are worse: `/teams/:teamIndex` resolves the team with `loadExercises().where((e) => e.numberOfTeams > teamIndex).firstOrNull`, a best-effort guess across whatever is loaded. A team or station index is only meaningful inside one program, so these paths are silently ambiguous without an active-program assumption baked in.

This is about to matter more. [DESIGN-006](../design/006-program-tab-consolidation.md) collapses the navigation to three tabs and relocates stations, roles and teams into the Program tab and a new Roster tab, so several tab-rooted deep links lose their destination. The catalog/wiki model and the account model ([ADR-0024](./0024-account-and-identity-model.md), [ADR-0025](./0025-authorization-and-publish-policy.md)) make multiple plans the norm and shared links a primary entry point, where "open this link" must open the *right* plan rather than reinterpret the path against whatever happened to be active. The brief route already carries the plan (`/brief/program/:programUuid`), so the rest of the app is the inconsistent part.

## Decision drivers

* Shared links must be self-contained. The recipient's app must know which plan a path belongs to.
* Index-based paths (teams, stations) must stop depending on a guessed active program.
* Activation should follow one deterministic path rather than being a precondition set elsewhere.
* Forward-compatibility with account-scoped plans ([ADR-0024](./0024-account-and-identity-model.md)).
* Links already in the wild must keep working ([ADR-0015](./0015-shareable-install-links.md), and the station-detail link DESIGN-002 promised to preserve).

## Considered options

* **Option A — Prefix everything program-scoped, including tab roots, and let the URL drive activation.** `/program/:uuid`, `/program/:uuid/map`, `/program/:uuid/roster`, and detail paths below them. Rendering any such path first activates `:uuid` locally. Old un-prefixed paths become redirects that resolve the owning program.
* **Option B — Prefix only detail/deep-link paths.** Tab roots (`/program`, `/map`, `/roster`) stay un-prefixed and operate on the active program. Only `/program/:uuid/exercise/...` style detail paths carry the uuid.
* **Option C — Status quo.** Keep relying on the active-program singleton plus global uuid lookups and index guessing.

## Decision outcome

Chosen option: **Option A**, because it removes implicit active-program state from routing entirely, so a path always names its plan and showing the path is what activates it.

Concretely, every path that looks *into* a concrete program carries the program uuid as a mandatory prefix. Resolving such a path runs a single activation gate: look up `:uuid`, ensure it is the active program locally, then render. An unknown or unavailable `:uuid` lands on a defined fallback rather than a wrong context.

### Canonical scheme

* `/program/:uuid` — Program tab. Redirects to `/program/:uuid/exercises` (the default segment) so every visible view in the Program tab has a canonical URL.
* `/program/:uuid/exercises` | `/program/:uuid/stations` | `/program/:uuid/script` | `/program/:uuid/teams` — the four Program-tab segments (Øvelser/Poster/Markører/Team) from DESIGN-006. Plural form keeps these segment views distinct from singular detail paths below them. Initially this section called the segments "view state, not path segments"; that turned out to break browser-back, deep-linking and shared URLs for those views, so they are promoted to path segments here.
* `/program/:uuid/map` — Map tab for that plan.
* `/program/:uuid/roster` — Roster tab (`nb` "Bemanning") for that plan.
* `/program/:uuid/exercise/:exerciseId` — exercise detail, with `/station/:stationIndex` and `/team/:teamIndex` below it. Teams are program-scoped, so `/program/:uuid/team/:teamIndex` is also valid and the exercise-nested team path redirects to it.
* `/program/:uuid/roleplay/:roleUuid` — role detail.
* `/program/:uuid/brief` and `/program/:uuid/exercise/:exerciseId/brief` — realigns the brief route from today's `/brief/program/:programUuid` into the same prefix.

### Activation contract

Rendering a program-scoped path is also what mutates in-memory navigation state. UI actions that change navigation must therefore go through `router.go(...)`, never through the underlying state setters directly:

* Plan activation (library "open plan", create-new-plan, install-link landing): call `router.go(programPath(uuid))`. `ProgramService.setActive` runs as the redirect-gate side effect, not at the UI call site.
* Segment selection in the Program tab: call `router.go(programSegmentPath(uuid, segment))`. `ProgramPageController.activeSegment` is written by the redirect gate, not by the segment switcher.
* Tab switching is already URL-bound via `MainScreen._onDestinationSelected` and stays unchanged.

`setActive` and `activeSegment` remain as the in-memory representations widgets listen to; the contract is about *who writes* to them.

### Out of scope for the prefix

Paths that exist *before* or *across* a program stay un-prefixed: library and catalog browsing, the open-plan flow, settings, and the install/file entry points `/i/:slug` and `/o/...`. These either pick a program or operate above the program layer.

### Back-compatibility

Old un-prefixed paths are kept as redirects, not as canonical routes. An incoming `/program/:exerciseId`, `/stations/:ex/:idx`, `/teams/:teamIndex` or `/roleplays/:roleUuid` resolves the owning program from the entity, activates it, and forwards to the prefixed canonical path. Links in the wild survive, and everything newly emitted is self-contained. This needs a reverse lookup from an entity to its owning program, which `ProgramService` can provide from the loaded set.

### Consequences

* Good: index-based paths (team, station) become unambiguous because the program is named in the path.
* Good: shared and bookmarked links open the correct plan without depending on prior app state.
* Good: one activation path. The redirect gate is the only place that sets the active program from a URL, which is easy to reason about and test.
* Good: forward-compatible with account-scoped plans and consistent with the existing brief route.
* Bad: navigating the tabs must thread the active program uuid into the routes it builds. The shell already knows the active program, but the route construction grows a parameter.
* Bad: app launch must build the initial URL from the resolved active-or-default program. `ensureActiveProgram` already finds it, so this is wiring rather than new logic.
* Bad: a deep link now mutates which program is active. This is intended for "open shared plan", but it is a global side effect to keep in mind when reasoning about navigation.
* Bad: a back-compat redirect layer must live alongside the canonical routes until the old paths can be retired.
* Bad: the segment switcher and the UI-initiated plan-activation call sites (library, create-new-plan, install/open flows) must be migrated from direct state writes to `router.go(...)`. Manageable but touches several files.

## Pros and cons of the options

### Option A
* See *Consequences* above.

### Option B
* Good: smaller change, detail links become self-contained while tab roots stay simple.
* Bad: leaves tab roots depending on the active-program singleton, so the inconsistency and the index-ambiguity survive at the tab level. Two mental models for one app.

### Option C
* Good: no work.
* Bad: keeps the latent index ambiguity and the implicit dependency, and shared links stay fragile exactly as the catalog/account model arrives.

## Links

* Related design: [DESIGN-006](../design/006-program-tab-consolidation.md) (the tab consolidation this routing supports). DESIGN-006 stage 2 implements against this ADR.
* Related ADRs: [ADR-0008](./0008-persistent-program-library-and-catalog.md) (active plan and library), [ADR-0024](./0024-account-and-identity-model.md) / [ADR-0025](./0025-authorization-and-publish-policy.md) (account-scoped plans), [ADR-0015](./0015-shareable-install-links.md) (install links), [ADR-0026](./0026-sheet-based-context-navigation.md) (the detail sheets these paths launch).
* Related code: `lib/views/main_screen.dart` (go_router shell, `_ContextSheetDeepLinkLauncher`, `_initTab`, `_routeForTab`), `lib/views/shell/app_router.dart` (`_activateCanonicalProgramPath`, redirect gate — extend with segment), `lib/views/app_routes.dart` (route constants — add `programSegmentPath`), `lib/views/program_view.dart` (`_ProgramSegmentSwitcher` — call `router.go`), `lib/views/library_view.dart` (`_activate` — route instead of `setActive`), `lib/views/active_plan_actions.dart` (`createNewPlan` and siblings — route instead of `setActive`), `lib/services/program_service.dart` (`activeProgram`, `ensureActiveProgram`, owning-program lookup).
