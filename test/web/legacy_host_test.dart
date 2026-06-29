import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/web/legacy_host_stub.dart';

// Tests run on the Dart VM (non-web), so they always import the stub.
// The stub's isLegacyHost() is unconditionally false; only checkIsLegacyHostName
// exercises the hostname-matching logic shared by both stub and web builds.
//
// The compile-time dart-defines in legacy_host_web.dart are verified manually:
//   flutter run -d chrome --dart-define=RINGDRILL_FORCE_LEGACY_HOST=true
//     # Forces isLegacyHost() to return true even on localhost.
//   flutter build web --dart-define=MIGRATION_DISABLED=true
//     # Kill switch: forces isLegacyHost() to return false regardless of host
//     # and the force-legacy override. Used in deploy-web.yml during ADR-0039
//     # Phase 1 rollout before web.ringdrill.app is live.
void main() {
  group('isLegacyHost (stub — non-web platforms)', () {
    test('always returns false on non-web', () {
      expect(isLegacyHost(), isFalse);
    });
  });

  group('checkIsLegacyHostName', () {
    test('ringdrill.app → true', () {
      expect(checkIsLegacyHostName('ringdrill.app'), isTrue);
    });

    test('web.ringdrill.app → false', () {
      expect(checkIsLegacyHostName('web.ringdrill.app'), isFalse);
    });

    test('localhost → false', () {
      expect(checkIsLegacyHostName('localhost'), isFalse);
    });

    test('deploy preview host → false', () {
      expect(
        checkIsLegacyHostName('abc--ringdrill.netlify.app'),
        isFalse,
      );
    });

    test('empty string → false', () {
      expect(checkIsLegacyHostName(''), isFalse);
    });
  });
}
