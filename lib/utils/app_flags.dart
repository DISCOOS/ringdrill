import 'package:flutter/foundation.dart';

class AppFlags {
  static const migrationDisabled =
      bool.fromEnvironment('MIGRATION_DISABLED');
  static const forceLegacyHost =
      bool.fromEnvironment('RINGDRILL_FORCE_LEGACY_HOST');
  static const localBaseUrl =
      String.fromEnvironment('RINGDRILL_LOCAL_BASE_URL');

  static Map<String, Object> get all => {
    'MIGRATION_DISABLED': migrationDisabled,
    'RINGDRILL_FORCE_LEGACY_HOST': forceLegacyHost,
    'RINGDRILL_LOCAL_BASE_URL': localBaseUrl,
  };

  /// Returns the subset of [all] where the value is non-default. Useful
  /// for rendering an "active flags" UI without listing flags that are
  /// silently at their defaults.
  static Map<String, Object> get activeOnly => activeOnlyFrom(all);

  /// Applies the same default-filtering logic as [activeOnly] to an
  /// arbitrary map. Exposed for testing so the logic can be verified
  /// without requiring --dart-define overrides in the test runner.
  @visibleForTesting
  static Map<String, Object> activeOnlyFrom(Map<String, Object> map) => {
    for (final e in map.entries)
      if (!_isDefault(e.value)) e.key: e.value,
  };

  static bool _isDefault(Object v) =>
      v == false || v == '' || v == 0;
}
