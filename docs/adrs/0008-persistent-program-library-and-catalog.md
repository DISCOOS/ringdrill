---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0008: Persistent program library with active plan and shared catalog

## Context and problem statement

Today, RingDrill has only one transient `Program`. No `Program` objects are persisted in `SharedPreferences`. The repository layer stores only `Exercise` (`e:<uuid>`) and `Team` (`t:<uuid>`), and `ProgramService.createProgram()` stitches them together ad hoc into a `Program` every time one is needed. The comment `// TODO: Make Program persistent` appears in several places in [`lib/services/program_service.dart`](../../lib/services/program_service.dart). The consequence is that a user can hold at most one plan at a time, and `openProgram(file)` overwrites the entire exercise library.

The need driving this decision is that users should be able to select a drill plan from a shared catalog (local on the device and shared via the backend) without losing existing plans. The backend already exposes `/api/market/feed` with published `.drill` files, and [`DrillClient.marketFeed()`](../../lib/data/drill_client.dart) reads this from Dart. What is missing is a persistence model for multiple plans, the concept of an "active plan", and a UI surface for browsing and selecting from the catalog.

## Decision drivers

* The user must be able to hold multiple plans at once without an import wiping everything.
* The existing `.drill` format ([ADR-0007](./0007-drill-file-format.md)) remains the canonical exchange format, both inbound and outbound.
* The change must not require backend modifications for the MVP. `/api/market/feed` and `/d/:slug` must cover the first version.
* The runtime (`ExerciseService`) operates on one active exercise at a time. It is simpler and safer to preserve the assumption of a single active plan than to make every service plan-aware.
* Migration from today's data store must be value-preserving and one-shot. Users must not lose exercises on upgrade.
* We do not want to introduce a new state-management mechanism ([ADR-0004](./0004-no-third-party-state-management.md)) or a database ([ADR-0007](./0007-drill-file-format.md)).

## Considered options

* **Active plan + local library + shared catalog (chosen).** One plan is active at a time. Other plans live in a local library and can be activated. The catalog combines local plans with the remote market feed at `/api/market/feed`.
* **Multiple plans in parallel in the runtime.** The user can keep several plans open at once in different tabs. `ExerciseService` and notifications must be made plan-aware.
* **Local multi-plan library only, no catalog.** The user has multiple plans locally, but import is only via `.drill` files. The catalog is deferred.
* **Catalog only, no local persistence of multiple plans.** The user always fetches the plan from remote and overwrites the local copy. The catalog is the source, the local copy is just a cache.

## Decision outcome

Chosen option: **active plan + local library + shared catalog**, because it covers the core need (selecting a plan from a shared catalog without losing other plans), keeps the runtime simple (one active plan), reuses the existing backend and `.drill` format, and lets us evolve toward parallel plans later without discarding this model.

### Data model

`Program` becomes the persistent top-level entity. Each `Program` owns its `Exercise`, `Team` and `Session` by copy, not by reference. This mirrors how `.drill` files already package a self-contained plan, and avoids global UUID collisions between plans imported from different sources.

Key format in `SharedPreferences`:

```
p:<programUuid>                          Program shell (no lists), JSON
pe:<programUuid>:<exerciseUuid>          Exercise JSON
pt:<programUuid>:<teamUuid>              Team JSON
ps:<programUuid>:<sessionUuid>           Session JSON
app:activeProgram:v1                     UUID of the active plan
app:librarySchema:v1                     '1' once migration has run
```

The `Program` shell is extended with a small source field so we know where a plan came from:

```dart
@freezed
sealed class ProgramSource with _$ProgramSource {
  const factory ProgramSource.local() = _Local;
  const factory ProgramSource.imported({required String fileName}) = _Imported;
  const factory ProgramSource.catalog({
    required String slug,
    required String latestEtag,
    DateTime? installedAt,
  }) = _Catalog;
}
```

`ProgramSource` is persisted as part of `Program`. This lets the `LibraryView` show where a plan came from and whether a catalog plan has a newer version available.

### Repository layer

`ProgramRepository` is rewritten to be plan-scoped. The API exposes `listPrograms()`, `loadProgram(uuid)`, `saveProgram(program)`, `deleteProgram(uuid)`, plus CRUD on `Exercise`/`Team`/`Session` parameterized by `programUuid`. The existing read/write methods without `programUuid` are retained as thin wrappers that operate on `activeProgramUuid`, so call sites can be migrated incrementally.

