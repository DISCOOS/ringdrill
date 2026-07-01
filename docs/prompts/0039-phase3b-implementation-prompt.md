# ADR-0039 Phase 3b — `drills-preview` Netlify function for slug previews

You are working in the RingDrill repository. Implement Phase 3b of [ADR-0039](../adrs/0039-site-pwa-api-origins.md). ADR-0039 is accepted and authoritative. Read the "Topology" and "New Netlify function: drills-preview" sections before starting.

Phase 3a landed the site-side apex-takeover assets. Phase 3b adds the server-side rendering that turns `ringdrill.app/i/<slug>` into a real HTML preview when someone opens a shared install link in a desktop browser. Without this the Cloudflare `_redirects` on apex proxy `/i/*` to Netlify but there is no function to answer, so the link 404s.

## Scope

Netlify-only. All work in `netlify/functions/` and `netlify.toml`. No changes to Flutter, Astro or GHA workflows.

## Steps

### Step 1 — `drills-preview` Netlify function

Add `netlify/functions/drills-preview.js`. Uses Netlify Functions v2 syntax (same as the existing functions).

Responsibilities:

* Read the slug from the request URL (after the `/i/` prefix).
* Read `meta.json` for that slug from the drills blob store via `getDrillsStore()` in `_shared.js`. Return 404 if the slug is unknown or unpublished (`meta.published` is `false`).
* Pick the locale (see "Locale handling" below).
* Render a small HTML page. The page must contain:
  * `<html lang="nb|en">` matching the chosen locale.
  * `<title>` with the plan name and app name.
  * `<meta name="description">` with a short summary (name + tag list truncated).
  * Open Graph tags: `og:title`, `og:description`, `og:url` (the canonical `https://ringdrill.app/i/<slug>` — the request URL, NOT the api subdomain), `og:type=website`, `og:locale=nb_NO` or `og:locale=en_US`.
  * `<link rel="canonical" href="https://ringdrill.app/i/<slug>">` and `<link rel="alternate" hreflang="nb" ...>` / `<link rel="alternate" hreflang="en" ...>` / `<link rel="alternate" hreflang="x-default" ...>` pointing at the same URL (content-negotiated).
  * A visible layout that reads sensibly without CSS: plan name as `<h1>`, tags as small text, exercise count if the meta has it, and two prominent link buttons — "Åpne i app" / "Open in app" pointing at the Universal / App Link `https://ringdrill.app/i/<slug>` (OS captures on mobile), and "Åpne på web" / "Open on web" pointing at `https://web.ringdrill.app/i/<slug>`. Include a small "Last ned .drill" / "Download .drill" link to `https://ringdrill.app/d/<slug>`.
* Response headers:
  * `Content-Type: text/html; charset=utf-8`
  * `Cache-Control: public, max-age=300, s-maxage=600`
  * `Content-Language: nb` or `en` matching the chosen locale
  * `Vary: Accept-Language` (crucial for correct CDN caching per locale)

**Locale handling.** The function supports two locales, `nb` (default) and `en`. Pick in this order:

1. Explicit `?lang=nb` or `?lang=en` query parameter (used by tests and for share-with-locale).
2. `Accept-Language` header — the first supported locale in the client's ranked list wins. `en-GB`, `en-US`, `en` all resolve to `en`. Anything not in the supported set falls through.
3. Default `nb`.

`Vary: Accept-Language` on the response tells shared caches (Cloudflare, Netlify edge) that the response body depends on the header and must be cached per-locale. Without it a `nb` cached response would leak to an `Accept-Language: en` visitor.

Keep the two locale string sets in a small `const STRINGS = { nb: {...}, en: {...} }` map at the top of the file. Do NOT introduce a translation framework — this is five strings per locale.

* CORS: use `withCors` and `corsPreflight` from `_shared.js` — the function is embedded via a proxy at apex, but sane CORS headers still help crawlers and any direct calls to `api.ringdrill.app/i/*`.

Style: inline styles or a small `<style>` block. Keep it under a few hundred bytes of CSS. Use the RingDrill brand palette from `docs/adrs/0023-brief-theme-tokens.md` (or a reasonable subset). This is a first-run design; polish happens later.

Handles only `/i/<slug>`. The `/brief/*` handling is a static Netlify redirect (Step 3), not a function.

Commit: `feat(api): add drills-preview function rendering /i/<slug> HTML in nb and en`. Verify `git status` is clean.

### Step 2 — Netlify redirect for `/i/*`

`netlify.toml` currently proxies `/i/*` nowhere (the path is defined only on the Cloudflare apex `_redirects` after Phase 3a). Add the redirect on the Netlify side so `api.ringdrill.app/i/<slug>` reaches the function:

