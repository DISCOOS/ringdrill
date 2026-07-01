.PHONY: \
	build watch i18n release patch publish \
	build-web build-web-js upload-symbols-web strip-source-maps-web release-web \
	release-android patch-android \
	release-ios patch-ios \
	release-tag release-notes \
	require-clean-tree \
	netlify-dev site-dev catalog-seed catalog-seed-demos catalog-feed catalog-reset

.SILENT: \
	build watch i18n release patch

# Local Netlify dev configuration. Override on the command line, e.g.:
#   make catalog-seed SEED_DRILL=path/to/other.drill
LOCAL_BASE_URL    ?= http://localhost:8888
LOCAL_ADMIN_TOKEN ?= dev-token
SEED_DRILL        ?= test/fixtures/test-7x.drill

# Git commit metadata injected into builds via --dart-define. The values
# get baked into the binary (see lib/utils/app_build_info.dart), surface
# on the About page and ship as a `commit` tag with every Sentry event,
# so a Sentry report can be traced back to the exact source tree even
# when the SemVer build number is reused across patches.
#
# `:=` (not `=`) forces a single eager shell-out: make evaluates this
# once at parse time instead of every reference, which matters because
# `git rev-parse` is not free. The `|| echo unknown` keeps things
# building when the source is extracted outside of a git checkout (e.g.
# a release tarball).
#
# `GIT_DIRTY` appends a `-dirty` suffix when the working tree has
# uncommitted changes. That way a build cut from a half-committed
# workspace can never be confused with the pristine commit on GitHub.
GIT_COMMIT       := $(shell git rev-parse HEAD 2>/dev/null || echo unknown)
GIT_COMMIT_SHORT := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
GIT_DIRTY        := $(shell git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null || echo -dirty)
DART_DEFINE_GIT  := --dart-define=GIT_COMMIT=$(GIT_COMMIT)$(GIT_DIRTY) --dart-define=GIT_COMMIT_SHORT=$(GIT_COMMIT_SHORT)$(GIT_DIRTY)

# Migration kill-switch for ADR-0039 Phase 1. When set to `true` the in-app
# migration banner, drawer entry and explainer are completely hidden. Used
# while Phase 1 is on apex but `web.ringdrill.app` (Phase 2) has not yet
# been stood up, so users do not see a banner pointing at a domain that
# does not resolve. Default empty leaves the host detection in
# lib/web/legacy_host_web.dart in charge.
MIGRATION_DISABLED ?=
DART_DEFINE_MIGRATION := $(if $(MIGRATION_DISABLED),--dart-define=MIGRATION_DISABLED=$(MIGRATION_DISABLED),)

build:
	echo "Run code generation..."
	dart run build_runner build --delete-conflicting-outputs

watch:
	echo "Watch for buildable changes..."
	dart run build_runner watch --delete-conflicting-outputs

# Regenerate Flutter localization sources from lib/l10n/app_*.arb.
# `make build` only covers freezed/json_serializable; the gen-l10n
# step is a separate Flutter tool and must be run after any ARB
# change. The generated `app_localizations*.dart` files must never
# be hand-edited (see CLAUDE.md).
i18n:
	echo "Generate Flutter localizations from ARB..."
	flutter gen-l10n

# Web release pipeline. Decomposed so CI can run the steps individually
# (one log group per step) but `make release-web` is the one-shot used
# locally and as a sanity check.
#
# Why source maps live on disk between build-web and strip-source-maps-web:
# sentry_dart_plugin needs the .map files next to main.dart.js so it can
# resolve the original Dart sources. They are stripped from build/web/
# AFTER upload so they never reach the public CDN — serving them would
# expose the unminified source to anyone who opens DevTools.

# --wasm produces both dart2wasm and dart2js outputs. The
# boot loader picks dart2wasm when the browser supports WASM
# GC (Chrome 119+, Firefox 120+, Safari 18.2+) and falls back
# to dart2js otherwise, so iOS 17 and older users see no
# regression. Expected gain: TBT down ~50-70%, TTI down
# ~30-50%, Performance score up 10-20 points.
#
# Bundle is ~15-25% larger because both compilations ship; the
# CDN serves only one variant per request based on the
# browser's capability headers.
#
# If a WASM-related regression shows up in production, fall
# back to `build-web-js` (dart2js only) until the issue is
# diagnosed. Same release-web wiring works for either target.
build-web:
	flutter build web \
		--wasm \
		--release \
		--pwa-strategy=offline-first \
		--source-maps \
		$(DART_DEFINE_GIT) \
		$(DART_DEFINE_MIGRATION)
	mkdir -p build/web/.well-known
	cp -f web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json

