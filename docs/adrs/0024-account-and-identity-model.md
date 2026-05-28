---
status: accepted
date: 2026-05-28
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0024: Introduce Account, User and Identity as separate entities

## Context and problem statement

RingDrill has no concept of "who owns a plan". The catalog uses a wiki
ownership model ([ADR-0008](./0008-persistent-program-library-and-catalog.md),
[ADR-0014](./0014-server-assigned-drill-version.md)): any holder of a `.drill`
file can publish updates to the slug it claims. The server records
`ownerId = "anon"` for every upload, the client guesses ownership locally via
the `app:catalogOwnership:<slug>` flag, and the only real authentication is
the shared `ADMIN_TOKEN` secret on `/api/admin`.

That model does not scale once planners want protection from unauthorised
changes. A protective model needs a stable principal that can sign requests,
survive device reinstalls, and be granted to more than one person on the
same plan. The actor/PII boundary
([ADR-0018](./0018-roleplayer-data-model.md)) already implies an account-like
notion ("the owner's device"), but cannot carry it across devices.

This ADR decides the data model only: which entities exist and how
identity-provider sign-ins map onto them. The authorisation rules live in
[ADR-0025](./0025-authorization-and-publish-policy.md).

## Decision drivers

* A plan can be co-owned. Two coordinators in the same SAR team must be able
  to publish updates to the same plan without sharing credentials.
* A person can sign in with more than one provider. Email magic link on the
  Mac, Sign in with Apple on the iPhone, possibly Feide later. All three
  must resolve to the same User.
* Offline-first. The Flutter app, the CLI and the PWA all run without a
  network round-trip for read-only work. Sign-in is required only to publish
  to the catalog, not to plan locally.
* No new state-management library ([ADR-0004](./0004-no-third-party-state-management.md))
  and no new persistence engine if we can avoid it. The existing Netlify
  Blobs store is sufficient for the volumes we expect.
* The PII boundary from [ADR-0018](./0018-roleplayer-data-model.md) must
  hold. Account/identity records are themselves PII (email, name) and must
  never leak into published `.drill` archives.
* Apple Sign In and Google Sign In ship together. Each is the obvious
  default on its platform (Apple on iOS/macOS, Google on Android). App
  Store guideline 4.8 also requires Apple parity as soon as any other
  social provider is offered, which Google triggers.

## Considered options

### A. Single `User` entity with embedded identities and no `Account`

Each User owns their own plans directly. Sharing is implemented by listing
multiple `userId`s on a plan. A future "organisation" lives outside the
identity layer if it ever becomes necessary.

### B. `Account` and `User` as the same entity, with multiple identities

The thing that owns a plan and the thing that logs in are the same object.
"Sharing" is multiple identities on one Account. There is no separate
"member" concept.

### C. Three entities: `Account`, `User`, `Identity` (chosen)

A plan is owned by an Account. An Account has zero or more Members,
each a (User, role) pair. A User can be a Member of several Accounts.
A User has one or more Identities, where an Identity is one provider login.
Provider linking happens via verified email match.

### D. Defer the model entirely and use an external identity-as-a-service

Adopt Auth0, Clerk, Stytch or Supabase. They give us Account+User+Identity
out of the box, plus magic links, OIDC and passkeys. We just call their SDK.

## Decision outcome

Chosen option: **C. Three entities: Account, User, Identity**, because it is
the smallest model that supports (a) co-ownership without credential
sharing, (b) multi-provider sign-in resolving to one person, and
(c) "personal" and "organisation" plans without forcing one to mimic the
other. Options A and B both collapse two of those needs into the same
field and force later refactors to recover the distinction. Option D
adds a vendor dependency the project has otherwise avoided
([ADR-0004](./0004-no-third-party-state-management.md) is about state,
but the same conservatism applies). The auth surface we need is small
enough that hosting it in Netlify Functions is cheaper than the
integration cost.

### Entities

```dart
@freezed
sealed class Account with _$Account {
  const factory Account({
    required String id,                 // "a_" + nanoid(12)
    required String displayName,
    required AccountType type,          // personal | organization
    required DateTime createdAt,
  }) = _Account;
}

@freezed
sealed class User with _$User {
  const factory User({
    required String id,                 // "u_" + nanoid(12)
    required String displayName,
    required String primaryEmail,       // verified
    required DateTime createdAt,
  }) = _User;
}

@freezed
sealed class Identity with _$Identity {
  const factory Identity({
    required String userId,
    required IdentityProvider provider, // email | apple | google | feide
    required String subject,            // provider-side stable ID
    required String email,              // for display; primaryEmail wins on conflict
    required DateTime addedAt,
  }) = _Identity;
}

@freezed
sealed class Member with _$Member {
  const factory Member({
    required String accountId,
    required String userId,
    required MemberRole role,           // owner | editor | viewer
    DateTime? invitedAt,
    required DateTime acceptedAt,
  }) = _Member;
}
```

