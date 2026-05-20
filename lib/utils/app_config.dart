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
  static const String ringDrillBaseUrl = 'https://ringdrill.netlify.app';

  static String catalogOwnershipKey(String slug) =>
      'app:catalogOwnership:$slug';
}
