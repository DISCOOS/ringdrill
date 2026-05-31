# Implement ADR-0021

You are working in the RingDrill repository. Implement ADR-0021 ("Use `app.ringdrill` as the iOS and macOS bundle identifier and keep `org.discoos.ringdrill` on Android") end-to-end. The ADR lives at `docs/adrs/0021-ios-bundle-identifier-app-ringdrill.md` and is **Accepted**. It is the authoritative spec for every identifier in the table and for the per-file changes in "Concrete Apple-side migration".

This prompt covers ADR-0021 only. If you find unrelated defects, record them as follow-ups under `docs/prompts/` named `adr-0021-followup-NN-<slug>.md`. Do not bundle.

## Prerequisite (off-repo, must be done before Step 1)

The maintainer must complete the Apple Developer portal work in step 1 of the ADR's migration plan before this prompt is runnable:

1. App ID `app.ringdrill` registered under the **DISCOOS** team with iOS **and** macOS platform boxes checked, plus capabilities for App Groups and Associated Domains.
2. App Group `group.app.ringdrill` registered.
3. Share-extension App ID `app.ringdrill.RingDrillShareExtension` registered.
4. Development and Distribution profiles generated for iOS Runner, iOS RingDrillShareExtension and macOS Runner.

You also need the **DISCOOS team ID** (a 10-character alphanumeric string from Apple Developer → Membership). It replaces `5S49AAAL87` in the iOS pbxproj and is the prefix for the AASA `appID`.

Do not start without:

* Confirmation from the maintainer that 1–4 above are done.
* The DISCOOS team ID. If the maintainer has not provided it, stop and ask. Do not invent it, do not use the current personal value `5S49AAAL87`, do not leave a literal `<DISCOOS_TEAM_ID>` placeholder in committed files. (Placeholders in the AASA file or pbxproj will break signing or Universal Links.)

Throughout this prompt, `${TEAM}` stands for that team ID.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. Non-negotiable for this change:

* No Dart, no `lib/` changes. This is an Apple-platform configuration migration. The only repo paths touched are under `ios/`, `macos/`, `web/.well-known/` and `netlify.toml`.
* The user-facing URL scheme `ringdrill://` does not change. The Sentry project slug `discoos/ringdrill` does not change. The Shorebird `app_id` does not change. The Android `applicationId = org.discoos.ringdrill` does not change.
* Android assets are unchanged. `web/.well-known/assetlinks.json` keeps `org.discoos.ringdrill` as the `package_name` (this is intentional — Android stays on the old ID per ADR).
* Match existing formatting in Swift and plist files. Do not reorder existing keys. Do not normalise whitespace in `project.pbxproj`.
* `test/widget_test.dart` is the known-broken default-template smoke test. Do not try to fix it.

## Commits

Five commits, in order, on the same working branch. Conventional Commits with scopes as listed. Suggested subjects:

1. `chore(ios): rename bundle IDs to app.ringdrill and pin DISCOOS team`
2. `fix(ios): rename App Group to group.app.ringdrill and fix .dev container bug`
3. `chore(ios): rename UTI to app.ringdrill.drill and update CFBundleURLName`
4. `chore(macos): switch bundle ID to app.ringdrill and pin DISCOOS team`
5. `feat(web): publish apple-app-site-association for ringdrill.app Universal Links`

### Commit discipline (non-negotiable)

* After every step, run `git status` and `git diff --stat`. No untracked or unstaged paths before claiming the step done.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Nothing else.
* Never `git stash` or `git restore` to close a step.
* The Verification gate at the end requires `git status` to print a clean tree with no untracked or unstaged files.

## Scope

### Step 1. iOS bundle IDs and DISCOOS team

Edit `ios/Runner.xcodeproj/project.pbxproj`.

Replace identifiers across Debug, Release and Profile configurations. Use the existing line numbers as anchors (the file has not been touched since the ADR was written):

