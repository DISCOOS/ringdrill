---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0010: Live catalog updates via HEAD polling with CDN cache

## Context and problem statement

[ADR-0008](./0008-persistent-program-library-and-catalog.md) introduced `ProgramService.refreshCatalogItem`, which checks `/api/drills/head/:slug` with `If-None-Match` and runs the conflict-resolution flow when a newer remote version exists. The refresh is currently triggered only by the user (pull-to-refresh in the library view). A user with a catalog plan open has no way to know that a new version was published unless they actively refresh.

This ADR makes that detection automatic, so that "endring i en plan som publiseres til Catalog plukkes opp av de som har denne åpen" works without the user thinking about it.

[ADR-0009](./0009-realtime-transport-and-session-model.md) introduced the session-status live transport. That transport is shaped around live drill state (exercise, teams, participants, positions). Catalog versioning is a separate concern. A catalog plan can sit in the library indefinitely with no drill active, so there may be no session at all. Folding catalog version checks into the session transport would either require a session that exists "just because the plan is open" or a new top-level slot in the locked schema. Both are worse than reusing the existing HEAD endpoint.

## Decision drivers

* Reuse existing infrastructure. `/api/drills/head/:slug` already exists, already supports `If-None-Match`, already returns 304. The refresh flow in [`ProgramService.refreshCatalogItem`](../../lib/services/program_service.dart) already handles the post-detection path.
* Do not change the session-status schema locked by ADR-0009.
* Work regardless of whether a live drill session exists.
* Stay inside the Legacy Free function-invocation budget. The cost of catalog polling must be additive on top of ADR-0009 and still fit.
* Latency target is loose. A 30-second to 5-minute detection delay is acceptable for catalog updates. They are rare and not time-critical.

## Considered options

* **Periodic HEAD polling with CDN cache and purge on upload (chosen).** Client polls `/api/drills/head/:slug` at an adaptive cadence. Server adds `s-maxage` to the response so the CDN absorbs most polls. `drills-upload.js` calls Netlify cache purge after a successful upload so the next HEAD picks up the new ETag within seconds.
* **Extend session status with a `catalogVersion` slot.** Would require unlocking ADR-0009's schema and creating sessions for catalog plans that have no live drill. Heavier than the problem warrants.
* **Push notifications.** No subscriber registry, no push-service infrastructure, would need significant new backend. Out of scope.
* **Manual refresh only (status quo).** Leaves the original gap unaddressed.

## Decision outcome

Chosen option: **periodic HEAD polling with CDN cache and purge on upload**, because it reuses every piece of infrastructure already in place, adds no new function endpoints, leaves ADR-0009's session schema untouched, and meets the loose latency target inside the function-invocation budget.

### Endpoint changes

`drills-head.js` is updated to set a CDN-friendly `Cache-Control` on the "latest" path:

```
Cache-Control: public, max-age=10, s-maxage=30, stale-while-revalidate=60
```

Versioned-path responses keep their existing `public, max-age=31536000, immutable` since version-pinned URLs never change content.

`drills-upload.js` is updated to call Netlify's cache purge API for the affected slug after a successful write:

```
purgeCache({ tags: [`drill:${slug}`] })
```

The response from `drills-head.js` is tagged with `Netlify-Cache-Tag: drill:<slug>` so purging by tag invalidates exactly the right entries. This is the same purge mechanism ADR-0009 uses for session status.

### Client polling loop

A new `CatalogWatchService` singleton in `lib/services/catalog_watch_service.dart` runs the polling. It listens to `ProgramService` events and the visibility of the library view to decide cadence:

| State                                                        | Cadence       |
|--------------------------------------------------------------|---------------|
| Library view open and user is browsing                       | 30 seconds    |
| Active program is a catalog plan, library view not visible   | 5 minutes     |
| App backgrounded or no catalog plans relevant                | Paused        |

The service polls `DrillClient.head(slug, ifNoneMatch: storedEtag)` for each catalog plan whose status it is tracking. The "tracked set" is:

* The active program if it has `ProgramSource.catalog`.
* Any catalog plan currently rendered as a visible row in the library view.

On a `notModified` (304) response, nothing happens. On a 200 with a different ETag, the service calls `ProgramService.refreshCatalogItem(programUuid, client, onConflict: ...)` and the existing flow from ADR-0008 takes over: diff computation, conflict-resolution dialog (`CatalogConflictDialog`), and one of `updatedSilently`, `updatedAfterPrompt`, `cancelled`, `published`, `forked`, `failed`.

### Consent gate

The same `app:liveConsent:v1` flag from [ADR-0009](./0009-realtime-transport-and-session-model.md) gates this polling. When consent is off, `CatalogWatchService` stays idle and the user can still manually refresh via the existing pull-to-refresh.

