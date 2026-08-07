---
status: proposed
date: 2026-08-08
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0074: A catalog entry is a distinct object, identified by `(namespace, slug)` and defined by an allowlist

## Context and problem statement

[ADR-0072](./0072-staff-pii-and-account-sync.md) says a published plan is "two
artifacts, not one blob with a policy on it" — a stripped public copy and a
complete private one — and then stops at *copies*. Its follow-up note records
the objection raised on approval: they may be different **objects**, where
publishing *derives* a catalog entry with its own identity and lifecycle rather
than putting the account's plan into a public state.

Two places in the codebase already behave as though that were true:

* `Plan.computeContentHash`'s denylist warning
  ([`lib/models/plan.dart`](../../lib/models/plan.dart)) — "anything added to
  `Plan` in future is published by default … the anticipated direction is a
  catalog of *templates* … which is an allowlist question, not a denylist one."
* [DESIGN-015](../design/015-accounts-and-iam.md) §9 — deleting an account does
  **not** delete published catalog plans, because other people have installed
  them. That only makes sense if the two have separate lifecycles.

A third pressure arrives from [ADR-0025](./0025-authorization-and-publish-policy.md)'s
accepted cost: an `anon` plan is unclaimable, and a user forking a `public`
plan "end[s] up with a new slug, not the original one" — because slugs are
globally unique and the name is already taken. That is only tolerable if a name
can be reused in a different scope.

The timing is unusually good and will not repeat. **Today only the catalog
object exists.** Account-side storage is the new thing ADR-0072 introduces. So
this is a boundary named *before* the second store is built, not a migration
after the fact.

## Decision drivers

* **A new field on `Plan` must not become public by default.** The current
  denylist means it does, and the failure is silent — nothing errors, no test
  fails.
* Deleting an account, unpublishing, or changing a policy must not be able to
  destroy something other people have installed, and vice versa.
* Forking a plan should be able to keep its name. The alternative is `-2` and
  `(kopi)` suffixes forever, on a corpus where the good names are taken by
  plans nobody can claim.
* The three live catalog plans and every link already shared must keep working,
  untouched.
* Whatever is decided has to leave room for the catalog to become a corpus of
  **templates** later, without that being a second migration.

## Considered options

### For the boundary between the account's plan and the catalog

* **Option A — One object, a policy field on it (status quo).** `accessPolicy`
  says who may write; the same stored bytes serve everyone.
* **Option B — Two objects; publishing derives the catalog entry (chosen).**
  The account holds the plan. Publishing produces a separate catalog entry from
  it. Unpublishing deletes that entry and leaves the plan alone.
* **Option C — Two objects kept in bidirectional sync.** Edits on either side
  propagate. A distributed-systems problem bought for no benefit anyone asked
  for.

### For catalog identity

* **Option D — Globally unique slugs (status quo).** One namespace for
  everyone; first publish wins the name forever.
* **Option E — `(namespace, slug)`, namespace being an account handle or
  `anon` (chosen).**
* **Option F — Opaque id as identity, slug as a display alias.** Maximum
  flexibility, and it throws away the readable, shareable URL that
  [ADR-0015](./0015-shareable-install-links.md) is built on.

### For what a catalog entry carries

* **Option G — Denylist (status quo).** Start from the plan, remove what must
  not be published.
* **Option H — Allowlist (chosen).** Start from nothing, name what a catalog
  entry carries.

## Decision outcome

Chosen: **B + E + H.**

### 0. "Distinct object" means a distinct stored instance, not a distinct class

Clarified 2026-08-08, because the first draft of this ADR implied more than it
should have.

| Distinct | |
|---|---|
| **Stored instance** | Its own store, its own key |
| **Identity** | `(namespace, slug)`, not the plan's `uuid` |
| **Lifecycle** | Deleting the plan leaves the catalog entry standing |
| **Access path** | Public and CDN-cached, versus authenticated and `no-store` |
| **Shape** | May differ — it carries what the allowlist names |
| ~~Class~~ | **No.** |

