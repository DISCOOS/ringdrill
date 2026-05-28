---
status: accepted
date: 2026-05-28
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0025: Authorise catalog writes against Account, with per-plan access policy

## Context and problem statement

[ADR-0024](./0024-account-and-identity-model.md) introduces Account, User
and Identity as a data model. This ADR decides how that model is enforced
on the write path: who may publish, refresh, delete a slug, and how
public-write plans
([ADR-0008](./0008-persistent-program-library-and-catalog.md),
[ADR-0014](./0014-server-assigned-drill-version.md)) coexist with
account-locked plans.

The catalog today is fully open: anyone with the `.drill` file can
publish. That model serves a real use case (publishing a training plan
that anyone can fork and extend) and must continue to work. At the same
time, planners who want protection from unauthorised changes need a
way to get it. The decision has to support both modes side by side.

Requests need to carry identity in a way that works for the CLI, native
mobile and the PWA without reshuffling the existing OCC contract
([ADR-0014](./0014-server-assigned-drill-version.md)).

## Decision drivers

* No silent breakage of existing public plans. Anyone who could publish
  yesterday must still be able to publish today, until the owner
  explicitly tightens the policy.
* New plans default to "protected from strangers". An anonymous third
  party must not be able to overwrite a freshly published plan.
* Account-locked plans can be co-owned without sharing credentials.
  Members with role `editor` or `owner` of the owning Account can
  publish.
* Public-write plans remain a first-class option. Publishing a training
  plan that anyone can fork and extend (or directly edit, in the
  fully-public case) is a legitimate use case in its own right, not a
  backwards-compatibility crutch. The model must keep supporting it
  after accounts land.
* The CLI must keep working in CI and scripted contexts. Replacing
  `RINGDRILL_ADMIN_TOKEN` with personal tokens is acceptable. Replacing
  it with an interactive-only login is not.
* OCC stays as-is. `If-Match` with content etag remains the single
  concurrency gate. Authorisation runs before OCC.
* The trust model from
  [ADR-0019](./0019-roleplayer-participant-role.md) (the server does not
  arbitrate session role) continues to apply: realtime participation is not
  account-gated. Only catalog writes are.
* The PII boundary from
  [ADR-0018](./0018-roleplayer-data-model.md) is unchanged. `actors/` is
  stripped on upload regardless of who uploads.

## Considered options

### For the access model

* **Option A — Per-plan `accessPolicy` sealed class:
  `account | shared | public` (chosen).** Each plan records its policy.
  `account` restricts writes to members of the owning Account.
  `shared` extends writes to additional named accounts via an
  `accountIds` list. `public` keeps the open-collaboration workflow
  (anyone with the file can publish). New authenticated publishes
  default `account`. Plans without an owning account
  (`ownerId="anon"`) default `public`. The sealed-class form carries
  `shared.accountIds` cleanly without a separate ACL table.
* **Option B — Global account-locked, no opt-out.** Every plan is
  bound to its owning Account, no `public` mode. Forces existing wiki
  co-planners to re-organise their workflow.
* **Option C — Per-user ACL.** Each plan stores an explicit list of
  user IDs allowed to write. Most flexible at the user level, but
  duplicates membership information that already lives on Accounts.

### For request authentication

* **Option D — Bearer access token in `Authorization`, opaque signed JWT
  (chosen).** Server validates signature, checks `aud`, `exp`, `userId`,
  `accountId`. No store lookup on the hot path.
* **Option E — Session cookie.** Standard for browser flows. Fails for the
  CLI and for native mobile clients.
* **Option F — HMAC request signing.** Stateless, strong. More client-side
  complexity than the threat model warrants. Reserved as a possible future
  step for service accounts that automate publishes.

### For `public` plans created before accounts existed

* **Option G — Public is permanent, fork to leave (chosen).** A
  `public` plan stays public for as long as its owner keeps it that
  way. A signed-in User who wants protection picks "Fork to my
  account", which produces a fresh local plan with a new `programUuid`
  and no link back to the original slug. Publishing the fork creates
  a new slug under the User's account at `account` policy.
* **Option H — Explicit one-shot adoption.** A signed-in User claims
  ownership of an `anon` slug by re-publishing it with a token. The
  slug-index record gains `adoptedBy: accountId` and the policy flips
  to `account` in place. First adoption wins.
* **Option I — Implicit adoption on next publish.** Any authenticated
  publish to an `anon` slug locks it to the publisher's account.
  Surprising and surreptitious. Easy to trigger accidentally on a plan
  you co-edit but do not own.

## Decision outcome

Chosen options: **A (per-plan accessPolicy)** + **D (Bearer JWT)** +
**G (wiki is permanent, fork to leave)**, applied together.