`AccountType.personal` accounts have exactly one Member with role
`owner`, created automatically on first sign-up. Inviting a second person
upgrades the account to `organization` after explicit user confirmation.

`AccountType.organization` accounts are created explicitly via "Create
organisation" in the UI. They may have any number of members, and at
least one must hold role `owner` at all times.

### Identity linking

When a User signs in with a provider for the first time, the backend:

1. Looks up the Identity by `(provider, subject)`. If found, returns its User.
2. Otherwise looks up an existing User by verified `email`. If found, the new
   Identity is linked to that User. The User is informed on next sign-in that
   a new provider was linked.
3. Otherwise creates a new User and a new personal Account, with the new
   Identity attached.

Linking by email match requires the new provider to mark the email
verified. Apple's "Hide my email" relay counts as verified, OIDC providers
must return `email_verified`. Unverified emails create a separate User and
offer manual linking later.

### Provider catalogue

Initial allowlist at first ship: `email`, `apple`, `google`. Apple and
Google ship together so each platform has its native provider from day
one. `feide` and `bankid` are reserved for later if demand from schools
or HRS partners materialises. New providers need only a server-side
adapter and a login-UI entry, no model change.

### Storage layout (Netlify Blobs)

Three new stores alongside the existing `drills` and `slug-index` stores
([`_shared.js`](../../netlify/functions/_shared.js)):

| Store          | Key                     | Value                                |
|----------------|-------------------------|--------------------------------------|
| `accounts`     | `<accountId>`           | `Account` JSON                       |
| `users`        | `<userId>`              | `User` JSON                          |
| `identities`   | `<provider>/<subject>`  | `{ userId, email, addedAt }`         |
| `members`      | `<accountId>/<userId>`  | `{ role, acceptedAt, invitedAt? }`   |
| `email-index`  | `<lowercased-email>`    | `{ userId }`                         |
| `sessions`     | `<sessionId>`           | `{ userId, expiresAt, deviceLabel }` |

`email-index` carries the verified-email-to-userId mapping that identity
linking depends on. `sessions` holds refresh-token state. Access tokens are
signed JWTs and need no store lookup on the hot path. Token shape and
rotation are in [ADR-0025](./0025-authorization-and-publish-policy.md).

### Client-side cache

The Flutter app keeps a minimal mirror of the signed-in User and the list
of Accounts that User belongs to. Tokens go in `flutter_secure_storage`,
which maps to the OS keychain (iOS/macOS), Keystore (Android), DPAPI
(Windows) and libsecret (Linux). Non-sensitive mirror values stay in
`SharedPreferences` alongside the rest of the app's state.

```
flutter_secure_storage:
  ringdrill.auth.accessToken    opaque, short-lived
  ringdrill.auth.refreshToken   opaque, rotated on use

SharedPreferences (app:auth:v1 namespace):
  user                          User JSON (id, displayName, primaryEmail)
  accounts                      List<Account> JSON
  activeAccount                 accountId currently selected for publishing
```

Splitting the two stores keeps the refresh token in OS-protected storage
without forcing every read of the User mirror through an async secure
call. The User and Accounts lists are not sensitive in the same sense —
both are re-fetchable from `/api/auth/me` at any time.

On web, `flutter_secure_storage` falls back to an AES-encrypted IndexedDB
entry whose key lives in `sessionStorage`. That is weaker than the native
backends, but no worse than what we have today and inside the PWA's same-
origin sandbox.

The active-account selector lives in the app drawer below the User name,
hidden when the User has only one Account.

### CLI

`bin/ringdrill.dart` gains a `login` subcommand that performs the email
magic-link flow in a terminal-friendly way (paste the link, or open it in
the browser when stdout is a TTY). The resulting refresh token is stored in
`$XDG_CONFIG_HOME/ringdrill/credentials.json` (or the platform equivalent),
and the existing `RINGDRILL_ADMIN_TOKEN` is preserved as a legacy fallback.
The CLI keeps no Flutter imports ([ADR-0005](./0005-cli-must-remain-flutter-free.md)).

