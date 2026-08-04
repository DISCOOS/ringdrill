---
status: proposed
date: 2026-08-04
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0072: Let a roster reach the account that owns the plan, and keep the catalog stripped

## Context and problem statement

[ADR-0018](./0018-roleplayer-data-model.md) drew the PII boundary as a folder
boundary: role data lives in `roleplays/` and is publishable, the humans live in
`staff/` and are not, and `drills-upload.js` drops the folder before anything is
stored. That is the whole of the current privacy story, and it holds for one
structural reason — **publishing to the catalog is the only path that sends a
plan to our servers.**

Accounts break that assumption in a way that is easy to get backwards. The
tempting reading is "the strip protects personal data, so keep stripping
everywhere". That mistakes the mechanism for the goal. A roster is not
incidental content that leaked into the archive; it is *operational data for
the people running the exercise* — who is on which post, which number to ring
when someone does not answer their radio. Two coordinators co-owning a plan
([ADR-0024](./0024-account-and-identity-model.md)'s central use case: "two
coordinators in the same SAR team must be able to publish updates to the same
plan without sharing credentials") need the same phone list. An account that
carries the plan but not the roster would leave the co-owner re-typing thirty
people by hand, which is not co-ownership of anything that matters.

So the boundary is not "PII never leaves the device". It is **the catalog** — a
public, wiki-model corpus that anyone can read. An account is the opposite kind
of place: a named, bounded set of people who are already working this exercise
together. Sharing a roster inside it is the expected behaviour, not a leak.

One fact makes this more than a policy question. Today, *stored server-side*
and *readable by anyone* are the same state:

* `/d/:slug` is served by [`deep-link.js`](../../netlify/functions/deep-link.js),
  which checks no `published` flag and no credential. Any uploaded slug is
  downloadable by anyone who knows or guesses it, and the response is CDN-cached.
* `published` only controls whether a plan is *listed* in
  [`market-feed.js`](../../netlify/functions/market-feed.js). It is a listing
  flag, not an access control.

There is therefore no such thing today as "upload it but keep it private". The
strip is not one safeguard among several — it is the only thing between a
roster and a public URL. Enabling roster sync is consequently not "stop
stripping on one path"; it requires a storage location and a read path that do
not exist yet. That, rather than the paperwork, is the real precondition, and
it is what this ADR has to decide before
[`../plans/account-rollout.md`](../plans/account-rollout.md) can sequence
anything.

## Decision drivers

* **A roster has to reach the people co-running the exercise.** This is the
  point of account co-ownership. A design that strips it everywhere protects
  nobody and breaks the feature.
* **The catalog is public and must stay stripped.** Publishing means anyone can
  read it. No policy value, no account, and no future feature changes that.
* **The two paths must not be able to collapse.** The failure mode is silent:
  PII reaches a publicly-readable blob, nothing errors, no test fails, and we
  find out from someone else. This repo has already had one near-miss of that
  exact shape — the `actors` → `staff` denylist rename in `computeContentHash`
  (ADR-0018, "One trap worth recording") would have published real names with
  nothing failing.
* **The data subjects are mostly not the user.** Someone enters a colleague's
  name and number. Inside an account that colleague is usually one of the
  people the account exists for, which is what makes the sharing reasonable —
  but it is not consent, and it does not remove their rights over the data.
* **One maintainer.** Whatever is committed to must be operable. A retention
  promise we cannot honour is worse than not storing the data.
* **Offline-first ([ADR-0024](./0024-account-and-identity-model.md)).** A plan
  stays fully usable with its roster on-device and nothing synced. Peer-to-peer
  `.drill` transfer already moves rosters between devices and is untouched by
  anything here.

## Considered options

### For where a roster may live

* **Option A — Strip on every path; rosters never leave the device.** One rule,
  nothing to state or retain, no legal work on the critical path.
* **Option B — A roster travels into the scope of the account that owns the
  plan; the catalog path strips unconditionally (chosen).** Two destinations,
  two rules, drawn where the trust boundary actually is.
* **Option C — The roster travels wherever the plan travels, with per-field
  redaction at the catalog edge.** One path, one archive, fields marked
  publishable or not.
* **Option D — Client-encrypted roster, opaque to the server.** The account's
  members hold the key; we store ciphertext.

### For how the catalog path is kept stripped once a second path exists

* **Option E — Separate stores, separate read paths, enforced by a test
  (chosen).** Catalog blobs and account-scoped blobs live in different stores
  reached by different functions. The catalog write path applies the strip
  inside its shared ingest helper; the account read path requires
  authentication and is never CDN-cached. A test asserts both.
* **Option F — One store, an access flag on the blob.** The existing `drills`
  store gains a field; handlers consult it.
* **Option G — Post-write scanning.** A scheduled job looks for `staff/` in
  publicly-readable blobs and alarms.

## Decision outcome

Chosen: **B (roster reaches the owning account, catalog stays stripped)**,
enforced by **E (separate stores and read paths, with a test)**.

B wins because it puts the boundary where the trust boundary is. A is the
version of this ADR I drafted first, and it is wrong: it protects the roster
from the people who need it and calls that a privacy win, while leaving
co-ownership useful only for plans nobody staffs. C fails on the catalog side —
per-field redaction is exactly the "inspect every field of every record"
approach that ADR-0018 rejected as Option A, and it re-establishes the failure
mode the folder boundary was created to eliminate. D is genuinely attractive
and stays on the table as a later hardening, but key distribution across
account members, and key loss meaning permanent roster loss, is a larger
project than the first version of this feature can carry.

E wins because F is one boolean away from a public roster, and because CDN
caching is decided per route: a flag on a blob cannot retract a response the
CDN has already cached, whereas a route that never caches cannot leak one.
G is worth having as a second line but detects a disclosure that already
happened, which for personal data is too late to be the mechanism.

### The rule

| Destination | `staff/` | Read path |
|---|---|---|
| Catalog (`published` or not — `/d/:slug`, feed, `/i/:slug`, MCP) | **Stripped, always** | Public, CDN-cached, as today |
| The owning account's own scope | **Travels with the plan** | Authenticated, members of that account only, `Cache-Control: private, no-store` |
| Another account via `AccessPolicy.shared` | **Stripped** by default | Plan content only — see below |

Three things follow, and each is a decision rather than an implementation
detail:

**1. Account scope is not the catalog with a flag on it.** Account-synced
archives live in their own store, written and read by their own functions.
Nothing under `/d/:slug`, `/i/:slug`, the feed, or `/mcp` can reach them, and
the account read path is never CDN-cached. This is what makes "uploaded but not
public" a state that can exist at all — today it cannot, because `deep-link.js`
serves any uploaded slug to anyone.

**2. Roster travel is implied by account ownership, not a per-plan toggle.**
A plan owned by an account syncs whole, roster included, to the members of that
account. A separate "also sync the roster" switch would be a confusing question
to ask — the answer is yes every time for a plan a team is actually running,
and the switch would mostly serve to make the default look deliberate. What
carries the transparency load instead is telling the account's members plainly,
once, what an account holds. This answers the open question that
[`../plans/account-rollout.md`](../plans/account-rollout.md) has carried since
May.

**3. `shared` does not carry the roster.** `AccessPolicy.shared`
([ADR-0025](./0025-authorization-and-publish-policy.md), phase 5) grants write
access on a plan to a *different* account — a different set of people, and in
data-protection terms a different controller. Plan content crosses that
boundary; the roster does not. Extending it is a deliberate later decision with
its own consent story, not something to fall out of a permission grant. Until
then the cross-account write path strips, same as the catalog path.

### What the catalog path keeps

`PII_FOLDERS` stays the single list, and keeps stripping **both** `actors/` and
`staff/` permanently, for the deploy-cadence reason DESIGN-011 already
recorded. Every function that accepts `.drill` bytes destined for the catalog
obtains them through the shared ingest helper, and that helper applies the
strip before returning them — there is no way to get raw request bytes on the
catalog path and skip it short of writing a new reader. A test enumerates the
functions that read archive bytes and asserts each catalog-bound one routes
through the helper, and that no account-scoped archive is reachable from a
public route. It is a coarse test on purpose: it should fail for someone adding
an endpoint who has not read this ADR.

### What shipping roster sync requires

These are not deferrals. They are the gate on the phase that ships sync, and
they are real work rather than paperwork:

1. **An authenticated, uncached read path** and a store that no public route
   can reach. Without this the rest is moot, because today every stored byte is
   public.
2. **A published privacy statement** naming what personal data an account
   holds, the legal basis, where it is hosted, and the retention window.
3. **Deletion that actually deletes.** Removing a plan, or an account, removes
   the roster server-side within the stated window, backups included.
4. **A route for data subjects who are not users** — someone on a colleague's
   roster asking what is held, correcting it, or having it removed.
5. **EU residency settled, and a sub-processor list** covering hosting, backups
   and any support tooling that can read the data.

Roster sync is not one of the six phases in the rollout plan; those phases are
about authorising *catalog writes*. It is the first feature the account model
unlocks, it lands as its own piece of work after phase 5 makes multi-member
accounts real, and the five items above are its entry criteria.

### Relationship to ADR-0018

This amends [ADR-0018](./0018-roleplayer-data-model.md)'s PII boundary, which is
written as though the catalog were the only destination a plan can be uploaded
to. The catalog rule is unchanged and unconditional. What changes is that the
boundary is now named for what it is — *public corpus* rather than *our
servers* — and a second, private destination is admitted alongside it.

### Consequences

* Good: Co-ownership works on the thing teams actually coordinate on. The
  second coordinator gets the roster, which is most of why they wanted the
  shared plan.
* Good: The catalog rule gets stronger, not weaker. It moves from "the publish
  endpoint remembers to strip" to "no catalog-bound byte reaches a store
  without passing the strip", enforced by a test.
* Good: "Uploaded but not public" becomes a state the backend can actually
  represent. That is worth having on its own — today `published` is a listing
  flag that reads like an access control, which is its own latent trap.
* Good: The `shared` boundary is decided before phase 5 designs a UI around it,
  rather than discovered when someone notices a roster crossed to another
  organisation.
* Bad: The privacy programme is back on the critical path, correctly. An
  earlier draft of this ADR removed it by removing the feature; that was a
  cheaper plan for a worse product. Roster sync costs a privacy statement, a
  deletion path that reaches backups, and a data-subject route before it can
  ship at all.
* Bad: Two stores and two read paths is more backend surface than one, and the
  cheap mistake — reusing the catalog store "just for now" — is exactly the one
  that leaks. The test is a guard, not a guarantee.
* Bad: Deferring encrypted sync (D) means the first version is server-readable,
  and every item on the gate list exists because of that. Revisiting D later
  means migrating stored rosters, not just adding a feature.
* Bad: Until sync ships, a co-owner still re-types the roster or passes a
  `.drill` by hand. The gap this ADR names is not closed by naming it.

## Pros and cons of the options

### A. Strip everywhere, rosters never leave the device

* Good: Nothing to state, retain, or delete. No legal work anywhere.
* Good: One rule, impossible to get wrong.
* Bad: Mistakes the mechanism for the goal. The roster is operational data for
  the people co-running the exercise, and an account is precisely the bounded
  context where sharing it is reasonable.
* Bad: Makes account co-ownership hollow for any plan with real staffing.

### B. Roster reaches the owning account; catalog stripped (chosen)

* Good: The boundary sits where the trust boundary sits.
* Good: The catalog rule stays absolute and gets structurally stronger.
* Bad: Two destinations means two sets of rules to keep straight, forever.
* Bad: Puts the privacy programme on the critical path for the sync feature.

### C. One path, per-field redaction at the catalog edge

* Good: One archive, one upload path, no second store.
* Bad: Re-establishes ADR-0018's rejected Option A — the upload handler
  inspects every field of every record instead of dropping a folder, and PII
  leakage becomes procedural rather than structural.
* Bad: A new PII-bearing field added anywhere leaks by default.

### D. Client-encrypted roster

* Good: We hold ciphertext, which shortens most of the gate list.
* Good: Survives a store compromise.
* Bad: Key distribution across account members, and key loss meaning
  unrecoverable roster loss, is a bigger project than the first version.
* Bad: "We cannot read it" still has to be stated publicly to be worth
  anything, so it does not remove the privacy statement.

### E. Separate stores and read paths, enforced by a test (chosen)

* Good: The unsafe path stops being reachable by accident.
* Good: Caching is decided per route, so a private route cannot leak a cached
  response.
* Bad: More backend surface, and the test recognises a shape rather than an
  intent.

### F. One store, an access flag on the blob

* Good: Least new infrastructure.
* Bad: One boolean between a roster and a public URL.
* Bad: Cannot retract a response the CDN already cached.

### G. Post-write scanning

* Good: Catches what the ingest rule misses.
* Bad: Detects a disclosure that already happened. A second line, not the
  mechanism.

## Links

* Related ADRs:
  [ADR-0006](./0006-sentry-behind-consent-gate.md),
  [ADR-0008](./0008-persistent-program-library-and-catalog.md),
  [ADR-0014](./0014-server-assigned-drill-version.md),
  [ADR-0018](./0018-roleplayer-data-model.md) — amended by this ADR,
  [ADR-0024](./0024-account-and-identity-model.md),
  [ADR-0025](./0025-authorization-and-publish-policy.md),
  [ADR-0063](./0063-per-field-brief-visibility.md) — who sees contact details
  *within* a plan on a device, a different axis from who can fetch the plan.
* Related designs:
  [DESIGN-011](../design/011-person-with-role-and-roster-model.md) — widened
  `Actor` to `Staff` and grew what the roster holds.
* Related plans:
  [`account-rollout.md`](../plans/account-rollout.md) — closes its open
  question on staff PII sync, and names roster sync as post-phase-5 work.
* Related code:
  `netlify/functions/lib/drill-pii.js` (`PII_FOLDERS`, `stripPiiFolders`),
  `netlify/functions/drills-upload.js` (today's only call site),
  `netlify/functions/deep-link.js` (serves `/d/:slug` with no publish check
  and no credential — why "stored" currently means "public"),
  `netlify/functions/market-feed.js` (`published` is a listing flag),
  `lib/models/plan.dart` (`computeContentHash` denylist),
  `lib/data/drill_file.dart` (writes `staff/` locally, unaffected)