A wins because keeping `public` as an opt-in matches today's reality
(some plans really do have multiple co-editors sharing the file), and
because `shared` covers cross-account collaboration without inventing a
parallel mechanism when organisations land. B would force existing wiki
workflows to change. C duplicates membership information that already
lives on Accounts.

D wins because a single Bearer header carries the User, the active
Account and the role map in one stateless validation. Cookies (E) do not
fit the CLI or native mobile. HMAC (F) is held for service accounts
later.

G wins because forking is conceptually clean: a `public` plan stays
public, the original collaborators are unaffected, and a User who
wants account protection ends up with their own slug under their own
account. H mutates a public resource in place with no symmetric
"undo", and breaks links other people may already share. I (implicit)
breaks the principle of least surprise, since one accidental publish
silently locks out the co-editors. "Replace from my version" stays a
future follow-up if anyone needs to push a fork back onto the
original public slug.

### Authorisation matrix

Each catalog endpoint runs this check before any business logic:

| Endpoint                  | Required policy + role                                         |
|---------------------------|----------------------------------------------------------------|
| `POST /api/drills/upload` for new slug | Authenticated User. Slug claimed for `activeAccount`. Policy initialised to `account`. |
| `POST /api/drills/upload` to existing slug, policy `account`  | Member of owning Account with role `owner` or `editor`. |
| `POST /api/drills/upload` to existing slug, policy `shared`   | Member of the owning Account OR member of any account in `shared.accountIds`, with role `owner` or `editor` on that account. |
| `POST /api/drills/upload` to existing slug, policy `public`   | Authenticated User OR no token. Backward-compatible with today's flow. |
| `GET /api/market/feed`, `GET /d/:slug`, `GET /api/drills/head/:slug` | Public. Same as today. No authentication. |
| `POST /api/drills/policy` (new)        | `owner` of the owning Account. Changes the plan's `accessPolicy` and the `shared.accountIds` list. |
| `POST /api/accounts/:id/members` (new) | Member of Account with role `owner`. Invites another User as `editor` or `viewer`. |
| `* /api/admin/*`                       | Bearer `ADMIN_TOKEN` (preserved) OR Bearer access token of a User with the `staff` Identity flag (future). |

`accessPolicy` is stored on the existing meta blob
(`drills/<accountId>/<programId>/meta.json`), defaulting to `account` for
new plans and `public` for any plan whose `ownerId` is `"anon"` after
the backfill. The legacy `wiki` value is accepted as an alias for
`public` on read for one release, and rewritten to `public` on next
update.

### Rollout order for the policy variants

`account` and `public` ship together with the policy mechanism itself
(phase 3 in [`../plans/account-rollout.md`](../plans/account-rollout.md)).
`shared` ships with organisation accounts (phase 5), since
cross-account write delegation only has a coherent UI once organisations
exist. The freezed sealed class is defined with all three variants from
day one so the schema does not have to migrate when `shared` lands.
Until then, the server rejects `accessPolicy: shared` writes with 400
to make the gap explicit.

### Token shape

Access token is a compact JWT signed with `EdDSA` (ed25519). Claims:

```
iss = "ringdrill.app"
aud = "ringdrill-api"
sub = "<userId>"
act = "<activeAccountId>"           // active account at sign-in time
acts = ["<accountId>", ...]         // all accounts the user is a member of
roles = { "<accountId>": "owner" }  // role per account
exp = now + 1h
iat = now
jti = "<random>"
```

Refresh tokens are opaque, rotated on every use, and stored server-side
in the `sessions` store from
[ADR-0024](./0024-account-and-identity-model.md). The old refresh token
is invalidated the moment a new one is issued. Replaying an invalidated
token is treated as session compromise and forces re-login.

The signing key is a server-only ed25519 keypair stored in Netlify env
vars (`AUTH_SIGNING_KEY_PRIVATE`, `AUTH_SIGNING_KEY_PUBLIC`). Key
rotation accepts both the current and previous public key during a
rotation window. Clients are not aware.

`act` is settable client-side per request via a `X-Active-Account` header,
which the server validates against `acts`. This avoids re-issuing the
token every time the user switches active account.

### Server-side changes

`netlify/functions/_shared.js` grows an `authenticate(request)` helper that:

1. Reads `Authorization: Bearer <token>`. Returns `{ anonymous: true }`
   when absent.
2. Validates JWT signature, `iss`, `aud`, `exp`. Returns 401 on failure.
3. Reads `X-Active-Account` when present, else the `act` claim.
   Validates against `acts`. Returns 403 on mismatch.
4. Returns `{ userId, accountId, role }` for downstream handlers.

`drills-upload.js` calls `authenticate` first, reads
`meta.accessPolicy`, and applies the matrix above before any write. OCC
(`If-Match` content etag) runs unchanged after the auth gate. The legacy
`ownerId` query parameter is accepted for one release cycle as a no-op
for unauthenticated wiki uploads.

