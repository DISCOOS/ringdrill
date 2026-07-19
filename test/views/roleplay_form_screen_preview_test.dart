import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 stage 2 fix — the per-section preview eye on the roleplay
/// editor's "Bakgrunn"/"Background" section (which, unlike the exercise
/// editor's addable sections, passes its own `label`) must keep showing
/// that label in preview, and the resolved text must sit flush left, not
/// centered — the two regressions the user's own screenshots caught.
Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [Station(index: 0, name: 'Post 1')],
  schedule: const [],
);

RolePlay _rolePlay() => RolePlay(
  uuid: 'rp-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Hilde',
  // Contains a {{var.*}} reference so the check exercises real resolution,
  // not just static text.
  background: '{{var.name}} er hovedpersonen',
  stationIndex: 0,
);

void main() {
  testWidgets(
    'the Bakgrunn/Background section keeps its label in preview, and the '
    'resolved text sits flush left, not centered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RolePlayFormScreen(
            rolePlay: _rolePlay(),
            exercise: _exercise(),
            variables: const [DrillVariable(name: 'name', value: 'Hilde')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      // Switch to the Background section via the wide rail.
      await tester.tap(find.text(l.roleBackground));
      await tester.pumpAndSettle();

      // Captured before toggling: the label and the input text's own
      // position in edit mode — `.last`: the wide rail's own tile also
      // shows this same label text, and comes first in the tree.
      final labelRectEdit = tester.getRect(find.text(l.roleBackground).last);
      final inputRectEdit = tester.getRect(find.textContaining('{{var.name}}'));

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Hilde er hovedpersonen'), findsOneWidget);
      // The section's own label stays visible — preview only swaps the
      // editable content for resolved text, not the field's chrome — and
      // does not move at all: InputDecorator positions it identically
      // whether its child is the editable field or the read-only preview.
      // Before this fix, a hand-built caption above the resolved text could
      // not match TextFormField's own label position pixel-for-pixel.
      final labelRectPreview = tester.getRect(find.text(l.roleBackground).last);
      expect(labelRectPreview, labelRectEdit);
      // The resolved text starts at exactly the same position the typed
      // text (with its still-literal {{var.name}} token) occupied — the
      // *only* thing that changed is what that position now shows.
      final contentRectPreview = tester.getRect(
        find.descendant(
          of: find.byType(BriefMarkdown),
          matching: find.textContaining('Hilde er hovedpersonen'),
        ),
      );
      expect(contentRectPreview.topLeft, inputRectEdit.topLeft);
    },
  );

  testWidgets(
    'a markdown section preview resolves {{roleplay.name}} from the live '
    'identity (RoleplayScope wraps the whole form)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RolePlayFormScreen(
            rolePlay: RolePlay(
              uuid: 'rp-role',
              index: 0,
              exerciseUuid: 'ex-1',
              name: 'Hilde',
              background: 'Markøren heter {{roleplay.name}}',
              stationIndex: 0,
            ),
            exercise: _exercise(),
            variables: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l.roleBackground));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      expect(find.textContaining('{{roleplay.'), findsNothing);
      expect(find.textContaining('Markøren heter Hilde'), findsOneWidget);
    },
  );

  testWidgets(
    'a section preview resolves co-occurring {{roleplay.*}} and '
    '{{exercise.*}} tokens together — a missing scope for one must not drag '
    'the whole field back to literal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RolePlayFormScreen(
            rolePlay: RolePlay(
              uuid: 'rp-both',
              index: 0,
              exerciseUuid: 'ex-1',
              name: 'Hilde',
              // The exact shape the manual test caught: one roleplay token
              // (scope present) and one exercise token (scope was missing in
              // the editor). The resolver's mustache pass is all-or-nothing
              // per field, so before the ExerciseScope fix the unresolved
              // {{exercise.*}} threw and left *both* literal.
              background: 'Markøren heter {{roleplay.name}}. Det er totalt '
                  '{{exercise.numberOfTeams}} lag.',
              stationIndex: 0,
            ),
            exercise: _exercise(),
            variables: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l.roleBackground));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      // No token of any kind is left literal.
      expect(find.textContaining('{{'), findsNothing);
      // _exercise() declares numberOfTeams: 1.
      expect(
        find.textContaining('Markøren heter Hilde. Det er totalt 1 lag.'),
        findsOneWidget,
      );
    },
  );
}
