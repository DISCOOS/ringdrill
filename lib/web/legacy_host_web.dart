import 'package:web/web.dart' as web;

// Production kill-switch. When set at build time the migration banner,
// drawer entry and explainer are completely hidden, regardless of host or
// the dev override below. Used to land Phase 1 of ADR-0039 on apex before
// `web.ringdrill.app` (Phase 2) is up, so users do not see a banner that
// points at a domain that does not resolve yet.
//
//   flutter build web --dart-define=MIGRATION_DISABLED=true
const bool _migrationDisabled = bool.fromEnvironment('MIGRATION_DISABLED');

// Debug-only override: flutter run --dart-define=RINGDRILL_FORCE_LEGACY_HOST=true
const bool _forceLegacyHost = bool.fromEnvironment('RINGDRILL_FORCE_LEGACY_HOST');

bool isLegacyHost() {
  if (_migrationDisabled) return false;
  if (_forceLegacyHost) return true;
  return checkIsLegacyHostName(web.window.location.hostname);
}

bool checkIsLegacyHostName(String hostname) => hostname == 'ringdrill.app';
