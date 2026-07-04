import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/app_flags.dart';

void main() {
  group('AppFlags', () {
    test('all has exactly three entries with expected names', () {
      expect(AppFlags.all.length, 3);
      expect(
        AppFlags.all.map((f) => f.name),
        containsAll([
          'MIGRATION_DISABLED',
          'RINGDRILL_FORCE_LEGACY_HOST',
          'RINGDRILL_LOCAL_BASE_URL',
        ]),
      );
    });

    test('each entry has a non-empty description and a kind', () {
      for (final f in AppFlags.all) {
        expect(f.description, isNotEmpty, reason: '${f.name} has empty description');
        expect(f.kind, isA<AppFlagKind>(), reason: '${f.name} missing kind');
      }
    });

    test('MIGRATION_DISABLED defaults to false', () {
      final flag = AppFlags.all.firstWhere((f) => f.name == 'MIGRATION_DISABLED');
      expect(flag.value, false);
    });

    test('activeOnly is empty when no dart-defines are set', () {
      // The test runner has no --dart-define overrides, so all flags are
      // at their defaults and should be absent from activeOnly.
      expect(AppFlags.activeOnly, isEmpty);
    });

    group('AppFlagInfo.isDefault', () {
      test('bool false is default', () {
        const f = AppFlagInfo(
          name: 'X',
          value: false,
          kind: AppFlagKind.temporary,
          description: 'd',
        );
        expect(f.isDefault, isTrue);
      });

      test('bool true is not default', () {
        const f = AppFlagInfo(
          name: 'X',
          value: true,
          kind: AppFlagKind.temporary,
          description: 'd',
        );
        expect(f.isDefault, isFalse);
      });

      test('empty string is default', () {
        const f = AppFlagInfo(
          name: 'X',
          value: '',
          kind: AppFlagKind.permanent,
          description: 'd',
        );
        expect(f.isDefault, isTrue);
      });

      test('non-empty string is not default', () {
        const f = AppFlagInfo(
          name: 'X',
          value: 'http://localhost:8888',
          kind: AppFlagKind.permanent,
          description: 'd',
        );
        expect(f.isDefault, isFalse);
      });

      test('zero is default', () {
        const f = AppFlagInfo(
          name: 'X',
          value: 0,
          kind: AppFlagKind.temporary,
          description: 'd',
        );
        expect(f.isDefault, isTrue);
      });
    });
  });
}