# dart2js-only fallback. Kept around so we can bisect WASM
# regressions without reverting commits, and so we have a
# known-good path if dart2wasm breaks for some plugin update.
# Drops to roughly the bundle size and runtime characteristics
# we had pre-WASM. Swap into release-web by hand:
#   make build-web-js upload-symbols-web strip-source-maps-web
build-web-js:
	flutter build web \
		--release \
		--pwa-strategy=offline-first \
		--source-maps \
		$(DART_DEFINE_GIT) \
		$(DART_DEFINE_MIGRATION)
	mkdir -p build/web/.well-known
	cp -f web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json

upload-symbols-web:
	dart run sentry_dart_plugin

strip-source-maps-web:
	find build/web -type f -name '*.js.map' -delete
	# Also drop the trailing `//# sourceMappingURL=...` comment from the JS.
	# Deleting the .map file alone leaves the reference in main.dart.js, so
	# the browser and Sentry's source scraper still try to fetch the now-404
	# map and log it as a download error. Removing the comment stops that.
	find build/web -type f -name '*.js' -exec sed -i '/^\/\/# sourceMappingURL=/d' {} +

# Refuse to build a release from a working tree that has uncommitted
# changes. Without this gate, $(DART_DEFINE_GIT) would tag the binary
# with `<sha>-dirty`, which:
#   - makes the GitHub link on the About page resolve to "404 — commit
#     not found" because GitHub does not know about the dirty SHA;
#   - leaves Sentry events pointing at a SHA that nobody else can
#     reproduce from the public repo.
#
# Run order matters: we want this to fail BEFORE shorebird or flutter
# burns 5+ minutes building. Make does no parallelism between targets
# in a sequential dependency list, so listing it first guarantees the
# gate runs before the heavy build step.
#
# `git status --short` is shown on failure so the developer sees
# exactly which files need to be committed or stashed instead of
# having to re-run `git status` themselves. The hint about
# `ALLOW_DIRTY=1` is intentionally NOT supported — a release with
# untracked code is the exact bug this gate exists to prevent. If a
# one-off escape hatch ever becomes necessary, add it via a dedicated
# target (e.g. `release-android-dirty`) rather than a flag, so it
# leaves a clear trace in CI logs and shell history.
require-clean-tree:
	@if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then \
		echo "ERROR: refusing to build a release from a dirty working tree."; \
		echo "Commit or stash these changes first:"; \
		git status --short; \
		exit 1; \
	fi

release-web: require-clean-tree build-web upload-symbols-web strip-source-maps-web

release-android: require-clean-tree
	shorebird release android -- \
		--obfuscate \
		--split-debug-info=build/debug-info \
		$(DART_DEFINE_GIT)
	dart run sentry_dart_plugin

patch-android: require-clean-tree
	shorebird patch android -- \
		--obfuscate \
		--split-debug-info=build/debug-info \
		$(DART_DEFINE_GIT)
	dart run sentry_dart_plugin

# iOS release/patch via Shorebird, mirroring the Android targets above:
# same require-clean-tree gate, same --obfuscate / --split-debug-info /
# git dart-defines, same sentry_dart_plugin run afterwards (uploads the
# iOS dSYMs in addition to Android symbols).
#
# Unlike Android these only run on a macOS host with Xcode, and code
# signing must already be configured in ios/Runner.xcodeproj (DISCOOS
# team, app.ringdrill, automatic signing — see ADR-0021). Shorebird drives
# `flutter build ipa` under the hood and signs with that configuration.
#
# `shorebird release ios` produces build/ios/ipa/*.ipa for App Store
# Connect; `shorebird patch ios` ships a code-push patch to the matching
# released version.
release-ios: require-clean-tree
	shorebird release ios -- \
		--obfuscate \
		--split-debug-info=build/debug-info \
		$(DART_DEFINE_GIT)
	dart run sentry_dart_plugin

