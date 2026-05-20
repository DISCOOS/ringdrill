# Codex CLI prompt: Implement ADR-0008

Copy everything below the line into Codex CLI. The prompt is self-contained and references files inside this repo.

---

You are working in the RingDrill repository. Implement ADR-0008 ("Persistent program library with active plan and shared catalog") end-to-end. The ADR lives at `docs/adrs/0008-persistent-program-library-and-catalog.md` and is accepted. It is the authoritative spec for this change. Read it in full before you start.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* Run codegen after editing freezed/json-annotated files: `make build` (or `dart run build_runner build --delete-conflicting-outputs`). Never hand-edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.
* CLI must stay Flutter-free. `bin/ringdrill.dart` and anything it imports (currently `lib/data/drill_client.dart`) must not import `package:flutter/*`. The `Program` model lives under `lib/models/` and is imported by the CLI path, so do not add Flutter imports to it.
* Mobile-safe imports. Anything reachable from `lib/main.dart` on a non-web platform must not transitively import `dart:html` or `package:web`. Web-only code lives under `lib/web/` with a stub.
* Localize every user-visible string. Add the key to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. If you do not know the Norwegian translation, copy the English string and flag it in the PR description.
* Use `SimpleTimeOfDay` in models and the CLI. `TimeOfDay` only inside widgets.
* Sentry only inside `if (Sentry.isEnabled)`. Default consent is opt-out.
* Match existing Dart style. Do not add new lint suppressions.

## Scope

The implementation is split into seven steps. Do them in order and run codegen/analyze between steps where indicated.

### Step 1. Data model

Extend `lib/models/program.dart`:

* Add a `ProgramSource` sealed freezed union with three variants. Use freezed union factories on a single sealed class so JSON round-trips cleanly:
  * `ProgramSource.local()`
  * `ProgramSource.imported({required String fileName})`
  * `ProgramSource.catalog({required String slug, required String latestEtag, DateTime? installedAt})`
* Add `ProgramSource source` and `String? contentHash` fields to `Program`. `contentHash` is a stable hash over the canonical JSON of `exercises`+`teams`+`sessions` (sorted by uuid), computed at install/upload time. Provide a `Program` extension `computeContentHash()` (sha256, hex string) in `lib/models/program.dart` or a new `lib/models/program_diff.dart`.
* Add a `ProgramDiff` freezed class with `addedExercises`, `removedExercises`, `modifiedExercises` (each a `List<String>` of names or uuids), same for teams and sessions. Provide a pure-Dart `ProgramDiff diffPrograms(Program local, Program remote)` function.
* Keep the existing `Program`, `Session`, `ProgramMetadata` shape otherwise. Add `source` and `contentHash` with safe defaults so older JSON still deserializes (`@Default(...)` for source, nullable for hash).
* Run `make build`.

### Step 2. Repository

Rewrite `lib/data/program_repository.dart` to be plan-scoped while keeping a thin compatibility surface for existing callers:

* New key format in `SharedPreferences`:
  * `p:<programUuid>` -> Program shell JSON (no nested lists)
  * `pe:<programUuid>:<exerciseUuid>` -> Exercise JSON
  * `pt:<programUuid>:<teamUuid>` -> Team JSON
  * `ps:<programUuid>:<sessionUuid>` -> Session JSON
  * `app:activeProgram:v1` -> String, UUID of active plan
  * `app:librarySchema:v1` -> String, `"1"` once migration has run
* New API surface (alongside existing methods, which become thin wrappers that operate on the active plan):
  * `Future<void> init()` runs migration if needed.
  * `List<Program> listPrograms()` returns shells.
  * `Program? loadProgram(String uuid)` returns shell + nested.
  * `Future<void> saveProgramShell(Program program)` writes shell only.
  * `Future<void> deleteProgram(String uuid)` removes shell and all `pe:/pt:/ps:` for that plan.
  * `String? get activeProgramUuid` and `Future<void> setActiveProgramUuid(String uuid)`.
  * `List<Exercise> loadExercises([String? programUuid])` etc. Default to active plan when omitted.
  * Same for `loadTeams`, `loadSessions`, `saveExercise`, `saveTeam`, `saveSession`, `deleteExercise`, `deleteTeam`, `deleteSession`.
