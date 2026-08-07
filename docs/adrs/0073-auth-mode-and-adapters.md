---
status: proposed
date: 2026-08-05
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0073: Select the auth backend by mode, and ship a mock adapter for dev and test

## Context and problem statement

[ADR-0024](./0024-account-and-identity-model.md) and
[ADR-0025](./0025-authorization-and-publish-policy.md) give the backend an
authentication surface with two hard external dependencies: a mail provider for
magic links, and an ed25519 signing keypair for access tokens. Neither belongs
in a local dev loop or a test run. A contributor who wants to check that a
`guest` is refused on an `account`-policy slug should not need a Resend account,
and a unit test should not need a keypair.

[ADR-0013](./0013-local-catalog-testing.md) already settled the shape of the
answer for the catalog: run the **real** Netlify functions against `netlify
dev`, and reject "mock the backend in Dart" precisely because a mock does not
exercise `netlify/functions/*.js`, the blob store, or the CDN headers. The same
reasoning applies here, one layer in. An `if (isDev) return { anonymous: true }`
branch inside `authenticate()` would mean dev and CI exercise a code path
production never runs, and production runs a path nothing exercises until it is
live.

Separately, [`../plans/account-rollout.md`](../plans/account-rollout.md) named a
`FEATURE_AUTH_ENFORCE` env var as an emergency kill switch for the account
release. That name is wrong twice over. Turning authorisation off is not a
feature flag: it is needed for dev and test regardless of any rollout, and it
will still be needed long after the rollout is history. And a name in the
`FEATURE_*` family carries an expectation from
[ADR-0042](./0042-feature-flags-and-sunset-telemetry.md) that it is temporary
and gets deleted at sunset. This one is permanent infrastructure.

The decision is therefore what the seam is, what selects across it, and what
stops the convenient implementation from becoming a production backdoor.

## Decision drivers

* A contributor must be able to exercise the **real** authorisation matrix with
  no mail provider and no signing key.
* A test must be able to produce a principal at any role on any account,
  deterministically, without seeding an identity graph first.
* **The same code path in every mode.** A mode that skips `authenticate()`
  entirely proves nothing about the mode that does not.
* A mock adapter that mints principals is a total authorisation bypass. It must
  be *structurally* impossible in production, not policy-impossible, and it must
  fail at startup rather than per request.
