# Implement plan-content `languageCode` and the `/catalog` language filter

You are working in the RingDrill repository. Add a `languageCode` field to `ProgramMetadata` — the human language a plan's *content* (name, briefs, exercise/station/team names) is written in, completely separate from the app's own nb/en UI language — and thread it end to end: app picker → `.drill` archive → publish → catalog feed → `/catalog` filter → `/i/<slug>` preview.

Read `docs/adrs/0007-drill-file-format.md`'s **"Addendum (2026-07-02): `languageCode` on `ProgramMetadata`"** section and `docs/adrs/0040-catalog-feed-schema-extension.md`'s **"Addendum (2026-07-02): `languageCode` — feed projection, `/catalog` filter, `/i/<slug>` surfacing"** section first — both are authoritative for this prompt. Then read this prompt in full before touching code.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that matter here:

* **No schema bump.** `KNOWN_SCHEMA_MAX` stays `1.2`. `languageCode` is an additive optional field on an existing part (`metadata.json`), not a new archive section — same treatment as `exerciseCount`/`mapCenter`/`author`/`accessPolicy` before it.
* **Language list is `nb`/`en` only, sourced from `AppLocalizations.supportedLocales` — never a separately maintained list.** `AppLocalizations.supportedLocales` (`lib/l10n/app_localizations.dart:96`) is a `static const List<Locale>` generated from the ARB files. The plan-language picker must read its options from there, not from a new hardcoded list, so a future third ARB locale extends the picker automatically. Only the code→display-name label map is manually maintained, and only for locales that exist today (`nb`, `en`).
* **`languageCode: null` is a normal, valid, permanent state** — not a temporary "not migrated yet" placeholder. Every plan defaults to it until an author explicitly picks a language. Readers (feed, filter, preview) must never guess or default it to something else.
* **The `/catalog` filter never hides a plan with no language set**, regardless of which language is selected. This is the one behavioral rule most likely to get quietly broken by an "obvious" filter implementation (`item.languageCode === selected`) — the actual predicate is `!item.languageCode || item.languageCode === selected || selected === ''`.
* Run `make build` after touching `ProgramMetadata` (freezed) and `make i18n` after touching an ARB file — `make build` does **not** regenerate `app_localizations*.dart`.
* User-visible strings go in `lib/l10n/app_en.arb`/`app_nb.arb` for the app, and `site/src/i18n.ts` for the site — no raw English/Norwegian in widgets or `.astro` files.
* `flutter analyze`, `flutter test`, repo-root `npm test`, and `npm --prefix site test` must all be green before claiming done.

## Commits

Commit as you progress, not in one blob. Conventional Commits with a scope. Scopes in use: `models`, `views`, `l10n`, `netlify`, `site`, `tools`, `docs`. Suggested subjects:

* `feat(models): add languageCode to ProgramMetadata`
* `feat(views): add plan-language picker to ProgramFormScreen`
* `feat(netlify): read and persist languageCode on publish`
* `feat(netlify): project languageCode in the feed and /i/<slug> preview`
* `feat(site): add a language filter to /catalog`
* `feat(tools): tag catalog-seed-demos fixtures with real language codes`

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat`; no untracked or unstaged paths before claiming a step done.
* Each step lists the files expected in that commit — the commit must include every listed path. Regenerated files (`.freezed.dart`/`.g.dart`, `app_localizations*.dart`) ship in the same commit as the source change that triggered them.
* Never close a step with `git stash`/`git restore`. The final Verification gate requires a clean tree.

## Scope

Six steps, in order.

### Step 1. Dart model

Add `String? languageCode` to `ProgramMetadata` in `lib/models/program.dart` (the `const factory ProgramMetadata({...})`, alongside `schema`). Run `make build`.

Files expected in this commit: `lib/models/program.dart`, `lib/models/program.freezed.dart`, `lib/models/program.g.dart`.

### Step 2. Plan-language picker in the app

Edit `lib/views/program_form_screen.dart`:

* Add a small display-name map near the top of the file (or in `lib/models/program.dart` next to `ProgramMetadata` — your call, pick whichever reads more naturally): `const Map<String, String> kPlanLanguageNames = {'nb': 'Norsk', 'en': 'English'};`. Comment it as needing to grow in lockstep with `AppLocalizations.supportedLocales` and with `site/src/lib/languages.ts`'s `LANGUAGE_NAMES` (Step 5).
* New `_LanguagePicker` widget, sibling to `_StationNumberFormatPicker` in the same file: a `DropdownButtonFormField<String?>` whose `items` are built from `AppLocalizations.supportedLocales.map((l) => l.languageCode)`, each labeled via `kPlanLanguageNames[code] ?? code` (fallback to the bare code — never crash on an unrecognized-but-supported locale). Include a `null`/unset option (e.g. a leading item with no label or a hint text like "Not set" — match whatever idiom `_StationNumberFormatPicker`'s label/hint styling already uses in this file).
* New state field `String? _languageCode;`, initialized in `initState` from `widget.program.metadata.languageCode`.
* Wire the picker into `build()`'s `Column`, near `_StationNumberFormatPicker` (same section of the form — plan-level settings, not exercise/station settings).
* In `_save()`, extend the existing `metadata: widget.program.metadata.copyWith(updated: DateTime.now())` to `metadata: widget.program.metadata.copyWith(updated: DateTime.now(), languageCode: _languageCode)`.
* Add ARB strings to `app_en.arb`/`app_nb.arb` for the picker's label (e.g. `planLanguageLabel`: "Plan language" / "Planens språk") and the "not set" option if you add one — placed near the existing `stationNumberFormatLabel` entries (`lib/l10n/app_en.arb:1835`). Run `make i18n`.
* Extend `test/views/program_form_screen_test.dart` (existing file) with a test that selects a language in the picker and asserts the popped `Program.metadata.languageCode`, and one confirming a plan with `languageCode: null` round-trips as still-null when saved without touching the picker.

Files expected in this commit: `lib/views/program_form_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, `lib/l10n/app_localizations*.dart`, `test/views/program_form_screen_test.dart`.

