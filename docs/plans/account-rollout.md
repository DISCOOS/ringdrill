# Account rollout plan

Companion document to [ADR-0024](../adrs/0024-account-and-identity-model.md)
and [ADR-0025](../adrs/0025-authorization-and-publish-policy.md). The ADRs
decide the data model and the authorisation rules. This document sequences
the work, names the feature flags, and lists the migration steps.

Status: approved. ADR-0024 and ADR-0025 are accepted as of 2026-05-28.
This document tracks the rollout against those decisions.

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
* Secure refresh-token storage beyond `SharedPreferences`. A separate
  hardening ADR can revisit this.
* Per-station or per-exercise access controls inside a plan. The unit of
  protection is the slug.
* Login walls on public reads. `/api/market/feed` and `/d/:slug` remain
  public.

## Phases

Each phase is a separate release. A phase can be paused, reverted, or
extended without forcing the next one.

### Phase 1 — Backend identity foundation

Server-only. No client UI change. Goal: stand up the auth surface and
seed the data model.

* Add `accounts`, `users`, `identities`, `members`, `email-index` and
  `sessions` stores in `netlify/functions/_shared.js`.
* Implement `POST /api/auth/start-email`, `POST /api/auth/callback`,
  `POST /api/auth/refresh`, `POST /api/auth/logout`, `GET /api/auth/me`.
* Magic link via Resend or SES. Sender domain: `noreply@ringdrill.app`.
  Templates in `netlify/functions/_email/`.
* Implement JWT signing (ed25519) with `AUTH_SIGNING_KEY_PRIVATE` and
  `AUTH_SIGNING_KEY_PUBLIC` Netlify env vars.
* Implement `authenticate(request)` helper that classifies a request as
  anonymous, authenticated, or invalid (401). No endpoint enforces yet.
* Add `accessPolicy` field to `meta.json` writes, defaulting to
  `public` for everything (preserves current behaviour). Accept
  serialized `wiki` as an alias on read for one release, since the
  serialized name is being renamed.
* Telemetry: log per-endpoint counts of `anonymous` vs `authenticated`
  uploads, behind the existing Sentry consent gate
  ([ADR-0006](../adrs/0006-sentry-behind-consent-gate.md)).

Exit criteria: a curl-driven sign-up + publish round-trip works in
`make netlify-dev`. No client release.

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
* Bump schema to 1.3 on `ProgramSource.catalog` to add `policy` and
  `ownerAccountId` fields, defaulting to `AccessPolicy.public()` /
  `null` for read compatibility.

Exit criteria: a signed-in user can publish and refresh without seeing
a different result than today.

### Phase 3 — Per-plan policy UI and fork-to-account

Goal: give users a path from wiki to a protected own-copy, without
mutating any existing slug.

* Implement `POST /api/drills/policy?slug=<slug>` for owners to flip
  between `account` and `public`. UI lives in publish dialog under
  "Tilgang" / "Access". The `shared` variant is server-rejected with
  400 in this phase and surfaced in phase 5.
* Surface policy in Library: account icon for `account`, globe icon
  for `public`. A people-with-link icon is reserved for `shared` and
  unused until phase 5.
* "Fork to my account" button on `public` plans in Library. Reuses
  the existing `forkAsLocal` branch in `ProgramService` to produce a
  new local plan with a `(kopi)`-suffixed name. The original slug
  stays untouched. Publishing the fork goes through the standard
  new-slug path.
* Client mirrors `ownerAccountId` and `policy` into
  `ProgramSource.catalog` from upload responses.

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

Goal: replace the shared admin secret with per-staff personal tokens.

* `ringdrill login` runs the magic-link flow over the terminal.
* `ringdrill list-all` and friends use the personal access token.
* `staff: true` flag on User records gates the admin endpoints.
* `ADMIN_TOKEN` accepted for one full release cycle after the CLI gains
  personal tokens, then removed from `drills-admin.js`.

Exit criteria: production admin operations no longer require
`ADMIN_TOKEN` and no script in the repo references it.

## Feature flags

Each phase ships behind a runtime flag readable from
`AppConfig`. Flag keys use the `app:feature:auth:*` namespace and the
`:v1` suffix per `lib/utils/app_config.dart` convention.

| Flag                                | Phase | Purpose                                                |
|-------------------------------------|-------|--------------------------------------------------------|
| `app:feature:auth:signin:v1`        | 2     | Show login UI and read access tokens                   |
| `app:feature:auth:fork:v1`          | 3     | Show "Fork to my account" button on `public` plans     |
| `app:feature:auth:policy:v1`        | 3     | Show policy controls in publish dialog                 |
| `app:feature:auth:accountDefault:v1`| 4     | Initialise new slugs with `accessPolicy=account`       |
| `app:feature:auth:orgs:v1`          | 5     | Show organisation + member-management UI, enable `shared` policy |
| `app:feature:auth:cliPersonal:v1`   | 6     | Accept personal tokens on `/api/admin`                 |

Server reads the same flag values from Netlify env vars
(`FEATURE_AUTH_*`) so client and backend can be flipped together. Flag
removal is part of the phase-N+1 release.

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
  used to seed `ProgramSource.catalog.ownerAccountId` for plans that the
  current device has been treating as owned. Cleared afterwards.
* **`RINGDRILL_ADMIN_TOKEN` in CI.** Continues to work through phase 6.
  Replaced with `RINGDRILL_ACCESS_TOKEN` (a long-lived personal token
  scoped to staff) in phase 6.
* **Drill schema.** Bumps to 1.3 in phase 2. Readers of 1.0/1.1/1.2
  archives inject `accessPolicy=AccessPolicy.public()` and
  `ownerAccountId=null` on parse. Server's `KNOWN_SCHEMA_MAX`
  ([`drills-upload.js`](../../netlify/functions/drills-upload.js)) is
  bumped in lockstep with the client release.

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
* **Insider takeover.** A hostile `editor` is demoted or removed by an
  `owner`. Later hardening: audit log of policy and member changes.

## Communication

* Changelog entry on phase 2 release: "Logg inn for å sikre planene
  dine. Planer du har i dag fortsetter å fungere uten innlogging."
* In-app notice in Library on first launch after phase 2, dismissible.
* Documentation update on `docs/architecture.md` "Backend" section to
  describe the auth flow once phase 1 ships.
* Update `AGENTS.md` to point at `AuthService` as the canonical
  identity source for client code once phase 2 ships.

## Open questions

* Mail provider choice: Resend (simpler, EU residency available) vs
  SES (cheaper at scale, more configuration). Decision lands before
  phase 1 starts.
* Whether to require signed-in identity for *creating* a session
  (realtime, [ADR-0009](../adrs/0009-realtime-transport-and-session-model.md)).
  Current default is no. Revisit after phase 5.
* Long-term home for the JWT signing key. Netlify env vars work for
  now, a managed KMS comes later.
