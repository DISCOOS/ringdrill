.PHONY: \
	build watch release \
	build-web build-web-js upload-symbols-web strip-source-maps-web release-web \
	release-android patch-android \
	release-ios patch-ios \
	release-tag \
	require-clean-tree \
	netlify-dev catalog-seed catalog-feed catalog-reset

.SILENT: \
	build watch release

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

build:
	echo "Run code generation..."
	dart run build_runner build --delete-conflicting-outputs

watch:
	echo "Watch for buildable changes..."
	dart run build_runner watch --delete-conflicting-outputs

# Web release pipeline. Decomposed so CI can run the steps individually
# (one log group per step) but `make release-web` is the one-shot used
# locally and as a sanity check.
#
# Why source maps live on disk between build-web and strip-source-maps-web:
# sentry_dart_plugin needs the .map files next to main.dart.js so it can
# resolve the original Dart sources. They are stripped from build/web/
# AFTER upload so they never reach the public CDN — serving them would
# expose the unminified source to anyone who opens DevTools.

build-web:
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
	flutter build web \
		--wasm \
		--release \
		--pwa-strategy=offline-first \
		--source-maps \
		$(DART_DEFINE_GIT)
	mkdir -p build/web/.well-known
	cp -f web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json

build-web-js:
	# dart2js-only fallback. Kept around so we can bisect WASM
	# regressions without reverting commits, and so we have a
	# known-good path if dart2wasm breaks for some plugin update.
	# Drops to roughly the bundle size and runtime characteristics
	# we had pre-WASM. Swap into release-web by hand:
	#   make build-web-js upload-symbols-web strip-source-maps-web
	flutter build web \
		--release \
		--pwa-strategy=offline-first \
		--source-maps \
		$(DART_DEFINE_GIT)
	mkdir -p build/web/.well-known
	cp -f web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json

upload-symbols-web:
	dart run sentry_dart_plugin

strip-source-maps-web:
	find build/web -type f -name '*.js.map' -delete

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
	@echo "Local blob store cleared. Restart 'make netlify-dev'."

# Bump pubspec version, prepend a changelog entry, commit and tag.
# Usage:
#   make release-tag VERSION=1.0.3+17
#
# VERSION must follow Flutter's `X.Y.Z+N` shape (semver + build number),
# matching the format already used for the existing `1.0.0+2` tag and for
# the `version:` line in pubspec.yaml.
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
#   - VERSION must be supplied and shaped correctly;
#   - refuses to overwrite an existing tag;
#   - refuses to "bump" to the version pubspec.yaml is already on (would
#     produce an empty commit and a misleading tag).
release-tag: require-clean-tree
	@test -n "$(VERSION)" || { \
		echo "ERROR: set VERSION=X.Y.Z+N (e.g. make release-tag VERSION=1.0.3+17)"; \
		exit 1; \
	}
	@echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$$' || { \
		echo "ERROR: VERSION must look like 1.2.3+45, got '$(VERSION)'"; \
		exit 1; \
	}
	@if git rev-parse --verify --quiet "refs/tags/$(VERSION)" >/dev/null; then \
		echo "ERROR: tag $(VERSION) already exists"; \
		exit 1; \
	fi
	@CURRENT=$$(awk '/^version:/ {print $$2; exit}' pubspec.yaml); \
	if [ "$$CURRENT" = "$(VERSION)" ]; then \
		echo "ERROR: pubspec.yaml is already at $(VERSION); pick a higher version"; \
		exit 1; \
	fi; \
	echo "Bumping pubspec.yaml: $$CURRENT -> $(VERSION)"
	@sed -i.bak -E 's/^version: .+/version: $(VERSION)/' pubspec.yaml && rm pubspec.yaml.bak
	@PREV_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || true); \
	if [ -n "$$PREV_TAG" ]; then RANGE="$$PREV_TAG..HEAD"; else RANGE="HEAD"; fi; \
	DATE=$$(date +%F); \
	{ \
		echo "## $(VERSION) - $$DATE"; \
		echo ""; \
		if [ -n "$$PREV_TAG" ]; then echo "Changes since $$PREV_TAG:"; \
		else echo "Initial changelog entry."; fi; \
		echo ""; \
		git log --no-merges --pretty=format:'- %s (%h)' $$RANGE; \
		echo ""; \
		echo ""; \
		if [ -f CHANGELOG.md ]; then cat CHANGELOG.md; fi; \
	} > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md
	@git add pubspec.yaml CHANGELOG.md
	@git commit -m "Released $(VERSION)"
	@git tag -a "$(VERSION)" -m "Released $(VERSION)"
	@echo ""
	@echo "Created tag $(VERSION). Push with:"
	@echo "  git push --follow-tags"

