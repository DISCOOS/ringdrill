---
status: accepted
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
  authentication, is never CDN-cached, and decides per reader whether the
  roster is attached. A test asserts both.
* **Option F — One store, an access flag on the blob.** The existing `drills`
  store gains a field; handlers consult it.
* **Option G — Post-write scanning.** A scheduled job looks for `staff/` in
  publicly-readable blobs and alarms.

### For withholding a roster from a reader who is not entitled to it

* **Option H — Strip at write time, wherever the plan is not fully private.**
  One mechanism for every case: if the roster should not reach someone, it is
  not stored.
* **Option I — Store whole, withhold per reader at read time (chosen for the
  account path).** The stored copy is complete; the response is narrowed to
  what the requester may see.

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

**I is the correction that gives this ADR its shape.** A write-time strip (H)
is right for the catalog, where the whole point is that the bytes must not
exist in a public store — but applying the same mechanism to the account path
destroys the owner's own data. A plan set to `shared`, or published, would come
back from the server without the roster its owner entered, on every device but
whichever one happened to author it. Granting a colleague write access must not
delete your phone list. So the two paths use *different* mechanisms on purpose:
write-time strip where the artifact must never contain it, read-time projection
where the artifact must contain it but this particular reader may not see it.

### The rule

Stripping happens in two different places for two different reasons, and
conflating them is the mistake this section exists to prevent. **On the
catalog path the strip is at write time**, because those bytes must never
exist in a publicly readable store. **On the account path there is no strip at
all** — the roster is stored, once, and *withheld per reader* when the reader
is not entitled to it.

Storage is therefore a single fact:

> A plan owned by an account is stored **whole, roster included**, in that
> account's scope. Nothing about the plan's `accessPolicy`, its published
> state, or who else has been granted access removes the roster from that
> stored copy. It is the owner's data, held for the owner.

Service is a projection over that fact, decided per request:

| Reader | Gets the roster? | How |
|---|---|---|
| A member of the **owning account** | **Yes** | Authenticated account read, `Cache-Control: private, no-store` |
| A member of an account granted `AccessPolicy.shared` | No | Same endpoint, roster withheld at read time |
| Anyone via the catalog (`/d/:slug`, feed, `/i/:slug`, MCP) | No | A *separate*, stripped artifact — see below |

Four things follow, and each is a decision rather than an implementation
detail:

**1. Account scope is not the catalog with a flag on it.** Account-synced
archives live in their own store, written and read by their own functions.
Nothing under `/d/:slug`, `/i/:slug`, the feed, or `/mcp` can reach them, and
the account read path is never CDN-cached. This is what makes "uploaded but not
public" a state that can exist at all — today it cannot, because `deep-link.js`
serves any uploaded slug to anyone.

**2. A published plan exists as two artifacts, not one blob with a policy on
it.** The catalog copy is built by stripping and is public. The account copy
keeps the roster and is private. Publishing does not mutate the account copy,
and un-publishing does not restore anything to it, because it never lost
anything. This is the direct consequence of the catalog strip being at write
time: the stripped bytes are a derived artifact, and the original stays where
its owner put it.

**3. Roster travel is implied by account ownership, not a per-plan toggle.**
A plan owned by an account syncs whole to the members of that account. A
separate "also sync the roster" switch would be a confusing question to ask —
the answer is yes every time for a plan a team is actually running, and the
switch would mostly serve to make the default look deliberate. What carries the
transparency load instead is telling the account's members plainly, once, what
an account holds. This answers the open question that
[`../plans/account-rollout.md`](../plans/account-rollout.md) has carried since
May.

**4. `shared` withholds the roster from the other account. It does not remove
it from the plan.** `AccessPolicy.shared`
([ADR-0025](./0025-authorization-and-publish-policy.md)) grants write
access on a plan to a *different* account — a different set of people, and in
data-protection terms a different controller. So plan content crosses that
boundary and the roster does not.

The mechanism has to be read-time, and this is the part that is easy to get
wrong: a write-time strip on the `shared` path would delete the roster from the
stored copy, and the owner — whose data it is, and who is still working the
exercise — would lose it on every device but the one that happened to author
it. Granting a colleague write access to a plan must not destroy your own
roster. The stored copy is untouched by any grant; only the response to the
grantee is narrowed.

Practically that argues for the roster being addressable separately from the
rest of the archive server-side, so the account read path attaches it or omits
it per reader rather than rebuilding an archive per request. Extending `shared`
to carry the roster is a deliberate later decision with its own consent story,
not something that should fall out of a permission grant.

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
2. **A per-reader projection on that path**, with the roster addressable
   separately from the rest of the archive so it can be attached or omitted
   without rebuilding anything. This is what makes withholding a *response*
   decision rather than a *storage* decision, and it is the difference between
   `shared` narrowing what a grantee sees and `shared` destroying the owner's
   roster.
3. **A published privacy statement** naming what personal data an account
   holds, the legal basis, where it is hosted, and the retention window.
