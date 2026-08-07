# Account rollout plan

Companion document to [ADR-0024](../adrs/0024-account-and-identity-model.md)
and [ADR-0025](../adrs/0025-authorization-and-publish-policy.md). The ADRs
decide the data model and the authorisation rules. This document sequences
the work, names the feature flags, and lists the migration steps.

Status: approved. ADR-0024 and ADR-0025 are accepted as of 2026-05-28.
This document tracks the rollout against those decisions.

> **Revised 2026-08-04, before phase 1 starts.** Nothing had been
> implemented, and four decisions accepted after this plan was first written
> changed what it should say:
>
> * **[ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md)**
>   (2026-06-29) chose *compile-time* `dart-define` flags in
>   [`app_flags.dart`](../../lib/utils/app_flags.dart) and explicitly rejected
>   a runtime flag service. The six-runtime-flag table this plan carried was
>   exactly what that ADR declined to build. See "Feature flags" below, now
>   one client flag and two server env vars.
> * **[ADR-0059](../adrs/0059-drill-schema-migration-ladder.md)** established
>   that additive fields land without a schema bump. The schema 1.3 bump in
>   phase 2 is withdrawn.
> * **[ADR-0060](../adrs/0060-remote-mcp-server.md)** shipped a hosted MCP
>   endpoint that is unauthenticated *because* it cannot publish. It is now a
>   downstream consumer of this rollout — see "Downstream consumers".
> * **[ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)** (2026-08-04)
>   answered the staff-PII question that used to sit open at the bottom of
>   this file. A roster does belong inside the account that owns the plan;
>   the catalog stays stripped unconditionally. Roster sync needs a private
>   store and an authenticated read path that do not exist yet, so it lands
>   after phase 5 as its own work rather than inside a phase here.
>
> Code references throughout were also refreshed for the Program→Plan rename
> ([ADR-0055](../adrs/0055-programid-planid-wire-back-compat.md)).

## Goals

1. Protect published plans from changes by people who are not on the
   owning Account.
2. Do not break any existing `public` plan during transition. `public`
   stays a supported policy after accounts land, not just a holdover.
3. Keep offline planning unaffected: sign-in is required only to publish,
   not to plan locally.
4. Keep the CLI usable in CI throughout the rollout. `ADMIN_TOKEN` is
   accepted until phase 6.

## Non-goals

* Passkeys / WebAuthn. Reserved for a later iteration.
* Per-station or per-exercise access controls inside a plan. The unit of
  protection is the slug.
* Login walls on public reads. `/api/market/feed` and `/d/:slug` remain
  public.
* Roster sync. A plan's `staff/` folder *does* belong in the scope of the
  account that owns it
  ([ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)) — that is most of
  why a co-owner wants the shared plan — but it needs a private store, an
  authenticated read path that projects per reader, and a privacy statement,
  none of which exist. It lands after phase 5, on its own, against
  ADR-0072's entry criteria. The six phases below are about authorising
  *catalog writes*, where the strip stays unconditional and at write time.

An earlier draft listed "secure refresh-token storage beyond
`SharedPreferences`" as a non-goal. That is wrong against
[ADR-0024](../adrs/0024-account-and-identity-model.md), which puts both
tokens in `flutter_secure_storage` from phase 2 and keeps only the
non-sensitive mirror in `SharedPreferences`.

## Phases

Each phase is a separate release. A phase can be paused, reverted, or
extended without forcing the next one.

### Phase 1 — Backend identity foundation

Server-only. No client UI change. Goal: stand up the auth surface and
seed the data model.

* Add `accounts`, `users`, `identities`, `members`, `email-index` and
  `sessions` stores in `netlify/functions/lib/shared.js`.
* Implement `POST /api/auth/start-email`, `POST /api/auth/callback`,
  `POST /api/auth/refresh`, `POST /api/auth/logout`, `GET /api/auth/me`.
* Magic link via Resend or SES. Sender domain: `noreply@ringdrill.app`.
  Templates in `netlify/functions/_email/`.
* Implement JWT signing (ed25519) with `AUTH_SIGNING_KEY_PRIVATE` and
  `AUTH_SIGNING_KEY_PUBLIC` Netlify env vars.
