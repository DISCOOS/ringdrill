import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: player-status-card — the coordinator's now/next is
// two forward-looking cells (no "Nå"), both labelled "Neste" (B3: the
// phase/round distinction is carried by the value and the inline time, not
// by "Neste fase"/"Neste runde"), from Exercise.schedule.
//
// 3 stations, 2 teams, 3 rounds — Exercise.teamIndex(stationIndex, round):
//   round0: s0->team0 s1->team1 s2->none
//   round1: s0->none  s1->team0 s2->team1
//   round2: s0->team1 s1->none  s2->team0
// ---------------------------------------------------------------------------

const _planUuid = 'prog-coordinator-status-card';
const _exerciseUuid = 'ex-coordinator-status-card';

/// A fixed morning reference, safely clear of midnight for every offset
/// used below (up to 58 minutes) and well before the fixture's own
/// `endTime` (noon) so it never itself reads as "past end".
final _fixedNow = DateTime(2026, 1, 1, 9, 0);

/// A [SimpleTimeOfDay] [minutesAgo] before [_fixedNow] — pairs with
/// [ExerciseService.debugNowOverride] pinned to [_fixedNow] so a test is
/// not at the mercy of real wall-clock time. A bare
/// `DateTime.now().subtract(...)` loses its date once truncated to
/// [SimpleTimeOfDay] (hour/minute only): whenever the real current time was
/// less than the subtracted offset past midnight, the synthetic start time
/// landed on the previous day and the exercise looked scheduled in the
/// future (pending) instead of already running — flaky in exactly the
/// first `minutesAgo` minutes after midnight.
SimpleTimeOfDay _startTimeMinutesAgo(int minutesAgo) {
  final past = _fixedNow.subtract(Duration(minutes: minutesAgo));
  return SimpleTimeOfDay(hour: past.hour, minute: past.minute);
}

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: _exerciseUuid,
  name: 'Coordinator Status Card Test Exercise',
  startTime: startTime,
  numberOfTeams: 2,
  numberOfRounds: 3,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [
    Station(index: 0, name: 'Post 1'),
    Station(index: 1, name: 'Post 2'),
    Station(index: 2, name: 'Post 3'),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
    [
      SimpleTimeOfDay(hour: 8, minute: 20),
      SimpleTimeOfDay(hour: 8, minute: 30),
      SimpleTimeOfDay(hour: 8, minute: 35),
    ],
    [
      SimpleTimeOfDay(hour: 8, minute: 40),
      SimpleTimeOfDay(hour: 8, minute: 50),
      SimpleTimeOfDay(hour: 8, minute: 55),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 12, minute: 0),
);

Future<void> _seedAndInit(Exercise exercise) async {
  SharedPreferences.setMockInitialValues({
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
      'description': '',
      'metadata': {
        'created': '2024-01-01T00:00:00.000Z',
        'updated': '2024-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(exercise.toJson()),
  });
  await PlanService().init();
}

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'running: shows two "Next" cells with no icon, no "Now" cell',
    (tester) async {
      // 3 minutes into round 0's execution phase (executionTime: 10), well
      // clear of round-boundary jitter, regardless of when the test runs.
      final exercise = _exercise(startTime: _startTimeMinutesAgo(3));
      await _seedAndInit(exercise);
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
      ExerciseService().start(exercise);

      await tester.pumpWidget(
        _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
      );
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);

      // The label row combines the label with an inline time ("Next ·
      // 08:10"), per the mockup, so match on containment. Both cells share
      // the plain "Next" label (B3) — the phase/round distinction is
      // carried by the value/time, not the label.
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.textContaining(l10n.nextLabel),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.textContaining(l10n.statusNextPhase),
        ),
        findsNothing,
        reason: '"Next phase" overflowed the half-card and is replaced by '
            'the plain "Next" label (B3)',
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.textContaining(l10n.statusNextRound),
        ),
        findsNothing,
        reason: '"Next round" overflowed the half-card and is replaced by '
            'the plain "Next" label (B3)',
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.textContaining(l10n.statusNow),
        ),
        findsNothing,
        reason: 'the coordinator has no "Nå" cell — the phase is already '
            'in the countdown line',
      );
      // No icon on either now/next cell (B3).
      expect(
        find.descendant(of: cardFinder, matching: find.byIcon(Icons.repeat)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.byIcon(Icons.arrow_forward),
        ),
        findsNothing,
      );

      // Round 0 execution's next phase is round 0's evaluation ("EVAL").
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.eval.toUpperCase()),
        ),
        findsOneWidget,
      );
      // The next round after round 0 is round 1 (displayed as "Round 2").
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('${l10n.round(1)} 2'),
        ),
        findsOneWidget,
      );

      // Stop inside the FakeAsync zone so the periodic timer is cancelled
      // before the framework's pending-timer invariant check.
      ExerciseService().stop();
      await tester.pump();
    },
  );

  testWidgets(
    'running: mid last round, the next-round cell falls back to the '
    'exercise finish time while next-phase still shows the real phase',
    (tester) async {
      // 3 minutes into round 2's (the last round's) execution phase: 2 full
      // rounds (20 min each: executionTime 10 + evaluationTime 5 +
      // rotationTime 5) plus 3 minutes.
      final exercise = _exercise(startTime: _startTimeMinutesAgo(43));
      await _seedAndInit(exercise);
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
      ExerciseService().start(exercise);

      await tester.pumpWidget(
        _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
      );
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);

      // Next phase (round 2 execution's next phase is round 2's EVAL) is
      // unaffected — only the next-round cell is exhausted.
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.eval.toUpperCase()),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('${l10n.nextLabel} · ${exercise.endTime}'),
        ),
        findsOneWidget,
        reason: 'the next-round cell falls back to "Next · finish time" '
            'instead of being empty',
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.statusFinishValue),
        ),
        findsOneWidget,
        reason: 'only the next-round cell falls back here — next phase '
            'still has a real phase to show',
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );

  testWidgets(
    'running: last phase of the last round, both next-cells fall back to '
    'the exercise finish time',
    (tester) async {
      // 3 minutes into round 2's rotation (ROLL) phase, its last phase:
      // 2 full rounds (40 min) + executionTime (10) + evaluationTime (5) +
      // 3 minutes into the 5-minute rotation phase.
      final exercise = _exercise(startTime: _startTimeMinutesAgo(58));
      await _seedAndInit(exercise);
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
      ExerciseService().start(exercise);

      await tester.pumpWidget(
        _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
      );
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);

      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('${l10n.nextLabel} · ${exercise.endTime}'),
        ),
        findsNWidgets(2),
        reason: 'both cells fall back to "Next · finish time" — there is '
            'no further phase or round to report',
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.statusFinishValue),
        ),
        findsNWidgets(2),
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );
}
