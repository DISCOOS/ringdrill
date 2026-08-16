# Setting up outgoing mail

Step-by-step for Resend, the environment variables to set afterwards, and the
things about this particular mail channel that are easy to get wrong.

Companion to [ADR-0075](./adrs/0075-mail-provider-adapter.md) (why an adapter
seam rather than a provider SDK) and [ADR-0073](./adrs/0073-auth-mode-and-adapters.md)
(the auth modes this interacts with). The sibling doc for OAuth providers is
[`identity-provider-setup.md`](./identity-provider-setup.md).

## The rule this setup exists to keep

**No key ever enters the repository.** `RESEND_API_KEY` lives in Netlify
environment variables on the API site and is read at runtime, exactly like the
OAuth client secrets.

This matters more than the usual "don't commit secrets" reflex, because of what
this particular key does. It authorises sending mail **as `ringdrill.app`**. A
leaked key is not a data breach; it is a working phishing kit aimed at our own
users, who would receive genuine, correctly-signed mail from
`noreply@ringdrill.app` telling them to click something. SPF, DKIM and DMARC all
pass, because the mail really is from us.

So: a **sending-only** key, scoped in the Resend dashboard rather than a
full-access one, and rotated rather than shared.

## What is safe to write down

The DNS records are public by definition — SPF, the DKIM public key and DMARC
all live in the `ringdrill.app` zone and anyone can query them. Nothing is
revealed by documenting them, and this file may name them freely.

The API key and (when it exists) the webhook signing secret are the only
secrets here.

## Domain and sender

The verified domain is the **apex, `ringdrill.app`**, and the sender is:

```
RingDrill <noreply@ringdrill.app>      # DEFAULT_FROM, netlify/functions/lib/mail/index.js
```

Nothing overrides it. Neither `auth.js` nor `accounts.js` passes a `from`, so
`DEFAULT_FROM` is the sender on every message we send.

**The trap, recorded because it cost an afternoon:** this used to be
`noreply@mail.ringdrill.app`. A subdomain is a *separate domain* in Resend's
model, so with only the apex verified every send is refused as unverified —
after DNS looks completely correct, and with an error that arrives at the first
send rather than at boot. If you ever move the sender to a subdomain, verify
that subdomain in Resend as its own domain first.

Using the apex is the simpler choice and the one made on 2026-08-12. The
argument for a dedicated sending subdomain is reputational isolation: a bounce
storm on transactional mail cannot then affect anything else sent from the
apex. At RingDrill's volume that separation buys little, and the extra domain to
verify and monitor costs more than it saves.

### DNS

Resend issues the exact records when you add the domain; add them to the
`ringdrill.app` zone in **Cloudflare**, which is where the zone lives (see
[`backend.md`](./backend.md)). There are three kinds and each does a different
job:

* **SPF** (TXT) — says Resend's servers may send for this domain.
* **DKIM** (TXT or CNAME) — the public half of the signing key. Resend holds the
  private half; we never see it, which is also why there is nothing secret in
  this record.
* **DMARC** (TXT) — tells receiving servers what to do when SPF and DKIM
  disagree with the From address, and where to send reports.

Verification is Resend-side once the records resolve. Cloudflare's proxy does
not apply to TXT records, so nothing needs unproxying.

## Environment

On the **API site** (`api.ringdrill.app`) in Netlify:

```
RESEND_API_KEY = re_...        # required; sending-only scope
MAIL_PROVIDER  = resend        # optional — this is already the default
```

`MAIL_PROVIDER` selects the adapter (ADR-0075): `resend`, `ses`, `console` or
`mock`. Unset means `resend`, which is why a missing `RESEND_API_KEY` is a boot
failure rather than a silent no-op — `createMailer` refuses to construct an
adapter it cannot use, on the grounds that a mail channel which looks healthy
until the first invitation is worse than one that will not start.

## Local development

`make netlify-dev` sets `MAIL_PROVIDER=console` and `AUTH_MODE=mock`, so nothing
is sent and no key is needed. The console adapter prints the whole message —
subject, body, sign-in code and magic link — to the terminal running the server.

These are two separate seams and both are needed. `AUTH_MODE=mock` returns the
sign-in code in the response body so the flow can be completed without reading
mail at all; it does **not** imply a mail adapter. Leaving `MAIL_PROVIDER` at its
default locally makes `start-email` answer 500, because Resend refuses to boot
without a key.

To smoke-test against the real provider once the domain verifies:

```bash
LOCAL_MAIL_PROVIDER=resend RESEND_API_KEY=re_... make netlify-dev
```

`AUTH_MODE` stays `mock`, so the code still comes back in the response — but the
mail goes out for real, which proves the domain and sender line up before it
matters in production.

## Security considerations

### The provider can read every sign-in code

The magic link and the six-character code pass through Resend in plain text,
because Resend is what delivers them. Anyone with access to that account — or to
its logs — can read a sign-in credential in flight.

