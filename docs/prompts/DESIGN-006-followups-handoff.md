# DESIGN-006 follow-ups handoff

## Session: 2026-06-02

### What landed

All four steps from `DESIGN-006-followups-prompt.md` are complete.

| Commit | Step |
|--------|------|
| `1591bd1` | `fix(widget)`: heroTag: null on both filter FABs |
| `77a8259` | `feat(roleplay)`: "Ny rolle" FAB on Markører segment; filter moved to AppBar action |
| `410c022` | `feat(settings)`: AppUserRole preference + brief default → director |

**Step 1** — `fix(widget)`: `heroTag: null` set on `_buildFilterFab` in both
`station_list_view.dart` and `roleplays_view.dart`. The roleplay FAB was
subsequently removed entirely in Step 2.

**Step 2** — `feat(roleplay)`: The Markører segment now has a "Ny rolle" FAB.
Tapping it opens an exercise-picker sheet (all exercises in the plan), then
`RolePlayFormScreen` pre-scoped to the chosen exercise with a blank `RolePlay`
draft. The body filter FAB is retired; filtering moved to `Icons.filter_list`
in the AppBar actions with a `Badge.count(1)` when active, keeping the
existing banner + "Vis alle" recovery. `noRolesInProgram` empty-state text
updated to point to the + FAB rather than the removed Stations tab.

**Steps 3+4** — `feat(settings)`: New `AppUserRole` enum (`director` /
`instructor`). Stored under `app:appUserRole:v1` in SharedPreferences. Added
`AppUserRoleSettings` widget to both native and web `SettingsPage` (radio
group: Øvelsesleder / Veileder). `BriefScreen` now defaults to
`BriefAudience.director` (was `participant`) and async-loads the stored role
on open, re-rendering once if different from default. Tests updated to match
new default.

### Still open

- **DESIGN-006-followups item 5** (`PhaseTile` horizontal overflow at 700 px
  viewport, 314 px content width overflows `Row` in `lib/views/phase_tile.dart`
  by ~10 px). Kept separate per the followups list.
- **DESIGN-006 implementation stages 3–4** (overview sliver, Roster tab) —
  not part of these follow-ups; tracked in the main DESIGN-006 doc.
