# DESIGN-006 Stage 3 — Handoff notes

## Investigation summary (pre-implementation)

**Insertion point.** The current `ProgramView.build` returns
`Column[_ProgramSegmentSwitcher, Expanded[ValueListenableBuilder → IndexedStack]]`
(`lib/views/program_view.dart:205-225`). Stage 3 replaces this `Column` with a
`NestedScrollView` whose `headerSliverBuilder` carries the overview sliver
(scrolls off) and a pinned switcher sliver, and whose `body` carries the active
segment widget.

**IndexedStack coordination caveat → fallback adopted.** The original plan
attempted NestedScrollView + IndexedStack coordination via per-child
`PrimaryScrollController` scoping. In practice wrapping stable-position children
in a new ancestor (to isolate inactive scroll controllers) causes Flutter to
unmount the child's subtree on each segment switch, defeating the state-retention
goal of IndexedStack. The fallback from the stage-3 prompt was therefore adopted:
only the active segment's body is rendered inside `NestedScrollView.body`. Per-
segment scroll position and expansion state (e.g., expanded station tile in
`StationListView`) are lost on segment switch. The `_expandedExerciseUuid` in
`_ProgramViewState` survives because it lives on the parent state, not the
segment body's state.

**`briefIntroMd` / `commsMd` already exist.** Both `program.briefIntroMd`,
`program.commsMd`, and `program.beforeRoundMd` are declared on `Program`
(`lib/models/program.dart:31-34`) as sidecar markdown fields
(`@JsonKey(includeFromJson: false, includeToJson: false)`). The spec/prompt claim
they don't exist yet — this is incorrect. However, `ProgramService.activeProgram`
never populates them (only the `.drill` archive reader at `lib/data/drill_file.dart`
does), so in practice they are null unless the user loaded from a catalog/import.
Stage 3 renders `briefIntroMd` when non-null/non-empty (compact first-paragraph
preview), and leaves `commsMd` as a commented seam for DESIGN-004 follow-up.

**Brief path helper.** `programBriefPath(uuid)` is at `lib/views/app_routes.dart:27`.
The existing `_buildExercisesActions` at `lib/views/program_view.dart:765-777`
pushes it via `GoRouter.of(context).push(programBriefPath(...))`. The same call
is used for the overview "Åpne brief" affordance.

**Count sources.** Team count: `ProgramService().loadTeams().length`.
Exercise count: `ProgramService().loadExercises().length`. Station count:
`ProgramService().loadExercises().fold(0, (n, e) => n + e.stations.length)`.
RolePlay count: `ProgramService().loadRolePlays().length`.

**Segment switcher height.** `_ProgramSegmentSwitcher` renders inside
`Padding(EdgeInsets.fromLTRB(8, 8, 8, 0))` + `SegmentedButton` (M3 height 40).
Total ≈ 48 px — used as `minExtent`/`maxExtent` for the pinned
`SliverPersistentHeaderDelegate`.

**Rename not duplicated.** Plan rename is handled by the AppBar title tap via
`active_actions.renameActivePlan` (`lib/views/active_plan_actions.dart:68-76`).
The overview only shows read-only content.

**l10n.** Existing keys reused: `briefAction`, `team(n)`, `station(n)`,
`exercise(n)`. New key `roleplay` added as ICU plural.

## Landing summary (post-implementation)

Stage 3 landed. The Program tab body is now a `NestedScrollView` with:

- A `SliverToBoxAdapter` carrying `_ProgramOverview` (scrolls off): summary line
  (`team(n) · <segment-count>`), optional `description`, optional `briefIntroMd`
  first-paragraph preview, and "Åpne brief" `TextButton.icon`.
- A pinned `SliverPersistentHeader` (`_SegmentSwitcherDelegate`, height 48) carrying
  `_ProgramSegmentSwitcher`.
- `body`: active-only segment rendering via `ValueListenableBuilder` + `switch`.

The brief `IconButton` was removed from `_buildExercisesActions`; the overview
is now the single brief entry point for the Program tab.

Reserved seam: `// TODO(DESIGN-004): render program.commsMd preview here when
briefing fields land.` is left as a commented block in `_ProgramOverview`.

Per-segment scroll position / expansion state (e.g., expanded station tile) is
no longer retained across segment switches — accepted trade-off of the fallback
approach. Widget tests updated accordingly.
