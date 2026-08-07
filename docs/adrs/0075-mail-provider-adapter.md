---
status: proposed
date: 2026-08-08
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0075: Send mail through a provider adapter, and keep templates and events on our side

## Context and problem statement

[`../plans/account-rollout.md`](../plans/account-rollout.md) picks **Resend**
for transactional mail. The account release depends on that channel for more
than sign-in: invitations to addresses with no account
([DESIGN-015](../design/015-accounts-and-iam.md) §6.4), verifying a second
address for the Apple-relay case (§3.5), bounce events that render on a member
row (§6.2), and security notices.

The vendor was chosen **with a known revisit condition already on the table.**
Resend stores account data — including recipient addresses — in the US under
SCCs and EU-US Data Privacy Framework certification; its `eu-west-1` is a
*sending* region, not residency. If EU residency ever becomes a hard
requirement from a korps or an HRS partner, SES `eu-north-1` is the fallback
and residency is the one axis Resend loses on. A vendor decision taken with its
own revisit trigger written down is exactly when to put a seam in — not after
the trigger fires.

[ADR-0073](./0073-auth-mode-and-adapters.md) already forces part of this to
exist: `AUTH_MODE=mock` must short-circuit the *whole* mail channel, not one
endpoint, so something already sits between the callers and the vendor. This
ADR decides what that something is, and — more importantly — which parts of the
mail integration are ours rather than the vendor's.

## Decision drivers

* A provider change must not mean re-authoring email content or re-deriving
  what a bounce means.
* The parts that genuinely differ between vendors have to be isolated: webhook
  shape and authentication, message identifiers, retry and error semantics.
* **Do not build an abstraction over email.** Cover what RingDrill actually
  sends — a handful of transactional messages — and let each adapter do
  vendor-specific work behind it.
* One seam, not two: ADR-0073's `mock` and a future `ses` are the same kind of
  thing, and should be the same mechanism.
* Email content is **content**: it needs review, diffs, and both `nb` and `en`
  like every other user-facing string in the app.

## Considered options

* **Option A — Call the vendor SDK at each send site.** Least code today. Every
  call site becomes a migration later, and `mock` has to be faked at each one.
* **Option B — One `MailSender` interface selected by `MAIL_PROVIDER`
  (chosen).** Same shape as ADR-0073's `AUTH_MODE`, so there is one pattern to
  learn rather than two.
* **Option C — A transport abstraction library** (nodemailer and friends).
  Solves SMTP portability well, which is not the problem: bounce webhooks and
  delivery events sit outside its model, and that is precisely where the
  lock-in lives.

## Decision outcome

Chosen: **B**, with three things deliberately kept on our side of the seam.

### The seam

```
MAIL_PROVIDER = resend | ses | mock | console
```

`resend` when unset, matching ADR-0073's rule that an unconfigured deploy gets
production behaviour. A **missing API key fails at startup, not at first
send** — a mail channel that appears healthy until the first invitation is
worse than one that refuses to boot.

`console` prints the rendered message instead of sending it, for local work
where even the mock's response-body shortcut is more indirection than a
developer wants. `mock` is ADR-0073's: it returns codes and invite links in the
response body so the flows run end to end.

The interface covers what we send and nothing more:

```
sendMail({ to, template, params, locale, idempotencyKey }) -> { messageId }
```

### 1. Templates are ours, and this is the main lock-in trap

Both Resend and SES offer hosted templates. Using them is the single decision
that would make a provider change expensive, and it is invisible until the day
you try to leave — the content is in a console somewhere, unversioned and
un-reviewed.

Templates therefore live in `netlify/functions/_email/` as functions returning
`{ subject, html, text }`, rendered **before** the adapter is called. The
adapter receives finished bytes. That also makes them diffable, reviewable, and
localisable like every other string in the project.

**Which language.** Two different signals, so two rules:

* A message caused by a request — magic link, address verification — uses the
  **requesting client's locale**, which the request already carries.
* An **invitation** uses the **inviting user's locale**. It is the only signal
  available for someone who has no account yet, and a Norwegian korps inviting
  a Norwegian colleague is the common case. Guessing from the address domain
  would be worse than useless.

