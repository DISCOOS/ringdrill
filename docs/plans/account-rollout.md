# Account rollout plan

Companion document to [ADR-0024](../adrs/0024-account-and-identity-model.md),
[ADR-0025](../adrs/0025-authorization-and-publish-policy.md) and
[DESIGN-015](../design/015-accounts-and-iam.md). The ADRs decide the data model
and the authorisation rules, DESIGN-015 decides what the user sees. This
document sequences the work and lists the migration and cutover steps.

Status: approved. ADR-0024 and ADR-0025 are accepted as of 2026-05-28.

> **Revised 2026-08-05 — collapsed from six phases to one release.** See
> "Why one release" below. The phased plan was written when the shape of the
> feature was uncertain; the measured cost of staging it now exceeds what it
> buys at this scale.
>
> **Revised 2026-08-04, before any work started.** Four decisions accepted
> after this plan was first written changed what it should say:
>
> * **[ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md)** chose
>   *compile-time* `dart-define` flags and explicitly rejected a runtime flag
>   service. The six runtime flags this plan carried were the system that ADR
>   declined to build.
> * **[ADR-0059](../adrs/0059-drill-schema-migration-ladder.md)** established
>   that additive fields land without a schema bump. The schema 1.3 bump is
>   withdrawn.
> * **[ADR-0060](../adrs/0060-remote-mcp-server.md)** shipped a hosted MCP
>   endpoint that is unauthenticated *because* it cannot publish — a
>   downstream consumer of this work, see "Downstream consumers".
> * **[ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)** settled staff
>   PII: a roster belongs inside the account that owns the plan, the catalog
>   stays stripped unconditionally, and roster sync needs infrastructure that
>   does not exist yet, so it is out of scope here.
>
> Code references were also refreshed for the Program→Plan rename
> ([ADR-0055](../adrs/0055-programid-planid-wire-back-compat.md)).

## Goals

1. Protect published plans from changes by people outside the owning Account.
2. Do not break any existing `public` plan. `public` stays a supported policy
   after accounts land, not a holdover.
3. Keep offline planning unaffected, and **keep publishing possible without an
   account**. Signing in buys protection; it is not the price of using the app
   ([DESIGN-015](../design/015-accounts-and-iam.md) §5.1).
4. Keep the CLI usable in CI throughout.

## Non-goals

* Passkeys / WebAuthn. Reserved for a later iteration.
* Per-station or per-exercise access controls inside a plan. The unit of
  protection is the slug.
* Login walls on public reads. `/api/market/feed` and `/d/:slug` stay public.
* Roster sync. A plan's `staff/` folder *does* belong in the scope of the
  account that owns it
  ([ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)) — that is most of
  why a co-owner wants the shared plan — but it needs a private store, an
  authenticated read path that projects per reader, and a privacy statement,
  none of which exist. It lands separately, against ADR-0072's entry criteria.
  This release is about authorising *catalog writes*, where the strip stays
  unconditional and at write time.

An earlier draft listed "secure refresh-token storage beyond
`SharedPreferences`" as a non-goal. That is wrong against
[ADR-0024](../adrs/0024-account-and-identity-model.md), which puts both tokens
in `flutter_secure_storage` and keeps only the non-sensitive mirror in
`SharedPreferences`.

## Why one release

The original plan had six phases, each a separate release, so that each step
could be paused or reverted before the next. That is the right structure when
a change might break a large installed base. It is the wrong structure here,
and the numbers say so plainly:

* **Three plans in the live catalog**, all `ownerId="anon"`
  ([ADR-0059](../adrs/0059-drill-schema-migration-ladder.md) measured this
  while deciding the migration ladder). Every one of them stays `public` and
  keeps working untouched, under a phased rollout or a single one.
* **Very few users.** The telemetry gate between phases — "expect
  `authenticated` ≥ 95% of new-slug publishes before flipping the default" —
  cannot produce a meaningful reading at this volume. A gate that cannot fail
  is not a gate.
* **Six phases is six releases**, each with an App Store review, a changelog
  entry, and a window where the app and the backend disagree about what
  exists. That coordination cost is real and recurring, and it is being paid
  to protect against a risk the first two bullets have already retired.

