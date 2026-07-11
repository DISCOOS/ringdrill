import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: player-status-card — the shared PlayerStatusCard
// widget itself, in isolation from the four surfaces that wire it up.
// ---------------------------------------------------------------------------

Exercise _exercise() => Exercise(
  uuid: 'status-card-ex',
  name: 'Status Card Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 10, minute: 45),
  numberOfTeams: 1,
  numberOfRounds: 6,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: List.generate(
    6,
    (i) => [
      SimpleTimeOfDay(hour: 10, minute: i),
      SimpleTimeOfDay(hour: 10, minute: i + 10),
      SimpleTimeOfDay(hour: 10, minute: i + 15),
    ],
  ),
  endTime: const SimpleTimeOfDay(hour: 14, minute: 0),
);

/// 20 h 45 min remaining until start — the mockup's own pre-start figure.
ExerciseEvent _pendingEvent(Exercise exercise) => ExerciseEvent(
  when: DateTime.now(),
  phase: ExercisePhase.pending,
  exercise: exercise,
  elapsedTime: 0,
  remainingTime: 20 * 60 + 45,
  currentRound: 0,
  phaseProgress: 0,
  roundProgress: 0,
  totalProgress: 0,
);

ExerciseEvent _runningEvent(
  Exercise exercise, {
  int currentRound = 0,
  int remainingTime = 5,
  double phaseProgress = 0.66,
}) => ExerciseEvent(
  when: DateTime.now(),
  phase: ExercisePhase.execution,
  exercise: exercise,
  elapsedTime: 300,
  remainingTime: remainingTime,
  currentRound: currentRound,
  phaseProgress: phaseProgress,
  roundProgress: 0.3,
  totalProgress: 0.1,
);

Widget _harness(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'a pending event renders the pre-start block, no phase or now/next '
    'even when cells are supplied',
    (tester) async {
      final exercise = _exercise();
      final event = _pendingEvent(exercise);
      final leading = const PlayerStatusCell(
        icon: Icons.groups,
        label: 'Now',
        value: 'Team 1',
        isNow: true,
      );
      final trailing = const PlayerStatusCell(
        icon: Icons.arrow_forward,
        label: 'Next',
        time: '11:15',
        value: 'Team 4',
      );

      await tester.pumpWidget(
        _harness(
          PlayerStatusCard(
            event: event,
            preStartSubline: 'starts 10:45 · 6 rounds',
            leadingCell: leading,
            trailingCell: trailing,
          ),
        ),
      );

      // Spelled-out countdown with units, not an ambiguous mm:ss/H:MM clock.
      expect(find.textContaining('20'), findsOneWidget);
      expect(find.text(l10n.statusUntilStart.toUpperCase()), findsOneWidget);
      expect(find.text('starts 10:45 · 6 rounds'), findsOneWidget);

      // No running-state content at all.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Team 1'), findsNothing);
      expect(find.text('Team 4'), findsNothing);
      expect(find.text(event.getState(l10n)), findsNothing);
    },
  );

  testWidgets(
    'a running event renders the countdown + meta + progress + now/next',
    (tester) async {
      final exercise = _exercise();
      final event = _runningEvent(exercise);
      final leading = const PlayerStatusCell(
        icon: Icons.groups,
        label: 'Now',
        value: 'Team 1',
        isNow: true,
      );
      final trailing = const PlayerStatusCell(
        icon: Icons.arrow_forward,
        label: 'Next',
        time: '11:15',
        value: 'Team 4',
      );

      await tester.pumpWidget(
        _harness(
          PlayerStatusCard(
            event: event,
            leadingCell: leading,
            trailingCell: trailing,
          ),
        ),
      );

      // Countdown line: bare remaining number + phase name (getState()).
      expect(find.text('${event.remainingTime}'), findsOneWidget);
      expect(find.text(event.getState(l10n)), findsOneWidget);

      // Meta cell: round counter + phase-end time.
      expect(
        find.text(l10n.statusRoundOfTotal(1, exercise.numberOfRounds)),
        findsOneWidget,
      );
      final endTime = exercise.phaseEndTime(
        event.currentRound,
        event.phase.index - 1,
      )!;
      expect(find.text(l10n.phaseEndsAt(endTime.toString())), findsOneWidget);

      // Phase-progress bar, driven by ExerciseEvent.phaseProgress.
      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, event.phaseProgress);

      // Now/next row.
      expect(find.text('Team 1'), findsOneWidget);
      expect(find.text('Team 4'), findsOneWidget);
    },
  );

  testWidgets(
    'a long value shows via badge + wrapped/auto-sized text, not truncated '
    'to just an ellipsis',
    (tester) async {
      final exercise = _exercise();
      final event = _runningEvent(exercise);
      const longName = 'Fisker (Angler)';
      const trailing = PlayerStatusCell(
        icon: Icons.arrow_forward,
        label: 'Next',
        time: '11:15',
        badge: '2b',
        value: longName,
      );

      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 300,
            child: PlayerStatusCard(event: event, trailingCell: trailing),
          ),
        ),
      );

      // The badge and the full value text both render — the value is never
      // clipped down to a bare "…".
      expect(find.text('2b'), findsOneWidget);
      expect(find.text(longName), findsOneWidget);
      expect(find.text('…'), findsNothing);
    },
  );
}
