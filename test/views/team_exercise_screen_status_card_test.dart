import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: player-status-card — the Lag player's now/next is
// the post the team is at now/next, badged with the shared station-number
// badge, from Exercise.stationIndex.
// ---------------------------------------------------------------------------

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: 'team-status-card-ex',
  name: 'Team Status Card Test Exercise',
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

/// A fixed morning reference, safely clear of midnight for every offset
/// used below (up to 43 minutes) and well before the fixture's own
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

  testWidgets('running: team 0 shows the badged post it is at now/next', (
    tester,
  ) async {
    final exercise = _exercise(startTime: _startTimeMinutesAgo(3));
    ExerciseService().debugNowOverride = () => _fixedNow;
    addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
    // Team 0: stationIndex(0, round) = round % 3 -> round0: station0
    // ("Post 1"), round1: station1 ("Post 2").
    ExerciseService().start(exercise);

    await tester.pumpWidget(
      _harness(TeamExerciseScreen(teamIndex: 0, exercise: exercise)),
    );
    await tester.pump();

    final cardFinder = find.byType(PlayerStatusCard);
    expect(cardFinder, findsOneWidget);

    expect(
      find.descendant(
        of: cardFinder,
        matching: find.textContaining(l10n.statusNow),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cardFinder,
        matching: find.textContaining(l10n.nextLabel),
      ),
      findsOneWidget,
    );
    // Both post names appear, each with its own number badge — not a
    // bare label baked into the surface title.
    expect(
      find.descendant(of: cardFinder, matching: find.text('Post 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardFinder, matching: find.text('Post 2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardFinder, matching: find.text('1.1')),
      findsOneWidget,
      reason: 'the "Nå" post is badged with the dotted station number',
    );
    expect(
      find.descendant(of: cardFinder, matching: find.text('1.2')),
      findsOneWidget,
      reason: 'the "Neste" post is badged with the dotted station number',
    );

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets(
    'running: team 0 on the last round falls back to the exercise finish '
    'time instead of an empty next-cell',
    (tester) async {
      // 3 minutes into round 2's (the last round's) execution phase: 2 full
      // rounds (20 min each: executionTime 10 + evaluationTime 5 +
      // rotationTime 5) plus 3 minutes.
      final exercise = _exercise(startTime: _startTimeMinutesAgo(43));
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
      // Team 0: stationIndex(0, 2) = 2 -> "Post 3" (still active this
      // round) — only the "next" cell is exhausted (no round after the
      // last one).
      ExerciseService().start(exercise);

      await tester.pumpWidget(
        _harness(TeamExerciseScreen(teamIndex: 0, exercise: exercise)),
      );
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);

      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('${l10n.nextLabel} · ${exercise.endTime}'),
        ),
        findsOneWidget,
        reason:
            'the next-cell label still reads "Next", with the '
            "exercise's finish time appended inline",
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.statusFinishValue),
        ),
        findsOneWidget,
        reason: 'the next-cell value reads "Finish" instead of being empty',
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );
}