What staging genuinely bought, and how it is replaced:

| Phased | Single release |
|---|---|
| Revert phase N without touching N−1 | `AUTH_MODE=off`, server-side, see below |
| Telemetry gate before enforcement | Nothing to gate at three plans |
| Ship auth code dark behind a flag | Work on the `design-015` branch; unmerged code does not ship |
| Verify each step before the next | `AUTH_MODE=mock` — the whole matrix is exercisable in dev and CI, which the phased plan never provided |

The one thing that does **not** collapse is deploy ordering, because web ships
in minutes and mobile takes days. That is handled in "Cutover" rather than by
splitting the feature.

## The release

Ordered by dependency, not by risk. Everything below ships together.

### Status — 2026-08-08

Built on `feat/accounts-backend`. Backend and client are both in; three things
are deliberately not, and only the first blocks the release.

| | State |
|---|---|
| Auth endpoints, accounts, members, invitations, policy, account plans | **Done** |
| Catalog re-key (ADR-0074) and its migration | **Done, not yet run** — see [`catalog-rekey-migration.md`](./catalog-rekey-migration.md) |
| `AuthService`, sign-in screen, account/members screen, invite page | **Done** |
| Library account tab, Online→Public, publish dialog sharing | **Done** |
| Sessions list, account deletion, handle-based sharing | **Done** |
| Apple / Google / Microsoft sign-in | **Not built** — blocks the release |
| CLI device grant | Deferred by design (§ CLI below) |
| `ADMIN_TOKEN` removal | Deferred — no user-facing effect |

**The provider gap is the one that matters.** Only the email path exists, on
both sides: `auth.js`'s `callback` redeems an email challenge and nothing else,
and the sign-in screen states that providers are coming rather than showing
disabled buttons. Shipping like this would mean an Apple-device user has no
Apple sign-in, which is a worse first impression than no accounts at all — and
[ADR-0024](../adrs/0024-account-and-identity-model.md)'s App Store 4.8 reasoning
assumes email is *an* option, not the only one.

Closing it needs two things this work could not produce:

1. **Server-side ID-token verification** in `callback` — fetch each provider's
   JWKS, verify the signature, and take `sub`, `email` and `email_verified`
   from the verified claims rather than from the request body. The
   `resolveIdentity` call it feeds is already provider-agnostic, so this is
   additive.
2. **OAuth client IDs and native configuration** — Apple Service ID and key,
   Google client IDs per platform, Microsoft app registration, plus the
   entitlements and URL schemes each needs. These are account-level
   credentials, not code.

### Backend

* Add `accounts`, `users`, `identities`, `members`, `email-index` and
  `sessions` stores in `netlify/functions/lib/shared.js`.
* Implement `POST /api/auth/start-email`, `POST /api/auth/callback`,
  `POST /api/auth/refresh`, `POST /api/auth/logout`, `GET /api/auth/me`.
  Magic link with a 6-character code alternative
  ([DESIGN-015](../design/015-accounts-and-iam.md) §3.3), sender
  `noreply@mail.ringdrill.app` (a subdomain, see "Open questions"),
  templates in `netlify/functions/_email/`.
* **Mail provider: Resend** (decided 2026-08-05). Free at this volume — 3,000
  emails/month, 100/day, one domain — against an expected load of tens per
  month, and $20/mo if that ever stops being true. Chosen over SES for bounce
  ergonomics: a webhook URL rather than an SNS topic, and
  [DESIGN-015](../design/015-accounts-and-iam.md) §6.2's member-row state is
  the only place a bounce surfaces, so that is the integration worth
  optimising.

  **Accepted cost, which the privacy statement has to name.** Resend lets you
  pick a *sending* region (`eu-west-1`), but account data — email metadata,
  logs, API records — is stored in the **United States** regardless. Transfers
  run on SCCs in their DPA and EU-US Data Privacy Framework certification, so
  it is lawful, but it is not residency. Email metadata includes recipient
  addresses, and for an invitation that is *the address of somebody who is not
  yet a user* — exactly the category
  [ADR-0072](../adrs/0072-staff-pii-and-account-sync.md) singles out. It does
  not block this release, which stores no rosters, but Resend is a US
  sub-processor holding EU personal data and belongs on the list from day one
  rather than being discovered later.

  **Swapping later is cheap, and specified rather than hoped for.**
  [ADR-0075](../adrs/0075-mail-provider-adapter.md) puts sending behind a
  `MAIL_PROVIDER` adapter and keeps the two expensive things on our side:
  templates render in `netlify/functions/_email/` before the adapter is called
  (hosted vendor templates are the lock-in trap that is invisible until you try
  to leave), and bounce webhooks normalise to a common `MailEvent` so §6.2
  reads one vocabulary. If EU residency becomes a hard requirement, SES
  `eu-north-1` (Stockholm) keeps data in region and the change is one adapter
  plus one webhook normaliser.