```toml
[[redirects]]
    from = "/i/*"
    to = "/.netlify/functions/drills-preview?slug=:splat"
    status = 200
```

The `slug` query parameter passes the slug into the function. In the function, read it with `new URL(request.url).searchParams.get('slug')`. Fall back to parsing `request.url.pathname` if the query param is missing (edge case for direct `/.netlify/functions/drills-preview/foo` calls during local testing).

Commit: `feat(api): route /i/* to drills-preview function`. Verify `git status` is clean.

### Step 3 — Interim brief redirect

Per ADR-0039, `/brief/<uuid>` and `/brief/program/<uuid>` return an interim 302 to `https://web.ringdrill.app/brief/<uuid>` until ADR-0041 lands proper brief pre-rendering. Add two redirect rules in `netlify.toml`:

```toml
[[redirects]]
    from = "/brief/program/*"
    to = "https://web.ringdrill.app/brief/program/:splat"
    status = 302

[[redirects]]
    from = "/brief/*"
    to = "https://web.ringdrill.app/brief/:splat"
    status = 302
```

Order matters: `/brief/program/*` must come first so it wins for program brief URLs; the generic `/brief/*` handles exercise briefs. Test both directions.

No function needed for brief right now.

Commit: `feat(api): interim redirect brief URLs to the new PWA`. Verify `git status` is clean.

### Step 4 — Unit test for `drills-preview`

Add `netlify/tests/drills-preview.test.mjs` following the pattern of `netlify/tests/drills-upload-strip.test.mjs`. Cover:

* Unknown slug → 404 with an HTML body that says so briefly.
* Unpublished slug (`meta.published: false`) → 404.
* Published slug (default locale) → 200 with `Content-Type: text/html`, `<html lang="nb">`, `Content-Language: nb`, Norwegian button labels ("Åpne i app", "Åpne på web").
* Published slug with `?lang=en` → 200 with `<html lang="en">`, `Content-Language: en`, English button labels ("Open in app", "Open on web").
* Published slug with `Accept-Language: en-GB,en;q=0.9` → English variant even without the query param.
* Published slug with `Accept-Language: nb-NO,en;q=0.5` → Norwegian variant (first supported wins).
* Response always contains `og:title`, `og:description`, `og:url`, `og:type` and matching `og:locale` (`nb_NO` or `en_US`).
* Response contains `<link rel="canonical">` pointing at `ringdrill.app/i/<slug>`, not the api subdomain, and `<link rel="alternate" hreflang="nb|en|x-default">` entries.
* Response contains `Vary: Accept-Language`.
* CORS preflight (OPTIONS request) returns 204 with appropriate headers.

Use the same test helpers and mock blob store the existing Netlify function tests use.

Commit: `test(api): cover drills-preview HTML rendering, locale picking and 404 paths`. Verify `git status` is clean.

### Step 5 — Verification

* `npm test` in `netlify/tests/` clean.
* Local dev via `make netlify-dev` and `make catalog-seed`. Then:

  ```bash
  curl -i "http://localhost:8888/i/test-7x"
  ```

  Returns 200 with an HTML body opening `<!DOCTYPE html>`, `<html lang="nb">`, Norwegian button labels, and `Vary: Accept-Language`. `-I` alternative shows `Content-Type: text/html`.

  ```bash
  curl -i -H "Accept-Language: en" "http://localhost:8888/i/test-7x"
  ```

  Returns 200 with `<html lang="en">` and English button labels.

  ```bash
  curl -i "http://localhost:8888/i/test-7x?lang=en"
  ```

  Same as above via query param.

  ```bash
  curl -i "http://localhost:8888/i/does-not-exist"
  ```

  Returns 404 with a short HTML body.

  ```bash
  curl -i "http://localhost:8888/brief/some-uuid"
  ```

  Returns 302 with `Location: https://web.ringdrill.app/brief/some-uuid`.

  ```bash
  curl -i "http://localhost:8888/brief/program/some-uuid"
  ```

  Returns 302 with `Location: https://web.ringdrill.app/brief/program/some-uuid`.

* `git status` clean.

## Out of scope

* Astro-side changes (Phase 3a is done)
* `deploy-web.yml` restructuring (Phase 3c)
* Manual DNS or Cloudflare configuration
* Full brief rendering (ADR-0041 — that replaces the 302 redirects with real HTML)
* Sharing images / open-graph image files (add later once the preview page needs richer sharing)
* Locales other than `nb` and `en`
* A translation framework — the two locales are hand-authored constants in the function
* Any change to Flutter code

## Definition of done

Four commits in order: `feat(api)`, `feat(api)`, `feat(api)`, `test(api)`. Tests pass. Local curl checks match Step 5. `git status` clean after every commit.

## Commit message conventions

Conventional commits, lowercase, imperative present tense, English. Each step has its own commit; do not squash.
