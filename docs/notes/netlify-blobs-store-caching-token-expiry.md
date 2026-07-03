# Don't cache `getStore()` results across invocations

**Date:** 2026-07-03

## Context

A user reported "Oppdater fra katalog" intermittently failing with a snackbar
reading "Utilgjengelig" (generic "catalog service unavailable"), and later,
after an unrelated fix made the failure mode more visible, with a specific
"HEAD error: Netlify Blobs has generated an internal error (Failed to decode
token: Token expired)" surfacing from `drills-head.js`. The confusing part:
the *same* endpoint, for the *same* plan, would work fine on one request and
fail on another a couple of minutes later — no code change in between.

## What we found

`netlify/functions/_shared.js` had:

```js
let _drillsStore, _slugIndexStore;
export function getDrillsStore() { _drillsStore ||= getStore(NS.DRILLS); return _drillsStore; }
export function getSlugIndexStore() { _slugIndexStore ||= getStore(NS.SLUG_INDEX); return _slugIndexStore; }
```

— a `let` + `||=` memoization at module scope, so the `Store` object returned
by `getStore()` is created once per warm function container and reused for
every subsequent invocation that container handles.

`@netlify/blobs`'s `Store` bakes its access token into the object **at
construction time** (`node_modules/@netlify/blobs/dist/main.d.ts`: `Store`
has a `private token`, set from `InternalClientOptions` in the constructor).
That token comes from a **per-invocation** environment context that
Netlify's own runtime wrapper refreshes on every request — see
`connectLambda` → `setEnvironmentContext` in the same package, which decodes
a fresh `token` out of the incoming Lambda `event` on every single
invocation.

Put those two facts together: a warm container's cached `Store` keeps using
whichever token was current on its *first* invocation, for its entire
lifetime. Once that token's validity window passes, every request served by
that specific warm container starts failing with "Token expired" — while a
different warm container (or a freshly cold-started one, e.g. right after a
deploy) still has a live token and works fine. That is exactly the
"intermittent, seemingly random, un-reproducible" symptom that was reported:
it isn't random at all, it's a function of *which container* served the
request and *how long that container has been warm*.

`getStore()` itself is a cheap, synchronous client construction — it does no
network I/O — so there was never a real performance reason to cache it.

## Implications

* **Never cache a `@netlify/blobs` `Store` (or anything built from `getStore()`/`getDeployStore()`) across invocations.** Call it fresh inside the request handler every time. This applies to any Netlify Function in this repo, not just `_shared.js` — if a future function rolls its own store access instead of using the shared helpers, it must follow the same rule.
* This is an easy mistake to reintroduce because the `let x; export function get() { x ||= create(); return x; }` shape is completely idiomatic, correct JS for lazily creating something *once* — it is only wrong here because of the credential-lifetime coupling specific to `Store`. A reviewer skimming a future refactor could easily see this pattern and assume it's a harmless (even desirable) memoization and leave it alone, or reintroduce it while "cleaning up" `_shared.js`.
* The original intent when this was written (see `git show efa1886 -- netlify/functions/_shared.js`, 2025-08-15, "upgraded to @netlify/blobs ^10.0.8") was reasonable — avoid calling `getStore()` at module-load/import time, before the Netlify runtime has necessarily set up its environment context. That part is still worth keeping. The mistake was conflating "defer creation until first use" with "reuse the same instance forever": the fix keeps the *lazy* part (nothing runs at import time) and drops the *cached* part (a fresh `Store` is constructed on every call).
* This bug shipped with the very first `getStore()`-based version of `_shared.js` (2025-08-15) and was live for roughly eleven months before being precisely diagnosed — it was very likely the unexplained cause of prior sporadic catalog-refresh/upload failures that got attributed to "flaky network" rather than root-caused.
* If you see a "Failed to decode token: Token expired" (or similarly worded credential-expiry) error from any Netlify Blobs call anywhere in this codebase in the future, check for exactly this pattern first before assuming it is a Netlify-side outage.

## Related

* Fix: `netlify/functions/_shared.js`, `getDrillsStore()` / `getSlugIndexStore()` — commit that removed the caching (see inline comment there for the short version of this note).
* [ADR-0039](../adrs/0039-site-pwa-api-origins.md) — site/PWA/API origin split; `functions` → `api.ringdrill.app` is one of the three deploy targets whose Blobs access this affects.
* A separate, unrelated bug was found and fixed in the same investigation: `drills-head.js` didn't recognize the `/api/drills-head/*` URL alias (only `/api/drills/head/*`), so every HEAD request resolved a garbled slug. Both bugs were live at once and briefly conflated during diagnosis — the alias bug produced a clean "Unknown slug" 404 for a valid plan, and the token-expiry bug (this note) produced a 500 for the same request a few minutes later, depending on which warm container handled it.
