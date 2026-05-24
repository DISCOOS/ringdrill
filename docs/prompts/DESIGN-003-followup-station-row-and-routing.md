You are working in the RingDrill repository. This is the third follow-up to DESIGN-003. The previous follow-ups landed the Station-screen authoring section (`DESIGN-003-followup-creating-roles.md`) and the Markører-tab polish plus active-program guards (`DESIGN-003-followup-tile-and-form-anatomy.md`). Both are merged. The next planned follow-up (`DESIGN-003-followup-station-expansions.md`, browse-surface summaries on the coordinator screen and the Stations-tab expansion) depends on the work in this one and lands after it.

Manual inspection of the running app after the second follow-up surfaced two coupled defects on the existing Station-screen Markører section. They are coupled because the design doc revision unifies the row anatomy across the Station-screen authoring section and the browse summaries that the next follow-up will introduce; the two-line row layout is specified once and reused on three surfaces.

1. **Routing crash on the Station-screen Markører section.** Tapping a row pushes `'/roleplays/<uuid>'`, but the GoRouter setup only registers a stub `GoRoute` for `routeRolePlays` with no nested `:roleUuid` child. GoException: `no routes for location: /roleplays/<uuid>`. The first follow-up's spec implied the nested route would exist; the loop missed registering it.
2. **Sparse Station-screen Markører rows.** The current layout shows only the role name. Age, the cast actor's name, and an explicit "no actor cast" indication are missing. The revised design now specifies a two-line layout — role name (with age suffix when set) on the title line, "Spilles av <name>" or "Ingen markør valgt" on the subtitle line — that is shared with the browse summaries that land in the next follow-up.

Read these before you start:

- `docs/design/roleplays-tab.md` (revised), specifically the **Creating roles** section (the Station-screen "Markører" row anatomy) and the **Station-expansion summary** section (which reuses the same two-line layout). The **Tile anatomy** rules also matter because they scope the cast-actor parens to the Markører-tab tile only — every other surface, including this one, uses the subtitle line for cast info.
- `docs/prompts/DESIGN-003-implementation-prompt.md` for the conventions the main loop established (ground rules, commit format, handoff pattern, token discipline).
- `docs/prompts/DESIGN-003-handoff.md` for the state established by the main loop and the first two follow-ups. Trust the handoff over re-reading files it asserts state on.

If anything in this prompt appears to contradict the design doc, the design wins. Stop and ask.

## Ground rules

The non-negotiables from `AGENTS.md` carry over unchanged. Highlights:

- No model changes are expected. ARB edits trigger l10n codegen on the next `flutter analyze`/`test`.
- Localize every user-visible string in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Reuse existing keys where possible. Follow the **terminology rule** from the revised design doc: *Markørordre* for singular naming of the `RolePlay` entity, *Markører* for lists and counts, *Markør* for the human (`Actor`), *Spilles av* as the relation phrase.
- CLI stays Flutter-free, mobile-safe imports stay mobile-safe, no new lint suppressions.
- `flutter analyze` and `flutter test` must be clean before any step is committed. `test/widget_test.dart` is the known-broken default-template smoke test; flag it rather than fixing it.

## Token discipline

Token discipline from `DESIGN-003-implementation-prompt.md` applies unchanged. Read the handoff first; do not re-read files it asserts state on. Append to the handoff at step end.

If a step cannot complete because state has drifted from what the handoff asserts, stop and write to `docs/prompts/DESIGN-003-blockers.md` rather than improvising.

## Verified facts (do not re-discover)

These were confirmed against the current tree before this prompt was written.

- **`lib/views/main_screen.dart`** holds `buildRouter`. The current `routeRolePlays` `GoRoute` (around lines 193–199) is a stub that builds `const SizedBox.shrink()` with no nested routes. This is the cause of the GoException described above. The station detail route at `/stations/:exerciseUuid/:stationIndex` uses `parentNavigatorKey: key`; the new nested route mirrors that.
- **`lib/views/station_screen.dart`** holds the Station-screen Markører section landed by the first follow-up. The row tap handler is `context.push('$routeRolePlays/${r.uuid}')` (around line 402). The row layout (around lines 401–432) is a single `Row` with leading icon, `Expanded(child: Text(r.name))`, and a trailing `IconButton` for the cast chip. There is no subtitle, no age, no cast actor name.
- **`lib/views/roleplay_screen.dart`** exposes `RolePlayScreen({required String rolePlayUuid})`. The nested GoRoute should construct this with `state.pathParameters['roleUuid']!`.
- **`ProgramService`** exposes `loadRolePlays()` and `loadActors()`. The Station-screen row already has access to the role; resolving the actor is `loadActors().firstWhereOrNull((a) => a.uuid == r.actorUuid)` or equivalent — verify the helper available in `station_screen.dart` rather than introducing a new one.
- **Icon family for actor surfaces** (set by the previous follow-up):
  - `Icons.theater_comedy` — leading icon on a single role row, also the Markører-tab nav icon.
  - `Icons.person` (filled) / `Icons.person_add_outlined` (outlined) — the cast affordance pair. **Interactive** on the Station-screen authoring section (this surface). The browse summaries in the next follow-up use the same icons but non-interactively.
