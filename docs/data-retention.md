# What RingDrill keeps, and what deletion removes

Written for the GDPR question people actually ask — *after somebody deletes
their account, what is left?* — and kept as a register rather than prose so it
can be checked against the code.

Companion to [ADR-0024](./adrs/0024-account-and-identity-model.md) (the identity
model), [ADR-0072](./adrs/0072-staff-pii-and-account-sync.md) (where a staff
roster may travel) and [DESIGN-015 §5.1](./design/015-accounts-and-iam.md)
(what "delete account" promises). Local, on-device storage is
[ADR-0076](./adrs/0076-local-plan-storage-at-rest.md).

Accurate as of 2026-08-09. `DELETE /api/accounts/:id`.

## Removed on deletion

| What | Where | Contains |
|---|---|---|
| User record | `users/<userId>` | Display name, primary email |
| Provider identities | `identities/<provider>/<subject>` | Provider subject, email |
| Verified-address index | `email-index/<email>` | The address itself |
| Sessions | `sessions/<sessionId>` | Device label, timestamps |
| Memberships in the deleted account | `members/<accountId>/*` | Role, invite state |
| Pending rows **in other accounts** | `members/*/pending:<email>` | The address |
| Invitations sent **by** them | `invitations/<token>` | Recipient address |
| Invitations sent **to** them | `invitations/<token>` | Their address |
| The account record | `accounts/<accountId>` | Display name, handle |

The last three were retained by oversight until 2026-08-09 — invitations live
in their own store and pending rows are keyed by address, so neither was
reachable from the account being deleted. Both are now swept.

## Retained deliberately

Each of these is a decision, not an omission.

### The handle, as a tombstone

`handles/<handle>` survives as `{accountId, tombstone: true, retiredAt}`, and
the handle string itself is kept.

**Why:** a handle appears in every shared link — `/d/<handle>/<slug>`. Releasing
it would let somebody else claim it and silently point an already-shared link at
a stranger's plan, which is the same reasoning that tombstones a *renamed*
handle ([ADR-0074](./adrs/0074-catalog-entry-as-distinct-object.md)).

**Personal-data note:** for an organisation a handle is a group name. For a
**personal** account a user may have chosen something identifying, and that
string is then retained indefinitely. Two things bound the exposure: a personal
account has no handle unless the user set one, and the tombstone no longer
resolves for sharing — `GET /api/accounts/lookup` returns 404 once the account
is gone. **Open question:** whether a personal account's handle should be
replaced with an opaque token on deletion, keeping the redirect without keeping
the name. It would work; nobody has asked for it yet.

### The account id in catalog index keys

A published plan stays at `slug-index/<accountId>/<slug>` with
`ownerAccountId: null` and an `ownerDeletedAt` timestamp.

**Why:** the key is the URL. Rewriting it into `anon/` would change
`/d/<handle>/<slug>` and break every link already shared. The id is a
pseudonymous identifier with nothing left to resolve it to — the account record
is gone.

### Published plans and their version history

Kept, with `ownerId` set to `anon` and `accessPolicy` forced to `public`.

**Why:** other people have installed them. DESIGN-015 §5.1 is explicit that
deleting an account does not unpublish, and the confirm dialog says so before
the user commits — "delete my account" reasonably sounds like it should
unpublish, so saying it afterwards would be too late.

**They contain no staff roster.** `stripPiiFolders` removes `staff/` and
`actors/` from the archive at the catalog door, unconditionally, before anything
is stored (ADR-0072). What a published plan *can* still contain is whatever
somebody typed into a free-text markdown field — a name in `director_notes`, a
phone number in a station description. Nothing strips those, and nothing can
without breaking the format. That is a content risk the authoring guidance
addresses ("never put a real person in any field", "declare an operational value
as a plan variable"), not a deletion one.

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