* Line 558 — `Runner` Debug: `PRODUCT_BUNDLE_IDENTIFIER = org.discoos.ringdrill;` → `PRODUCT_BUNDLE_IDENTIFIER = app.ringdrill;`
* Line 743 — `Runner` Release: same replacement.
* Line 768 — `Runner` Profile: same replacement.
* Line 575 — `RunnerTests` Debug: `org.discoos.ringdrill.RunnerTests` → `app.ringdrill.RunnerTests`.
* Line 593 — `RunnerTests` Release: same replacement.
* Line 609 — `RunnerTests` Profile: same replacement.
* Line 807 — `RingDrillShareExtension` Debug: `org.discoos.ringdrill.RingDrillShareExtension` → `app.ringdrill.RingDrillShareExtension`.
* Line 848 — `RingDrillShareExtension` Release: same replacement.
* Line 887 — `RingDrillShareExtension` Profile: same replacement.

Replace `DEVELOPMENT_TEAM` in all six occurrences (`5S49AAAL87` → `${TEAM}`):

* Line 550 — `Runner` Debug.
* Line 735 — `Runner` Release.
* Line 760 — `Runner` Profile.
* Line 790 — `RingDrillShareExtension` Debug.
* Line 832 — `RingDrillShareExtension` Release.
* Line 871 — `RingDrillShareExtension` Profile.

After edits, sanity-check with:

```
grep -n "PRODUCT_BUNDLE_IDENTIFIER\|DEVELOPMENT_TEAM" ios/Runner.xcodeproj/project.pbxproj
```

Every line printed must contain either `app.ringdrill`, `app.ringdrill.RunnerTests`, `app.ringdrill.RingDrillShareExtension`, or the actual DISCOOS team ID. Zero matches for `org.discoos.ringdrill` or `5S49AAAL87`.

Files expected in this commit:

* `ios/Runner.xcodeproj/project.pbxproj`

Run `git status`. Commit: `chore(ios): rename bundle IDs to app.ringdrill and pin DISCOOS team`.

### Step 2. iOS App Group rename and the `.dev` fix

Edit `ios/Runner/Runner.entitlements` line 7:

```diff
- <string>group.org.discoos.ringdrill</string>
+ <string>group.app.ringdrill</string>
```

Edit `ios/RingDrillShareExtension/RingDrillShareExtension.entitlements` line 7: same replacement.

Edit `ios/Runner/AppDelegate.swift` line 38:

```diff
-            .containerURL(forSecurityApplicationGroupIdentifier: "group.org.discoos.ringdrill")?
+            .containerURL(forSecurityApplicationGroupIdentifier: "group.app.ringdrill")?
```

Edit `ios/RingDrillShareExtension/ShareViewController.swift` line 40:

```diff
-    guard let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.org.discoos.ringdrill.dev") else {
+    guard let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.app.ringdrill") else {
```

The `.dev` suffix is the bug the ADR's Consequences section calls out: the share extension was writing to a container the main app does not read from. Removing it is the fix that rides with the App Group rename — do not split this into a separate commit, because the rename and the bug fix touch the same string on the same line.

Sanity-check:

```
grep -rn "group.org.discoos\|group.app.ringdrill.dev" ios/
```

Must return zero matches.

Files expected in this commit:

* `ios/Runner/Runner.entitlements`
* `ios/RingDrillShareExtension/RingDrillShareExtension.entitlements`
* `ios/Runner/AppDelegate.swift`
* `ios/RingDrillShareExtension/ShareViewController.swift`

Run `git status`. Commit: `fix(ios): rename App Group to group.app.ringdrill and fix .dev container bug`.

### Step 3. iOS UTI and CFBundleURLName

Edit `ios/Runner/Info.plist`. Three string values change. The URL scheme `ringdrill` (line 97) is unchanged.

* Line 61 — `LSItemContentTypes` array, `org.discoos.ringdrill` → `app.ringdrill.drill`.
* Line 69 — `UTExportedTypeDeclarations` → `UTTypeIdentifier`, `org.discoos.ringdrill` → `app.ringdrill.drill`.
* Line 94 — `CFBundleURLTypes` → `CFBundleURLName`, `org.discoos.ringdrill` → `app.ringdrill`.

ADR rationale: the current UTI string `org.discoos.ringdrill` is identical to a bundle ID on another team, which is exactly the conflict Apple's UTI documentation warns against. `app.ringdrill.drill` follows the recommended `<owned reverse-DNS>.<type>` pattern. `CFBundleURLName` is metadata that Apple recommends matching the owning bundle ID; the URL scheme itself stays `ringdrill`.