`drills-admin.js` keeps the `ADMIN_TOKEN` Bearer path and adds a second
path: a User access token where the User has a `staff: true` flag (set
manually via blob edit until a self-service path exists). This lets us
issue and revoke per-staff personal tokens without touching the CLI.

Two new endpoints land in this ADR:

* `POST /api/drills/policy?slug=<slug>` with body `{ accessPolicy }`.
  Owner-only. Mutates `meta.accessPolicy`.
* `GET /api/auth/me`. Returns the User, the list of Accounts and the
  current active Account. Used by the client to populate the drawer.

`POST /api/auth/start-email`, `POST /api/auth/callback` and
`POST /api/auth/refresh` round out the surface and are detailed in
[`../plans/account-rollout.md`](../plans/account-rollout.md).

### Client-side changes

`DrillClient.upload` loses its `ownerId` parameter and gains
`accessToken` (optional) and `activeAccountId` (optional). When both are
absent, the request is anonymous and the server applies the wiki branch.

`ProgramService.publishProgram` reads the access token from
`AuthService` (new) and passes it through. `setOwnsCatalogSlug` is
removed in favour of trusting the server response: a successful publish
to an `account`-policy slug means the active Account owns it. The
client mirrors `meta.accessPolicy` into `ProgramSource.catalog` so the
UI can render the right indicator.

`AccessPolicy` is itself a freezed sealed class:

```dart
@freezed
sealed class AccessPolicy with _$AccessPolicy {
  const factory AccessPolicy.account() = _Account;
  const factory AccessPolicy.shared({
    @Default(<String>[]) List<String> accountIds,
  }) = _Shared;
  const factory AccessPolicy.public() = _Public;

  factory AccessPolicy.fromJson(Map<String, dynamic> json) =>
      _$AccessPolicyFromJson(json);
}
```

`ProgramSource.catalog` is extended:

```dart
const factory ProgramSource.catalog({
  required String slug,
  required String latestEtag,
  DateTime? installedAt,
  @Default(AccessPolicy.public()) AccessPolicy policy,   // new
  String? ownerAccountId,                                // new
}) = _Catalog;
```

`make build` is required after this change. The migration path is "treat
absent `policy` as `public`" (matching today's wiki-style reality), and
"treat serialized `wiki` as `public`" for one release.

The UI surfaces policy in two places: an icon next to the slug in
Library (account, shared and globe), and a "Tilgang" / "Access" section
in the publish dialog where the owner can switch between `account` and
`public`. The `shared` variant is hidden until phase 5.

### Relation to today's conflict resolution

The concurrent-edit handling from
[ADR-0008](./0008-persistent-program-library-and-catalog.md) and
[ADR-0014](./0014-server-assigned-drill-version.md) is unchanged. OCC
via content etag (`If-Match`), the `ProgramDiff` shown before any
overwrite, and the three user choices (Cancel, Overwrite local, Publish
my changes / Fork) apply regardless of `accessPolicy`. The new model
reduces the set of people who can trigger a collision but does not
change what happens when one occurs.

### Fork flow for `public` plans

Signed-in Users who want their own protected copy of a `public` plan
use "Fork to my account" from the plan's Library row. This reuses the
existing `forkAsLocal` branch from `ProgramService.refreshCatalogItem`
([ADR-0008](./0008-persistent-program-library-and-catalog.md)):

1. The local plan is duplicated with a new `programUuid` and a
   `(kopi)`-suffixed name. Source becomes `ProgramSource.local()`. The
   fork carries no reference to the original slug.
2. The original `public` plan in Library is untouched. Co-editors still
   share that slug.
3. When the User publishes the fork, the server allocates a new slug
   under their active Account at `accessPolicy = AccessPolicy.account()`.
   The publish path is the standard new-slug case, no special endpoint.

No server-side adoption endpoint is added. No `slug-index` rewrite. No
`anon`-to-account copy step. The `public` plan keeps its slug for its
co-editors, the User gets a clean account-owned copy under their own
identity.

A future "replace from my version" feature can let the User push a
fork's content back onto the original `public` slug if they still have
write access. That stays a separate decision and a separate PR.

### Wiki opt-in for new plans

New plans can opt into `public` from the publish dialog under "Avansert"
/ "Advanced". The choice is visible and reversible. Any later publish
from the owner can flip it back to `account`.

### Realtime sessions

Realtime sessions ([ADR-0009](./0009-realtime-transport-and-session-model.md)),
position sharing ([ADR-0012](./0012-position-sharing-and-team-aggregation.md))
and synchronized exercise control
([ADR-0011](./0011-synchronized-exercise-control.md)) are unchanged. The
server does not authenticate session joins.

### Consequences

