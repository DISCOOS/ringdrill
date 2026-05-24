You are working in the RingDrill repository. This is the second follow-up to DESIGN-003. The first follow-up (`docs/prompts/DESIGN-003-followup-creating-roles.md`) landed the Station-screen authoring surface. Manual inspection of the running app then surfaced four gaps between the design and the implementation, all of which sit on already-existing visible surfaces (the Markører tab tile and the `RolePlayFormScreen`):

1. The expanded tile's Cast section shows only the actor's name. The design specifies the full record — name, phone with tap-to-call, notes — and a trailing overflow menu with "Rediger markør" and "Fjern markør". The current code has a bare "Fjern markør" text button instead of the menu.
2. The Cast section header is labelled "Markør" with a "Privat — publiseres aldri" hint. The revised design uses "Spilles av" as a relation label and "Lagres lokalt" as a positively framed hint.
3. The Markører tab tile subtitle is the bare exercise name. The revised design specifies a post-prefixed subtitle (`Post: <station name>`) with an exercise fallback for station-less roles, because the post is the role's operational home and the exercise is already encoded in the leading code badge.
4. `RolePlayFormScreen`'s AppBar is just the role name. The revised design specifies the form should mirror the row anatomy: a role-code badge plus the name (with create-mode fallback to "Ny markørordre") plus the same post-prefixed subtitle.

Close all four gaps in this follow-up.

Read these before you start:

- `docs/design/roleplays-tab.md` (revised 2026-05-24), specifically the sections **Terminology note**, **Tile anatomy** (the Cast subsection and the subtitle bullet under "Collapsed"), and **Form anatomy**. These are the authoritative spec.
- `docs/prompts/DESIGN-003-implementation-prompt.md` for the conventions the main loop established (ground rules, commit format, handoff pattern, token discipline).
- `docs/prompts/DESIGN-003-handoff.md` for the state established by the main loop and the first follow-up. Trust the handoff over re-reading files it asserts state on.

If anything in this prompt appears to contradict the design doc, the design wins. Stop and ask.

## Ground rules

The non-negotiables from `AGENTS.md` carry over unchanged. Highlights for this change:

- No model changes are expected. `make build` is triggered automatically by `flutter analyze`/`test` after ARB edits.
- Localize every user-visible string in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Follow the terminology rule from the revised design doc.
- CLI stays Flutter-free, mobile-safe imports stay mobile-safe, no new lint suppressions.
- `flutter analyze` and `flutter test` must be clean before any step is committed. `test/widget_test.dart` is the known-broken default-template smoke test; flag it rather than fixing it.

## Token discipline

Token discipline from `DESIGN-003-implementation-prompt.md` applies unchanged. Two reminders for this follow-up:

- **Read the handoff first.** Before any other file read, open `docs/prompts/DESIGN-003-handoff.md` and read the last few entries. Trust what it says.
- **Append to the handoff at step end.** Same three-line format the main loop uses.

If a step cannot complete because state has drifted from what the handoff asserts, stop and add a note to `docs/prompts/DESIGN-003-blockers.md` rather than improvising.

## Verified facts (do not re-discover)

These were confirmed against the current tree before this prompt was written.