- **ARB keys already in place**: `editCast`, `addCast`, `stationRolesSection`, `addRolePlay`, `noRolesAtThisStation`, `castSection` ("Spilles av" / "Played by"), `actorRealName`. The two new keys this follow-up adds are `castedByLine` and `noCastLine`; both are shared with the next follow-up's browse-summary widget.

## Commits

Conventional Commits with a scope. Same format as the main loop. Scopes that fit: `navigation`, `l10n`, `station`, `roleplay`, `test`.

## Loop control

Four steps. Each is one commit. Headings carry the keyword the loop matches against `git log`.

## Scope and step order

### Step 1. **navigation**: register the nested `/roleplays/:roleUuid` GoRoute

Edit `lib/views/main_screen.dart`. The current `routeRolePlays` `GoRoute` (around lines 193–199) builds `SizedBox.shrink()` with no nested routes. The first follow-up's row-tap handler assumed the nested route would resolve; this step makes that assumption true.

Replace the stub block with a `GoRoute` whose `routes:` list includes a nested route for the read view:

```dart
GoRoute(
  path: routeRolePlays,
  // ShellRoute's child is ignored by MainScreen (IndexedStack).
  // Stub builder avoids constructing an extra RolePlaysController.
  builder: (BuildContext context, GoRouterState state) =>
      const SizedBox.shrink(),
  routes: [
    GoRoute(
      path: ':roleUuid',
      parentNavigatorKey: key,
      builder: (BuildContext context, GoRouterState state) =>
          RolePlayScreen(
        rolePlayUuid: state.pathParameters['roleUuid']!,
      ),
    ),
  ],
),
```

`key` is the same `navigatorKey` that the other deep routes use (verify by reading the surrounding `GoRoute` entries — the station detail route at `/stations/:exerciseUuid/:stationIndex` uses `parentNavigatorKey: key`).

Do **not** add a `:roleUuid/edit` sub-route in this step. The form is reached via `Navigator.push` with a `MaterialPageRoute` from the row's swipe handler (verified in `station_screen.dart:386` and `roleplays_view.dart` swipe paths), so a GoRoute is not required.

Smoke check after this step: tap a row in the Station-screen Markører section. `RolePlayScreen` opens with the right role. No GoException in the console.

Commit: `fix(navigation): register nested /roleplays/:roleUuid route`.

### Step 2. **l10n**: add cast-subtitle ARB keys

Add these new keys to both ARB files together. Neither exists today (verified against `app_nb.arb`).

| Key | English | Norwegian |
|-----|---------|-----------|
| `castedByLine` | Played by {name} | Spilles av {name} |
| `noCastLine` | No actor selected | Ingen markør valgt |

`castedByLine` takes a single `String name` placeholder. Declare it as `@<key>` metadata with `"name": {"type": "String"}` per the existing ARB conventions in this repo.

Run `flutter analyze` (or `flutter gen-l10n` explicitly) to trigger localization codegen, and sanity-check the new getters appear on `AppLocalizations`.

Both keys are scoped to the row-level cast subtitle. The next follow-up (`DESIGN-003-followup-station-expansions.md`) reuses them on the browse summaries; do not duplicate.

Commit: `feat(l10n): add cast-subtitle keys for station-row markørordre display`.

### Step 3. **station**: enrich the Station-screen Markører row with age and cast subtitle

Edit `lib/views/station_screen.dart`. The current Markører-row build (around lines 401–432) renders only the role name. Replace the inline `Row` body of the `InkWell` with a layout that surfaces age and cast status, using a two-line `Row` + `Column` pattern.

Target layout for each row:

```
[theater_comedy]  Anna Hansen, 67               [person]
                  Spilles av Kari Nordmann
```

Or when uncast:

```
[theater_comedy]  Olav Berg                     [person_add_outlined]
                  Ingen markør valgt
```

Construction outline:

```dart
final actor = r.actorUuid != null
    ? _programService.loadActors().firstWhereOrNull((a) => a.uuid == r.actorUuid)
    : null;
final titleText = r.age != null ? '${r.name}, ${r.age}' : r.name;
final subtitleText = actor != null
    ? localizations.castedByLine(actor.realName)
    : localizations.noCastLine;
final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
  color: actor != null
      ? colorScheme.onSurfaceVariant
      : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
  fontStyle: actor != null ? FontStyle.normal : FontStyle.italic,
);

return InkWell(
  onTap: () => context.push('$routeRolePlays/${r.uuid}'),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.theater_comedy, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(subtitleText, style: subtitleStyle, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            actor != null ? Icons.person : Icons.person_add_outlined,
            color: actor != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          tooltip: actor != null
              ? localizations.editCast
              : localizations.addCast,
          onPressed: () => _openCastPicker(r),
        ),
      ],
    ),
  ),
);
```

