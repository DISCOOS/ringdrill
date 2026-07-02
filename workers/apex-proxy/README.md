# apex-proxy

Reverse-proxy Worker for `ringdrill.app`. Restores 200-proxying of the dynamic
apex paths that Cloudflare Pages cannot proxy to an external origin after the
ADR-0039 Phase 3 cutover.

## What it proxies

Bound (see `wrangler.toml`) to these apex prefixes, forwarded verbatim to
`api.ringdrill.app`:

- `/api/*` — catalog / market-feed and other functions
- `/.netlify/functions/*` — legacy path used by cached PWAs
- `/d/*` — `.drill` downloads (deep-link alias)
- `/i/*` — share / install preview pages
- `/brief/*` — brief links (upstream 302 passes through)

Everything else on the apex stays on the `ringdrill-site` Pages project.

## Deploy

CI: `.github/workflows/deploy-proxy.yml` on push to `main` touching
`workers/apex-proxy/**`.

Manual: `npx wrangler@latest deploy` from this directory.

## Token permissions

Beyond the Pages permission used by `deploy-site.yml`, the
`CLOUDFLARE_API_TOKEN` needs:

- Account · Workers Scripts · Edit
- Zone · Workers Routes · Edit (`ringdrill.app`)
- Zone · Zone · Read (`ringdrill.app`)

## Verify after deploy

```bash
curl -sI  "https://ringdrill.app/d/<known-slug>"          # 200, application/vnd.ringdrill+zip, attachment
curl -s   "https://ringdrill.app/api/market-feed?limit=3" # JSON
curl -sI  "https://ringdrill.app/i/<known-slug>"          # 200 HTML preview
curl -sI  "https://ringdrill.app/brief/<known-uuid>"      # 302 to web.ringdrill.app
```

Static apex paths (`/`, `/migrate`, `/.well-known/*`) must still be served by
the Pages site — the Worker routes deliberately do not cover them.