### Migration from legacy keys

At startup, `ProgramRepository.init()` checks whether `app:librarySchema:v1` is missing. If legacy `e:` or `t:` keys exist, a single "Default plan" is created with a generated UUID. All `e:<uuid>` keys are moved to `pe:<defaultUuid>:<uuid>`, all `t:<uuid>` to `pt:<defaultUuid>:<uuid>`. A `Program` shell is written to `p:<defaultUuid>` with `ProgramSource.local()`. `app:activeProgram:v1` is set to `<defaultUuid>`. Finally the legacy keys are removed and `app:librarySchema:v1 = '1'` is written. The operation is idempotent and runs only once.

### Service layer

`ProgramService` gets these new operations, all persistent:

* `Future<List<Program>> listPrograms()` returns all plans as shells (without nested lists).
* `Future<Program> createProgram({required String name, String description = ''})` creates and persists a new empty plan.
* `Future<void> deleteProgram(String uuid)` deletes a plan and all its exercises, teams and sessions. Forbidden against the active plan when `ExerciseService.isStarted`.
* `String get activeProgramUuid` and `Future<void> setActive(String uuid)`. Switching is blocked while `ExerciseService.isStarted`.
* `Future<Program> installFromFile(DrillFile file)` installs a `.drill` file as a new plan in the library and returns it. Replaces today's `openProgram` for the normal case. The existing `openProgram` is kept as "install and activate".
* `Future<Program> installFromCatalog(MarketFeedItem item)` downloads via `DrillClient.download(item.slug)`, calls `installFromFile` and sets `ProgramSource.catalog(slug, latestEtag, installedAt)`.
* `Future<CatalogRefreshOutcome> refreshCatalogItem(String programUuid, {required CatalogConflictResolver onConflict})` checks `DrillClient.head(slug, ifNoneMatch: latestEtag)` for a catalog plan. When a newer version exists it computes a `ProgramDiff` between the local plan and the incoming remote, hands the diff to the `onConflict` resolver, and applies the user's choice (see [Catalog refresh and local changes](#catalog-refresh-and-local-changes) below).

All CRUD operations on `Exercise`/`Team` operate against `activeProgramUuid` unless the call site explicitly passes a `programUuid`. `ExerciseService` is left untouched. It does not know which plan an `Exercise` belongs to and does not need to.

### Catalog refresh and local changes

The baseline refresh policy is **last-remote-wins (LRW)**: when the user accepts an update, the catalog version overwrites the local copy. However, the user must never lose local edits silently. Whenever `refreshCatalogItem` finds a newer remote version *and* the local plan has diverged from the original install (tracked by `ProgramSource.catalog.latestEtag` and a content hash captured at install time), we show a diff and let the user choose between three actions:

1. **Cancel.** Keep the local plan as it is. The "update available" indicator stays so the user can retry later.
2. **Overwrite local (LRW).** Replace exercises, teams and sessions with the remote version. `ProgramSource.catalog.latestEtag` is updated. Local edits are discarded.
3. **Publish my changes.** Upload the local plan as a new catalog version via `DrillClient.upload(ifMatchEtag: latestEtag)`. On success, `latestEtag` is updated to the new version. This option is only enabled when the user owns the slug. For non-owned slugs the option is hidden and the user is offered "Fork as new local plan" instead (creates a copy under a new `programUuid` with `ProgramSource.local()`, breaking the catalog link).

The diff (`ProgramDiff`) is computed as a structural comparison of exercises, teams and sessions and is **always shown** before any of the three actions executes, regardless of which one the user picks. It lists added, removed and modified entries by name.

When the local plan has *not* diverged (content hash matches `latestEtag`), the refresh is silent: the remote version is applied without prompting, since there is nothing to lose.

### UI

New route `/library` with two tabs:

* **My plans** lists `listPrograms()`. The active plan is marked with a badge. Tap activates the plan. Swipe-to-delete with confirmation. Each row shows name, source (local/imported/catalog), exercise count and update time. When a catalog plan has a newer version available (via `refreshCatalogItem`), an update icon is shown.
* **Catalog** calls `DrillClient.marketFeed()` and shows the result as a flat, unfiltered list. The backend has no organization/team concept yet, so personal/team filtering is intentionally out of scope for the MVP and is left for a follow-up ADR when the backend grows that concept. Each row shows name, tags and an install button. Plans already installed from the catalog are marked "Installed" and cannot be reinstalled (but can be updated). Pull-to-refresh.

