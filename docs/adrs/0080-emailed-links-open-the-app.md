---
status: proposed
date: 2026-08-16
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0080: Emailed links open the app, and never act on load

## Context and problem statement

RingDrill sends two links by email, and **both are dead**.

Sign-in mail promises two ways in — the screen says so in as many words: *"We
sent a link and a six-digit code to you. Either one works."* Only the code
works. An invitation has no such fallback: the link is the entire message.

Both are built from `PUBLIC_APP_ORIGIN`, which defaults to the apex. Probed
2026-08-16:

| Emailed link | Apex | AASA | Intent filter | App route |
|---|---|---|---|---|
| `/auth/callback?c=&k=` — sign-in | **404** | ✗ | ✗ | ✗ |
| `/invite/<token>` — invitation | **404** | ✗ | ✗ | **✓ `/invite/:token`** |

Neither follows the shape the apex already uses for links people receive:
`/d/<slug>` to download, `/i/<slug>` to install, `/o/<path>` to open a shared
file. One is a two-segment backend-sounding path, the other a word.

So a person who taps either link — the obvious thing to do, and for an
invitation the *only* thing to do — lands on a 404. A sign-in recipient can
recover by finding the six characters further down the message. An invitee
cannot recover at all.

The invitation route already knows what it was supposed to be. Its own comment
says so:

> A real route rather than a dialog, because the link arrives by email and is
> opened cold — often on a device where nobody is signed in yet, and on mobile
> as a universal link into the installed app.

The route was built. The association entry and the served path never were.

**The sign-in path is also misnamed.** Three different things are called
`auth/callback` and only one of them is this:

| Path | Direction | What it is |
|---|---|---|
| `POST /api/auth/callback` | app → backend | Redeems a `{challengeId, code}`, a provider `idToken`, or a `handoff`, and returns tokens |
| `GET /api/auth/callback/<provider>` | provider → backend | Where a provider redirects the browser; the server exchanges the code and bounces to the app |
| `<apex>/auth/callback?c=&k=` | mail → device | The magic link — the only user-facing one, and the only one nothing serves |

The first two are backend endpoints on the API origin. The third borrows their
name for something else on a different origin, which is a collision that costs
nothing today and will cost somebody an afternoon later.

`/invite/` has no such collision. Its problem is only that it is the odd one
out.

Two further things shape the fix rather than merely following from it.

**Mail is scanned, and scanners follow links.** Corporate mail security and
link-preview generators fetch URLs before a human sees them, and both of these
links carry an action.

A sign-in challenge is single-use and deleted on redemption, so a page that
redeems on `GET` hands the user's sign-in to the scanner: by the time they tap,
the challenge is gone and they are told the link is "unknown or used". That
failure is unreproducible on the developer's machine, arrives only for users at
organisations that scan, and looks exactly like a bug in our flow rather than a
property of their mail provider.

An invitation is worse in kind rather than degree. Accepting on `GET` would
have a scanner join an organisation on somebody's behalf — a membership granted
by a machine that was checking for malware. `InvitePage` already gets this
right: it describes the invitation and accepts on a button press. The rule
below is therefore not a new invention, it is the behaviour invitations already
have, written down so the sign-in landing page matches it.

**The link is a bearer credential.** Anyone holding it can sign in as that
address until it expires or is used. That is equally true of the code, and is
inherent to email-based sign-in — but a URL is forwarded, pasted into chat and
kept in browser history far more casually than six characters are.

## Decision drivers

* Both links have to work on the two surfaces a person will actually open them
  on: a phone with the app, and a browser anywhere.
* An invitation has no fallback. A sign-in recipient can fall back to the code;
  an invitee who cannot open the link has nothing else to try.
* A universal link is only honoured for the host in the URL, and only if that
  host serves the association file. `ringdrill.app` already serves one;
  `web.ringdrill.app` serves none.
