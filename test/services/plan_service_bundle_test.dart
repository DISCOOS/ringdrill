import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_library.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Plan _plan(String uuid, String name) {
  final now = DateTime(2026, 1, 1);
  return Plan(
    uuid: uuid,
    name: name,
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

/// Rebuilds [bundle] with an extra corrupt `.drill` entry appended, so a
/// caller can assert on best-effort per-entry install (ADR-0045).
List<int> _withCorruptEntry(List<int> bundle) {
  final outer = ZipDecoder().decodeBytes(bundle);
  final rebuilt = Archive();
  for (final file in outer.files) {
    if (file.isFile) {
      rebuilt.addFile(
        ArchiveFile(file.name, file.size, file.content as List<int>),
      );
    }
  }
  final garbage = utf8.encode('not a zip at all');
  rebuilt.addFile(ArchiveFile('corrupt.drill', garbage.length, garbage));
  return ZipEncoder().encode(rebuilt);
}

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await PlanService().init();
  });

  tearDown(() async {
    await PlanService().clearAllForTest();
  });

  group('PlanService.installBundle', () {
    test('a clean bundle of 2 imports 2 and activates nothing', () async {
      final existing = await PlanService().createPlan(name: 'Existing');
      await PlanService().setActive(existing.uuid);

      final bundle = DrillLibrary.fromPlans([
        _plan('bundle-a', 'Bundle plan A'),
        _plan('bundle-b', 'Bundle plan B'),
      ]);

      final result = await PlanService().installBundle(bundle);

      expect(result.imported, 2);
      expect(result.skipped, isEmpty);
      expect(result.hasFailures, isFalse);
      // Bundle import never activates anything (ADR-0045) — the
      // pre-existing active plan is left exactly as it was.
      expect(PlanService().activePlanUuid, existing.uuid);
      expect(
        PlanService().listPlans().map((p) => p.uuid),
        containsAll(['bundle-a', 'bundle-b']),
      );
    });

    test(
      'a bundle with one corrupt inner entry imports the good ones',
      () async {
        final bundle = _withCorruptEntry(
          DrillLibrary.fromPlans([
            _plan('good-a', 'Good plan A'),
            _plan('good-b', 'Good plan B'),
          ]),
        );

        final result = await PlanService().installBundle(bundle);

        expect(result.imported, 2);
        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.fileName, 'corrupt.drill');
        expect(result.skipped.single.reason, DrillFormatReason.notArchive);
        expect(result.hasFailures, isTrue);
        expect(
          PlanService().listPlans().map((p) => p.uuid),
          containsAll(['good-a', 'good-b']),
        );
      },
    );

    test('an empty bundle throws DrillLibraryException', () async {
      expect(
        () => PlanService().installBundle(const <int>[]),
        throwsA(isA<DrillLibraryException>()),
      );
    });
  });
}