**There is no second model type, and on the server there is no type at all.**
`drills-upload.js` never deserialises a `Plan`: a catalog entry is a ZIP plus
`meta.json`, and an account-scoped copy is a ZIP plus `meta.json`. On the
client both parse into the same `Plan` and differ only in what is populated —
already true today, since a catalog download arrives with an empty staff list.
A parallel `CatalogPlan` would be a second model to keep in sync for no
enforcement gain.

That changes where the guarantee comes from, and the earlier framing of this
ADR got it wrong. A catalog entry does not exclude a roster because "the type
cannot express it" — **the allowlist is applied at one derivation site and held
there by a test.** Weaker than a type would be, and it is what this
architecture actually offers: one place to get right, and a test that fails
when a new field is unclassified.

**One consequence worth knowing before implementing.** The allowlist operates
at **archive-entry granularity** — `program.json`, `metadata.json`,
`exercises/`, `teams/`, `sessions/`, `roleplays/` and the markdown companions
are named; `staff/` is not. That is exactly where
[ADR-0018](./0018-roleplayer-data-model.md)'s folder boundary already sits, so
day one is a restatement of today's behaviour in the safe direction.

It also means the allowlist **cannot** reach field-level instance data —
`variables` values live *inside* `program.json`, so an entry-level list will
never catch them. Tightening toward templates therefore needs a second,
field-level pass over `program.json`, which is a different mechanism rather
than a longer list. Knowing that now is worth more than discovering it while
trying to extend the wrong thing.

**The class question is deferred, not settled forever.** "No separate class"
is right for a catalog entry that is *a plan minus one folder*, which is what
it is today. If the catalog converges on **templates**, that stops being true:
a template has no roster, no resolved variable values, and arguably no
instantiated teams or sessions — it is not a `Plan` with fields left empty, it
is the thing a `Plan` is instantiated *from*. At that point a distinct type
earns itself, because the two would no longer share a shape and "same class,
different content" would stop describing anything.

So the trigger is the template move, not the storage split. Splitting storage
now (§1) costs nothing if a type arrives later — the derivation site is where
a `Template` would be produced instead of a stripped `Plan`, and the allowlist
is the seed of that type's field list.

### 1. Publishing derives an object; it does not flip a state

The account's plan and the catalog entry are separate objects with separate
lifecycles:

| Action | Catalog entry | Account's plan |
|---|---|---|
| Publish | Created or updated, derived from the plan | Untouched |
| Unpublish | Deleted | Untouched |
| Change `accessPolicy` | Changed | Untouched |
| Delete the plan | **Untouched** — other people have installed it | Deleted |
| Delete the account | **Untouched** | Deleted |

The last two are the ones that motivate the split, and DESIGN-015 §9 already
promised them. Under Option A they would require a special case; here they are
just what separate objects do.

**`accessPolicy` moves onto the catalog entry**, where it always belonged. It
answers "who may publish updates to *this catalog entry*", which is meaningless
for a plan that has never been published. The account's plan needs no policy at
all: access to it follows account membership
([ADR-0024](./0024-account-and-identity-model.md),
[ADR-0072](./0072-staff-pii-and-account-sync.md)). Two objects, two mechanisms,
neither pretending to be the other.

### 2. Identity is `(namespace, slug)`

A namespace is an **account handle**, or the reserved `anon`.

```
/d/lsor-eidene-2026                      →  anon namespace   (unchanged, forever)
/d/lsor-eidene-2026@5                    →  anon, version 5  (unchanged)
/d/redcross-bergen/lsor-eidene-2026      →  account namespace
/d/redcross-bergen/lsor-eidene-2026@5    →  account, version 5
```

**No sigil.** An earlier draft prefixed handles with `@`, justified as avoiding
collisions with route segments like `api` and `mcp`. That justification is
wrong: those are *root* routes, and a handle only ever appears under `/d/` or
`/i/`, so it cannot collide with them.

**Segment count disambiguates on its own.** `sanitizeSlug`
([`lib/shared.js`](../../netlify/functions/lib/shared.js)) strips everything
outside `[a-z0-9-]`, so a slug can never contain `/`. One segment means `anon`,
two means namespaced, and there is no third reading.