patch-ios: require-clean-tree
	shorebird patch ios -- \
		--obfuscate \
		--split-debug-info=build/debug-info \
		$(DART_DEFINE_GIT)
	dart run sentry_dart_plugin

# Local backend for development. Uses `netlify functions:serve` (not
# `netlify dev`) because the latter sets up an Edge Functions runtime
# that fails to install reliably on macOS hosts. functions:serve runs the
# Lambda-compat function host directly on $(LOCAL_BASE_URL).
#
# Caveat: redirects in netlify.toml (/api/* and /d/*) do NOT apply here.
# DrillClient already calls /.netlify/functions/* directly, so upload/
# feed/head/admin all work. `ringdrill download <slug>` uses /d/<slug>
# and will return 404 against this mode.
netlify-dev:
	npm install
	ADMIN_TOKEN=$(LOCAL_ADMIN_TOKEN) npx netlify functions:serve --port 8888

# Local Astro dev server for the site/ project. Runs `astro dev` with HMR
# at http://localhost:4321/. No Netlify backend required; the CTAs link to
# the live web.ringdrill.app and play.google.com so there is nothing to stub.
site-dev:
	npm --prefix site install
	npm --prefix site run dev

catalog-seed:
	@test -f $(SEED_DRILL) || { echo "Seed file $(SEED_DRILL) not found. Set SEED_DRILL=<path>"; exit 1; }
	RINGDRILL_BASE_URL=$(LOCAL_BASE_URL) \
	RINGDRILL_ADMIN_TOKEN=$(LOCAL_ADMIN_TOKEN) \
	dart run bin/ringdrill.dart upload $(SEED_DRILL) --published

# Seed the local catalog with the two store-screenshot demo plans (slugs
# `demo-no` and `demo-en`), so they can be opened straight from the in-app
# catalog instead of importing a file by hand. Requires `make netlify-dev`
# running in another shell, and the app started with
# `--dart-define=RINGDRILL_LOCAL_BASE_URL=$(LOCAL_BASE_URL)` so it talks to
# the local backend. Regenerate the files first with
# `python3 tools/screenshots/make_demo_drills.py` if they are missing.
DEMO_DRILLS := tools/screenshots/demo-no.drill tools/screenshots/demo-en.drill
catalog-seed-demos:
	@for f in $(DEMO_DRILLS); do \
		test -f $$f || { echo "Missing $$f. Run: python3 tools/screenshots/make_demo_drills.py"; exit 1; }; \
	done
	@for f in $(DEMO_DRILLS); do \
		echo "Uploading $$f ..."; \
		RINGDRILL_BASE_URL=$(LOCAL_BASE_URL) \
		RINGDRILL_ADMIN_TOKEN=$(LOCAL_ADMIN_TOKEN) \
		dart run bin/ringdrill.dart upload $$f --published || exit 1; \
	done

catalog-feed:
	RINGDRILL_BASE_URL=$(LOCAL_BASE_URL) \
	dart run bin/ringdrill.dart feed

catalog-reset:
	rm -rf .netlify/blobs-serve
	@echo "Local blob store cleared. Restart 'make netlify-dev'."