### Step 3. Backend — read and persist on publish

Edit `netlify/functions/drills-upload.js`. `stripActorsAndValidate` already parses `metadata.json` into a local `metadata` variable to check `metadata?.schema` against `KNOWN_SCHEMA_MAX`. Add right there:

```js
const languageCode = typeof metadata?.languageCode === "string" ? metadata.languageCode : null;
```

Thread it onto the object `stripActorsAndValidate` returns (alongside `program`, e.g. as `program.languageCode = languageCode` before the `return { strippedBytes, program }` — mirroring how `exerciseCount`/`mapCenter` already ride on that same `program` object from `programInfoFromArchive`). In the publish handler, add `currentMeta.languageCode = program.languageCode;` next to the existing `currentMeta.exerciseCount =` / `currentMeta.mapCenter =` lines.

Extend `netlify/tests/drills-upload-meta.test.mjs`: a case with `metadata.json.languageCode: "nb"` → persisted; a case with no `languageCode` key → `null`; a case where it's present but non-string (e.g. a number) → `null`, never thrown.

Run `npm test`.

Files expected in this commit: `netlify/functions/drills-upload.js`, `netlify/tests/drills-upload-meta.test.mjs`.

### Step 4. Backend — project in the feed and the `/i/<slug>` preview

Edit `netlify/functions/_shared.js`'s `metaToFeedItem`: add `languageCode: typeof meta.languageCode === "string" ? meta.languageCode : null,` alongside `mapCenter`. Extend `netlify/tests/_shared-feed-item.test.mjs` and `netlify/tests/market-feed.test.mjs` with present/absent/malformed cases, same pattern as the existing `mapCenter` tests in those files.