Sanity-check:

```
grep -n "discoos" ios/Runner/Info.plist
```

Must return zero matches.

Files expected in this commit:

* `ios/Runner/Info.plist`

Run `git status`. Commit: `chore(ios): rename UTI to app.ringdrill.drill and update CFBundleURLName`.

### Step 4. macOS bundle ID and DISCOOS team

Edit `macos/Runner/Configs/AppInfo.xcconfig`:

* Line 11: `PRODUCT_BUNDLE_IDENTIFIER = org.discoos.ringdrill` → `PRODUCT_BUNDLE_IDENTIFIER = app.ringdrill`.
* Line 14: replace the copyright `Copyright © 2025 org.discoos. All rights reserved.` with a string that names the organisation rather than the legacy bundle prefix. Suggested: `Copyright © 2025 DISCOOS. All rights reserved.` Confirm wording with the maintainer if unsure — otherwise pick the suggested form.

Edit `macos/Runner.xcodeproj/project.pbxproj`:

* Line 388 — `RunnerTests` Debug: `PRODUCT_BUNDLE_IDENTIFIER = org.discoos.ringdrill.RunnerTests;` → `PRODUCT_BUNDLE_IDENTIFIER = app.ringdrill.RunnerTests;`
* Line 402 — `RunnerTests` Release: same replacement.
* Line 416 — `RunnerTests` Profile: same replacement.

Add `DEVELOPMENT_TEAM = ${TEAM};` to the build settings of both `Runner` (Debug, Release, Profile) and `RunnerTests` (Debug, Release, Profile) — six insertions total in the pbxproj.

Today the macOS pbxproj has no `DEVELOPMENT_TEAM` line. Place the new line alphabetically inside each affected `buildSettings = { ... }` block (typically next to `CURRENT_PROJECT_VERSION` or `CODE_SIGN_STYLE`). Preserve the existing tab indentation. Quote the value only if other identifiers in the block are quoted; otherwise leave bare.

Sanity-check:

```
grep -n "PRODUCT_BUNDLE_IDENTIFIER\|DEVELOPMENT_TEAM\|org.discoos" macos/Runner.xcodeproj/project.pbxproj macos/Runner/Configs/AppInfo.xcconfig
```

Every printed line for `PRODUCT_BUNDLE_IDENTIFIER` must contain `app.ringdrill` or `app.ringdrill.RunnerTests`. Every printed `DEVELOPMENT_TEAM` must contain the DISCOOS team ID. Zero matches for `org.discoos`.

Files expected in this commit:

* `macos/Runner/Configs/AppInfo.xcconfig`
* `macos/Runner.xcodeproj/project.pbxproj`

Run `git status`. Commit: `chore(macos): switch bundle ID to app.ringdrill and pin DISCOOS team`.

### Step 5. Apple App Site Association (Universal Links)

