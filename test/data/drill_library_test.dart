import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_library.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';

Plan _plan(String uuid, String name, {int exerciseCount = 0}) {
  final now = DateTime(2026, 1, 1);
  return Plan(
    uuid: uuid,
    name: name,
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: [
      for (var i = 0; i < exerciseCount; i++)
        Exercise(
          uuid: 'ex-$uuid-$i',
          index: i,
          name: 'Exercise $i',
          startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 15,
          evaluationTime: 5,
          rotationTime: 2,
          stations: [Station(index: 0, name: 'Station 1')],
          schedule: [
            [
              SimpleTimeOfDay(hour: 9, minute: 0),
              SimpleTimeOfDay(hour: 9, minute: 15),
              SimpleTimeOfDay(hour: 9, minute: 20),
            ],
          ],
          endTime: const SimpleTimeOfDay(hour: 9, minute: 22),
        ),
    ],
    rolePlays: const [],
    staff: const [],
  );
}

ArchiveFile _entry(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

List<int> _emptyZip() => ZipEncoder().encode(Archive());

void main() {
  group('DrillLibrary.sniff', () {
    test('single .drill -> DrillArchiveKind.single', () {
      final content = DrillFile.fromPlan(_plan('u1', 'Solo plan'), 'x').content;
      expect(DrillLibrary.sniff(content), DrillArchiveKind.single);
    });

    test('drill-library bundle -> DrillArchiveKind.library', () {
      final content = DrillLibrary.fromPlans([
        _plan('u1', 'Alfa'),
        _plan('u2', 'Beta'),
      ]);
      expect(DrillLibrary.sniff(content), DrillArchiveKind.library);
    });

    test('ASCII garbage -> DrillArchiveKind.invalid', () {
      final content = utf8.encode('this is definitely not a zip');
      expect(DrillLibrary.sniff(content), DrillArchiveKind.invalid);
    });

    test('ZIP with neither program.json nor .drill entries -> invalid', () {
      final archive = Archive()..addFile(_entry('readme.txt', 'hello'));
      final content = ZipEncoder().encode(archive);
      expect(DrillLibrary.sniff(content), DrillArchiveKind.invalid);
    });

    test('empty ZIP -> DrillArchiveKind.invalid', () {
      final content = _emptyZip();
      expect(DrillLibrary.sniff(content), DrillArchiveKind.invalid);
    });

    test(
      'Finder-repacked bundle (nested folder + __MACOSX/.DS_Store) -> library',
      () {
        // Mirrors what Finder produces when someone extracts a downloaded
        // bundle, edits a file, then re-compresses the folder: every real
        // entry sits one level deeper, plus junk cruft is added.
        final drillFile = DrillFile.fromPlan(_plan('u1', 'Alfa'), 'alfa');
        final archive = Archive()
          ..addFile(_entry('bundle/', ''))
          ..addFile(_entry('__MACOSX/._bundle', 'junk'))
          ..addFile(_entry('bundle/.DS_Store', 'junk'))
          ..addFile(
            ArchiveFile(
              'bundle/alfa.drill',
              drillFile.content.length,
              drillFile.content,
            ),
          )
          ..addFile(_entry('__MACOSX/bundle/._alfa.drill', 'junk'));
        final content = ZipEncoder().encode(archive);
        expect(DrillLibrary.sniff(content), DrillArchiveKind.library);
      },
    );
  });

  group('DrillLibrary.entries — round-trip', () {
    test('fromPlans([a, b]) -> entries() reproduces a and b', () {
      final a = _plan('uuid-a', 'Alfa plan', exerciseCount: 2);
      final b = _plan('uuid-b', 'Beta plan', exerciseCount: 1);

      final bundle = DrillLibrary.fromPlans([a, b]);
      final files = DrillLibrary.entries(bundle);
      expect(files.length, 2);

      final plans = files.map((f) => f.plan()).toList();
      final byUuid = {for (final p in plans) p.uuid: p};

      expect(byUuid['uuid-a']!.name, 'Alfa plan');
      expect(byUuid['uuid-a']!.exercises.length, 2);
      expect(byUuid['uuid-b']!.name, 'Beta plan');
      expect(byUuid['uuid-b']!.exercises.length, 1);
    });

    test('ZIP with unrelated entries -> entries() throws noDrillEntries', () {
      final archive = Archive()..addFile(_entry('readme.txt', 'hello'));
      final bundle = ZipEncoder().encode(archive);
      DrillLibraryException? caught;
      try {
        DrillLibrary.entries(bundle);
      } on DrillLibraryException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillLibraryReason.noDrillEntries);
      expect(caught, isA<FormatException>());
    });

    test(
      'Finder-repacked bundle decodes the nested .drill and skips cruft',
      () {
        final drillFile = DrillFile.fromPlan(_plan('u1', 'Alfa'), 'alfa');
        final archive = Archive()
          ..addFile(_entry('bundle/', ''))
          ..addFile(_entry('__MACOSX/._bundle', 'junk'))
          ..addFile(_entry('bundle/.DS_Store', 'junk'))
          ..addFile(
            ArchiveFile(
              'bundle/alfa.drill',
              drillFile.content.length,
              drillFile.content,
            ),
          )
          ..addFile(_entry('__MACOSX/bundle/._alfa.drill', 'junk'));
        final bundle = ZipEncoder().encode(archive);

        final files = DrillLibrary.entries(bundle);

        expect(files.length, 1);
        expect(files.single.fileName, 'alfa.drill');
        expect(files.single.plan().uuid, 'u1');
      },
    );

    test(
      'ZIP with only __MACOSX/.DS_Store cruft -> entries() throws noDrillEntries',
      () {
        final archive = Archive()
          ..addFile(_entry('bundle/.DS_Store', 'junk'))
          ..addFile(_entry('__MACOSX/._bundle', 'junk'));
        final bundle = ZipEncoder().encode(archive);
        DrillLibraryException? caught;
        try {
          DrillLibrary.entries(bundle);
        } on DrillLibraryException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.reason, DrillLibraryReason.noDrillEntries);
      },
    );

    test('empty bytes -> DrillLibraryReason.empty', () {
      DrillLibraryException? caught;
      try {
        DrillLibrary.entries(const <int>[]);
      } on DrillLibraryException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillLibraryReason.empty);
    });

    test('ASCII garbage -> DrillLibraryReason.notArchive', () {
      final bytes = utf8.encode('this is definitely not a zip');
      DrillLibraryException? caught;
      try {
        DrillLibrary.entries(bytes);
      } on DrillLibraryException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillLibraryReason.notArchive);
    });
  });

  group('DrillLibrary.fromPlans — slug collisions', () {
    test('two plans with the same name get distinct entry names', () {
      final bundle = DrillLibrary.fromPlans([
        _plan('uuid-1', 'My Plan'),
        _plan('uuid-2', 'My Plan'),
      ]);
      final archive = ZipDecoder().decodeBytes(bundle);
      final names = archive.files
          .where((f) => f.isFile)
          .map((f) => f.name)
          .toSet();

      expect(names, contains('my-plan.drill'));
      expect(names, contains('my-plan-1.drill'));
    });
  });
}