* A prefetch must not consume the challenge.
* The web fallback cannot be a dead end for somebody without the app.
* [ADR-0039](./0039-site-pwa-api-origins.md) put every shareable, deep-linkable
  path on the apex. A second link-bearing origin would split that.

## Considered options

* Option A: Serve the link path on the apex, proxied to a function, and register
  it as a universal link — the shape `/i/*` already uses.
* Option B: Point the link at `web.ringdrill.app` and let the PWA route it.
* Option C: Put a custom scheme (`ringdrill://…`) in the mail.
* Option D: Keep the apex URL and have the proxy Worker rewrite it to the PWA.

## Decision outcome

Chosen option: **Option A**, because the association files, the proxy Worker and
the precedent all already point at the apex, and because it is the only option
that opens the app *and* degrades to a working web page without registering a
second link-bearing origin.

Concretely:

1. **The sign-in link becomes `<apex>/s/<challengeId>/<code>`.** One letter,
   matching the convention the apex already uses for user-facing links —
   `/d/<slug>` for downloads, `/i/<slug>` for install links — rather than the
   long `/auth/callback`, which reads like the two backend endpoints above and
   is not either of them. `/s/` for sign-in matches the app's own vocabulary
   and leaves `/a/` free for accounts, which `/api/accounts/` and `AccountPage`
   would otherwise make ambiguous. Path segments rather than `?c=&k=`: shorter,
   and a plaintext mail that wraps a long URL breaks the link in some clients.
2. **The invitation link becomes `<apex>/j/<token>`** — `j` for join, which is
   what the recipient does and the verb the invitation itself uses. The app
   route moves with it; keeping `/invite/:token` internally would leave two
   names for one thing, which is the problem being fixed.

   Renaming a live route is normally not worth it. It is worth it here because
   **no invitation has ever been sent**: production holds no accounts (the
   ADR-0077 backfill scanned zero members and zero sessions on 2026-08-12), an
   invitation can only be sent by an account owner, and the link has never
   resolved anywhere regardless. There is nothing to keep working. That stops
   being true the first time somebody invites a colleague, and the cost only
   rises from there.
3. Both paths are added to the apex proxy Worker's routes and served by a
   function, mirroring `/i/*` ([ADR-0015](./0015-shareable-install-links.md)).
4. Both are added to the two copies of the association file
   (`web/.well-known/` and `site/public/.well-known/`) and to the Android
   intent filter, alongside `/i/` and `/o/`.
5. The app gains a `/s/` route that completes sign-in, and `/invite/:token`
   becomes `/j/:token` — the page behind it is unchanged.

**The association entry and the consumer ship together**, in one change, not as
"register now, wire later".

[DEBT-0001](../debts/0001-orphan-https-app-link-for-o-path.md) is this mistake
already made once and since fixed. `/o` was declared `autoVerify="true"` in the
Android manifest with no route behind it. Android re-runs App-Link verification
at every install and every app update, so the declaration had a standing cost
and no benefit — and worse, if verification ever *failed*, say after a signing
key rotation changed the fingerprint in `assetlinks.json`, the failure would be
logged and nothing would visibly break, precisely because nothing depended on
the link. A broken association is then discovered by the next feature that
needs one, where it presents as a bug in that feature. It was resolved by
ADR-0015's implementation giving the path a real consumer (`pathPrefix="/o/"`
reaching the existing Flutter `/o/` route) rather than by removing it.

iOS fails differently and just as quietly: a path absent from the AASA is not an
error, it simply opens Safari — indistinguishable from the feature not having
been built.

### A landing page never acts on load

**On the web, the page renders and waits for a tap.** It shows what is about to
happen — which address is signing in, which organisation is being joined — and
acts on a button, never on the `GET`. This is the whole defence against
prefetching, and it is worth the extra tap precisely because the failure it
prevents is invisible to us: it happens in somebody else's mail infrastructure
and reports back as "the link didn't work".

