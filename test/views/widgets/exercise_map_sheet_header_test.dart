import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/widgets/exercise_mini_map.dart';

/// Regression guard: `ExerciseMapSheetHeader` used to compute its own
/// `#<exerciseNumber>` prefix and prepend it to `exercise.name` — but
/// every other place in the app (`coordinator_screen.dart`'s own AppBar,
/// `_MapSheetHeader`/`_RoleMapSheetHeader`'s exercise subtitle) renders
/// `exercise.name` as-is, since plan authors already bake their own
/// numbering convention into the name (e.g. "#1 Søk og redning"). The
/// computed prefix duplicated it — "#1 #1 Søk og redning" — first
/// noticed once `MapView.withFullscreen` made this header visible from
/// the coordinator's own inline exercise map.
void main() {
  testWidgets(
    'renders exercise.name as-is, with no computed number prefix',
    (tester) async {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: '#1 Søk og redning (ringøvelse)',
        startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
        endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: ExerciseMapSheetHeader(exercise: exercise),
          ),
        ),
      );

      expect(find.text('#1 Søk og redning (ringøvelse)'), findsOneWidget);
      expect(
        find.text('#1 #1 Søk og redning (ringøvelse)'),
        findsNothing,
      );
    },
  );
}
