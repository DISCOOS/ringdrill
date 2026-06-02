You are working in the RingDrill repository. Implement **stage 2 of DESIGN-006** ("Program tab consolidation and Roster layer"): collapse the navigation and adopt program-scoped routing. The authoritative specs are:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — read *Information architecture*, *Implementation notes → Stage 2*, and the *Delivery* note.
- `docs/adrs/0032-program-scoped-routing.md` (ADR-0032, Accepted) — the routing invariant, the canonical scheme, the out-of-scope paths, and the back-compatibility rule.

Read both in full before you start. If this prompt contradicts them, the specs win. Stop and ask rather than diverging.

Stage 1 (the segmented Program tab) has already landed. Read `docs/prompts/DESIGN-006-stage-1-handoff.md` for the state it established before you touch anything.

## What stage 2 is, and is not

Stage 2 finishes the first release unit. After it, the navigation is **Program + Map** (two tabs), every program-scoped path is prefixed with `/program/:uuid/`, and old links still resolve. Stages 1 and 2 together are pushed to GitHub as one unit, so the tree must be clean and releasable when stage 2 ends.

**In scope:**

- Program-scoped routing per ADR-0032: a `/program/:uuid/` prefix on every path that looks into a concrete program, plus a single activation gate (resolve `:uuid` → make it the active program → render).
- Back-compat redirects: the old un-prefixed paths keep working by forwarding to the canonical path.
- Collapse the bottom navigation to **Program + Map** by removing the Stations, RolePlays and Teams root destinations. Their content already lives in the Program segments from stage 1.
- Tab navigation threads the active program uuid into the routes it builds.

**Out of scope (do not touch):**

- **Do not add the Roster tab.** It needs a body and arrives in stage 4. Stage 2 ends on two tabs, not three. Leaving an empty Roster tab is exactly the awkward state to avoid.
- No collapsing overview / sliver header (stage 3).
- No data-model change, no codegen.
- No cross-program reverse lookup. Old un-prefixed entity paths resolve against the **active** program, matching today's behaviour (they never carried a program uuid, so they were always active-relative). Self-contained `/program/:uuid/` links activate `:uuid` via `ProgramService.setActive`.
- The person-with-role model (stage 5).

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **CLI must stay Flutter-free.** Routing is widget-layer; nothing here reaches `bin/` or `lib/data/drill_client.dart`.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **Localize every user-visible string.** The two remaining destinations reuse existing tab-label keys. Add a key only if genuinely new, to both `app_en.arb` and `app_nb.arb`.
- **No new Sentry/analytics calls.**
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.**
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** Run `flutter analyze` and `flutter test` at the end of each step. Routing changes are easy to break silently, so exercise the deep links in tests.

## Investigate before you wire (do this first, no commit)

Routing is the load-bearing change, so map it before editing. Establish:

1. The current router. `buildRouter` in `lib/views/main_screen.dart`: the `ShellRoute`, its `routes` list `[routeProgram, routeMap, routeStations, routeRolePlays, routeTeams]`, the nested detail subroutes under each, and the `_ContextSheetDeepLinkLauncher` / `_BriefDeepLinkLauncher` pattern that opens a sheet then pops. Note the existing redirects (`/i/:slug`, `/o/...`).
2. The route constants in `lib/views/app_routes.dart` (`routeProgram`, `routeMap`, `routeStations`, `routeTeams`, `routeRolePlays`, `routeBrief`).
3. How the shell selects and changes tabs: `_initTab` (matches `widget.location` against `widget.routes`) and `_onDestinationSelected` (does `widget.router.go(widget.routes[tab])`). Both must thread the active program uuid once paths are prefixed.
4. `ProgramService` activation API: `activeProgram`, `activeProgramUuid`, `setActive(uuid)`, `ensureActiveProgram(...)`, `getExercise(uuid)`, `getRolePlay(uuid)`. **Note:** `getExercise`/`getRolePlay`/`loadExercises` are scoped to the active program, so they cannot resolve an entity in a non-active program. That is why back-compat is active-relative, not a cross-program search.
5. Where the segment controllers live: `_stationListController`, `_rolePlaysController`, `_teamsPageController` are fields on `_MainScreenState`, injected into `ProgramPageController` and into the Program segment bodies (stage 1). They must survive even though their standalone tabs are removed.

Append a short note of what you found to `docs/prompts/DESIGN-006-stage-2-handoff.md` (create it) before step 1.

