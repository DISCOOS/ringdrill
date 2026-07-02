---
status: resolved
severity: medium
discovered: 2026-07-02
resolved: 2026-07-02
related_adrs: ["ADR-0039", "ADR-0044"]
---

# DEBT-0011: ADR-0039 post-cutover cleanup

## What

Post-cutover loose ends from the ADR-0039 migration. **All resolved as of
2026-07-02** — see [History](#history). The three items were:

1. **Dead proxy lines in `site/public/_redirects`.** The `/api/*`,
   `/.netlify/functions/*`, `/d/*`, `/i/*` and `/brief/*` status-200 rewrites to
   `api.ringdrill.app` were no-ops: Cloudflare Pages cannot 200-proxy to an
   external origin. The real proxy is the `workers/apex-proxy/` Worker. Removed.
2. **Phase 3c functions-deploy split.** Done — `deploy-web.yml` retired, origins
   consolidated into `deploy-origins.yml`.
3. **`/i/*` Worker route is a temporary bridge.** `workers/apex-proxy` proxies
   `/i/*` to the `drills-preview` function. Retiring it is gated on ADR-0044
   landing the native Astro `/i/[slug]` route (Worker routes take precedence
   over Pages, so the native route is unreachable until then). This is now
   tracked solely in [ADR-0044](../adrs/0044-render-preview-on-site.md) step 4,
   not here.

## Where

* `site/public/_redirects` — dead 200-proxy lines removed; only vanity 301s remain.
* `workers/apex-proxy/wrangler.toml` — `ringdrill.app/i/*` route stays until ADR-0044 (tracked there).

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

**2026-07-02: Dead `_redirects` proxy lines removed.** The five no-op
status-200 proxy rules were deleted from `site/public/_redirects`, leaving the
vanity 301s plus a comment noting the apex dynamic paths are proxied by
`workers/apex-proxy/`. The `/i/*` Worker-route retirement was handed to ADR-0044
step 4, closing this debt.

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
