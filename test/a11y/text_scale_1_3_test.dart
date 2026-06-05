// Regression tests for ADR-0037 part 2: klynge B/C live-drill chrome and one
// klynge A spot-check must render without RenderFlex overflow at the maximum
// reachable scale (1.3, capped by MediaQuery.withClampedTextScaling in main.dart).
//
// Tests at 1.0 establish a passing baseline; tests at 1.3 are the regression
// guard. If a surface overflows at 1.3 the test framework reports it as a
// FlutterError — only surfaces that pass at 1.3 are committed here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/phase_widget.dart';
import 'package:ringdrill/theme.dart' show kRingdrillHeaderHeight;
import 'package:ringdrill/views/widgets/sheet_title.dart';

// ---------------------------------------------------------------------------
// Shared fixture
// ---------------------------------------------------------------------------

Exercise _makeExercise() => Exercise(
      uuid: 'a11y-scale-test',
      name: 'A11y Scale Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 2,
      numberOfRounds: 3,
      executionTime: 5,
      evaluationTime: 3,
      rotationTime: 2,
      stations: [],
      schedule: [
        [
          const SimpleTimeOfDay(hour: 8, minute: 0),
          const SimpleTimeOfDay(hour: 8, minute: 5),
          const SimpleTimeOfDay(hour: 8, minute: 8),
        ],
        [
          const SimpleTimeOfDay(hour: 8, minute: 10),
          const SimpleTimeOfDay(hour: 8, minute: 15),
          const SimpleTimeOfDay(hour: 8, minute: 18),
        ],
        [
          const SimpleTimeOfDay(hour: 8, minute: 20),
          const SimpleTimeOfDay(hour: 8, minute: 25),
          const SimpleTimeOfDay(hour: 8, minute: 28),
        ],
      ],
    );

ExerciseEvent _makeEvent(Exercise exercise) => ExerciseEvent(
      when: DateTime.now(),
      phase: ExercisePhase.execution,
      exercise: exercise,
      elapsedTime: 0,
      remainingTime: 5,
      currentRound: 0,
      phaseProgress: 0.5,
      roundProgress: 0.2,
      totalProgress: 0.1,
    );

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

// Sets a 390×844 phone viewport (iPhone 14 size) and injects the textScaler
// via a MediaQuery override placed inside MaterialApp.builder — this sits after
// WidgetsApp's own MediaQuery so it wins for all descendants.
Widget _harness(double scale, Widget surface) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(body: Center(child: surface)),
    );

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() => ExerciseService().stop());

  final exercise = _makeExercise();

  // ── klynge B/C: PhaseTile (phase_tile.dart) ─────────────────────────────

  for (final scale in [1.0, 1.3]) {
    testWidgets('PhaseTile has no overflow at ${scale}x text scale',
        (tester) async {
      addTearDown(tester.view.reset);
      _setPhoneViewport(tester);

      final event = _makeEvent(exercise);
      await tester.pumpWidget(_harness(
        scale,
        PhaseTile(
          title: 'Runde 1',
          event: event,
          exercise: exercise,
          roundIndex: 0,
          titleWidth: 80,
        ),
      ));
      await tester.pump();
    });
  }

  // ── klynge B/C: PhasesWidget (phase_widget.dart) ─────────────────────────

  for (final scale in [1.0, 1.3]) {
    testWidgets('PhasesWidget has no overflow at ${scale}x text scale',
        (tester) async {
      addTearDown(tester.view.reset);
      _setPhoneViewport(tester);

      final event = _makeEvent(exercise);
      await tester.pumpWidget(_harness(
        scale,
        PhasesWidget(
          event: event,
          exercise: exercise,
          roundIndex: 0,
          phaseIndex: 1,
        ),
      ));
      await tester.pump();
    });
  }

  // ── klynge B/C: PhaseHeaders (phase_headers.dart) ────────────────────────

  for (final scale in [1.0, 1.3]) {
    testWidgets('PhaseHeaders has no overflow at ${scale}x text scale',
        (tester) async {
      addTearDown(tester.view.reset);
      _setPhoneViewport(tester);

      await tester.pumpWidget(_harness(
        scale,
        const PhaseHeaders(
          title: 'Runde',
          titleWidth: 80,
          mainAxisAlignment: MainAxisAlignment.start,
        ),
      ));
      await tester.pump();
    });
  }

  // ── klynge B/C: MiniRoundRow (mini_round_row.dart) ───────────────────────

  for (final scale in [1.0, 1.3]) {
    testWidgets('MiniRoundRow has no overflow at ${scale}x text scale',
        (tester) async {
      addTearDown(tester.view.reset);
      _setPhoneViewport(tester);

      final event = _makeEvent(exercise);
      await tester.pumpWidget(
          _harness(scale, MiniRoundRow(exercise: exercise, event: event)));
      await tester.pump();
    });
  }

  // ── klynge B/C: DrillMiniPlayer idle (drill_mini_player.dart) ────────────

  for (final scale in [1.0, 1.3]) {
    testWidgets('DrillMiniPlayer (idle) has no overflow at ${scale}x text scale',
        (tester) async {
      addTearDown(tester.view.reset);
      _setPhoneViewport(tester);

      await tester.pumpWidget(_harness(
        scale,
        DrillMiniPlayer(exercise: exercise, onOpen: () {}),
      ));
      await tester.pump();
    });
  }

  // ── klynge A spot-check: SheetTitle in 72px AppBar ───────────────────────

  for (final scale in [1.0, 1.3]) {
    testWidgets(
        'SheetTitle in 72px AppBar has no overflow at ${scale}x text scale',
        (tester) async {
      addTearDown(tester.view.reset);
      _setPhoneViewport(tester);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: kRingdrillHeaderHeight,
            title: const SheetTitle(
              primary: '1a) Turgåer: Gjennomkjøring av simulert situasjon',
              secondary: 'Krisehåndtering og kommunikasjon',
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
    });
  }
}