# Bump pubspec version, prepend a changelog entry, commit and tag.
# Usage:
#   make release-tag VERSION=1.0.3+17    # explicit version
#   make release-tag                     # auto-bump build number only
#
# VERSION must follow Flutter's `X.Y.Z+N` shape (semver + build number),
# matching the format already used for the existing `1.0.0+2` tag and for
# the `version:` line in pubspec.yaml.
#
# Auto-bump mode: when VERSION is not given, the current `X.Y.Z+N` in
# pubspec.yaml is read and `N` is incremented by 1. X.Y.Z stays put. Use
# this for shorebird patches and other release cuts where the user-facing
# semver does not change. To move semver (new minor, new major, etc.),
# pass VERSION explicitly.
#
# The changelog window is `git log <last-tag>..HEAD`. We use the most
# recent annotated/lightweight tag rather than scanning pubspec history,
# so each release-tag invocation lines up cleanly with the previous one
# even if someone hand-edited pubspec.yaml in between. `--no-merges`
# keeps the entry to actual feature/fix commits.
#
# The annotated tag (`git tag -a`) means `git describe` keeps working and
# GitHub renders a Release page out of the box. Push afterwards with:
#   git push --follow-tags
#
# Guard rails:
#   - require-clean-tree first, so the version bump commit is the only
#     thing on top of the previous release;
#   - VERSION (if supplied) must be shaped correctly;
#   - build number `+N` MUST be strictly greater than the current pubspec
#     build number, independent of X.Y.Z. App Store and Play Store both
#     require monotonically increasing build numbers across uploads, so
#     `1.0.3+25 -> 1.1.0+1` is rejected even though semver moved forward;
#   - refuses to overwrite an existing tag;
#   - refuses to "bump" to the version pubspec.yaml is already on (would
#     produce an empty commit and a misleading tag).
release-tag: require-clean-tree
	@set -e; \
	CURRENT=$$(awk '/^version:/ {print $$2; exit}' pubspec.yaml); \
	CUR_BASE=$$(echo "$$CURRENT" | cut -d'+' -f1); \
	CUR_BUILD=$$(echo "$$CURRENT" | cut -d'+' -f2); \
	case "$$CUR_BUILD" in ''|*[!0-9]*) \
		echo "ERROR: cannot parse build number from pubspec version '$$CURRENT'"; \
		exit 1;; \
	esac; \
	if [ -n "$(VERSION)" ]; then \
		NEW_VERSION="$(VERSION)"; \
	else \
		BUMPED="$$CUR_BASE+$$((CUR_BUILD + 1))"; \
		if [ ! -t 0 ]; then \
			echo "No VERSION given (non-interactive). Auto-bumping: $$CURRENT -> $$BUMPED"; \
			NEW_VERSION="$$BUMPED"; \
		else \
			echo ""; \
			echo "Current version: $$CURRENT"; \
			echo ""; \
			echo "  [1] Increment build → $$BUMPED (Enter)"; \
			echo "  [2] Enter version"; \
			echo "  [3] Cancel"; \
			echo ""; \
			printf "Select [1]: "; \
			read CHOICE; \
			case "$$CHOICE" in \
				""|1) NEW_VERSION="$$BUMPED";; \
				2) \
					while true; do \
						printf "New version (X.Y.Z+N, empty to cancel): "; \
						read NEW_VERSION; \
						if [ -z "$$NEW_VERSION" ]; then \
							echo "Cancelled."; exit 1; \
						fi; \
						if ! echo "$$NEW_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$$'; then \
							echo "Invalid. Expected X.Y.Z+N (e.g. 1.2.3+45)."; \
							continue; \
						fi; \
						IN_BUILD=$$(echo "$$NEW_VERSION" | cut -d'+' -f2); \
						if [ "$$IN_BUILD" -le "$$CUR_BUILD" ]; then \
							echo "Invalid. Build number must be > $$CUR_BUILD (got $$IN_BUILD). Store build numbers must increase monotonically."; \
							continue; \
						fi; \
						break; \
					done;; \
				3) echo "Cancelled."; exit 1;; \
				*) echo "Invalid choice."; exit 1;; \
			esac; \
		fi; \
	fi; \
	echo "$$NEW_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$$' || { \
		echo "ERROR: VERSION must look like 1.2.3+45, got '$$NEW_VERSION'"; \
		exit 1; \
	}; \
	NEW_BUILD=$$(echo "$$NEW_VERSION" | cut -d'+' -f2); \
	if [ "$$NEW_BUILD" -le "$$CUR_BUILD" ]; then \
		echo "ERROR: build number must be strictly greater than $$CUR_BUILD (got $$NEW_BUILD)."; \
		echo "       Store build numbers must increase monotonically, independent of X.Y.Z."; \
		exit 1; \
	fi; \
	if git rev-parse --verify --quiet "refs/tags/$$NEW_VERSION" >/dev/null; then \
		echo "ERROR: tag $$NEW_VERSION already exists"; \
		exit 1; \
	fi; \
	if [ "$$CURRENT" = "$$NEW_VERSION" ]; then \
		echo "ERROR: pubspec.yaml is already at $$NEW_VERSION; pick a higher version"; \
		exit 1; \
	fi; \
	echo "Bumping pubspec.yaml: $$CURRENT -> $$NEW_VERSION"; \
	sed -i.bak -E "s/^version: .+/version: $$NEW_VERSION/" pubspec.yaml && rm pubspec.yaml.bak; \
	PREV_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || true); \
	if [ -n "$$PREV_TAG" ]; then RANGE="$$PREV_TAG..HEAD"; else RANGE="HEAD"; fi; \
	DATE=$$(date +%F); \
	{ \
		echo "## $$NEW_VERSION - $$DATE"; \
		echo ""; \
		if [ -n "$$PREV_TAG" ]; then echo "Changes since $$PREV_TAG:"; \
		else echo "Initial changelog entry."; fi; \
		echo ""; \
		git log --no-merges --pretty=format:'- %s (%h)' $$RANGE; \
		echo ""; \
		echo ""; \
		if [ -f CHANGELOG.md ]; then cat CHANGELOG.md; fi; \
	} > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md; \
	git add pubspec.yaml CHANGELOG.md; \
	git commit -m "Released $$NEW_VERSION"; \
	git tag -a "$$NEW_VERSION" -m "Released $$NEW_VERSION"; \
	echo ""; \
	echo "Created tag $$NEW_VERSION. Push with:"; \
	echo "  git push --follow-tags"

