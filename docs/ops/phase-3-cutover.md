# ADR-0039 Phase 3 — apex cutover checklist

Manual runbook for flipping `ringdrill.app` from Netlify (Flutter PWA) to Cloudflare (Astro site). Each step has a verify line. Do them in order.

Phase 3a landed the Astro assets on `ringdrill-site.pages.dev` (SW self-unregister stub, `/migrate` page, `_redirects` proxy, landing banner). Phase 3b landed the `drills-preview` function on `api.ringdrill.app`. This runbook is what makes them the live apex.

## Prerequisites

* Phase 3a and Phase 3b are merged to `main` and their deploys are green in GitHub Actions.
* `web.ringdrill.app` and `api.ringdrill.app` are healthy (Phase 2 smoke test passed).
* The `ringdrill-site` Cloudflare Pages project is deployed with the Phase 3a artefact.

Verify by opening the three sibling origins in a browser:

* `https://web.ringdrill.app/` — the new PWA loads
* `https://api.ringdrill.app/api/market-feed` — returns JSON
* `https://ringdrill-site.pages.dev/` — the Astro landing loads, contains the migration nudge when Flutter localStorage keys are seeded via devtools

## 1. Attach custom domain to `ringdrill-site`

Cloudflare Pages → `ringdrill-site` → **Custom domains** → **Set up a custom domain**.

* Add `ringdrill.app`.
* Add `www.ringdrill.app`.

Cloudflare provisions SSL automatically. Both should show `Verified`, `SSL: Active` after a few minutes.

**Verify:** the Pages project's custom domains list shows both. Do not proceed until SSL is active.

## 2. Flip DNS in Cloudflare

Cloudflare DNS → `ringdrill.app` zone.

Change the apex `CNAME` and the `www` `CNAME`:

* From: `ringdrill.netlify.app` (or the imported flattened A/AAAA records)
* To: `ringdrill-site.pages.dev`
* Proxy status: **Proxied** (orange cloud) — required for Cloudflare Pages to receive the traffic.

**Verify:** from a couple of resolvers:

```bash
dig ringdrill.app @1.1.1.1
dig ringdrill.app @8.8.8.8
```

Should resolve to Cloudflare edge IPs. Propagation usually happens within a minute inside Cloudflare's own network; up to a few hours globally.

## 3. Wait for the SW-unregister stub to spread

Cached legacy Flutter PWA installs still have the old apex SW registered. On their next visit to `ringdrill.app`, they will:

1. Fetch `flutter_service_worker.js` from apex (now Cloudflare Pages).
2. Get the Phase 3a self-unregister stub instead of the Flutter SW.
3. Install the stub as "waiting" (old SW keeps serving until clients close).
4. On next reload, the stub activates, unregisters, clears caches, and posts a message to controlled clients.
5. Reload lands on the Astro site.

This is per-user and happens as each returns to the app. Nothing to do here except observe.

## 4. Smoke tests

Run these against `ringdrill.app` in a fresh browser session (no cached SW):

### Astro landing loads

* Open `https://ringdrill.app/`.
* Verify the Astro landing renders (not a Flutter loader).
* If you seed `localStorage` with a dummy `p:test-uuid` key via devtools, the migration nudge banner appears.

### Migration page works

* Open `https://ringdrill.app/migrate` directly.
* Confirm the page renders and offers export when Flutter localStorage is present.

### Slug preview and brief preview (regression watch)

Pre-cutover, `/i/*` and `/brief/*` were served by `netlify.toml` redirects on apex Netlify. Post-cutover, apex is Cloudflare and those paths are proxied to `api.ringdrill.app` via `_redirects`. Verify both work end-to-end:

```bash
curl -i "https://ringdrill.app/i/<known-published-slug>"
curl -i "https://ringdrill.app/brief/<known-uuid>"
curl -i "https://ringdrill.app/brief/program/<known-program-uuid>"
```

Expected:

* `/i/<slug>` → 200 with HTML preview (from `drills-preview` on Netlify, proxied through Cloudflare)
* `/brief/<uuid>` → 302 redirect to `web.ringdrill.app/brief/<uuid>` (interim per ADR-0041 spec)
* `/brief/program/<uuid>` → 302 redirect to `web.ringdrill.app/brief/program/<uuid>`

If any of these break, `_redirects` in the Astro build is likely missing or the api subdomain does not resolve to the drills-preview function correctly. Check both.

### Deep-link and .drill download

* `curl -I "https://ringdrill.app/d/<known-slug>"` → 200 with `Content-Type: application/vnd.ringdrill+zip` and `Content-Disposition: attachment`.
* Universal Link / App Link behavior on mobile is unchanged (native app captures the URL before browser fetch).

### API surface

* `curl "https://ringdrill.app/api/market-feed?limit=5"` → JSON (proxied to api subdomain).
* `curl "https://ringdrill.app/.netlify/functions/market-feed?limit=5"` → JSON (proxied). This is the legacy path old cached PWAs use; it must keep working while any legacy PWAs are still on cache.

### .well-known files

* `curl -I "https://ringdrill.app/.well-known/assetlinks.json"` → 200, `Content-Type: application/json`.
* `curl -I "https://ringdrill.app/.well-known/apple-app-site-association"` → 200, `Content-Type: application/json`.

Both should return the byte-identical files that were previously served from Netlify. Any change here breaks Android App Links and iOS Universal Links.

## 5. Post-cutover cleanup

* Phase 3c: split `deploy-web.yml` into `deploy-functions.yml` — separate prompt.
* Observe sunset telemetry in Sentry: `boot on legacy apex` events should decay toward zero over the coming weeks.

## Rollback

If something goes wrong within the first 30 minutes:

* Cloudflare DNS → revert apex and `www` CNAMEs back to `ringdrill.netlify.app`. Set proxy status to **DNS only** (gray cloud) so Netlify continues to serve without Cloudflare in the path.
* Detach `ringdrill.app` from the `ringdrill-site` Pages project.
* Deploy will roll back in seconds inside Cloudflare's network; a few minutes globally.

The Astro build, Phase 3b functions and PWA on `web.ringdrill.app` remain in place — they can serve their sub-audiences even while apex is on Netlify.

## Post-cutover open items

* [DEBT-...?]: Legacy PWA `/i/<slug>` regression. Pre-cutover the Netlify `/i/*` → `drills-preview` redirect made click-throughs render a preview instead of routing directly in the Flutter PWA. Post-cutover the legacy PWA is gone anyway, so the regression closes itself. No fix needed unless we get user reports that predate the cutover.

## Related

* [ADR-0039](../adrs/0039-site-pwa-api-origins.md) — the site/PWA/API origin split
* [`docs/ops/phase-2-cloudflare-setup.md`](./phase-2-cloudflare-setup.md) — the Phase 2 setup cookbook
* [`docs/notes/`](../notes/) — episodic findings from the migration
