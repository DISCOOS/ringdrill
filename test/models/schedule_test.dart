// ADR-0062's derivation: a round is as long as the stations live in it, and which
// stations those are comes from the exercise's mode.
//
// The invariant that matters most is the first group's: a ring route with no station
// overrides must derive exactly what it derived before this existed, because that is
// most of every plan in the catalog.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/schedule.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';

const _nine = SimpleTimeOfDay(hour: 9, minute: 0);

String _hhmm(SimpleTimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}';

/// Per-round phases where only the execution length varies, which is the shape most of
/// these cases are about.
List<PhaseMinutes> _uniform(
  List<int> execution, {
  required int evaluation,
  required int rotation,
}) => [
  for (final minutes in execution)
    (execution: minutes, evaluation: evaluation, rotation: rotation),
];

List<String> _flat(List<RoundPhases> rounds) => [
  for (final round in rounds) round.map(_hhmm).join('-'),
];

void main() {
  group('a uniform ring route is unchanged', () {
    test('rounds match the old one-cycle-multiplied derivation', () {
      // 15 + 10 + 5 from 09:00, four rounds. Every existing document depends on
      // exactly these numbers, so they are spelled out rather than computed.
      final rounds = ExerciseSchedule.rounds(
        startTime: _nine,
        numberOfRounds: 4,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
      );
      expect(_flat(rounds), [
        '0900-0915-0925',
        '0930-0945-0955',
        '1000-1015-1025',
        '1030-1045-1055',
      ]);
    });

    test('endTime still counts the trailing rotation', () {
      // startTime + numberOfRounds * cycle. The teams still have to move off the
      // last station, which is why the final rotation is in.
      final end = ExerciseSchedule.endTime(
        startTime: _nine,
        numberOfRounds: 4,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
      );
      expect(_hhmm(end), '1100');
    });

    test('the uniform entry points agree with the general one', () {
      // `rounds` and `endTime` are now thin wrappers. If they ever disagree with
      // `roundsFrom`/`endTimeFrom` on equal inputs, one of them has grown a special
      // case it should not have.
      const args = (execution: 20, evaluation: 5, rotation: 5, count: 3);
      expect(
        _flat(
          ExerciseSchedule.rounds(
            startTime: _nine,
            numberOfRounds: args.count,
            executionTime: args.execution,
            evaluationTime: args.evaluation,
            rotationTime: args.rotation,
          ),
        ),
        _flat(
          ExerciseSchedule.roundsFrom(
            startTime: _nine,
            minutes: _uniform(
              List.filled(args.count, args.execution),
              evaluation: args.evaluation,
              rotation: args.rotation,
            ),
          ),
        ),
      );
    });
  });

  group('executionMinutesFor', () {
    test('ring: every station is live every round, so the longest sets all', () {
      // The correction that came out of reviewing the mockup. An unequal ring does
      // not produce unequal rounds — it produces equally *longer* ones, and teams on
      // the short stations wait.
      final minutes = ExerciseSchedule.executionMinutesFor(
        mode: ExerciseMode.ring,
        numberOfRounds: 4,
        executionTime: 15,
        stationMinutes: const [15, 15, 25, 15],
      );
      expect(minutes, [25, 25, 25, 25]);
    });

    test('ring with no stations falls back to the exercise time', () {
      expect(
        ExerciseSchedule.executionMinutesFor(
          mode: ExerciseMode.ring,
          numberOfRounds: 2,
          executionTime: 15,
          stationMinutes: const [],
        ),
        [15, 15],
      );
    });

    test('together: a round is a station, in order, at its own length', () {
      // Exercise 7's sequential part: 70 then 100.
      expect(
        ExerciseSchedule.executionMinutesFor(
          mode: ExerciseMode.together,
          numberOfRounds: 2,
          executionTime: 15,
          stationMinutes: const [70, 100],
        ),
        [70, 100],
      );
    });

    test('split: a round is a group, as long as its longest station', () {
      // Four teams across three stations — 2 + 1 + 1 — is one group of three
      // stations running at once, so one round of 75.
      expect(
        ExerciseSchedule.executionMinutesFor(
          mode: ExerciseMode.split,
          numberOfRounds: 1,
          executionTime: 15,
          stationMinutes: const [75, 75, 90],
          groups: const [
            [0, 1, 2],
          ],
        ),
        [90],
      );
    });

    test('split with no groups declared degenerates to together', () {
      // Not an error state: a split exercise mid-edit has stations before it has
      // groups, and one station per round is the honest reading until it does.
      expect(
        ExerciseSchedule.executionMinutesFor(
          mode: ExerciseMode.split,
          numberOfRounds: 3,
          executionTime: 15,
          stationMinutes: const [70, 100, 75],
        ),
        [70, 100, 75],
      );
    });

    test(
      'a group naming a station that does not exist is ignored, not fatal',
      () {
        // A stale index survives a station being deleted. The round still has to have
        // a length, and the exercise's own time is the only defensible one.
        expect(
          ExerciseSchedule.executionMinutesFor(
            mode: ExerciseMode.split,
            numberOfRounds: 1,
            executionTime: 15,
            stationMinutes: const [70],
            groups: const [
              [9],
            ],
          ),
          [15],
        );
      },
    );
  });

  group('phaseMinutesFor', () {
    const exercise = (execution: 15, evaluation: 10, rotation: 5);

    test('a station inherits each phase it does not override', () {
      final minutes = ExerciseSchedule.stationMinutesFrom(
        stations: const [
          Station(index: 0, name: 'a'),
          Station(index: 1, name: 'b', executionTime: 100),
          Station(index: 2, name: 'c', rotationTime: 25),
          Station(
            index: 3,
            name: 'd',
            executionTime: 40,
            evaluationTime: 20,
            rotationTime: 2,
          ),
        ],
        fallback: exercise,
      );

      expect(minutes[0], exercise, reason: 'nothing overridden');
      expect(minutes[1], (execution: 100, evaluation: 10, rotation: 5));
      expect(minutes[2], (execution: 15, evaluation: 10, rotation: 25));
      expect(minutes[3], (execution: 40, evaluation: 20, rotation: 2));
    });

    test('ring: each phase is maxed on its own, not as a package', () {
      // The claim worth pinning. The post that runs longest is not necessarily the one
      // furthest from the next, so taking the longest station's *triple* would inflate
      // the phases it does not lead on.
      final minutes = ExerciseSchedule.phaseMinutesFor(
        mode: ExerciseMode.ring,
        numberOfRounds: 2,
        fallback: exercise,
        stationMinutes: const [
          (execution: 100, evaluation: 10, rotation: 5),
          (execution: 15, evaluation: 10, rotation: 25),
        ],
      );

      expect(minutes, [
        (execution: 100, evaluation: 10, rotation: 25),
        (execution: 100, evaluation: 10, rotation: 25),
      ]);
    });

    test('ring: overriding every station downward shortens the round', () {
      // No floor at the exercise's own value: if no station needs 15 minutes, keeping
      // teams at a post for 15 minutes is time the exercise does not have.
      expect(
        ExerciseSchedule.phaseMinutesFor(
          mode: ExerciseMode.ring,
          numberOfRounds: 1,
          fallback: exercise,
          stationMinutes: const [
            (execution: 8, evaluation: 4, rotation: 2),
            (execution: 10, evaluation: 4, rotation: 2),
          ],
        ),
        [(execution: 10, evaluation: 4, rotation: 2)],
      );
    });

    test('together: the walk out of station 3 is round 3 rotation', () {
      // A round *is* a station here, so a per-station rotation lands exactly where it
      // was authored rather than being flattened into a maximum.
      expect(
        ExerciseSchedule.phaseMinutesFor(
          mode: ExerciseMode.together,
          numberOfRounds: 3,
          fallback: exercise,
          stationMinutes: const [
            (execution: 70, evaluation: 10, rotation: 5),
            (execution: 100, evaluation: 20, rotation: 30),
            (execution: 45, evaluation: 10, rotation: 5),
          ],
        ),
        const [
          (execution: 70, evaluation: 10, rotation: 5),
          (execution: 100, evaluation: 20, rotation: 30),
          (execution: 45, evaluation: 10, rotation: 5),
        ],
      );
    });

    test('split: the longest of each phase within the group', () {
      expect(
        ExerciseSchedule.phaseMinutesFor(
          mode: ExerciseMode.split,
          numberOfRounds: 2,
          fallback: exercise,
          stationMinutes: const [
            (execution: 75, evaluation: 10, rotation: 30),
            (execution: 90, evaluation: 25, rotation: 5),
            (execution: 45, evaluation: 10, rotation: 5),
          ],
          groups: const [
            [0, 1],
            [2],
          ],
        ),
        const [
          (execution: 90, evaluation: 25, rotation: 30),
          (execution: 45, evaluation: 10, rotation: 5),
        ],
      );
    });

    test('a long walk moves the clock, not just the total', () {
      // End to end: the rotation override has to land between the rounds, or the phase
      // boundaries a marker reads off the brief are wrong even when the total is right.
      final minutes = ExerciseSchedule.phaseMinutesFor(
        mode: ExerciseMode.together,
        numberOfRounds: 2,
        fallback: exercise,
        stationMinutes: const [
          (execution: 30, evaluation: 10, rotation: 40),
          (execution: 30, evaluation: 10, rotation: 5),
        ],
      );
      final rounds = ExerciseSchedule.roundsFrom(
        startTime: _nine,
        minutes: minutes,
      );

      // Round 2 starts 40 minutes after round 1's evaluation ends, not 5.
      expect(_flat(rounds), ['0900-0930-0940', '1020-1050-1100']);
      expect(
        _hhmm(ExerciseSchedule.endTimeFrom(startTime: _nine, minutes: minutes)),
        '1105',
      );
    });
  });

  group('roundsForMode', () {
    test('ring obeys the authored count', () {
      expect(
        ExerciseSchedule.roundsForMode(
          mode: ExerciseMode.ring,
          numberOfRounds: 6,
          numberOfStations: 4,
        ),
        6,
      );
    });

    test(
      'together derives one round per station, ignoring the authored count',
      () {
        // The field becomes derived in this mode, which is why the editor shows it
        // locked rather than editable.
        expect(
          ExerciseSchedule.roundsForMode(
            mode: ExerciseMode.together,
            numberOfRounds: 4,
            numberOfStations: 2,
          ),
          2,
        );
      },
    );

    test('split derives one round per group', () {
      expect(
        ExerciseSchedule.roundsForMode(
          mode: ExerciseMode.split,
          numberOfRounds: 4,
          numberOfStations: 4,
          numberOfGroups: 3,
        ),
        3,
      );
    });
  });

  group('the exercises that motivated ADR-0062', () {
    test('Exercise 7 derives 20:15–01:15, not 20:15–02:35', () {
      // Stations a=70 and b=100 in sequence, then c and d together at 75. The plan
      // as shipped derived 80 minutes that do not exist, with a note in
      // execution_tips telling the reader not to trust the grid.
      final minutes = ExerciseSchedule.executionMinutesFor(
        mode: ExerciseMode.split,
        numberOfRounds: 3,
        executionTime: 15,
        stationMinutes: const [70, 100, 75, 75],
        groups: const [
          [0],
          [1],
          [2, 3],
        ],
      );
      expect(minutes, [70, 100, 75]);

      final rounds = ExerciseSchedule.roundsFrom(
        startTime: const SimpleTimeOfDay(hour: 20, minute: 15),
        minutes: _uniform(minutes, evaluation: 10, rotation: 10),
      );
      expect(_flat(rounds), [
        '2015-2125-2135',
        '2145-2325-2335',
        '2345-0100-0110',
      ]);

      final end = ExerciseSchedule.endTimeFrom(
        startTime: const SimpleTimeOfDay(hour: 20, minute: 15),
        minutes: _uniform(minutes, evaluation: 10, rotation: 10),
      );
      expect(_hhmm(end), '0120');
    });

    test('Exercise 4 as together keeps its real team count', () {
      // The workaround was numberOfTeams: 1 — four teams merged into one so the
      // schedule came out right, which made the brief label the merged group
      // "Lag 2.1". Together needs no such lie.
      final minutes = ExerciseSchedule.executionMinutesFor(
        mode: ExerciseMode.together,
        numberOfRounds: 2,
        executionTime: 45,
        stationMinutes: const [45, 45],
      );
      final rounds = ExerciseSchedule.roundsFrom(
        startTime: const SimpleTimeOfDay(hour: 13, minute: 0),
        minutes: _uniform(minutes, evaluation: 15, rotation: 10),
      );
      expect(_flat(rounds), ['1300-1345-1400', '1410-1455-1510']);
    });
  });

  group('generateSchedule carries the mode and groups', () {
    // The exercise editor rebuilds its exercise from these inputs on every save, so
    // anything generateSchedule does not take is dropped. That is how a split plan
    // edited in the app would silently revert to a ring route — the flattening hazard
    // ADR-0062 named, closed by passing them rather than by guarding against it.
    testWidgets('a split exercise keeps its groups and its derived clock', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final rebuilt = PlanService.generateSchedule(
        name: 'Night search',
        startTime: const TimeOfDay(hour: 20, minute: 15),
        numberOfTeams: 4,
        numberOfStations: 4,
        numberOfRounds: 3,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 10,
        localizations: l10n,
        mode: ExerciseMode.split,
        groups: const [
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 0, teams: [0, 1, 2, 3]),
            ],
          ),
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 1, teams: [0, 1, 2, 3]),
            ],
          ),
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 2, teams: [0, 1]),
              GroupSlot(stationIndex: 3, teams: [2, 3]),
            ],
          ),
        ],
        stations: const [
          Station(index: 0, name: 'A', executionTime: 70),
          Station(index: 1, name: 'B', executionTime: 100),
          Station(index: 2, name: 'C', executionTime: 75),
          Station(index: 3, name: 'D', executionTime: 75),
        ],
      );

      expect(rebuilt.mode, ExerciseMode.split);
      expect(rebuilt.groups, hasLength(3));
      expect(rebuilt.numberOfRounds, 3, reason: 'one per group');
      expect(_flat(rebuilt.schedule), [
        '2015-2125-2135',
        '2145-2325-2335',
        '2345-0100-0110',
      ]);
      // And the assignment still answers "who is where" after the rebuild.
      expect(rebuilt.teamsAt(2, 2), [0, 1]);
      expect(rebuilt.teamsAt(3, 2), [2, 3]);
    });

    testWidgets('a ring exercise is unchanged by any of this', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final rebuilt = PlanService.generateSchedule(
        name: 'Area search',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        numberOfTeams: 4,
        numberOfStations: 4,
        numberOfRounds: 4,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
        localizations: l10n,
      );
      expect(rebuilt.mode, ExerciseMode.ring);
      expect(rebuilt.groups, isEmpty);
      expect(_flat(rebuilt.schedule), [
        '0900-0915-0925',
        '0930-0945-0955',
        '1000-1015-1025',
        '1030-1045-1055',
      ]);
    });
  });
}