### Scope boundary

Authorisation rules, token format and rotation are in
[ADR-0025](./0025-authorization-and-publish-policy.md). Rollout order
and feature flags are in
[`../plans/account-rollout.md`](../plans/account-rollout.md). Passkeys
are deferred and fit the model as another Identity provider without
schema changes.

### Consequences

* Good: Co-ownership and multi-provider sign-in fit in one model. No later
  refactor to split User from Account when organisations land.
* Good: The PII boundary holds. Identities and members live in separate
  stores from drill content. `drills-upload.js` keeps stripping `actors/`
  regardless of who uploaded.
* Good: Personal accounts are created automatically. A single planner sees
  no account-management UI.
* Good: Adding Apple, Google or Feide later is one adapter, not a model
  change.
* Good: Refresh tokens land in OS keychain/keystore via
  `flutter_secure_storage`, not in plain-text SharedPreferences.
* Bad: Three entities plus members plus email-index is more moving parts
  than today. Wrong-state combinations (Member without Account, Identity
  without User) become representable and need repository invariants.
* Bad: Magic-link email is a new vendor dependency (Resend or SES) and a
  new sign-in failure mode.
* Bad: Apple's "Hide my email" relay survives at the provider but does not
  receive outbound mail from arbitrary senders. Reset flows on Apple-relay
  accounts depend on the relay, which is out of our control.
* Bad: `flutter_secure_storage`'s web backend (encrypted IndexedDB) is
  weaker than the native keychain backends. Acceptable inside the PWA
  same-origin sandbox, but worth flagging.

## Pros and cons of the options

### A. Single User entity

* Good: Simplest model, no Account concept to design.
* Good: Personal-only users never see an Account abstraction.
* Bad: Co-ownership becomes ad-hoc userId lists per plan, roles end up
  on the plan instead of the principal, and invite/revoke has to be
  reimplemented at every endpoint.
* Bad: A future "organisation" has nowhere to attach without a retrofit.

### B. Account and User merged

* Good: Two entities (the merged Account/User, plus Identity). Smaller
  surface than C.
* Good: Login resolves to an Account in one hop.
* Bad: Multi-account membership is impossible without splitting them back
  out. A planner who also helps the local Red Cross cannot act as
  themselves and as the organisation.
* Bad: Service accounts (the eventual replacement for ADMIN_TOKEN) do not
  fit cleanly, because a service account is not a person.

### C. Account + User + Identity (chosen)

* Good: One entity per concern, refactors stay local.
* Good: Apple, Google, email and Feide all land on the same pattern.
* Good: Service accounts fit as `AccountType.service` (future) without
  inventing a new entity.
* Bad: Most schema for a fresh use case, over-engineered for a single
  planner with no co-owners.

### D. Identity-as-a-service vendor

* Good: Zero implementation effort. Magic links, OIDC, MFA and passkeys
  out of the box.
* Bad: Vendor lock-in. Auth0 has a long history of pricing changes,
  Clerk's free tier is fine today but defines a hard ceiling.
* Bad: User and Account data live in the vendor, not in our backend.
  Wiki adoption flows would still need our DB.
* Bad: Forces a third-party SDK into the Flutter app. Conditional imports
  for web vs mobile become harder, and PWA bundles grow.

## Links

* Related ADRs:
  [ADR-0004](./0004-no-third-party-state-management.md),
  [ADR-0006](./0006-sentry-behind-consent-gate.md),
  [ADR-0007](./0007-drill-file-format.md),
  [ADR-0008](./0008-persistent-program-library-and-catalog.md),
  [ADR-0014](./0014-server-assigned-drill-version.md),
  [ADR-0018](./0018-roleplayer-data-model.md),
  [ADR-0025](./0025-authorization-and-publish-policy.md)
* Related code:
  `netlify/functions/_shared.js` (stores to extend),
  `netlify/functions/drills-upload.js` (today's `ownerId="anon"` default),
  `netlify/functions/drills-admin.js` (today's ADMIN_TOKEN),
  `lib/data/drill_client.dart` (today's `ownerId` parameter),
  `lib/services/program_service.dart` (publish flow),
  `lib/data/program_repository.dart` (`ownsCatalogSlug` flag),
  `bin/ringdrill.dart` (CLI auth, `RINGDRILL_ADMIN_TOKEN`)
* External references: App Store Review Guideline 4.8 (Sign in with Apple
  parity), OIDC `email_verified` semantics.
