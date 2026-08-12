---
status: proposed
date: 2026-08-12
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0078: Put the expiry in the key, and let the sweep catch itself up

## Context and problem statement

`sweepExpired` drops records whose `expiresAt` has passed. It is called opportunistically from write paths rather than from a scheduler, because a sweep that runs whenever the store is used cannot silently stop running the way a cron can — that reasoning still holds and is not what this ADR revisits.

What it revisits is the cost. The sweep read every blob in the store to find out which had lapsed, because the expiry was only visible inside the record. Its two callers are not alike:

* **Sign-in challenges** have a ten-minute TTL, so the store holds roughly the sign-ins of the last few minutes. The scan is small and stays small.
* **Invitations** have a fourteen-day TTL, and the sweep runs on `POST /api/accounts/:id/members` — the path an organisation walks once per member it invites. So the store holds a fortnight of invitations and is scanned during exactly the burst that fills it, which is a new organisation onboarding its people.

The `limit: 200` guard does not help: it caps deletions, not reads. A store of mostly-live invitations is walked in full to remove nothing.

This is the same shape as [ADR-0077](./0077-reverse-indexes-for-per-user-lookups.md) — a store keyed for one question being asked another — with one difference that changes the design. There, a missing index entry costs a fallback scan and the user still gets the right answer. Here, a record the sweep cannot see is a record that is never dropped: an email address belonging to somebody who may never have had an account, kept indefinitely, silently. Invisibility is the failure mode the sweep exists to prevent.

## Decision drivers

* The steady-state sweep must not read records to decide what to drop.
* No record may become invisible to the sweep, including one written before the index existed or one whose index write was lost.
* No required migration step. "It works once an operator remembers to run the backfill" is not an acceptable property for a retention mechanism.
* Per-call work must be bounded, so a store full of unindexed records cannot produce one very long call.
* The challenge store must not be made more complicated to fix a problem it does not have.

## Considered options

* Option A: Expiry in the index key (`<expiresAt>/<recordKey>`), plus a bounded catch-up pass over anything unindexed.
* Option B: Expiry in the index key, plus a one-off backfill admin action like ADR-0077's.
* Option C: Day- or hour-bucketed index keys (`<yyyy-mm-dd>/<recordKey>`), sweeping buckets already past.
* Option D: Leave the sweep alone and move it to a scheduled function.

## Decision outcome

Chosen option: **Option A**, because it is the only one where the sweep is cheap *and* cannot be made blind by a record it has not met yet.

The key is `<expiresAt zero-padded to 13 digits>/<recordKey>`. A `list` returns keys without their values, so the sweep learns what has lapsed without reading anything. Padding is not needed by any current code — nothing depends on the ordering — but a mixed-width key set would make that option unrecoverable later, and it costs one `padStart` to keep.

The catch-up pass is what makes the index safe to rely on. After the index-driven deletions, the sweep lists the base store — keys only, no reads — and reads at most `backfill` records that the index does not already know about, dropping them if they have lapsed and indexing them if they have not. Two properties follow:

* **Nothing stays invisible.** A store of legacy records is absorbed over a handful of calls rather than being ignored forever.
* **The work is bounded and self-extinguishing.** Once everything is indexed, the pass reads nothing at all, so the steady state is two listings and the deletes.

The challenge store keeps the old scan, deliberately. Its TTL keeps it small, and the path with no index argument is retained and tested rather than left as an untested branch.

Writes go record-first, index-second, as in ADR-0077 and for the same reason: an unindexed invitation is picked up by the next catch-up pass, where an index entry for an invitation that was never written would name a key belonging to nobody.

### Consequences

* Good: the steady-state sweep costs two listings and the deletions, instead of one read per invitation in the store.
* Good: no deploy ordering and no backfill action. The change is correct the moment it ships.
* Good: an index write that is lost is repaired by the next sweep rather than leaking a record permanently.
* Bad: the sweep now lists the base store on every call to find unindexed keys. That is a listing rather than a read per record, and it is what buys the guarantee above — but it is not free, and it does not shrink as the store grows.
* Bad: a third index store to reason about, with a key format that is parsed rather than compared. Keys that do not parse are left alone rather than treated as ours.
* Bad: invitations withdrawn or accepted keep their index entry until expiry. Harmless — the entry names a key whose deletion is a no-op — but it means the index is a superset of the store rather than a mirror of it.

## Pros and cons of the options

### Option A: expiry in the key, plus bounded catch-up

* Good: cheap steady state with no way for a record to hide from the sweep.
* Bad: lists the base store every call.

### Option B: expiry in the key, plus a backfill action

* Good: no per-call listing of the base store; the cheapest steady state of the four.
* Bad: correctness depends on an operator running something. For a mechanism whose job is to stop holding stray email addresses, a forgotten step is a retention failure that nothing surfaces. Rejected on that.

### Option C: bucketed keys

* Good: sweeping a past bucket is a prefix listing, so the base store is never listed.
* Bad: finding *which* buckets exist needs either a range query, which the blob store does not offer, or enumerating a fixed window of recent buckets — which silently misses anything older than the window if the sweep does not run for a while. Trades one invisibility hole for another.
* Bad: coarse buckets also delay removal by up to a bucket, which is the wrong direction for a retention mechanism.

### Option D: schedule it instead

* Good: no index, no new key format.
* Bad: does not address the cost at all, only who pays it. Also gives up the property the current design was chosen for — a cron that stops firing is silent, where a sweep on the write path cannot stop while the feature is in use.

## Links

* [ADR-0077: Reverse indexes for per-user lookups](./0077-reverse-indexes-for-per-user-lookups.md) — the same inversion for a different question, and the source of the record-first write ordering.
* [ADR-0024: Account and identity model](./0024-account-and-identity-model.md) — the invitation lifecycle and its fourteen-day TTL.
* [`docs/data-retention.md`](../data-retention.md) — why an expired invitation is deleted rather than kept.
