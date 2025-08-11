.PHONY: \
	build watch release

.SILENT: \
	build watch release

build:
	echo "Run code generation..."
	dart run build_runner build --delete-conflicting-outputs

watch:
	echo "Watch for buildable changes..."
	dart run build_runner watch --delete-conflicting-outputs

release-android:
	shorebird release android
	#flutter build appbundle --obfuscate --split-debug-info=build/debug-info
	#echo "appbundle path: build/app/outputs/bundle/release/$(ls build/app/outputs/bundle/release/)"
	#flutter pub run sentry_dart_plugin

patch-android:
	shorebird patch android
