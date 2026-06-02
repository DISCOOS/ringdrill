class AppConfig {
  static const String keyIsFirstLaunch = 'app:isFirstLaunch:v1';
  static const String keyActiveProgram = 'app:activeProgram:v1';
  static const String keyLibrarySchema = 'app:librarySchema:v1';
  static const String keyLibrarySchemaJustMigrated =
      'app:librarySchemaJustMigrated';
  static const String keyAnalyticsConsent = 'app:analyticsConsent';
  static const String keyIsNotificationsEnabled = 'app:isNotificationsEnabled';
  static const String keyIsNotificationFullScreenIntentEnabled =
      'app:isNotificationFullScreenIntentEnabled';
  static const String keyNotificationPlaySound = 'app:isNotificationPlaySound';
  static const String keyIsNotificationVibrateEnabled =
      'app:isNotificationVibrateEnabled';
  static const String keyUrgentNotificationThreshold =
      'app:isUrgentNotificationThreshold';
  static const String keyAppUserRole = 'app:appUserRole:v1';
  static const String ringDrillBaseUrl = 'https://ringdrill.netlify.app';
  static const String briefViewerBaseUrl = 'https://ringdrill.app';

  /// Optional local backend override, set at build time via
  ///
  ///   flutter run --dart-define=RINGDRILL_LOCAL_BASE_URL=http://localhost:8888
  ///
  /// Only takes effect in debug builds (see [catalogBaseUrl]). Release builds
  /// cannot be coerced into talking to a localhost backend at runtime.
  /// See ADR-0013 for the rationale.
  static const String localBaseUrl = String.fromEnvironment(
    'RINGDRILL_LOCAL_BASE_URL',
    defaultValue: '',
  );

  /// Returns the base URL the Flutter client should use when talking to the
  /// catalog/backend.
  ///
  /// Resolution order:
  ///   1. If [isDebug] and [localBaseUrl] is non-empty, use [localBaseUrl].
  ///   2. If running as a release web build, use the empty string (same-origin
  ///      requests, so the PWA talks to whatever host served it).
  ///   3. Otherwise use [ringDrillBaseUrl] (production).
  ///
  /// Pass [kIsWeb], [kReleaseMode] and [kDebugMode] from
  /// `package:flutter/foundation.dart` at the call site.
  static String catalogBaseUrl({
    required bool isWeb,
    required bool isRelease,
    required bool isDebug,
  }) {
    if (isDebug && localBaseUrl.isNotEmpty) return localBaseUrl;
    return isWeb && isRelease ? '' : ringDrillBaseUrl;
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