Create `web/.well-known/apple-app-site-association` (no extension). Content:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "${TEAM}.app.ringdrill",
        "paths": ["/i/*"]
      }
    ]
  }
}
```

Substitute the real DISCOOS team ID for `${TEAM}`. One file covers both iOS and macOS because the bundle ID is shared. Path `/i/*` matches the install-link host pattern from ADR-0015 (the Android counterpart in `assetlinks.json` covers the same `/i/<slug>` route via App Links).

Edit `netlify.toml`. The existing `/.well-known/*` redirect already serves the file as-is. Add a headers block so Netlify serves the file with `Content-Type: application/json` and no caching surprises. Place this block next to the existing `assetlinks.json` header block:

```toml
[[headers]]
    for = "/.well-known/apple-app-site-association"
    [headers.values]
        Content-Type = "application/json"
        Cache-Control = "public, max-age=3600"
```

Apple requires the file to be served as JSON with no extension. The `Content-Type` header is what makes Netlify do this, since the file has no `.json` extension to drive type detection.

Verify locally with:

```
cat web/.well-known/apple-app-site-association | python3 -m json.tool
```

Must parse without error.

Files expected in this commit:

* `web/.well-known/apple-app-site-association`
* `netlify.toml`

Run `git status`. Commit: `feat(web): publish apple-app-site-association for ringdrill.app Universal Links`.

## Verification

1. `flutter analyze` clean. (No Dart changed, but run it as a smoke test to confirm nothing slipped.)
2. `flutter test` no new failures. `test/widget_test.dart` remains broken; flag as known.
3. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing. No `git stash` or `git restore` used.
4. **Diff sanity.** `git log --stat origin/main..HEAD` — every changed path in its intended commit, no path appears in two commits.
5. **Grep gate (iOS).**

   ```
   grep -rn "org.discoos.ringdrill\|5S49AAAL87\|group.org.discoos\|group.app.ringdrill.dev" ios/
   ```

   Returns zero matches.
6. **Grep gate (macOS).**

   ```
   grep -rn "org.discoos.ringdrill" macos/
   ```

   Returns zero matches.
7. **Grep gate (Android untouched).**

   ```
   grep -n "package_name" web/.well-known/assetlinks.json
   ```

   Still reads `"package_name": "org.discoos.ringdrill"`. (Android stays on the old ID per ADR. Do not touch this file.)
8. **AASA gate.**

   ```
   python3 -m json.tool < web/.well-known/apple-app-site-association
   ```

   Parses. `appID` is `${TEAM}.app.ringdrill` with the actual team ID substituted. No literal `${TEAM}` or `<DISCOOS_TEAM_ID>` string.
9. **Local pod install (recommended sanity check, not commit-bearing).** `cd ios && pod install` from a Mac, then `cd ../macos && pod install`. Confirm neither command rewrites `Podfile.lock` in a way that would surprise the maintainer. If they do, mention in the final report — do not commit.
10. **Device QA matrix (run on a physical iOS device after the maintainer has installed the new profiles).** This is post-commit work and lives in the final report, not in the commit history:

    * `.drill` file from Files app → opens RingDrill, imports correctly.
    * Share extension from Mail/Files for a `.drill` attachment → main app opens via `ringdrill://import` and reads the file from the new `group.app.ringdrill` container.
    * Tap `https://ringdrill.app/i/<slug>` from another app → opens RingDrill (Universal Link). This requires the AASA file deployed to Netlify and the app reinstalled after the bundle-ID change so the system re-evaluates Associated Domains.
    * macOS Runner builds and signs under the DISCOOS team without prompting for an account switch.

    Mark each item pass/fail. Failures that are infrastructure rather than code (Apple Developer portal misconfig, Netlify cache, profile install) belong in a follow-up note rather than a code follow-up.
11. No follow-ups bundled. If found, record at the bottom of the final commit body under `## Follow-ups` and create a fresh prompt file under `docs/prompts/` named `adr-0021-followup-NN-<slug>.md`.

## Out of scope

* macOS `com.apple.developer.associated-domains` and macOS App Group entitlement. ADR-0021 marks both as **optional** and gated on macOS distribution being in scope. If the maintainer asks for them in the same change, fold them into Step 4 — otherwise leave `DebugProfile.entitlements` and `Release.entitlements` untouched and record a follow-up prompt.
* macOS `CFBundleDocumentTypes` and `CFBundleURLTypes` for `.drill` and `ringdrill://`. ADR-0021 explicitly defers this. When the maintainer wires it up, reuse the iOS UTI `app.ringdrill.drill` and the scheme `ringdrill` verbatim.
* Android. The Android `applicationId`, `assetlinks.json`, and SHA-256 fingerprint are not touched by this ADR.
* `web/.well-known/assetlinks.json`. Leave it as-is.
* Sentry, Shorebird, the Dart package name, every user-visible string. No change.
* Bumping `pubspec.yaml` version. Use `make release-tag` from a separate change when distributing.
* The off-repo Apple Developer portal work (App ID, App Group, share-extension App ID, profiles). The maintainer does this before Step 1.

## Deliverables

Five Conventional Commits as outlined above. Clean tree at the end. Final commit body for commit 5 (or in the PR description):

* One-line summary: "iOS and macOS now run under app.ringdrill on the DISCOOS team; AASA published for ringdrill.app Universal Links; share-extension `.dev` bug fixed."
* Device QA matrix filled out (or marked "deferred — pending profile install" with the reason).
* `## Follow-ups` section, even if empty. Include any deferred macOS entitlement work here with a pointer to the new follow-up prompt.

ADR-0021 is the authoritative spec. If you find yourself contradicting it, stop and ask.
