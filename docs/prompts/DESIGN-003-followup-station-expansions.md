You are working in the RingDrill repository. This is the fourth follow-up to DESIGN-003. The previous follow-ups are `DESIGN-003-followup-creating-roles.md` (Station-screen authoring section), `DESIGN-003-followup-tile-and-form-anatomy.md` (Markører-tab polish plus active-program guards) and `DESIGN-003-followup-station-row-and-routing.md` (nested `/roleplays/:roleUuid` route plus the two-line Station-screen row anatomy with age and cast subtitle).

This follow-up addresses one remaining gap: two surfaces render stations as expandable rows but do not show the role briefs (markørordrer) attached to each station. A coordinator browsing the coordinator screen or the Stations tab has to navigate into a dedicated Station screen to see the roles, even though there is room to summarize them inline. This follow-up adds a **read-only** summary to both surfaces. Authoring stays on the dedicated Station screen — the new summary rows are pure browse affordances.

The row anatomy on the browse summaries reuses the exact two-line layout the third follow-up established for the Station-screen Markører section: leading `Icons.theater_comedy`, role name (with age suffix when set) on the title line, "Spilles av <name>" or "Ingen markør valgt" on the subtitle line, trailing cast chip. The only difference is interaction — the browse cast chip is **non-interactive**, no swipe affordances, no header action.

Read these before you start:

- `docs/design/roleplays-tab.md` (revised), specifically the **Station-expansion summary** section and the **Creating roles** §Station screen "Markører" section it now references for the shared row anatomy. The **Tile anatomy** rules also matter because they scope the cast-actor parens to the Markører-tab tile only.
- `docs/prompts/DESIGN-003-followup-station-row-and-routing.md` for the routing fix and the ARB keys (`castedByLine`, `noCastLine`) that this follow-up reuses. That follow-up must land before this one.
- `docs/prompts/DESIGN-003-implementation-prompt.md` for the conventions the main loop established.
- `docs/prompts/DESIGN-003-handoff.md` for the state established by the main loop and earlier follow-ups. Trust the handoff over re-reading files it asserts state on.

If anything in this prompt appears to contradict the design doc, the design wins. Stop and ask.

## Ground rules

The non-negotiables from `AGENTS.md` carry over unchanged. Highlights:

- No model changes are expected. ARB edits trigger l10n codegen on the next `flutter analyze`/`test`.
- Localize every user-visible string in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Reuse existing keys where possible — this follow-up should not need new ARB keys; `castedByLine`, `noCastLine` and `stationRolesSection` already cover the summary.
- CLI stays Flutter-free, mobile-safe imports stay mobile-safe, no new lint suppressions.
- `flutter analyze` and `flutter test` must be clean before any step is committed. `test/widget_test.dart` is the known-broken default-template smoke test; flag it rather than fixing it.

## Token discipline

Token discipline from `DESIGN-003-implementation-prompt.md` applies unchanged. Read the handoff first; do not re-read files it asserts state on. Append to the handoff at step end.

If a step cannot complete because state has drifted, stop and write to `docs/prompts/DESIGN-003-blockers.md` rather than improvising.

## Verified facts (do not re-discover)

These were confirmed against the current tree before this prompt was written.

- **`lib/views/coordinator_screen.dart`** holds `_buildStationList` (around line 696) and `_buildStationDetail` (around line 855). `_buildStationDetail` is the inline expansion body for a station row on the coordinator screen. It currently renders description and `StationPositionPanel` and nothing else. The exercise context is `_exercise!`, a non-null field on the screen's state.
- **`lib/views/station_list_view.dart`** holds `_buildExpandedBody` (around line 244). It is the expansion body for a station row on the Stations tab. It currently renders description and `StationPositionPanel` and nothing else. The exercise context is the `exercise` parameter passed to the row builder.
- **`lib/views/roleplay_screen.dart`** exposes `RolePlayScreen({required String rolePlayUuid})` for the read view. The nested `/roleplays/:roleUuid` route was registered in the third follow-up, so summary rows can navigate with `context.push('$routeRolePlays/${role.uuid}')`.
- **`lib/views/widgets/role_expansion_tile.dart`** exports `RoleCodeBadge`. Not needed here because the summary rows use the compact theatre glyph (size ~18), matching the Station-screen Markører row from the third follow-up.
- **`ProgramService`** exposes `loadRolePlays()` and `loadActors()`. Filter for roles attached to a station with `r.exerciseUuid == exercise.uuid && r.stationIndex == stationIndex`.
- **ARB keys already in place**: `stationRolesSection` ("Markører" / "Roles") from the first follow-up, `castedByLine` ("Spilles av {name}" / "Played by {name}") and `noCastLine` ("Ingen markør valgt" / "No actor selected") from the third follow-up. No new keys are introduced in this follow-up.
- **Icon family for actor surfaces** (set by the previous follow-ups):
  - `Icons.theater_comedy` — leading icon on a single role row, also the Markører-tab nav icon.
  - `Icons.person` (filled) / `Icons.person_add_outlined` (outlined) — the cast affordance pair. Interactive on the Station-screen authoring section. **Non-interactive** on the browse summaries this follow-up adds: render the icon directly, no `IconButton` wrapper, no `onTap`, no tooltip.

