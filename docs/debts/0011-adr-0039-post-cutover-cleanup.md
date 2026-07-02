---
status: open
severity: medium
discovered: 2026-07-02
resolved: null
related_adrs: ["ADR-0039", "ADR-0044"]
---

# DEBT-0011: ADR-0039 post-cutover cleanup

## What

The ADR-0039 apex cutover is live and correct, but three loose ends remain from
the migration. They are not bugs — everything works — but each will mislead or
trip up the next contributor if left as is.

1. **Dead proxy lines in `site/public/_redirects`.** The `/api/*`,
   `/.netlify/functions/*`, `/d/*`, `/i/*` and `/brief/*` status-200 rewrites to
   `api.ringdrill.app` are no-ops: Cloudflare Pages cannot 200-proxy to an
   external origin. The real proxy is the `workers/apex-proxy/` Worker. The
   lines still read as if they route traffic.
2. **Phase 3c not executed.** ADR-0039 (Implementation section) describes a
   `deploy-functions.yml` that deploys only the Netlify functions. It does not
   exist; functions still ship via `deploy-web.yml` alongside the Flutter web
   build. The ADR reads as if the split is done.
3. **`/i/*` Worker route is a temporary bridge.** `workers/apex-proxy` proxies
   `/i/*` to the `drills-preview` function. When ADR-0044 lands the native
   Astro `/i/[slug]` route, this route must be removed from
   `workers/apex-proxy/wrangler.toml` (Worker routes take precedence over Pages,
   so the native route is unreachable until then).

## Where

* `site/public/_redirects` — the five dead 200-proxy lines.
* `.github/workflows/deploy-web.yml` — still bundles functions; no `deploy-functions.yml`.
* `docs/adrs/0039-site-pwa-api-origins.md` — Implementation section references `deploy-functions.yml` as if present (corrected with a dated note, but the split itself is pending).
* `workers/apex-proxy/wrangler.toml` — the `ringdrill.app/i/*` route to retire under ADR-0044.

## Why it is debt

Everything functions, so this is not a bug. It is debt because the config and
the ADR now describe an intent that differs from reality. A contributor editing
`_redirects` could reasonably assume the proxy lines matter and waste time, or
worse, "fix" them and think they changed routing. The missing functions-deploy
split means a `netlify/functions/**` change rebuilds and redeploys the whole
Flutter web artefact — slower, and it couples two unrelated deploys. Risk is low
today but grows as more people touch the hosting config.

## Suggested fix

* Delete the five dead proxy lines from `site/public/_redirects`, keeping only
  the vanity 301s. Add a one-line comment that apex dynamic paths are proxied by
  `workers/apex-proxy/`.
* Split functions out of `deploy-web.yml` into `deploy-functions.yml`
  (`netlify deploy --prod --dir=. --functions=netlify/functions`, triggered on
  `netlify/functions/**` and `netlify.toml`), per ADR-0039. Then `deploy-web.yml`
  only builds and deploys the Flutter web artefact.
* When ADR-0044 ships, drop the `ringdrill.app/i/*` route from
  `workers/apex-proxy/wrangler.toml` and redeploy (see ADR-0044 step 4).

One-time operational item, not tracked here once done: purge the Cloudflare
cache for the apex after cutover so no stale landing-page responses survive for
dynamic paths.

## Links

* Related ADRs: [ADR-0039](../adrs/0039-site-pwa-api-origins.md), [ADR-0044](../adrs/0044-render-preview-on-site.md)
* Related code: `site/public/_redirects`, `workers/apex-proxy/`, `.github/workflows/deploy-web.yml`, `netlify.toml`
