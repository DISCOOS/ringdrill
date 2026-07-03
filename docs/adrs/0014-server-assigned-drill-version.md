---
status: accepted
date: 2026-05-22
deciders: ["Kenneth"]
consulted: []
informed: []
---

# ADR-0014: Server-controlled drill upload contract

## Context and problem statement

`drills-upload` (the Netlify function backing the catalog) had two related
weaknesses in its concurrency contract:

**1. Version assignment was nominally client-driven but effectively broken.**
The function treated the `?version=` query parameter as the authoritative
version label for the uploaded blob and rejected with HTTP 409 when a blob
already existed at that version. The Dart client (`DrillClient._uploadOnce`)
built the query as `version: (file.version + 1).toString()`, but no code path
ever set `DrillFile.version` to anything other than the default `0` —
`DrillFile.fromProgram` and `DrillFile.fromFile` both ignore it. Every upload,
from both the CLI (`make catalog-seed`) and the Flutter publish flow,
announced itself as `version=1`. Result: any second upload to the same
`(ownerId, programId)` pair fails with `409 Version '1' already exists`.
Reproducible path: `make catalog-reset` → `make catalog-seed test-7x.drill`
→ install the catalog item in the web app → click *Publiser*. Seed claims
slug `test-7x` at v1; the web publish tries v1 again and 409s.

**2. Optimistic concurrency on the `latest` blob was illusory.** The Dart
client passed `If-Match: <etag>` HTTP headers on update uploads (the etag
coming from `ProgramSource.catalog.latestEtag`, captured at install or
refresh time) on the assumption that the server would 412 on a stale view.
The server ignored the header completely; it read its own `getBlobEtag(latest)`
immediately before writing, used that as `onlyIfMatch`, and silently dropped
the `modified: false` outcome. Two clients racing on the same slug could
both successfully overwrite each other without either of them seeing a
conflict, even though both passed `If-Match`. The `upload()` retry path in
the client (`maxRetries: 1`) was effectively dead code because the server
almost never returned 412.

Tracking the version on the client requires either a schema change on
`ProgramSource.catalog` (add `latestVersion`), or a HEAD round-trip to ask
the server, or a stateful counter elsewhere. All three move the responsibility
for an essentially server-side fact onto a client that has no other reason
to care about version numbers. Likewise, the OCC fix can either be done in
the server (extract `If-Match`, validate, return 412) or by adding a parallel
"etag fingerprint" mechanism on the client.

## Decision drivers

* The publish flow must work end-to-end without manual intervention after a
  catalog seed.
* The catalog uses a wiki ownership model (ADR-0008 / project memory):
  anyone with the drill file can publish updates. Version numbers are
  bookkeeping, not coordination — clients should not have to negotiate them.
* "Wiki" does not mean "last writer silently wins" — concurrent editors
  should be able to detect when their local view has fallen behind, so the
  upload retry logic in `DrillClient.upload()` is built on real 412s instead
  of a dead path.
* Keep the change reversible. Existing callers that explicitly set a version
  (none in tree today, but plausible for future tooling that imports semver
  ranges) should still work.
* Avoid a freezed schema change for a problem that is purely a server-side
  identifier policy.

## Considered options

### For version assignment

* **Option A — Server auto-assigns version when the client omits `?version`.**
  Backend reads `meta.versions`, picks `max(parseInt(v.v)) + 1`. Explicit
  `?version=...` from the client is still honoured (legacy path).
* **Option B — Track `latestVersion` in `ProgramSource.catalog`.** Update the
  freezed model, run `make build`, persist the version on every successful
  upload, and pass it through `DrillFile.fromProgram(..., version: n)` so
  `_uploadOnce` can send `n + 1`.
* **Option C — Client retries on `409 Version '...' already exists` with an
  incremented version.** No backend change; the client probes until it
  succeeds.

### For OCC tightening

* **Option D — Server validates client `If-Match` against the most recent
  content etag in `meta.versions`, and checks `modified` on the storage
  write for `latest`.** Two layers of OCC: client-driven (stale view) and
  server-internal (write race).
* **Option E — Drop the client's `If-Match` plumbing entirely.** Embrace
  last-writer-wins. Simpler, but loses staleness detection and makes the
  existing client retry logic vestigial.
* **Option F — Synthesise a single etag from storage that matches the
  content etag.** Either rewrite HEAD/download to return storage etags, or
  rewrite the upload OCC to use sha256 throughout. Either rewrite touches
  several handlers and breaks the cache-control story.

## Decision outcome

Chosen options: **Option A (server auto-assigns version)** and **Option D
(server validates client `If-Match` against content etag in meta)**, applied
together as one upload-handler refactor.