**In the app, opening *is* the tap.** A universal link only resolves to the app
because a human tapped it; no scanner opens an iOS app. So the app may act
immediately, and asking for a second confirmation there would be ceremony
protecting against nothing.

That asymmetry is the part of this most likely to be "tidied" into consistency
later. It is deliberate: the two surfaces have different adversaries.

### Consequences

* Good: the copy becomes true. Both halves of "either one works" work.
* Good: **invitations start working at all.** They have no fallback, so every
  invitation sent before this lands on a 404 and the invitee has nothing else
  to try.
* Good: on a phone with the app installed, both sign-in and accepting an
  invitation are one tap from the mail.
* Good: no new link-bearing origin, so ADR-0039's split holds and one
  association file governs every link RingDrill sends.
* Good: a prefetching scanner costs the user nothing.
* Bad: an extra tap on the web path, for a threat most users do not face.
* Bad: three more places that must agree, now for two paths — the Worker
  routes, the association files, the intent filter — and a mismatch is silent.
  A path missing from the AASA does not error; it just quietly opens Safari
  instead of the app, which looks like the feature was never built.
* Bad: `/d/`, `/i/`, `/o/`, `/s/` and `/j/` are terse to the point of being
  unguessable from outside the codebase. That is the price of the brevity, and
  the brevity is bought for a reason — these go in mail bodies, where a long URL
  wraps and a wrapped URL stops being a link in some clients.
* Bad: the credential is in a URL, so it reaches browser history and any access
  log along the way. Path segments rather than a query string keeps it out of
  the places that strip or redact `?…` specifically, but that is a small
  mitigation, not a fix. Bounded by the ten-minute TTL and single use, and no
  worse than the code it accompanies — but a URL is forwarded more casually than
  six characters, and that is a real difference in practice rather than in
  theory.
* Bad: the link and the code are one challenge, so whichever is used first wins
  and the other stops working. Somebody who taps the link on their phone and
  then types the code on their laptop will find the second attempt refused. The
  sign-in copy already avoids implying otherwise; this makes it a behaviour
  somebody will actually meet.

## Pros and cons of the options

### Option A: apex path, proxied and registered (chosen)

* Good: reuses a proven shape, an already-served association file, and an
  already-deployed Worker.
* Bad: a function and a Worker route for what is, on a phone, a redirect.

### Option B: point the link at the PWA origin

* Good: `web.ringdrill.app` already answers 200 there, so the web fallback needs
  no new function at all.
* Bad: that host serves no association file and appears in no intent filter, so
  **the app would never open** — the link would always land in a browser, which
  is most of what this ADR exists to fix. Registering it would mean a second
  link-bearing origin, splitting what ADR-0039 deliberately kept on the apex.

### Option C: a custom scheme in the mail

* Good: opens the app with no association file.
* Bad: many mail clients will not linkify a non-`https` scheme, there is no
  fallback for somebody without the app, and any application may claim a custom
  scheme — the operating system verifies nothing. A sign-in credential is the
  last thing to hand to an unverifiable handler.

### Option D: proxy rewrite to the PWA

* Good: keeps the apex URL, so the association file still governs.
* Bad: still needs the AASA entry and the app route, so it saves nothing over A
  while adding an origin hop to every sign-in.

## Links

* [ADR-0024: Account and identity model](./0024-account-and-identity-model.md) — the challenge the sign-in link redeems, and the invitation model behind the other.
* [ADR-0015: Shareable install links](./0015-shareable-install-links.md) — the `/i/*` shape this copies.
* [ADR-0021: iOS bundle identifier](./0021-ios-bundle-identifier-app-ringdrill.md) — the app IDs the association file names.
* [ADR-0039: Site, PWA and API origins](./0039-site-pwa-api-origins.md) — why link-bearing paths live on the apex.
* [ADR-0079: Rate limit on start-email](./0079-start-email-rate-limit.md) — the resend path a dead link currently forces people onto.
* [`docs/mail-setup.md`](../mail-setup.md) — the channel that carries the link.
