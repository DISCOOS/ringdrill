You are working in the RingDrill repository. Implement **stage 1 of DESIGN-006** ("Program tab consolidation and Roster layer"): turn the Program tab into a segmented view with four lenses (Øvelser, Poster, Markører, Team), driven by a segment switcher, while leaving the rest of the navigation untouched. The authoritative spec is:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — read it in full before you start, especially *Program tab anatomy*, *Segmented switcher*, *Contextual FAB and actions*, and *Implementation notes → Stage 1*.

If anything in this prompt contradicts DESIGN-006, the spec wins. Stop and ask rather than silently diverging.

## What stage 1 is, and is not

Stage 1 is **only** the segmented Program tab. After it, the app still has all five bottom-navigation tabs. Stage 1 deliberately leaves a transitional redundancy: the Program tab's Poster/Markører/Team segments show the same content as the still-present Stations/RolePlays/Teams tabs. That is expected and is cleaned up in stage 2. Do not start stage 2.

**In scope:**

- A segment switcher in the Program tab with four segments: Øvelser, Poster, Markører, Team.
- Showing the active segment's body, reusing today's view bodies (`ProgramView`'s exercise list, `StationListView`, `RolePlaysView`, `TeamsView`).
- The FAB and the AppBar actions follow the active segment, delegating to the **existing** per-tab behaviour.
- In the wide (master/detail) layout, the empty detail pane follows the active segment.

**Out of scope (do not touch in stage 1):**

- No navigation change. The five tabs and their routes stay exactly as they are. (Stage 2.)
- No routing change. Do not implement the `/program/:uuid/` scheme from ADR-0032 here. (Stage 2.)
- No collapsing overview / sliver header. The switcher sits at the top of the Program tab body for now. (Stage 3.)
- No data-model change, no codegen.
- **No new FABs.** DESIGN-006's FAB table is the end-state. In stage 1 you only relocate the FAB each tab shows **today**. Concretely: Øvelser keeps "Ny øvelse" (`ProgramPageController`), Poster reuses the station filter FAB (`StationListController`), Markører reuses whatever `RolePlaysController` exposes today, and Team has **no** FAB (`TeamsPageController` defines none). Do not invent "Ny rolle" or "Nytt lag".

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite this change:

- **Localize every user-visible string.** Do not hardcode segment labels. Reuse the existing tab-label keys, which already carry the right `nb`/`en` values: `exercise(2)` ("Øvelser"/"Exercises"), `stationsTab` ("Poster"/"Stations"), `rolePlaysTab` ("Markører"/"RolePlays"), `team(2)` ("Lag"/"Teams"). Add a new key only if a label genuinely has no existing equivalent, and then add it to both `app_en.arb` and `app_nb.arb`. Norwegian for *station* stays "post"/"poster".
- **CLI must stay Flutter-free.** This is widget-only work under `lib/views/`. Nothing here should reach `bin/` or `lib/data/drill_client.dart`.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **MapView stays domain-agnostic** (ADR/feedback): no domain flags pushed into `MapView`. Stage 1 should not need to touch it.
- **No new Sentry/analytics calls.**
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.** No codegen is expected in this stage at all.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** Run `flutter analyze` and `flutter test` at the end of each step. A pre-existing failing test is acknowledged, not hidden, but you must not add new failures.

## Investigate before you wire (do this first, no commit)

The intricate part is the controller wiring, so map it before writing code. Use `Grep`/`Explore` for lookups, `Read` with `offset`/`limit` for sections. Establish:

1. How `MainScreen` builds the per-tab chrome: `_pages` (the `PageWidget` list), `page.controller.buildFAB`, `page.controller.buildActions`, and the field-held controllers `_stationListController` and `_rolePlaysController` (see `lib/views/main_screen.dart`). The Program tab is `PageWidget(controller: ProgramPageController(), child: ProgramView())`.
2. How each segment body is structured today and what it assumes about owning the page: `ProgramView` (`lib/views/program_view.dart`), `StationListView` (`lib/views/station_list_view.dart`), `RolePlaysView` (`lib/views/roleplays_view.dart`), `TeamsView` (`lib/views/teams_view.dart`). Note that the bodies render lists and read `MasterDetailScope`, while the FAB/actions live on the controllers, not the bodies.
3. The `ScreenController` contract (`lib/views/page_widget.dart`): `title`, `buildFAB`, `buildActions`.
4. **The double-instantiation hazard.** `main_screen.dart` deliberately holds `_stationListController` and `_rolePlaysController` as fields and warns (in comments) against constructing a second instance, because a duplicate double-subscribes to `ProgramService`. When the Program tab embeds these bodies, reuse the **existing** controller instances rather than creating new ones. Pass them into `ProgramView`.

Write a two-to-four line note of what you found to `docs/prompts/DESIGN-006-stage-1-handoff.md` (create on first use) before step 1, so a fresh context can pick up without re-deriving the wiring.

### Recommended approach (adopt unless investigation shows a cheaper path)

- Add a `ProgramSegment` enum (`exercises`, `stations`, `roleplays`, `teams`) and a `ValueNotifier<ProgramSegment> activeSegment` owned by `ProgramPageController` (the controller outlives `ProgramView` rebuilds and is already reachable from `MainScreen`).
- `ProgramView` renders a `Column`: the `SegmentedButton<ProgramSegment>` pinned at the top, then `Expanded` holding the active segment's body. Keep all four bodies behind the switcher via an `IndexedStack` so each keeps its state when you switch, mirroring how `MainScreen` keeps tabs alive.
- The Poster/Markører/Team bodies are the existing `StationListView` / `RolePlaysView` / `TeamsView` widgets, bound to the controller instances `MainScreen` already owns (passed into `ProgramView`). The Øvelser body is `ProgramView`'s current exercise list.
- `ProgramPageController.buildFAB` and `buildActions` switch on `activeSegment.value` and delegate to the matching existing controller's `buildFAB`/`buildActions` (Team returns null). `MainScreen` rebuilds its chrome when `activeSegment` changes — subscribe to the notifier the same way it already listens to `ProgramService`/`ExerciseService`.

## Commits

Conventional Commits with a scope. Types allowed: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Use scope `program` (or `navigation`/`widget` where more specific). One commit per step. After each step, stage **all** changes and confirm `git status` is clean before moving on — no stray modified or untracked files left behind. Do not squash the steps into one commit.

## Steps

### Step 1 — `feat(program)`: add ProgramSegment and the segment switcher

Add the `ProgramSegment` enum and the `activeSegment` notifier on `ProgramPageController`. Refactor `ProgramView` to render the `SegmentedButton<ProgramSegment>` at the top and, below it, the active body via an `IndexedStack`. In this step the Øvelser segment shows the real exercise list; the other three may show their bodies if wiring is trivial, otherwise a temporary `SizedBox.shrink()` placeholder you replace in step 2. Labels use the existing l10n keys.

The switcher must survive the narrow master pane (320 px in the wide layout, per ADR-0030). Implement the DESIGN-006 open-question resolution option 1: icon + label normally, **icon-only** (with tooltips) below a width threshold. Icons: `Icons.update`, `Icons.place`, `Icons.theater_comedy`, `Icons.group`.

Gates green. Commit.

### Step 2 — `feat(program)`: embed station, roleplay and team bodies as segments

Wire the Poster/Markører/Team segments to the existing `StationListView`, `RolePlaysView` and `TeamsView` bodies, reusing the controller instances `MainScreen` holds (pass them into `ProgramView`; do not construct duplicates — see the double-instantiation hazard). Confirm filtering, expansion mutex and detail-sheet navigation still work from inside the Program tab.

Gates green. Commit.

### Step 3 — `feat(program)`: make FAB, AppBar actions and empty pane follow the active segment

Make `ProgramPageController.buildFAB` and `buildActions` switch on `activeSegment` and delegate to the matching existing controller (Øvelser → "Ny øvelse"; Poster → station filter FAB; Markører → `RolePlaysController`'s FAB and cast-roster action; Team → none). Have `MainScreen` rebuild its chrome when `activeSegment` changes. In the wide layout, make `_emptyPaneBuilderForCurrentTab` consult the active segment when the current tab is Program, so the empty detail pane matches (exercise / station / role / team empty pane).

Gates green. Commit.

### Step 4 — `test(program)`: cover segment switching and contextual chrome

Widget tests under `test/` for: the four segments render and switch, switching swaps the body without losing the others' state, the FAB and AppBar actions change with the segment (and Team shows no FAB), and the wide-layout empty pane follows the segment. Do not add regression coverage for unrelated surrounding code.

Gates green. Commit.

## When you finish or get stuck

- After the last step, append a short closing entry to `docs/prompts/DESIGN-006-stage-1-handoff.md` summarizing the landed state and anything stage 2 needs to know.
- Off-scope findings go to `docs/prompts/DESIGN-006-followups.md` (create on first use) as a one-line note each. Do not fix them here. New defects you uncover become their own numbered follow-up rather than extra steps bolted onto this prompt.
- If a step is blocked by an ambiguous spec or an unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-006-stage-1-blockers.md` explaining the blocker and the choice you would otherwise have had to make, then exit rather than guessing.
- **Do not push to GitHub.** Per the DESIGN-006 delivery note, stages 1 and 2 are one release unit. Commit locally and stop. The push happens after stage 2.