`MainScreen`'s drawer gets a new `ListTile` "Library" that opens the route. The `ProgramView` AppBar shows the active plan's name under the tab title, so the user always knows which plan is active.

The `openProgram` flow (today's "open from file") changes semantics: instead of deleting existing exercises, it calls `installFromFile` and sets the new plan as active. Existing plans are preserved. This must be explained in a short migration message in the changelog or UI on first launch after upgrade.

### Backend

No backend changes are required for the MVP. `/api/market/feed`, `/d/:slug` and `/api/drills/head/:slug` cover browsing, downloading and update checks. The existing `POST /api/drills/upload` with `If-Match: <etag>` covers the "publish my changes" path on owned slugs. A future extension of the feed with `description`, `exerciseCount` and per-organization filtering would improve UX, but is not a requirement now.

### Consequences

* Good: The user can select a plan from the shared catalog without losing existing plans. Directly addresses the original need.
* Good: The existing `.drill` format and backend are reused without changes. ADR-0007 is unaffected.
* Good: `ExerciseService` and notifications remain unchanged. The risk of runtime regression is low.
* Good: Migration from legacy keys is one-shot and idempotent. Users do not lose data.
* Good: The model opens for a later extension to multiple parallel plans without tearing down the data layer. Only `ExerciseService` and the UI need to change.
* Good: LRW with explicit conflict resolution gives a predictable refresh policy without silently destroying local edits. The diff is always shown, so the user can audit the impact before any choice.
* Bad: The key format in `SharedPreferences` changes. The migration code must be tested on multiple platforms (Android, iOS, web/PWA) before release.
* Bad: The `openProgram` semantics changes from "replace everything" to "install and activate". Users who learned the old pattern must be re-oriented.
* Bad: The catalog tab requires network. We must handle the offline case and errors gracefully.
* Bad: `Program` becomes a richer model with `ProgramSource`. That requires a `make build` round and a migration of tests that construct `Program` manually.
* Bad: The catalog tab is flat and unfiltered for MVP. Discovery degrades as the feed grows. Filtering and search are deferred to a follow-up ADR.
* Bad: Computing a `ProgramDiff` adds code we did not previously need. The diff format is internal and must be kept simple to avoid scope creep.

## Pros and cons of the options

### Active plan + local library + shared catalog (chosen)
* Good: Minimal runtime change, persistent multi-plan, reuses the backend.
* Good: The model can extend to parallel plans later.
* Bad: Requires migration of existing `SharedPreferences` keys.

### Multiple plans in parallel in the runtime
* Good: Maximum flexibility, the user can coordinate several drills simultaneously.
* Bad: Requires significant refactoring of `ExerciseService`, `NotificationService` and UI. Larger risk, more testing.
* Bad: Breaks today's assumption of a single globally active exercise.

### Local multi-plan library only, no catalog
* Good: Simplest to implement. No catalog UI or network.
* Bad: Does not address the core need of a shared catalog.

### Catalog only, no local persistence of multiple plans
* Good: Very little client state. The catalog is the source of truth.
* Bad: Requires network to switch plans. Loses offline use and local-without-publishing.
* Bad: A regression for users who build plans locally.

## Migration plan

1. Bump the key version to `app:librarySchema:v1` and run the one-shot migration on first start after upgrade.
2. Add a short changelog message in `AboutPage` or a SnackBar on first launch after upgrade: "Library and catalog are new. Your existing plan has been moved to 'Default plan' and is still active."
3. Keep legacy read paths for one release cycle as a fallback if the migration fails, before removing them.

## Links

* Related ADRs: [ADR-0004](./0004-no-third-party-state-management.md), [ADR-0007](./0007-drill-file-format.md)
* Related code: `lib/services/program_service.dart`, `lib/data/program_repository.dart`, `lib/data/drill_client.dart`, `lib/data/drill_file.dart`, `lib/models/program.dart`, `lib/views/program_view.dart`, `lib/views/main_screen.dart`
* External references: backend endpoints `/api/market/feed` and `/d/:slug` (see [`docs/architecture.md`](../architecture.md))
