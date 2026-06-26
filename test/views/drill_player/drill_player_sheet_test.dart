import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';

/// Builds an exercise whose time window lies safely in the future
/// relative to the wall clock the test happens to run under.
///
/// Hardcoded `startTime: 10:00, endTime: 11:00` made this test
/// time-of-day flaky: `ExerciseService.start()` calls
/// `_progress(force: true)` synchronously, which compares the
/// configured window against `TimeOfDay.now()`. If the test ran
/// after 10:10 (start + totalTime = numberOfRounds * 10 min), the
/// auto-stop branch fired before the sheet had a chance to
/// subscribe, leaving `_exercise == null`. The later manual
/// `stop()` call then short-circuited and never emitted a `done`
/// event, so the sheet stayed open and the test failed.
///
/// Anchoring the window two hours ahead of "now" keeps the
/// exercise in the pending phase for the entire test run regardless
/// of when it executes.
Exercise _makeExercise() {
  final now = TimeOfDay.now();
  final start = (now.hour + 2) % 24;
  final end = (start + 1) % 24;
  return Exercise(
    uuid: 'test-uuid-player-sheet',
    name: 'Player Sheet Exercise',
    startTime: SimpleTimeOfDay(hour: start, minute: 0),
    endTime: SimpleTimeOfDay(hour: end, minute: 0),
    numberOfTeams: 2,
    numberOfRounds: 1,
    executionTime: 5,
    evaluationTime: 3,
    rotationTime: 2,
    stations: [],
    schedule: [],
  );
}

Widget _harness() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDrillPlayerSheet<void>(
          context: context,
          builder: (_) => Container(
            key: const ValueKey('test-body'),
            child: const Center(child: Text('sheet body')),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  tearDown(() {
    ExerciseService().stop();
  });

  testWidgets('wraps builder body without adding chrome', (tester) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Body is rendered
    expect(find.byKey(const ValueKey('test-body')), findsOneWidget);
    expect(find.text('sheet body'), findsOneWidget);

    // Chevron-down close button is gone — body's own AppBar X is the sole
    // close affordance
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('no drag handle', (tester) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ringdrill-sheet-drag-handle')), findsNothing);
  });

  testWidgets('drag gesture does not dismiss sheet', (tester) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('sheet body'), findsOneWidget);

    await tester.fling(find.text('sheet body'), const Offset(0, 400), 800);
    await tester.pumpAndSettle();

    // Sheet must still be visible — drag is disabled
    expect(find.text('sheet body'), findsOneWidget);
  });

  testWidgets('sheet has square corners and fills the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Find the outermost Material that the modal sheet renders into and
    // verify its shape has no border radius (square corners).
    final materials = tester.widgetList<Material>(
      find.descendant(
        of: find.byKey(const ValueKey('test-body')),
        matching: find.byType(Material),
      ),
    );
    // Coarse check: no Material in the sheet subtree has a rounded shape
    final hasRoundedCorners = materials.any((m) {
      if (m.shape is RoundedRectangleBorder) {
        final r = (m.shape as RoundedRectangleBorder).borderRadius;
        return r != BorderRadius.zero;
      }
      return false;
    });
    expect(
      hasRoundedCorners,
      isFalse,
      reason: 'Sheet body must not introduce rounded corners',
    );

    // Sheet height fills the viewport
    final bodySize = tester.getSize(find.byKey(const ValueKey('test-body')));
    final viewportHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(bodySize.height, closeTo(viewportHeight, 2.0));
  });

  testWidgets('closes when the active exercise stops', (tester) async {
    ExerciseService().start(_makeExercise());
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);

    ExerciseService().stop();
    await tester.pumpAndSettle();

    expect(find.text('sheet body'), findsNothing);
  });
}