### Notification UX

When a new ETag is detected for a catalog plan in the library, the row shows an "Oppdatering tilgjengelig" badge. The user can tap to trigger the refresh dialog, or it can be triggered automatically depending on a setting (default: tap-to-confirm). The conflict dialog from ADR-0008 stays the same.

For the active program, if its catalog plan gets a new version, a snackbar appears with "Oppdatering tilgjengelig" and a "Vis" action that opens the refresh dialog.

### Cost analysis

The HEAD endpoint sits behind the CDN with `s-maxage=30`. Each unique slug being polled costs roughly one function invocation per 30 seconds per edge POP, independent of how many devices are polling that slug.

For the øvingsplan profile (one active catalog plan, 14 devices, 24 hours of active drill time over a weekend, 2 edge POPs):

```
Polled slugs: 1 (the active program)
Function invocations: 86 700s / 30s × 2 POPs ≈ 5 800 per weekend
```

Plus a small additional cost when the library view is open at 30s cadence, but that only matters when users are actively browsing. Estimate: ~500 additional invocations per weekend.

**Total: ~6 300 invocations per weekend on top of ADR-0009's ~87 000.** Combined: ~93 000, well inside the 125 000 cap.

If a user is tracking five catalog plans in their library all weekend, the cost scales linearly to ~30 000 invocations for catalog HEAD polling. Still inside the cap with margin.

Bandwidth is negligible. A 304 response is around 200 bytes, so polling traffic is well under 50 MB per weekend even across many slugs.

### Where the code lives

* `lib/services/catalog_watch_service.dart` for the polling loop and trigger logic.
* `lib/views/library_view.dart` gets the visibility signal that drives the cadence switch.
* `netlify/functions/drills-head.js` gets the updated `Cache-Control` and `Netlify-Cache-Tag` headers.
* `netlify/functions/drills-upload.js` gets the cache purge call after a successful upload.

### Consequences

* Good: Reuses existing endpoint and refresh flow. No new functions, no schema changes to ADR-0009.
* Good: Works for catalog plans regardless of whether a live drill session exists.
* Good: CDN cache plus purge keeps function invocations small. Comfortable margin on Legacy Free.
* Good: The user's existing manual refresh keeps working. Automatic detection is additive.
* Bad: Detection latency is 30 seconds at best and up to 5 minutes when the library view is closed. Acceptable for catalogs.
* Bad: Two polling loops to manage on the client (this one and ADR-0009's session status). The lifecycle rules are simple but separate.
* Bad: Adds a dependency on Netlify cache purge for the upload path. If purge fails, detection falls back to the natural `s-maxage` expiry (30 seconds), which is still acceptable.
* Bad: Polling cost scales linearly with the number of unique catalog slugs the user is watching. A user with many catalog plans in the library will consume more of the budget, though still inside the cap at expected scale.

## Pros and cons of the options

### Periodic HEAD polling with CDN cache (chosen)
* Good: No new endpoints, no schema changes, reuses ADR-0008's refresh flow.
* Good: Works without a live drill session.
* Bad: Two client polling loops to maintain.

### Extend session status with catalog slot
* Good: Single unified transport.
* Bad: Requires unlocking ADR-0009's schema.
* Bad: Forces a session to exist for catalog-only viewing.

### Push notifications
* Good: Instant updates, no polling.
* Bad: No subscriber registry today, no mobile push service connected. Significant new infrastructure.

### Status quo (manual refresh only)
* Good: Zero work.
* Bad: Does not address the user-reported gap.

## Migration plan

1. Update `drills-head.js` with the new `Cache-Control` and add the `Netlify-Cache-Tag` header. Verify CDN caching behavior in production.
2. Update `drills-upload.js` to call `purgeCache({ tags: [...] })` on success. Verify that a fresh upload propagates to a HEAD response within ~3 seconds.
3. Implement `CatalogWatchService` with the cadence rules. Wire it to consent and library visibility.
4. Add the "Oppdatering tilgjengelig" badge in `library_view.dart` and the snackbar for the active program.
5. Manual QA on a real upload-then-watch cycle, then ship.

## Links

* Related ADRs: [ADR-0006](./0006-sentry-behind-consent-gate.md), [ADR-0008](./0008-persistent-program-library-and-catalog.md), [ADR-0009](./0009-realtime-transport-and-session-model.md)
* Related code: `lib/services/program_service.dart`, `lib/data/drill_client.dart`, `lib/views/library_view.dart`, `lib/views/catalog_conflict_dialog.dart`, `netlify/functions/drills-head.js`, `netlify/functions/drills-upload.js`
* External references: [Netlify cache control and purge](https://docs.netlify.com/build/caching/caching-overview/)
