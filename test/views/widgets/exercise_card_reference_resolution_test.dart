import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';

/// Regression: the expanded ExerciseCard's ExerciseDescriptionRollup renders
/// each markdown field via RingDrillText.rich, which resolves `{{exercise.*}}`
/// cross-references through an ancestor ExerciseScope (ADR-0048) — but
/// `_buildExpandedBody` used to wrap only the station rows in their own
/// StationScope, with no ExerciseScope around the rollup itself, so
/// `{{exercise.numberOfRounds}}` (and friends) stayed a literal token there.
/// program_view.dart now wraps the whole expanded body in one ExerciseScope.
Exercise _exercise() => Exercise(
  uuid: 'exercise-card-ref',
  name: 'Reference exercise',
  startTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 11, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 4,
  executionTime: 45,
  evaluationTime: 10,
  rotationTime: 5,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [[]],
  methodMd: 'This exercise runs {{exercise.numberOfRounds}} rounds.',
);

void main() {
  testWidgets(
    'the expanded ExerciseCard resolves {{exercise.numberOfRounds}} in its '
    'ExerciseDescriptionRollup',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlanScope(
            variables: const [],
            child: Scaffold(
              body: Builder(
                builder: (context) => ExerciseCard(
                  exercise: _exercise(),
                  localizations: AppLocalizations.of(context)!,
                  markers: const [],
                  expanded: true,
                  onOpen: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('{{exercise.numberOfRounds}}'),
        findsNothing,
      );
      expect(
        find.textContaining('This exercise runs 4 rounds.'),
        findsOneWidget,
      );
    },
  );
}