A sigil would also have been actively harmful here, because **`@` is already
spoken for in this route** as the version separator —
[`deep-link.js`](../../netlify/functions/deep-link.js) parses
`^([^@/]+)(?:@([^/]+))?$`. `/d/@redcross-bergen/lsor-eidene-2026@5` gives `@`
two meanings in one path. Without the sigil the namespace and the version
compose cleanly, as the examples above show.

The one thing a sigil would buy is reserving the option of **root-level account
pages** (`ringdrill.app/redcross-bergen`), which would need a reserved-word
list to coexist with `/api`, `/d`, `/i`, `/mcp` and `/brief`. No such page
exists or is planned, and that is the moment to choose a sigil — not now, for a
page that may never be built.

**Back-compat is free and permanent.** `/d/<slug>` resolves in `anon`, which is
where all three live plans are and where anonymous publishing keeps putting new
ones ([ADR-0025](./0025-authorization-and-publish-policy.md), amended
2026-08-05). This is not a transitional shim: `anon` entries are unclaimable by
design, so the bare form has to keep working indefinitely.

What it buys:

* **A fork keeps its name.** `@redcross-bergen/lsor-eidene-2026` sits beside
  `anon/lsor-eidene-2026`. This retires the cost ADR-0025 explicitly accepted.
* **The slug-taken 409 becomes informative.** It fires only within your own
  namespace, where it means "you already have one called this" instead of
  "somebody, somewhere, got there first".

**Global uniqueness does not disappear — it moves up to account handles**, and
that is a better place for it: far fewer accounts than plans, chosen once and
deliberately, and squatting is bounded rather than a race on every plan name.
Handles are `^[a-z0-9](?:[a-z0-9-]{1,38})$`, case-insensitive, and `anon` is
reserved.

**Handles may be renamed, and the old one becomes a permanent tombstone** that
redirects and can never be re-registered. Forbidding rename is cheaper to build
and worse to live with — organisations do change names — and re-issuing a
released handle would silently redirect somebody's shared link to a stranger's
plan.

### 3. Content is an allowlist, and the criterion is *instance data*

A catalog entry carries what an explicit allowlist names — at archive-entry
granularity, applied at the single derivation site (§0). Adding an archive
member therefore does **not** publish it; it is excluded until somebody
classifies it, and a test fails until they do.

That inversion is the whole point. The current denylist has exactly the failure
mode ADR-0018 recorded as "One trap worth recording": a rename that moved a
field without moving its denylist entry would have published real names with
nothing failing.

**The criterion is "is this instance data", not "is this PII".** If the catalog
converges on templates, then adding staff to a plan is *hydrating* one, and the
roster is excluded because it is run-specific — PII exclusion falls out as a
consequence. That is more durable in both directions: it survives a new
PII-bearing field, and it catches run-specific data that a PII rule waves
through.

There is already such a case. `DrillVariable` holds its declaration and its
value in one object, and `variables` is in the published set — so the duty
phone number, KO number and talegruppe that the authoring guidance tells
authors to put in variables travel to the catalog. Not a privacy problem; a
staleness one, since a forker inherits somebody else's operational values.

