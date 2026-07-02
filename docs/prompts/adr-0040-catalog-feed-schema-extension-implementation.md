# Implement ADR-0040: catalog feed schema extension

You are working in the RingDrill repository. Implement ADR-0040 ("Extend the catalog feed schema with description, exercise count, author and access policy") end-to-end. The ADR at `docs/adrs/0040-catalog-feed-schema-extension.md` is the authoritative spec — read it first, then read this prompt in full before touching code.

Context you can rely on as already shipped: the publish handler already reads plan-level `name`, `description` and `tags` from `program.json` (ADR-0043) via the pure helper `programInfoFromArchive` in `netlify/functions/drills-upload.js`, and already persists `name`, `description`, `tags`, `published` and `versions` into `meta.json`. The feed at `GET /api/market/feed` (`netlify/functions/market-feed.js`) currently projects only `{ programId, slug, name, tags, latestUrl, updatedAt }`. The slug preview (`netlify/functions/drills-preview.js`) already reads `meta.exerciseCount` and renders a count line, but nothing writes that field today, so the line never renders — this change lights it up.

The single behavioural change: derive `exerciseCount` at publish and persist it, persist `author` and `accessPolicy`, and widen the feed (and any future per-slug meta endpoint) to project `description`, `exerciseCount`, `author` and `accessPolicy` alongside the existing fields. All new fields are additive and nullable; legacy `meta.json` blobs degrade to defaults and self-heal on the next publish. No `.drill` schema bump.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* This change is mostly Netlify JS plus one Flutter model. Run `make build` only if you touch a `@freezed`/`json_serializable` class. `MarketFeedItem` in `lib/data/drill_client.dart` is a hand-written `@immutable` class, NOT freezed — edit it directly, no codegen.
* The CLI must stay Flutter-free. `MarketFeedItem` lives under `lib/data/`, which the CLI may import; keep it Flutter-free (it already is). Verify with `rg "package:flutter" lib/data/drill_client.dart` — must return nothing.
* Any new user-visible UI string (e.g. a catalog card exercise-count label) goes in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. No raw English in widgets. Run `make i18n` (`flutter gen-l10n`) after editing an ARB — `make build` does NOT regenerate `app_localizations*.dart`. Norwegian: "øvelse"/"øvelser" for exercise count (match `drills-preview.js` `STRINGS`). Keep IDs/code identifiers English.
* Do NOT bump the archive schema. `KNOWN_SCHEMA_MAX` stays `1.2`. `exerciseCount` is derived from `program.json.exercises.length`, not a new stored `.drill` field.
* Do NOT touch version/release steps or `pubspec.yaml` version. Releases go through the release script.
* `meta.json` is an internal server blob with no client schema version. Adding fields is additive — do not gate it behind any version check.
* Run `flutter analyze`, `flutter test`, and `npm test` (the Netlify suite) before claiming the change is green.

## Commits

Commit as you progress, not in one blob. Conventional Commits with a scope. Types in use: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Scopes in use: `models`, `data`, `views`, `l10n`, `functions`/`netlify`, `docs`. Write commit messages in English even though this prompt is mixed-language. Suggested subjects:

* `feat(netlify): add shared meta→feed-item projection in _shared.js`
* `feat(netlify): persist exerciseCount, author and accessPolicy on publish`
* `feat(netlify): project description, exerciseCount, author, accessPolicy in feed`
* `feat(data): widen MarketFeedItem with description, exerciseCount, author, accessPolicy`
* `docs(adr): mark ADR-0040 accepted`

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure — new test files and new source files ship in the step that introduces them.
* Each step lists the files expected in that commit. The commit must include every listed path. Any regenerated file (`app_localizations*.dart` if you add ARB strings) ships in the SAME commit as the source change that triggered it — never a follow-up regen commit.
* Never close a step with `git stash` or `git restore`. If it is in the working tree, it ships.
* The final Verification gate requires `git status` to print a clean tree with no untracked or unstaged files.

## Scope

Five steps, in order.

### Step 1. Add a shared meta→feed-item projection helper

Edit `netlify/functions/_shared.js`. Add one exported pure function that both `market-feed.js` and the future ADR-0044 `/api/drills/:slug/meta` endpoint project through, so the two contracts cannot drift:

```js
// Project a stored meta.json blob into the public catalog item shape.
// Single source of truth for the feed / per-slug meta contract (ADR-0040).
// All derived fields degrade gracefully for legacy blobs written before
// ADR-0040 (missing exerciseCount → null, author → ownerId, accessPolicy →
// public for anon plans else account, per ADR-0025).
export function metaToFeedItem(meta, { origin }) { ... }
```

It must return exactly:

```
{ programId, slug, name, description, exerciseCount, author, accessPolicy, tags, latestUrl, updatedAt }
```

Rules inside the helper:

* `description` → `typeof meta.description === "string" ? meta.description : ""`.
* `exerciseCount` → `Number.isInteger(meta.exerciseCount) ? meta.exerciseCount : null`. Never coerce a missing value to `0`.
* `author` → `meta.author ?? meta.ownerId ?? null`.
* `accessPolicy` → `meta.accessPolicy ?? (meta.ownerId === "anon" ? "public" : "account")`.
* `tags` → `Array.isArray(meta.tags) ? meta.tags : []`.
* `latestUrl` → `${origin}/d/${meta.slug}`.
* `updatedAt` → the `updatedAt` of the highest version in `meta.versions` (reuse the same "latest version" logic `market-feed.js` uses today; move `latestVersionEntry` into `_shared.js` and export it, or inline the reduce). `null` when there are no versions.