* Good: Existing `public` plans keep working without account creation,
  and remain a supported policy choice for new plans. The protective
  path (`account`) is opt-in, not forced.
* Good: New plans are protected by default. The most common ask
  ("nobody changes my plan without me knowing") works without any user
  action beyond signing in.
* Good: One enforcement layer covers `account`, `shared` and `public`.
  Avoids a growing set of one-off flags.
* Good: Conflict resolution from ADR-0008 / ADR-0014 (OCC, ProgramDiff,
  user choice on overwrite) carries over unchanged. The account model
  reduces the number of writers but reuses the same collision pipeline.
* Good: OCC contract from [ADR-0014](./0014-server-assigned-drill-version.md)
  is unchanged. Existing tests against `If-Match` still apply.
* Good: The CLI keeps an `ADMIN_TOKEN` path during transition and gains a
  per-User token path afterwards. No big-bang migration of automated
  publishes.
* Bad: The JWT signing keypair is a new operational secret. Rotation
  procedure must be documented before first production use.
* Bad: `setOwnsCatalogSlug` and the `app:catalogOwnership:<slug>` flag
  are removed. Existing reads must derive ownership from
  `ProgramSource.catalog.ownerAccountId`.
* Bad: Adding `accessPolicy` to `ProgramSource.catalog` is a freezed
  schema change. Schema 1.0–1.2 archives default to `public` on read.
* Bad: Users who want to "own" a `public` plan they collaborated on
  must fork to a new slug. The original public slug stays addressable
  forever, even when its last co-editor has moved on.

## Pros and cons of the options

### A. Per-plan `accessPolicy` enum (chosen)

* Good: Two named states with clear rules. UI maps each to one icon.
* Good: Enum (not bool) leaves room for `serviceAccounts` or similar
  later without a schema bump.
* Bad: Need to track policy on `meta.json` and mirror it on the client.

### B. Global account-lock, no opt-out

* Good: Simplest server logic.
* Bad: Breaks existing wiki workflows. The `project_catalog_wiki_model`
  memory explicitly warns against this.

### C. ACL per plan

* Good: Maximum flexibility.
* Bad: Heaviest metadata. No demand to justify the cost.

### D. Bearer JWT (chosen)

* Good: One header, stateless validation, works for CLI and mobile.
* Good: Carries multi-account info. No second hop to discover roles.
* Bad: JWT has sharp edges. Signing-key management has to be taken
  seriously.

### E. Cookies

* Good: Native browser ergonomics.
* Bad: CLI and native mobile are not cookie-shaped.

### F. HMAC request signing

* Good: Strong and stateless. No shared signing key on the client.
* Bad: More client complexity than the threat model justifies. Held for
  service accounts later.

### G. Wiki is permanent, fork to leave (chosen)

* Good: No server-side adoption mechanism, no `slug-index` rewrites,
  no `anon`-to-account copy step.
* Good: Public plans keep their slug forever. Co-editors who share the
  link never see it break, and publishing a `public` plan stays a
  first-class workflow.
* Good: Reuses the existing `forkAsLocal` branch from ADR-0008.
* Bad: Users who collaborated on a `public` plan and want their own
  protected version end up with a new slug, not the original one.

### H. Explicit one-shot adoption

* Good: User-initiated. Idempotent and safe to retry.
* Bad: Mutates a public resource in place. Co-editors of the same
  slug lose write access overnight.
* Bad: Needs a new server endpoint and a copy-then-delete migration of
  the underlying blobs, with a GC pass to clean up.

### I. Implicit adoption on next publish

* Good: Zero new UI.
* Bad: A casual publish by a `public`-plan co-editor silently locks
  the plan to their account.

## Links

* Related ADRs:
  [ADR-0008](./0008-persistent-program-library-and-catalog.md),
  [ADR-0009](./0009-realtime-transport-and-session-model.md),
  [ADR-0011](./0011-synchronized-exercise-control.md),
  [ADR-0014](./0014-server-assigned-drill-version.md),
  [ADR-0015](./0015-shareable-install-links.md),
  [ADR-0018](./0018-roleplayer-data-model.md),
  [ADR-0024](./0024-account-and-identity-model.md)
* Related code:
  `netlify/functions/_shared.js` (new `authenticate` helper),
  `netlify/functions/drills-upload.js` (auth + policy enforcement),
  `netlify/functions/drills-admin.js` (token + staff flag),
  `lib/data/drill_client.dart` (drop `ownerId`, add `accessToken`),
  `lib/services/program_service.dart` (publish flow reads `AuthService`),
  `lib/models/program.dart` (`ProgramSource.catalog` extension),
  `lib/data/program_repository.dart` (drop `ownsCatalogSlug` after migration)
* External references: JWT best current practices (RFC 8725), OAuth 2.1
  refresh-token rotation.
