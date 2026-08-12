# Catalog re-key migration plan

Companion to [ADR-0074](../adrs/0074-catalog-entry-as-distinct-object.md). The
ADR decides that a catalog entry is a distinct object identified by
`(namespace, slug)` and keyed by an opaque entry id; this document is the
runbook for getting the live catalog there without breaking a link.

Status: **complete, 2026-08-12.** All six steps ran. The catalog is in the new layout, serving from it, and the old
blobs and flat index keys are gone. There is no rollback from here, by design
— see Rollback below.

Cleanup removed 15 blobs (12 + 3, matching the copy exactly) and the two flat
index keys, with nothing skipped. It was re-verified immediately afterwards by
downloading the same versions again and comparing them byte-for-byte against
copies taken before the cleanup: all identical, which is what proves the bytes
now come from `catalog/<entryId>/` and not from something the dual-read had
been quietly covering for. Feed, install pages, both origins and
`npm run smoke:mcp` all green afterwards.

The copy moved two entries — `lier-07juni` (12 blobs, 10 versions) and
`lsor-eidene-2026` (3 blobs, 1 version) — with no errors and nothing skipped.
Verification found: latest and versioned downloads good on both the apex
(proxied) and `api.` origins, archives valid with CRCs intact across the
version range rather than only at the newest, `latest.drill` byte-identical to
`@10`, feed and install pages fine, `npm run smoke:mcp` 12/12, and an
unmodified plan installed *before* the migration refreshed from the catalog in
the web app with no conflict — which is the one check that exercises
`drills-head`'s ETag path against a migrated record.

## What changes

**Storage keys — invisible to everyone.**

| | Before | After |
|---|---|---|
| Blobs | `drills/<ownerId>/<planId>/{latest,N}.drill`, `.../meta.json` | `catalog/<entryId>/{latest,N}.drill`, `.../meta.json` |
| Index | `slug-index/<slug>` → `{ownerId, programId}` | `slug-index/<namespace>/<slug>` → `{entryId, planId, ownerAccountId, …}` |

**URLs — purely additive.**

| | Before | After |
|---|---|---|
| Anon plan | `/d/lsor-eidene-2026` | unchanged, permanently |
| Anon, versioned | `/d/lsor-eidene-2026@5` | unchanged |
| Install link | `/i/lsor-eidene-2026` | unchanged |
| Account plan | — | `/d/redcross-bergen/lsor-eidene-2026` |

Nothing is rewritten and no redirect is needed. `anon` is a real namespace, not
a transitional shim, so the bare form keeps working for as long as anonymous
publishing does — which is forever
([ADR-0025](../adrs/0025-authorization-and-publish-policy.md), amended
2026-08-05).

**Namespace is stored as the account id**, not the handle. Handles are
(semi-)changeable, ids are not — so a rename rewrites *nothing*, and
`resolveNamespace` maps a URL handle onto the id at read time. A tombstoned
handle still resolves and reports the current one, which is what keeps an
already-shared link working across a rename.

## Blocking list — must be done before the migration runs

Each of these reads the catalog and still assumes the old layout. The dual-read
in `lib/catalog.js` makes them independently convertible, but the migration must
not run until **all** are done: a migrated plan would 404 from the ones left
behind, and new publishes would land back in the old layout.

- [x] `deep-link.js` — `/d/` download.
- [x] `drills-upload.js` — publishes into the new layout and claims namespaced
      slugs. Done first, because while it wrote the old layout every publish
      created another entry to migrate.
- [x] `market-feed.js` — enumerates the index and carries the namespace into
      `latestUrl`.
- [x] `drills-head.js` — HEAD metadata, feeding ADR-0010's refresh polling.
- [x] `drills-preview.js` — `/i/` install links (ADR-0015).
- [x] `mcp-backend.js` — `search_catalog` and `get_plan`.
- [x] `drills-admin.js` — `listall`, `versions`, `deleteversion`, `deleteall`.
      Every action resolves through one helper so none can drift onto a single
      layout while the others move, and `deleteall` takes its prefix from the
      record rather than deriving an owner-scoped one — otherwise it would
      delete nothing, report success, and leave the plan still being served.

**All clear as of 2026-08-08.** The legacy `keysFor` / `getSlugRecord` imports
are gone from every function, so no reader can reach the old layout except
through `keysForEntry`'s deliberate fallback.

