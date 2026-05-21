.PHONY: \
	build watch release netlify-dev

.SILENT: \
	build watch release

# Local Netlify dev server (functions + emulated blob store)
LOCAL_ADMIN_TOKEN ?= dev-token

build:
	echo "Run code generation..."
	dart run build_runner build --delete-conflicting-outputs

watch:
	echo "Watch for buildable changes..."
	dart run build_runner watch --delete-conflicting-outputs

web:
	flutter build web --pwa-strategy=offline-first --release --web-renderer canvaskit

release-android:
	shorebird release android
	#flutter build appbundle --obfuscate --split-debug-info=build/debug-info
	#echo "appbundle path: build/app/outputs/bundle/release/$(ls build/app/outputs/bundle/release/)"
	#flutter pub run sentry_dart_plugin

patch-android:
	shorebird patch android

netlify-dev:
	npm install
	ADMIN_TOKEN=$(LOCAL_ADMIN_TOKEN) npx netlify dev