A was chosen because version numbers are a server-side ledger and have no
other meaning to the client. Pushing that into the client either adds a
model field that exists solely to mirror server state (B) or burns extra
HTTP calls fighting the 409 wall (C). The auto-assign branch is a small
change confined to the upload handler, and the legacy-explicit branch
keeps the door open for future tooling that wants to control versioning.

D was chosen because the client already maintains the right etag (content
sha256, captured on download/install/refresh) — the server just needs to
respect it. The two etag worlds (content sha256 in responses and meta, vs
Netlify Blobs storage etag in `getBlobEtag`/`onlyIfMatch`) are kept
separate: client OCC compares against the content etag, server OCC
compares against the storage etag. E was rejected because it would silently
strip a feature the client already implements; F was rejected as more
invasive than the actual problem warrants.

The handler additionally retries internally when the auto-assigned version
collides with a concurrent writer (bounded at five attempts) and surfaces a
real 412 when the `latest` storage write reports `modified: false`. Both are
mechanical consequences of taking the OCC contract seriously.

### Consequences

* Good: `make catalog-seed` followed by a publish from the app works on
  the first try, no version coordination required.
* Good: The Flutter publish flow needs no new persistent state; the catalog
  source still stores only `slug`, `latestEtag`, `installedAt`.
* Good: `DrillClient.upload()`'s `maxRetries: 1` becomes a real safety net:
  it sees genuine 412s from short race windows and from stale-view writes,
  and can refresh + retry once before propagating to the UI.
* Good: CLI users see human-meaningful version numbers (`1`, `2`, `3`)
  in the upload response instead of always seeing `1`.
* Bad: The response now reveals a version that the client did not choose.
  Anyone parsing the response and expecting their requested version back
  must update — currently only the CLI prints it.
* Bad: Stale-view publishers see `412 Precondition failed (latest changed
  since you last saw it)` after the retry budget is spent. The UI translates
  this to `libraryPublishConflict`, "Noen oppdaterte denne planen først.
  Prøv igjen." The user has to refresh and re-publish manually. We do not
  attempt any auto-merge.
* Bad: The auto-bump retry loop runs up to five times per upload in the
  pathological case (five concurrent writers on the same slug). In practice
  contention is far lower than that; the bound is there as a guard, not as
  a target.
* Bad: A versioned blob can be written successfully even if the subsequent
  `latest` write fails (server-internal race), leaving an orphan immutable
  version. Storage waste only; the next auto-bump will skip past it via the
  `onlyIfNew` retry. Cleanup is left for a future GC pass if it ever proves
  expensive.

## Pros and cons of the options

### Option A — Server auto-assigns version

* Good: Small backend change, single-line client change. No freezed work.
* Good: Honours explicit `?version=` for future explicit-version callers.
* Good: Version becomes server-of-record; no client/server skew possible.
* Bad: Version numbers in upload responses become advisory rather than
  echoes of caller input. Existing assumption that "what I sent is what
  I get back" no longer holds for callers that omit the param.

### Option B — Client tracks `latestVersion`

* Good: Server stays a dumb store; client owns its identity.
* Bad: Requires a freezed schema bump, a migration path for existing
  catalog programs (default `latestVersion` to `null` and treat as 0),
  and a `version:` parameter on `DrillFile.fromProgram`.
* Bad: The client now has two pieces of catalog state (`latestEtag` and
  `latestVersion`) that the user cannot influence and that must stay in
  sync. Drift is easy to introduce.
* Bad: When a user reinstalls and reimports a drill, the `latestVersion`
  is lost; first publish 409s again unless we encode the version into
  the `.drill` archive too.

### Option C — Client retries on `409 Version '...' already exists`

* Good: No backend change.
* Bad: Wastes HTTP calls. With `N` existing versions, the worst-case is
  `N+1` round-trips before success.
* Bad: 409 from the slug-claim path and 409 from the version-collision
  path become indistinguishable to the retry logic — needs string-matching
  on error bodies.
* Bad: Cements `version` as a client-supplied identifier rather than
  treating it as derived state, postponing the fix.

### Option D — Server validates client `If-Match` against content etag

* Good: Honest OCC. The 412 retry path in `DrillClient.upload()` becomes
  load-bearing instead of vestigial.
* Good: No client change; existing `If-Match` plumbing is already in place.
* Good: Two-layer guard (client view + storage race) catches both stale
  views and short server-internal race windows.
* Bad: Storage-OCC and view-OCC use different etags. The handler has to
  keep them distinct in its head and in code, which is a small ongoing
  cognitive cost for future editors.

### Option E — Drop the client's `If-Match` plumbing