* **The mail seam** ([ADR-0075](../adrs/0075-mail-provider-adapter.md)):
  `MAIL_PROVIDER = resend | ses | mock | console`, templates in-repo in both
  locales, per-provider webhook normalisers, namespaced message ids. Invitation
  mail uses the *inviting* user's locale; request-driven mail uses the
  requesting client's.
* **The mail channel, which several flows depend on** — not only sign-in:
  invitations to addresses with no account (DESIGN-015 §6.4), verifying a
  second address (the Apple-relay fix, §3.5), bounce webhooks so a failed
  invite shows on the member row, and security notices. Outbound only: a
  transactional send API, no MX record and no inbox. **SPF, DKIM and DMARC on
  `ringdrill.app`** are part of this and matter more than usual — a magic link
  or an invitation in a spam folder is a silently broken flow, not a degraded
  one.
* JWT signing (ed25519) with `AUTH_SIGNING_KEY_PRIVATE` /
  `AUTH_SIGNING_KEY_PUBLIC`.
* `authenticate(request)` helper: anonymous, authenticated, or 401 — behind the
  adapter seam from [ADR-0073](../adrs/0073-auth-mode-and-adapters.md), with
  `live`, `mock` and `off` implementations, the `live`-rejects-`test.`-tokens
  guard, and the test asserting `mock` refuses to load under
  `CONTEXT=production`.
* **Enforce ADR-0025's authorisation matrix** in `drills-upload.js`, before
  OCC. `accessPolicy` stops being descriptive and becomes a gate, so the
  "descriptive only" notes in `shared.js`, `drill_client.dart` and `api.md`
  come out in the same change. Accept serialized `wiki` as an alias for
  `public` on read for one release.
* **An anonymous new-slug publish keeps working** and produces an
  `anon`-owned `public` plan, exactly as today
  ([ADR-0025](../adrs/0025-authorization-and-publish-policy.md), amended
  2026-08-05). An authenticated one claims the slug for the active account at
  `accessPolicy=account`. This is goal 3, and it is the single most important
  line in this section.
* `POST /api/drills/policy?slug=<slug>` — owner-only, flips between `account`,
  `shared` and `public`.
* `POST /api/accounts`, `POST /api/accounts/:id/members`,
  `DELETE /api/accounts/:id/members/:userId` — owner-only.
* `GET /api/accounts/:id/plans` — plans owned by an account, published or not.
  `market-feed` cannot serve this: it filters on `published` and is public by
  design.
* Move the PII strip from `drills-upload.js`'s call site into the shared
  ingest path, so every catalog-bound function that reads archive bytes goes
  through it, and add the test that enumerates those functions
  ([ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)). A second
  server-side write path becomes plausible the moment accounts exist; the
  catalog rule has to be structural before that, not remembered.
* Telemetry, behind the Sentry consent gate
  ([ADR-0006](../adrs/0006-sentry-behind-consent-gate.md)).

### Client

* `AuthService` (singleton, framework-free). Tokens in
  `flutter_secure_storage` (`ringdrill.auth.accessToken`,
  `ringdrill.auth.refreshToken`); non-sensitive mirror (user, accounts,
  activeAccount) in `SharedPreferences` under `app:auth:v1:*`.