**Both layouts are covered by tests**, so the dual-read is not taken on trust.
`netlify/tests/mcp-catalog-layout.test.mjs` and
`netlify/tests/drills-admin-layout.test.mjs` each run every case twice — once
against a pre-migration record, once against a migrated one — because the
failure mode this migration invites is a reader that works perfectly on one
side and silently answers wrong on the other. These were the two surfaces with
no handler test at all; `drills-admin` had none because it was the one function
without a `createHandler({ deps })` seam, which it now has.

**Checked and not applicable:** `make mcp-bundle`. The Dart→JS compiler bundle
covers `lib/data/source/`, `lib/models/`, `lib/services/brief/` and `lib/l10n/`;
`mcp-backend.js` is plain JS and is not in `mcp-compiler-bundle.sources.json`,
so no rebuild is needed for this work. Verify with
`node --test netlify/tests/mcp-packaging.test.mjs` anyway.

## Order of operations

**Copy first, repoint second, delete last.** Reversing any two opens a window
where a live `/d/<slug>` 404s.

1. **Deploy the converted read paths** (blocking list above). The dual-read
   means every plan works whether or not it has been moved, so this deploy
   changes nothing observable.
2. **Dry run** the copy. Read the report; it lists every entry it would move
   and every one it cannot.
3. **Run the copy.** Idempotent and resumable — a half-run just needs running
   again, and an entry that already has an `entryId` is skipped rather than
   given a second one.
4. **Verify** (below). This is the step with no deadline; take it.
5. **Dry run** the cleanup, then run it.
6. **Deploy again with the dual-read fallback removed**, once nothing points at
   the old shape.

```bash
# 2 / 3 — copy
curl -s -X POST "https://ringdrill.app/api/drills-admin?action=migrate-catalog-keys" \
  -H "Authorization: Bearer $RINGDRILL_ADMIN_TOKEN" | jq
curl -s -X POST "https://ringdrill.app/api/drills-admin?action=migrate-catalog-keys&dryRun=false" \
  -H "Authorization: Bearer $RINGDRILL_ADMIN_TOKEN" | jq

# 5 — cleanup
curl -s -X POST "https://ringdrill.app/api/drills-admin?action=migrate-catalog-keys-cleanup" \
  -H "Authorization: Bearer $RINGDRILL_ADMIN_TOKEN" | jq
curl -s -X POST "https://ringdrill.app/api/drills-admin?action=migrate-catalog-keys-cleanup&dryRun=false" \
  -H "Authorization: Bearer $RINGDRILL_ADMIN_TOKEN" | jq
```

Both phases default to a dry run; `dryRun=false` is the only way to act.

## Verification after the copy

The catalog is two plans (it was trimmed to the real ones on 2026-08-12), so
this is done by hand and that is fine. `lier-07juni` is the one that matters
most here: it carries ten versioned blobs to `lsor-eidene-2026`'s one, so it is
the only plan that meaningfully exercises the versioned-URL case below.

* Every slug still downloads: `curl -IL https://ringdrill.app/d/<slug>` → 200,
  correct `x-version`, correct `Content-Length`.
* A **versioned** URL still downloads: `/d/<slug>@<n>`. Versioned blobs are the
  ones most likely to be missed by a partial copy.
* `/api/market-feed` lists both, and each `latestUrl` resolves.
* `/i/<slug>` still renders.
* The MCP endpoint still answers: `npm run smoke:mcp`. This drives the deployed
  endpoint over the network and is not part of `npm test`, so it is easy to
  skip and is exactly the surface most likely to break unnoticed.