* The default must be unchanged behaviour: a developer or deploy that sets
  nothing gets production semantics
  ([ADR-0013](./0013-local-catalog-testing.md)'s driver, restated).
* The mail-provider decision (Resend vs SES) must not block the work. It is the
  last open question on the rollout plan and the least interesting.

## Considered options

### For the seam

* **Option A — `if (dev)` branches inside `authenticate()`.** No new structure.
  The branch ships to production, and dev exercises something production does
  not.
* **Option B — One adapter interface, selected at startup (chosen).** A single
  `authenticate(request)` contract with three implementations behind it.
  Everything downstream — the matrix, OCC, the endpoints — is identical in all
  three.
* **Option C — A separate mock server, or a parallel set of dev-only
  endpoints.** Dev and CI then test a surface production does not serve, which
  is the failure ADR-0013 already rejected in another form.

### For what selects the adapter

* **Option D — `FEATURE_AUTH_ENFORCE`, boolean.** The rollout plan's original.
  `FEATURE_*` is rollout vocabulary implying eventual deletion (ADR-0042), a
  boolean cannot express "mock", and "enforce" names only one of the axes.
* **Option E — `AUTH_MODE`, one variable, three values (chosen).** A mode, not
  a flag. Permanent, self-describing, and the emergency-rollback capability
  falls out of it rather than motivating it.
* **Option F — Two booleans (`AUTH_DISABLED` + `AUTH_MOCK`).** Four
  combinations, two of them meaningless, and the meaningless ones are the ones
  a misconfiguration produces.

## Decision outcome

Chosen: **B (adapter interface)** selected by **E (`AUTH_MODE`)**.

### The modes

| `AUTH_MODE` | Tokens accepted | Mail | Signing key | Used by |
|---|---|---|---|---|
| `live` *(default, and the value when unset)* | Signed ed25519 JWT | Real provider | Required | Production |
| `mock` | `test.<claims>` tokens, minted by the caller | Returned in the response body, never sent | Not needed | `make netlify-dev`, integration tests, CI |
| `off` | None — every request is anonymous | — | — | Pre-account regression tests, emergency rollback |

Unset means `live`, so a deploy that configures nothing gets production
semantics and a misconfiguration fails closed rather than open.

### What `mock` does *not* bypass

This is the point of the ADR, and the reason it is an adapter rather than a
branch. In `mock`:

* The same endpoints exist, at the same paths, with the same request and
  response shapes.
* `authenticate()` returns the same `{ userId, accountId, role }` shape.
* **ADR-0025's authorisation matrix runs unchanged.** A `guest` is refused on an
  `account`-policy slug in `mock` for exactly the reason it is refused in
  `live`, through the same code.
* OCC (`If-Match`) is untouched.
* The PII strip ([ADR-0072](./0072-staff-pii-and-account-sync.md)) is untouched.

What `mock` replaces is the two *dependencies*, not the flow:

* **Mail.** `POST /api/auth/start-email` returns the 6-character code in the
  response body instead of mailing it. The magic-link flow then runs end to end
  with no provider — the client posts the code back to `/api/auth/callback`
  exactly as it would after reading an email.
* **Signature verification.** A `test.` token carries its claims in the clear
  instead of being verified against a public key.

**Consequence worth stating plainly: the mail-provider choice stops blocking
the build.** Resend vs SES is needed for the `live` adapter and for production
only. Everything else — the endpoints, the matrix, the client, the tests — can
be written and verified before that decision is made.

### Test tokens

Format is `test.<base64url(JSON)>`, where the JSON carries the same claims the
real JWT would (`sub`, `act`, `acts`, `roles`). A test that needs a `guest` on
one account and an `owner` on another writes one line and gets a principal; no
sign-up, no store seeding.

Two independent guards, because one is not enough for a credential-shaped
thing:

1. **The `live` adapter rejects any token beginning with `test.`
   unconditionally**, before signature verification, regardless of
   `AUTH_MODE`. A mode misconfiguration therefore cannot make a forged token
   work — the live path refuses the format outright.
2. **The `mock` adapter refuses to load when `process.env.CONTEXT ===
   "production"`** (Netlify sets `CONTEXT` on every deploy), regardless of
   `AUTH_MODE`. It throws at module load, so the function fails to start rather
   than serving forged principals. A test asserts this.

Fail closed, loudly, at startup. A mock auth adapter is a backdoor by
construction; the only acceptable version is one that cannot be reached from
production even by someone actively trying to configure it that way.

### `off`, and the rollback story

`AUTH_MODE=off` is what the rollout plan called `FEATURE_AUTH_ENFORCE=false`:
`authenticate()` reports anonymous for every request and the matrix is not
applied, so the catalog behaves exactly as it did before accounts existed. It
is the emergency rollback path — reverting a mobile release takes days, and
flipping a Netlify env var takes seconds — but that is now a *consequence* of
having modes rather than the reason the variable exists.

It is also the honest way to run the pre-account regression tests: the suite
that asserts today's wiki behaviour runs under `off` and keeps passing for as
long as that behaviour is supported.

### The client is not involved

The app does not know the mode and has no branch for it. It calls
`/api/auth/start-email`, gets a code (from an email in `live`, from the response
body in `mock`), and posts it back. `RINGDRILL_LOCAL_BASE_URL`
([ADR-0013](./0013-local-catalog-testing.md)) already decides *which* backend a
build talks to; the backend decides its own mode. Nothing about auth mode is
compiled into a client, which keeps ADR-0013's rule that a release build cannot
be pointed anywhere unexpected.

### Consequences

* Good: dev and CI exercise the production authorisation path. The matrix is
  not a thing that first runs for real in production.
* Good: the mail-provider decision leaves the critical path. It is needed for
  the `live` adapter and nothing else.
* Good: the rollback capability survives, but as a mode value rather than a
  feature flag somebody has to remember to delete at sunset.
* Good: a test can mint any principal in one line, so role-matrix coverage is
  cheap enough to actually be written.
* Bad: a mock adapter is a backdoor by construction. The two guards are
  load-bearing, and "the test that asserts mock refuses to load in production"
  is now one of the most important tests in the repository.
* Bad: three adapters is three things to keep aligned at the seam. Mitigated by
  the shared return shape and a contract test that runs the same matrix cases
  against `live` and `mock`.
* Bad: **`off` makes allow-assertions pass vacuously.** A test asserting "a
  member may publish" passes under `off` for the wrong reason. Refusal
  assertions fail loudly under `off`, which is the safe direction, but any
  suite that asserts permission must pin the mode explicitly rather than
  inherit it from the environment.
* Bad: one more environment variable to get wrong in a deploy. Mitigated by
  unset meaning `live`.

## Pros and cons of the options

### A. `if (dev)` branches in `authenticate()`

* Good: nothing new to build.
* Bad: dev and CI exercise a path production does not run, and vice versa —
  the failure ADR-0013 rejected for the catalog.
* Bad: the branch ships to production, where it is one predicate away from
  being a bypass.

### B. Adapter interface selected at startup (chosen)

* Good: one contract, one downstream code path, three swappable dependencies.
* Good: the unsafe implementation is a separate module that can refuse to load.
* Bad: a seam to maintain, and three implementations to keep aligned.

### C. Separate mock server or dev-only endpoints

* Good: no mock code in the production bundle at all.
* Bad: dev and CI test a surface production does not serve.
* Bad: the two surfaces drift, and the drift is invisible until production.

### D. `FEATURE_AUTH_ENFORCE` boolean

* Good: obvious meaning for the rollback case.
* Bad: `FEATURE_*` implies a temporary rollout artifact (ADR-0042); this is
  permanent.
* Bad: boolean cannot express `mock`, so a second variable appears later.

### E. `AUTH_MODE` with three values (chosen)

* Good: names the thing it is — a deployment mode, not a rollout stage.
* Good: one variable, mutually exclusive values, no meaningless combinations.
* Bad: a string is easier to typo than a boolean. Unknown values must fail
  closed to `live`… and *loudly*, since silently defaulting a typo to `live` in
  a dev environment produces a confusing "why is nothing authenticating" hunt.

### F. Two booleans

* Good: each is individually obvious.
* Bad: four combinations, two meaningless, and a misconfiguration lands in one
  of the meaningless ones.

## Links

* Related ADRs:
  [ADR-0006](./0006-sentry-behind-consent-gate.md),
  [ADR-0013](./0013-local-catalog-testing.md) — the same "run the real thing
  locally" decision, one layer out,
  [ADR-0024](./0024-account-and-identity-model.md),
  [ADR-0025](./0025-authorization-and-publish-policy.md),
  [ADR-0042](./0042-feature-flags-and-sunset-telemetry.md) — why this is not a
  `FEATURE_*` flag,
  [ADR-0072](./0072-staff-pii-and-account-sync.md)
* Related designs:
  [DESIGN-015](../design/015-accounts-and-iam.md)
* Related plans:
  [`account-rollout.md`](../plans/account-rollout.md) — replaces its
  `FEATURE_AUTH_ENFORCE`
* Related code:
  `netlify/functions/lib/shared.js` (`authenticate` seam),
  `netlify/functions/lib/auth/` (adapters),
  `netlify/functions/drills-upload.js` (matrix consumer),
  `Makefile` (`netlify-dev` sets `AUTH_MODE=mock`),
  `netlify/tests/` (contract test across adapters, production-guard test)
