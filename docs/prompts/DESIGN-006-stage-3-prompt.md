You are working in the RingDrill repository. Implement **stage 3 of DESIGN-006** ("Program tab consolidation and Roster layer"): add the collapsing read-only overview above the segment switcher in the Program tab. The authoritative spec is:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — read *Program tab anatomy → Collapsing overview*, *Segmented switcher*, *Sliver structure*, and *Implementation notes → Stage 3*.

Read it in full first. If this prompt contradicts it, the spec wins; stop and ask.

Stages 1 and 2 have landed: the Program tab is segmented (Øvelser/Poster/Markører/Team) and the navigation is collapsed to Program + Map with program-scoped routing. Read `docs/prompts/DESIGN-006-stage-1-handoff.md` and `docs/prompts/DESIGN-006-stage-2-handoff.md` before touching anything.

## What stage 3 is, and is not

Stage 3 adds the overview region at the top of the Program tab. It is additive and main-safe on its own (it ships after the 1+2 release unit, so it may be pushed normally).

**In scope:**

- A **collapsing read-only overview** at the top of the Program tab that scrolls away as the user moves down a long segment list.
- The segment switcher stays **pinned** below the overview, always reachable even after the overview has scrolled off.
- Overview content (all read-only): a plan summary line (team count `numberOfTeams` plus a count for the active segment, e.g. station count for Poster), the active plan's `description` when present, and an **"Åpne brief"** affordance.
- "Åpne brief" opens the brief at the canonical program-scoped path from stage 2 (the `programBriefPath(uuid)` helper), and the existing brief AppBar action on the Øvelser segment is **removed** so the overview becomes the single brief entry point for the Program tab.

**Out of scope (do not touch):**

- **No new data-model fields.** DESIGN-006 reserves overview space for the program-level brief fields `program.briefIntroMd` / `program.commsMd` (DESIGN-004), but those do not exist in code yet (`program.dart` has only `description`). Ship the overview with the summary line and `description`, and leave a clear seam to add the brief-intro preview when those fields land. Do not add them here.
- **No inline editing and no new `ProgramFormScreen`.** The overview is read-only. Plan rename already exists via the AppBar title tap (`active_actions.renameActivePlan`); do not build a new edit surface. Full brief-field editing is a separate follow-up.
- No routing change (stage 2 done) — reuse the canonical brief path helper.
- No Roster tab (stage 4).
- No `BriefTheme`. Render the overview in plain Material style. The docs-site `BriefTheme` palette (ADR-0023) stays confined to the brief sheet so it does not clash with the working surfaces around it.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** New labels ("Åpne brief", the summary-line units) go in both `app_en.arb` and `app_nb.arb`. Reuse existing count nouns (`team(n)`, `station(n)`, etc.) where they exist. Norwegian for *station* stays "post"/"poster".
- **CLI must stay Flutter-free.** Widget-layer only.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **No new Sentry/analytics calls.**
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.** No codegen expected.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Investigate before you wire (do this first, no commit)

1. The current Program tab body. `ProgramView.build` returns `Column[_ProgramSegmentSwitcher, Expanded[ValueListenableBuilder → IndexedStack[exerciseBody, StationListView, RolePlaysView, TeamsView]]]`. The four segment bodies are box scrollables (ListView/Padding), not slivers.
2. How each segment body scrolls today, and whether it already owns a scroll controller, since the collapse must be driven by scrolling the active segment's list.
3. The canonical brief path helper added in stage 2 (`programBriefPath`, and how `_buildExercisesActions` in `program_view.dart` currently pushes the brief). Confirm the active program uuid source (`ProgramService.activeProgramUuid`).
4. Count sources on `ProgramService` for the summary line: exercises, stations, roleplays, teams (`loadExercises().length`, `loadTeams().length`, etc.).
5. `active_actions.renameActivePlan` and the existing AppBar title-tap rename, so the overview does not duplicate plan editing.

Append a short note of what you found to `docs/prompts/DESIGN-006-stage-3-handoff.md` (create it) before step 1.

### Recommended approach (adopt unless investigation shows a cheaper path)

- Restructure the Program tab body as a `NestedScrollView`: `headerSliverBuilder` returns the overview as a collapsing sliver (a `SliverToBoxAdapter`, or a `SliverAppBar`-style region that scrolls off) followed by the switcher as a **pinned** `SliverPersistentHeader`; the `body` is the existing `IndexedStack` of segment bodies. This keeps the box-scrollable segment bodies as-is and gets the "overview scrolls away, switcher stays" behaviour for free.
- **Validate the caveat:** `NestedScrollView` coordinates with the body's scrollable, and the body here is an `IndexedStack` keeping all four bodies alive. Confirm the active segment's list drives the header collapse cleanly (you may need `SliverOverlapAbsorber` / the inner controller, or to wrap each body so it participates). If `NestedScrollView` fights the `IndexedStack`, the fallback is to render only the active segment's body inside the `NestedScrollView` body (dropping per-segment scroll-position retention) rather than forcing every segment view into slivers.
- The overview reads `controller.activeSegment` to choose which count to show alongside the team count, and rebuilds with it.

## Commits

Conventional Commits, scope `program`. One commit per step, `git status` clean between steps. Do not squash.

## Steps

### Step 1 — `feat(program)`: collapsing overview and pinned switcher

Restructure the Program tab body so the read-only overview sits above a pinned switcher, scrolling away as the active segment list scrolls. Overview shows the summary line (team count + active-segment count) and the active plan's `description` when present, in plain Material style. Leave a clearly-commented seam where the `briefIntroMd` preview will go once that field exists. Handle the near-empty case gracefully (a fresh plan may have only the summary line); the switcher must stay present and pinned regardless.

Gates green. Commit.

### Step 2 — `feat(program)`: wire "Åpne brief" and retire the per-segment brief action

Add the "Åpne brief" affordance to the overview, navigating to the canonical brief path (`programBriefPath(activeProgramUuid)`). Remove the brief `IconButton` from `_buildExercisesActions` so the Øvelser segment no longer carries it in the AppBar; the overview is now the single brief entry point for the Program tab.

Gates green. Commit.

### Step 3 — `test(program)`: cover the overview

Widget tests under `test/`: the overview renders the summary line and description; the summary's segment count follows the active segment; scrolling the segment list collapses the overview while the switcher stays pinned and usable; "Åpne brief" navigates to the canonical brief path; the Øvelser AppBar no longer shows the brief action. Do not add coverage for unrelated surrounding code.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-006-stage-3-handoff.md` summarizing the landed state and the reserved brief-field seam.
- Off-scope findings go to `docs/prompts/DESIGN-006-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here.
- If a step is blocked by an ambiguous spec or unmet precondition (for example `NestedScrollView` not coordinating with the `IndexedStack`), stop and write a one-paragraph note to `docs/prompts/DESIGN-006-stage-3-blockers.md`, then exit rather than guessing.
- Stage 3 is additive and post-release-unit, so it may be pushed once green.
