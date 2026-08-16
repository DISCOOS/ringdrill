---
status: proposed
date: 2026-08-13
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0079: Bound the open mail endpoint with a per-recipient rate limit

## Context and problem statement

`POST /api/auth/start-email` accepts any syntactically valid address and sends a
RingDrill-branded sign-in mail to it. It carries no token, and it cannot: the
email *is* how authentication starts, so at the moment it is called there is no
credential in existence to check. Requiring one would mean nobody could ever
sign in for the first time, or recover after losing a session. Every
magic-link, OTP and password-reset endpoint in every system is unauthenticated
for the same reason.

Nothing currently limits it. The only rate limiter in the codebase is
`lib/mcp-rate-limit.js`, scoped to MCP tool calls.

So anyone who finds the endpoint can make our infrastructure send mail, as
`ringdrill.app`, to an address of their choosing, at whatever rate they like.

The harm is not account compromise — the message contains a sign-in code for an
account the *recipient* controls, so a flood of them grants an attacker nothing.
The harm is threefold and the third one is the serious one:

* nuisance mail to uninvolved third parties, from our domain;
* the Resend quota, which is finite (3 000/month, 100/day on the free tier per
  the account rollout plan);
* **deliverability**. Spam complaints and bounces from unsolicited mail cost
  sending reputation, and sign-in mail is precisely the mail that cannot afford
  to land in a junk folder — the failure mode is a real user locked out of a
  tool they may be trying to use during an exercise.

## Decision drivers

* The endpoint cannot become authenticated. Any control has to work on an
  anonymous caller.
* A control must not make the endpoint reveal who has an account. `start-email`
  deliberately behaves identically for known and unknown addresses; a limit that
  answered differently would trade an abuse problem for an enumeration oracle.
* It must bound the harm to a *specific victim*, not merely the total volume.
  Per-source limiting alone is defeated by rotating the source.
* It must not lock out legitimate users. Someone who mistypes their address, or
  signs in from a conference wifi shared with other members, has to still get in.
* Netlify's declarative rate limiting is not available on this deploy path
  (ADR-0060, proven twice against production).

## Considered options

* Option A: Rate limit per recipient address **and** per source IP, in the
  function.
* Option B: Rate limit per source IP only.
* Option C: Put a backend-for-frontend in front of the endpoint.
* Option D: Client attestation — App Attest, Play Integrity, Turnstile.
* Option E: Invitation-only enrolment, so the endpoint will only mail addresses
  already known to the system.

## Decision outcome

Chosen option: **Option A**, because the per-recipient half is the only one of
these that bounds what an attacker can do to a *particular person*, and it does
so without any way to defeat it by changing where the request comes from.

The two limits do different jobs and both are needed:

* **Per recipient** — caps how much mail one address can be sent, counted
  regardless of who asked. No amount of IP rotation, proxying or distribution
  gets past it. This is what protects third parties and, through them, our
  sending reputation.
* **Per source IP** — caps how many *different* addresses one origin can enumerate
  through. This is what protects the quota and the function meter. It is the
  weaker of the two and is not relied on alone.

Enforced **in the function against a strongly consistent store**, the same shape
as `lib/mcp-rate-limit.js` and for the same reason recorded there: Netlify reads
declarative rate limit rules during a deploy's post-processing stage, and this
site deploys with `netlify deploy --prod --dir=. --functions=...`, which never
runs it. Both the `config` export and `[redirects.rate_limit]` forms parse
without complaint and register nothing. Blobs reads are eventually consistent by
default, and a counter built on a stale read does not accumulate.

**A refusal must be indistinguishable from a send.** The response shape, status
and body stay exactly as they are today, and the limit only suppresses the side
effect. Returning 429 here would answer a question the endpoint is carefully
built not to answer — an attacker could probe which addresses are being mailed,
and by extension which are worth targeting. This is the one place where the
usual advice to make rate limiting visible is wrong.

### Consequences

* Good: a specific person cannot be mailed more than the cap allows, by anyone,
  from anywhere.
* Good: no change to the client, and no change to what any caller observes.
* Good: reuses a pattern already in the codebase, including its hard-won
  consistency requirement.
* Bad: silent refusal means a legitimate user who has genuinely exhausted their
  own limit sees a sign-in mail simply not arrive. The cap has to be set high
  enough that this effectively cannot happen by accident, which in turn makes it
  a loose bound on an attacker.
