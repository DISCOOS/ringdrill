import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';

/// Coverage for exercise reorder detection in `diffPrograms`. Before this,
/// swapping two exercises' positions flagged both as "modified" with an
/// empty change list, which the view rendered as an unexplained "Other
/// changes". Now a pure reorder surfaces as a `field: 'order'` entry on that
/// specific exercise's [ItemDiff], carrying both its old (remote/catalog)
/// and new (local) formatted position (e.g. "#1" → "#2") — the same number
/// the rest of the app shows — so identically named exercises (a drill
/// program routinely repeats a name across rounds) stay distinguishable.
/// Teams have no numbering scheme, so a pure team reorder is simply not
/// reported as a change at all (see the last test).
void main() {
  final now = DateTime(2026);

  Program base({
    List<Exercise> exercises = const [],
    List<Team> teams = const [],
  }) => Program(
    uuid: 'prog-1',
    name: 'Test',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: teams,
    sessions: const [],
    exercises: exercises,
    rolePlays: const [],
    actors: const [],
  );

  Exercise exercise(String uuid, String name, {int index = 0}) => Exercise(
    uuid: uuid,
    index: index,
    name: name,
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 2,
    stations: const [Station(index: 0, name: 'Station 1')],
    schedule: const [
      [
        SimpleTimeOfDay(hour: 8, minute: 0),
        SimpleTimeOfDay(hour: 8, minute: 10),
        SimpleTimeOfDay(hour: 8, minute: 15),
      ],
    ],
    endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
  );

  test(
    'swapping two exercises reports one order change per exercise, labelled with its new number',
    () {
      final local = base(
        exercises: [
          exercise('ex-1', 'Førsteinnsats søk', index: 0),
          exercise('ex-2', 'Førsteinnsats søk', index: 1),
        ],
      );
      final remote = base(
        exercises: [
          exercise('ex-1', 'Førsteinnsats søk', index: 1),
          exercise('ex-2', 'Førsteinnsats søk', index: 0),
        ],
      );

      final diff = diffPrograms(local, remote);

      expect(diff.addedExercises, isEmpty);
      expect(diff.removedExercises, isEmpty);
      expect(diff.modifiedExercises, hasLength(2));

      // Both instances share a name (a routine occurrence — the same
      // exercise repeated per round/team) but are distinguished by their
      // local formatted number, and each carries exactly one change: its
      // own reorder, from its old (remote/catalog) to its new (local)
      // position. ex-1 is now first locally (was second in the catalog);
      // ex-2 is the reverse.
      final ex1 = diff.modifiedExercises.firstWhere((i) => i.number == '#1');
      final ex2 = diff.modifiedExercises.firstWhere((i) => i.number == '#2');
      expect(ex1.changes, hasLength(1));
      expect(ex1.changes.single.field, 'order');
      expect(ex1.changes.single.local, '#1');
      expect(ex1.changes.single.remote, '#2');
      expect(ex2.changes, hasLength(1));
      expect(ex2.changes.single.field, 'order');
      expect(ex2.changes.single.local, '#2');
      expect(ex2.changes.single.remote, '#1');
    },
  );

  test('a real content edit is still reported as modified, no order entry', () {
    final local = base(
      exercises: [
        exercise('ex-1', 'Warmup', index: 0),
        exercise('ex-2', 'Ladder', index: 1),
      ],
    );
    final remote = base(
      exercises: [
        exercise('ex-1', 'Warmup', index: 0),
        exercise('ex-2', 'Ladder', index: 1).copyWith(methodMd: 'New method'),
      ],
    );

    final diff = diffPrograms(local, remote);

    expect(diff.modifiedExercises, hasLength(1));
    final changed = diff.modifiedExercises.single;
    expect(changed.name, 'Ladder');
    expect(changed.number, '#2');
    expect(changed.changes.map((c) => c.field), ['methodMd']);
  });

  test(
    'reordering and editing the same exercise reports both facts on one card',
    () {
      final local = base(
        exercises: [
          exercise('ex-1', 'Warmup', index: 0),
          exercise('ex-2', 'Ladder', index: 1),
        ],
      );
      final remote = base(
        exercises: [
          exercise('ex-1', 'Warmup', index: 1),
          exercise('ex-2', 'Ladder', index: 0).copyWith(
            methodMd: 'New method',
          ),
        ],
      );

      final diff = diffPrograms(local, remote);

      // Both exercises moved (a swap), and 'ex-2' also had a content edit —
      // one card per exercise, each listing everything true about it.
      expect(diff.modifiedExercises, hasLength(2));
      final ladder = diff.modifiedExercises.firstWhere(
        (i) => i.name == 'Ladder',
      );
      expect(ladder.changes.map((c) => c.field), ['order', 'methodMd']);
    },
  );

  test('inserting an exercise shifts numbers without a false order change', () {
    final local = base(
      exercises: [
        exercise('ex-1', 'Warmup', index: 0),
        exercise('ex-2', 'Ladder', index: 1),
      ],
    );
    final remote = base(
      exercises: [
        exercise('ex-0', 'Briefing', index: 0),
        exercise('ex-1', 'Warmup', index: 1),
        exercise('ex-2', 'Ladder', index: 2),
      ],
    );

    final diff = diffPrograms(local, remote);

    expect(diff.addedExercises, ['Briefing']);
    expect(diff.modifiedExercises, isEmpty);
  });

  test(
    'editing a station reports it as a nested change on the exercise, '
    'not a blanket stations marker',
    () {
      final local = base(
        exercises: [exercise('ex-1', 'Søk og redning', index: 0)],
      );
      final remote = base(
        exercises: [
          local.exercises.single.copyWith(
            stations: [
              local.exercises.single.stations.single.copyWith(
                name: 'Gammelt navn',
              ),
            ],
          ),
        ],
      );

      final diff = diffPrograms(local, remote);

      expect(diff.modifiedExercises, hasLength(1));
      final exerciseDiff = diff.modifiedExercises.single;
      // The old blanket `field: 'stations'` marker is gone — no top-level
      // field change at all, just the nested station detail.
      expect(exerciseDiff.changes, isEmpty);
      expect(exerciseDiff.nestedChanges, hasLength(1));
      final stationDiff = exerciseDiff.nestedChanges.single;
      expect(stationDiff.name, 'Station 1');
      // Exercise #1's first (only) station, dotted format.
      expect(stationDiff.number, '1.1');
      expect(stationDiff.changes, hasLength(1));
      expect(stationDiff.changes.single.field, 'name');
      expect(stationDiff.changes.single.local, 'Station 1');
      expect(stationDiff.changes.single.remote, 'Gammelt navn');
    },
  );

  test('editing a station brief field reports that specific field', () {
    final local = base(
      exercises: [exercise('ex-1', 'Søk og redning', index: 0)],
    );
    final remote = base(
      exercises: [
        local.exercises.single.copyWith(
          stations: [
            local.exercises.single.stations.single.copyWith(
              equipmentMd: 'Tau og karabinkroker',
            ),
          ],
        ),
      ],
    );

    final diff = diffPrograms(local, remote);

    final stationDiff = diff.modifiedExercises.single.nestedChanges.single;
    expect(stationDiff.changes.single.field, 'equipmentMd');
    expect(stationDiff.changes.single.local, isNull);
    expect(stationDiff.changes.single.remote, 'Tau og karabinkroker');
  });

  test(
    'a station present on only one side falls back to the generic other '
    'marker rather than being silently dropped',
    () {
      final local = base(
        exercises: [exercise('ex-1', 'Søk og redning', index: 0)],
      );
      final remote = base(
        exercises: [
          local.exercises.single.copyWith(
            stations: [
              ...local.exercises.single.stations,
              const Station(index: 1, name: 'Station 2'),
            ],
          ),
        ],
      );

      final diff = diffPrograms(local, remote);

      // Added/removed stations are out of scope for per-station detail —
      // there is nothing common to diff — but the exercise-level 'other'
      // safety net still surfaces that *something* changed rather than
      // silently ignoring it.
      expect(diff.modifiedExercises, hasLength(1));
      final exerciseDiff = diff.modifiedExercises.single;
      expect(exerciseDiff.nestedChanges, isEmpty);
      expect(exerciseDiff.changes.map((c) => c.field), ['other']);
    },
  );

  test('swapping two teams is not reported — teams have no numbering scheme', () {
    final local = base(
      teams: const [
        Team(uuid: 'team-1', index: 0, name: 'Red'),
        Team(uuid: 'team-2', index: 1, name: 'Blue'),
      ],
    );
    final remote = base(
      teams: const [
        Team(uuid: 'team-1', index: 1, name: 'Red'),
        Team(uuid: 'team-2', index: 0, name: 'Blue'),
      ],
    );

    final diff = diffPrograms(local, remote);

    expect(diff.modifiedTeams, isEmpty);
    expect(diff.addedTeams, isEmpty);
    expect(diff.removedTeams, isEmpty);
  });
}
