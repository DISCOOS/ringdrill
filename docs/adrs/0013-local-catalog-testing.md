---
status: accepted
date: 2026-05-21
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0013: Local end-to-end catalog testing via netlify dev, CLI seeding and a build-time base URL

## Context and problem statement

The shared catalog introduced in [ADR-0008](./0008-persistent-program-library-and-catalog.md) and refined in [ADR-0010](./0010-live-catalog-updates.md) is served by Netlify Functions under `netlify/functions/` and backed by `@netlify/blobs`. The Flutter client reaches the catalog through `DrillClient.marketFeed()` at `/api/market/feed`, and uses the conditional refresh flow at `/api/drills/head/:slug` for live updates.

In practice the catalog has only one base URL the client knows about: `AppConfig.ringDrillBaseUrl = 'https://ringdrill.netlify.app'`. The branch in [`LibraryView._catalogBaseUrl()`](../../lib/views/library_view.dart) returns same-origin only for `kIsWeb && kReleaseMode`. Every other configuration (debug web, mobile, desktop) hits production directly. There is no documented or repeatable way to run the catalog stack locally end to end, which means:

* Backend changes in `netlify/functions/market-feed.js`, `drills-head.js`, `drills-upload.js`, `deep-link.js` or `_shared.js` can only be verified by deploying to production or by ad hoc `curl` against a hand-started function host.
* The conflict-resolution flow from ADR-0008 (`refreshCatalogItem` with three-way diff) and the live-update polling from ADR-0010 cannot be exercised end to end without mutating the public catalog.
* Tests of new CLI behavior (e.g. an upload command) cannot run against an isolated backend.

The tooling pieces needed to fix this already exist in the repository (`netlify.toml`, `.netlify/blobs-serve/` cache, an admin CLI at `bin/ringdrill.dart` whose `--base-url` is already overridable). What is missing is a glued-together workflow that is part of the contract: which command starts the backend, which seeds it, which configures the client, and which resets it.

## Decision drivers

* The Flutter app, the CLI and the Netlify backend must all be exercisable against a single local instance, not just unit-tested in isolation.
* The default behavior of every binary must remain unchanged. A developer who does nothing must still hit production, exactly as today.
* The CLI must remain Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md).
* The backend contract must not change. `/api/market/feed`, `/api/drills/head/:slug`, `/api/drills/upload`, `/api/admin` and `/d/:slug` are the same locally and in production.
* The local workflow must not require a network round trip after the initial install (apart from `npm install`).
* The convention for pointing the app at a non-production backend must be visible at build time, not at runtime, so accidental cross-environment calls in a release build are impossible.

## Considered options

* **Composed workflow: `netlify dev` + CLI seeding commands + Makefile orchestration + `--dart-define` base URL (chosen).** One repeatable path that uses tools already in the repo. The CLI gains `upload`, `feed`, `download` commands so it can both populate and inspect the local catalog. The Makefile wires `netlify dev`, seeding and reset into named targets. The app reads an optional `RINGDRILL_LOCAL_BASE_URL` via `String.fromEnvironment` and uses it only in debug builds.
* **Runtime debug flag in the running app.** A toggle inside the app (e.g. via developer menu or hidden setting) switches the catalog base URL. Avoids the build-time step but means a release APK can in principle be pointed at localhost, and the toggle ships in user builds.
* **Mock the backend in Dart.** A fake `DrillClient` or an in-memory HTTP server inside the app process. Good for widget tests, but does not exercise the real `netlify/functions/*.js` code, the blob store or the CDN headers. Catches Dart-side bugs only.
* **Docker compose with a self-hosted Netlify equivalent.** A container that boots functions and blobs. Reproducible but reinvents what `netlify dev` already does, and adds Docker to the contributor prerequisites.
* **Do nothing (status quo).** Continue to test against `ringdrill.netlify.app`. Acceptable for read-only work but dangerous for write paths and impossible for breaking-change experiments.

## Decision outcome

Chosen option: **composed workflow with `netlify dev`, CLI seeding commands, Makefile targets and a debug-only `--dart-define`**, because it reuses tooling already present in the repository, leaves production code paths and defaults untouched, exercises the real backend code (not a mock), and prevents accidental release-time misconfiguration by making the override a compile-time substitution that is gated on `kDebugMode`.

### CLI changes

`bin/ringdrill.dart` gains three commands that complement the existing admin set:

* `ringdrill upload <file.drill> [--published] [--tags=a,b,c] [--owner=anon]` calls `DrillClient.upload`. Does not require an admin token. The `--published` flag maps directly to the upload contract.
* `ringdrill feed [--limit=N] [--cursor=C]` calls `DrillClient.marketFeed` and pretty-prints the result. Does not require an admin token.
* `ringdrill download <slug> [--out=<file>] [--version=N]` calls `DrillClient.download` and writes the bytes to disk. Does not require an admin token.

The existing admin-token check at the top of `main()` is moved into the per-command branches so that non-admin commands do not require `RINGDRILL_ADMIN_TOKEN`. The base-URL handling (`--base-url` / `RINGDRILL_BASE_URL` / default) is unchanged, which is what makes the same CLI work against production and against `http://localhost:8888` by environment variable alone.