## Commits

Conventional Commits with a scope. Same format as the main loop. Scopes that fit: `widget`, `station`, `coordinator`, `test`.

## Loop control

Three steps. Each is one commit. Headings carry the keyword the loop matches against `git log`.

## Scope and step order

### Step 1. **widget**: extract `StationRoleSummary`

New file `lib/views/widgets/station_role_summary.dart`. A self-contained widget that takes an `Exercise` and a `stationIndex`, looks up the roles attached to that station, and renders a compact **read-only** summary section. Returns `SizedBox.shrink()` when no roles match, so callers can drop the widget into any vertical layout without local gating.

Shape:

```dart
class StationRoleSummary extends StatelessWidget {
  const StationRoleSummary({
    super.key,
    required this.exercise,
    required this.stationIndex,
  });

  final Exercise exercise;
  final int stationIndex;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = ProgramService();
    final roles = service.loadRolePlays()
        .where((r) =>
            r.exerciseUuid == exercise.uuid &&
            r.stationIndex == stationIndex)
        .toList();
    if (roles.isEmpty) return const SizedBox.shrink();
    final actors = {for (final a in service.loadActors()) a.uuid: a};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.theater_comedy, size: 18,
                color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(localizations.stationRolesSection,
                style: theme.textTheme.titleSmall),
            const SizedBox(width: 6),
            Text('(${roles.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        ...roles.map((r) => _RoleSummaryRow(
          role: r,
          actor: actors[r.actorUuid],
        )),
      ],
    );
  }
}
```

Private `_RoleSummaryRow`:

- **Layout matches the Station-screen Markører row from the third follow-up** (`DESIGN-003-followup-station-row-and-routing.md` Step 3): leading `Icon(Icons.theater_comedy, size: 20, color: colorScheme.onSurfaceVariant)`, two-line `Column` in an `Expanded` child with title (`role.name`, with `, <age>` suffix when `role.age != null`) and subtitle (`localizations.castedByLine(actor.realName)` when cast, `localizations.noCastLine` when not), trailing cast-state icon. The italic + lowered-opacity styling for the uncast subtitle mirrors the Station-screen row exactly.
- **Title rule.** Cast-actor parens never appear on this title. DESIGN-003 §Tile anatomy scopes the parenthetical cast suffix to the Markører-tab tile only.
- **Tap on the row body**: `context.push('$routeRolePlays/${role.uuid}')`. The route was registered in the third follow-up.
- **Trailing cast chip is non-interactive**: render `Icon(Icons.person)` (with `colorScheme.primary` when cast) or `Icon(Icons.person_add_outlined)` (with `colorScheme.onSurfaceVariant` when not) directly, **without** an `IconButton` or `InkWell` wrapper. No `onTap`, no tooltip.
- No `Dismissible`, no swipe affordances, no overflow menu, no `Icons.delete`.

The visual identity with the Station-screen rows is intentional: an operator scanning either surface sees the same row shape. The difference is interaction (browse surfaces are read-only). The surrounding screen context tells the operator which surface they are on.

Widget tests under `test/views/widgets/station_role_summary_test.dart`:

- Returns `SizedBox.shrink()` when no roles match the `(exerciseUuid, stationIndex)` pair.
- Renders the header with the right count when roles exist.
- Renders one row per matching role with the right title (age suffix when set) and subtitle (cast info or "Ingen markør valgt").
- Subtitle style is italic + lowered-opacity when uncast, regular otherwise (mirrors the Station-screen row test from the third follow-up).
- Cast chip is non-interactive: no `InkWell`, no `IconButton`, no `onTap`.
- Tapping a row body pushes `/roleplays/<uuid>`.
- No `Dismissible`, no `Icons.delete`.

Commit: `feat(widget): add StationRoleSummary for inline station expansions`.