**This ADR does not fix that**, and deliberately so. The allowlist starts by
admitting everything the denylist admits today, so nothing changes on day one.
What changes is that tightening it later — splitting `DrillVariable`, adding
publish placeholders (ADR-0072's "Future work") — becomes an edit to one
declaration rather than an archaeology exercise.

### 4. What has to be threaded through

The namespace is not confined to the storage key:

* `slug-index` keys become `<namespace>/<slug>`.
* `deep-link.js` (`/d/`) and the install-link route (`/i/`,
  [ADR-0015](./0015-shareable-install-links.md)) accept an optional leading
  namespace segment. `deep-link.js`'s current pattern already rejects `/`
  inside the tail, so this is a widened match rather than a rewrite, and the
  existing `@version` suffix is untouched.
* Feed items gain the namespace, so a client can address what it just read.
* The MCP catalog tools take a bare slug today
  ([ADR-0060](./0060-remote-mcp-server.md)) and need the namespaced form —
  with the bare form still resolving in `anon`, which is where every plan they
  can currently see lives.
* `Account` gains `handle`, with its own uniqueness index.

### Consequences

* Good: a new `Plan` field is private until classified. The most likely future
  privacy incident in this codebase is the one this removes.
* Good: unpublish, plan deletion and account deletion stop needing special
  cases to avoid destroying what others installed. Separate objects simply
  behave that way.
* Good: forks keep their names, which retires a cost ADR-0025 accepted with
  visible reluctance.
* Good: `accessPolicy` lands on the object it describes, and the account's plan
  loses a field that never meant anything for it.
* Good: the template direction becomes a list edit rather than a second
  migration.
* Bad: account handles are a new globally unique namespace, with validation,
  reserved names, a rename-and-tombstone story, and a squatting surface — none
  of which exist today.
* Bad: the namespace has to be threaded through five surfaces (storage keys,
  two routes, the feed, MCP). Each is small; forgetting one produces a
  404 rather than a silent error, which is the good direction, but it is still
  five places.
* Bad: two objects means they can diverge — an account plan edited without
  republishing. That is already true and already handled (OCC, `ProgramDiff`,
  the three-way refresh from
  [ADR-0008](./0008-persistent-program-library-and-catalog.md)); this ADR makes
  the divergence explicit rather than introducing it.
* Bad: the allowlist admits nearly everything on day one, so it buys no
  immediate protection — only the mechanism for it. A reader could mistake the
  mechanism for the fix.

## Pros and cons of the options

### A. One object with a policy field

* Good: no new concepts, no migration, nothing to thread through.
* Bad: account deletion and unpublish need special cases to avoid destroying
  what other people installed.
* Bad: leaves `accessPolicy` on an object where it is meaningless until publish.

### B. Two objects, derived on publish (chosen)

* Good: lifecycles that DESIGN-015 already promised fall out for free.
* Good: the public bytes and the private bytes are separate stored instances,
  so the boundary is a storage fact rather than a flag anyone can flip.
* Bad: two objects to keep straight, and a derivation step to get right.

### C. Bidirectional sync

* Good: edits anywhere converge.
* Bad: conflict resolution across a public corpus nobody owns. A large problem
  bought to solve one nobody has.

### D. Global slugs

* Good: one flat namespace, simplest possible resolution.
* Bad: the good names are permanently held by unclaimable `anon` plans.
* Bad: forks cannot keep their name.

### E. `(namespace, slug)` (chosen)

* Good: forks keep names; the 409 becomes informative; policy and identity
  separate cleanly.
* Good: back-compat is free, because `anon` is a real namespace rather than a
  legacy mode.
* Bad: introduces account handles and everything that comes with them.

### F. Opaque id with slug as alias

* Good: renames and moves become trivial.
* Bad: throws away the readable shareable URL ADR-0015 is built on.

### G. Denylist

* Good: no work; new fields publish automatically, which is occasionally what
  you want.
* Bad: new fields publish automatically, which is usually not, and the failure
  is silent.

### H. Allowlist (chosen)

* Good: unclassified fields stay private. Fails closed.
* Good: the template direction becomes one declaration to edit.
* Bad: every new field needs a decision, including the many that are obviously
  publishable.

## Links

* Related ADRs:
  [ADR-0008](./0008-persistent-program-library-and-catalog.md),
  [ADR-0014](./0014-server-assigned-drill-version.md),
  [ADR-0015](./0015-shareable-install-links.md) — the routes that gain a
  namespace segment,
  [ADR-0018](./0018-roleplayer-data-model.md) — the denylist trap this inverts,
  [ADR-0024](./0024-account-and-identity-model.md) — `Account` gains `handle`,
  [ADR-0025](./0025-authorization-and-publish-policy.md) — `accessPolicy` moves
  onto the catalog entry; the fork-keeps-its-name cost is retired,
  [ADR-0060](./0060-remote-mcp-server.md) — catalog tools take a namespaced
  slug,
  [ADR-0072](./0072-staff-pii-and-account-sync.md) — this ADR is the other half
  of its two-artifact statement
* Related designs:
  [DESIGN-015](../design/015-accounts-and-iam.md) §9
* Related code:
  `netlify/functions/lib/shared.js` (`keysFor`, slug-index),
  `netlify/functions/drills-upload.js` (derivation on publish),
  `netlify/functions/deep-link.js` (`/d/` routing),
  `lib/models/plan.dart` (the denylist this replaces)
