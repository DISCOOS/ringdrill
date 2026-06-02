You are working in the RingDrill repository. Implement **stage 4 of DESIGN-006**: add the **Roster** tab (nb "Bemanning" / en "Roster") as the third bottom-navigation destination, a flat registry of the real people in a plan. The authoritative specs:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — read *Information architecture*, *Roster tab*, and *Implementation notes → Stage 4*.
- `docs/adrs/0032-program-scoped-routing.md` (ADR-0032, Accepted) — the `/program/:uuid/` routing scheme stage 2 established.

Read both before starting. If this prompt contradicts them, the specs win; stop and ask.

Stages 1–3 have landed: the Program tab is segmented (Øvelser/Poster/Spill/Team), the navigation is Program + Map with program-scoped routing, and the overview is in place. Read the stage-2 and stage-3 handoffs before touching the router or `MainScreen`.

## What stage 4 is, and is not

Stage 4 restores the third tab — the **Roster** — that stage 2 deliberately left out until it had a body. It is additive and main-safe (push when green).

**In scope:**

- A **Roster** bottom-nav destination, nb "Bemanning" / en "Roster", at the program-scoped path `/program/:uuid/roster`, consistent with the stage-2 scheme.
- A `RosterView` + `RosterController` showing a **flat list of `Actor` entries** (the local people / cast registry), with add / edit / delete reusing the **existing actor flow**: `ActorFormScreen`, `ProgramService.loadActors()` / `getActor()` / `saveActor()` / `deleteActor()`. This is the cast-roster sheet from `RolePlaysView._openCastRoster` promoted to a destination.
- Wiring into `MainScreen`: the destination, `_pages`, `routes`, `_initTab`, `_onDestinationSelected`, the empty-pane builder, and the go_router tree (a `/program/:uuid/roster` route).
- A `programRosterPath(uuid)` helper in `app_routes.dart` and a `rosterTab` l10n key.

**Out of scope (do not touch):**

- **No person-with-role model.** Stage 4 lists `Actor`s only (the markør cast). The generalization to a "person with named role" (øvelsesleder / veileder / deltaker) is stage 5. Do not add roles, do not add `Actor` fields.
- **No drill-format / schema change.** `Actor` is unchanged. This is UI + routing only.
- **Do not remove the cast-roster sheet/action in the Spill segment.** It stays for quick casting context while editing a role; the Roster tab is an additional, primary home for the same `Actor` records. (Retiring the redundant cast-roster action is a separate follow-up.)
- No new `ContextSheet` target for actors — tapping a row opens `ActorFormScreen` via the existing form flow (modal on wide per ADR-0030), the same way the cast-roster sheet edits them today.

## Ground rules

Read `AGENTS.md`. The ones that bite:

- **Localize.** Add `rosterTab` (nb "Bemanning", en "Roster") to both arb files and run `make build` (gen-l10n). Reuse the existing actor strings ("Ny markør" / "New actor", etc.) for add/edit/empty states where they fit; add new keys only if genuinely missing.
- **CLI Flutter-free, mobile-safe imports, no new Sentry.** Widget + routing layer only.
- **Privacy.** `Actor` is PII and local (stripped on publish, ADR-0018). The Roster tab is the local people layer — it must not push actor data onto any published/wire path. Reads/writes go through `ProgramService` as today.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Investigate before you wire (do this first, no commit)

1. The post-stage-2 router and nav. `buildRouter` in `lib/views/main_screen.dart`, the program-scoped path helpers in `lib/views/app_routes.dart` (`programPath`, `programMapPath`, ...), the activation gate, and how `MainScreen` threads the active uuid in `_initTab` / `_onDestinationSelected` and `routes`. Add Roster the same way Map is wired.
2. The existing actor surface to promote: `RolePlaysView._openCastRoster` (the sheet listing every `Actor` with add/edit/remove) and how it uses `ActorFormScreen` and `ProgramService` actor CRUD. The Roster tab is this list as a destination.
3. `ActorFormScreen({actor, modal})` and how the cast sheet opens it (add: blank; edit: existing; delete path).
4. The empty-pane builder `_emptyPaneBuilderForCurrentTab` and how the other tabs supply a detail-empty widget; the Roster tab needs one too.

Append a short note to `docs/prompts/DESIGN-006-stage-4-handoff.md` (create it) before step 1.

### Recommended approach

- Add `programRosterPath(uuid)` to `app_routes.dart` and a `/program/:uuid/roster` `GoRoute` mirroring the Map route.
- `RosterView` (`lib/views/roster_view.dart`): a flat `ListView` of `ProgramService().loadActors()`, each row showing the actor (real name, phone), tap → edit via `ActorFormScreen`, swipe/long-press → edit, delete via `deleteActor` (guard against deleting an actor that is still cast, matching the cast sheet's rule if one exists). `RosterController extends ScreenController`: `title` = `rosterTab`, `buildFAB` = "Ny markør" (or the existing add-actor affordance) opening a blank `ActorFormScreen`.
- Wire `MainScreen`: add the destination (icon `Icons.badge` or `Icons.recent_actors`, agent's pick — distinct from Teams' `Icons.group`), add the `PageWidget`, extend `routes` and the destination list to three, update `_initTab` / `_onDestinationSelected` to build `programRosterPath(activeUuid)`, and add a `RosterDetailEmpty` (or reuse a generic placeholder) to the empty-pane builder.

## Commits

Conventional Commits with a scope (`navigation`, `roster`, `l10n`). One commit per step, `git status` clean between steps. Do not squash.

## Steps

### Step 1 — `feat(roster)`: RosterView and RosterController

Build `RosterView` + `RosterController` showing the flat `Actor` list with add/edit/delete via `ActorFormScreen` and `ProgramService` actor CRUD, reusing the logic from `RolePlaysView._openCastRoster`. Not yet wired into navigation. Add the `rosterTab` l10n key and run `make build`.

Gates green. Commit.

### Step 2 — `feat(navigation)`: add the Roster destination and route

Add `programRosterPath` + the `/program/:uuid/roster` route, the third bottom-nav destination (nb "Bemanning" / en "Roster"), the `PageWidget`, and update `routes`, `_buildDestinations`, `_initTab`, `_onDestinationSelected` and the empty-pane builder. The navigation goes from two tabs to three (Program, Map, Roster).

Gates green. Commit.

### Step 3 — `test(roster)` + `docs(design)`: cover the tab and update DESIGN-006

Widget tests under `test/`: the Roster destination renders and selects; the actor list shows; add opens `ActorFormScreen`; edit and delete work; the bottom nav now has three destinations. Update DESIGN-006 so the *Roster tab* section reflects the shipped view-shell (actor registry now, person-with-role still stage 5), and add a changelog line.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-006-stage-4-handoff.md`.
- Off-scope findings go to `docs/prompts/DESIGN-006-followups.md` (one line each).
- If a step is blocked, write a one-paragraph note to `docs/prompts/DESIGN-006-stage-4-blockers.md` and exit rather than guessing.
- Stage 4 is additive and post-release-unit, so it may be pushed once green.
