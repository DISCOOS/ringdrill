import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/web/legacy_host_stub.dart';

// Tests run on the Dart VM (non-web), so they always import the stub.
// The stub's isLegacyHost() is unconditionally false; only checkIsLegacyHostName
// exercises the hostname-matching logic shared by both stub and web builds.
//
// The --dart-define=RINGDRILL_FORCE_LEGACY_HOST=true override is a compile-time
// constant in legacy_host_web.dart and is verified manually by running:
//   flutter run -d chrome --dart-define=RINGDRILL_FORCE_LEGACY_HOST=true
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
