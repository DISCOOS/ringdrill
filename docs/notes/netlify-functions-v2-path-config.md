# Netlify Functions v2 `path` config replaces the default URL

**Date:** 2026-07-01

## Context

During ADR-0039 Phase 2 we wanted to route `/api/*` URLs directly to Netlify functions without the `netlify.toml` redirect layer, so the same URL structure would work in production, in `netlify dev`, in `netlify functions:serve` and in the old cached PWA on apex.

Netlify Functions v2 supports per-function URL configuration via a named export:

```js
export const config = {
  path: "/api/market/feed",
};
```

Docs suggest this makes the function respond at the custom path in addition to the default `/.netlify/functions/<name>`. We wanted to verify that against `netlify functions:serve`.

## What we tried

Two experiments against `netlify functions:serve` on port 8888.

**1. Single string path**

```js
export const config = {
  path: "/api/market/feed",
};
```

Result:

* `GET /api/market/feed` → 200 with JSON. Custom path works.
* `GET /.netlify/functions/market-feed` → 404. The default URL is gone.

**2. Array path with both URLs**

```js
export const config = {
  path: [
    "/api/market/feed",
    "/.netlify/functions/market-feed",
  ],
};
```

Result:

* `GET /api/market/feed` → 200 with JSON. First entry works.
* `GET /.netlify/functions/market-feed` → 404. `functions:serve` prints a warning explicitly refusing the second URL because `/.netlify/functions/*` is a reserved internal routing prefix:

  ```
  Warning: Function market-feed cannot be invoked on
  /.netlify/functions/market-feed, because the function has the
  following URL paths defined: /api/market/feed,
  /.netlify/functions/market-feed
  ```

## What we found

Setting `path` (string or array) **replaces** the default `/.netlify/functions/<name>` URL rather than adding to it. There is no supported way to reach the function at both a custom path and the default path via `path` config alone. `/.netlify/functions/*` is reserved and cannot be declared as one of the custom paths, even in an array.

This is verified against `netlify functions:serve` v22.18.0. Behaviour in production or `netlify dev` may differ, but we did not test those because the replacement semantics already ruled out our use case.

## Implications

* **Do not use `path` config for gradual URL migrations** where old cached clients depend on the default URL. Setting `path` on a function immediately breaks the default URL for that function; any client (including the old apex PWA) that still calls `/.netlify/functions/<name>` will 404.
* **For dual-URL access, use `netlify.toml` redirects instead.** They route without replacing the default URL and are cheap.
* If a future refactor wants to move fully off `/.netlify/functions/*` (e.g. because the old PWA has been retired per ADR-0039 sunset criteria), `path` config becomes viable at that point.
* Netlify Functions v2 `path` is still useful for **new functions** that never had a default URL exposed publicly — declare the intended URL up front, done.

## Related

* [ADR-0039](../adrs/0039-site-pwa-api-origins.md) — site/PWA/API origin split, source of the `/api/*` refactor
* `netlify.toml` — the redirect layer we ended up using instead
* `lib/utils/app_config.dart` — `functionsBasePathFor` handles the local-dev vs production distinction on the client side
