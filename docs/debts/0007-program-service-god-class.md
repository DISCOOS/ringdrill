---
status: open
severity: medium
discovered: 2026-05-31
resolved: null
related_adrs: ["ADR-0024", "ADR-0025"]
---

# DEBT-0007: `ProgramService` is a god class

## What

`ProgramService` (889 lines, around 54 methods) mixes at least four responsibilities in one stateful singleton: a CRUD facade over `ProgramRepository`, catalog/wiki synchronization with conflict resolution, pure stateless domain computation, and event broadcasting.

## Where

* `lib/services/program_service.dart`:
  * CRUD facade: `loadExercises`, `saveExercise`, `deleteExercise`, `saveRolePlay`, `saveActor`, `loadTeams`, and friends.
  * Catalog sync: `refreshCatalogItem` (line 418), `publishProgram` (566), `publishProgramAs` (649), `_overwriteCatalogProgram` (759) — most of the ADR-0024/0025 logic.
  * Stateless domain computation: `generateSchedule` (779), `ensureStations` (847), `_ensureTeams` (864), `_addMinutesToTime` (882).
  * Event broadcasting via `ProgramEvent`.
* 28 files import this service directly.

## Why it is debt

The breadth makes the service hard to test in isolation and hard to reason about, and the wide import surface means almost any UI change can reach into catalog-sync internals. The stateless schedule/provisioning helpers do not belong in a stateful singleton and currently cannot be reused by the CLI without dragging in the catalog code.

## Suggested fix

Incremental and low-risk, keeping thin delegating methods during a transition:

1. Move the static schedule/provisioning functions (`generateSchedule`, `ensureStations`, `ensureTeams`, `_addMinutesToTime`) out to a pure file (for example `ScheduleFactory` under `lib/models/` or `lib/utils/`). Almost a pure move, and it lets the CLI use them.
2. Extract catalog sync into a dedicated `CatalogSyncService` that takes the repository as a dependency, leaving `ProgramService` as a thinner persistence + events facade.

This changes the service split, so it should be accompanied by its own ADR.

## Links

* Related ADRs: [ADR-0024](../adrs/0024-account-and-identity-model.md), [ADR-0025](../adrs/0025-authorization-and-publish-policy.md)
* Related code: `lib/services/program_service.dart`, `lib/data/program_repository.dart`, `bin/ringdrill.dart`
