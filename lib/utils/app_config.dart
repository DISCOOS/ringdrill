import 'package:flutter/foundation.dart';
import 'package:ringdrill/utils/app_flags.dart';

class AppConfig {
  static const String keyIsFirstLaunch = 'app:isFirstLaunch:v1';
  static const String keyOnboardingSeen = 'app:onboardingSeen:v1';
  static const String keyStartHereSeen = 'app:startHereSeen:v1';
  static const String keyActiveProgram = 'app:activeProgram:v1';
  static const String keyLibrarySchema = 'app:librarySchema:v1';
  static const String keyLibrarySchemaJustMigrated =
      'app:librarySchemaJustMigrated';
  static const String keyAnalyticsConsent = 'app:analyticsConsent';
  static const String keyIsNotificationsEnabled = 'app:isNotificationsEnabled';
  /// Set to `true` after the user has answered the in-app
  /// notification-rationale pre-prompt (see ADR-0038). While `false`,
  /// boot-time service init must call into the plugin with
  /// `requestPermissions: false` so we do not fire the iOS system
  /// dialog before the user has read RingDrill's own copy.
  static const String keyNotificationConsentAsked =
      'app:notificationConsentAsked:v1';
  static const String keyIsNotificationFullScreenIntentEnabled =
      'app:isNotificationFullScreenIntentEnabled';
  static const String keyNotificationPlaySound = 'app:isNotificationPlaySound';
  static const String keyIsNotificationVibrateEnabled =
      'app:isNotificationVibrateEnabled';
  static const String keyUrgentNotificationThreshold =
      'app:isUrgentNotificationThreshold';
  static const String keyAppUserRole = 'app:appUserRole:v1';
  static const String keyShowMapZoomControls = 'app:showMapZoomControls:v1';
  static const String keyMigrationBannerDismissedAt =
      'app:migrationBannerDismissedAt:v1';
  static const String ringDrillBaseUrl = 'https://ringdrill.app';
  static const String briefViewerBaseUrl = 'https://ringdrill.app';
  static const String apiBaseUrl = 'https://api.ringdrill.app';

  /// Native app store listings. Fixed for the app's lifetime, so plain
  /// constants — no build-time override layer (the App Store id and Play
  /// package never change per build).
  ///
  /// NB: The App Store id (`6777269410`) is also hardcoded in `web/index.html`
  /// as the Smart App Banner meta tag (`apple-itunes-app`). If the id ever
  /// changes, update both places.
  static const String appStoreUrl =
      'https://apps.apple.com/no/app/ringdrill-app/id6777269410';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=org.discoos.ringdrill';

  /// Optional local backend override — see [AppFlags.localBaseUrl].
  static String get localBaseUrl => AppFlags.localBaseUrl;

  /// Returns the base URL the Flutter client should use when talking to the
  /// catalog/backend.
  ///
  /// Resolution order:
  ///   1. If [isDebug] and [localBaseUrl] is non-empty, use [localBaseUrl].
  ///   2. If running as a release web build on apex (`ringdrill.app`), use
  ///      the empty string (same-origin – the cached PWA's calls to
  ///      `/.netlify/functions/*` keep working there because Netlify hosts
  ///      both the PWA and the functions on apex until Phase 3).
  ///   3. If running as a release web build on any other host
  ///      (`web.ringdrill.app`, `ringdrill-pwa.pages.dev`, deploy previews,
  ///      etc.), use [apiBaseUrl] (cross-origin to the dedicated API
  ///      subdomain). Same-origin would fail because Cloudflare Pages does
  ///      not serve Netlify functions.
  ///   4. Otherwise use [ringDrillBaseUrl] (production native / debug).
  ///
  /// Pass [kIsWeb], [kReleaseMode] and [kDebugMode] from
  /// `package:flutter/foundation.dart` at the call site.
  /// [webHost] defaults to `Uri.base.host` when omitted; override in tests.
  static String catalogBaseUrl({
    required bool isWeb,
    required bool isRelease,
    required bool isDebug,
    String? webHost,
  }) {
    if (isDebug && localBaseUrl.isNotEmpty) return localBaseUrl;
    if (isWeb && isRelease) {
      final host = webHost ?? Uri.base.host;
      // Apex is the only origin where same-origin still works: Netlify
      // hosts both the PWA and the functions there until Phase 3.
      if (host == 'ringdrill.app') return '';
      // Every other host is on Cloudflare Pages (or a preview) and must
      // call the API subdomain explicitly.
      return apiBaseUrl;
    }
    return ringDrillBaseUrl;
  }

  /// Returns the deep-link base path the [DrillClient] should use for the
  /// given [baseUrl]. In production the path is `/d` (the public deep-link
  /// alias, served via the redirect in `netlify.toml`). When the backend
  /// is a local `netlify functions:serve` instance the redirect is not
  /// applied, so the client must call the function directly. See ADR-0013.
  ///
  /// The local branch is gated on [kDebugMode] so release builds
  /// constant-fold the check away and Dart tree-shakes [_looksLocal].
  static String deepLinkBasePathFor(String baseUrl) {
    if (kDebugMode && _looksLocal(baseUrl)) {
      return '/.netlify/functions/deep-link';
    }
    return '/d';
  }

  /// Returns the functions base path the [DrillClient] should use for the
  /// given [baseUrl]. In production the path is `/api` (public alias,
  /// served via the redirects in `netlify.toml`). When the backend is a
  /// local `netlify functions:serve` instance those redirects are not
  /// applied, so the client must call the implementation path directly.
  /// See ADR-0013 and the comment in `make netlify-dev`.
  ///
  /// The local branch is gated on [kDebugMode] so release builds
  /// constant-fold the check away and Dart tree-shakes [_looksLocal].
  static String functionsBasePathFor(String baseUrl) {
    if (kDebugMode && _looksLocal(baseUrl)) return '/.netlify/functions';
    return '/api';
  }

  static bool _looksLocal(String baseUrl) {
    final lower = baseUrl.toLowerCase();
    return lower.contains('localhost') || lower.contains('127.0.0.1');
  }

  static String catalogOwnershipKey(String slug) =>
      'app:catalogOwnership:$slug';
}
