import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
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
    await ProgramService().clearAllForTest();
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

  // ---------------------------------------------------------------------------
  // reorderStations
  //
  // Fixture: one exercise with three stations (Alpha=0, Beta=1, Gamma=2).
  // Reorder: [2, 0, 1] means old-index-2 (Gamma) → position 0,
  //          old-index-0 (Alpha) → position 1, old-index-1 (Beta) → position 2.
  // ---------------------------------------------------------------------------

  Exercise exThreeStations(String uuid) => Exercise(
    uuid: uuid,
    index: 0,
    name: 'Øvelse',
    startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 15,
    evaluationTime: 5,
    rotationTime: 2,
    stations: [
      Station(index: 0, name: 'Alpha'),
      Station(index: 1, name: 'Beta'),
      Station(index: 2, name: 'Gamma'),
    ],
    schedule: _schedule,
    endTime: _end,
  );

  group('ProgramService — reorderStations', () {
    test('writes a dense 0..n-1 index permutation in the new order', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, exThreeStations('ex-s'));

      // Reorder: Gamma first, then Alpha, then Beta.
      await service.reorderStations('ex-s', [2, 0, 1]);

      final ex = service.getExercise('ex-s')!;
      expect(ex.stations.length, 3);
      // Indices are reassigned densely to match list position.
      expect(ex.stations.map((s) => s.index).toList(), [0, 1, 2]);
      // Names reflect the new order.
      expect(ex.stations.map((s) => s.name).toList(), ['Gamma', 'Alpha', 'Beta']);
    });

    test('a RolePlay whose stationIndex pointed at a moved station follows it', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, exThreeStations('ex-s'));

      // Marker at old station index 0 (Alpha).
      final rp = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-s',
        name: 'Testspiller',
        stationIndex: 0,
      );
      await service.saveRolePlay(l10n, rp);

      // Reorder: old index 0 (Alpha) → new position 1.
      await service.reorderStations('ex-s', [2, 0, 1]);

      // The marker should now point at new index 1 (Alpha's new position).
      final loaded = service.getRolePlay('rp-1')!;
      expect(loaded.stationIndex, 1);
    });

    test('a RolePlay with stationIndex == null is left untouched', () async {
      final service = ProgramService();
      await service.saveExercise(l10n, exThreeStations('ex-s'));

      final rp = RolePlay(
        uuid: 'rp-null',
        index: 0,
        exerciseUuid: 'ex-s',
        name: 'Ingen post',
        stationIndex: null,
      );
      await service.saveRolePlay(l10n, rp);

      await service.reorderStations('ex-s', [2, 0, 1]);

      final loaded = service.getRolePlay('rp-null')!;
      expect(loaded.stationIndex, isNull);
    });
  });
}