This is inherent to using an email service for email-based sign-in, not a flaw
in this setup, and it is the same trade every magic-link system makes. It is
written down because it is a real trust assumption that is otherwise invisible:
the security of a RingDrill account is bounded by the security of the Resend
account and of the user's mailbox. Treat Resend access with the same care as
production credentials, and prefer the OAuth providers where a person has one.

### `start-email` is unauthenticated, and cannot be otherwise

`POST /api/auth/start-email` accepts any address and sends mail to it, with no
token. That is not an oversight: the email *is* how authentication starts, so
there is no credential available to check. Requiring one would mean nobody could
ever sign in for the first time, or recover after losing a session.

The consequence is that anyone who finds the endpoint can make our
infrastructure send RingDrill-branded mail to an address of their choosing. The
harm is not account compromise — the message contains a sign-in code for an
account the *recipient* controls — but it is real:

* nuisance mail to uninvolved third parties, from our domain;
* spam complaints and bounces, which cost **deliverability**. Sign-in mail is
  precisely the mail that cannot afford to land in spam, because the failure
  mode is a user locked out;
* the Resend quota, which is finite (the rollout plan records 3 000/month and
  100/day on the free tier).

**The control is a rate limit**, in `lib/auth/start-email-limit.js`. Two
counters: **3 mails per address per hour**, counted whoever asks, and **20
attempts per source IP per hour**. The first is the one that matters — it cannot
be defeated by rotating IPs, so no one can flood a chosen person's inbox. The
second protects the quota and the function meter.

Both are overridable with `START_EMAIL_RECIPIENT_LIMIT` and
`START_EMAIL_SOURCE_LIMIT` if the caps prove wrong in practice.

Enforced in the function against a strongly consistent store, the same shape as
`lib/mcp-rate-limit.js` and for the same reason: Netlify's declarative rate
limiting is read during a deploy's post-processing stage, which this site's
deploy path never runs.

**A refusal is silent** — same response, same status, only the send suppressed —
because a visible 429 would tell a caller which addresses are being mailed, which
is the enumeration oracle the next section is about. Refusals are logged
server-side (`[auth] start-email suppressed by <recipient|source> limit`), which
is the only signal that somebody is working through addresses. It does not apply
under `AUTH_MODE=mock`, where three sign-ins an hour would make local testing
miserable and there is no production to protect.

See [ADR-0079](./adrs/0079-start-email-rate-limit.md).

Two alternatives were considered and rejected. A **BFF in front** moves the hop
without adding a gate: whatever endpoint it exposes is equally unauthenticated
and equally callable, and there is no secret a native app could hold to prove
otherwise. **Client attestation** (App Attest, Play Integrity, Turnstile) is the
only mechanism that genuinely restricts callers to our own apps, and remains
available if a determined abuser ever appears — but its failure modes cost real
users access, which is too high a price for a threat that has not materialised.

### Do not make the endpoint reveal who has an account

`start-email` creates a challenge for *any* syntactically valid address and
resolves identity only at `callback`. That is deliberate: answering differently
for known and unknown addresses would turn sign-in into an account-enumeration
oracle.

Anything added here — an "unknown address" error, a different status, a
noticeably faster response — breaks that property. If a future change needs to
treat known addresses differently, the response must stay identical in shape,
status and timing, and only the side effect may differ.

### The webhook endpoint does not exist yet

ADR-0075 specifies a per-provider webhook endpoint that authenticates the
request and normalises the payload into `MailEvent`. **Only the normaliser is
built** — `normalizeResendEvent`, covered by `netlify/tests/mail.test.mjs`.
Nothing calls it: there is no function and no redirect.

So there is currently no URL to give Resend, and bounces and complaints are
invisible. That matters more for sign-in mail than for most: a bounced magic
link is a person who cannot get in, and nothing reports it today.

When it is built, it **must verify the request signature** before trusting a
payload. An unauthenticated bounce endpoint lets anyone mark any address
undeliverable, which is a denial-of-service against a specific user's ability to
sign in.

## When something is wrong

* **Every send fails, DNS looks fine** — the sender's domain is not the verified
  one. Check `DEFAULT_FROM` against the domain in the Resend dashboard; a
  subdomain is a separate domain there.
* **`start-email` answers 500 locally** — `MAIL_PROVIDER` is at its `resend`
  default with no key. Use `make netlify-dev`, which sets `console`.
* **Mail sends but never arrives** — check the Resend activity log first; it
  distinguishes "not sent" from "sent and bounced", which are different
  problems. Bounces are not otherwise visible until the webhook exists.
* **Mail arrives in spam** — check that all three DNS records resolve, and that
  DMARC alignment passes. A recently verified domain also has no sending
  reputation, so early volume matters.

## Rotating or removing the key

Generate the replacement in the Resend dashboard, set it in Netlify, redeploy,
then revoke the old one — in that order, so no window exists where the deployed
functions hold a revoked key. Netlify environment changes only take effect on a
new deploy, which is the step most easily forgotten.