* The app refreshes an installed plan without reporting a conflict (ADR-0010's
  HEAD poll → ADR-0008's diff).

## Rollback

* **Before step 3** — nothing has changed. Redeploy the previous functions.
* **After the copy, before cleanup** — the old blobs and flat index keys are
  still there, untouched. Rolling back is deploying the previous read paths;
  they will find the flat keys exactly as before. The namespaced records left
  behind are inert.
* **After cleanup** — no rollback. The old blobs are gone. This is why cleanup
  is a separate run and why step 4 has no deadline.

## Things to remember

Kept as a running list; add to it rather than trusting memory.

* **Strong reads.** Every read in the migration feeds a write elsewhere, which
  is the case `lib/shared.js` documents at length: an eventually consistent
  read of a recently written blob answers `null`. If the copy phase used the
  default store it would record `source_vanished` for a blob that is right
  there — and then cleanup would delete the original it failed to copy. Both
  phases use the strong store; do not "simplify" that away.
* **`drills-upload` before anything else.** While it still writes the old
  layout, every publish creates another entry to migrate.
* **`deleteall` in `drills-admin`** *used* to delete by the
  `drills/<ownerId>/<programId>/` prefix, which after migration is empty for a
  migrated plan — so it would have removed nothing, reported success, and left
  the plan still being served. Fixed: it takes the prefix from the record via
  `keysForEntry`, and removes whichever index key the record came from. Left
  here because it is the shape any *new* delete path will be tempted into.
* **CDN caching.** `/d/` responses are CDN-cached. Content is byte-identical
  across the move so a cached 200 stays correct — but a 404 served during a
  window where the index points at bytes that are not there yet could be
  cached. The copy-then-repoint order is what prevents that window existing.
* **`published` is a listing flag, not an access control.** It gates the feed
  only; `/d/<slug>` serves any uploaded slug. Unchanged by this work, but it is
  the assumption most likely to be misread while touching these paths.
* **The dual-read removal is a third deploy**, not part of the migration. Leave
  it in place until the cleanup has run and been verified.
* **Blob `list()` pagination.** Both phases loop on `cursor`. At two plans it
  will never page, which is exactly why a regression here would go unnoticed
  until it mattered.
* **Netlify Blobs has no move.** A copy is a read plus a write, so a partially
  copied entry is re-copied on the next run — harmless, because the bytes are
  identical.
* **Account deletion does not exist yet.** When it is built, it must not sweep
  by account prefix. After this migration there is no account in the blob path
  to sweep, which is the whole point of §4 — but the temptation returns if
  anyone reintroduces an owner-scoped key.

## Open questions

* Whether to convert `drills-admin`'s `listall` to enumerate `catalog/` or to
  keep enumerating the index. The index is authoritative post-migration and
  cheaper; the blob scan is what exists today.
**Settled:** `GET /api/accounts/:id/plans` (DESIGN-015 §5.7's fourth tab) scans
the index by namespace prefix rather than maintaining a per-account list. The
scan is fine at current scale, is the same shape as `membershipsOf`, and has no
second copy to keep in step. Revisit if an account ever holds enough plans for
the paging to bite — a maintained list is the answer then, not a bigger page.

## Step 6 — what the dual-read removal actually touched

Larger than "delete the `else` branch", which is worth recording because the
next migration will look just as small at the outset.

* **Two fallbacks, not one.** `findEntry` fell back to the bare slug key and
  `keysForEntry` fell back to the owner-scoped blob layout. Both are gone.
  `keysForEntry` now **throws** on a record with no `entryId`: that used to mean
  "pre-migration" and now means a corrupt index record, and returning a
  plausible key would turn it into a 404 indistinguishable from an ordinary
  missing plan.
* **`market-feed` carried mid-migration logic** — flat/namespaced key parsing, a
  sort putting namespaced records first, and a dedupe so one plan could not
  appear as two during the copy window. All removed; the index key is the
  entry's identity, so there is nothing to dedupe.
* **The migration machinery went with it**: `lib/migrate-catalog.js`, both
  `drills-admin` actions, and `migrate-catalog.test.mjs`. With the old layout
  deleted the actions could only ever report finding nothing, and a
  destructive-sounding action that does nothing invites someone to run it to see
  what happens. Also `keysFor`, `getSlugRecord` and `getSlugRecordStrong` from
  `lib/shared.js`, which had no callers left.
* **Eight test files, not two.** The fixtures in `drills-head`,
  `drills-preview`, `mcp-endpoint`, `drills-policy` and `market-feed` were all
  built as pre-migration records, because that was the state the migration
  started from. The two dual-world files (`mcp-catalog-layout`,
  `drills-admin-layout`) collapsed to one world. Several assertions in
  `catalog-keys` were vacuous once the fallback was gone — they passed while
  testing nothing — and were replaced by the opposite property.
* **One real bug surfaced.** `listall` reported `slug: <the index key>`, so it
  answered `anon/lsor` where a person expects `lsor`. The migration made that
  wrong in step 3 and nothing caught it, because `listall` was the one action
  with no test. It round-tripped by accident: `parseCatalogPath` takes the key
  apart again on the way back in. Fixed, with the regression test it lacked.