* Implement `authenticate(request)` helper that classifies a request as
  anonymous, authenticated, or invalid (401). No endpoint enforces yet.
* `accessPolicy` already reaches `meta.json` via
  `resolvePublishPolicy` ([ADR-0040](../adrs/0040-catalog-feed-schema-extension.md)),
  derived from `ownerId`. It stays **descriptive** through phases 1–2:
  nothing reads it to decide anything until phase 3. Accept serialized
  `wiki` as an alias on read for one release, since the serialized name is
  being renamed.
* Move the PII strip from `drills-upload.js`'s call site into the shared
  ingest path, so every catalog-bound function that reads archive bytes goes
  through it, and add the test that enumerates those functions
  ([ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)). Phase 1 is where
  a second server-side write path first becomes plausible, and the catalog
  rule has to be structural before that path exists.
* Telemetry: log per-endpoint counts of `anonymous` vs `authenticated`
  uploads, behind the existing Sentry consent gate
  ([ADR-0006](../adrs/0006-sentry-behind-consent-gate.md)).

Exit criteria: a curl-driven sign-up + publish round-trip works in
`make netlify-dev`. No client release.

**Known gap this phase does not close.** `ownerId` is a caller-supplied
query parameter, and the feed publishes it as `author`, so anyone can read
an owner off the public feed and pass it back to write to that slug. That is
the pre-accounts wiki model working as designed
([ADR-0008](../adrs/0008-persistent-program-library-and-catalog.md)) and it
stays open until phase 3 enforces policy. What must not happen meanwhile is
the *feed* implying otherwise — see phase 3's first bullet.

### Phase 2 — Client sign-in (no enforcement)

Client UI lands. Goal: let users sign in and link providers, without
changing publish behaviour.

* New `AuthService` (singleton, framework-free). Tokens persist in
  `flutter_secure_storage` (`ringdrill.auth.accessToken`,
  `ringdrill.auth.refreshToken`). Non-sensitive mirror values (user,
  accounts list, activeAccount) stay in SharedPreferences under
  `app:auth:v1:*`.
* New routes `/auth/login`, `/auth/callback`. Default cold-start route
  still `/library`.
* New "Logg inn" / "Sign in" tile in the app drawer above "Settings".
  Anonymous users see a one-line "Logg inn for å sikre planene dine"
  hint at the top of Library.
* Implement Sign in with Apple on iOS and macOS, Sign in with Google on
  Android and web. Email magic link on all platforms. Apple and Google
  ship in the same release so each platform has its native provider
  from day one.
* Publish flow sends the access token when present and `accessToken=null`
  otherwise. Server accepts both. No new restrictions yet.
* Add `policy` and `ownerAccountId` to `PlanSource.catalog`, defaulting to
  `AccessPolicy.public()` / `null` for read compatibility. **No schema
  bump** — both are additive, and `source` is excluded from
  `Plan.computeContentHash`, so an older reader that drops them is not
  "ahead of remote"
  ([ADR-0059](../adrs/0059-drill-schema-migration-ladder.md)). `make build`
  is still required.

Exit criteria: a signed-in user can publish and refresh without seeing
a different result than today.

### Phase 3 — Per-plan policy UI and fork-to-account

Goal: give users a path from wiki to a protected own-copy, without
mutating any existing slug.

* **`accessPolicy` becomes enforced.** `drills-upload.js` reads
  `meta.accessPolicy` and applies ADR-0025's authorisation matrix before
  OCC. This is the phase where the field stops being a label and starts
  being a gate, so it is also where the "descriptive only" notes added in
  phase 1 (`shared.js`, `drill_client.dart`, `api.md`) come out.
* Implement `POST /api/drills/policy?slug=<slug>` for owners to flip
  between `account` and `public`. UI lives in publish dialog under
  "Tilgang" / "Access". The `shared` variant is server-rejected with
  400 in this phase and surfaced in phase 5.
* Surface policy in Library: account icon for `account`, globe icon
  for `public`. A people-with-link icon is reserved for `shared` and
  unused until phase 5.
* "Fork to my account" button on `public` plans in Library. Reuses
  the existing `forkAsLocal` branch in `PlanService` to produce a
  new local plan with a `(kopi)`-suffixed name. The original slug
  stays untouched. Publishing the fork goes through the standard
  new-slug path.
