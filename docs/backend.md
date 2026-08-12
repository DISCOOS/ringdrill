# Backend, hosting and local dev

The HTTP API surface (endpoints, auth, examples) is documented in [`api.md`](./api.md). This file covers the backend runtime, the hosting topology across origins, and running the stack locally.

## Domain and hosting

The [ADR-0039](./adrs/0039-site-pwa-api-origins.md) three-origin split has landed. Deploys are GitHub-Actions-only (`.github/workflows/deploy-origins.yml` for the three origins; `deploy-proxy.yml` for the apex proxy Worker) — Netlify/Cloudflare auto-publish is off.

* **Registrar:** `ringdrill.app` is registered with **GoDaddy** (DISCOOS account), used for nameserver delegation only.
* **DNS / zone:** the `ringdrill.app` zone is on **Cloudflare**.
* **`ringdrill.app` (apex) — site:** a **Cloudflare Worker** (`ringdrill-site`) — the Astro site built via the `@astrojs/cloudflare` adapter, which emits a Workers bundle (the same-named Pages project is retired). A separate **apex reverse-proxy Worker** (`workers/apex-proxy/`, deployed by `deploy-proxy.yml`) restores 200-proxying of the dynamic apex paths Cloudflare Pages could not proxy itself (ADR-0039 Phase 3).
* **`web.ringdrill.app` — PWA:** the Flutter PWA on **Cloudflare Pages** (`ringdrill-pwa`), deployed with `wrangler pages deploy build/web`.
* **`api.ringdrill.app` — API:** **Netlify functions** only (`netlify/functions/**`), no static hosting.
* **SSL:** issued and renewed automatically by each provider. No manual cert handling.

**Direction (to-be, not started):** consolidate the backend onto a self-hosted rig.

## Blob store indexes

Two stores hold no data of their own and exist only to make a per-user lookup cheap: `member-index` (`<userId>/<accountId>`) and `session-index` (`<userId>/<sessionId>`). Without them, `membershipsOf` and `sessionsOf` walk every membership — or every session — in the system to answer a question about one user, on the hottest path in the API. See [ADR-0077](./adrs/0077-reverse-indexes-for-per-user-lookups.md) for why they carry no `role` and why deletion ignores them.

Both are self-healing: a read that finds nothing indexed falls back to the old scan and indexes what it finds, so nothing has to be run in any particular order. The backfill just decides *when* the remaining scans stop rather than whether the system is correct.

```bash
curl -s -X POST "https://api.ringdrill.app/api/drills-admin?action=backfill-indexes" -H "Authorization: Bearer $RINGDRILL_ADMIN_TOKEN" | jq
```

That is a dry run. Add `&dryRun=false` to write. It is additive and idempotent — it creates derived keys and deletes nothing, so a re-run costs a duplicate pass and nothing else.

## Running the backend locally

The full Netlify stack (functions plus an emulated blob store) can be run on a contributor machine without touching production. The architectural rationale is in [ADR-0013](./adrs/0013-local-catalog-testing.md).

Prerequisites: Node 20+ and the [Netlify CLI](https://docs.netlify.com/cli/get-started/) (`npx netlify` will fetch it on first use).

Start the backend:
```bash
make netlify-dev
```
The target runs `npm install` and `ADMIN_TOKEN=dev-token npx netlify functions:serve --port 8888`. Override the token with `make netlify-dev LOCAL_ADMIN_TOKEN=<token>`. Functions are now reachable at `http://localhost:8888/.netlify/functions/<name>`. The blob store is emulated under `.netlify/blobs-serve/`.

The target uses `netlify functions:serve` instead of `netlify dev` because the latter sets up an Edge Functions runtime that fails to install reliably on some macOS hosts. We do not use edge functions, so `functions:serve` is sufficient.

Caveat: the redirects defined in `netlify.toml` (`/api/*` and `/d/*`) are not applied by `functions:serve`. `DrillClient` already calls `/.netlify/functions/*` directly, so the CLI commands `upload`, `feed`, `list-all`, `publish` and friends all work. `ringdrill download <slug>` uses the `/d/<slug>` deep-link path and will return 404 in this mode.

Seed the catalog, inspect the feed, or reset the blob store:
```bash
make catalog-seed     # uploads $(SEED_DRILL) and publishes it
make catalog-feed     # lists /.netlify/functions/market-feed
make catalog-reset    # clears .netlify/blobs-serve (with the backend stopped)
```
`SEED_DRILL` defaults to `test/fixtures/test-7x.drill`. Override with `make catalog-seed SEED_DRILL=path/to/other.drill` to publish a different file.

Under the hood these targets shell out to `dart run bin/ringdrill.dart`, which gained three public commands (no admin token required):
```bash
ringdrill upload <file.drill> [--published] [--tags=a,b,c] [--owner=<id>]
ringdrill feed [--limit=N] [--cursor=C]
ringdrill download <slug> [--out=<file>] [--version=N]
```
The CLI honors `RINGDRILL_BASE_URL`, so the same binary works against the local backend without rebuilding:
```bash
export RINGDRILL_BASE_URL=http://localhost:8888
export RINGDRILL_ADMIN_TOKEN=dev-token
ringdrill list-all
ringdrill publish <slug>
```

Point the Flutter app at the local backend using a compile-time `--dart-define`:
```bash
flutter run -d macos --dart-define=RINGDRILL_LOCAL_BASE_URL=http://localhost:8888
```
The override is resolved at compile time (via `String.fromEnvironment` in `AppConfig.localBaseUrl`) and only takes effect in debug builds. Release builds cannot be coerced into talking to localhost.
