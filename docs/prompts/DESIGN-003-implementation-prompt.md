You are working in the RingDrill repository. Implement DESIGN-003 ("RolePlays tab / Markører-fanen") end-to-end together with the model and transport changes from ADR-0018 and ADR-0019 that DESIGN-003 depends on. The authoritative specs live at:

- `docs/design/roleplays-tab.md` (DESIGN-003, Accepted) — UI surface and behaviour.
- `docs/adrs/0018-roleplayer-data-model.md` (ADR-0018, Accepted) — `RolePlay` and `Actor` models, archive layout, schema 1.1.
- `docs/adrs/0019-roleplayer-participant-role.md` (ADR-0019, Accepted) — `rolePlayUuid` on `SessionParticipant`, broadcaster activation, patch authorization.

Read all three in full before you start. If anything in this prompt appears to contradict them, the specs win. Stop and ask for guidance rather than silently diverging.

Also skim:

- `docs/design/stations-tab.md` (DESIGN-002) — the pattern DESIGN-003 mirrors (expandable tile, filter FAB, mutex expansion).
- `docs/adrs/0007-drill-file-format.md` — the file format that grows the two new folders.
- `docs/adrs/0009-realtime-transport-and-session-model.md` and `docs/adrs/0012-position-sharing-and-team-aggregation.md` — the session and position-broadcasting contracts ADR-0019 extends.
- `docs/prompts/0017-implementation-prompt.md` — the prior successful loop, used here as the structural template.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

