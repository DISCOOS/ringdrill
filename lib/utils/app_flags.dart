enum AppFlagKind { permanent, temporary }

class AppFlagInfo {
  const AppFlagInfo({
    required this.name,
    required this.value,
    required this.kind,
    required this.description,
  });

  final String name;
  final Object value;
  final AppFlagKind kind;
  final String description;

  bool get isDefault =>
      (value is bool && value == false) ||
      (value is String && (value as String).isEmpty) ||
      (value is num && value == 0);
}

class AppFlags {
  static const migrationDisabled =
      bool.fromEnvironment('MIGRATION_DISABLED');
  static const forceLegacyHost =
      bool.fromEnvironment('RINGDRILL_FORCE_LEGACY_HOST');
  static const localBaseUrl =
      String.fromEnvironment('RINGDRILL_LOCAL_BASE_URL');

  static const List<AppFlagInfo> all = [
    AppFlagInfo(
      name: 'MIGRATION_DISABLED',
      value: migrationDisabled,
      kind: AppFlagKind.temporary,
      description:
          'Kill switch hiding the in-app migration UI before web.ringdrill.app is live.',
    ),
    AppFlagInfo(
      name: 'RINGDRILL_FORCE_LEGACY_HOST',
      value: forceLegacyHost,
      kind: AppFlagKind.temporary,
      description:
          'Dev override that makes isLegacyHost() return true regardless of actual host.',
    ),
    AppFlagInfo(
      name: 'RINGDRILL_LOCAL_BASE_URL',
      value: localBaseUrl,
      kind: AppFlagKind.permanent,
      description:
          'Points the catalog client at a local netlify dev instance.',
    ),
  ];

  static Iterable<AppFlagInfo> get activeOnly =>
      all.where((f) => !f.isDefault);
}