### Step 2. **station**: integrate the summary on both expansion surfaces

Two small edits, one commit.

**A. Coordinator screen.** Edit `lib/views/coordinator_screen.dart`. In `_buildStationDetail` (around line 855), append a `StationRoleSummary(exercise: _exercise!, stationIndex: stationIndex)` after the existing `StationPositionPanel` block. Keep the same `Padding` wrapper conventions used by neighbouring children.

**B. Stations tab.** Edit `lib/views/station_list_view.dart`. In `_buildExpandedBody` (around line 244), append a `StationRoleSummary(exercise: exercise, stationIndex: station.index)` after the existing `StationPositionPanel`. Use the same spacing rhythm — `const SizedBox(height: 12)` between sections.

Both calls rely on `StationRoleSummary` returning `SizedBox.shrink()` when no roles match, so neither caller needs an explicit "if roles exist" check.

Import `package:ringdrill/views/widgets/station_role_summary.dart` in both files.

Smoke checks:

- Coordinator screen: expand a station that has roles. Markører section appears after the position panel with one row per attached role, using the same two-line layout as the dedicated Station screen.
- Stations tab: same behaviour.
- Stations with no roles: neither header nor empty hint renders.
- Tap a row: `RolePlayScreen` opens via the route registered in the third follow-up.
- Cast chip on a summary row: no ripple, no picker, no tooltip. The chip is a state indicator only.

Commit: `feat(station): show inline markørordre summary on coordinator and Stations-tab expansions`.

### Step 3. **test**: sweep and final verification

Two cleanup tasks.

1. Grep for the call sites and confirm the import lines are clean:

   ```
   grep -rn "StationRoleSummary" lib/ test/
   grep -rn "castedByLine\|noCastLine" lib/ test/
   ```

   All three call sites of `StationRoleSummary` should appear (widget definition + two integrations). The two ARB getters should appear in both the Station-screen row (from the third follow-up) and the new summary widget — at least four hits total across `lib/` and the corresponding test files.

2. Run the full verification:
   - `flutter analyze` clean.
   - `flutter test` passes (except the known-broken `test/widget_test.dart`).
   - `make build` runs without diff.

Commit: `test(roleplay): cover StationRoleSummary on browse surfaces`.

## Verification

After all three steps:

1. `flutter analyze` clean.
2. `flutter test` passes (except the known-broken `test/widget_test.dart`).
3. `make build` runs without diff.
4. Manual QA (record in the PR description):
   - Open the coordinator screen for an exercise with roles attached to one or more stations. Expand a station that has roles. The expansion shows description, position panel, then a "Markører (n)" section. Rows have the same age + cast-subtitle layout as the dedicated Station-screen rows. Cast chip is **not** tappable (no ripple, no picker on tap). Tapping a row navigates to `RolePlayScreen`.
   - Repeat on the Stations tab. Same behaviour, same rendering.
   - Expand a station with no roles on either surface. No Markører header or empty hint is rendered.
   - Confirm no swipe-edit, no swipe-delete, no overflow menu on the browse summary rows.

## Out of scope

- **Authoring from the browse summary rows.** "+ Legg til markørordre", edit-via-swipe and cast-chip-tap are reserved for the dedicated Station screen and the Markører tab. The browse summary rows are pure browse affordances.
- **Cast suffix on the title.** The `(actor name)` parenthetical on the title is only on the Markører-tab tile per DESIGN-003 §Tile anatomy. Browse summary rows convey cast info through the subtitle line, not the title.
- **Refresh on role mutation.** The summary reads from `ProgramService` on each build. Mutating a role elsewhere does not automatically rebuild a coordinator-screen or Stations-tab expansion. The next collapse-and-re-expand picks up the change. A listener-based refresh is a future improvement.
- **Anything covered by the third follow-up** (routing fix, Station-screen row enrichment, the two new ARB keys). That work must land first; this follow-up assumes it is in place.
- **Deletion of `RolePlay` records.** DESIGN-003 §Deletion and templating defers this. Do not add it on any surface.
- **Observer-player Role tab.** Still waiting on the DESIGN-001 shell.

## Deliverables

Three commits, in order, that together:

- Add the reusable `StationRoleSummary` widget with the shared two-line row layout and a non-interactive cast-state chip.
- Integrate it into the coordinator screen's `_buildStationDetail` and the Stations tab's `_buildExpandedBody`.
- Add widget and integration tests and verify the gates.

DESIGN-003 §Station-expansion summary is the authoritative spec, with the row anatomy delegated to §Creating roles (Station screen "Markører" section).