* Routes `/auth/login`, `/auth/callback`. Cold-start route stays `/library`.
* Sign in with Apple (iOS, macOS), Google (Android, web), Microsoft (personal
  and work/school via the `common` endpoint), email link everywhere. Ordering
  per platform is [DESIGN-015](../design/015-accounts-and-iam.md) §3.2; the
  catalogue and the reasoning — including why `bankid` is rejected rather than
  reserved — is [ADR-0024](../adrs/0024-account-and-identity-model.md), amended
  2026-08-05. Only `email` is on the critical path; the rest are adapters.
* Sign-in entry points, account pages, recovery, member management: all
  specified in [DESIGN-015](../design/015-accounts-and-iam.md) §3–§6.
* Add `policy` and `ownerAccountId` to `PlanSource.catalog`, defaulting to
  `AccessPolicy.public()` / `null`. **No schema bump** — additive, and `source`
  is excluded from `Plan.computeContentHash`
  ([ADR-0059](../adrs/0059-drill-schema-migration-ladder.md)). `make build`
  after.
* Publish dialog: names the account it will publish to, tappable to switch
  (DESIGN-015 §5.5), and a **"Deling" / "Sharing"** section for the access
  policy.

  > Not *"Tilgang"*. DESIGN-015 §7 reserves *Tilgang* for `MemberRole` —
  > because *Rolle* is already spent on `StaffRole` — and using it here too
  > would put the plan's write policy and a person's standing in the account
  > under one word, which is the collision §7 exists to prevent, one level
  > down. The publish dialog is choosing how the plan is shared; the members
  > list is choosing what someone may do.
* Library surfaces policy: account icon, globe for `public`, people-with-link
  for `shared`.
* "Fork to my account" on `public` plans, reusing `forkAsLocal` in
  `PlanService`. The original slug is untouched.
* Plan selector gains its fourth tab and `online` is renamed `public`
  (DESIGN-015 §5.7). The tab is absent for signed-out users, so an install
  without an account keeps today's three. ARB: `libraryOnlineTab` →
  `libraryPublicTab`, new `libraryAccountTab`; `make i18n` after.

### CLI — deferred, but designed

**Not in this release.** The CLI keeps `RINGDRILL_ADMIN_TOKEN` and changes
nothing, which is why goal 4 holds without any work here.

It is designed now because two of its endpoints have to be known before the
auth surface is built rather than bolted on afterwards
([DESIGN-015](../design/015-accounts-and-iam.md) §3.5):