The italic + lowered-opacity styling for "Ingen markør valgt" signals a soft missing-state without being alarming. Match existing empty-state styling in the app if you find a closer convention while reading neighbouring widgets.

The trailing cast chip stays **interactive** on this surface (it opens the cast picker), per the first follow-up's spec. The browse summaries the next follow-up adds use the same icons but without the `IconButton` wrapper.

Per DESIGN-003 §Tile anatomy, the cast-actor parens on the title (`Anna Hansen, 67 (Kari Nordmann)`) are exclusive to the Markører-tab tile. Station-screen rows convey cast info through the subtitle line and **do not** append the actor name to the title.

Widget test in `test/views/station_screen_test.dart`:

- Row renders age in the title when `role.age != null`.
- Row renders no age suffix when `role.age == null`.
- Subtitle renders `castedByLine(actor.realName)` when the role is cast.
- Subtitle renders `noCastLine` when the role is not cast.
- Subtitle style is italic + lowered-opacity when uncast, regular otherwise.
- Tapping the row body invokes `context.push('/roleplays/<uuid>')` (assert via a route observer or by stubbing the GoRouter).
- Cast chip stays interactive: tapping it opens the cast picker.

Commit: `feat(station): show age and cast subtitle on Markører rows`.

### Step 4. **test**: sweep and final verification

Two cleanup tasks.

1. Grep for the new keys and the bug signature:

   ```
   grep -rn "castedByLine\|noCastLine" lib/ test/
   grep -rn "no routes for location" test/
   grep -rn "Icons.theater_comedy" lib/views/station_screen.dart
   ```

   The two new ARB getters should appear in the Station-screen row build. The grep for the GoException string should return no hits (the route is now registered). The Station-screen row still uses the theatre glyph as leading.

2. Run the full verification:
   - `flutter analyze` clean.
   - `flutter test` passes (except the known-broken `test/widget_test.dart`).
   - `make build` runs without diff.

Commit: `test(roleplay): cover route fix and station-row enrichment`.

## Verification

After all four steps:

1. `flutter analyze` clean.
2. `flutter test` passes (except the known-broken `test/widget_test.dart`).
3. `make build` runs without diff.
4. Manual QA (record in the PR description):
   - Open the dedicated Station screen via the Stations tab → tap-row navigation. The Markører section shows rows with age in the title and a subtitle reading either "Spilles av <name>" (when cast) or "Ingen markør valgt" (when not, styled subtly italic). Cast chip remains interactive — tap opens the cast picker.
   - Tap a row body. `RolePlayScreen` opens with the right role. No GoException in the console.
   - Edit a role's name and age via the swipe-left handler. The row reflects the change after the form pops.
   - Cast an actor. The subtitle switches from "Ingen markør valgt" (italic, subdued) to "Spilles av <actor name>" (regular weight). Cast chip switches from outlined to filled.
   - Clear the cast. Subtitle returns to "Ingen markør valgt"; chip returns to outlined.
   - Confirm there is still no swipe-right, no overflow-menu delete, and no long-press destructive action on the row. Deletion stays out of scope per DESIGN-003 §Deletion and templating.

## Out of scope

- **Browse-surface summaries on the coordinator screen and the Stations-tab expansion.** That work is the next follow-up (`DESIGN-003-followup-station-expansions.md`) and depends on this one (the routing fix and the two new ARB keys land here).
- **Deletion of `RolePlay` records.** DESIGN-003 §Deletion and templating defers this. The service method exists; the UI must not expose it.
- **Template instantiation / "don't use here anymore".** Also deferred.
- **Station-less role creation.** No "no station" affordance in this iteration.
- **Observer-player Role tab.** Still waiting on the DESIGN-001 shell and the blocked Phase B work.
- **The blocked Phase B steps from the main loop** (`SessionParticipant.rolePlayUuid`, broadcaster activation, patch authorization, live roleplayer marker). Out of scope here; those need a separate loop covering ADR-0009 and ADR-0012 first.
- **A `:roleUuid/edit` GoRoute.** Edit-form navigation goes through `Navigator.push` with `MaterialPageRoute` in the existing flows. Adding a GoRoute for the edit form is unnecessary and would just duplicate the form's navigation surface.

## Deliverables

Four commits, in order, that together:

- Register the nested `/roleplays/:roleUuid` GoRoute so the Station-screen Markører rows stop crashing on tap.
- Add the `castedByLine` and `noCastLine` ARB keys (shared with the next follow-up).
- Enrich the Station-screen Markører rows with age in the title and an explicit cast subtitle, matching the two-line layout the design doc now specifies.
- Sweep, test and verify.

DESIGN-003 §Creating roles (the Station-screen "Markører" row anatomy) and §Tile anatomy (cast-suffix scoping) are the authoritative specs for this change.