* Bad: it costs a strongly consistent read and a write on every call to a
  pre-auth endpoint, on a metered platform.
* Bad: it does not stop a distributed attacker spreading a low rate across very
  many *different* addresses. That is bounded by the per-IP limit only, and
  imperfectly.

### Amendment, 2026-08-16: two windows, a refund, and a hint the client can give

Shipped with a single per-recipient cap of **3 an hour**, and production found
both ways that was wrong within a day of going live.

**The number was below normal use.** A first sign-in is not one send: a phone, a
tablet, a laptop and the PWA each need their own link, and at least one gets
retried because the mail was slow or landed in spam. Three an hour is reached by
using the product correctly — which is precisely what the consequence above says
the cap must never do.

Raising it alone does not work either, because one window has to serve two
purposes. The burst allowance has to cover that multi-device hour, and an hourly
cap permits that same burst *every* hour — at six, 144 messages a day to a chosen
inbox. So the recipient counter now has two windows, and they say different
things: **6 an hour** (a busy hour is normal) and **20 a day** (a busy day is
not). The daily figure is the one that bounds harassment; the hourly one only
smooths bursts. The per-source limit is unchanged.

**Quota was charged for mail that never left.** The counter is spent before the
send, because the decision is what gates it — but a mailer failure then charges
somebody for nothing and locks them out of retrying the thing that never
happened. That is not theoretical: three sign-in attempts that 500'd inside the
mailer emptied a real address's whole allowance without one message being sent,
and every refusal after it was silent. A failed send is now refunded. This does
not reopen enumeration: a provider outage looks identical for an address with an
account and one without.

**The silence is now broken by the client, not the server.** The response must
stay identical — that part of the decision is unchanged and is the reason a 429
is still not returned. But the *device* knows how many links it has asked for,
and that is our own history rather than an answer about the address, so saying
it leaks nothing. After a third request for the same address the sign-in screen
says several codes have been sent, to check spam, and that asking again may not
send another. It is deliberately hedged: the count is per screen, so links
requested elsewhere are invisible to it, and the server may have stopped sending
before it fires.

None of this changes the decision — it corrects three values and adds a
client-side affordance the original wrote off too quickly, by reading "the
caller cannot be told" as "nobody can say anything".

## Pros and cons of the options

### Option A: per recipient and per source (chosen)

* Good: bounds harm to an individual, which no source-based control can.
* Bad: two counters, and a silent-refusal design that is unusual enough to
  need the explanation above.

### Option B: per source only

* Good: simplest, and the conventional answer.
* Bad: defeated by rotating IPs, which is the cheapest thing an abuser can do.
  It protects our quota while leaving a chosen victim's inbox fully exposed —
  the wrong way round, since the quota is replaceable and the reputation is not.

### Option C: a backend-for-frontend

* Good: a natural place for cross-cutting request policy.
* Bad: **does not address this at all.** Whatever endpoint the BFF exposes is
  equally unauthenticated and equally callable, because the caller has no
  credential by definition. It moves the hop without adding a gate. RingDrill
  also ships native iOS and Android clients, so there is no secret the client
  could hold to prove it is ours — anything in the binary is extractable.

### Option D: client attestation

* Good: the *only* option that genuinely restricts callers to our own apps.
* Bad: per-platform integration on three clients, and it introduces a failure
  mode where a legitimate user on a rooted device, an unusual browser or a
  degraded attestation service cannot sign in. That is a real cost paid by real
  users against a threat that has not appeared. Held in reserve.

### Option E: invitation-only enrolment

* Good: shrinks the set of addresses the system will ever mail to people an
  existing owner deliberately invited.
* Bad: reintroduces enumeration — behaving differently for known and unknown
  addresses is exactly what the current design avoids — and still does not stop
  anyone flooding an address that *is* enrolled. It is also a product decision
  about how RingDrill onboards, not a security control, and was rejected on
  those grounds rather than technical ones.

## Links

* [ADR-0024: Account and identity model](./0024-account-and-identity-model.md) — the sign-in flow this protects.
* [ADR-0060: Remote MCP server](./0060-remote-mcp-server.md) — where the in-function rate limiting pattern and the Netlify deploy-path finding come from.
* [ADR-0075: Mail provider adapter](./0075-mail-provider-adapter.md) — the channel whose reputation this defends.
* [`docs/mail-setup.md`](../mail-setup.md) — the operational side, including what a leaked sending key would mean.
