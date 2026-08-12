---
status: proposed
date: 2026-08-12
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0077: Reverse indexes for per-user lookups in the blob store

## Context and problem statement

Memberships are stored under `<accountId>/<userId>` and sessions under `<sessionId>`. Both key layouts answer the question they were designed for cheaply — "who is in this account", "what is this session" — and the opposite question only by scanning.

Two hot paths ask the opposite question. `membershipsOf` assembles the `acts` and `roles` claims on every access-token mint, which is hourly per signed-in device ([ADR-0025](./0025-authorization-and-publish-policy.md), `ACCESS_TTL_S = 3600`). `sessionsOf` builds the Devices list ([DESIGN-015](../design/015-accounts-and-iam.md) §4.3). Each walked its whole store and issued one `get` per blob to find the handful belonging to one user.

The cost is O(all tenants) per request, and it is paid on the API's hottest path. At the volumes [ADR-0024](./0024-account-and-identity-model.md) sized for, that was free and documented as such. It stops being free well before the Netlify Free plan's 125 000 invocations per month becomes the binding meter ([ADR-0009](./0009-realtime-transport-and-session-model.md)): assuming ~5 ms per blob `get`, a 10-second function budget is exhausted somewhere around 2 000 membership rows — roughly 250 organisations of eight people.

The failure mode is what forces the decision rather than the cost. Because the scan is global, the threshold is not reached by one large tenant on their own request; it is reached by the *system*, and when it is, token refresh fails for everybody at once. There is no per-tenant degradation to notice first, so "act when it gets slow" is not an available strategy. Traffic is expected to grow from autumn 2026, and the change is far cheaper to make now, before there is production data to migrate, than after.

## Decision drivers

* The hot paths must not scale with total tenants.
* A permissions system may not fail open. A role read must never be able to grant something the canonical record does not.
* There is no transaction across two blob writes, so any design must stay correct when the second write is lost.
* Deploying must not require an ordering dance. A read path that returns "no accounts" until a migration finishes is indistinguishable, from the user's side, from being locked out.
* Erasure must stay complete. A deletion that misses a record is a data-retention bug, not a performance one.

## Considered options

* Option A: Two reverse-index stores, `member-index` and `session-index`, keyed `<userId>/<...>`, holding no data.
* Option B: The same indexes, but denormalising `role` and `acceptedAt` into the index blob.
* Option C: One blob per user holding the whole membership map (`by-user/<userId>` → `{accounts, roles}`).
* Option D: Re-key the canonical stores to `<userId>/<accountId>` and `<userId>/<sessionId>`.
* Option E: Encode the owning user inside the session id, making the key derivable from the id alone.

## Decision outcome

Chosen option: **Option A**, because it removes the scan without creating any state in which drift between two non-transactional writes can grant a permission.

The index blob's body is a marker; only its *key* is read. A `list` returns keys and not values, so resolving N memberships costs one prefix listing plus N `get`s either way — denormalising the role would buy nothing and would introduce a second copy of the one field that must never be wrong.

Three rules follow from that, and each is load-bearing:

1. **Writes go canonical-first, index-second.** A lost index write hides a membership until it is re-indexed. The reverse order would surface one that no longer exists. Hiding fails closed; surfacing fails open.
2. **Reads treat a missing index as "not indexed yet" and fall back to the scan, indexing what they find.** This is what removes the deploy-ordering requirement: the system is correct before the backfill runs, during it, and if it is never run at all. A stale entry pointing at a record that is gone is deleted by the read that noticed — but never the other way round, because a missing index entry must not be able to delete a live membership.
3. **Deletion does not use the index at all.** `deleteUserRecords` sweeps the canonical stores and treats the index purely as derived data to be dropped alongside. Reads may assume the index is incomplete and pay a scan; a deletion that made the same assumption would leave a live refresh token belonging to a user who asked to be erased. Deletion is the rare path, which is exactly why it can afford to be the thorough one.

`backfillIndexes` (`netlify/functions/lib/backfill-indexes.js`, exposed as `drills-admin?action=backfill-indexes`) builds both indexes. It is an optimisation, not a migration: it decides *when* the remaining scans stop rather than whether the system is correct. It is additive, idempotent, and deletes nothing, so unlike the [ADR-0074](./0074-catalog-entry-as-distinct-object.md) catalog re-key it needs no separate cleanup phase and no ordering against a deploy.

### Consequences

* Good: both hot paths become one prefix listing plus one `get` per record the user actually owns — typically one to five — instead of one `get` per record in the system.
* Good: no deploy ordering. The change can ship before, after, or without the backfill.
* Good: role and acceptance stay single-sourced, so index drift cannot escalate a privilege. The regression test for this is the one that would fail if somebody later "optimised" the role into the index blob.
* Bad: two more blob stores and two more writes on the membership and session write paths. Both paths are already low-frequency relative to the reads they serve.
* Bad: a user who genuinely holds no accepted membership scans on every call, because an empty index is indistinguishable from an unindexed one. This is the state of somebody whose only membership is an unaccepted invitation — rare, and it costs the old behaviour rather than a new one.
* Bad: account deletion still scans `identities`, `email-index`, `sessions` and the pending member rows. That is deliberate per rule 3 above, and is bounded by being one call per deletion.

## Pros and cons of the options

### Option A: index stores holding no data

* Good: drift cannot grant anything, because there is nothing in the index to grant from.
* Good: same read cost as the denormalised form.
* Bad: needs the canonical row fetched per membership; no single-get answer.

### Option B: denormalise `role` into the index

* Good: would allow answering from the listing alone if `list` ever returned values.
* Bad: it does not, so the cost is identical while a demoted owner can keep owner rights in their token whenever the second of two writes is lost. Rejected on that alone.

### Option C: one blob per user with the whole map

* Good: a single `get` answers the question outright.
* Bad: every membership change anywhere must rewrite a per-user document with no transaction, so concurrent changes to two accounts race and one is silently lost. Turns a per-membership drift risk into a per-user one.

### Option D: re-key the canonical stores by user

* Good: no second store, no drift by construction.
* Bad: `rotateSession` is reached with a session id and a refresh token and no authenticated user — that is the point of refresh — so the key could not be constructed. Also inverts `membersOf`, which the last-owner invariant (DESIGN-015 §6.3) needs.

### Option E: encode the user id in the session id

* Good: key derivable from the id alone, one store, no drift.
* Bad: puts a user identifier inside a credential-adjacent token held by the client and sent on every refresh. Small disclosure, but a permanent one taken for a performance win that Option A also delivers.

## Links

* [ADR-0024: Account and identity model](./0024-account-and-identity-model.md) — the store layout this indexes, and the volumes under which the scan was correct.
* [ADR-0025: Authorization and publish policy](./0025-authorization-and-publish-policy.md) — why `acts`/`roles` are re-read on every mint, which is what puts `membershipsOf` on the hot path.
* [ADR-0009: Short polling as live transport](./0009-realtime-transport-and-session-model.md) — the Free-plan invocation budget this is measured against.
* [ADR-0074: Catalog entry as a distinct object](./0074-catalog-entry-as-distinct-object.md) — the re-key migration whose copy/repoint/cleanup shape this backfill deliberately does *not* need.
