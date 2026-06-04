import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _station = Station(index: 0, name: 'Post 1');
final _schedule = [
  [
    SimpleTimeOfDay(hour: 9, minute: 0),
    SimpleTimeOfDay(hour: 9, minute: 15),
    SimpleTimeOfDay(hour: 9, minute: 20),
  ],
];
final _end = SimpleTimeOfDay(hour: 9, minute: 22);

Exercise _ex(String uuid, {String name = 'Øvelse', int index = 0}) => Exercise(
  uuid: uuid,
  index: index,
  name: name,
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 15,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [_station],
  schedule: _schedule,
  endTime: _end,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgramService().init();
    // Pre-create and activate a program so saveExercise doesn't need to
    // create a default plan itself.
    final program = await ProgramService().createProgram(name: 'Test plan');
    await ProgramService().setActive(program.uuid);
  });

  tearDown(() async {
    final service = ProgramService();
    for (final p in List.from(service.listPrograms())) {
      await service.deleteProgram(p.uuid);
    }
  });

  group('ProgramService — index assignment on create', () {
    test('first exercise appended to empty plan gets index 0', () async {
      final service = ProgramService();
      final exercise = _ex('ex-1');
      await service.saveExercise(l10n, exercise);

      final loaded = service.loadExercises();
      expect(loaded.length, 1);
      expect(loaded.first.index, 0);
    });

    test('second exercise appended gets index 1', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, _ex('ex-1', index: 0));
      await service.saveExercise(l10n, _ex('ex-2', index: 0));

      // loadExercises normalises: both had index 0 → migration by name.
      // But from saveExercise the second one gets index = max + 1.
      final loaded = service.loadExercises();
      expect(loaded.length, 2);
      // After save, indices are a valid permutation.
      final indices = loaded.map((e) => e.index).toSet();
      expect(indices, {0, 1});
    });

    test('editing an existing exercise preserves its index', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, _ex('ex-1'));
      final original = service.loadExercises().first;

      // Save again with a name change — index must not change.
      await service.saveExercise(l10n, original.copyWith(name: 'Renamed'));
      final updated = service.loadExercises().first;
      expect(updated.name, 'Renamed');
      expect(updated.index, original.index);
    });
  });

  group('ProgramService — reorderExercises', () {
    test('produces a dense 0..n-1 permutation', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, _ex('ex-a', name: 'Alpha'));
      await service.saveExercise(l10n, _ex('ex-b', name: 'Beta'));
      await service.saveExercise(l10n, _ex('ex-c', name: 'Gamma'));

      final before = service.loadExercises();
      final uuids = before.map((e) => e.uuid).toList();

      // Reverse the order.
      await service.reorderExercises(uuids.reversed.toList());

      final after = service.loadExercises();
      expect(after.length, 3);
      expect(after.map((e) => e.index).toList(), [0, 1, 2]);
      // The list is now in the reversed order.
      expect(after.map((e) => e.uuid).toList(), uuids.reversed.toList());
    });

    test('reordering to the same order does not change indices', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, _ex('ex-1'));
      await service.saveExercise(l10n, _ex('ex-2'));

      final before = service.loadExercises();
      final uuids = before.map((e) => e.uuid).toList();
      await service.reorderExercises(uuids);

      final after = service.loadExercises();
      for (var i = 0; i < after.length; i++) {
        expect(after[i].uuid, before[i].uuid);
        expect(after[i].index, before[i].index);
      }
    });
  });
}
