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

  /// Optional local backend override — see [AppFlags.localBaseUrl].
  static String get localBaseUrl => AppFlags.localBaseUrl;

  /// Returns the base URL the Flutter client should use when talking to the
  /// catalog/backend.
  ///
  /// Resolution order:
  ///   1. If [isDebug] and [localBaseUrl] is non-empty, use [localBaseUrl].
  ///   2. If running as a release web build on `web.ringdrill.app`, use
  ///      [apiBaseUrl] (cross-origin to the dedicated API subdomain).
  ///   3. If running as a release web build on apex (`ringdrill.app`), use
  ///      the empty string (same-origin – the cached PWA's calls to
  ///      `/.netlify/functions/*` keep working on apex).
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
      if (host == 'web.ringdrill.app') return apiBaseUrl;
      // Apex stays same-origin. The cached PWA's calls to
      // /.netlify/functions/* keep working on apex (served directly
      // by Netlify today, proxied via Cloudflare in Phase 3).
      return '';
    }
    return ringDrillBaseUrl;
  }

  /// Returns the deep-link base path the [DrillClient] should use for the
  /// given [baseUrl]. In production the path is `/d` (the public deep-link
  /// alias, served via the redirect in `netlify.toml`). When the backend
  /// is a local `netlify functions:serve` instance the redirect is not
  /// applied, so the client must call the function directly. See ADR-0013.
  static String deepLinkBasePathFor(String baseUrl) {
    if (_looksLocal(baseUrl)) return '/.netlify/functions/deep-link';
    return '/d';
  }

  static bool _looksLocal(String baseUrl) {
    final lower = baseUrl.toLowerCase();
    return lower.contains('localhost') || lower.contains('127.0.0.1');
  }

  static String catalogOwnershipKey(String slug) =>
      'app:catalogOwnership:$slug';
}
