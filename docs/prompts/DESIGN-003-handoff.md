## Step 1: RolePlay and Actor models (c346da5)
- State established: `lib/models/role_play.dart` and `lib/models/actor.dart` exist, codegen ran clean, 5 model tests pass.
- Next step inputs: `Program` in `lib/models/program.dart` needs `rolePlays`/`actors` fields; `ProgramRepository` needs CRUD with key prefixes `pr:` and `pa:`; all `Program(...)` call sites need the two new required fields.
- Deferred: nothing.

## Steps 2–5: Program model, repository CRUD, schema 1.1, backend (f857a23, 016442c, 33eb110, 2b0681d)
- `Program` uses `@Default([])` (not `required`) for `rolePlays`/`actors` for 1.0 backward compat.
- `DrillFile` stamps `schema: '1.1'` on `fromProgram` output; reads it back as optional.
- Netlify backend uses `fflate` to strip `actors/` before blob storage and rejects schema > '1.1'.
- `package.json` dependencies updated with `"fflate": "0.8.3"`.

## Phase B blocked (ccdffb7)
- Steps 6–8, 18 documented as blocked in `docs/prompts/DESIGN-003-blockers.md`.
- Session/participant/broadcast layer (ADR-0009/ADR-0012) does not exist.

## Step 9: l10n (e221ec6)
- 22 new keys in `app_en.arb` + `app_nb.arb`. Later additions: `roleName`, `roleAge`, `optional`, `ageRange`, `stationLabel`, `actorRealName`, `actorPhone`, `actorNotes`.

## Step 10: RoleExpansionTile + RoleCodeBadge (6792543)
- `lib/views/widgets/role_expansion_tile.dart` — slot pattern mirroring StationExpansionTile.
- `RoleCodeBadge` uses tertiary colours to distinguish from StationCodeBadge (primary).

## Step 11: RolePlayScreen + RolePlayFormScreen (a6eaee6)
- `RolePlayFormScreen` accepts a `RolePlay` object (not uuid) — same pattern as `StationFormScreen`.
- Caller (`RolePlayScreen`, `RolePlaysView`) is responsible for persisting via `saveRolePlay()`.
- `_RoleMiniMap` uses `MapView` directly (not `StationMiniMap`) per domain-agnostic rule.

## Step 12: ActorFormScreen + CastRosterSheet (4834bb6)
- `ActorFormScreen` pops with the saved `Actor`; caller persists. Uses `nanoid(10)` for new UUIDs.
- `CastRosterSheet` renders actors with cast-to-role footer; swipe-delete blocked when cast.

## Step 13: CastPickerSheet (e14211b)
- Search filters by `realName`; cross-cast annotation shown for sibling roles in same exercise.
- New-actor row at top opens `ActorFormScreen` inline and returns new uuid.
- Tests seed SharedPreferences with correct key names: `'p:$uuid'`, `'app:activeProgram:v1'`.

## Steps 14–16: RolePlaysView + navigation (a1de6ab)
- `RolePlaysController` with exercise filter and cast roster AppBar button.
- `RolePlaysView`: flat list, mutex expansion, cast chip, swipe-to-edit, filter FAB + banner.
- Nav reorder: Exercises/Map/Stations/RolePlays/Teams (Map moved from pos 4 to 2).
- `routeRolePlays = '/roleplays'` added to `app_routes.dart`.

## Step 17: Map role markers (788812f)
- `MapView<K>` gains `roleMarkers` parallel parameter (same tuple shape as `markers`).
- `_RoleMarker` widget: rounded-square container, `Icons.theater_comedy`, `colorScheme.tertiary`.
- `StationsView` passes role positions from `loadRolePlays()` where `position != null`.

## Step 18: BLOCKED
- Live roleplayer broadcaster requires `SessionParticipant` (ADR-0009/ADR-0012). Not implemented.

## Step 19: Verification
- `flutter analyze`: no issues
- `flutter test`: 58 tests pass (all new + existing)
- `make build`: 0 outputs written (codegen stable)

## Follow-up: Creating roles (DESIGN-003-followup-creating-roles.md)

### Follow-up Step 1: l10n (cbdc1fb)
- `roleSection` (nb): `"Rolle"` → `"Markørordre"` per terminology rule.
- `noRolesInProgram` (en/nb): updated to direct users to Stations tab.
- 8 new keys: `addRolePlay`, `newRolePlayTitle`, `editRolePlayTitle`, `stationRolesSection`, `noRolesAtThisStation`, `roleSignalement`, `roleBackground`, `roleBehavior`.
- `flutter gen-l10n` run explicitly; generated files committed.

### Follow-up Step 2: localize form labels + title fallback (5375d7d)
- `roleplay_form_screen.dart`: literal `'Signalement'`/`'Background'`/`'Behavior'` → localized getters.
- AppBar title falls back to `newRolePlayTitle` when `rolePlay.name.trim().isEmpty`.
- 3 new widget tests added to `test/views/roleplay_form_screen_test.dart` (8 total).

### Follow-up Step 3: Markørordre section on StationExerciseScreen (6a564bd)
- `station_screen.dart`: `_buildRolesSection(station)` Card added below stationInfo (portrait) and below side-by-side Row (landscape).
- Rows: `theater_comedy` icon, name, cast chip, `Dismissible(startToEnd)` → edit form (never dismisses), body tap → `context.push('/roleplays/$uuid')`.
- `_addRolePlay`: `nanoid(10)` draft with `stationIndex` pre-set, pushes `RolePlayFormScreen`.
- `_openCastPicker`: standard `CastPickerSheet` pattern.
- No delete affordance. `ProgramService.deleteRolePlay` stays unwired.
- Exercises stored under `'pe:$programUuid:$uuid'` keys (not inline in program JSON) — critical for test seeding.
- 6 widget tests in new `test/views/station_screen_test.dart`.

### Follow-up Step 4: test alignment (4679446)
- No old wording literals found in test files; unused import removed.

### Follow-up Verification
- `flutter analyze`: no issues
- `flutter test`: 67 tests pass
- `make build`: 0 outputs written (codegen stable)
