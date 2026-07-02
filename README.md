# RingDrill App

Efficient station-based training. Organize, run and track drills with ease. 

[![Google Play](https://playbadges.pavi2410.me/badge/full?id=org.discoos.ringdrill)](https://play.google.com/store/apps/details?id=org.discoos.ringdrill)
[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/no/app/ringdrill-app/id6777269410)

## Online version
[![Deploy origins](https://github.com/DISCOOS/ringdrill/actions/workflows/deploy-origins.yml/badge.svg)](https://github.com/DISCOOS/ringdrill/actions/workflows/deploy-origins.yml)
[![Deploy apex proxy](https://github.com/DISCOOS/ringdrill/actions/workflows/deploy-proxy.yml/badge.svg)](https://github.com/DISCOOS/ringdrill/actions/workflows/deploy-proxy.yml)
[![Netlify Status](https://api.netlify.com/api/v1/badges/1da1f642-4138-499f-8e22-6679dfddd3cd/deploy-status)](https://app.netlify.com/projects/ringdrill/deploys)

Live web-version is available on https://web.ringdrill.app

## Documentation

* [`docs/architecture.md`](docs/architecture.md): project overview, tech stack, repo layout, conventions, backend contract, and where to look first when navigating the code.
* [`docs/adrs/`](docs/adrs/): Architecture Decision Records (MADR format). Read these to understand why a non-obvious choice was made, and add a new one when you make such a choice.
* [`AGENTS.md`](AGENTS.md): operating guide for AI coding agents (Claude Code, Codex, Cursor, etc.) and a quick orientation for human contributors. Read this before letting an agent change code.
* [`CLAUDE.md`](CLAUDE.md): short pointer file read by Claude Code on startup, defers to `AGENTS.md`.
* [`docs/feature-flags.md`](docs/feature-flags.md): living index of every build-time dart-define flag, its purpose and its sunset criterion. Updated in the same commit as a flag is added, changed or removed.

## Getting Started
To get started with developing for RingDrill using Flutter, follow these steps:

1. **Clone the Repository**:  
   Clone the RingDrill repository to your local machine:
   ```bash
   git clone https://github.com/DISCOOS/ringdrill.git
   ```

2. **Set Up Development Environment**:  
   Ensure you have the following prerequisites installed:
   - [Flutter SDK](https://flutter.dev/docs/get-started/install)
   - Appropriate code editor (e.g., [Android Studio](https://developer.android.com/studio) with the Flutter and Dart plugins or [Visual Studio Code](https://code.visualstudio.com/) with Flutter extension)
   - JDK 17 or higher if you're targeting Android
   - Xcode installed if you're targeting iOS

3. **Configure the Project**:
   - Run the following commands in the project’s root directory to ensure all dependencies are installed:
     ```bash
     flutter pub get
     ```
   - Android `compileSdk` is delegated to `flutter.compileSdkVersion` in `android/app/build.gradle.kts`; override only if you need to pin it.
   - If you're targeting iOS, ensure that the iOS deployment target is appropriately set in `ios/Podfile`.

4. **Generate Code Using Build Runner**:  
   Generate any required code for the project by running:
   ```bash
   make build
   ```

5. **Enable Build Runner Watch Mode (Optional)**:  
   To automatically rebuild generated code when making changes, you can run:
   ```bash
   make watch
   ```

6. **Cut a Release** (one-shot):
   `make release` bumps `pubspec.yaml`, prepends a `CHANGELOG.md` entry,
   commits and tags, then builds web + Android + iOS. iOS requires a macOS
   host with Xcode and signing configured per ADR-0021.
   ```bash
   make release                     # interactive: prompts for version
   make release VERSION=1.0.3+17    # non-interactive: use this exact version
   ```
   Without `VERSION` you get a prompt:
   ```
     [1] Increment build → X.Y.Z+N+1   (Enter)
     [2] Enter version
     [3] Cancel
   ```
   Rules enforced by `release-tag` (the first step inside `release`):
   - working tree must be clean;
   - `VERSION` (if supplied) must match `X.Y.Z+N`;
   - build number `+N` must be strictly greater than the current pubspec
     build number, independent of `X.Y.Z` — App Store and Play Store both
     require monotonically increasing build numbers across uploads, so
     `1.0.3+25 -> 1.1.0+1` is rejected;
   - refuses to overwrite an existing tag, or to "bump" to the version
     `pubspec.yaml` is already on.

   To run individual steps instead of the one-shot:
   ```bash
   make release-tag      # version bump + commit + tag only
   make release-web      # web build + Sentry symbols
   make release-android  # Shorebird Android release
   make release-ios      # Shorebird iOS release
   ```

7. **Publish the Release**:
   The tag is local until you push. Sanity-check the artifacts first, then:
   ```bash
   make publish          # git push --follow-tags (refuses dirty trees)
   ```
   Pushing the tag triggers the web deploy workflow on GitHub Actions;
   Shorebird Android/iOS are already on Shorebird's CDN from step 6.

   To tag a previous commit (e.g. retroactively tag the commit that bumped
   to `1.0.2+16`), pass the SHA to `git tag` directly:
   ```bash
   git tag -a "1.0.2+16" <sha> -m "Released 1.0.2+16"
   git push origin 1.0.2+16
   ```

8. **Patch Builds** (*Optional*):
   If deploying incremental code-push patch updates, run:
   ```bash
   make patch-android
   make patch-ios
   ```

9. **Run the Application**:  
   Start the project on your desired emulator or physical device:
   ```bash
   flutter run
   ```
   
10. **Run the Admin CLI**:
    To activate:
    ```bash
    dart pub global activate -s path .
    ```
    See usage for additional information:
    ```bash
    ringdrill -h
    ```

11. **Run the Netlify backend locally**:
    Start the Netlify function host (with emulated blob store) on your machine:
    ```bash
    make netlify-dev
    ```
    Seed it with a sample drill, list the feed, or reset the local store:
    ```bash
    make catalog-seed     # uploads test/fixtures/test-7x.drill and publishes it
    make catalog-feed     # lists the market feed
    make catalog-reset    # clears .netlify/blobs-serve (with the backend stopped)
    ```
    See [`docs/architecture.md`](docs/architecture.md#running-the-backend-locally) for the full workflow (including how to point the Flutter app at the local backend) and the known limitation around the `/d/<slug>` deep-link path. The rationale is in [ADR-0013](docs/adrs/0013-local-catalog-testing.md).