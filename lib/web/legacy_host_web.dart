import 'package:web/web.dart' as web;

// Debug-only override: flutter run --dart-define=RINGDRILL_FORCE_LEGACY_HOST=true
const bool _forceLegacyHost = bool.fromEnvironment('RINGDRILL_FORCE_LEGACY_HOST');

bool isLegacyHost() {
  if (_forceLegacyHost) return true;
  return checkIsLegacyHostName(web.window.location.hostname);
}

bool checkIsLegacyHostName(String hostname) => hostname == 'ringdrill.app';
