---
status: open
severity: medium
discovered: 2026-07-02
resolved: null
related_adrs: ["ADR-0039", "ADR-0044"]
---

# DEBT-0011: ADR-0039 post-cutover cleanup

## What

The ADR-0039 apex cutover is live and correct, but two loose ends remain from
the migration. They are not bugs — everything works — but each will mislead or
trip up the next contributor if left as is.

1. **Dead proxy lines in `site/public/_redirects`.** The `/api/*`,
   `/.netlify/functions/*`, `/d/*`, `/i/*` and `/brief/*` status-200 rewrites to
   `api.ringdrill.app` are no-ops: Cloudflare Pages cannot 200-proxy to an
   external origin. The real proxy is the `workers/apex-proxy/` Worker. The
   lines still read as if they route traffic.
2. **`/i/*` Worker route is a temporary bridge.** `workers/apex-proxy` proxies
   `/i/*` to the `drills-preview` function. When ADR-0044 lands the native
   Astro `/i/[slug]` route, this route must be removed from
   `workers/apex-proxy/wrangler.toml` (Worker routes take precedence over Pages,
   so the native route is unreachable until then).

Resolved (2026-07-02): the Phase 3c functions split and the stale
`deploy-web.yml` duplicate — see [History](#history) — are fixed.

## Where

* `site/public/_redirects` — the five dead 200-proxy lines.
* `workers/apex-proxy/wrangler.toml` — the `ringdrill.app/i/*` route to retire under ADR-0044.

## Why it is debt

Everything functions, so this is not a bug. It is debt because the config now
describes an intent that differs from reality. A contributor editing
`_redirects` could reasonably assume the proxy lines matter and waste time, or
worse, "fix" them and think they changed routing. Risk is low today but grows
as more people touch the hosting config.

## Suggested fix

* Delete the five dead proxy lines from `site/public/_redirects`, keeping only
  the vanity 301s. Add a one-line comment that apex dynamic paths are proxied by
  `workers/apex-proxy/`.
* When ADR-0044 ships, drop the `ringdrill.app/i/*` route from
  `workers/apex-proxy/wrangler.toml` and redeploy (see ADR-0044 step 4).

One-time operational item, not tracked here once done: purge the Cloudflare
cache for the apex after cutover so no stale landing-page responses survive for
dynamic paths.

## History

**2026-07-02: Phase 3c split done, `deploy-web.yml` deleted.** ADR-0039
(Implementation section) described replacing `deploy-web.yml` with per-origin
deploys, but `deploy-web.yml` had never been retired — on every push to `main`
it kept rebuilding the Flutter web artefact and pushing it to the old Netlify
site, duplicating what `deploy-pwa.yml` already deployed to Cloudflare Pages,
to a destination (`api.ringdrill.app`) meant to be functions-only. Fixed by
consolidating `functions`, `pwa` and `site` into three ordered, path-gated
jobs in one workflow, `.github/workflows/deploy-origins.yml` (`pwa`/`site`
`needs: functions`); `deploy-web.yml`, `deploy-pwa.yml` and `deploy-site.yml`
were deleted. The PWA now deploys to Cloudflare only.

## Links

* Related ADRs: [ADR-0039](../adrs/0039-site-pwa-api-origins.md), [ADR-0044](../adrs/0044-render-preview-on-site.md)
* Related code: `site/public/_redirects`, `workers/apex-proxy/`, `.github/workflows/deploy-origins.yml`, `netlify.toml`
