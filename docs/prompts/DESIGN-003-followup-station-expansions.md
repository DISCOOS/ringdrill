You are working in the RingDrill repository. This is the third follow-up to DESIGN-003. The previous follow-ups landed the Station-screen authoring section (`DESIGN-003-followup-creating-roles.md`) and the Markører-tab polish plus active-program guards (`DESIGN-003-followup-tile-and-form-anatomy.md`).

Manual inspection then surfaced a missing piece: two surfaces render stations as expandable rows but do not show the role briefs (markørordrer) attached to each station. A coordinator browsing the coordinator screen or the Stations tab has to navigate into a dedicated Station screen to see the roles, even though there is room to summarize them inline. This follow-up adds a **read-only** summary to both surfaces. Authoring stays on the dedicated Station screen — the new summary rows are pure browse affordances.

Read these before you start:

- `docs/design/roleplays-tab.md` (revised), specifically the new **Station-expansion summary** section. That section is the authoritative spec for this follow-up.
- `docs/prompts/DESIGN-003-implementation-prompt.md` for the conventions the main loop established (ground rules, commit format, handoff pattern, token discipline).
- `docs/prompts/DESIGN-003-handoff.md` for the state established by the main loop and earlier follow-ups. Trust the handoff over re-reading files it asserts state on.

If anything in this prompt appears to contradict the design doc, the design wins. Stop and ask.

## Ground rules

The non-negotiables from `AGENTS.md` carry over unchanged. Highlights:

- No model changes are expected. `make build` is triggered automatically by `flutter analyze`/`test` after ARB edits.
- Localize every user-visible string in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Reuse existing keys where possible.
- CLI stays Flutter-free, mobile-safe imports stay mobile-safe, no new lint suppressions.
- `flutter analyze` and `flutter test` must be clean before any step is committed. `test/widget_test.dart` is the known-broken default-template smoke test; flag it rather than fixing it.

## Token discipline

Token discipline from `DESIGN-003-implementation-prompt.md` applies unchanged. Read the handoff first; do not re-read files it asserts state on. Append to the handoff at step end.

If a step cannot complete because state has drifted, stop and write to `docs/prompts/DESIGN-003-blockers.md` rather than improvising.

## Verified facts (do not re-discover)

These were confirmed against the current tree before this prompt was written.

- **`lib/views/coordinator_screen.dart`** holds `_buildStationList` (around line 696) and `_buildStationDetail` (around line 855). `_buildStationDetail` is the inline expansion body for a station row on the coordinator screen. It currently renders description and `StationPositionPanel` and nothing else. The exercise context is `_exercise!`, a non-null field on the screen's state.
- **`lib/views/station_list_view.dart`** holds `_buildExpandedBody` (around line 244). It is the expansion body for a station row on the Stations tab. It currently renders description and `StationPositionPanel` and nothing else. The exercise context is the `exercise` parameter passed to the row builder.
- **`lib/views/widgets/role_expansion_tile.dart`** exports `RoleCodeBadge`. Not needed for this follow-up because the summary rows use a compact theatre glyph rather than the full badge, mirroring the Station-screen Markører section landed in the first follow-up.
- **`lib/views/roleplay_screen.dart`** exposes `RolePlayScreen({required String rolePlayUuid})` for the read view. The new summary rows navigate to it on tap.
- **`ProgramService`** exposes `loadRolePlays()` and `loadActors()`. Filter for roles attached to a station with `r.exerciseUuid == exercise.uuid && r.stationIndex == stationIndex`.
- **ARB key `stationRolesSection`** ("Markører" / "Roles") was added by the first follow-up and is reused here as the section header label.
- **Icon family for actor surfaces** (set by the previous follow-up):
  - `Icons.theater_comedy` — leading icon on a single role row, also the Markører-tab nav icon.
  - `Icons.person` (filled) / `Icons.person_add_outlined` (outlined) — the cast affordance pair. In the new summary, the chip is **non-interactive**, used purely as a state indicator.

## Commits

Conventional Commits with a scope. Same format as the main loop. Scopes that fit: `roleplay`, `station`, `coordinator`, `widget`.

## Loop control

Three steps. Each is one commit. Headings carry the keyword the loop matches against `git log`.

## Scope and step order

### Step 1. **widget**: extract `StationRoleSummary` widget