# One-shot release: bump version + tag, then build web + Android + iOS.
# Usage:
#   make release VERSION=1.0.3+17    # explicit version
#   make release                     # auto-bump build number only
#
# Order matters:
#   1. release-tag bumps pubspec.yaml, prepends CHANGELOG.md, commits and
#      creates the annotated tag. The version label baked into every build
#      below is read from pubspec.yaml, so the bump MUST happen first.
#      When VERSION is omitted, release-tag increments the build number
#      (`X.Y.Z+N` -> `X.Y.Z+N+1`) from pubspec.yaml.
#   2. release-web, release-android and release-ios run sequentially. They
#      share build/ output and share dart_define inputs, so parallelism
#      would step on itself. iOS also needs a macOS host with Xcode.
#
# Does NOT push. The tag is local until you run:
#   git push --follow-tags
# Intentional — gives one last look at tag, CHANGELOG and built artifacts
# before publishing.
#
# If a build step fails midway, undo the local tag and commit with:
#   git tag -d <version> && git reset --hard HEAD~1
# then re-run after fixing the cause. The current tag is the one at HEAD
# (`git tag --points-at HEAD`).
release: release-tag release-web release-android release-ios
	@VERSION_OUT=$$(awk '/^version:/ {print $$2; exit}' pubspec.yaml); \
	echo ""; \
	echo "Release $$VERSION_OUT built (web + android + ios). Publish with:"; \
	echo "  make publish"

# One-shot Shorebird patch for both stores. Code-push to the X.Y.Z+N
# already on Shorebird's CDN — does NOT bump pubspec.yaml and does NOT
# create a git tag. The git commit metadata baked in via
# $(DART_DEFINE_GIT) still makes the patched binary traceable on the
# About page and in Sentry.
#
# Order matters and the steps are sequential:
#   1. patch-android (works on any host) builds the AAB delta, uploads
#      to Shorebird, then runs sentry_dart_plugin to push the new
#      obfuscation mapping. Mapping is tied to the patch-specific
#      $(GIT_COMMIT), so Sentry can still resolve obfuscated stack
#      traces from this patch.
#   2. patch-ios runs the same flow against the iOS released version.
#      Requires macOS + Xcode; on Linux/Windows this target will fail.
#
# Shorebird does NOT have a single command that patches both platforms
# in one operation — `shorebird patch` takes a single platform
# argument, and the iOS half can only run on macOS. Two operations is
# the only path; this target just chains them so the user does not
# have to.
#
# If the Android half succeeds but the iOS half fails, the Android
# patch is already live. Re-running `make patch` will then attempt a
# second Android patch on top of the first, which Shorebird will
# refuse unless --allow-native-diffs is set. The right recovery is to
# fix the iOS issue and run `make patch-ios` alone.
patch: patch-android patch-ios
	@VERSION_OUT=$$(awk '/^version:/ {print $$2; exit}' pubspec.yaml); \
	echo ""; \
	echo "Patched $$VERSION_OUT (android + ios) via Shorebird code-push."; \
	echo "No tag was created; pubspec.yaml is unchanged."

