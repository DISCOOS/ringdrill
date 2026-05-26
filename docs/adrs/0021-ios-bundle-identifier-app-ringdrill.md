---
status: accepted
date: 2026-05-26
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0021: Use `app.ringdrill` as the iOS and macOS bundle identifier and keep `org.discoos.ringdrill` on Android

## Context and problem statement

RingDrill ships on Google Play under `applicationId = org.discoos.ringdrill`. The iOS and macOS targets currently mirror that identifier, but the iOS project is bound to a personal Apple Developer team (`DEVELOPMENT_TEAM = 5S49AAAL87` in [`ios/Runner.xcodeproj/project.pbxproj`](../../ios/Runner.xcodeproj/project.pbxproj)) instead of the DISCOOS Organization team that should own the App Store listing. macOS has no `DEVELOPMENT_TEAM` pinned at all, so signing follows whoever is logged in to Xcode.

Apple does not allow transferring an App ID between developer teams before publication. DISCOOS owns the domain `ringdrill.app`, which is already the canonical share host per [ADR-0015](./0015-shareable-install-links.md), but no Apple-side mechanism today claims `https://ringdrill.app/i/<slug>` Universal Links for RingDrill.

A decision is needed before the first iOS submission. macOS belongs in the same decision because it is still pre-release, and a divergent identifier now would force a second migration later.

## Decision drivers

* iOS and macOS submissions must use a bundle ID owned by the DISCOOS team.
* The Android install base on Play uses `org.discoos.ringdrill`. Renaming would orphan every device.
* `https://ringdrill.app/i/<slug>` Universal Links must work on both Apple platforms, matching the Android App Link path from [ADR-0015](./0015-shareable-install-links.md).
* iOS and macOS should share one Apple identity for Universal Purchase, a single AASA file, and a shared App Group.
* The path must not depend on cooperation from the personal-team account.
* No rename of the Sentry project, the URL scheme, or anything user-facing.

## Considered options

* **A. Transfer the App ID between teams.** Not supported by Apple before publication. Discarded.
* **B. Delete `org.discoos.ringdrill` from the personal team and re-register it under DISCOOS.** Same ID everywhere, but the personal team must first clear every dependent record. Any stuck record stalls the migration.
* **C. Use `app.ringdrill` on iOS and macOS, keep Android on `org.discoos.ringdrill`.** Apple identity converges under DISCOOS, Android stays untouched, and the bundle root matches the domain DISCOOS already owns.

## Decision outcome

Chosen: **C — `app.ringdrill` on iOS and macOS, `org.discoos.ringdrill` on Android**. C is the only option that does not depend on releasing the existing App ID from the personal team. `app.ringdrill` is the reverse-DNS of a domain DISCOOS already serves, which is exactly what Associated Domains expects. Aligning iOS and macOS now is cheaper than reconciling them after a second migration.

Flutter configures the three platforms independently, so the Apple/Android divergence costs nothing at build time. The URL scheme `ringdrill://`, the Sentry project (`discoos/ringdrill`), the Shorebird app ID, the Dart package name and every user-visible string remain unchanged.

### Identifier table

| Asset                       | iOS (new)                                | macOS (new)                              | Android (unchanged)        |
|-----------------------------|------------------------------------------|------------------------------------------|----------------------------|
| App bundle / applicationId  | `app.ringdrill`                          | `app.ringdrill`                          | `org.discoos.ringdrill`    |
| Test target                 | `app.ringdrill.RunnerTests`              | `app.ringdrill.RunnerTests`              | n/a                        |
| Share extension             | `app.ringdrill.RingDrillShareExtension`  | n/a                                      | n/a                        |
| App Group                   | `group.app.ringdrill`                    | `group.app.ringdrill` (when needed)      | n/a                        |
| URL scheme                  | `ringdrill://`                           | `ringdrill://` (when needed)             | `ringdrill://`             |
| Universal/App Link host     | `ringdrill.app`                          | `ringdrill.app`                          | `ringdrill.app`            |
| UTI for `.drill`            | `app.ringdrill.drill`                    | `app.ringdrill.drill` (when needed)      | MIME-based                 |
| Sentry release prefix       | `app.ringdrill@<version>+<build>`        | `app.ringdrill@<version>+<build>`        | `org.discoos.ringdrill@…`  |