All three commands stay inside `lib/data/` (Flutter-free per ADR-0005). The download command writes to a path with `dart:io`, which is already used elsewhere in the CLI.

### Makefile changes

A new section orchestrates the local stack:

```make
LOCAL_BASE_URL    ?= http://localhost:8888
LOCAL_ADMIN_TOKEN ?= dev-token
SEED_DRILL        ?= test/fixtures/test-7x.drill

netlify-dev:
    npm install
    ADMIN_TOKEN=$(LOCAL_ADMIN_TOKEN) npx netlify functions:serve --port 8888

catalog-seed:
    @test -f $(SEED_DRILL) || { echo "Seed file $(SEED_DRILL) not found. Set SEED_DRILL=<path>"; exit 1; }
    RINGDRILL_BASE_URL=$(LOCAL_BASE_URL) \
    RINGDRILL_ADMIN_TOKEN=$(LOCAL_ADMIN_TOKEN) \
    dart run bin/ringdrill.dart upload $(SEED_DRILL) --published

catalog-feed:
    RINGDRILL_BASE_URL=$(LOCAL_BASE_URL) \
    dart run bin/ringdrill.dart feed

catalog-reset:
    rm -rf .netlify/blobs-serve
```

The default `SEED_DRILL` points at the checked-in fixture at `test/fixtures/test-7x.drill`. This is a synthetic `.drill` archive used as the canonical seed for local catalog testing. The `SEED_DRILL` variable is overridable so a contributor can point at any local `.drill` file without editing the Makefile. The same applies to `LOCAL_BASE_URL` and `LOCAL_ADMIN_TOKEN`.

Real planning files in the repository root (such as the existing `Ovingsplan-2026-Eidene.drill`) are explicitly not used as defaults. They are contributor-specific artifacts, not test fixtures, and tying the workflow to them would couple the developer setup to whatever happens to be checked in.

### Note on `netlify dev` vs `netlify functions:serve`

The `netlify-dev` Makefile target uses `netlify functions:serve` rather than the more general `netlify dev` command. The reason is that `netlify dev` sets up an Edge Functions runtime (Deno) even when the project has no edge functions, and that setup fails to install reliably on some macOS hosts (an unhandled exception terminates the CLI shortly after the static server comes up). We do not use edge functions, so `functions:serve` is sufficient and stable.

The trade-off: `functions:serve` does not apply the redirects from `netlify.toml`, so the `/api/*` and `/d/*` aliases are not available locally. `DrillClient` already calls `/.netlify/functions/*` directly for the upload/head/admin/market-feed paths, so those all work. The download path used to go through `/d/<slug>`, which would 404 against `functions:serve`. To fix this, `AppConfig.deepLinkBasePathFor(baseUrl)` returns `/.netlify/functions/deep-link` when the base URL is local and `/d` otherwise. `LibraryView` constructs its `DrillClient` through `_buildCatalogClient()` which threads this path through. The result is that catalog install and refresh work end to end against the local backend.

`ringdrill download <slug>` from the CLI still uses the default `deepLinkBasePath = '/d'` and will 404 against `functions:serve`. The Makefile workflow does not depend on `download`, so this is left as-is. A contributor who needs CLI download against a local backend can pass `--deep-link-path /.netlify/functions/deep-link` once that CLI flag is added (deferred until the need is real).

### App configuration

`lib/utils/app_config.dart` gains a single new constant and a helper:

```dart
/// Override via:
///   flutter run --dart-define=RINGDRILL_LOCAL_BASE_URL=http://localhost:8888
static const String _localBaseUrl = String.fromEnvironment(
  'RINGDRILL_LOCAL_BASE_URL',
  defaultValue: '',
);

static String catalogBaseUrl({
  required bool isWeb,
  required bool isRelease,
  required bool isDebug,
}) {
  if (isDebug && _localBaseUrl.isNotEmpty) return _localBaseUrl;
  return isWeb && isRelease ? '' : ringDrillBaseUrl;
}
```

`LibraryView._catalogBaseUrl()` and any future call site delegate to `AppConfig.catalogBaseUrl(...)`. The previous branch (`kIsWeb && kReleaseMode` → same-origin, otherwise production) is preserved as the default. The override only takes effect when both conditions hold: a debug build, and a non-empty `RINGDRILL_LOCAL_BASE_URL` was passed at build time.

`String.fromEnvironment` is resolved at compile time, so a release `.aab` or PWA cannot be coerced into talking to a localhost backend at runtime. This matters because a misconfigured app pointed at `localhost:8888` from a user device would silently fail and could leak local data.

### CORS

The PWA in production is served same-origin with the functions (both under `ringdrill.netlify.app`), so CORS is not needed there. Local dev has the Flutter dev server on `http://localhost:<random>` and the function host on `http://localhost:8888`, which are different origins and trigger CORS preflight.

The functions opt in to CORS via an explicit origin allowlist in `netlify/functions/_shared.js`:

