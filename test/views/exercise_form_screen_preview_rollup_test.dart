import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 stage 2 — the per-section preview toggle (remembered per
/// section across a switch) and the default-section rollup (lists active
/// sections resolved, tap-to-edit), exercised end to end through the real
/// ExerciseFormScreen/SectionNavigatedForm rather than a bespoke harness.
Exercise _exerciseWithMethod() => Exercise(
  uuid: 'ex-preview-1',
  name: 'Exercise 1',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
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
  // Contains a {{var.name}} reference so the preview/rollup can be checked
  // against a resolved value, not just literal text.
  methodMd: 'Method for {{var.name}}',
);

Future<AppLocalizations> _pumpWideEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExerciseFormScreen(
        exercise: _exerciseWithMethod(),
        variables: const [DrillVariable(name: 'name', value: 'World')],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets(
    'the preview toggle switches a section to resolved markdown and back, '
    'remembered across a section switch',
    (tester) async {
      final l = await _pumpWideEditor(tester);

      // Switch to the "Method" section via the wide rail.
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l.formSectionPreviewAction), findsOneWidget);
      expect(find.byType(BriefMarkdown), findsNothing);

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Method for World'), findsOneWidget);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);

      // Switch away to the default section and back — the preview state is
      // remembered per section within the session (DESIGN-010).
      await tester.tap(find.text(l.exercise(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);

      // Toggling back to edit restores the editable chip field.
      await tester.tap(find.byTooltip(l.formSectionEditAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsNothing);
      expect(find.byTooltip(l.formSectionPreviewAction), findsOneWidget);
    },
  );

  testWidgets(
    'the preview toggle is disabled on the default (non-previewable) section',
    (tester) async {
      await _pumpWideEditor(tester);

      final toggle = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.visibility_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(toggle.onPressed, isNull);
      expect(toggle.tooltip, isNull);
    },
  );

  testWidgets(
    'the rollup lists the active section resolved, and tapping it navigates '
    'to that section in the switcher (tap-to-edit)',
    (tester) async {
      final l = await _pumpWideEditor(tester);

      // The rollup toggle lives on the default section, which is where the
      // editor opens.
      expect(find.text(l.rollupShowAction), findsOneWidget);
      await tester.tap(find.text(l.rollupShowAction));
      await tester.pumpAndSettle();

      expect(find.text(l.rollupHideAction), findsOneWidget);
      expect(find.textContaining('Method for World'), findsOneWidget);

      // Still on the default section — its own name field is visible.
      expect(
        find.widgetWithText(TextFormField, l.exerciseName),
        findsOneWidget,
      );

      // Tapping the rendered block jumps to the Method section: the
      // detail pane now shows Method's own body (no longer the default
      // section's structural fields), and the rail highlights Method.
      await tester.tap(find.textContaining('Method for World'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, l.exerciseName), findsNothing);
      final methodTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text(l.briefSectionExerciseMethod),
          matching: find.byType(ListTile),
        ),
      );
      expect(methodTile.selected, isTrue);
    },
  );

  testWidgets('narrow renders the rollup as an inline continuation below the '
      'structural fields, in one scroll, with no layout exception', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExerciseFormScreen(
          exercise: _exerciseWithMethod(),
          variables: const [DrillVariable(name: 'name', value: 'World')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l.rollupShowAction));
    await tester.pumpAndSettle();

    // No rail on narrow — both the structural field and the resolved
    // rollup content coexist in the same (single) scrollable body.
    expect(find.byType(ListTile), findsNothing);
    expect(find.widgetWithText(TextFormField, l.exerciseName), findsOneWidget);
    expect(find.textContaining('Method for World'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
