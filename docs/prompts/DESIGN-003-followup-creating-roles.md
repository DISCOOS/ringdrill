You are working in the RingDrill repository. Implement the "Creating roles" section that was added to `docs/design/roleplays-tab.md` after the main DESIGN-003 loop landed. The previous loop built the RolePlays tab, the cast picker, the cast roster sheet, the map markers, the data model and `RolePlayScreen`/`RolePlayFormScreen`, but missed the authoring entry point: there is no way to create a new `RolePlay` from the UI today. This follow-up closes that gap by adding a "Markører" section to the Station screen.

Read these before you start:

- `docs/design/roleplays-tab.md` (revised 2026-05-24), specifically the sections **Creating roles**, **Deletion and templating**, and the **Terminology note** at the top. These are the authoritative spec for this change.
- `docs/prompts/DESIGN-003-implementation-prompt.md` for the conventions the main loop established (ground rules, commit format, handoff pattern, token discipline).
- `docs/prompts/DESIGN-003-handoff.md` for the state established by the main loop. Trust the handoff over re-reading the files it asserts state on. Note that Steps 6–8 and 18 are blocked (see `docs/prompts/DESIGN-003-blockers.md`); they are out of scope here too.

If anything in this prompt appears to contradict the design doc, the design wins. Stop and ask.

## Ground rules

The non-negotiables from `AGENTS.md` carry over unchanged. Highlights for this change:

- No model changes are expected. `make build` is only needed if you touch a `@freezed` class or an ARB file. ARB changes trigger l10n codegen on the next `flutter analyze`/`test`/`run`/`build`.
- Localize every user-visible string in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Follow the **terminology rule** from the revised design doc: *Markørordre* for singular naming of the `RolePlay` entity, *Markører* for lists and counts, *Markør* for the human (`Actor`).
- CLI stays Flutter-free, mobile-safe imports stay mobile-safe, no new lint suppressions.
- `flutter analyze` and `flutter test` must be clean before any step is committed. `test/widget_test.dart` is the known-broken default-template smoke test; flag it rather than fixing it.

## Token discipline

The discipline section in `DESIGN-003-implementation-prompt.md` applies here unchanged. Two reminders that matter specifically:

- **Read the handoff first.** Before any other file read, open `docs/prompts/DESIGN-003-handoff.md` and read the last few entries. Trust what it says about which files exist, which ARB keys are in place, and what the main loop's structural choices were. Do not re-verify state the handoff asserts.
- **Append to the handoff at step end.** Same three-line format the main loop uses.

If a step cannot complete because state has drifted from what the handoff asserts, stop and add a note to `docs/prompts/DESIGN-003-blockers.md` rather than improvising.

## Verified facts (do not re-discover)

These were confirmed against the current tree before this prompt was written. Use them directly.

- **`lib/views/roleplay_form_screen.dart`** exists. Signature: `RolePlayFormScreen({required RolePlay rolePlay, Exercise? exercise})`. Pops with the updated `RolePlay` (or `null` on cancel). The caller persists via `ProgramService.saveRolePlay(...)`. AppBar title binds to `widget.rolePlay.name`.
- **`lib/views/roleplay_screen.dart`** exists. Signature: `RolePlayScreen({required String rolePlayUuid})`. Read-only view, looks up the role from `ProgramService`.
- **`lib/views/widgets/cast_picker_sheet.dart`** exists. Invoke via `showModalBottomSheet<String>` with `CastPickerSheet(rolePlay: r)`. Returns the selected `Actor.uuid` or `null`. The sheet's own doc-comment shows the canonical call shape.
- **`lib/views/station_screen.dart`** holds class `StationExerciseScreen` (not `StationScreen`). Constructor: `StationExerciseScreen({required int stationIndex, required String uuid})` where `uuid` is the exercise uuid. It loads the exercise via `_programService.getExercise(widget.uuid)` and uses `setState` for refresh (no listener-driven rebuild for role mutations).
- **`ProgramService`** exposes `loadRolePlays() -> List<RolePlay>`, `saveRolePlay(RolePlay) -> Future<void>`, and `deleteRolePlay(String uuid) -> Future<RolePlay?>`. The delete method exists in the service for completeness but **must not be wired into any UI in this follow-up** (see DESIGN-003 §Deletion and templating).
- **New UUIDs** use `nanoid(10)` (`import 'package:nanoid/nanoid.dart';`) per the convention established in Step 12 of the main loop.
- **The `RolePlay.index` field** is required. For a new role at a post, compute `index` as `_programService.loadRolePlays().where((r) => r.exerciseUuid == exercise.uuid).length`. The value only needs to be a stable sort key within the exercise; monotonic by creation order is fine.
- **Current ARB values that need updating** (verified):
  - `app_nb.arb` `roleSection` = `"Rolle"` → must become `"Markørordre"`.
  - `app_nb.arb` `noRolesInProgram` = `"Ingen markører ennå. Legg til en rolle fra Øvelser-fanen."` → must become `"Ingen markører ennå. Åpne en post i Poster-fanen for å legge til en."`.
  - `app_en.arb` `noRolesInProgram` (current English wording) must become `"No roles yet. Open a post in the Stations tab to add one."`.
  - `app_nb.arb` `rolePlaysTab` = `"Markører"` and `castSection` = `"Markør"` are already correct per the terminology rule; leave them.
