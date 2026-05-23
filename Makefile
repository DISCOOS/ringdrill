.PHONY: \
	build watch release \
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

web:
	flutter build web --pwa-strategy=offline-first --release --web-renderer canvaskit

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