### 2. Events are normalised, and the raw payload is kept

Resend posts a signed webhook; SES publishes to an SNS topic requiring
subscription confirmation and signature verification. Different shapes,
different authentication, same meaning. Each provider gets its own webhook
endpoint whose only job is to authenticate the request and normalise it:

```
MailEvent { type: delivered | bounced | complained | deferred,
            messageId, recipient, at, raw }
```

Everything downstream — including DESIGN-015 §6.2's "Email bounced" member
row — reads `type` only. **`raw` is stored alongside**, because normalising
throws away provider detail (Resend distinguishes bounce sub-types that the
common vocabulary flattens), and a support question six months later is the
moment that detail matters.

### 3. Message identifiers are namespaced

Stored as `resend:abc123`, not `abc123`. A provider change cannot collide with
historical records, and an old event says which vendor produced it without a
lookup table.

### What is deliberately not abstracted

Scheduling, marketing sends, attachments, analytics, suppression lists. None of
those are things RingDrill sends. If one becomes necessary, the interface is
extended deliberately — the failure mode to avoid is a vendor-specific option
leaking through a `providerOptions` escape hatch, which is how these interfaces
usually rot.

### Consequences

* Good: a provider change is one adapter plus one webhook normaliser, with no
  content to re-author and no downstream code to touch.
* Good: ADR-0073's `mock` requirement is satisfied by the same seam rather than
  by a parallel mechanism.
* Good: email content is reviewed, versioned and localised like the rest of the
  app's strings, instead of living in a vendor console.
* Good: keeping `raw` means normalisation is lossless in practice, so the
  common vocabulary can stay small without regret.
* Bad: an interface is a bet on what stays stable across vendors. The first
  genuinely provider-specific feature we want will strain it, and the honest
  response then is to widen the interface rather than punch a hole through it.
* Bad: two webhook endpoints exist during any migration. That is also the
  migration path — run both, compare, cut over — but it is real code carried
  for the duration.
* Bad: rendering before the adapter means we own deliverability details that a
  hosted template would have handled, notably HTML-email quirks across clients.
  Mitigated by keeping the templates plain: one column, no layout tables beyond
  the container, text part always present.

## Pros and cons of the options

### A. Vendor SDK at each send site

* Good: nothing to design, least code for the first message.
* Bad: every call site is a migration, and there will be more call sites than
  the four we can currently name.
* Bad: ADR-0073's `mock` has to be faked per site, which is the shape that
  makes dev and production diverge.

### B. `MailSender` selected by `MAIL_PROVIDER` (chosen)

* Good: one seam, one pattern shared with `AUTH_MODE`.
* Good: the expensive parts — templates, event meaning — never reach the
  vendor.
* Bad: an interface to maintain, and a guess about what stays stable.

### C. Transport abstraction library

* Good: mature, and solves SMTP portability thoroughly.
* Bad: solves the part that is not hard. Bounce webhooks and delivery events
  are outside its model, and they are where the lock-in actually is.
* Bad: another dependency for a seam that is a few dozen lines.

## Links

* Related ADRs:
  [ADR-0006](./0006-sentry-behind-consent-gate.md),
  [ADR-0013](./0013-local-catalog-testing.md),
  [ADR-0024](./0024-account-and-identity-model.md),
  [ADR-0072](./0072-staff-pii-and-account-sync.md) — the residency criterion
  that could trigger a provider change,
  [ADR-0073](./0073-auth-mode-and-adapters.md) — the same adapter pattern, and
  the reason a mail seam has to exist at all
* Related designs:
  [DESIGN-015](../design/015-accounts-and-iam.md) §3.3, §3.5, §6.2, §6.4
* Related plans:
  [`account-rollout.md`](../plans/account-rollout.md) — where Resend is chosen
* Related code:
  `netlify/functions/lib/mail/` (adapters),
  `netlify/functions/_email/` (templates, both locales),
  `netlify/functions/mail-webhook-*.js` (per-provider normalisers)