- **Hardcoded English strings in `roleplay_form_screen.dart`**: the form labels for Signalement, Background and Behavior are literal `'Signalement'`, `'Background'`, `'Behavior'` strings rather than localized getters. This is a pre-existing l10n bug. Step 2 fixes it because the same step touches the form anyway.

## Commits

Conventional Commits with a scope. Same format as the main loop. Use `feat`, `fix`, `refactor` or `test` as appropriate. Scopes that fit: `roleplay`, `station`, `l10n`, `widget`.

## Loop control

Four steps. Each is one commit. Headings carry the keyword the loop matches against `git log`.

## Scope and step order

### Step 1. **l10n**: align ARB values and add the new keys

Two changes to existing values in `app_nb.arb` and one to `app_en.arb`:

- `roleSection` (nb): `"Rolle"` → `"Markørordre"`. English stays `"Role"`.
- `noRolesInProgram` (nb): `"Ingen markører ennå. Legg til en rolle fra Øvelser-fanen."` → `"Ingen markører ennå. Åpne en post i Poster-fanen for å legge til en."`.
- `noRolesInProgram` (en): current value → `"No roles yet. Open a post in the Stations tab to add one."`.

Add these new keys to both ARB files together. None of them exist today (verified against `app_nb.arb`):

| Key | English | Norwegian |
|-----|---------|-----------|
| `addRolePlay` | Add role | Legg til markørordre |
| `newRolePlayTitle` | New role | Ny markørordre |
| `editRolePlayTitle` | Edit role | Rediger markørordre |
| `stationRolesSection` | Roles | Markører |
| `noRolesAtThisStation` | No roles at this post | Ingen markører på denne posten |
| `roleSignalement` | Signalement | Signalement |
| `roleBackground` | Background | Bakgrunn |
| `roleBehavior` | Behaviour | Oppførsel |

Run `flutter analyze` to trigger the localization codegen, then sanity-check that the new getters appear on `AppLocalizations` (a `grep "newRolePlayTitle" lib/l10n/app_localizations.dart` should hit one declaration).

Commit: `feat(l10n): align RolePlay strings and add station section keys`.

### Step 2. **roleplay**: localize form labels and add new-role AppBar title fallback

Edit `lib/views/roleplay_form_screen.dart`. Two changes:

