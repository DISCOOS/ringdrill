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

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Hilde er hovedpersonen'), findsOneWidget);
      // The section's own label stays visible — preview only swaps the
      // editable content for resolved text, not the field's chrome — and
      // sits directly above the resolved text, both flush left at (near)
      // the same x — not offset by BriefMarkdown's own brief-page gutter (a
      // 24px mismatch a looser tolerance here would miss entirely). Before
      // the fix, the resolved text (short) shrink-wrapped and Align
      // centered it well to the right of the label. `.last`: the wide
      // rail's own tile also shows this same label text.
      final labelLeft = tester.getTopLeft(find.text(l.roleBackground).last).dx;
      final contentLeft = tester
          .getTopLeft(
            find.descendant(
              of: find.byType(BriefMarkdown),
              matching: find.textContaining('Hilde er hovedpersonen'),
            ),
          )
          .dx;
      expect(contentLeft, closeTo(labelLeft, 2));
    },
  );
}
