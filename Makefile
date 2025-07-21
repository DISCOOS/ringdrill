.PHONY: \
	release

.SILENT: \
	release

release:
	flutter build appbundle --obfuscate --split-debug-info=build/debug-info
	echo "appbundle path: build/app/outputs/bundle/release/$(ls build/app/outputs/bundle/release/)"
	#flutter pub run sentry_dart_plugin