* Client mirrors `ownerAccountId` and `policy` into
  `PlanSource.catalog` from upload responses.

Exit criteria: an owner can change a plan's policy between `account`
and `public` and have the change enforced. A user who collaborated on
a `public` plan can fork it to their account, publish the fork at a
new slug, and the original `public` slug remains writable by its
co-editors.

### Phase 4 — Default `account` for new slugs

Goal: flip the default for new plans without changing existing ones.

* `drills-upload.js` initialises new slug records with
  `accessPolicy: AccessPolicy.account()` when the requester is
  authenticated, and `accessPolicy: AccessPolicy.public()` only for
  legacy `ownerId="anon"` writes.
* Publish dialog gets an "Advanced → make this plan public" toggle
  for users who deliberately want anyone-can-edit behaviour on a new
  plan (e.g. a shared training plan for a community).

Exit criteria: a freshly published plan from a signed-in user cannot
be overwritten by a stranger. Existing `public` plans behave unchanged,
and new plans can still opt into `public` deliberately.

### Phase 5 — Organisations, members and cross-account sharing

Goal: enable co-ownership of plans by named people, and cross-account
delegation through the `shared` policy.

* Implement `POST /api/accounts` for "Create organisation".
* Implement `POST /api/accounts/:id/members` and
  `DELETE /api/accounts/:id/members/:userId` (owner-only).
* Account switcher in the drawer (`X-Active-Account` header on
  requests).
* Inviting a user by email creates a Member with role `pending` until
  the invitee signs in and accepts. Acceptance fills `acceptedAt`.
* Member-management UI under Settings → "Konto" / "Account".
* Enable `AccessPolicy.shared`. Server stops rejecting it with 400.
  Publish dialog gains a "Del med andre kontoer" / "Share with other
  accounts" picker that edits `shared.accountIds`. Library surfaces
  the shared icon.

Exit criteria: two signed-in users in the same organisation can both
publish to a plan. A third user outside the organisation cannot. A
plan owner can grant write access to another Account via `shared`,
and a member of that other Account can publish updates to the plan.

### Phase 6 — CLI personal tokens, ADMIN_TOKEN deprecation

Goal: replace the shared admin secret with per-person admin tokens.

* `ringdrill login` runs the magic-link flow over the terminal.
* `ringdrill list-all` and friends use the personal access token.
* `admin: true` flag on User records gates the admin endpoints. Named
  `admin`, not `staff`, so it cannot be confused with the `Staff` roster
  entity or the `staff/` PII folder (ADR-0025).
* `ADMIN_TOKEN` accepted for one full release cycle after the CLI gains
  personal tokens, then removed from `drills-admin.js`.

Exit criteria: production admin operations no longer require
`ADMIN_TOKEN` and no script in the repo references it.

## Feature flags

[ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md) chose
**compile-time** `dart-define` flags, collected in
[`app_flags.dart`](../../lib/utils/app_flags.dart) and documented in
[`feature-flags.md`](../feature-flags.md), and explicitly rejected a runtime
flag service (its Option C) as more machinery than this project's scale
justifies. An earlier draft of this plan assumed six runtime flags under
`app:feature:auth:*`, flipped in lockstep with server env vars. That is the
system ADR-0042 declined to build, so the flags are re-scoped here.

The starting point is that **a phase that is not merged does not ship**.
Each phase is its own release, so most of them need no flag at all. A flag
earns itself in exactly two situations: client code that must merge to
`main` before its UI should be visible, and a server behaviour change that
has to be reversible without a redeploy of the app.

**One client flag**, compile-time, `AppFlagKind.temporary`:

| `dart-define`   | Phases | Purpose                                                                 |
|-----------------|--------|-------------------------------------------------------------------------|
| `AUTH_DISABLED` | 2–5    | Hides every sign-in surface (drawer tile, Library hint, `/auth/*` routes, policy and fork affordances) so auth work can merge and ship dark. |

It follows `MIGRATION_DISABLED`'s shape deliberately — same kind, same
registry, same Sentry tag — and is retired in the release after phase 5,
which is the point at which every surface it hides is meant to be visible.
One flag rather than one per phase because the phases are strictly ordered:
there is no build in which phase 3's fork button should be live while phase
2's login is not.

