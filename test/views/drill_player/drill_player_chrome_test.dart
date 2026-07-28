import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's own chrome, both borrowed from the now-playing metaphor
/// DESIGN-001 is built on:
/// - its page background is a step off the ordinary scaffold colour, so being in
///   the player reads without a label, and
/// - it closes with a chevron-down rather than an X, because it dismisses back to
///   the mini bar without stopping anything. DESIGN-001 specified the chevron
///   from the start; the X was drift.
const _planUuid = 'prog-chrome';
const _exerciseUuid = 'ex-chrome';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Chrome Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
  );
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  ExerciseService().stop();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await PlanService().init();
}

Future<void> _openPlayer(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => DrillPlayerCoordinator().openDrillPlayer(
                context,
                target: const ExerciseSheetTarget(exerciseUuid: _exerciseUuid),
              ),
              child: const Text('open player'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open player'));
  await tester.pumpAndSettle();
}

/// The background the player's hosted screen actually paints with.
Color _playerScaffold(WidgetTester tester) => Theme.of(
  tester.element(find.byType(CoordinatorScreen)),
).scaffoldBackgroundColor;

void main() {
  setUp(_seedAndInit);

  group('page background', () {
    testWidgets('light: a step darker than the ordinary scaffold', (
      tester,
    ) async {
      await _openPlayer(tester, ringDrillTheme);

      final player = _playerScaffold(tester);
      final base = ringDrillTheme.scaffoldBackgroundColor;
      expect(player, isNot(base));
      // Darker: away from the surrounding surface, which is what makes the step
      // legible in a light theme.
      expect(player.computeLuminance(), lessThan(base.computeLuminance()));
    });

    testWidgets('dark: a step lighter than the ordinary scaffold', (
      tester,
    ) async {
      await _openPlayer(tester, ringDrillDarkTheme);

      final player = _playerScaffold(tester);
      final base = ringDrillDarkTheme.scaffoldBackgroundColor;
      expect(player, isNot(base));
      expect(player.computeLuminance(), greaterThan(base.computeLuminance()));
    });

    // Subtle on purpose: the player hosts the same screens the shell does, so a
    // strong shift would read as a different app rather than a different mode.
    //
    // Measured as a contrast *ratio*, not a luminance difference. Luminance is
    // perceptually non-linear, so the same 5% tint moves a bright surface's
    // luminance by 0.094 and a near-black one's by 0.011 — a difference bound
    // would call one of them wrong while both look like the same small step.
    // The ratio is how accessibility reasons about "just distinguishable", and it
    // comes out comparable across the two themes (~1.10 and ~1.15).
    testWidgets('the step is a hint in both themes', (tester) async {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final theme in [ringDrillTheme, ringDrillDarkTheme]) {
        final ratio = contrast(
          playerSurfaceColor(theme),
          theme.scaffoldBackgroundColor,
        );
        expect(ratio, greaterThan(1.02), reason: 'must be visible at all');
        expect(ratio, lessThan(1.3), reason: 'a hint, not a repaint');
      }
    });

    // The screens the player hosts also render in the shell and in sheets, where
    // the ordinary background is correct — so the shift belongs to the player,
    // not to them.
    testWidgets('outside the player the background is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ringDrillTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoordinatorScreen(uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(_playerScaffold(tester), ringDrillTheme.scaffoldBackgroundColor);
    });
  });

  group('close affordance', () {
    testWidgets('in the player it is a chevron-down, not an X', (tester) async {
      await _openPlayer(tester, ringDrillTheme);

      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('outside the player it stays an X', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ringDrillTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoordinatorScreen(uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('and it dismisses the player', (tester) async {
      await _openPlayer(tester, ringDrillTheme);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      expect(find.byType(CoordinatorScreen), findsNothing);
      expect(find.text('open player'), findsOneWidget);
    });
  });
}