iOS and macOS deliberately share one bundle ID. With both platform checkboxes enabled on the App ID, this supports Universal Purchase and lets a single `apple-app-site-association` file cover both targets.

The UTI is renamed because the current value `org.discoos.ringdrill` is identical to a bundle ID on another team, which is exactly the conflict Apple's UTI documentation warns against. `app.ringdrill.drill` follows the recommended `<owned reverse-DNS>.<type>` pattern and is reused verbatim on macOS when a document handler is added there.

The macOS App Group, URL scheme and document-handler entries are gated. The bundle-ID decision does not require them. Add them when macOS distribution or Universal Links is in scope.

### Concrete Apple-side migration

**iOS:**

* [`ios/Runner.xcodeproj/project.pbxproj`](../../ios/Runner.xcodeproj/project.pbxproj): set `PRODUCT_BUNDLE_IDENTIFIER` for Runner, RunnerTests and RingDrillShareExtension to the table values across Debug, Release and Profile. Replace `DEVELOPMENT_TEAM = 5S49AAAL87` with the DISCOOS team ID in the same six configurations.
* [`ios/Runner/Runner.entitlements`](../../ios/Runner/Runner.entitlements): set App Group to `group.app.ringdrill`. Add `Associated Domains` with `applinks:ringdrill.app`.
* [`ios/RingDrillShareExtension/RingDrillShareExtension.entitlements`](../../ios/RingDrillShareExtension/RingDrillShareExtension.entitlements): set App Group to `group.app.ringdrill`.
* [`ios/Runner/AppDelegate.swift`](../../ios/Runner/AppDelegate.swift) line 38: replace `"group.org.discoos.ringdrill"` with `"group.app.ringdrill"`.
* [`ios/RingDrillShareExtension/ShareViewController.swift`](../../ios/RingDrillShareExtension/ShareViewController.swift) line 40: replace `"group.org.discoos.ringdrill.dev"` with `"group.app.ringdrill"`. The `.dev` suffix is an existing bug — the share extension writes to a container the main app does not read from. The fix rides with the App Group rename.
* [`ios/Runner/Info.plist`](../../ios/Runner/Info.plist): rename the UTI `org.discoos.ringdrill` to `app.ringdrill.drill` in `LSItemContentTypes` and `UTExportedTypeDeclarations`. Set `CFBundleURLName` to `app.ringdrill`. The URL scheme string `ringdrill` is unchanged.
* New file `web/.well-known/apple-app-site-association`, served by Netlify as `Content-Type: application/json` with no extension. The `applinks` block lists App ID `<TEAM>.app.ringdrill` and path `/i/*`. One file covers both iOS and macOS.

**macOS:**

* [`macos/Runner/Configs/AppInfo.xcconfig`](../../macos/Runner/Configs/AppInfo.xcconfig): set `PRODUCT_BUNDLE_IDENTIFIER = app.ringdrill`. Update `PRODUCT_COPYRIGHT` to use the organization name rather than the legacy bundle prefix.
* [`macos/Runner.xcodeproj/project.pbxproj`](../../macos/Runner.xcodeproj/project.pbxproj): rename the RunnerTests bundle ID to `app.ringdrill.RunnerTests` in Debug, Release and Profile. Add `DEVELOPMENT_TEAM = <DISCOOS team ID>` to both Runner and RunnerTests so signing is no longer floating.
* Optional, when Universal Links should reach macOS: add `com.apple.developer.associated-domains` with `applinks:ringdrill.app` to both [`macos/Runner/DebugProfile.entitlements`](../../macos/Runner/DebugProfile.entitlements) and [`macos/Runner/Release.entitlements`](../../macos/Runner/Release.entitlements).
* Optional, when iOS and macOS should share storage: add `com.apple.security.application-groups` with `group.app.ringdrill` to both entitlement files.
* Out of scope but worth noting: macOS `Info.plist` has no `CFBundleDocumentTypes` or `CFBundleURLTypes` today. When `.drill` association and `ringdrill://` deep linking are wired up on macOS, reuse the iOS UTI and scheme strings.