4. **Deletion that actually deletes.** Removing a plan, or an account, removes
   the roster server-side within the stated window, backups included.
5. **A route for data subjects who are not users** — someone on a colleague's
   roster asking what is held, correcting it, or having it removed.
6. **EU residency settled, and a sub-processor list** covering hosting, backups
   and any support tooling that can read the data. One entry is already known:
   the transactional mail provider is **Resend**, which stores account data
   (including recipient addresses) in the US under SCCs and EU-US Data Privacy
   Framework certification — a *sending* region in Ireland is dispatch, not
   residency. That is settled for the account release, which stores no rosters.
   If roster residency has to be strictly EU, the mail entry is the one already
   on the wrong side of that line, and swapping it is behind the send seam
   ADR-0073 forces to exist.

Roster sync is not part of the account release; that release is
about authorising *catalog writes*. It is the first feature the account model
unlocks, it lands as its own piece of work once the account release has made
multi-member accounts real, and the six items above are its entry criteria.

### Follow-up: the catalog entry as a distinct object (proposed ADR-0074)

This ADR says a published plan is "two artifacts, not one blob with a policy on
it", and stops at *copies*. Raised on approval (2026-08-05): they may be
different **objects** — publishing derives a catalog entry with its own
identity and lifecycle, rather than putting the account's plan into a public
state.

That strengthens the guarantee here rather than changing it. A catalog object
with no `staff` field cannot represent a roster, so the strip stops being an
operation code must remember and becomes something the type cannot express —
the same move [ADR-0018](./0018-roleplayer-data-model.md) made with the folder
boundary, one level further in. Two places already assume it:

* `Plan.computeContentHash`'s denylist warning
  ([`lib/models/plan.dart`](../../lib/models/plan.dart)) — "anything added to
  `Plan` in future is published by default … the anticipated direction is a
  catalog of *templates* … which is an allowlist question, not a denylist one".
  A distinct catalog object is that allowlist.
* [DESIGN-015](../design/015-accounts-and-iam.md) §9 — deleting an account does
  not delete published catalog plans, which only makes sense if they have
  separate lifecycles.

It is a separate decision because it reaches past PII: publish becomes
derive-and-put, unpublish becomes delete-the-catalog-object with the account
plan untouched, and `accessPolicy` arguably belongs on the catalog object
rather than on the plan ([ADR-0025](./0025-authorization-and-publish-policy.md)).
Convenient timing: today *only* the catalog object exists — account-side
storage is the new thing — so this is a boundary named before the second store
is built, not a migration.

**And the criterion should be "instance data", not "PII"** (raised 2026-08-05).
If public plans converge on being *templates*, then adding staff is
**hydrating** one, and the catalog object excludes the roster *because it is
run-specific* — PII-exclusion becomes a consequence rather than the rule. That
is more durable in both directions: it survives a new PII-bearing field, and it
catches run-specific data that a PII rule waves through.

There is already such a case, and it is published today. `DrillVariable` holds
the declaration and the value in one object
([`lib/models/drill_variable.dart`](../../lib/models/drill_variable.dart)), and
`variables` is re-added to the canonical publish map in `computeContentHash` —
`staff` is the only genuine exclusion. So the duty phone number, KO number and
talegruppe that the authoring guidance tells authors to put in variables rather
than prose travel to the catalog with the plan. Not a privacy problem; a
staleness and usefulness one, since a forker inherits somebody else's
operational values.

Two consequences for ADR-0074 when it is written:

* **Define the catalog object by an allowlist from day one**, even if it
  initially admits everything except `staff`. Tightening toward a real template
  is then an edit to one list, which is exactly what
  [`lib/models/plan.dart`](../../lib/models/plan.dart)'s denylist warning asks
  for and what a denylist can never provide.
* **Splitting `DrillVariable` into declaration and value is the step after**,
  and it is a schema change. Worth knowing before someone attempts it as a
  refactor. Hydration itself is not hypothetical — ADR-0046 and
  [ADR-0068](./0068-cascaded-fields-and-scoped-overrides.md)'s scoped-override
  cascade already hydrate values within a plan; a template is the same
  mechanism with an outer scope.

### The other half of ADR-0074: namespaced slugs

Raised 2026-08-05 while accepting that an `anon` plan stays unclaimable. That
is only tolerable if a slug is unique **per namespace** rather than globally —
one namespace per account, plus `anon` for the wiki corpus. Identity is then
`(namespace, slug)`, which makes it the same decision as the catalog object
rather than a separate one: what the object is, what it carries, how it is
addressed.

What it buys:

* **Fork keeps the name.** [ADR-0025](./0025-authorization-and-publish-policy.md)
  lists as an accepted cost that a user forking a `public` plan "end[s] up with
  a new slug, not the original one". Namespaced, they keep the same name in
  their own namespace, beside the original. No `(kopi)` suffix, no `-2`.
* **The 409 gets informative.** `drills-upload.js` answers
  `x-conflict-kind: slug` today when someone else holds the name. Namespaced it
  only fires within your own account, which is the case where it means
  something.