* One-shot migration from legacy `e:<uuid>` / `t:<uuid>` keys:
  * If `app:librarySchema:v1` is absent and any `e:` or `t:` keys exist, generate a default program uuid (`nanoid(10)`), copy each `e:<uuid>` to `pe:<defaultUuid>:<uuid>` and each `t:<uuid>` to `pt:<defaultUuid>:<uuid>`, write a `Program` shell to `p:<defaultUuid>` with name "Default plan" (localized fallback handled at the service layer, the repo writes a stable English placeholder that the service can rename), `source: ProgramSource.local()`, and an empty sessions list.
  * Set `app:activeProgram:v1 = <defaultUuid>`.
  * Remove the legacy `e:` and `t:` keys.
  * Write `app:librarySchema:v1 = "1"`.
  * The operation must be idempotent. Subsequent calls do nothing.
* If `app:librarySchema:v1` is present but no programs exist (fresh install), do not create one. Leave the library empty. The service layer is responsible for inviting the user to create a plan.

Add a pure-Dart test in `test/program_repository_migration_test.dart` that:

* Seeds `SharedPreferences` (use `SharedPreferences.setMockInitialValues`) with a couple of `e:` and `t:` entries and no `app:librarySchema:v1`.
* Calls `init()`.
* Asserts a default program exists, exercises/teams are migrated under `pe:`/`pt:`, `activeProgramUuid` is set, legacy keys are gone, and a second call to `init()` is a no-op.

### Step 3. Service layer

Rewrite `lib/services/program_service.dart`:

* `init()` calls `_repo.init()`, then loads exercises from the active plan.
* New public surface:
  * `List<Program> listPrograms()` returns shells.
  * `Program? get activeProgram` returns the active shell (or null if library is empty).
  * `Future<Program> createProgram({required String name, String description = ''})` creates and persists a new plan with `ProgramSource.local()` and an empty content. Does not auto-activate.
  * `Future<void> setActive(String uuid)`. Blocks with `StateError` when `ExerciseService().isStarted`.
  * `Future<void> deleteProgram(String uuid)`. Blocks with `StateError` when uuid is active and `ExerciseService().isStarted`.
  * `Future<Program> installFromFile(DrillFile file, {bool activate = false})` reads the program, assigns a fresh `programUuid` if it would collide with an existing local one, writes all nested entities under the new uuid, sets `ProgramSource.imported(fileName: file.fileName)`, computes and stores `contentHash`. Returns the installed shell. Activates iff `activate == true`.
  * `Future<Program> installFromCatalog(MarketFeedItem item, DrillClient client, {bool activate = false})` calls `client.download(item.slug)`, converts to `DrillFile`, installs via `installFromFile`, then overwrites `source` to `ProgramSource.catalog(slug: item.slug, latestEtag: <etag from download>, installedAt: DateTime.now())`. Returns the shell.
  * `Future<CatalogRefreshOutcome> refreshCatalogItem(String programUuid, DrillClient client, {required Future<CatalogConflictChoice> Function(ProgramDiff diff, {required bool ownedSlug}) onConflict})`. Implements the flow in the ADR "Catalog refresh and local changes" section. Use `client.head(slug, ifNoneMatch: latestEtag)` to decide if an update is needed; download via `client.download(slug)`. Compute `ProgramDiff` between the local plan and the incoming remote. When the local `contentHash` matches the stored `latestEtag`-anchored hash, apply silently. Otherwise call `onConflict` and act on the result.
