.PHONY: \
	build watch release \
	build-web build-web-js upload-symbols-web strip-source-maps-web release-web \
	smoke-web \
	netlify-dev catalog-seed catalog-feed catalog-reset

.SILENT: \
	build watch release

# Local Netlify dev configuration. Override on the command line, e.g.:
#   make catalog-seed SEED_DRILL=path/to/other.drill
LOCAL_BASE_URL    ?= http://localhost:8888
LOCAL_ADMIN_TOKEN ?= dev-token
SEED_DRILL        ?= test/fixtures/test-7x.drill

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
		--source-maps
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
		--source-maps
	mkdir -p build/web/.well-known
	cp -f web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json

upload-symbols-web:
	dart run sentry_dart_plugin

strip-source-maps-web:
	find build/web -type f -name '*.js.map' -delete

release-web: build-web upload-symbols-web strip-source-maps-web

# Post-deploy smoke test against the production URL. Catches the class
# of failure that widget tests cannot see: a UI that compiles, ships
# and boots but doesn't actually paint anything (Stack-collapse,
# missing function deploy, uncaught error during boot). Override
# SMOKE_URL to point at a different environment.
SMOKE_URL ?= https://ringdrill.app
smoke-web:
	SMOKE_URL=$(SMOKE_URL) node scripts/smoke-test-web.mjs

release-android:
	shorebird release android -- \
		--obfuscate \
		--split-debug-info=build/debug-info
	dart run sentry_dart_plugin

patch-android:
	shorebird patch android -- \
		--obfuscate \
		--split-debug-info=build/debug-info
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