- **Run codegen.** `RolePlay`, `Actor`, the `Program` extension and the `SessionParticipant` extension are all `@freezed`. After any model edit, run `make build` (or `dart run build_runner build --delete-conflicting-outputs`). Never hand-edit `*.freezed.dart` or `*.g.dart`.
- **Localize every user-visible string.** Add the key to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Norwegian UI uses "Markører" (tab/roster), "Rolle" (Role section), "Markør" (Cast section, singular). English uses "RolePlays" (tab), "Role" and "Cast". If a Norwegian translation is uncertain, copy the English string and flag it in the commit body for review. Norwegian for *station* stays "post"/"poster" per the project terminology rule.
- **CLI must stay Flutter-free.** `bin/ringdrill.dart` and anything it transitively imports (currently only `lib/data/drill_client.dart`) must not gain a `package:flutter/*` import. The new models, drill-file changes and session changes all belong in CLI-safe layers. UI work is widget-only.
- **Mobile-safe imports.** Nothing in this change reaches `dart:html` or `package:web`.
- **Analytics consent gate.** Do not introduce new Sentry, analytics or telemetry calls. If a new failure path warrants logging, route it through the existing `SentryConfig` gate.
- **Match existing Dart style.** No new lint suppressions without an inline comment explaining why.
- **Verify before claiming green.** Run `flutter analyze` and `flutter test` before reporting a step done. `test/widget_test.dart` is the known-broken default-template smoke test; acknowledge that rather than asserting all tests pass.
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart` directly.** They regenerate.
- **Backend coupling.** Anything that bumps the on-disk schema is a coordinated change across the Flutter app, the model files and `netlify/functions/drills-upload.js`. Do not change the schema constant in one place without the other.
- **MapView stays domain-agnostic.** New marker types are added via slot props or marker tuples, not a `isRolePlay` boolean. See the existing `markers: [(index, label, position)]` shape in `lib/views/map_view.dart` and extend that shape rather than branching on domain flags inside `MapView`.
- **Trust model.** Coordinator/roleplayer mutex is client-enforced only per ADR-0019. Server tolerates both; do not add server-side enforcement.

## Token discipline

Each loop iteration draws against the budget that pays for the model. Treat tokens as a constrained resource and make cost/benefit calls as you work. These are defaults you may break with a one-line justification in the commit body.

- **Prefer narrow reads.** Use `Glob` and `Grep` to locate, then `Read` with `offset`/`limit` when you only need a section. A full-file read on a large file to change a single line is wasteful.
- **Skip generated files.** `*.freezed.dart`, `*.g.dart` and `app_localizations*.dart` regenerate from source. There is no value in reading them, and they bloat context fast.
- **Do not re-read within a step.** Hold files you already read in working memory. Re-reading the same file across two `Read` calls in the same step is almost always a sign of context loss; pause and check whether you actually need the content again.
- **Run each gate once.** `flutter analyze` and `flutter test` are step-end verification. Do not run them between intermediate edits unless you are debugging a specific failure surfaced by an earlier run.
- **Delegate cheap lookups.** Where the harness offers a lighter-model subagent (for example `Explore` on Haiku), use it for "where is X defined", "which files import Y" and similar searches. Do not spend the implementing model's tokens on lookup work.
- **Resist speculative refactors.** If you spot something off-scope worth fixing, add a one-line note to `docs/prompts/DESIGN-003-followups.md` (create on first use) and keep moving. The only in-scope refactor invitation is the "extract shared filter banner" call-out in Step 15, bounded by the ~150-line cap.
- **Commit bodies are short.** Two to four short paragraphs is enough. Reference the ADR or design doc rather than replaying the work step by step.
- **Tests target new behaviour.** Do not add regression coverage for code surrounding your change unless that surrounding code is currently uncovered and your change interacts with it directly.
- **Pick the smaller diff.** When two approaches are technically equivalent, choose the one that touches fewer files or adds fewer lines.
- **Stop when stuck.** If you find yourself burning iterations on a single failure without progress, stop and write to `docs/prompts/DESIGN-003-blockers.md` rather than thrashing.

### Handoff between iterations

The loop runs as a sequence of steps. Each step may execute in a fresh context (separate CLI invocation) or in a continuous session. Either way, treat the boundary between steps as a place to drop detail and carry forward only what the next step needs.

- **Read the handoff first.** At the start of every step, before any `Read`/`Glob`/`Grep`, read `docs/prompts/DESIGN-003-handoff.md` (create on first use). The handoff is the authoritative record of facts established by prior steps that are not obvious from `git log` alone. Trust it; do not re-verify state it asserts unless you have reason to suspect it is stale.
- **Write the handoff at step end.** After committing, append a single entry with the format below. Three to five lines. Do not paste diffs or full file contents.

  ```
  ## Step <N>: <short title> (<commit sha>)
  - State established: <one line, e.g. "Program now has rolePlays/actors fields; all call sites passing []">
  - Next step inputs: <one line, e.g. "ARB keys for cast picker live at app_en.arb lines 234-256">
  - Deferred: <one line if anything was noticed and parked; omit otherwise>
  ```

- **Compact at phase boundaries.** When you cross from Phase A to B, B to C, C to D or D to E, the detail accumulated in the prior phase is no longer relevant to forward progress. If you are running in Claude Code interactive mode, issue `/compact` after the last commit of a phase. If you are running headless, end the iteration on a clean phase boundary so the next invocation starts with a fresh context plus the handoff. The handoff file is what makes both modes equivalent.
- **Keep the handoff append-only.** Never rewrite or compress entries. The file grows linearly and the operator may want the trail intact for review. If it gets long enough to hurt your own reads, use `Read` with `offset` to grab only the last two or three entries.

The bar is enough rigor to land a correct change, not maximum thoroughness. A loop that completes 19 reviewable commits in 60% of the budget beats one that completes 12 over-engineered commits in 100%.

## Commits

Commit at the end of each step below. Use Conventional Commits with a scope. Allowed types in this repo: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Scopes already in use that apply here: `program`, `model`, `drillfile`, `session`, `position`, `roleplay`, `actor`, `l10n`, `map`, `navigation`, `widget`. Pick the most specific one. Format:

```
<type>(<scope>): <imperative subject, lowercase, no trailing period>