* Define the supporting types in `lib/services/program_service.dart` (or a new `lib/services/catalog_refresh.dart`):
  * `enum CatalogConflictChoice { cancel, overwriteLocal, publishMyChanges, forkAsLocal }`.
  * `class CatalogRefreshOutcome { final CatalogRefreshKind kind; final String programUuid; final ProgramDiff? diff; }`.
  * `enum CatalogRefreshKind { upToDate, updatedSilently, updatedAfterPrompt, cancelled, published, forked, failed }`.
  * `ownedSlug` is true when the local plan's `ProgramSource.catalog` source has a `latestEtag` *and* the user is the owner. For the MVP, infer ownership from a new `app:catalogOwnership:<slug>` preference key that we set to `true` whenever the local user uploads to that slug (via `publishMyChanges`). Unknown slugs default to `false`.
* Update `ProgramEvent` to include events `programCreated`, `programDeleted`, `programActivated`, `programInstalled`, `programRefreshed`. Keep the existing exercise/team events. Existing `saveExercise` continues to emit `exerciseAdded` for the active plan.
* All existing exercise/team CRUD continues to operate against the active plan. The signature stays the same so call sites do not need to change.
* When the library is empty after migration (fresh install path), `init()` returns an empty list. The first `saveExercise` call from the UI must trigger `createProgram(name: localizations.defaultPlanName)` and activate it before saving.

### Step 4. UI: LibraryView

Add `lib/views/library_view.dart`:

* A `StatefulWidget` with a `TabBar` and two tabs: "My plans" and "Catalog". Use the localizations entries `libraryMyPlans` and `libraryCatalog`.
* "My plans" tab:
  * Calls `ProgramService().listPrograms()`.
  * Renders each plan as a `ListTile`. Title is the plan name. Subtitle shows the source as a humanized string ("Local", "Imported from <file>", "From catalog · <slug>"), exercise count and last update.
  * Active plan is marked with a leading filled radio icon and a localized "Active" badge in the trailing area.
  * Tap activates the plan (via `setActive`). Blocked with a localized SnackBar when `ExerciseService.isStarted`.
  * Swipe-to-delete with confirm dialog (mirror the dismiss pattern in `lib/views/program_view.dart`). Cannot delete the active plan when the service is running.
  * Long-press opens a bottom sheet with `Rename`, `Refresh from catalog` (only for catalog plans), `Export as .drill` and `Delete`.
* "Catalog" tab:
  * Calls `DrillClient(baseUrl: ...).marketFeed()`. The base URL is the same one `lib/data/drill_client.dart` uses today; do not introduce a new config key. If web build, `baseUrl: ''` (same-origin). If native, use the existing `kRingDrillBaseUrl` constant if present, otherwise hard-code `https://ringdrill.netlify.app` as the default (search the repo for the existing definition; if it does not exist, add it to `lib/utils/app_config.dart`).
  * Pull-to-refresh.
  * Each row shows `name`, comma-separated `tags` and an Install button. If the slug is already installed locally (any program with `source.catalog.slug == item.slug`), show "Installed" instead and disable Install.
  * Install button calls `installFromCatalog` and shows a SnackBar with the result.
  * Loading state, empty state ("Catalog is empty"), error state with a Retry button.
* Add the route `/library` to `buildRouter` in `lib/views/main_screen.dart` as a top-level route (not inside the shell, so the AppBar and FAB are managed by `LibraryView` itself).
* Add a drawer entry "Library" in `_buildDrawer` that navigates to `/library`.

Add the localization keys in `lib/l10n/app_en.arb` and `app_nb.arb`. At minimum:

* `library`, `libraryMyPlans`, `libraryCatalog`
* `librarySourceLocal`, `librarySourceImported` (with placeholder), `librarySourceCatalog` (with placeholder)
* `libraryActive`, `libraryInstalled`
* `libraryInstall`, `libraryRefresh`, `libraryRename`, `libraryExport`, `libraryDelete`
* `libraryEmptyCatalog`, `libraryErrorLoad`, `libraryRetry`
* `libraryCannotSwitchRunning` (SnackBar when blocked)
* `defaultPlanName` (used by service for first plan after migration / first save)
* `catalogConflictTitle`, `catalogConflictBody`, `catalogConflictCancel`, `catalogConflictOverwrite`, `catalogConflictPublish`, `catalogConflictFork`
* `catalogDiffAdded`, `catalogDiffRemoved`, `catalogDiffModified`, `catalogDiffExercises`, `catalogDiffTeams`, `catalogDiffSessions`

### Step 5. UI: catalog conflict dialog

Add `lib/views/catalog_conflict_dialog.dart`:

* A `Future<CatalogConflictChoice> showCatalogConflictDialog(BuildContext context, {required ProgramDiff diff, required bool ownedSlug})` helper.
* Renders the diff grouped by exercises/teams/sessions with added/removed/modified sections.
* Three or four buttons depending on `ownedSlug`:
  * "Cancel" -> `CatalogConflictChoice.cancel`
  * "Overwrite local" -> `overwriteLocal`
  * "Publish my changes" -> `publishMyChanges` (only when `ownedSlug == true`)
  * "Fork as local plan" -> `forkAsLocal` (only when `ownedSlug == false`)
* The diff is always shown, regardless of which choice the user picks.

Wire this dialog into the "Refresh from catalog" entry of the LibraryView long-press menu by passing it as the `onConflict` callback to `refreshCatalogItem`.

### Step 6. UI: active plan indicator and openProgram semantics change

Update `lib/views/program_view.dart`:

* `ProgramPageControllerBase.title()` returns the active plan name when present, fallback to `localizations.exercise(2)`.
* In `_handleMenuAction`, the `open` action keeps its label "Open program" but now calls `programService.installFromFile(drillFile, activate: true)` instead of the legacy `openProgram`. Show a SnackBar like "Installed and activated <name>".
* Add a SnackBar shown once after migration explaining the change. Trigger condition: `app:librarySchema:v1` was just set in this app launch. Use a flag in `AppConfig`, e.g. `app:librarySchemaJustMigrated`, set true by the repo when migration ran in this session, consumed (cleared) by `MainScreen` after the SnackBar is dismissed.

The legacy `ProgramService.openProgram` can stay in place for backwards compatibility but should now delegate to `installFromFile(..., activate: true)`. Existing tests that call it must continue to work.

### Step 7. Verification

Before claiming done:

* `make build`
* `flutter analyze`
* `flutter test`
* `test/widget_test.dart` is known-broken (default Flutter counter template, expects a `+` button). Acknowledge it in your summary; do not fix it as part of this change unless trivial.
* Manually verify with `flutter run -d chrome`:
  * App migrates an existing single-plan state (seed it by hand via DevTools or a debug helper) to a "Default plan" without losing exercises.
  * Library shows the plan; activate works; delete works.
  * Catalog tab lists market-feed items and Install creates a new plan with `ProgramSource.catalog`.
  * Open program from file installs and activates without wiping other plans.
  * Refresh from catalog with no local changes is silent; with local changes shows the conflict dialog.

## Out of scope

* Per-organization / team filtering of the catalog.
* Multiple plans running in parallel in `ExerciseService`.
* Replacing SharedPreferences with hive/sqflite.
* Backend changes beyond what `DrillClient` already exposes.

## Deliverable

A single change set that:

* Adds the new model, repository, service, views and localizations.
* Includes the migration test.
* Passes `flutter analyze` and `flutter test` (modulo the known-broken `widget_test.dart`).
* Updates no ADRs. ADR-0008 already covers this work and is accepted.

If you encounter a decision the ADR does not cover, pick the smallest change that is consistent with the ADR's spirit and note it in the PR description. Do not invent new architecture.