### Recommended approach (adopt unless investigation shows a cheaper path)

- Add `routeRoster` is **not** needed yet. Keep `routeProgram` and `routeMap`. Introduce the canonical prefixed scheme from ADR-0032 as the path structure under `/program/:uuid/`.
- Build a single **activation gate** used by every `/program/:uuid/...` match: resolve `:uuid`; if it exists in the library, `setActive(:uuid)` (no-op when already active) and render; otherwise redirect to a defined fallback. go_router's `redirect` is the natural home, so the gate runs before the page builds.
- Canonical paths: `/program/:uuid` (Program tab), `/program/:uuid/map` (Map tab), `/program/:uuid/exercise/:exerciseId` with `/station/:stationIndex` and `/team/:teamIndex` below, `/program/:uuid/team/:teamIndex`, `/program/:uuid/roleplay/:roleUuid`, and `/program/:uuid/brief` (+ `/program/:uuid/exercise/:exerciseId/brief`). Detail paths keep launching the existing `ContextSheet` targets via the launcher widgets.
- `_initTab` matches the prefixed location against the surviving routes, and `_onDestinationSelected` builds `'/program/$activeUuid'` and `'/program/$activeUuid/map'`. The active uuid comes from `ProgramService.activeProgramUuid`.
- Back-compat: keep the old paths as `redirect`s that build the canonical path from the active program. `/program/:exerciseId` → `/program/:activeUuid/exercise/:exerciseId`, `/stations/:ex/:idx` → `/program/:activeUuid/exercise/:ex/station/:idx`, `/teams/:teamIndex` → `/program/:activeUuid/team/:teamIndex`, `/roleplays/:roleUuid` → `/program/:activeUuid/roleplay/:roleUuid`, bare `/stations` `/teams` `/roleplays` → `/program/:activeUuid`. The old brief paths redirect to the prefixed brief.

## Commits

Conventional Commits with a scope (`navigation` fits most of this). One commit per step. After each step, stage **all** changes and confirm `git status` is clean before moving on. Do not squash steps.

## Steps

### Step 1 — `feat(navigation)`: program-scoped route tree and activation gate

Restructure `buildRouter` so the surviving tabs and all detail launchers live under `/program/:uuid/` per ADR-0032, with the activation gate resolving and activating `:uuid` before render and falling back on an unknown uuid. Thread the active uuid through `_initTab` and `_onDestinationSelected`. Leave the old paths reachable for now (their redirects land in step 2). Keep all five tabs mounted in this step so you can verify routing in isolation before collapsing the nav.

Gates green. Commit.

### Step 2 — `feat(navigation)`: back-compat redirects for un-prefixed paths

Add redirects forwarding every old un-prefixed path to its canonical `/program/:activeUuid/...` form, active-program-relative as described above, including the bare tab paths and the old brief paths. Confirm an externally-shaped link (e.g. `/stations/<ex>/<idx>`) still opens the right detail.

Gates green. Commit.

### Step 3 — `feat(navigation)`: collapse the bottom navigation to Program + Map

Remove the Stations, RolePlays and Teams root destinations. Reduce `routes`, `_pages` and `_buildDestinations` to Program + Map. Keep the field-held `_stationListController`, `_rolePlaysController` and `_teamsPageController` (and their disposal) because the Program segments still use them. The segment-aware empty pane from stage 1 stays. Verify nothing now reaches a removed destination and that the Markører segment's cast-roster action still opens the actor list (the only path to actors until the Roster tab arrives in stage 4).

Gates green. Commit.

### Step 4 — `test(navigation)`: cover routing, redirects and the reduced nav

Tests under `test/` for: a `/program/:uuid/...` path activates that program; an unknown uuid hits the fallback; each old un-prefixed path redirects to its canonical form and opens the right sheet; the bottom navigation renders exactly Program and Map; the detail deep links resolve. Do not add coverage for unrelated surrounding code.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-006-stage-2-handoff.md` summarizing the landed state.
- Off-scope findings go to `docs/prompts/DESIGN-006-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here.
- If a step is blocked by an ambiguous spec or unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-006-stage-2-blockers.md`, then exit rather than guessing.
- **Release unit complete.** Stages 1 and 2 are the first release unit. After stage 2 passes its gates, the unit is ready to push, but **do not push** — leave that to the operator. Commit locally and stop.