* Good: Simplest possible model: last writer wins, no retries needed.
* Bad: Silently loses changes when two editors race. The wiki model permits
  collective editing but does not require silent overwrites.
* Bad: `DrillClient.upload()`'s retry logic becomes dead code — either
  remove it (signal a behaviour change) or leave it dead (worse).

### Option F — Unify the two etag worlds

* Good: Long-term elegance: one etag everywhere.
* Bad: Touches `drills-head`, `deep-link`, `drills-admin`, and possibly
  feed handlers. Either every consumer learns Netlify Blobs storage etags
  (unstable across infra changes), or every storage write computes and
  stores a content etag for OCC purposes too (write amplification).
* Bad: Risk of cache-control regressions: the current `Cache-Control:
  immutable` story relies on stable content etags for versioned URLs.

## Links

* Related ADRs:
  [ADR-0007](./0007-drill-file-format.md),
  [ADR-0008](./0008-persistent-program-library-and-catalog.md),
  [ADR-0010](./0010-live-catalog-updates.md),
  [ADR-0013](./0013-local-catalog-testing.md)
* Related code:
  `netlify/functions/drills-upload.js` (auto-bump version + If-Match
  validation + retry loop),
  `lib/data/drill_client.dart` (`_uploadOnce` only sends `version` when
  `DrillFile.version > 0`; `upload()` retry handles real 412s),
  `lib/services/program_service.dart` (`publishProgram`, `publishProgramAs`)

## Addendum (2026-07-03): `latestVersion` added to `ProgramSource.catalog` after all — for display, not for OCC

The "Consequences" section above states "the catalog source still stores
only `slug`, `latestEtag`, `installedAt`," and Option B (client tracks
`latestVersion`) was rejected specifically to avoid that field. Both are now
stale: `ProgramSource.catalog` gained a nullable `latestVersion` field, so
this addendum exists to keep this ADR from misleading a future reader into
thinking that decision still holds, and to be explicit that it does not
reopen or reverse the OCC decision above.

**Why this isn't Option B.** Option B was about using a client-tracked
version to drive the *upload* flow — sending `version: n + 1` to sidestep
version-collision 409s. That responsibility still belongs entirely to the
server (Option A, unchanged): the client never chooses or predicts a version
number for publishing, and the OCC gate in `drills-upload.js` is still pure
ETag `If-Match` comparison, exactly as this ADR decided. `latestVersion` is
not consulted anywhere in the publish/upload path.

**What it's actually for.** Two unrelated, narrow purposes, neither of which
is coordination:
1. **Addressing a specific historical version** via the existing
   `slug@version` URL convention (already supported by `drills-head`,
   `deep-link`, and the CLI) — `version` was always the human-readable
   pointer for this, `latestVersion` just lets the client remember which one
   it last saw without another round-trip.
2. **Human-readable display.** The catalog conflict dialog
   (`catalog_conflict_dialog.dart`) shows a single comparison line —
   "Local vN → Catalog vN" (the `_VersionComparison` widget) — so a user
   resolving a conflict can see which published revision their install last
   tracked versus what the catalog currently has, read in the same
   old-to-new direction as the diff below it. This is presentational only;
   the conflict itself (and the choice of overwrite/fork/publish) is entirely
   driven by `ProgramDiff` and the `hasLocalChanges` content-hash check, not
   by whether the two version numbers differ. Both sides are always shown —
   an unknown version (e.g. a plan installed before this field existed)
   renders as a muted italic "None"/"Ingen" rather than being hidden, so the
   absence of data is visible instead of silently blank.

**How it's kept fresh.** `latestVersion` is populated the same way
`latestEtag` already was: from the `x-version` response header, added this
session to `drills-head.js` and `deep-link.js` (mirroring the header
`drills-upload.js`'s 304 path already sent), and from the `version` field
already present in the upload response body. It is best-effort and
advisory — if it's ever stale or absent, at worst a chip shows an outdated
number or "None." Nothing downstream re-derives correctness from it, so
drift here cannot cause the silent-overwrite failure mode Option D was
designed to prevent.

**Consequences.** The "no new persistent state" consequence above no longer
holds — there is one more optional field on `ProgramSource.catalog`, nullable
and additive (old serialized programs decode it as `null`). The concurrency
contract itself — ETag-based `If-Match`, server-assigned version numbers —
is unchanged.

Related code: `lib/models/program.dart` (`ProgramSource.catalog.latestVersion`),
`lib/data/drill_client.dart` (`DrillHeadResponse.version`,
`DrillDownloadResponse.version`), `lib/services/program_service.dart`
(`refreshCatalogItem`), `lib/views/catalog_conflict_dialog.dart`.
