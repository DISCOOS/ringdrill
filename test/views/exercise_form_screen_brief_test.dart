import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

Exercise _exerciseWithMethod() => Exercise(
  uuid: 'ex-brief-1',
  name: 'Brief øvelse',
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
  methodMd: 'Gruppevis øving utendørs',
);

void main() {
  testWidgets('seeded brief section survives a save round-trip', (tester) async {
    Exercise? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Exercise>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ExerciseFormScreen(
                    exercise: _exerciseWithMethod(),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The Method section is seeded as active and shows the existing value.
    expect(find.text('Gruppevis øving utendørs'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, l10n.briefSectionExerciseMethod),
      findsNothing,
    );

    // Replace the method content and save.
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.briefSectionExerciseMethod),
      'Skogsøving',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.methodMd, 'Skogsøving');
    // Other brief fields stay null because we never added their sections.
    expect(captured!.learningGoalsMd, isNull);
    expect(captured!.commsMd, isNull);
  });

  testWidgets('removing a seeded brief section clears its value on save', (
    tester,
  ) async {
    Exercise? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Exercise>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ExerciseFormScreen(
                    exercise: _exerciseWithMethod(),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Remove the seeded Method section via its suffix close button. The
    // AppBar leading also uses Icons.close, so scope to the Form subtree.
    await tester.tap(
      find.descendant(of: find.byType(Form), matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.methodMd, isNull);
  });
}