**Two server env vars**, read by the Netlify functions at request time.
These are deploy-time configuration in the same family as `ADMIN_TOKEN`,
not a client flag service, so ADR-0042 does not speak to them:

| Env var                       | Phase | Purpose                                                       |
|-------------------------------|-------|---------------------------------------------------------------|
| `FEATURE_AUTH_ACCOUNT_DEFAULT`| 4     | Initialise new slugs with `accessPolicy=account`. Reversible without an app release, which is the whole reason it exists — phase 4 is the one change that can lock a user out of their own slug. |
| `FEATURE_AUTH_ADMIN_TOKENS`   | 6     | Accept per-person admin tokens on `/api/admin` alongside `ADMIN_TOKEN`. |

The client does not read either one. It reacts to what the server returns
(`meta.accessPolicy` on the upload response), so client and server do not
have to be flipped together — which was the coupling the six-flag table was
trying to manage.

## Migration steps

* **Backfill `meta.accessPolicy`.** Phase 1 introduces the field with
  default `public`. No backfill needed because reads treat absent
  fields as `public` and accept legacy serialized `wiki` as an alias
  for one release.
* **`ownerId="anon"` plans.** Stay under `drills/anon/...` for their
  lifetime. No copy, no rewrite. The fork path (phase 3) creates a
  separate plan under `drills/<accountId>/...` at a new slug, the
  original `anon` blobs are untouched.
* **`app:catalogOwnership:<slug>` flag.** Read once on phase 2 startup,
  used to seed `PlanSource.catalog.ownerAccountId` for plans that the
  current device has been treating as owned. Cleared afterwards.
* **`RINGDRILL_ADMIN_TOKEN` in CI.** Continues to work through phase 6.
  Replaced with `RINGDRILL_ACCESS_TOKEN` (a long-lived personal token
  scoped to an admin user) in phase 6.
* **Drill schema.** Unchanged — stays at 1.2. Absent `policy` reads as
  `AccessPolicy.public()` and absent `ownerAccountId` as `null`, which is
  ordinary additive-field behaviour and needs no version to key off
  ([ADR-0059](../adrs/0059-drill-schema-migration-ladder.md): the version
  string does not identify content shape, and all live catalog plans are
  1.2 while differing in shape). `KNOWN_SCHEMA_MAX`
  ([`shared.js`](../../netlify/functions/lib/shared.js)) is not touched, so
  there is no client/server lockstep release to coordinate.

## Telemetry and verification

The phase rollouts depend on the following counts. All log lines go
through the Sentry consent gate
([ADR-0006](../adrs/0006-sentry-behind-consent-gate.md)) and never
include slug, account name, or user identifiers.

* `auth.signin.start`, `auth.signin.success`, `auth.signin.fail` —
  count of attempts per provider.
* `auth.upload.anonymous`, `auth.upload.authenticated` — every upload,
  per phase. Phase 4 expects `authenticated` ≥ 95% for new slugs.
* `auth.policy.flip.account`, `auth.policy.flip.public`,
  `auth.policy.flip.shared` — count of policy changes. Sudden spikes
  to `public` after phase 4 mean we need to study why.
* `auth.fork.created` — count of "Fork to my account" actions. Helps
  size the demand for a future "replace from my version" feature.
* `auth.refresh.replay` — refresh-token replay attempts (a security
  signal, not a UX signal). Any non-zero value is investigated.

A short manual verification script lives at
`docs/plans/account-rollout-verify.md` (to be created in phase 1) and
covers the happy path on each phase.

## Threat model (short version)

* **Stolen access token.** 1h expiry, no damage beyond the User's
  existing roles, refresh-token rotation detects parallel use.
* **Stolen refresh token.** Rotation on each use, replay invalidates the
  session and forces re-login. Later hardening: bind refresh token to a
  device public key.
* **Mail-relay compromise (magic links).** Codes expire in 10 minutes,
  single-use, IP-pinned to the start request when possible.
* **Sign-up squatting.** A bad actor signs up for
  `noreply@victim.example` using an unverified provider, hoping the
  real owner shows up later and gets auto-linked into the squatter's
  account. Identity linking only happens on verified emails, so the
  squatter cannot inherit the real owner's verified identity. No
  in-place adoption exists, so a squatter cannot claim a wiki slug
  either.