* `https://ringdrill.netlify.app` (production)
* `https://ringdrill.app` (custom domain)
* `https://<id>--ringdrill.netlify.app` (Netlify deploy previews / branch deploys)
* `http://localhost:<port>` and `http://127.0.0.1:<port>` (local dev, any port)

`Access-Control-Allow-Origin: *` is intentionally avoided. The API endpoints are otherwise public, so `*` would not weaken authentication (admin endpoints are token-gated, upload is anonymous-by-design), but the allowlist keeps defense in depth: if a future change adds an endpoint that should not be readable cross-origin, the model already restricts it.

`withCors(request, response)` and `corsPreflight(request)` helpers in `_shared.js` add the headers when the request's `Origin` matches the allowlist, and pass the response through unchanged otherwise. Non-browser clients (the CLI, native mobile apps, curl) do not send an `Origin` header and are unaffected.

### Developer workflow

The intended path is:

1. `npm install` once (Netlify dev needs the `@netlify/blobs` dependency declared in `package.json`).
2. `make netlify-dev` in one terminal. Functions and blobs are now reachable at `http://localhost:8888`.
3. `make catalog-seed` in another terminal. The fixture at `test/fixtures/test-7x.drill` is uploaded with `published=true`. Override with `make catalog-seed SEED_DRILL=path/to/other.drill` to publish a different file.
4. `make catalog-feed` to confirm the entry appears in the local feed.
5. `flutter run -d macos --dart-define=RINGDRILL_LOCAL_BASE_URL=http://localhost:8888` to launch the app against the local backend. The `LibraryView` now lists the seeded plan in its Catalog tab.
6. `make catalog-reset` (with the backend stopped) clears `.netlify/blobs-serve/` for a clean run.

### Documentation

`docs/architecture.md` gets a short "Local catalog testing" subsection that references this ADR and the four `make catalog-*` targets. `AGENTS.md` gains a one-line pointer under "Common commands". No new files outside `docs/` are required.

### Consequences

* Good: One repeatable path covers all three components (backend, CLI, app) against an isolated stack.
* Good: Default behavior is unchanged. Without `RINGDRILL_LOCAL_BASE_URL` set, every binary behaves as before.
* Good: The override is compile-time and gated on `kDebugMode`. Release builds cannot be tricked into pointing at localhost.
* Good: The CLI grows three commands that are useful in their own right, independent of the local workflow.
* Good: ADR-0005's Flutter-free rule is preserved. The new CLI commands use only `DrillClient`, which is already Flutter-free.
* Good: Backend code is exercised as-is, including blob store interactions and CDN headers.
* Bad: Adds Netlify CLI to the contributor prerequisites (`npx netlify dev` will install it on first use if absent).
* Bad: Introduces a new `--dart-define` convention. The codebase did not have one before. Future overrides will be tempted to follow the same pattern, which is fine for build-time switches but should not become a runtime configuration backdoor.
* Bad: `catalog-seed` depends on the fixture at `test/fixtures/test-7x.drill` being present. If the fixture is later moved or removed, the target breaks unless the `SEED_DRILL` variable is set explicitly. The target prints a clear error and exits non-zero in that case rather than calling `dart run` against a missing file.
* Bad: The Makefile assumes a POSIX shell. Windows contributors will need WSL or a manual invocation of the equivalent commands.

## Pros and cons of the options

### Composed workflow (chosen)
* Good: Reuses existing tooling, no new services or containers.
* Good: Clear separation: Netlify CLI runs the backend, the CLI seeds, the app consumes.
* Bad: Requires Node and the Netlify CLI on the contributor's machine.

### Runtime debug flag in the running app
* Good: No build-time arguments, easier to toggle from inside the app.
* Bad: The toggle ships in release builds unless guarded carefully, and even a guarded toggle is a runtime configuration surface.
* Bad: Does not help the CLI or backend dev cycle on its own.

### In-process mock of the backend
* Good: Fastest feedback loop, no external processes.
* Good: Useful for widget and integration tests, complementary to this ADR.
* Bad: Does not exercise `netlify/functions/*.js`, the blob store or the real HTTP semantics. Catches Dart-side bugs only.

### Docker compose with a self-hosted Netlify equivalent
* Good: Hermetic and reproducible across machines.
* Bad: Adds Docker as a prerequisite, reinvents what `netlify dev` already provides.
* Bad: Higher maintenance cost for a small team.

### Status quo
* Good: Zero work.
* Bad: Backend changes can only be tested in production, which is unsafe for write paths and impossible for breaking-change experiments.

## Links

* Related ADRs: [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0008](./0008-persistent-program-library-and-catalog.md), [ADR-0010](./0010-live-catalog-updates.md)
* Related code: `bin/ringdrill.dart`, `lib/data/drill_client.dart`, `lib/utils/app_config.dart`, `lib/views/library_view.dart`, `netlify/functions/market-feed.js`, `netlify/functions/_shared.js`, `netlify.toml`, `Makefile`, `package.json`
* External references: [Netlify CLI `netlify dev`](https://docs.netlify.com/cli/get-started/#netlify-dev), [`@netlify/blobs` local emulation](https://docs.netlify.com/blobs/overview/)
