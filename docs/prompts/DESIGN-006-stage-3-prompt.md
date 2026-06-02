You are working in the RingDrill repository. Implement **stage 3 of DESIGN-006** ("Program tab consolidation and Roster layer"): add the collapsing read-only overview above the segment switcher in the Program tab. The authoritative spec is:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — read *Program tab anatomy → Collapsing overview*, *Segmented switcher*, *Sliver structure*, and *Implementation notes → Stage 3*.

Read it in full first. If this prompt contradicts it, the spec wins; stop and ask.

Stages 1 and 2 have landed: the Program tab is segmented (Øvelser/Poster/Markører/Team) and the navigation is collapsed to Program + Map with program-scoped routing. Read `docs/prompts/DESIGN-006-stage-1-handoff.md` and `docs/prompts/DESIGN-006-stage-2-handoff.md` before touching anything.

## What stage 3 is, and is not

Stage 3 adds the overview region at the top of the Program tab. It is additive and main-safe on its own (it ships after the 1+2 release unit, so it may be pushed normally).

**In scope:**

- A **collapsing read-only overview** at the top of the Program tab that scrolls away as the user moves down a long segment list.
- The segment switcher stays **pinned** below the overview, always reachable even after the overview has scrolled off.
- Overview content (all read-only): the active plan's `description` when set and a `briefIntroMd` preview, with a "Les mer" / "Vis mindre" toggle that expands and collapses the prose (shown only when it is long enough to truncate). No counts summary line.
- The brief stays an `Icons.menu_book` AppBar action on the Øvelser lens (its original home). (An earlier revision of this stage moved it into the overview as an "Åpne brief" affordance; it read poorly there and was reverted.)

**Out of scope (do not touch):**

- **No new data-model fields.** `program.briefIntroMd` already exists on the model and is loaded at runtime from `program/intro.md` (`lib/data/drill_file.dart`, ADR-0022), so render a compact read-only preview of it when non-empty (see step 1). Do not add new fields and do not run codegen. `commsMd` stays out of the overview — only the brief intro is previewed, per DESIGN-006.
- **No inline editing and no new `ProgramFormScreen`.** The overview is read-only. Editing `briefIntroMd` is the DESIGN-004 stage 4 markdown editor, out of scope here. Plan rename already exists via the AppBar title tap (`active_actions.renameActivePlan`); do not build a new edit surface. Full brief-field editing is a separate follow-up.
- No routing change (stage 2 done) — reuse the canonical brief path helper.
- No Roster tab (stage 4).
- No `BriefTheme`. Render the overview in plain Material style. The docs-site `BriefTheme` palette (ADR-0023) stays confined to the brief sheet so it does not clash with the working surfaces around it.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** The "Les mer" / "Vis mindre" toggle uses new `showMore` / `showLess` keys in both `app_en.arb` and `app_nb.arb`; run `make build` (gen-l10n) after editing the arb files. Norwegian for *station* stays "post"/"poster".
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

`NestedScrollView` does **not** fit here. It coordinates the header collapse with a single inner `PrimaryScrollController`, but the body is an `IndexedStack` keeping all four segment `ListView`s alive, and they cannot share one controller. The naive workaround (render only the active segment in the body) is rejected: it tears the other three views out of the tree, so it loses each segment view's State — the expansion mutex (`_expandedRowIndex`) and scroll position — and re-subscribes to `ProgramService` on every switch. That is a regression from the stage 1 `IndexedStack`.

Do the collapse manually instead, keeping the `IndexedStack`:

- Keep the Program tab body as `Column[overview, switcher, Expanded[IndexedStack[...]]]`. The switcher stays a normal always-visible widget above the body, which satisfies the "switcher always reachable" goal without a `SliverPersistentHeader`. (The spec's `SliverPersistentHeader` was a suggested mechanism, not the goal.)
- Thread a `ScrollController` into each segment's list (add a `controller` parameter to the exercise list, `StationListView`, `RolePlaysView`, `TeamsView`). Keep one controller per segment so each retains its own offset.
- Collapse or hide the overview based on the **active** segment's scroll offset (or scroll direction, like an app bar hiding on scroll-down and reappearing on scroll-up), driven by listening to the active controller. Swap which controller drives the collapse when the active segment changes.
- The overview reads `controller.activeSegment` to choose which count to show alongside the team count, and rebuilds with it.

All four views stay alive, so no State is lost on switch. If a true continuous sliver-flight collapse is wanted later, that is the heavier path (segments as `CustomScrollView`s with `SliverOverlapInjector` under a `NestedScrollView`, TabBarView-style, keeping `AutomaticKeepAlive`), which means converting every segment body — including the filter banner and the `Positioned` FAB in the Stack — into slivers. Defer it unless the manual collapse feels insufficient.

## Commits

Conventional Commits, scope `program`. One commit per step, `git status` clean between steps. Do not squash.

## Steps

### Step 1 — `feat(program)`: collapsing overview and pinned switcher

Restructure the Program tab body so the read-only overview sits above an always-visible switcher, hiding as the active segment list scrolls. Overview shows the active plan's `description` and a compact preview of `program.briefIntroMd` when non-empty, plus a "Les mer" / "Vis mindre" toggle (shown only when the prose truncates at a few lines) that expands and collapses the full text. Render the prose in plain Material style, **not** `BriefMarkdown` / `BriefTheme` — the docs-site palette (ADR-0023) stays in the brief sheet. There is no counts summary line. Omit each part when its source is empty (the overview collapses to nothing for a bare plan); the switcher must stay present regardless.

Gates green. Commit.

### Step 2 — `feat(program)`: keep the brief as the Øvelser AppBar action

The brief stays the `Icons.menu_book` AppBar action on the Øvelser lens (`_buildExercisesActions`), navigating to the canonical brief path (`programBriefPath(activeProgramUuid)`). The overview carries no brief affordance.

Gates green. Commit.

### Step 3 — `test(program)`: cover the overview

Widget tests under `test/`: the overview renders the description and the `briefIntroMd` preview when non-empty and omits each when empty; the "Les mer" toggle appears only when the prose truncates and expands/collapses it; scrolling the segment list collapses the overview while the switcher stays visible and usable; the Øvelser AppBar shows the brief action and switching segments retains each segment's State. Do not add coverage for unrelated surrounding code.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-006-stage-3-handoff.md` summarizing the landed state, including how the `briefIntroMd` preview is rendered.
- Off-scope findings go to `docs/prompts/DESIGN-006-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here.
- If a step is blocked by an ambiguous spec or unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-006-stage-3-blockers.md`, then exit rather than guessing.
- Stage 3 is additive and post-release-unit, so it may be pushed once green.