* **Policy and identity separate cleanly.** The namespace says who published
  it; `accessPolicy` says who may write to it. An account-owned plan at
  `public` policy is ordinary, not a contradiction.

What it costs, stated plainly: **global uniqueness does not disappear, it moves
up one level.** Accounts need a human-readable handle (`@redcross-bergen`, not
`a_xK3nP2v…`) and those must be globally unique. That is a better place for the
constraint — there are far fewer accounts than plans, a handle is chosen once
and deliberately, and squatting becomes bounded rather than a race on every
plan name.

Back-compat is free: `/d/<slug>` keeps resolving to the `anon` namespace, so
the three live plans and every link already shared keep working, and account
plans take the namespaced form. Threading the namespace through
`/i/<slug>` ([ADR-0015](./0015-shareable-install-links.md)), the MCP catalog
tools that take a bare slug ([ADR-0060](./0060-remote-mcp-server.md)), the
`slug-index` key and the feed item shape is the actual work.

### Future work: default values and publish placeholders

Raised 2026-08-05, alongside the framing above and not yet decided.

A variable could carry a **default** (template-level) as well as its current
value (run-level), and publishing could emit a **placeholder** — `________`, or
something shaped like the type — in place of a value that is decided on the day.

Three reasons this is the same idea as the split above, approached from the
authoring side rather than the type side:

* A placeholder *is* an un-hydrated slot, made visible. It is what a template
  should show for a value nobody has filled in yet, and it is why omitting the
  value outright is the wrong answer: an unresolved `{{var.x}}` renders as
  broken, while a blank renders as *fill me in*.
* The domain already does this on paper. The 2026 LSOR booklet wrote `Lag 2.X`
  as a hand-filled wildcard 39 times
  ([ADR-0066](./0066-team-scope-for-cross-reference-tokens.md)) because paper
  cannot compute. A publish placeholder is that blank line, digital.
* It fixes the staleness noted above without inventing a second mechanism: a
  forker inherits a blank to fill rather than somebody else's duty phone
  number.

Open questions if it is picked up: whether the marker is per-variable and
author-set (likely — the author knows which numbers are theirs) or inferred
from `VariableType` (guessy); whether the placeholder is stored or derived at
publish; and how the publish dialog previews what will actually go out, since
a substitution the author cannot see before publishing is worse than none.
Note that a *value*, unlike `staff/`, is not PII by default — a duty number
belongs to a role. The reason to placeholder it is that it is run-specific,
which is the same criterion as everything else here.

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
* Good: The `shared` boundary is decided before its UI is designed,
  rather than discovered when someone notices a roster crossed to another
  organisation.
* Good: Sharing a plan is non-destructive to the owner. No grant, policy flip
  or publish can remove the roster from the copy the owner holds, because
  withholding is a property of the response and not of the stored bytes.
* Bad: The privacy programme is back on the critical path, correctly. An
  earlier draft of this ADR removed it by removing the feature; that was a
  cheaper plan for a worse product. Roster sync costs a privacy statement, a
  deletion path that reaches backups, and a data-subject route before it can
  ship at all.
* Bad: Two stores and two read paths is more backend surface than one, and the
  cheap mistake — reusing the catalog store "just for now" — is exactly the one
  that leaks. The test is a guard, not a guarantee.
* Bad: Two different withholding mechanisms in one system is a thing to keep
  straight. Write-time on the catalog path, read-time on the account path, and
  the plausible-sounding simplification ("just strip everywhere, it is safer")
  is the bug — it silently deletes the owner's roster. Anyone touching either
  path has to know which one they are on.
* Bad: A read-time projection means the account read path cannot be a blob
  passthrough. It has to assemble a response per requester, which is more work
  than serving bytes and one more place for an authorisation check to be
  forgotten.
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

### H. Strip at write time, wherever the plan is not fully private

* Good: One mechanism for every case, and the simplest thing to reason about:
  if the bytes are not there, they cannot leak.
* Good: Correct, and the only safe answer, for the catalog — where the artifact
  is public and must never have contained a roster.
* Bad: Destroys the owner's own data on the account path. Setting a plan to
  `shared`, or publishing it, would remove the roster from the stored copy, and
  the owner would lose it everywhere except whichever device authored it.
* Bad: Makes an access grant irreversible in a way nobody would expect.
  Revoking `shared` cannot bring the roster back, because it was deleted, not
  hidden.

### I. Store whole, withhold per reader (chosen for the account path)

* Good: Sharing is non-destructive. The owner's copy is complete regardless of
  who else has been granted what.
* Good: Reversible by construction — revoking a grant restores nothing because
  nothing was removed.
* Good: Puts the decision next to the identity that motivates it, at the moment
  of the request, rather than at write time when the future set of readers is
  not yet known.
* Bad: The response has to be assembled per reader, so the account read path
  cannot be a blob passthrough.
* Bad: The PII is present on the server for every request that touches the
  plan, and only an authorisation check keeps it out of the response. A missing
  check leaks; under H there would be nothing to leak.

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
