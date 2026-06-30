import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/app_flags.dart';

void main() {
  group('AppFlags', () {
    test('all contains the three expected keys', () {
      expect(AppFlags.all.keys, containsAll([
        'MIGRATION_DISABLED',
        'RINGDRILL_FORCE_LEGACY_HOST',
        'RINGDRILL_LOCAL_BASE_URL',
      ]));
      expect(AppFlags.all.length, 3);
    });

    test('MIGRATION_DISABLED defaults to false', () {
      expect(AppFlags.all['MIGRATION_DISABLED'], false);
    });

    test('activeOnly is empty when no dart-defines are set', () {
      // The test runner has no --dart-define overrides, so all flags are
      // at their defaults and should be absent from activeOnly.
      expect(AppFlags.activeOnly, isEmpty);
    });

    group('activeOnlyFrom helper logic', () {
      test('excludes bool false, empty string, and zero', () {
        final result = AppFlags.activeOnlyFrom({
          'A': false,
          'B': '',
          'C': 0,
        });
        expect(result, isEmpty);
      });

      test('includes bool true, non-empty string, and non-zero int', () {
        final result = AppFlags.activeOnlyFrom({
          'A': true,
          'B': 'custom',
          'C': 1,
        });
        expect(result, {'A': true, 'B': 'custom', 'C': 1});
      });

      test('filters a mixed map correctly', () {
        final result = AppFlags.activeOnlyFrom({
          'MIGRATION_DISABLED': false,
          'RINGDRILL_FORCE_LEGACY_HOST': true,
          'RINGDRILL_LOCAL_BASE_URL': '',
        });
        expect(result, {'RINGDRILL_FORCE_LEGACY_HOST': true});
      });
    });
  });
}
