# ADR-0039 Phase 1 — Final Flutter release with migration banner and bulk export

You are working in the RingDrill repository. Implement Phase 1 of [ADR-0039](../adrs/0039-site-pwa-api-origins.md). The ADR is accepted and is the authoritative spec. Read it in full before starting, especially the "Phase 1" subsection in "Rollout phases" and the "User data migration" section.

## Why Phase 1 ships first

Phase 1 is the only programmatic channel we have into existing PWA installs. Cached Flutter PWAs on apex update their SW within hours of a release (entry points are no-cache per ADR-0016). After Phase 1 lands, every installed PWA has the in-app migration UI and the bulk export available, so Phases 2 and 3 can proceed without leaving users in the dark.

## Scope

Flutter-only. No backend changes, no Cloudflare or DNS work, no new ADRs. Only files under `lib/`, `test/` and `lib/l10n/`. Existing patterns and design tokens. No new design system.

## Steps

### Step 1 — Origin detection

Add a helper that returns `true` when the running PWA is on the legacy apex origin and `false` everywhere else.

* Web release builds on host `ringdrill.app` → `true`.
* `web.ringdrill.app`, `localhost`, deploy previews, any other host → `false`.
* Native builds → `false`.
* Test environments must not throw.
* A `--dart-define=RINGDRILL_FORCE_LEGACY_HOST=true` debug-only override returns `true` so the banner can be exercised in local dev without DNS hacks.

Place it next to existing host/env logic in `lib/web/`. If `web_env.dart` can be extended cleanly, do that. Otherwise create a new file with a non-web stub following the `pwa_update_stub.dart` / `pwa_update_web.dart` pattern.

Unit test covers the four cases above plus the debug override.

Commit: `feat(web): detect when PWA is running on the legacy apex origin`. Verify `git status` is clean before continuing.

### Step 2 — Bulk export

Add an "export all programs" function in `lib/data/` next to `drill_file.dart`.

* Iterates all programs via `ProgramService.listPrograms()` and `ProgramRepository`.
* Produces one `.drill` archive per program using `DrillFile.write()` (existing pipeline, ADR-0007).
* Bundles every archive into one outer ZIP. Filename: `ringdrill-eksport-YYYY-MM-DD.zip` (local-date).
* Returns bytes for the caller to hand off to `share_plus` (native) or a browser download (web).
* Works on both native and web. Use the same ZIP library `DrillFile` already uses.

Unit test builds a small in-memory program list, runs the export, unzips the outer archive, and asserts the expected number of `.drill` files with sensible filenames.

Commit: `feat(data): bulk-export all programs as one ZIP for migration`. Verify `git status` is clean.

### Step 3 — Migration banner

Build `MigrationBanner` under `lib/views/shell/` per ADR-0028. Wire it into the shell (`WideShell` and the narrow-shell equivalent) so it renders at the top of the app on every screen.

Content (two lines, bold heading + body):

* Heading nb: "Web-appen flytter til web.ringdrill.app."
* Heading en: "The web app is moving to web.ringdrill.app."
* Body nb: "Last ned planene dine her og åpne den nye appen."
* Body en: "Download your plans here and open the new app."

Actions:

* Primary "Eksporter alle planene mine" / "Export all my plans" — calls Step 2 export, hands the ZIP to `share_plus` on native or triggers a `<a download>` on web.
* Secondary "Åpne den nye appen" / "Open the new app" — opens `https://web.ringdrill.app/` in a new tab.

Dismiss behaviour:

* Banner is dismissable per-session via a small close affordance.
* Dismiss writes `app:migrationBannerDismissedAt:v1` to `SharedPreferences` (timestamp).
* Banner reappears 24 hours after dismiss.
* Banner only renders when the Step 1 helper returns `true`.

i18n strings go into `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. Run `make i18n` after editing ARB files (`make build` does not regenerate l10n).

Widget test covers visible state, dismiss, primary action triggers export, secondary action calls the URL launcher (mock the launcher).

Commit: `feat(shell): add in-app migration banner with export and open-new-app actions`. Verify `git status` is clean.

### Step 4 — Settings entry "Om migrasjon"

Add a "Om migrasjon" / "About the migration" entry to the settings page (`lib/views/settings_page.dart`, and the web variant `lib/web/settings_page.dart` if it has its own list).

The entry opens a page that renders a markdown explainer via the existing brief-renderer pipeline (same pattern as DESIGN-007 onboarding/FAQ help). Content sources:

* `lib/l10n/migration_explainer_nb.md`
* `lib/l10n/migration_explainer_en.md`

Explainer covers:

* Why we are moving (one short paragraph)
* What changes for the user (PWA lives at the new origin, install fresh there)
* How to migrate data (export here → open new app → import)
* What happens to data on the old origin (stays in browser storage until cleared, can be re-exported from the new `/migrate` page after Phase 3)

Page ends with a button that re-triggers the same Step 2 export.

Commit: `feat(settings): add Om migrasjon page with explainer and re-export action`. Verify `git status` is clean.

### Step 5 — Verification

Before declaring Phase 1 done:

* `flutter analyze` clean
* `flutter test` clean (no skips except pre-existing ones documented in CI)
* Run web debug build with `--dart-define=RINGDRILL_FORCE_LEGACY_HOST=true` and confirm in a real browser:
  - Banner appears at top of app on every screen
  - Primary action downloads `ringdrill-eksport-YYYY-MM-DD.zip` with one `.drill` per program
  - Outer ZIP unpacks cleanly and the inner `.drill` files import successfully into a fresh program library
  - Secondary action opens a new tab to `https://web.ringdrill.app/`
  - Dismissing the banner removes it; reopening the app within 24h keeps it dismissed; after 24h it returns
  - Settings → Om migrasjon opens the explainer with working re-export button
* On a release web build pointed at the production apex (or a deploy preview), confirm the banner renders without the dart-define override (because the host matches)
* `git status` is clean

Any verification-driven fixes go in their own `fix(...)` commits.

## Out of scope

Do NOT touch any of the following as part of this prompt. They are Phase 2 and Phase 3 and will be separate prompts.

* Cloudflare Pages setup, `wrangler`, GHA workflows for Cloudflare
* DNS authority change (Netlify → Cloudflare)
* Astro source under `site/`
* New Netlify function `drills-preview.js`
* `_redirects` proxy rules on apex
* Self-unregister SW stub
* `AppConfig.catalogBaseUrl()` change for `web.ringdrill.app`
* `ALLOWED_ORIGIN_PATTERNS` extension
* `/migrate` page on Astro

If you discover that any of these become necessary to make Phase 1 work, stop and report. Do not bundle them into this commit set.

## Definition of done

* Five commits in order: `feat(web)`, `feat(data)`, `feat(shell)`, `feat(settings)`, plus any verification `fix(...)`.
* `git status` clean after every commit and at the end.
* `flutter analyze` and `flutter test` pass.
* Manual verification per Step 5 passes.
* The change set ships through the existing `.github/workflows/deploy-web.yml` to the Netlify-hosted apex with no other infrastructure touched.

## Commit message conventions

Conventional commits, lowercase, imperative present tense, English. Match the style of recent commits in the repo. Each step has its own commit; do not squash.
