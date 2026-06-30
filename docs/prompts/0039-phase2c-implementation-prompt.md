# ADR-0039 Phase 2c — Cloudflare Pages deploy workflows

You are working in the RingDrill repository. Implement Phase 2c of [ADR-0039](../adrs/0039-site-pwa-api-origins.md). ADR-0039 is accepted and authoritative. Read the "Topology", "Deploy pipelines" and "Phase 2" sections before starting.

Phase 2a and Phase 2b have landed. Phase 2c adds the GHA workflows that deploy the Astro site and a Flutter-web artifact to Cloudflare Pages.

## Scope

Two new GHA workflow files. No code changes. The workflows are written and validated as YAML, ready to run as soon as the maintainer has:

* Created the Cloudflare Pages projects `ringdrill-site` and `ringdrill-pwa`
* Added `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` to the PROD GHA environment

Those steps are out-of-band for this prompt. The agent does not touch Cloudflare or DNS.

## Steps

### Step 1 — `deploy-pwa.yml`

Add `.github/workflows/deploy-pwa.yml`. Builds Flutter web and pushes to Cloudflare Pages project `ringdrill-pwa`.

Mirror the structure of the existing `deploy-web.yml`, but:

* Trigger on the same events (`push` to `main`, `workflow_dispatch`)
* Environment: `PROD`
* Secrets verification block lists `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `SENTRY_AUTH_TOKEN`
* Same Setup Flutter / pub cache / `flutter pub get` setup
* No `npm ci` (no Netlify functions in this artifact)
* Build via `make build-web`. **Do NOT set `MIGRATION_DISABLED`**. The new PWA on `web.ringdrill.app` does not show the migration banner (the host check in `isLegacyHost()` returns false for that subdomain), so the kill switch is irrelevant here. Including the env would be confusing noise.
* Keep `upload-symbols-web` and `strip-source-maps-web` steps (Sentry source map upload is the same as for Netlify-hosted PWA)
* Replace the Netlify CLI deploy step with:

```yaml
- name: Deploy to Cloudflare Pages
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
  run: |
    npx wrangler@latest pages deploy build/web \
      --project-name=ringdrill-pwa \
      --branch=main
```

* Drop the Lighthouse audit step from this workflow — Lighthouse stays on `deploy-web.yml` targeting apex until cutover, and the new PWA can grow its own audit step later if needed.

`concurrency: group: deploy-pwa` so two pushes do not race.

Commit: `ci(pwa): add Cloudflare Pages deploy workflow for new PWA`. Verify `git status` is clean.

### Step 2 — `deploy-site.yml`

Add `.github/workflows/deploy-site.yml`. Builds the Astro site at `site/` and pushes to Cloudflare Pages project `ringdrill-site`.

Triggers:

* `push` to `main` with `paths: [site/**, .github/workflows/deploy-site.yml]`
* `schedule: cron: '0 * * * *'` — hourly. Reserved for a future catalog index that needs to reflect new publishes without a manual rebuild. For Phase 2 there is no catalog data yet, so the cron is a no-op rebuild, but it is wired now so it is in place when needed.
* `workflow_dispatch`

Structure:

```yaml
- name: Checkout
  uses: actions/checkout@v6

- name: Setup Node
  uses: actions/setup-node@v6
  with:
    node-version-file: site/package.json
    cache: npm
    cache-dependency-path: site/package-lock.json

- name: Install site dependencies
  working-directory: site
  run: npm ci

- name: Build site
  working-directory: site
  run: npm run build

- name: Deploy to Cloudflare Pages
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
  run: |
    npx wrangler@latest pages deploy site/dist \
      --project-name=ringdrill-site \
      --branch=main
```

Environment: `PROD`. Secrets verification block: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

`concurrency: group: deploy-site, cancel-in-progress: true`.

Commit: `ci(site): add Cloudflare Pages deploy workflow for Astro site`. Verify `git status` is clean.

### Step 3 — Verification

* YAML files validate without errors. If `actionlint` is available locally, run it. Otherwise rely on GHA's parse check on the next push.
* The first push of either workflow will fail at the secrets verification block until the maintainer has added the Cloudflare secrets to the PROD environment. That is expected. The workflow files themselves are correct.
* `git status` clean

## Notes for the maintainer (kept in this prompt, not a separate runbook)

The workflows are deployable once these manual steps are done, in any order:

* Create Cloudflare Pages projects `ringdrill-site` and `ringdrill-pwa`. Leave them empty for now; the workflows will populate them on first run.
* Add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` to the PROD environment under Settings → Environments → PROD → Secrets.
* DNS records for `web.ringdrill.app` and `api.ringdrill.app` are needed before the new origins are reachable. That is a separate manual task and not blocking for the workflows themselves.

The first successful deploy of each workflow lands the artifact at `ringdrill-{site,pwa}.pages.dev`. Custom domains (`web.ringdrill.app`, etc.) are added in the Cloudflare project settings after that, when DNS is in place.

## Out of scope

* Any Cloudflare or DNS configuration
* Flipping `MIGRATION_DISABLED=false` — Phase 3
* Apex CNAME flip — Phase 3
* `_redirects` proxy rules — Phase 3
* Self-unregister SW stub — Phase 3
* Astro `/migrate` page — Phase 3
* `drills-preview` Netlify function — Phase 3
* Lighthouse audit on the new PWA workflow

## Definition of done

Two commits in order: `ci(pwa)` and `ci(site)`. Workflows are valid YAML. `git status` clean after every commit.