Add `netlify/tests/_shared-feed-item.test.mjs` (Node test runner, mirroring the style of `drills-upload-meta.test.mjs`) asserting: a full modern blob projects every field; a legacy blob with no `exerciseCount`/`author`/`accessPolicy` yields `exerciseCount: null`, `author === ownerId`, and the anon→`public` / owned→`account` default; a blob with no `versions` yields `updatedAt: null`. Run `npm test`.

Files expected in this commit: `netlify/functions/_shared.js`, `netlify/tests/_shared-feed-item.test.mjs`.

### Step 2. Persist exerciseCount, author and accessPolicy on publish

Edit `netlify/functions/drills-upload.js`:

* Extend `programInfoFromArchive` to also return `exerciseCount`: `Array.isArray(p?.exercises) ? p.exercises.length : null`. Missing/malformed → `null`, never throw. Update its JSDoc.
* In the handler, after the existing `currentMeta.tags = tags;` block, also set:
  * `currentMeta.exerciseCount = program.exerciseCount;` (the value read from the archive; `null` when the archive had no `exercises`).
  * `currentMeta.author = ownerId;` — today author mirrors the resolved `ownerId`. ADR-0024 will change what is written here to an account display name; readers already fall back to `ownerId`, so this is forward-compatible.
  * `currentMeta.accessPolicy = ownerId === "anon" ? "public" : "account";` — the ADR-0025 default. Do not invent `shared` here; that arrives with ADR-0024/0025.
* Leave the initial `readJson(meta, {...})` seed shape as-is; the new keys are written unconditionally on every publish, so the seed does not need them.

Update `netlify/tests/drills-upload-meta.test.mjs`: assert a published plan's `meta.json` gains `exerciseCount` equal to the archive's exercise count, `author` equal to the resolved `ownerId`, and `accessPolicy` equal to `public` for an anon upload. Add a case where `program.json` has no `exercises` → `exerciseCount: null`. Run `npm test`.

Files expected in this commit: `netlify/functions/drills-upload.js`, `netlify/tests/drills-upload-meta.test.mjs`.

### Step 3. Project the new fields in the feed

Edit `netlify/functions/market-feed.js`. Replace the inline per-item object literal with a call to `metaToFeedItem(m, { origin })` from Step 1. Keep everything else — the pagination loop, the `if (!m || !m.published) continue` filter, the `items.sort` on `updatedAt`, and the existing `cache-control: public, max-age=30` header. The feed must stay a pure projection with no extra blob reads.

Add `netlify/tests/market-feed.test.mjs` (there is none today). Stub the drills store the way the other Netlify tests do and assert: published items carry the widened shape; unpublished items are omitted; a legacy blob (no `exerciseCount`/`author`/`accessPolicy`) projects with the graceful defaults from Step 1. Run `npm test`.

Files expected in this commit: `netlify/functions/market-feed.js`, `netlify/tests/market-feed.test.mjs`.

### Step 4. Widen the Flutter feed model

Edit `MarketFeedItem` in `lib/data/drill_client.dart`. Add four fields, all nullable/defaulted so old feed payloads still parse:

* `final String description;` (default `''`)
* `final int? exerciseCount;`
* `final String? author;`
* `final String? accessPolicy;`

Update the constructor and `fromJson`:

* `description: j['description'] as String? ?? ''`
* `exerciseCount: (j['exerciseCount'] as num?)?.toInt()`
* `author: j['author'] as String?`
* `accessPolicy: j['accessPolicy'] as String?`

Surface `exerciseCount` and `description` in the in-app catalog card in `lib/views/widgets/catalog_browser.dart`, following the existing subtitle/`item.tags` conventions there — show a localized "N øvelser"/"N exercises" line when `exerciseCount != null`, and the description when non-empty. Do not render a count when `exerciseCount` is null. Keep `accessPolicy` parsed but unused in the UI (it lights up with ADR-0024/0025); a `// ignore: unused` is not needed since it is a public field.

Add ARB strings for the count label to `app_en.arb` and `app_nb.arb` if you introduce new copy (reuse existing pluralization patterns), then run `make i18n`. If you add a model test, put it under `test/data/`.

Files expected in this commit: `lib/data/drill_client.dart`, `lib/views/widgets/catalog_browser.dart`, and (if you added copy) `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `lib/l10n/app_localizations*.dart`, plus any test you add.

### Step 5. Docs

Confirm `docs/adrs/0040-catalog-feed-schema-extension.md` front-matter `status:` is `accepted` and the index row in `docs/adrs/README.md` reads `Accepted` (both were set when the ADR was accepted — only touch them if they drifted). If `docs/api.md` documents the `/api/market/feed` response shape, update the example to the widened item. Do not create a `README` you were not asked for.

Files expected in this commit: `docs/api.md` if edited (and the ADR/README only if they were not already `accepted`).

## Verification gate

Do not claim done until all of these pass:

* `npm test` green (all Netlify suites, including the two new test files).
* `flutter analyze` clean (no new warnings).
* `flutter test` green.
* `rg "package:flutter" lib/data/drill_client.dart` returns nothing.
* The feed does no per-request archive reads — confirm `market-feed.js` still reads only `meta.json`, never a `.drill`.
* `git status` shows a clean tree — no untracked, no unstaged, all regenerated files committed alongside their source.

## Out of scope

* The ADR-0044 `/api/drills/:slug/meta` endpoint itself. This prompt only provides the shared `metaToFeedItem` helper it will reuse; building the endpoint and the site `/i/[slug]` render is ADR-0044's implementation.
* The site `/catalog` route (planned in ADR-0039, not yet built). This change readies the feed contract it will consume; it does not build the route.
* Any `shared`-policy authorization, account resolution, or real author display names — those arrive with ADR-0024/0025.
* Any backfill of existing `meta.json` blobs. They self-heal on the next publish.
* Schema bump to 1.3 (not needed; `KNOWN_SCHEMA_MAX` stays `1.2`).
