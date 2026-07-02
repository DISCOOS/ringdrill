import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_library.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/station.dart';

Program _program(String uuid, String name, {int exerciseCount = 0}) {
  final now = DateTime(2026, 1, 1);
  return Program(
    uuid: uuid,
    name: name,
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
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
    actors: const [],
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
      final content = DrillFile.fromProgram(_program('u1', 'Solo plan'), 'x').content;
      expect(DrillLibrary.sniff(content), DrillArchiveKind.single);
    });

    test('drill-library bundle -> DrillArchiveKind.library', () {
      final content = DrillLibrary.fromPrograms([
        _program('u1', 'Alfa'),
        _program('u2', 'Beta'),
      ]);
      expect(DrillLibrary.sniff(content), DrillArchiveKind.library);
    });

    test('ASCII garbage -> DrillArchiveKind.invalid', () {
      final content = utf8.encode('this is definitely not a zip');
      expect(DrillLibrary.sniff(content), DrillArchiveKind.invalid);
    });

    test(
      'ZIP with neither program.json nor .drill entries -> invalid',
      () {
        final archive = Archive()..addFile(_entry('readme.txt', 'hello'));
        final content = ZipEncoder().encode(archive);
        expect(DrillLibrary.sniff(content), DrillArchiveKind.invalid);
      },
    );

    test('empty ZIP -> DrillArchiveKind.invalid', () {
      final content = _emptyZip();
      expect(DrillLibrary.sniff(content), DrillArchiveKind.invalid);
    });
  });

  group('DrillLibrary.entries — round-trip', () {
    test('fromPrograms([a, b]) -> entries() reproduces a and b', () {
      final a = _program('uuid-a', 'Alfa plan', exerciseCount: 2);
      final b = _program('uuid-b', 'Beta plan', exerciseCount: 1);

      final bundle = DrillLibrary.fromPrograms([a, b]);
      final files = DrillLibrary.entries(bundle);
      expect(files.length, 2);

      final programs = files.map((f) => f.program()).toList();
      final byUuid = {for (final p in programs) p.uuid: p};

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

  group('DrillLibrary.fromPrograms — slug collisions', () {
    test('two programs with the same name get distinct entry names', () {
      final bundle = DrillLibrary.fromPrograms([
        _program('uuid-1', 'My Plan'),
        _program('uuid-2', 'My Plan'),
      ]);
      final archive = ZipDecoder().decodeBytes(bundle);
      final names =
          archive.files.where((f) => f.isFile).map((f) => f.name).toSet();

      expect(names, contains('my-plan.drill'));
      expect(names, contains('my-plan-1.drill'));
    });
  });
}
