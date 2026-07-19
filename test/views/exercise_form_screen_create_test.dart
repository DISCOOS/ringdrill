import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

import 'support/save_roundtrip_harness.dart';

/// Create path (the "add exercise" button → blank [ExerciseFormScreen] → save):
/// the add caller must apply the popped [ExerciseFormSave] to the service so
/// the new exercise lands in the active plan's list. The blank form defaults
/// every numeric field (teams/stations/rounds/times) and the start time, so a
/// bare name is enough to save.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => initActivePlan('Create plan'));
  tearDown(() => ProgramService().clearAllForTest());

  testWidgets(
    'creating a new exercise from a blank form persists it in the active '
    'plan list',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                final result = await Navigator.push<ExerciseFormSave>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const ExerciseFormScreen(),
                  ),
                );
                if (result != null) {
                  await ProgramService().saveExercise(l10n, result.exercise);
                }
              },
              child: const Text('New'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      // A brand-new form has no delete action and defaults all counters.
      expect(find.byIcon(Icons.delete), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.exerciseName),
        'Fresh exercise',
      );
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      final names = ProgramService().loadExercises().map((e) => e.name);
      expect(names, contains('Fresh exercise'));
    },
  );
}