Edit `netlify/functions/drills-preview.js`: add a `LANGUAGE_NAMES` map (or extend the existing `STRINGS` dict per-locale — your call, whichever fits the file's existing structure better) covering `nb`/`en` display names, localized so the nb reader sees "Norsk"/"Engelsk" and the en reader sees "Norwegian"/"English". In `renderHtml`, add a third `metaBits` entry when `meta.languageCode` is present and recognized: `metaBits.push(\`<span>${esc(languageDisplayName)}</span>\`);` — omit the bit entirely when `languageCode` is absent or unrecognized, matching the existing "omit, don't fake" treatment the exercise-count bit already uses in this same array. Extend `netlify/tests/drills-preview.test.mjs`: a case asserting the language bit renders (both locales) when `meta.languageCode` is set, and is absent from the rendered HTML when it isn't.

Run `npm test`.

Files expected in this commit: `netlify/functions/_shared.js`, `netlify/functions/drills-preview.js`, `netlify/tests/_shared-feed-item.test.mjs`, `netlify/tests/market-feed.test.mjs`, `netlify/tests/drills-preview.test.mjs`.

### Step 5. Site — the `/catalog` language filter

* `site/src/lib/catalog.ts`: add `languageCode: string | null;` to `CatalogItem`.
* New `site/src/lib/languages.ts`:
  ```ts
  // Scoped to the app's supported UI locales (lib/l10n/app_*.arb) — extend
  // this in lockstep with lib/views/program_form_screen.dart's
  // kPlanLanguageNames whenever a new locale is added.
  export const LANGUAGE_NAMES: Record<string, string> = { nb: 'Norsk', en: 'English' };

  export function distinctLanguageCodes(items: { languageCode: string | null }[]): string[] {
    return [...new Set(items.map((i) => i.languageCode).filter((c): c is string => Boolean(c)))].sort();
  }
  ```
  Add `site/src/lib/languages.test.ts` (vitest): dedup, sort, null/empty-array handling.
* `CatalogCard.astro`: add `data-language={item.languageCode ?? ''}` on the `<li class="catalog-card">` root element.
* `catalog.astro` / `en/catalog.astro`: when `distinctLanguageCodes(result.items).length > 1` (a filter with ≤1 option is noise — don't render it), render:
  ```astro
  <select class="catalog__language-filter" id="catalog-language-filter">
    <option value="">{c.catalog.allLanguages}</option>
    {distinctLanguageCodes(result.items).map((code) => (
      <option value={code}>{LANGUAGE_NAMES[code] ?? code}</option>
    ))}
  </select>
  ```
  placed between the lead paragraph and the grid. Add a small client `<script>` (same plain-script, progressively-enhance convention as `MigrateApp.astro`/`CatalogCard.astro`) that, on the select's `change` event, iterates `document.querySelectorAll('.catalog-card')` and toggles visibility per card: **visible when `card.dataset.language` is empty (unset — always shown) OR equals the selected value OR the selected value is `''` (All languages)** — this exact predicate, not a naive equality check, per ADR-0040's addendum.
* `site/src/i18n.ts`: add `catalog.allLanguages` ("Alle språk" / "All languages") and `catalog.languageFilterLabel` ("Språk" / "Language", used as a visually-hidden `<label>` for the select) to both `nb`/`en` blocks.

Run `npm --prefix site test` and `npm --prefix site run build`.

Files expected in this commit: `site/src/lib/catalog.ts`, `site/src/lib/languages.ts`, `site/src/lib/languages.test.ts`, `site/src/components/CatalogCard.astro`, `site/src/pages/catalog.astro`, `site/src/pages/en/catalog.astro`, `site/src/i18n.ts`.

### Step 6. Demo fixtures

Edit `tools/screenshots/make_demo_drills.py`. Give `build()` a `language: str` parameter. Build a per-call metadata dict instead of reusing the module-level `META` literal directly:

```python
def build(filename, prog_uuid, prog_name, prog_desc, team_names, exercises, language):
    meta = {**META, "languageCode": language}
    ...
    z.writestr("metadata.json", json.dumps(meta))
    program = {
        ...
        "metadata": meta,
        ...
    }
```

Update `main()`'s two `build(...)` calls: `"nb"` for `demo-no.drill`, `"en"` for `demo-en.drill`. Regenerate the fixtures (`python3 tools/screenshots/make_demo_drills.py`) so the committed `.drill` files carry the new field — check `tools/screenshots/README` (if one exists) for whether these are checked in or gitignored, and commit them if they're tracked.

Files expected in this commit: `tools/screenshots/make_demo_drills.py`, and `tools/screenshots/demo-no.drill`/`demo-en.drill` if tracked by git.

## Verification gate

Do not claim done until all of these pass:

* `flutter analyze` clean, `flutter test` green (including the extended `program_form_screen_test.dart`).
* Repo-root `npm test` green (Node ≥20 — use `nvm use` if the shell default is older), including the extended `drills-upload-meta.test.mjs`, `_shared-feed-item.test.mjs`, `market-feed.test.mjs`, `drills-preview.test.mjs`.
* `npm --prefix site test` green (new `languages.test.ts`), `npm --prefix site run build` succeeds.
* Local end-to-end: `make netlify-dev` in one shell, `make catalog-seed-demos` (now tagging `demo-no.drill`→`nb`, `demo-en.drill`→`en`) and `make catalog-seed` (untouched `test-7x.drill`, no language) in another, `make site-dev` in a third. On `http://localhost:4321/catalog`: the language filter appears with "Norsk" and "English" as options; selecting one hides the other language's card but the untagged `test-7x` plan stays visible under every selection; `/i/demo-no` and `/i/demo-en` each show the right language in their meta line.
* `git status` clean — no untracked or unstaged files.

## Out of scope

* Adding a third UI/plan language (the picker/filter infrastructure supports it for free once a new ARB locale exists — this prompt does not add one).
* Any backfill of existing published plans' `languageCode` — self-heals on next publish, same as every other ADR-0040 field.
* A language filter or badge inside the in-app catalog browser (`lib/views/widgets/catalog_browser.dart`) — this prompt is scoped to the public site and the archive/publish pipeline.
* Fixing the in-app map's missing Kartverket attribution (unrelated, pre-existing, called out in ADR-0040's map addendum).