<wrap body at ~72 chars. Reference ADR-0018, ADR-0019 or DESIGN-003 in the
body where it adds context. Multiple paragraphs are fine.>
```

Examples that match this change set:

- `feat(model): add RolePlay and Actor entities per ADR-0018`
- `feat(program): include rolePlays and actors collections`
- `feat(drillfile): persist roleplays and actors folders, schema 1.1`
- `feat(session): add rolePlayUuid to SessionParticipant`
- `feat(roleplay): add RoleExpansionTile widget`
- `feat(navigation): add Markører as fifth bottom-navigation destination`

One commit per step. Do **not** squash steps into a single "implement DESIGN-003" commit; bisect and review break down otherwise.

## Loop control

The loop driver picks up the next unfinished step by inspecting `git log` against the step headings. Each step's commit subject contains the keyword in **bold** in its heading. If a step is partially landed (commit exists but verification failed), open the commit, fix forward, amend. Never revert a green commit to re-do a step "cleanly".

If `flutter analyze` or `flutter test` fails after a step:

1. Read the failure.
2. Fix in a follow-up commit on the same step (`fix(<scope>): ...`) rather than amending unless the failure is trivially a typo.
3. Only proceed to the next step once both gates are clean.

If a step cannot be completed because the spec is ambiguous or a precondition is unmet, stop the loop and write a one-paragraph note to `docs/prompts/DESIGN-003-blockers.md` (create the file if needed) explaining what was blocking and what choice the loop would have had to make. Then exit non-zero so the operator notices.

## Scope and step order

Implementation is divided into five phases and 19 steps. Do them in order. Each step's heading contains the commit keyword.

### Phase A — Data model (ADR-0018)

#### Step 1. **roleplay**: add `RolePlay` and `Actor` freezed models

New files:

- `lib/models/role_play.dart` with the `RolePlay` class as specified in ADR-0018 §Models. Fields: `uuid`, `index`, `exerciseUuid`, `name`, `age?`, `signalement?`, `background?`, `behavior?`, `stationIndex?`, `position?` using `NullableLatLngJsonConverter`, `actorUuid?`. Freezed sealed class with `fromJson`. Behaviour-free; helpers go in an extension if needed.
- `lib/models/actor.dart` with the `Actor` class. Fields: `uuid`, `realName`, `phone?`, `notes?`. Freezed sealed class with `fromJson`.

Run `make build`. Add a short serialization round-trip test under `test/models/role_play_test.dart` and `test/models/actor_test.dart` covering populated and minimal instances.

Commit: `feat(model): add RolePlay and Actor entities per ADR-0018`.

#### Step 2. **program**: include `rolePlays` and `actors` collections

Edit `lib/models/program.dart`:

- Add `required List<RolePlay> rolePlays` and `required List<Actor> actors` to the `Program` factory.
- Extend `computeContentHash` to include `rolePlays` in the canonical map (sorted by uuid). **Exclude `actors`** so local cast changes never flag the program as "ahead of remote".
- Extend `ProgramDiff` with `addedRolePlays`, `removedRolePlays`, `modifiedRolePlays`. **No** diff fields for `actors` (consistent with the hash decision; cast changes are local-only).
- Update `diffPrograms` to populate the new fields using `_diffNamed` against `(rp) => rp.name`.

Run `make build`. Update every constructor call site for `Program` to pass `rolePlays: []` and `actors: []` as defaults (search with `grep -rn "Program(" lib/ test/ netlify/`). Tests in `test/program_repository_migration_test.dart` and others must continue to compile and pass.

Add a unit test that `computeContentHash` is stable across mutations of `actors` and changes when `rolePlays` changes.

Commit: `feat(program): include rolePlays and actors collections`.

#### Step 3. **model**: persist `schema` in `ProgramMetadata`

Edit `lib/models/program.dart`:

- Add `String? schema` to `ProgramMetadata`. Optional, so 1.0 archives parse unchanged.
- 1.1-aware writers must set `schema: DrillFile.drillSchemaCurrent` (added in Step 4).
- Readers that need to act on schema use `metadata.schema ?? DrillFile.drillSchema1_0`.

Run `make build`. Add a serialization test that `ProgramMetadata` round-trips with and without `schema`.

Commit: `feat(model): persist schema marker in ProgramMetadata`.

#### Step 4. **drillfile**: persist `roleplays/` and `actors/` folders, schema 1.1

Edit `lib/data/drill_file.dart`:

- Add `static const drillSchema1_1 = '1.1';` and `static const drillSchemaCurrent = drillSchema1_1;` alongside the existing `drillSchema1_0`.
- `DrillFile.fromProgram` writes `roleplays/<uuid>.json` and `actors/<uuid>.json` entries, and writes `schema: drillSchemaCurrent` into `metadata.json`.
- `DrillFile.program()` reads both folders. Older archives without the folders deserialize to empty lists. Older archives without `metadata.schema` are treated as `'1.0'`.
- The reader matches by prefix; unknown top-level entries are ignored silently.

Add a round-trip test under `test/data/drill_file_roleplay_test.dart`:

- Round-trip a program with two `RolePlay` entries and one `Actor`, assert both come back identical and that `metadata.schema` survives as `'1.1'`.
- Round-trip a program without any rolePlays/actors, assert the archive structure is byte-stable against the 1.0 baseline (no spurious empty folders; `schema` may still appear in metadata).
- Open a synthetic 1.0 archive (no `roleplays/`, no `actors/`, no `schema` field) and assert deserialization yields empty lists and `metadata.schema` is null (interpreted as `'1.0'`).

Commit: `feat(drillfile): persist roleplays and actors folders, schema 1.1`.

#### Step 5. **backend**: strip `actors/` on catalog upload, reject unknown schemas

Edit `netlify/functions/drills-upload.js`:

- Before storage, strip every entry whose path starts with `actors/` from the uploaded archive.
- Read `metadata.json` from the archive and reject (HTTP 415 with a JSON error body) if `schema` is a string whose semantic value exceeds `'1.1'`. Absent or `'1.0'`/`'1.1'` schemas are accepted.
- Add or update the function's unit/integration tests under `netlify/functions/__tests__/` (mirror existing test structure; check what's there before inventing a new one).

Do **not** strip `actors/` from peer-to-peer files (USB, AirDrop, email). The strip is catalog-upload only.

Commit: `feat(backend): strip actors folder and reject unknown schemas on upload`.

### Phase B — Session model (ADR-0019)

#### Step 6. **session**: add `rolePlayUuid` to `SessionParticipant`

Edit `lib/data/session_status.dart`:

- Add `String? rolePlayUuid` to `SessionParticipant`. Optional, backward compatible.
- Update `fromJson`/`toJson` round-trip (Freezed should handle it automatically once the field exists).

Run `make build`. Add a serialization test that older payloads without `rolePlayUuid` decode with `rolePlayUuid: null`, and that a payload carrying the field round-trips.

Commit: `feat(session): add rolePlayUuid to SessionParticipant`.

#### Step 7. **position**: broadcast when `rolePlayUuid` is set

Edit `lib/services/position_broadcast_service.dart`:

- The broadcaster activation condition changes from `checkedInTeamUuid != null` to `checkedInTeamUuid != null || rolePlayUuid != null`.
- Consent rules (`app:liveConsent:v1`, `app:positionConsent:v1`) are unchanged. The roleplayer check-in path surfaces the same prompts; do not bypass them.

Add tests for the new activation path:

- Roleplayer (no team, has `rolePlayUuid`) with consent → broadcaster active.
- Roleplayer without consent → broadcaster inactive.
- Team member with `rolePlayUuid` also set (operationally team-attached roleplayer) → broadcaster active.

Commit: `feat(position): broadcast when rolePlayUuid is set`.

#### Step 8. **realtime**: allow `participant_position` patches from roleplayers

Update the patch authorization rule wherever it is enforced (likely a function in `lib/services/` or `lib/data/`; grep for `checkedInTeamUuid` to locate). The new rule reads:

> the device whose `participantId` matches the patch, provided their `participants[participantId].checkedInTeamUuid` is non-null **OR** `rolePlayUuid` is non-null.

Add a test that a `participant_position` patch from a roleplayer-only participant is accepted, and one from a pure observer (`isCoordinator == false && checkedInTeamUuid == null && rolePlayUuid == null`) is still rejected.

Commit: `feat(realtime): allow position patches from roleplayers`.

### Phase C — Authoring UI (DESIGN-003)

#### Step 9. **l10n**: add Markører strings

Add the following ARB keys to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. Place them grouped with related stations keys for readability.

| Key | English | Norwegian |
|-----|---------|-----------|
| `rolePlaysTab` | RolePlays | Markører |
| `roleSection` | Role | Rolle |
| `castSection` | Cast | Markør |
| `addCast` | Add cast | Velg markør |
| `editCast` | Edit cast | Rediger markør |
| `clearCast` | Clear cast | Fjern markør |
| `castRoster` | Cast roster | Markører |
| `newActor` | New actor | Ny markør |
| `castedAs` | Cast as: {names} | Markør for: {names} |
| `alreadyCastAs` | Already cast as {name} | Allerede markør for {name} |
| `castPickerTitle` | Cast: {role} | Markør: {role} |
| `castPrivateHint` | Private — never published | Privat — publiseres aldri |
| `noSignalement` | No description | Ingen signalement |
| `noBackground` | No background | Ingen bakgrunn |
| `noBehavior` | No behaviour | Ingen oppførsel |
| `noStationAssigned` | No station | Ingen post |
| `noRolesInProgram` | No roles yet. Add a role from the Exercises tab. | Ingen markører ennå. Legg til en rolle fra Øvelser-fanen. |
| `noRolesInExercise` | No roles in this exercise. | Ingen markører for denne øvelsen. |
| `showAllRoles` | Show all | Vis alle |
| `showingRolesIn` | Showing roles in: {exercise} | Viser markører i: {exercise} |
| `castDeleteBlocked` | Cast in {count} role(s). Clear before deleting. | Markør i {count} rolle(r). Fjern først. |
| `confirmReduceRoles` | (placeholder) | (placeholder) |

`castedAs`, `alreadyCastAs`, `castPickerTitle`, `showingRolesIn` and `castDeleteBlocked` take placeholders; declare them as `@<key>` metadata with `{type: String}` / `{type: int}` as appropriate.

`confirmReduceRoles` is listed here only as a placeholder so the loop reserves the key. Final wording is added in the step that needs it.

Commit: `feat(l10n): add Markører strings for DESIGN-003`.

#### Step 10. **widget**: add `RoleExpansionTile`

New file `lib/views/widgets/role_expansion_tile.dart`. Built on the same slot pattern as `StationExpansionTile`. Slots: `leading`, `title`, `subtitle?`, `trailing?`, `body`, `expanded`, `onOpen`, `onToggle`. Tap targets are split identically: body → `onOpen`, chevron → `onToggle`. The widget owns no domain state.

Also add a `RoleCodeBadge` mirroring `StationCodeBadge`, taking a `code` string and a `highlight` flag. Use the same swatch shape so the two badges look like a family.

Widget tests in `test/views/widgets/role_expansion_tile_test.dart`: collapsed-state render, expanded-state body visibility, body tap fires `onOpen`, chevron tap fires `onToggle` only.

Commit: `feat(widget): add RoleExpansionTile`.

#### Step 11. **roleplay**: add `RolePlayScreen` and `RolePlayFormScreen`

New files:

- `lib/views/roleplay_screen.dart` — read view. Shows the same Role-section fields as the expanded tile body. Tap on edit pencil pushes `RolePlayFormScreen`. AppBar: role name + `Icons.edit`. Cast section is **not** shown here; the read screen is the publishable view.
- `lib/views/roleplay_form_screen.dart` — edit form. Fields per ADR-0018: `name`, `age` (optional int), `signalement` (multi-line), `background` (multi-line), `behavior` (multi-line), `stationIndex` (dropdown of stations in the same exercise, plus "No station"), `position` (uses existing `PositionFormField`). `actorUuid` is **not** edited here; casting happens in the cast picker.

Both screens accept the role's `uuid` and look up the live record from `ProgramService`. Saving updates the `RolePlay` in-place and triggers the program persistence path used by `StationFormScreen`.

Form validators: `name` non-empty; `age` (if present) in 0..120; free-text fields unbounded but trimmed.

Tests under `test/views/roleplay_form_screen_test.dart`: name required, age range, save round-trip.

Commit: `feat(roleplay): add read and edit screens`.

#### Step 12. **actor**: add `ActorFormScreen` and cast roster sheet

New files:

- `lib/views/actor_form_screen.dart` — form for `Actor`. Fields: `realName` (required), `phone` (optional, `keyboardType: TextInputType.phone`), `notes` (multi-line). Save persists to the program's `actors` list. Used both as a full-screen route and inside the cast picker's "New actor" flow (`modal: true` constructor flag distinguishes the two).
- `lib/views/widgets/cast_roster_sheet.dart` — bottom sheet listing every `Actor` in the program. Each row: `realName`, `phone` (secondary), and a footer "Cast as: ..." listing role names. Tap row → `ActorFormScreen` (edit). Swipe-left → confirm deletion; deletion blocked when the actor is cast in any role (`castDeleteBlocked` ARB key). FAB inside the sheet: "New actor" / "Ny markør" → `ActorFormScreen` modal.

Tests:

- Roster sheet shows uncast and cast actors with the right footer text.
- Deletion blocked when cast count > 0.
- New-actor flow appends to `actors` and closes the form on save.

Commit: `feat(actor): add form screen and cast roster sheet`.

#### Step 13. **roleplay**: add cast picker bottom sheet

New file `lib/views/widgets/cast_picker_sheet.dart`. `showModalBottomSheet`-based. Top: drag handle, title `castPickerTitle` with the role name, search field. Body: list of every `Actor` in the program, filtered by the search query.

Each actor row shows `realName` + `phone` (secondary). If the actor is already cast to **another** role in the **same exercise**, the row shows `alreadyCastAs` annotation. Still selectable; the warning is informational.

Sticky top-of-list "New actor" / "Ny markør" row. Tap → `ActorFormScreen` in modal mode. On save, the new actor is added to the roster and immediately cast to the current role (set `RolePlay.actorUuid = newActor.uuid`).

Selecting an actor row sets `RolePlay.actorUuid` and closes the sheet. Returning `null` from the sheet means "user cancelled, no change".

Tests:

- Search filters actors by `realName` substring.
- "Already cast as <other role>" appears for cross-cast actors.
- Selection returns the actor's uuid.
- New-actor flow returns the freshly-created uuid.

Commit: `feat(roleplay): add cast picker with new-actor inline`.

#### Step 14. **roleplay**: add the `RolePlaysScreen` (fifth tab body)

New file `lib/views/roleplays_view.dart`. Flat list of `RolePlay` rows across all exercises in the program, sorted first by exercise order then by `role.index`. Each row uses `RoleExpansionTile`:

- Leading: `RoleCodeBadge` showing `${exerciseNumber}.${role.index + 1}`.
- Title: role name. If `age != null`, append `, $age`.
- Subtitle: `Exercise: <exercise.name>`.
- Trailing: cast chip (`Icons.person` filled when cast, `Icons.person_add` outlined when uncast). Tap on chip opens the cast picker directly. Chevron sits next to it.
- Body: two stacked sections, Role and Cast, exactly as specified in DESIGN-003 §Tile anatomy. The Cast section subtitle "Private — never published" appears on the first expanded tile per session (use a static bool or a session flag in the view's state).

Mutex expansion: at most one tile expanded at a time. Same pattern as `StationsView`.

Gestures:

- Tap body → push `RolePlayScreen`.
- Tap cast chip → cast picker.
- Tap mini-map (when `role.position != null`) → reuse `openStationMapSheet`'s pattern adapted to roles. Either generalise that function or add a sibling `openRoleMapSheet`. Discuss before duplicating; the cleaner choice is usually to extract a shared helper accepting a marker tuple.
- Swipe-left on the row → `confirmDismiss` pushes `RolePlayFormScreen`, returns `false`, row snaps. Same pattern as `StationListView`.

AppBar: a `Icons.people_outline` action that opens the cast roster sheet (tooltip "Cast roster" / "Markører").

Tests:

- Tiles render in the correct order (exercise then index).
- Cast chip swap on actor assignment.
- Mutex expansion: opening tile B collapses tile A.
- Swipe-left opens the form and snaps back.

Commit: `feat(roleplay): add Markører tab screen`.

#### Step 15. **roleplay**: add the exercise filter FAB and banner

Add to `RolePlaysScreen`:

- Bottom-right `FloatingActionButton` with `Icons.filter_list`. Inactive (no exercise selected) shows the plain icon; active shows `Badge.count(count: 1, child: fab)`.
- Tap → modal bottom sheet with a radio list of exercises plus an "All exercises" row. Single-select, applies on selection.
- When a filter is active, a slim banner above the bottom navigation shows `showingRolesIn(exerciseName)` and a "Show all" / "Vis alle" recovery button.
- State does **not** persist across process restarts.

This mirrors DESIGN-002 §Filtering. Reuse whatever banner widget the Stations tab uses; if none is a shared widget yet, extract one to `lib/views/widgets/filter_banner.dart` and refactor the Stations tab to use it in the same commit. **However**, only refactor if the diff stays under ~150 lines; otherwise leave the duplication and add a follow-up note.

Empty states:

- No roles in the program: `noRolesInProgram`.
- Filter excludes everything: banner stays visible, list area shows `noRolesInExercise`.

Tests: filter changes list contents, banner appears/disappears with state, "Show all" clears.

Commit: `feat(roleplay): add exercise filter to Markører tab`.

#### Step 16. **navigation**: add Markører as the fifth bottom-navigation destination

Edit `lib/views/app_routes.dart`:

- Add `const String routeRolePlays = '/roleplays';`.

Edit `lib/views/main_screen.dart`:

- The current `routes:` array passed to `MainScreen` is `[routeProgram, routeStations, routeTeams, routeMap]`. DESIGN-003 specifies the destination order as **Exercises, Map, Stations, RolePlays, Teams**. Reorder the array to `[routeProgram, routeMap, routeStations, routeRolePlays, routeTeams]` and update the matching `_destinations`/`NavigationBar` config so positional indices stay aligned with the new order.
- Add a `GoRoute` for `/roleplays` mounting `RolePlaysScreen`. Add the nested `/roleplays/:roleUuid` for the read screen and `/roleplays/:roleUuid/edit` for the form, mirroring the station nesting. Use `parentNavigatorKey` consistently with how station deep links are wired.
- Icon for the new destination: `Icons.theater_comedy`. Label: `localizations.rolePlaysTab`.
- Reordering the bottom nav is a user-facing change for existing users (Map moves from position 3 to 1). Call it out in the commit body so it shows up in the changelog.

The bottom nav now has five destinations: Exercises, Map, Stations, RolePlays, Teams. Five is the upper bound for Material `NavigationBar` before labels collapse on narrow phones; the design accepts that bound. Do not add a sixth.

Tests: a widget test that pumps the router and confirms the fifth destination is wired and that tapping it lands on `routeRolePlays`.

Commit: `feat(navigation): add Markører as fifth bottom-navigation destination`.

### Phase D — Map markers

#### Step 17. **map**: render static role positions via slot props

Extend `MapView` to accept role markers as a separate marker channel. Per the project's `feedback_mapview_domain_agnostic` rule, do **not** add a `isRolePlay` boolean. Either:

- Generalise the existing `markers` tuple shape to include a marker style (a `MarkerSpec` record or enum), or
- Add a parallel `roleMarkers` parameter with the same `(index, label, position)` shape but a distinct rendering.

Pick the option that minimises call-site churn for existing callers. Document the choice in the commit body.

Rendering for static role positions (`RolePlay.position` set, no live broadcaster):

- Shape: rounded square (vs the team's circle).
- Glyph inside: `Icons.theater_comedy`.
- Colour: derived from the role's station colour if `stationIndex != null`, otherwise `colorScheme.tertiary`.
- "Pinned" border weight (heavier) since this is a static position.

Update `StationMiniMap` and any role-side mini-map to pass role markers through the new channel where appropriate.

Tests (golden or widget): a map snapshot containing a static role marker renders as a rounded square with the theatre glyph.

Commit: `feat(map): render static role markers via slot props`.

#### Step 18. **map**: render live roleplayer broadcasters distinct from teams

Extend the live-broadcast rendering path so a `SessionParticipant` with `rolePlayUuid != null` renders as a roleplayer marker rather than a team marker.

- Same shape as the static role marker (rounded square + theatre glyph), but with a thinner border (live, not pinned).
- Label: role name from local `rolePlays` lookup. **No actor identity ever appears here**, per ADR-0019. If the program has not loaded yet, label reads "Unknown role" / "Ukjent rolle" (add ARB key `unknownRole` if missing).
- Stale positions dim per ADR-0012's rule, same as team broadcasters.

If a participant carries both `checkedInTeamUuid` and `rolePlayUuid`, the role marker takes precedence in display (per ADR-0019 §Participant role mapping).

Tests: live roleplayer marker rendered when participant has `rolePlayUuid`, dimming applied when position is stale.

Commit: `feat(map): render live roleplayer broadcasters distinct from teams`.

### Phase E — Tests and manual QA

#### Step 19. **test**: integration coverage and known-broken acknowledgement

Add or update integration-style tests under `test/`:

- Open a 1.0 archive (no `roleplays/`, no `actors/`, no `schema`) and confirm `Program` round-trips with empty lists and `metadata.schema == null` (interpreted as 1.0).
- Open a 1.1 archive with two roles, one actor, and assert the cast linkage survives serialization.
- Confirm `computeContentHash` is stable across actor mutations and changes on role mutations.
- Confirm the catalog-upload path (mock the function input) strips `actors/`.
- Cast-picker test: selecting a "new actor" flow returns the new actor's uuid and appends to the roster.
- Filter banner test: active filter shows the banner and "Show all" clears it.

Run `flutter analyze` and `flutter test`. `test/widget_test.dart` is the default-template smoke test and is **known broken**; do not attempt to fix it. Flag it in the commit body.

Commit: `test(roleplay): integration coverage for DESIGN-003 + ADR-0018/0019`.

## Verification

After all 19 steps:

1. `flutter analyze` clean.
2. `flutter test` — no new failures. `test/widget_test.dart` still broken; do not touch it.
3. `make build` runs without diff (codegen up to date).
4. CLI sanity: `dart pub global activate -s path .` followed by `ringdrill -h` succeeds. This catches accidental `package:flutter/*` imports in CLI-reachable code.
5. Manual QA matrix (record in the PR description):
   - Create a new program. Open the Markører tab; the empty state reads `noRolesInProgram`.
   - From the Exercises tab, add a role to an exercise. Return to Markører; the role appears with code `1.1`, exercise subtitle, uncast chip.
   - Tap the cast chip → cast picker opens with the "New actor" sticky row.
   - Create a new actor via the sticky row → role is cast to the new actor; cast chip changes to filled.
   - Expand the role tile; Role section shows scenario fields, Cast section shows the actor's name and phone. The "Private — never published" hint appears the first time.
   - Tap the row body → `RolePlayScreen` opens (read view, no Cast section visible).
   - Swipe-left on the row → `RolePlayFormScreen` opens; saving an edit returns to the list.
   - Open the AppBar action → cast roster sheet lists the actor with "Cast as: <role name>".
   - Swipe-left to delete the actor; deletion is blocked with `castDeleteBlocked`. Clear the cast from the role, retry; deletion succeeds.
   - Apply the filter FAB to a single exercise; banner appears with "Show all". List narrows. Press "Show all"; list expands.
   - Save the program and re-open it; all roles and the actor round-trip, including position.
   - Export to a `.drill` and re-import; same round-trip.
   - Publish to the catalog (or simulate the upload handler) and confirm the served file does **not** contain `actors/`.
   - Run a session with one device flagged as a roleplayer; confirm the map shows the rounded-square theatre marker and the label is the role name, not the actor's real name.

## Out of scope

- **Role tab inside the observer-player.** DESIGN-001's player shell does not exist in code yet. DESIGN-003 specifies the role-tab content for when the shell lands; building the shell is **not** part of this prompt. Leave a TODO in `lib/views/` if it helps a reader find the deferred work.
- **Behaviour timing.** Free-text only; no structured timeline.
- **Coordinator-to-roleplayer messaging.** Out of scope.
- **Run-state on roles** ("found", "evacuated"). Deferred.
- **Field markers (mobile roleplayers).** Allowed by the spec but consequences are deferred; assume one role at one station for now.
- **Schema enforcement on older clients.** Out of scope per ADR-0018; the marker exists on disk, but client-side refusal is a future ADR.

## Deliverables

A series of commits, one per step, that together:

- Land `RolePlay` and `Actor` in the program data model with schema 1.1 persistence and the catalog-side strip (Phase A).
- Land `rolePlayUuid` on `SessionParticipant` with the broadcaster and patch-authorization extensions (Phase B).
- Land the Markører tab, its tile, screens, cast picker, cast roster sheet, filter FAB and the fifth bottom-navigation destination (Phase C).
- Land the rounded-square theatre marker on the map, both static and live (Phase D).
- Cover the change set with tests and acknowledge the known-broken `test/widget_test.dart` (Phase E).

DESIGN-003 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR or design doc as part of this work.