New file `lib/views/widgets/station_role_summary.dart`. A self-contained widget that takes an `Exercise` and a `stationIndex`, looks up the roles attached to that station, and renders a compact read-only summary section. Returns `SizedBox.shrink()` when no roles match, so callers can drop the widget into any vertical layout without having to gate it themselves.

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
            Icon(
              Icons.theater_comedy,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              localizations.stationRolesSection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 6),
            Text(
              '(${roles.length})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...roles.map((r) => _RoleSummaryRow(role: r, actor: actors[r.actorUuid])),
      ],
    );
  }
}
```

Private `_RoleSummaryRow`:

- Leading: `Icon(Icons.theater_comedy, size: 18)` (matches the Station-screen Markører section landed in the first follow-up).
- Title: `role.name` only. **No** age suffix and **no** cast actor parens. The cast suffix on the title belongs to the Markører-tab tile only per DESIGN-003 §Tile anatomy. Other surfaces stay clean.
- Trailing: cast chip, **non-interactive**. `Icon(Icons.person)` filled when `actor != null`, `Icon(Icons.person_add_outlined)` when not. Wrap in a `Chip` or a thin `Container` to match the chip styling used by the Markører tab. No `InkWell`, no `onTap` on the chip — this is a read-only surface; the cast picker is reachable through the Station screen and the Markører tab.
- Row body `onTap`: push `RolePlayScreen(rolePlayUuid: role.uuid)`.
- No `Dismissible`, no swipe affordances, no overflow menu, no `Icons.delete`.

Widget tests under `test/views/widgets/station_role_summary_test.dart`:

- Returns `SizedBox.shrink()` when no roles match the `(exerciseUuid, stationIndex)` pair.
- Renders the header with the right count when roles exist.
- Renders one row per matching role, with the role name as the title.
- Cast chip is filled when actor is present, outlined when null.
- Tapping a row body pushes `RolePlayScreen` with the right uuid.
- No `Dismissible`, no `Icons.delete`, no tappable `InkWell` on the cast chip.

Commit: `feat(widget): add StationRoleSummary for inline station expansions`.

### Step 2. **station**: integrate the summary on both expansion surfaces

Two small edits, one commit.

**A. Coordinator screen.** Edit `lib/views/coordinator_screen.dart`. In `_buildStationDetail` (around line 855), append a `StationRoleSummary(exercise: _exercise!, stationIndex: stationIndex)` after the existing `StationPositionPanel` block. Keep the same `Padding` wrapper conventions used by neighbouring children.

**B. Stations tab.** Edit `lib/views/station_list_view.dart`. In `_buildExpandedBody` (around line 244), append a `StationRoleSummary(exercise: exercise, stationIndex: station.index)` after the existing `StationPositionPanel`. Use the same children-list shape — `const SizedBox(height: 12)` between sections matches the existing rhythm on this surface.

Both calls rely on `StationRoleSummary` returning `SizedBox.shrink()` when no roles match, so neither caller needs an explicit "if roles exist" check.

Import `package:ringdrill/views/widgets/station_role_summary.dart` in both files.

Quick smoke checks:

- Open a station on the coordinator screen that has roles attached. The expansion shows description, position panel, then a "Markører (<n>)" section with one row per role.
- Open the same station from the Stations tab. Same section appears with the same rows.
- Open a station with no roles. Neither surface renders a Markører header or empty hint; the layout is identical to before the change.
- Tapping a row navigates to `RolePlayScreen` for that role.

Commit: `feat(station): show inline markørordre summary in station expansions`.

### Step 3. **test**: sweep and final verification

Two cleanup tasks.

1. Grep for the call sites and confirm the import lines are clean:

   ```
   grep -rn "StationRoleSummary" lib/ test/
   ```

   Both call sites in `coordinator_screen.dart` and `station_list_view.dart` should appear. Tests should reference the widget in `station_role_summary_test.dart`. No orphan imports.

2. Run the full verification:
   - `flutter analyze` clean.
   - `flutter test` passes (except the known-broken `test/widget_test.dart`).
   - `make build` runs without diff.

Commit: `test(roleplay): cover StationRoleSummary in station-expansion surfaces`.

## Verification

After all three steps:

1. `flutter analyze` clean.
2. `flutter test` passes (except the known-broken `test/widget_test.dart`).
3. `make build` runs without diff.
4. Manual QA (record in the PR description):
   - Open the coordinator screen for an exercise with roles attached to one or more stations. Expand a station that has roles. The expansion shows description, position panel, and a "Markører (n)" section listing each attached role with a non-interactive cast chip and the theatre glyph. Tapping a role row opens `RolePlayScreen`.
   - Expand a station with no roles. No Markører header or empty hint is rendered. Visual layout matches the pre-change baseline.
   - Repeat on the Stations tab. Same behaviour, same rendering.
   - Confirm the cast chip is not tappable — no ripple, no cast picker opens on tap. The Station screen and the Markører tab remain the only paths to casting.
   - Confirm no swipe-edit, no swipe-delete, no overflow menu on the summary rows.

## Out of scope

- **Authoring from the summary rows.** "+ Legg til markørordre", edit-via-swipe and cast-chip-tap are reserved for the dedicated Station screen and the Markører tab. The summary rows are pure browse affordances.
- **Cast suffix on the title.** The `(actor name)` cast suffix is only on the Markører-tab tile title per DESIGN-003 §Tile anatomy. Summary rows render `role.name` only.
- **Empty-state hint when no roles exist.** None is rendered; the section disappears entirely. Operators familiar with the existing description-and-map expansion will see no extra content, so the change is additive and unobtrusive when no roles are present.
- **Refresh on role mutation.** The summary reads from `ProgramService` on each build. Mutating a role elsewhere does not automatically rebuild this expansion. The next time the user collapses and re-expands (or scrolls and rebuilds) the section, the data is fresh. A listener-based refresh is a future improvement, not in scope here.

## Deliverables

Three commits, in order, that together:

- Add the reusable `StationRoleSummary` widget with read-only rows and a static cast-state chip.
- Integrate it into the coordinator screen's `_buildStationDetail` and the Stations tab's `_buildExpandedBody`.
- Add widget and integration tests and verify the gates.

DESIGN-003 §Station-expansion summary is the authoritative spec.