* `POST /api/auth/device/start` and `POST /api/auth/device/token` — the device
  authorization grant ([RFC 8628](https://www.rfc-editor.org/rfc/rfc8628)).
  `ringdrill auth login` prints a URL and a short code, the browser reuses the
  session it already has, a consent screen states what is being granted, and
  the CLI polls until it is.
* A **consent screen** at `/auth/device` on the web surface, which echoes the
  code back for the user to check against their terminal. That echo is the
  mitigation for RFC 8628 §5.4's phishing case and is not optional.
* `admin: true` on User records to gate `/api/admin`. Named `admin`, not
  `staff`, so it cannot be confused with the `Staff` roster entity or the
  `staff/` PII folder (ADR-0025).

Two properties this buys that a CLI-shaped magic link would not: nobody
authenticates twice, and the CLI becomes a **separately revocable session**
appearing in Account → Devices, signed out without touching the phone.

Removing `ADMIN_TOKEN` is a later step again, after CI has moved to
`RINGDRILL_ACCESS_TOKEN` — see "Cutover".

## Auth mode

Not a feature flag. [ADR-0073](../adrs/0073-auth-mode-and-adapters.md) makes
the auth backend an adapter selected by one env var, because dev and test need
to exercise the authorisation matrix without a mail provider or a signing key —
a need that exists regardless of this release and outlives it.

| `AUTH_MODE` | Tokens | Used by |
|---|---|---|
| `live` *(default when unset)* | Signed ed25519 JWT | Production |
| `mock` | `test.<claims>`, minted by the caller; `start-email` returns the code in the response body | `make netlify-dev`, integration tests, CI |
| `off` | None; every request anonymous, matrix not applied | Pre-account regression tests, emergency rollback |

`mock` replaces the two *dependencies* — mail delivery and signature
verification — and nothing else. The endpoints, the matrix, OCC and the PII
strip are the same code in every mode, so a `guest` is refused locally for the
same reason it is refused in production.

Two consequences for this release:

* **The mail-provider decision leaves the critical path.** Resend vs SES is
  needed for the `live` adapter and for production. Everything else can be
  built and verified before it is made.
* **`AUTH_MODE=off` is the rollback.** An earlier draft of this plan called it
  `FEATURE_AUTH_ENFORCE`, which named it wrongly on both counts: `FEATURE_*`
  implies a temporary rollout artifact that gets deleted at sunset
  ([ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md)), and a
  boolean cannot express `mock`. The rollback capability is a *consequence* of
  having modes, not the reason the variable exists.

Rolling back still matters as much as it did: reverting a mobile release takes
days, flipping a Netlify env var takes seconds, and with no phases to fall back
through, the whole recovery path is server-side.

No client `dart-define` flag. ADR-0042's `MIGRATION_DISABLED` existed because
phase 1 shipped to production while phase 2 was still being written; with one
release there is no such window. Unmerged work on `design-015` does not ship,
which is the same protection without a flag to retire later. The client has no
branch for auth mode at all — it asks for a code and posts it back, and the
backend decides where the code came from.

## Cutover

The only sequencing that survives, and it is deployment rather than feature
sequencing:

1. **Deploy the backend first**, with `AUTH_MODE=off`. Nothing changes for
   anyone: no client sends a token yet.
2. **Verify against production** with the curl script
   (`docs/plans/account-rollout-verify.md`, written during the work): sign up,
   publish authenticated, publish anonymous, confirm the anonymous path still
   produces an `anon`/`public` plan.
3. **Set `AUTH_MODE=live`.** Existing plans are all `anon`/`public` and are
   unaffected — there is nothing yet for the matrix to refuse.
4. **Ship web.** Minutes. Web users can sign in.
5. **Ship mobile.** Days, gated on review. Until it lands, mobile publishes
   anonymously — which is exactly today's behaviour, not a degraded mode.
6. **Later: `ringdrill auth login`** (device grant, DESIGN-015 §3.5), then
   **retire `ADMIN_TOKEN`** once CI has moved to `RINGDRILL_ACCESS_TOKEN` and
   no script in the repo references the old name. Two separate releases, both
   after this one.

Step 5 is why goal 3 matters operationally and not only philosophically: the
old app is an anonymous client, and an anonymous client has to keep working or
every phone in the field breaks for the length of an App Store review.

## Migration

* **`meta.accessPolicy`.** No backfill. Absent reads as `public`, and legacy
  serialized `wiki` is accepted as an alias for one release.
* **`ownerId="anon"` plans.** Stay under `drills/anon/...` for their lifetime.
  No copy, no rewrite. Fork creates a separate plan at a new slug; the `anon`
  blobs are untouched.
* **`app:catalogOwnership:<slug>`.** Read once at first launch after the
  release, used to seed `PlanSource.catalog.ownerAccountId` for plans this
  device has been treating as owned. Cleared afterwards.
* **`RINGDRILL_ADMIN_TOKEN` in CI.** Keeps working. Replaced with
  `RINGDRILL_ACCESS_TOKEN` before the follow-up that removes it.
* **Drill schema.** Unchanged at 1.2. `KNOWN_SCHEMA_MAX` is not touched, so
  there is no client/server lockstep release to coordinate.

## Telemetry and verification

Through the Sentry consent gate
([ADR-0006](../adrs/0006-sentry-behind-consent-gate.md)), never including
slug, account name or user identifiers.

* `auth.signin.start` / `.success` / `.fail` — per provider.
* `auth.upload.anonymous` / `.authenticated` — every upload. No longer a
  release gate (there is not enough volume for one), but the ratio tells us
  whether sign-in is being adopted or avoided.
* `auth.policy.flip.account` / `.public` / `.shared`.
* `auth.fork.created` — sizes demand for a future "replace from my version".
* `auth.refresh.replay` — a security signal, not a UX one. Any non-zero value
  is investigated.

`docs/plans/account-rollout-verify.md` holds the manual happy-path script and
is written during the work, not after.

## Threat model (short version)

* **Stolen access token.** 1 h expiry, no damage beyond the User's existing
  roles, refresh rotation detects parallel use.
* **Stolen refresh token.** Rotated on every use; replay invalidates the
  session and forces re-login. Later hardening: bind to a device public key.
* **Mail-relay compromise (magic links).** Codes expire in 10 minutes,
  single-use, IP-pinned to the start request where possible.
* **Sign-up squatting.** Linking only happens on verified emails, so a
  squatter cannot inherit a real owner's identity. No in-place adoption
  exists, so a squatter cannot claim a wiki slug either.
* **Insider takeover.** A hostile member is **removed** by an `owner`.
  Demotion is not a mitigation and must not be offered as one: every role
  publishes, so moving someone to `guest` withdraws their view of the staff
  roster and nothing else (ADR-0024, 2026-08-05 amendment). Later hardening:
  an audit log of policy and member changes.

## Communication

* Changelog: *"Logg inn for å sikre planene dine. Planer du har i dag
  fortsetter å fungere uten innlogging."*
* Dismissible in-app notice in Library on first launch after the release.
* `docs/architecture.md` "Backend" section describes the auth flow.
* `AGENTS.md` points at `AuthService` as the canonical identity source for
  client code.

## Staff PII — decided, and out of scope here

[ADR-0072](../adrs/0072-staff-pii-and-account-sync.md) settles where the
boundary sits: the catalog is public and stays stripped unconditionally, and a
roster does travel into the scope of the account that owns the plan, because
that is the co-ownership case ADR-0024 was written for.

The reason it is not in this release is concrete rather than legal. Today
**stored server-side and publicly readable are the same state**:
[`deep-link.js`](../../netlify/functions/deep-link.js) serves `/d/:slug` with
no `published` check and no credential, CDN-cached, and `published` only
controls listing in the feed. Roster sync is not "stop stripping on one path"
— it needs a store no public route can reach and an authenticated, uncached
read path that projects per reader. That is backend work of its own, gated on
ADR-0072's six entry criteria.

Two consequences for this release:

* **No consent surface.** Nothing here sends a roster anywhere, so there is no
  disclosure to write yet. The account page carries the "what is stored"
  heading from DESIGN-015 §8 so there is one obvious place for it to grow.
* **`shared` ships knowing the answer.** Cross-account delegation grants write
  access to plan *content*; the grantee's responses omit the roster. Withheld,
  not removed — the owner's stored copy is untouched by any grant, so sharing
  never costs you your own phone list, and revoking restores nothing because
  nothing was deleted.

## Downstream consumers

* **MCP publish ([ADR-0060](../adrs/0060-remote-mcp-server.md)).** The hosted
  `/mcp` endpoint is deliberately unauthenticated because `publish` is absent
  — "so there is nothing to authorize" ([`api.md`](../api.md)). This release
  unblocks a `publish` tool, which still needs its own decision about how an
  agent holds a token: an MCP client is neither the app nor the CLI. Until
  then the rate limit is the only control, and that remains correct rather
  than a gap.
* **The CLI's admin commands.** `bin/ringdrill.dart` is untouched by this
  release and keeps `RINGDRILL_ADMIN_TOKEN`. `ringdrill auth login` and the
  device-grant endpoints follow separately, designed in DESIGN-015 §3.5.

## Open questions

* Whether creating a realtime session
  ([ADR-0009](../adrs/0009-realtime-transport-and-session-model.md)) should
  require a signed-in identity. Current default is no; revisit after the
  release.
* Long-term home for the JWT signing key. Netlify env vars for now, a managed
  KMS later.
* Whether an `owner` should be distinguishable from an *admin* who manages
  people but cannot delete the account (DESIGN-015 §11). Fits the model
  without a change; nobody to be it at current scale.
* **Local plan storage** — decided in
  [ADR-0076](../adrs/0076-local-plan-storage-at-rest.md) (accepted): a folder
  per plan, laid out like the archive, with an iOS protection class and a
  deliberate backup policy. Reads stay synchronous. Not built yet, and not a
  release blocker — it is independent of accounts.
* **Whether `POST /api/accounts` should ever create a *second* personal
  account.** It cannot today, and nothing needs it to; noted because the
  endpoint's shape does not say so.
