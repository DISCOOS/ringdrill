import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/app_config.dart';

void main() {
  group('AppConfig.catalogBaseUrl', () {
    test('release web build on apex returns empty string (same-origin)', () {
      expect(
        AppConfig.catalogBaseUrl(
          isWeb: true,
          isRelease: true,
          isDebug: false,
          webHost: 'ringdrill.app',
        ),
        equals(''),
      );
    });

    test('release web build on web.ringdrill.app returns api URL', () {
      expect(
        AppConfig.catalogBaseUrl(
          isWeb: true,
          isRelease: true,
          isDebug: false,
          webHost: 'web.ringdrill.app',
        ),
        equals(AppConfig.apiBaseUrl),
      );
    });

    test('debug build with local URL override returns the local URL', () {
      // Exercisable when built with
      // --dart-define=RINGDRILL_LOCAL_BASE_URL=http://localhost:8888.
      // In unit tests localBaseUrl is always empty, so the debug path falls
      // through; the expectation adapts accordingly.
      final result = AppConfig.catalogBaseUrl(
        isWeb: true,
        isRelease: false,
        isDebug: true,
        webHost: 'localhost:8080',
      );
      if (AppConfig.localBaseUrl.isNotEmpty) {
        expect(result, equals(AppConfig.localBaseUrl));
      } else {
        expect(result, equals(AppConfig.ringDrillBaseUrl));
      }
    });

    test('native release build returns ringDrillBaseUrl', () {
      expect(
        AppConfig.catalogBaseUrl(
          isWeb: false,
          isRelease: true,
          isDebug: false,
        ),
        equals(AppConfig.ringDrillBaseUrl),
      );
    });
  });
}