# Generate Google Play release-notes scaffolding for the current pubspec
# version. Writes store/release-notes/google-play/<version>.txt with the
# two-locale wrapper that Play's Console import expects:
#
#   <en-US>
#   ...
#   </en-US>
#   <no-NO>
#   ...
#   </no-NO>
#
# Behaviour:
#   - Version comes from pubspec.yaml unless VERSION= is passed.
#   - English block is pre-filled from the CHANGELOG.md entry for that
#     version, with `docs/test/chore/build/refactor` commits filtered out
#     and the trailing `(abcdef0)` SHA stripped. The result is raw material
#     to distill into store-friendly copy, not the final text.
#   - Norwegian block stays as a placeholder for now (translation deferred).
#   - Refuses to overwrite an existing file unless FORCE=1.
#   - Reports the per-locale character count and warns if either block
#     exceeds Play's 500-character per-release-note limit.
#
# Usage:
#   make release-notes                     # current pubspec version
#   make release-notes VERSION=1.0.3+27    # explicit version
#   make release-notes FORCE=1             # overwrite an existing file
#
# Not wired into `make release` on purpose: notes are written by hand
# AFTER the bump, often during the upload step in Play Console, so the
# author can read the final CHANGELOG entry before distilling.
release-notes:
	@set -e; \
	if [ -n "$(VERSION)" ]; then \
		VER="$(VERSION)"; \
	else \
		VER=$$(awk '/^version:/ {print $$2; exit}' pubspec.yaml); \
	fi; \
	if [ -z "$$VER" ]; then \
		echo "ERROR: could not resolve version. Pass VERSION= or set version in pubspec.yaml."; \
		exit 1; \
	fi; \
	DIR=store/release-notes/google-play; \
	OUT="$$DIR/$$VER.txt"; \
	mkdir -p "$$DIR"; \
	if [ -f "$$OUT" ] && [ "$(FORCE)" != "1" ]; then \
		echo "ERROR: $$OUT already exists. Re-run with FORCE=1 to overwrite."; \
		exit 1; \
	fi; \
	HINT=$$(awk -v ver="$$VER" ' \
		index($$0, "## " ver " ") == 1 {found=1; next} \
		found && /^## / {exit} \
		found {print} \
	' CHANGELOG.md \
		| grep -E '^- ' \
		| grep -vE '^- (docs|test|chore|build|refactor)(\(|:)' \
		| sed -E 's/ \([0-9a-f]{7,}\)$$//'); \
	{ \
		echo "<en-US>"; \
		if [ -n "$$HINT" ]; then \
			printf '%s\n' "$$HINT"; \
		else \
			echo "Write English release notes here (max 500 chars)."; \
		fi; \
		echo "</en-US>"; \
		echo "<no-NO>"; \
		echo "Skriv norske versjonsnotater her (maks 500 tegn)."; \
		echo "</no-NO>"; \
	} > "$$OUT"; \
	echo "Wrote $$OUT"; \
	echo ""; \
	for LOC in en-US no-NO; do \
		BODY=$$(awk -v loc="$$LOC" '$$0 == "<" loc ">" {f=1; next} $$0 == "</" loc ">" {f=0} f' "$$OUT"); \
		LEN=$$(printf '%s' "$$BODY" | wc -c | tr -d ' '); \
		if [ "$$LEN" -gt 500 ]; then \
			echo "WARN: $$LOC is $$LEN chars, Play caps each note at 500."; \
		else \
			echo "OK:   $$LOC is $$LEN chars (limit 500)."; \
		fi; \
	done

# Push the release commit and tag to origin. Pair with `make release`.
#
# What ends up where:
#   - Web: `git push` triggers .github/workflows/deploy-web.yml, which
#     rebuilds on GHA, uploads symbols to Sentry, and deploys to Netlify.
#     ~5-7 minutes from push to live on ringdrill.app.
#   - Android/iOS: already on Shorebird's CDN — `shorebird release` uploaded
#     during `make release`. The push only ships the commit/tag on GitHub
#     for traceability and About-page deep links.
#
# Guards:
#   - require-clean-tree so no untracked changes ride along with the push;
#   - HEAD must carry a tag, otherwise there is no release to publish and
#     `--follow-tags` would silently just push commits.
publish: require-clean-tree
	@TAG=$$(git tag --points-at HEAD | head -n1); \
	if [ -z "$$TAG" ]; then \
		echo "ERROR: HEAD has no tag. Run 'make release VERSION=...' first."; \
		exit 1; \
	fi; \
	echo "Publishing $$TAG ..."; \
	git push --follow-tags