### Consequences

* Good: iOS and macOS ship under the DISCOOS team without depending on the personal team releasing the old App ID.
* Good: the bundle root matches the owned domain, so Associated Domains verification is straightforward. One AASA file covers both Apple platforms.
* Good: Universal Purchase becomes possible. A single customer purchase grants both targets, and a future shared App Group spans iOS and macOS.
* Good: the `.dev`-suffix bug in `ShareViewController.swift` is corrected as a side effect.
* Bad: Apple and Android identifiers diverge. Future scripts that group by identifier must handle both forms. No current code makes this assumption.
* Bad: macOS now requires `DEVELOPMENT_TEAM` to be the DISCOOS team. Local dev builds on a machine not signed in to DISCOOS fail until the signing account is switched. One-time onboarding cost.

## Pros and cons of the options

### Option B — delete and re-register under DISCOOS
* Good: one bundle ID across all three platforms. Lowest cognitive load.
* Bad: the personal team must first clear every dependent record (App ID, App Group, provisioning profiles, App Store Connect entry). Any stuck record stalls the migration indefinitely.
* Bad: even after deletion succeeds, the re-registered App ID is functionally new. Certificates, profiles, App Groups and entitlements must be re-created. Same on-device work as Option C.
* Bad: the bundle ID still does not match the owned domain.

### Option C — `app.ringdrill` on Apple, `org.discoos.ringdrill` on Android (chosen)
* Good: independent of the personal team.
* Good: the bundle root matches the owned domain, exactly what Associated Domains expects.
* Good: the Android install base keeps its identifier.
* Good: iOS and macOS share Universal Purchase, AASA, and App Group eligibility.
* Bad: Apple/Android identifiers diverge (see Consequences).

## Migration plan

1. Register the App ID `app.ringdrill` under the DISCOOS team with both iOS and macOS platform boxes checked. Add the App Groups and Associated Domains capabilities. Register the App Group `group.app.ringdrill` and the iOS share-extension App ID `app.ringdrill.RingDrillShareExtension`. Generate Development and Distribution profiles for iOS Runner, iOS RingDrillShareExtension, and macOS Runner.
2. Apply the file changes in "Concrete Apple-side migration" as one commit. Run `flutter clean && flutter pub get`, then `pod install` in `ios/` and `macos/`.
3. On a physical iOS device, verify that the share extension hands `.drill` files to the main app (exercises the `.dev` fix) and that `ringdrill://import` round-trips. Verify a macOS build runs and signs under the DISCOOS team.
4. Deploy `web/.well-known/apple-app-site-association` via Netlify. Confirm it is served as JSON with no extension at `https://ringdrill.app/.well-known/apple-app-site-association`.
5. Test Universal Links from Android or a browser, tapped on an iOS device with the build installed. The link should open via the `/i/:slug` route from ADR-0015. Repeat on macOS if the Associated Domains entitlement was enabled.
6. Tag the first iOS and macOS releases in Sentry as `app.ringdrill@<version>+<build>` and confirm dSYM upload still works.

## Links

* Related ADRs: [ADR-0015](./0015-shareable-install-links.md) (install links and the `ringdrill.app` host)
* Related code: `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `ios/Runner/AppDelegate.swift`, `ios/RingDrillShareExtension/RingDrillShareExtension.entitlements`, `ios/RingDrillShareExtension/ShareViewController.swift`, `macos/Runner/Configs/AppInfo.xcconfig`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `web/.well-known/assetlinks.json` (Android counterpart)
* External references: [Apple — Supporting Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains), [Apple — Configuring an App Group for an App Extension](https://developer.apple.com/documentation/xcode/configuring-app-groups), [Apple — Defining file and data types for your app](https://developer.apple.com/documentation/uniformtypeidentifiers/defining_file_and_data_types_for_your_app), [Apple — Universal Purchase](https://developer.apple.com/documentation/xcode/distributing-your-app-as-a-universal-purchase)