1. Replace the literal `'Signalement'`, `'Background'`, `'Behavior'` labels in the three multi-line `TextFormField` `decoration: InputDecoration(labelText: ...)` calls with `localizations.roleSignalement`, `localizations.roleBackground`, `localizations.roleBehavior` from Step 1.
2. Change the AppBar title binding from `Text(widget.rolePlay.name)` to a fallback expression:

   ```dart
   title: Text(
     widget.rolePlay.name.trim().isEmpty
         ? localizations.newRolePlayTitle
         : widget.rolePlay.name,
   ),
   ```

   This preserves existing edit behaviour (title is the role's identity) and gives new roles a meaningful header before the user types a name.

Add or extend a widget test in `test/views/roleplay_form_screen_test.dart`:

- AppBar title falls back to `localizations.newRolePlayTitle` when constructed with a `RolePlay` whose name is empty.
- AppBar title shows the role name when constructed with a `RolePlay` whose name is non-empty.
- The three localized labels render with the expected strings.

Commit: `fix(roleplay): localize form labels and add new-role title fallback`.

### Step 3. **station**: add Markører section to `StationExerciseScreen`

Edit `lib/views/station_screen.dart`. Add a new section to `StationExerciseScreen` below `_buildStationInfo`. The section lists every `RolePlay` where `r.exerciseUuid == _exercise.uuid && r.stationIndex == widget.stationIndex` and surfaces "+ Legg til markørordre".

Implementation outline:

```dart
Widget _buildRolesSection(Station station) {
  final localizations = AppLocalizations.of(context)!;
  final roles = _programService.loadRolePlays()
      .where((r) =>
          r.exerciseUuid == _exercise.uuid &&
          r.stationIndex == widget.stationIndex)
      .toList();
  return Card(
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(localizations.stationRolesSection,
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(localizations.addRolePlay),
                onPressed: () => _addRolePlay(station),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (roles.isEmpty)
            Text(localizations.noRolesAtThisStation,
                style: Theme.of(context).textTheme.bodySmall)
          else
            ...roles.map((r) => _buildRoleRow(r)),
        ],
      ),
    ),
  );
}
```

Row layout: leading `Icon(Icons.theater_comedy, size: 20)`, title `r.name`, trailing a small `InkWell` that wraps either `Icons.person` (filled, when `r.actorUuid != null`) or `Icons.person_add` (outlined, when null). Wrap the row in a `Dismissible` whose `confirmDismiss` pushes the edit form and returns `false`:

```dart
Dismissible(
  key: ValueKey('role-row-${r.uuid}'),
  direction: DismissDirection.startToEnd, // swipe-left → edit
  confirmDismiss: (_) async {
    final updated = await Navigator.push<RolePlay>(
      context,
      MaterialPageRoute(
        builder: (_) => RolePlayFormScreen(
          rolePlay: r,
          exercise: _exercise,
        ),
      ),
    );
    if (updated != null) {
      await _programService.saveRolePlay(updated);
      if (mounted) setState(() {});
    }
    return false; // never actually dismiss the row
  },
  background: /* edit-affordance background, mirror StationListView */,
  child: InkWell(
    onTap: () => context.push('/roleplays/${r.uuid}'),
    child: /* row layout */,
  ),
);
```

(Verify the swipe direction against how `StationListView` does it. The two surfaces should feel the same.)

Cast chip tap handler:

```dart
Future<void> _openCastPicker(RolePlay r) async {
  final actorUuid = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CastPickerSheet(rolePlay: r),
  );
  if (actorUuid != null && actorUuid != r.actorUuid) {
    await _programService.saveRolePlay(r.copyWith(actorUuid: actorUuid));
    if (mounted) setState(() {});
  }
}
```

Add role handler:

```dart
Future<void> _addRolePlay(Station station) async {
  final existing = _programService.loadRolePlays()
      .where((r) => r.exerciseUuid == _exercise.uuid)
      .length;
  final draft = RolePlay(
    uuid: nanoid(10),
    index: existing,
    exerciseUuid: _exercise.uuid,
    stationIndex: station.index,
    name: '',
  );
  final saved = await Navigator.push<RolePlay>(
    context,
    MaterialPageRoute(
      builder: (_) => RolePlayFormScreen(
        rolePlay: draft,
        exercise: _exercise,
      ),
    ),
  );
  if (saved != null) {
    await _programService.saveRolePlay(saved);
    if (mounted) setState(() {});
  }
}
```

Insert `_buildRolesSection(station)` into the build tree. In portrait it stacks below `stationInfo` and above `rotations`. In landscape, place it as a full-width section between the side-by-side Row and the next content (or below `stationInfo` inside the left Expanded — pick what looks cleanest after running the app once). Verify the layout in both orientations before committing.

**No delete affordance.** The design defers this. Do not add swipe-right, an overflow menu with delete, a long-press action, or any other destructive control. The `ProgramService.deleteRolePlay` method exists but stays unwired in this surface.

Widget tests in `test/views/station_screen_test.dart` (create the file if it does not exist):

- Section renders only the roles matching `(exerciseUuid, stationIndex)`.
- Tapping "+ Legg til markørordre" pushes `RolePlayFormScreen` with a draft role whose `exerciseUuid`, `stationIndex` and `index` match expectations and whose `name` is empty.
- Tapping a row body navigates to the read view (the test can assert the navigation call, not the screen render).
- Tapping the cast chip shows the cast picker.
- Swipe-left opens the edit form; row does not dismiss.
- Empty-state hint appears when no roles match.
- No `Icons.delete` and no `DismissDirection.endToStart` exist on the row.

Commit: `feat(station): add markørordre section to station screen`.

### Step 4. **test**: align RolePlays-tab empty-state assertions

The main loop's tests for `RolePlaysView` likely assert the old `noRolesInProgram` wording ("Legg til en rolle fra Øvelser-fanen"). Find those assertions and update them to the new wording from Step 1. The targeted way to find them:

```
grep -rn "Legg til en rolle" lib/ test/
grep -rn "Add a role from the Exercises" lib/ test/
```

Any hit in `test/` is an assertion to update. Any hit in `lib/` outside the generated `app_localizations*.dart` files is an unlocalized string that needs to go via `AppLocalizations`. Do not touch the generated localization files; they regenerate from the ARB.

Run `flutter analyze` and `flutter test`. Acknowledge `test/widget_test.dart` is still broken.

Commit: `test(roleplay): align tests with revised empty-state wording`.

## Verification

After all four steps:

1. `flutter analyze` clean.
2. `flutter test` passes (except the known-broken `test/widget_test.dart`).
3. `make build` runs without diff.
4. Manual QA (record in the PR description):
   - Open the Stations tab → open a post that has no roles. The Markører section shows with the "+ Legg til markørordre" action and the empty-state hint "Ingen markører på denne posten".
   - Tap "+ Legg til markørordre". The form opens with the AppBar title "Ny markørordre". Fill name, save. Form pops; the section now shows the new role with an outlined cast chip.
   - Tap the cast chip on the new row. The cast picker opens. Pick an actor (or create one inline via the sticky "Ny markør" row). Chip switches to filled.
   - Tap the row body. `RolePlayScreen` opens showing the role brief.
   - Swipe-left on the row. `RolePlayFormScreen` opens with AppBar title showing the role's name. Edit a field, save. Section reflects the change.
   - Open the RolePlays tab. The new role appears in the cross-cutting list with the right exercise subtitle and the filled cast chip.
   - Open the Markører-tab empty state on a fresh program (no roles anywhere). The text reads "Ingen markører ennå. Åpne en post i Poster-fanen for å legge til en."
   - Confirm there is no delete affordance on the Station-screen row (no swipe-right, no overflow menu offering delete, no long-press destructive action).

## Out of scope

- **Deletion of `RolePlay` records.** DESIGN-003 §Deletion and templating defers this. The service method exists; the UI must not expose it.
- **Template instantiation / "don't use here anymore".** Also deferred.
- **Station-less role creation.** No "no station" affordance in this iteration. The Station-screen flow always sets `stationIndex` on creation.
- **Observer-player Role tab.** Still waiting on the DESIGN-001 shell and the blocked Phase B work.
- **The blocked Phase B steps from the main loop** (`SessionParticipant.rolePlayUuid`, broadcaster activation, patch authorization, live roleplayer marker). Out of scope here; those need a separate loop covering ADR-0009 and ADR-0012 first.

## Deliverables

Four commits, in order, that together:

- Bring Norwegian ARB values into line with the markørordre/markører/markør rule, and add the eight new keys for the creation flow and the form labels.
- Localize the three hardcoded form labels and give the AppBar a sensible title for new roles.
- Land the Markører section on `StationExerciseScreen` with rows, cast-chip tap, swipe-to-edit, the "+ Legg til markørordre" action and the empty-state hint. No deletion.
- Align the RolePlays-tab tests with the revised empty-state wording.

DESIGN-003 §Creating roles and §Deletion and templating are the authoritative specs for this change.