* **Insider takeover.** A hostile `member` is demoted to `guest`, or
  removed, by an `owner`. Later hardening: audit log of policy and member changes.

## Communication

* Changelog entry on phase 2 release: "Logg inn for å sikre planene
  dine. Planer du har i dag fortsetter å fungere uten innlogging."
* In-app notice in Library on first launch after phase 2, dismissible.
* Documentation update on `docs/architecture.md` "Backend" section to
  describe the auth flow once phase 1 ships.
* Update `AGENTS.md` to point at `AuthService` as the canonical
  identity source for client code once phase 2 ships.

## Staff PII — decided, and scoped out of these six phases

This section used to argue that account-backed sync would carry the staff
folder server-side, and that a privacy statement, a legal basis, retention,
deletion and a sub-processor list therefore had to land somewhere around
phase 3 or 5. That argument was right.
[ADR-0072](../adrs/0072-staff-pii-and-account-sync.md) settles *where* the
boundary sits: the catalog is public and stays stripped unconditionally, and
a roster does travel into the scope of the account that owns the plan,
because that is the co-ownership use case ADR-0024 was written for.

The reason it is not a phase here is concrete rather than legal. Today
**stored server-side and publicly readable are the same state**:
[`deep-link.js`](../../netlify/functions/deep-link.js) serves `/d/:slug` with
no `published` check and no credential, CDN-cached, and `published` only
controls listing in the feed. So roster sync is not "stop stripping on one
path" — it needs a store no public route can reach and an authenticated,
uncached read path, neither of which exists. That is backend work of its
own, gated on ADR-0072's five entry criteria, and it lands after phase 5
makes multi-member accounts real.

What that means for the six phases below:

* **Phase 3 needs no consent surface.** The publish dialog gets policy
  controls and nothing else. Nothing in phases 1–6 sends a roster anywhere,
  so there is no disclosure to write yet.
* **Phase 5 designs the `shared` UI knowing the answer.** Cross-account
  delegation grants write access to plan *content*; the grantee's responses
  omit the roster. Withheld, not removed — the owner's stored copy is
  untouched by any grant, so sharing a plan never costs you your own phone
  list and revoking a grant restores nothing because nothing was deleted.
  Decided in ADR-0072 before the picker exists, rather than discovered
  afterwards.
* **One item is added to phase 1**: move the strip from `drills-upload.js`'s
  call site into the shared ingest path, and add the test that enumerates
  the functions accepting archive bytes. Phase 1 is where a second
  server-side write path first becomes plausible, so it is the right moment
  to make the catalog rule structural rather than remembered.

Roster sync itself is tracked against ADR-0072, not against a phase number
here.

## Downstream consumers

Two things outside this plan are waiting on it, and neither is tracked
anywhere else:

* **MCP publish ([ADR-0060](../adrs/0060-remote-mcp-server.md)).** The hosted
  `/mcp` endpoint is deliberately unauthenticated, and the reason given in
  [`api.md`](../api.md) is that every tool maps to a public operation and
  `publish` is absent — "so there is nothing to authorize". A `publish` tool
  therefore cannot ship before phase 2 at the earliest, and needs its own
  decision about how an agent holds a token (an MCP client is neither the app
  nor the CLI). Until then, the rate limit is the only control, and that is
  the correct posture rather than a gap.
* **The CLI's admin commands.** `bin/ringdrill.dart` reads
  `RINGDRILL_ADMIN_TOKEN` today and gets personal tokens in phase 6. Nothing
  before phase 6 changes for it, which is the point of keeping `ADMIN_TOKEN`
  accepted throughout.

## Open questions

* Mail provider choice: Resend (simpler, EU residency available) vs
  SES (cheaper at scale, more configuration). Decision lands before
  phase 1 starts.
* Whether to require signed-in identity for *creating* a session
  (realtime, [ADR-0009](../adrs/0009-realtime-transport-and-session-model.md)).
  Current default is no. Revisit after phase 5.
* Long-term home for the JWT signing key. Netlify env vars work for
  now, a managed KMS comes later.
