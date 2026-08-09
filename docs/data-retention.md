# What RingDrill keeps, and what deletion removes

Written for the GDPR question people actually ask — *after somebody deletes
their account, what is left?* — and kept as a register rather than prose so it
can be checked against the code.

Companion to [ADR-0024](./adrs/0024-account-and-identity-model.md) (the identity
model), [ADR-0072](./adrs/0072-staff-pii-and-account-sync.md) (where a staff
roster may travel) and [DESIGN-015 §5.1](./design/015-accounts-and-iam.md)
(what "delete account" promises). Local, on-device storage is
[ADR-0076](./adrs/0076-local-plan-storage-at-rest.md).

Accurate as of 2026-08-09. `DELETE /api/accounts/:id`, body
`{ "unpublishedPlans": "delete" | "publish" }` (default `delete`).

## Removed on deletion

| What | Where | Contains |
|---|---|---|
| User record | `users/<userId>` | Display name, primary email |
| Provider identities | `identities/<provider>/<subject>` | Provider subject, email |
| Verified-address index | `email-index/<email>` | The address itself |
| Sessions | `sessions/<sessionId>` | Device label, timestamps |
| Memberships in the deleted account | `members/<accountId>/*` | Role, invite state |
| Plans nobody else relies on | `catalog/<entryId>/*`, `slug-index/<accountId>/<slug>` | Plan content and version history |
| The handle, when no plans remain | `handles/<handle>` | The organisation's chosen name |
| Pending rows **in other accounts** | `members/*/pending:<email>` | The address |
| Invitations sent **by** them | `invitations/<token>` | Recipient address |
| Invitations sent **to** them | `invitations/<token>` | Their address |
| The account record | `accounts/<accountId>` | Display name, handle |

The invitation and pending-row entries were retained by oversight until
2026-08-09: invitations live in their own store and pending rows are keyed by
address, so neither was reachable from the account being deleted. Plans nobody
relies on, and the handle when nothing is left under it, were retained by an
over-broad reading of "deleting an account does not unpublish" — corrected the
same day.

## Retained deliberately

Each of these is a decision, not an omission.

### Plans somebody else relies on — and only those

Two kinds are kept, both with `ownerId` set to `anon` and `accessPolicy` forced
to `public`:

* **Published plans.** Other people have installed them. DESIGN-015 §5.1 is
  explicit that deleting an account does not unpublish, and the confirm dialog
  says so before the user commits — "delete my account" reasonably sounds like
  it should unpublish, so saying it afterwards would be too late.
* **Plans shared with named accounts.** A granted account may be co-editing one
  right now, and deleting it would take their work with it.

**Everything else is deleted** — index record and blobs. An unpublished draft
nobody was granted has no third party relying on it, so keeping it would be
retaining somebody's data after they asked for it to be gone. Until 2026-08-09
every entry was kept and made public regardless, which was wrong on both counts.

The user may instead choose to **publish** those plans on the way out, as an
explicit "leave my work to the community". Never the default: publishing has
consequences they will not be around to reverse.

A grantee list does not survive its granter — `sharedAccountIds` is cleared,
because it names accounts granted access by an owner who no longer exists.

**They contain no staff roster.** `stripPiiFolders` removes `staff/` and
`actors/` from the archive at the catalog door, unconditionally, before anything
is stored (ADR-0072). Only `staff/` is written by the app today — `actors/` is
the pre-DESIGN-011 name, kept in the strip list because the **server never runs
the migration ladder**: a `.drill` exported to disk years ago still carries
`actors/`, and those files travel by USB and email, so one can be uploaded at
any point in the future. What a published plan *can* still contain is whatever
somebody typed into a free-text markdown field — a name in `director_notes`, a
phone number in a station description. Nothing strips those, and nothing can
without breaking the format. That is a content risk the authoring guidance
addresses ("never put a real person in any field", "declare an operational value
as a plan variable"), not a deletion one.


### The account id in catalog index keys, for the plans that stay

A retained plan stays at `slug-index/<accountId>/<slug>` with
`ownerAccountId: null` and an `ownerDeletedAt` timestamp.

**Why:** the key is the URL. Rewriting it into `anon/` would change
`/d/<handle>/<slug>` and break every link already shared. The id is a
pseudonymous identifier with nothing left to resolve it to — the account record
is gone.

### The handle — only while something is published under it

`handles/<handle>` survives as `{accountId, tombstone: true, retiredAt}` **when
the account leaves plans behind**. When it leaves none, the handle is deleted
and the name returns to the pool.

**Why the tombstone:** a handle appears in every shared link. Releasing it while
plans are still served through it would let somebody else claim the name and
silently point an already-shared link at a stranger's plan — the same reasoning
that tombstones a *renamed* handle
([ADR-0074](./adrs/0074-catalog-entry-as-distinct-object.md)).

**Why the release:** with nothing left under the namespace, every such link was
going to 404 anyway, so reserving the name reserves it for nobody. This is the
domain-lease behaviour: the name is held only as long as something depends on
it.

**Not personal data in practice.** Only organisations have handles — a personal
account is created with `handle: null` and `claimHandle` is reachable only from
organisation creation. An earlier version of this document raised a personal-
handle concern that cannot occur.

## Retained outside the application

* **Netlify** — request logs and CDN access logs, processor-side, on their
  retention schedule. Contain IP addresses and request paths.
* **Resend** — delivery logs for sign-in and invitation mail, including
  recipient addresses ([ADR-0075](./adrs/0075-mail-provider-adapter.md)).
  Processor-side; US-stored under DPF/SCCs.
* **Sentry** — only with analytics consent, which is **opt-out by default**
  (`main.dart` gates every Sentry call). No plan content is sent.

None of these are reached by `DELETE /api/accounts/:id`. A subject-access or
erasure request that has to cover them is a manual process against each
processor.

## Records that expire rather than being deleted

Two stores hold an email address for somebody who may never have completed
sign-up at all:

| Store | Holds | TTL | Swept by |
|---|---|---|---|
| `auth-challenges/<id>` | Address, code hash | 10 minutes | `POST /api/auth/start-email` |
| `invitations/<token>` | Recipient address, inviter id | 14 days | `POST /api/accounts/:id/members` |

Until 2026-08-09 neither was swept: a record was removed only when somebody
*used* it, so an address typed by a person who then closed the tab stayed
indefinitely — including an address belonging to somebody who never became a
user and so had no account to delete. Both write paths now sweep expired records
first.

The sweep runs on the write path rather than on a schedule, deliberately: at
this volume a scan per sign-in costs nothing, and a sweep that runs whenever the
store is used cannot silently stop the way a cron job can.

## Checking this document

The claims above are pinned by tests, so drift shows up as a failure rather than
as a stale document:

* `netlify/tests/accounts-endpoints.test.mjs` — what deletion removes and
  retains, including the invitation and pending-row sweeps.
* `netlify/tests/drills-upload-strip.test.mjs` and `pii-ingest.test.mjs` — that
  the catalog copy carries no roster.
* `netlify/tests/auth-session.test.mjs` — session tombstones and their expiry.
