# ADR-0039 Phase 2a — Host-aware API client and CORS

You are working in the RingDrill repository. Implement Phase 2a of [ADR-0039](../adrs/0039-site-pwa-api-origins.md). ADR-0039 is accepted and authoritative. Read the "Topology", "CORS" and "API client configuration" sections before starting.

Phase 1 is shipped to apex with the `MIGRATION_DISABLED=true` kill switch keeping the migration UI hidden. Phase 2a prepares the API client and the backend CORS allowlist so the future PWA on `web.ringdrill.app` can talk to `api.ringdrill.app` cross-origin without breaking the existing cached PWA on apex.

## Scope

Two small code changes:

* Flutter: `lib/utils/app_config.dart` runtime host detection
* Netlify: `netlify/functions/_shared.js` CORS allowlist extension

This prompt is safe to land before any infrastructure exists. The existing apex PWA continues to call same-origin and is unaffected.

## Steps

### Step 1 — Host-aware `catalogBaseUrl`

Update `lib/utils/app_config.dart` so release web builds return `https://api.ringdrill.app` when running on `web.ringdrill.app`, and stay same-origin (empty string) on apex.

```dart
static const String apiBaseUrl = 'https://api.ringdrill.app';

static String catalogBaseUrl({
  required bool isWeb,
  required bool isRelease,
  required bool isDebug,
  String? webHost, // exposed for tests; defaults to Uri.base.host
}) {
  if (isDebug && localBaseUrl.isNotEmpty) return localBaseUrl;
  if (isWeb && isRelease) {
    final host = webHost ?? Uri.base.host;
    if (host == 'web.ringdrill.app') return apiBaseUrl;
    // Apex stays same-origin. The cached PWA's calls to
    // /.netlify/functions/* keep working on apex (served directly
    // by Netlify today, proxied via Cloudflare in Phase 3).
    return '';
  }
  return ringDrillBaseUrl;
}
```

Unit test verifies four cases:

* Release web build on apex (`webHost: 'ringdrill.app'`) → empty string
* Release web build on `web.ringdrill.app` → `https://api.ringdrill.app`
* Debug build with `RINGDRILL_LOCAL_BASE_URL` set → the local URL
* Native release build (`isWeb: false`) → `https://ringdrill.app`

Commit: `feat(config): point new PWA at api.ringdrill.app via runtime host detection`. Verify `git status` is clean.

### Step 2 — CORS allowlist for `web.ringdrill.app`

`netlify/functions/_shared.js` allows `https://ringdrill.app` and Netlify preview hosts. Extend `ALLOWED_ORIGIN_PATTERNS` to include `https://web.ringdrill.app`.

```js
const ALLOWED_ORIGIN_PATTERNS = [
    /^https:\/\/ringdrill\.netlify\.app$/,
    /^https:\/\/ringdrill\.app$/,
    /^https:\/\/web\.ringdrill\.app$/,
    /^https:\/\/[^/]+--ringdrill\.netlify\.app$/,
    /^http:\/\/localhost(:\d+)?$/,
    /^http:\/\/127\.0\.0\.1(:\d+)?$/,
];
```

If there is a test under `netlify/functions/__tests__/` covering `corsHeadersFor`, add a case asserting that `https://web.ringdrill.app` is accepted.

Commit: `feat(api): allow web.ringdrill.app origin in CORS allowlist`. Verify `git status` is clean.

### Step 3 — Verification

* `flutter analyze` clean
* `flutter test` clean
* `npm test` in `netlify/functions/__tests__/` clean (if a suite exists)
* `git status` clean

## Out of scope

* Astro site scaffold — Phase 2b
* GHA workflows for Cloudflare deploys — Phase 2c
* Any Cloudflare or DNS changes — manual, separate
* Flipping `MIGRATION_DISABLED=false` — Phase 3
* Self-unregister SW stub — Phase 3

## Definition of done

Two commits in order: `feat(config)` and `feat(api)`. `flutter analyze` and `flutter test` pass. `git status` clean after every commit.