- **`lib/views/roleplay_form_screen.dart`** AppBar is currently `AppBar(title: Text(widget.rolePlay.name), actions: [Save])`. No badge, no subtitle. The form already imports `Exercise` and accepts an optional `exercise` parameter, so the post-subtitle lookup has the data it needs.
- **`lib/views/roleplays_view.dart`** Cast section is around lines 300–345. The header is built with `Icon(Icons.people, …)` + `Text(localizations.castSection)` + `Text(localizations.castPrivateHint)`. The cast-set body renders `actor.realName` and a bare "Fjern markør" `TextButton`. Phone, notes and an overflow menu are not present today.
- **`lib/views/roleplays_view.dart`** subtitle at line 228 is `subtitle: Text(exercise.name)`. The variable `exercise` is the host `Exercise` for the role. The role's station name can be resolved via `exercise.stations[rolePlay.stationIndex!]` when `stationIndex` is non-null and within bounds.
- **`RoleCodeBadge`** is exported from `lib/views/widgets/role_expansion_tile.dart` (per the main loop's Step 10). Reuse it in the form's AppBar.
- **`_MapSheetHeader`** in `lib/views/widgets/station_mini_map.dart` (around lines 108–163) is the canonical pattern for a Row + Column header with a badge, a primary text and a secondary text. Mirror this layout in the form's AppBar.
- **`ProgramService.loadExercises()`** returns the program's exercises in display order; the role's `exerciseNumber` (1-based) is `loadExercises().indexWhere((e) => e.uuid == rolePlay.exerciseUuid) + 1`. The badge code is `${exerciseNumber}.${rolePlay.index + 1}`.
- **`ProgramService.loadActors()`** and `saveActor(Actor)` exist for the Edit-cast action.
- **`ActorFormScreen`** exists in `lib/views/actor_form_screen.dart`. Per the main loop's handoff (Step 12), the screen pops with the saved `Actor` (or null on cancel); the caller persists.
- **`url_launcher`** is already a project dependency for `tel:` URLs (verify with `grep "url_launcher" pubspec.yaml`). If absent, do not add a new dependency; render the phone number as plain text and add a tooltip "Tap-to-call not wired yet" rather than expanding scope.
- **Current ARB values that need updating** (verified):
  - `app_nb.arb` `castSection` = `"Markør"` → must become `"Spilles av"`. English `"Cast"` → `"Played by"`.
  - `app_nb.arb` `castPrivateHint` = `"Privat — publiseres aldri"` → must become `"Lagres lokalt"`. English `"Private — never published"` → `"Stays on this device"`.
- **ARB keys that already exist and stay as-is**: `editCast`, `clearCast`, `actorRealName`, `actorPhone`, `actorNotes` (per the main loop's l10n additions; verify via `grep` rather than re-introducing them).

## Commits

Conventional Commits with a scope. Same format as the main loop. Scopes that fit: `roleplay`, `l10n`, `widget`.

## Loop control

Six steps. Each is one commit. Headings carry the keyword the loop matches against `git log`.

## Scope and step order

### Step 1. **l10n**: update Cast terminology and add subtitle keys

Existing values to update (verified):

| Key | Locale | Old | New |
|-----|--------|-----|-----|
| `castSection` | nb | `Markør` | `Spilles av` |
| `castSection` | en | `Cast` | `Played by` |
| `castPrivateHint` | nb | `Privat — publiseres aldri` | `Lagres lokalt` |
| `castPrivateHint` | en | `Private — never published` | `Stays on this device` |

New keys to add to both ARB files together:

| Key | English | Norwegian |
|-----|---------|-----------|
| `roleSubtitleStation` | Station: {name} | Post: {name} |
| `roleSubtitleExercise` | Exercise: {name} | Øvelse: {name} |
| `noActorsInRoster` | No actors yet. Tap + New actor to add one. | Ingen markører ennå. Trykk + Ny markør for å legge til. |
| `noActiveProgramHint` | No active program. Open or create one in the Exercises tab. | Ingen aktiv øvelsesplan. Velg eller opprett en i Øvelser-fanen. |

The two `roleSubtitle*` keys take a single `String name` placeholder. Declare them as `@<key>` metadata with `"name": {"type": "String"}` per the existing ARB conventions in this repo. The other two are plain strings.

Run `flutter analyze` to trigger localization codegen, then sanity-check the new getters appear on `AppLocalizations`.

Commit: `feat(l10n): refine cast section terminology, add subtitle keys`.

### Step 2. **roleplay**: complete the Cast section per DESIGN-003 §Tile anatomy

Edit `lib/views/roleplays_view.dart`. The Cast section in `_buildExpandedBody` currently renders only `actor.realName` with a bare "Fjern markør" button. Replace that block with the full layout the design specifies.

Cast-set body (`actor != null`):

- Primary line: `actor.realName` (existing).
- Secondary line: `actor.phone` rendered with `tel:` tap-to-call when non-null. Use `url_launcher`'s `launchUrl(Uri.parse('tel:${actor.phone}'))` wrapped in an `InkWell`. When `actor.phone` is null, omit the line entirely; do not render a placeholder. If `url_launcher` is not on the dependency list, render the phone number as plain text and skip the tap behaviour.
- Tertiary line: `actor.notes` rendered as a single small-style `Text` when non-null and non-empty. Omit when null/empty.
- Trailing affordance: a `PopupMenuButton<_CastAction>` with two items, "Rediger markør" (`localizations.editCast`) and "Fjern markør" (`localizations.clearCast`). Replace the existing bare `TextButton(onPressed: () => _clearCast(rolePlay))` with the menu.

The "Rediger markør" item opens `ActorFormScreen` with the current actor, awaits the popped Actor, persists via `ProgramService.saveActor(updated)`, and refreshes the view.

The "Fjern markør" item keeps the existing `_clearCast(rolePlay)` behaviour (sets `actorUuid = null` and persists).

Layout: a `Row` with the three text lines stacked in a left-aligned `Column` taking `Expanded`, and the `PopupMenuButton` as the trailing child. Match the existing visual weight (Cast section is "slightly less weight than the Role section" per the design).

Cast-unset body (`actor == null`) is unchanged from today (the `TextButton.icon` with `localizations.addCast`).

Widget tests in `test/views/roleplays_view_test.dart` (or wherever the existing tile tests live):

- When `actor != null`, the Cast section renders `realName`, `phone` (when non-null) and `notes` (when non-empty).
- When `actor.phone` is null, no phone line is rendered.
- The overflow menu exists and contains the two expected items in order.
- Selecting "Fjern markør" clears the cast (existing behaviour preserved).
- Selecting "Rediger markør" pushes `ActorFormScreen` with the current actor.

Commit: `feat(roleplay): complete cast section with phone, notes and overflow menu`.

### Step 3. **roleplay**: collapsed-tile presentation (subtitle + cast suffix on title)

Two coordinated changes in the same widget block in `lib/views/roleplays_view.dart` (around lines 220–240). They are landed together because both adjust how a collapsed Markører-tab row presents itself.

**Change A — post-prefixed subtitle.** At line 228 (the `subtitle: Text(exercise.name)` line), replace the bare expression with a station-aware lookup:

```dart
final subtitleText = (rolePlay.stationIndex != null &&
        rolePlay.stationIndex! < exercise.stations.length)
    ? localizations.roleSubtitleStation(
        exercise.stations[rolePlay.stationIndex!].name,
      )
    : localizations.roleSubtitleExercise(exercise.name);
// ...
subtitle: Text(subtitleText),
```

Place the computation just above the `RoleExpansionTile` widget so the build method stays readable. Do not introduce a helper method unless multiple call sites need it.

**Change B — cast actor name in parens on the title.** At lines 223–227 (the `title: Text(...)` block), append the cast actor's `realName` in parens when the role is cast. The current expression renders `'<name>, <age>'` or just `<name>`. The new expression appends ` (<actor.realName>)` when `actor != null`:

```dart
final titleBuilder = StringBuffer(rolePlay.name);
if (rolePlay.age != null) titleBuilder.write(', ${rolePlay.age}');
if (actor != null) titleBuilder.write(' (${actor.realName})');
// ...
title: Text(titleBuilder.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
```

The Markører-tab tile is the **only** surface that gets the cast suffix on the title. The other places that show a role name (form AppBar, `RolePlayScreen` read view, Station-screen Markører section row) have their own ways to convey cast status (Cast section in the expanded body, dedicated read view, chip in trailing) and would be confused by a duplicated cast reference in the title.

Update any existing widget test that asserts the bare exercise name in the subtitle or the bare role name in the title. The targeted way to find them:

```
grep -rn "exercise.name" test/views/roleplays_view_test.dart
grep -rn "subtitle" test/views/roleplays_view_test.dart
grep -rn "rolePlay.name" test/views/roleplays_view_test.dart
```

Tests should switch to asserting:

- Subtitle: one of `localizations.roleSubtitleStation(...)` or `localizations.roleSubtitleExercise(...)` based on the fixture's stationIndex.
- Title: the new string including age and cast actor in parens when applicable.

Commit: `feat(roleplay): post subtitle and cast actor suffix on collapsed tile`.

### Step 4. **roleplay**: form AppBar mirrors row anatomy

Edit `lib/views/roleplay_form_screen.dart`. Replace the current `title: Text(widget.rolePlay.name)` with a Row containing the role-code badge, the role name (with create-mode fallback), and the post-prefixed subtitle. Mirror the shape used by `_MapSheetHeader` in `lib/views/widgets/station_mini_map.dart`.

Outline (verify against the existing `_MapSheetHeader` shape; do not invent a parallel one):

```dart
final exercises = _programService.loadExercises();
final exerciseIndex =
    exercises.indexWhere((e) => e.uuid == widget.rolePlay.exerciseUuid);
final code = exerciseIndex < 0
    ? '?.${widget.rolePlay.index + 1}'
    : '${exerciseIndex + 1}.${widget.rolePlay.index + 1}';

final stationIndex = widget.rolePlay.stationIndex;
final stations = widget.exercise?.stations ?? [];
final subtitleText = (stationIndex != null && stationIndex < stations.length)
    ? localizations.roleSubtitleStation(stations[stationIndex].name)
    : localizations.roleSubtitleExercise(widget.exercise?.name ?? '');

final titleText = widget.rolePlay.name.trim().isEmpty
    ? localizations.newRolePlayTitle
    : widget.rolePlay.name;

return Scaffold(
  appBar: AppBar(
    title: Row(
      children: [
        RoleCodeBadge(code: code),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                subtitleText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [/* existing Save button */],
  ),
  body: /* unchanged */,
);
```

Add a `ProgramService` instance to the state if not present (`final _programService = ProgramService();`). Import `RoleCodeBadge` from `lib/views/widgets/role_expansion_tile.dart`.

The `Save` action and the form body remain unchanged.

Widget tests in `test/views/roleplay_form_screen_test.dart` (extend whatever the previous follow-up left):

- AppBar renders a `RoleCodeBadge` with the expected text for both edit and create modes.
- Title falls back to `localizations.newRolePlayTitle` when the role's name is empty, and shows the role name otherwise.
- Subtitle renders the station-prefixed string when `stationIndex` is set, and the exercise-prefixed string when null.

Commit: `feat(roleplay): restructure form AppBar with badge, title fallback and post subtitle`.

### Step 5. **roleplay**: cast roster polish and Markører-flow vakter

This step closes four related gaps in one commit, all on the cast roster sheet and the Markører-tab body. They are landed together because they share the same surfaces and tell one story for reviewers: defensive UI for the casting flow.

**Change A — drop the spurious AppBar from the cast roster sheet.** Edit `lib/views/widgets/cast_roster_sheet.dart`. The build method currently returns a `Scaffold` with an `AppBar(title: Text(localizations.castRoster))`. The AppBar makes the sheet feel like a full-screen route with a back arrow, even though the sheet's drag handle (`showDragHandle: true` on the caller's `showModalBottomSheet`) is the dismiss affordance.

Replace the `Scaffold(appBar: ..., body: ...)` pattern with `Scaffold(body: Column(...), floatingActionButton: ...)`. The Column has:

1. A header row at the top with padding and the sheet's title (`localizations.castRoster`) styled with `Theme.of(context).textTheme.titleLarge`. No back button, no leading icon.
2. An `Expanded` child holding the existing list / empty-state body.

Keep the Scaffold (without an AppBar) because it gives the FAB its anchored positioning. Do not switch to a Stack-based layout unless a real problem with the Scaffold surfaces during testing.

**Change B — informative empty state on the roster sheet.** Replace `Center(child: Text(localizations.newActor))` with a padded empty-state hint using the new `localizations.noActorsInRoster` key ("Ingen markører ennå. Trykk + Ny markør for å legge til."). Match the visual weight of other empty states: `Theme.of(context).textTheme.bodyMedium` with `colorScheme.onSurfaceVariant`. Centre horizontally; vertical centring is fine.

**Change C — Cast-roster AppBar action: icon, tooltip and disabled state.** The existing `IconButton` in `lib/views/roleplays_view.dart` (line ~486) uses `Icons.people_outline` with tooltip `localizations.castRoster`. Both change:

- Replace `Icons.people_outline` with `Icons.recent_actors`. The new icon depicts a row of silhouettes, which is semantically a list of castable people and visually distinct from the tab's `Icons.theater_comedy` (the role briefs). The Markører-tab title "Markører" and the AppBar action's icon should not look the same; the tab is about role briefs (markørordrer), the action is about the people (markører).
- Drop the existing `tooltip: localizations.castRoster` line. "Markører" as a tooltip duplicates the tab title shown directly above it and adds no information. The new tooltip behaviour is described below.

**Icon family for actor surfaces.** While restructuring the cast-roster AppBar action, unify the icons across the casting surfaces so the visual hierarchy reads at a glance:

- `Icons.recent_actors` — plural, list-level. Used on the AppBar action that opens the cast roster.
- `Icons.face` — single, row-level. Used as `leading` on individual actor rows in lists where the actor is being browsed or picked.
- `Icons.person` / `Icons.person_add_outlined` — the cast affordance family. Used on the cast chip (filled when cast, outlined when not) and on the Cast section header in the expanded tile, because the section labels the affordance that the chip controls. Material does not ship a `face_add` companion, so swapping one half of the affordance pair to `face` would break the visual symmetry.

Concrete edits:

- `lib/views/widgets/cast_roster_sheet.dart` line ~123: replace `Icon(Icons.person)` in the actor `ListTile.leading` with `Icon(Icons.face)`.
- `lib/views/widgets/cast_picker_sheet.dart` line ~150: replace `Icon(Icons.person)` in the actor row's `leading` with `Icon(Icons.face)`.
- `lib/views/roleplays_view.dart` line ~306: replace `Icon(Icons.people, ...)` in the Cast section header (next to the "Spilles av" label) with `Icon(Icons.person, ...)`. This corrects a pre-existing deviation from the design and aligns the section header with the chip family.
- Do **not** touch the cast-chip pair on the Markører-tab tile (line ~251) and the Station-screen Markører section (line ~418). They stay as `Icons.person` / `Icons.person_add_outlined`.

When `_programService.activeProgramUuid == null` at build time:

- Replace the tab body with a centred empty-state widget rendering `localizations.noActiveProgramHint` ("Ingen aktiv øvelsesplan. Velg eller opprett en i Øvelser-fanen.").
- Render the cast-roster AppBar action as **disabled** (greyed out), not hidden. Set `onPressed: null` on the `IconButton`. The tooltip is conditional on state:
  - When the action is enabled (active program exists), tooltip is `localizations.castSection` ("Spilles av" / "Played by"). Reusing the cast-section label keeps the button, its tooltip and the tile section it gates internally consistent.
  - When the action is disabled (no active program), tooltip is `localizations.noActiveProgramHint` so a long-press explains why the button is greyed.

  Use the `IconButton`'s built-in `tooltip` parameter; do not wrap in a separate `Tooltip` widget unless required for the conditional swap.

  The button stays in the actions list at all times so the user can see the affordance exists and understands why it is unavailable. This matches Material's pattern for unavailable actions and avoids the AppBar reshaping when an active program is later set.
- Do not render the filter FAB. Material's FAB convention is that a visible FAB is always actionable; a disabled FAB reads worse than an omitted one. The FAB returns when an active program is set.
- Subscribe `RolePlaysView` to `ProgramService.events` if it is not already a listener, so the tab rebuilds when an active program is set elsewhere (then the action enables, the FAB returns, and the empty state is replaced by the role list).

**Change D — gated startup call to `_ensureActiveProgram`.** Expose a public `ensureActiveProgram(AppLocalizations localizations)` in `lib/services/program_service.dart` that calls the existing private helper with `localizations.defaultPlanName`. Do not change the private helper's signature.

In `lib/views/main_screen.dart`, add a one-time call to `ProgramService().ensureActiveProgram(localizations)` from `MainScreen.initState` via `WidgetsBinding.instance.addPostFrameCallback`, gated by an explicit check that an active program is already stored in SharedPreferences:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(AppConfig.keyActiveProgram)) return;
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    await ProgramService().ensureActiveProgram(localizations);
  });
}
```

The `containsKey` guard is intentional: `_ensureActiveProgram` auto-creates a default plan when no active is stored, and that auto-creation is **not** what we want on app startup. A fresh-install user who has never created a program should land in the no-active-program UI (Change C) and be guided to the Øvelser-fanen to create one explicitly, not surprised by an auto-created "Default plan" they did not ask for. The startup call therefore only runs in the case where an active reference is already in SharedPreferences, which means the call is effectively a no-op today (the private helper returns early when `activeProgramUuid != null`). The hook exists so that if the helper grows future logic (e.g., recovery from a stale active reference, promotion of a remaining program after the active was deleted), it has a startup entry point.

**Do not** add `_ensureActiveProgram` calls to `saveActor` or `saveRolePlay`. Auto-creation on writes is the saveExercise pattern, but that pattern was a pre-existing concession; we are not extending it to the casting paths. With Change C in place the no-active state is no longer reachable through normal UI, so saves do not need the auto-create fallback.

Widget tests:

- The roster sheet renders no `AppBar` widget anywhere in its tree; the header row renders `localizations.castRoster` as title-style text; the empty state renders `localizations.noActorsInRoster`; the FAB still exists and shows `localizations.newActor`.
- `RolePlaysView` with `activeProgramUuid == null`: body renders `noActiveProgramHint`; cast-roster AppBar action exists but is disabled (`onPressed == null`); the action's icon is `Icons.recent_actors`; tooltip on it carries `noActiveProgramHint`; filter FAB is not rendered.
- `RolePlaysView` with `activeProgramUuid != null`: cast-roster AppBar action is enabled; tooltip is `castSection` ("Spilles av" / "Played by"); icon is `Icons.recent_actors`.
- `MainScreen` does not call `ensureActiveProgram` when `SharedPreferences` does not contain `AppConfig.keyActiveProgram` (assert with a stub).
- `MainScreen` calls `ensureActiveProgram` once when the key is present.

Commit: `feat(roleplay): polish cast roster sheet and guard Markører flow against missing active program`.

### Step 6. **test**: sweep and final verification

Two cleanup tasks.

1. Grep for the old hint and label strings to confirm nothing still asserts them in tests:

   ```
   grep -rn "Privat — publiseres aldri" lib/ test/
   grep -rn "Private — never published" lib/ test/
   grep -rn "Markør" test/  # spot-check the test files; assertions on the section label
   ```

   Hits in `test/` are assertions to update to the new wording. Hits in `lib/` outside generated `app_localizations*.dart` are unlocalized strings that need to use the getter.

2. Run the full verification:
   - `flutter analyze` clean.
   - `flutter test` passes. Acknowledge `test/widget_test.dart` is still broken; do not touch it.
   - `make build` runs without diff.

Commit: `test(roleplay): align assertions with refined cast terminology and subtitle`.

## Verification

After all six steps:

1. `flutter analyze` clean.
2. `flutter test` passes (except the known-broken `test/widget_test.dart`).
3. `make build` runs without diff.
4. Manual QA (record in the PR description):
   - Open the Markører tab. Each row's subtitle reads `Post: <station name>` for roles tied to a station, or `Øvelse: <exercise name>` for any rare orphan. The title reads `<role name>, <age> (<actor name>)` when the role is cast, drops the parenthetical when uncast, and drops the age when none is set.
   - Expand a tile whose role has a cast actor. The Cast section header reads "Spilles av" with a subdued "Lagres lokalt" hint. Body shows the actor's name, the phone (if any) with tap-to-call, and notes (if any). The trailing overflow menu offers "Rediger markør" and "Fjern markør".
   - Tap "Rediger markør". `ActorFormScreen` opens with the actor pre-filled. Save and return; the section refreshes with the edited values.
   - Tap "Fjern markør". The role becomes uncast; the section switches to the "Velg markør" button.
   - Open a role in `RolePlayFormScreen` (swipe-left on a row). The AppBar shows the role-code badge, the role name as title, and `Post: <station name>` as subtitle.
   - Create a new role from the Station screen. The form opens with the AppBar showing the badge, "Ny markørordre" as title fallback, and `Post: <station name>` as subtitle. Fill in the name; the title updates live to reflect the typed name (or stays as the fallback if you do not implement live-update — that is fine, the title is recomputed on rebuild after save).
   - Open the cast roster sheet from the Markører-tab AppBar action. No internal AppBar or back arrow; the drag handle is the only dismiss. Header row shows "Markører" as a title. Empty state reads "Ingen markører ennå. Trykk + Ny markør for å legge til." The FAB at the bottom shows "Ny markør".
   - Wipe the app's storage (or fresh install) and launch. The Markører tab shows "Ingen aktiv øvelsesplan. Velg eller opprett en i Øvelser-fanen." The cast-roster AppBar action is visible but greyed out (long-press shows the same tooltip). The filter FAB is not rendered. Tapping the Øvelser-fanen and creating a program flips the Markører tab to its normal state — the AppBar action enables and the FAB returns. No `Bad state: No active program` exception fires.
   - Launch the app with an active program already stored. Normal behaviour, no auto-create dialog, no surprise programs in the list.

## Out of scope

- **Deletion of `RolePlay` records.** DESIGN-003 §Deletion and templating defers this. Do not add it.
- **Template instantiation.** Deferred.
- **Station-less role creation.** Still no creation affordance for roles without a `stationIndex`.
- **Observer-player Role tab.** Waiting on the DESIGN-001 shell.
- **The blocked Phase B steps** (`SessionParticipant.rolePlayUuid`, broadcaster activation, patch authorization, live roleplayer marker). Out of scope here.
- **A new `url_launcher` dependency.** If it is not already in `pubspec.yaml`, fall back to non-tappable phone text rather than expanding scope.

## Deliverables

Six commits, in order, that together:

- Refine the Cast section terminology (Spilles av, Lagres lokalt) and add the subtitle, roster and no-active ARB keys.
- Complete the Cast section per the design: name + phone (tap-to-call) + notes + overflow menu.
- Replace the bare exercise-name subtitle on the Markører-tab tile with a post-prefixed subtitle, exercise as fallback.
- Restructure `RolePlayFormScreen`'s AppBar to mirror the row anatomy: badge + name (with create fallback) + post subtitle.
- Polish the cast roster sheet (drop AppBar, informative empty state), guard the Markører tab against missing active program, and add a gated startup call to `_ensureActiveProgram` that never auto-creates a plan on fresh install.
- Sweep test assertions and verify the gates.

DESIGN-003 §Tile anatomy, §Form anatomy and §Terminology note are the authoritative specs.
