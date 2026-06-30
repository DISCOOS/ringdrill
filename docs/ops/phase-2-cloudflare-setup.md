# ADR-0039 Phase 2 — Cloudflare and DNS setup (wrangler-first)

Manual one-time setup for the Phase 2 infrastructure. Driven from the wrangler CLI where possible; the rest goes through the v4 API with curl or through the Cloudflare dashboard. Each step has a verify line so you know it worked before moving to the next.

Phase 1 is shipped to apex with `MIGRATION_DISABLED=true`. Phase 2 stands up `web.ringdrill.app` and `api.ringdrill.app` without touching the apex Netlify deploy. Apex moves to Cloudflare in Phase 3, not here.

## Prerequisites

* Cloudflare account with admin access. Sign up at <https://dash.cloudflare.com/> if you do not have one.
* GoDaddy account login for `ringdrill.app` (see [`docs/architecture.md`](../architecture.md#domain-and-hosting)).
* Node.js 20+ locally.
* `wrangler` available. We use it via `npx wrangler@latest` rather than installing globally so the version stays current.

Authenticate once:

```bash
npx wrangler@latest login
```

Browser opens, you authorise wrangler. After login:

```bash
npx wrangler@latest whoami
```

Prints your account email, account ID and a list of memberships. Note the account ID — you will need it.

```bash
export CF_ACCOUNT_ID=<the-id-from-whoami>
```

## 1. Add `ringdrill.app` zone to Cloudflare

Wrangler cannot create zones. Use the dashboard:

1. Dashboard → **Add a Site** → enter `ringdrill.app`.
2. Pick the Free plan unless you have a reason to pick higher.
3. Cloudflare scans the existing DNS at Netlify and auto-imports what it can see.

**Verify:** the new zone appears in your dashboard with imported records.

## 2. Compare with the Netlify DNS zone and re-create missing records

Log in at <https://app.netlify.com/>, find `ringdrill.app` in the DNS panel and list every record. Cross-check against the Cloudflare zone. Common gotchas:

* TXT records (SPF, DKIM, DMARC, ACME challenge) often need manual re-creation.
* MX records are easy to miss.
* Any third-party verification records.

Add anything missing via the Cloudflare DNS UI or with curl (see Step 8 for the curl pattern).

**Verify:** `dig ringdrill.app ANY @1.1.1.1` shows the expected record set when queried via Cloudflare nameservers (though the nameservers are not yet authoritative — see Step 3).

## 3. Switch nameservers at GoDaddy

The Cloudflare zone overview shows two nameservers (something like `*.ns.cloudflare.com`). Update GoDaddy:

1. Log in at <https://godaddy.com/>.
2. **My Products** → **Domains** → `ringdrill.app` → **DNS**.
3. **Nameservers** → **Change** → **Enter my own nameservers (advanced)**.
4. Paste the two Cloudflare nameservers. Save.

Propagation: typically minutes to a few hours; up to 48 hours worst case.

**Verify:** `dig ringdrill.app NS @1.1.1.1` returns the Cloudflare nameservers. Cloudflare's dashboard also shows a green check on the zone overview once propagation completes.

## 4. Create the two Cloudflare Pages projects

Wrangler creates Pages projects directly:

```bash
npx wrangler@latest pages project create ringdrill-site \
  --production-branch=main

npx wrangler@latest pages project create ringdrill-pwa \
  --production-branch=main
```

Both should report success. List to confirm:

```bash
npx wrangler@latest pages project list
```

**Verify:** both projects appear under your account in the Cloudflare dashboard (Workers & Pages).

## 5. Create the API token for GitHub Actions

Wrangler login authorises your laptop, but GitHub Actions needs its own token. Create one via the dashboard (wrangler cannot generate API tokens):

1. Dashboard → **My Profile** → **API Tokens** → **Create Token**.
2. **Use template** → **Custom token**. Click **Get started**.
3. Permissions:
   * `Account` → `Cloudflare Pages` → `Edit`
   * `Zone` → `DNS` → `Edit` (limit to `ringdrill.app`)
4. **Account Resources**: include your account.
5. **Zone Resources**: include `ringdrill.app`.
6. Create. The token is shown **once** — copy it.

Save it locally for the GitHub step coming up:

```bash
export CF_API_TOKEN=<the-token>
```

## 6. Add secrets to the PROD environment in GitHub

The two new workflows (`deploy-pwa.yml`, `deploy-site.yml`) read `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from the `PROD` environment, same as the existing Netlify secrets.

1. GitHub repo → **Settings** → **Environments** → **PROD**.
2. **Add secret**: `CLOUDFLARE_API_TOKEN` = the token from Step 5.
3. **Add secret**: `CLOUDFLARE_ACCOUNT_ID` = the account ID from `whoami`.

**Verify:** trigger one of the new workflows via **Actions** → **deploy-pwa** → **Run workflow**. The secrets-verification block at the top of the workflow either passes or prints which secret is missing.

## 7. Trigger first deploys

Push a no-op commit, or use `workflow_dispatch`:

```bash
gh workflow run deploy-site.yml
gh workflow run deploy-pwa.yml
```

Or via the Actions tab in the GitHub UI.

**Verify:**

* `https://ringdrill-site.pages.dev/` loads the Astro landing page.
* `https://ringdrill-pwa.pages.dev/` loads the Flutter PWA shell.

The `*.pages.dev` URLs are Cloudflare's default deploy URL for each project. Custom domains come next.

## 8. Add DNS records for `web.ringdrill.app` and `api.ringdrill.app`

Wrangler does not manage DNS records, so use curl against the v4 API. First, find the zone ID:

```bash
curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=ringdrill.app" \
  | jq -r '.result[0].id'
```

```bash
export CF_ZONE_ID=<the-zone-id>
```

Add `web.ringdrill.app` → `ringdrill-pwa.pages.dev` (proxied, so Cloudflare's CDN handles caching):

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "web",
    "content": "ringdrill-pwa.pages.dev",
    "proxied": true
  }'
```

Add `api.ringdrill.app` → the existing Netlify site. Find the Netlify subdomain on the Netlify dashboard (Site settings → Domain management). Typically `ringdrill.netlify.app` or similar.

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "api",
    "content": "ringdrill.netlify.app",
    "proxied": false
  }'
```

`proxied: false` for api. Cloudflare's reverse proxy in front of Netlify Functions has bitten projects before with edge-caching mismatches and cold-start surprises. Keep the connection direct to Netlify for the API subdomain. Revisit after Phase 3 if there is a concrete reason.

**Verify:**

```bash
dig web.ringdrill.app
dig api.ringdrill.app
```

Both resolve. `web` returns Cloudflare proxy IPs, `api` returns Netlify's CNAME target.

## 9. Attach the custom domain to the Pages project

DNS now points at `ringdrill-pwa.pages.dev`, but the Pages project does not yet know that `web.ringdrill.app` is one of its domains. Attach it via the API (wrangler does not expose this yet in stable):

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/pages/projects/ringdrill-pwa/domains" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"name": "web.ringdrill.app"}'
```

Cloudflare provisions SSL automatically. Takes a minute or two.

**Do NOT attach `ringdrill.app` to `ringdrill-site` here.** Apex stays on Netlify until Phase 3.

**Verify:**

```bash
curl -I https://web.ringdrill.app/
```

Returns 200, with `cf-ray` header confirming Cloudflare is serving.

## 10. End-to-end smoke test

* Open `https://ringdrill.app/` in a fresh browser. The existing Flutter PWA on Netlify still loads. Banner is hidden because `MIGRATION_DISABLED=true`.
* Open `https://web.ringdrill.app/` in a fresh browser. The new PWA loads from Cloudflare.
* In the new PWA, confirm the catalog feed loads. `DrillClient` should be calling `api.ringdrill.app/.netlify/functions/market-feed` per ADR-0039's "API client configuration".
* On the apex PWA, force the migration banner on with the dev override (`RINGDRILL_FORCE_LEGACY_HOST=true` locally, or set `MIGRATION_DISABLED=false` once you are ready), export a `.drill` ZIP, then open `web.ringdrill.app` and import. Confirm plans land.

When this works, Phase 2 is done. The kill switch can be flipped to `false` as a deliberate activation step, separate from this cookbook.

## What NOT to do here

These are Phase 3, not Phase 2. Doing them now will break the running apex PWA:

* Attach `ringdrill.app` (apex) or `www.ringdrill.app` to `ringdrill-site`.
* Change the apex CNAME away from Netlify.
* Deploy a self-unregister SW stub to apex.
* Set `MIGRATION_DISABLED=false` in `deploy-web.yml` (that is an activation step, not a setup step).
* Move the Netlify functions to a new Netlify site or rename the existing one.

When Phase 3 is ready it gets its own cookbook.

## Troubleshooting

* **`wrangler whoami` shows the wrong account.** Run `npx wrangler@latest logout` then `login` again. Multiple accounts are common.
* **`pages project create` errors with "project already exists".** Someone created it via the dashboard. Skip the create step.
* **DNS record returns "Content for CNAME record is invalid".** The target must not have a trailing dot. Use `ringdrill-pwa.pages.dev`, not `ringdrill-pwa.pages.dev.`.
* **Custom domain attach errors with "domain already in use".** The hostname is attached to a different Pages project. Remove it there first.
* **`api.ringdrill.app` returns 404 from Netlify.** The Netlify site does not have the custom domain registered. Netlify dashboard → Site settings → Domain management → Add custom domain → `api.ringdrill.app`. Save and retry.
* **`web.ringdrill.app` returns a Cloudflare 522 or similar.** DNS has propagated but Cloudflare cannot reach the Pages backend. Wait one or two minutes; the first request after attach often takes a moment.

## Related

* [ADR-0039](../adrs/0039-site-pwa-api-origins.md) — the topology decision and the DNS plan
* [`docs/architecture.md` § Domain and hosting](../architecture.md#domain-and-hosting) — registrar and DNS facts
* `.github/workflows/deploy-pwa.yml` and `deploy-site.yml` — the workflows that consume the secrets created here
