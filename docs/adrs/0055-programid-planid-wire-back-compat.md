---
status: accepted
date: 2026-07-25
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0055: Dual-accept `programId`/`planId` at the Netlify API boundary, with Sentry-tracked deprecation

## Context and problem statement

The `Program` -> `Plan` Dart model rename (`docs/prompts/refactor-program-to-plan-and-person-description.md`) was scoped as a clean, no-alias rename of Dart identifiers, the in-app URL namespace, and the interim brief redirect — it deliberately left the Netlify functions' API contract untouched, since that is a separately deployed system (`api.ringdrill.app`) already live for real clients, not something a Dart-only refactor can safely clean-break.

That left an asymmetry: the app now says "Plan" everywhere, but `drill_client.dart` still sends and reads the wire parameter `programId` (the upload query param, the `x-program-id` response header, and the `programId` JSON field in upload/feed/admin responses), because that is what `netlify/functions/*.js` accepts and emits. The maintainer wants to close this gap on the wire too, without a hard cutover that could break any client build still in the wild once the Flutter client's own name changes.

## Decision drivers

* The Netlify functions are a live, deployed API — unlike the Dart rename, a clean breaking change here is not safe by default.
* We do want the wire contract to eventually read `planId`, matching the rest of the rename.
* We need a way to know when it is actually safe to remove `programId` support, rather than guessing or leaving it forever "just in case."

## Considered options

* **Option A — Dual-accept/dual-emit at the API boundary, with usage telemetry.** The server accepts either `planId` or `programId` on the one endpoint that reads it (`drills-upload.js`'s query string), preferring `planId`; every client-facing response (upload, admin, catalog feed) carries both fields/headers. The Flutter client switches to sending/reading `planId`. Every time a request still uses `programId` instead of `planId`, the server reports it to Sentry, so real-world `programId` usage is observable and its removal date can be a data-driven call instead of a guess.
* **Option B — Hard cutover.** Rename the wire contract outright, same as the Dart-only parts of this refactor. Rejected: unlike the .drill archive and the in-app routes, this is a live deployed API; any already-installed app build (or any other consumer) sending the old param would start failing silently (`programId` fallback code paths default `programId` to a freshly generated random uuid when absent, per `drills-upload.js`'s existing `?? (globalThis.crypto?.randomUUID?.() ...)` fallback — meaning a break here doesn't 400, it silently mints a new plan identity on next publish, which is a much worse failure mode than an error).
* **Option C — Do nothing; keep `programId` forever.** Simplest, but leaves the API permanently out of step with the rest of the rename, with no path to ever finishing the migration.

## Decision outcome

Chosen option: **Option A**, because it lets the migration actually complete (Option C never does) without risking silent data corruption for any lagging client (Option B's failure mode).

### Wire contract

* **Incoming** (`drills-upload.js`, the only endpoint that reads this param): accepts `?planId=`, falling back to `?programId=` when `planId` is absent. `?planId=` takes priority if a caller somehow sent both.
* **Outgoing** (`drills-upload.js`'s 200 JSON body and 304 headers, `drills-admin.js`'s `listall`/`versions` responses, and the catalog feed via `_shared.js`'s `metaToFeedItem`): every response carries **both** `planId` and `programId` (and both `x-plan-id`/`x-program-id` headers on the upload 304 path) with the same value, so old and new clients both work unmodified.
* **Internal storage is untouched.** The stored `meta.json`/slug-index blob field stays named `programId` — this is our own persistence, not a client contract, and migrating already-published blobs is a separate, larger concern this ADR does not take on.

### Deprecation telemetry

`_shared.js` exports `reportLegacyProgramIdUsage(context)`, called from `drills-upload.js` whenever a request arrives with `programId` but no `planId`. It reports an `@sentry/node` message (level `info`, tagged `legacy_program_id`) and is a no-op when `SENTRY_DSN` is unset — telemetry must never make the API depend on Sentry being reachable, and local/dev/test environments run with no DSN configured. Once the Sentry data shows no real traffic still sending bare `programId`, `programId` support (both directions) can be removed in a follow-up change, and this ADR's status updated to `superseded`.

### Consequences

* Good: the app's Dart-side rename and the API's wire contract converge, without a breaking change to a live system.
* Good: the removal decision is data-driven (Sentry volume) rather than a guess about whether anything still depends on `programId`.
* Good: every response carrying both fields means a partial/rolled-back client deploy on either side (server or app) still works during the transition.
* Bad: permanent-feeling duplication (two fields carrying one value) until the telemetry says it's safe to remove — mitigated by the telemetry actually existing, unlike Option C.
* Bad: a new runtime dependency (`@sentry/node`) in `netlify/functions`, gated on a new `SENTRY_DSN` environment variable that must be provisioned in the Netlify dashboard (out of band, matching how `ADMIN_TOKEN` is already configured) for the telemetry to actually fire.

## Pros and cons of the options

### Option A
* See *Consequences* above.

### Option B
* Good: no lingering duplicate fields, no telemetry to build.
* Bad: silently mints a new plan identity for any client still sending `programId` once support is dropped (see *Considered options* above) — a data-integrity risk, not just an error a caller can retry past.

### Option C
* Good: zero implementation cost.
* Bad: the Program -> Plan rename never actually reaches the one system it didn't touch; permanent inconsistency with no plan to resolve it.

## Links

* Related: `docs/prompts/refactor-program-to-plan-and-person-description.md` (the Dart-only rename this ADR follows up on), `AGENTS.md` rule 8 (publish query string params).
* Related code: `netlify/functions/_shared.js` (`reportLegacyProgramIdUsage`, `metaToFeedItem`), `netlify/functions/drills-upload.js`, `netlify/functions/drills-admin.js`, `netlify/functions/openapi.js`, `lib/data/drill_client.dart`.
