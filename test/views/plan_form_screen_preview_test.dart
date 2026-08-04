import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/views/plan_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 — the per-section preview eye on `PlanFormScreen`'s markdown
/// sections. It was disabled on *every* section here, because the plan editor
/// was the one section-navigated editor that never passed
/// `FormSection.preview`/`onPreviewChanged`, and `SectionNavigatedForm`
/// disables the toggle for a null `preview`.
Plan _plan({String? briefIntroMd, List<DrillVariable> variables = const []}) {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: 'pgm-1',
    name: 'Vinterøvelse',
    description: '',
    metadata: PlanMetadata(
      created: now,
      updated: now,
      version: '1.0',
      languageCode: 'nb',
    ),
    teams: const [],
    sessions: const [],
    exercises: const [],
    variables: variables,
    briefIntroMd: briefIntroMd,
  );
}

void main() {
  testWidgets(
    "the markdown section's preview eye is enabled, and previewing resolves "
    'the section through the field resolver',
    (tester) async {
      // Wide, so the section rail selects sections directly.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlanFormScreen(
            plan: _plan(
              // A {{var.*}} reference, so the check exercises real resolution
              // rather than static text.
              briefIntroMd: 'Øvelsen ledes av {{var.leader}}',
              variables: const [DrillVariable(name: 'leader', value: 'Hilde')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l.briefSectionPlanIntro).first);
      await tester.pumpAndSettle();

      // The toggle offers "preview" (not a disabled, tooltip-less icon).
      final toggle = find.byTooltip(l.formSectionPreviewAction);
      expect(toggle, findsOneWidget);
      // `byTooltip` matches the tooltip IconButton builds around its child,
      // so the button itself is the ancestor.
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: toggle, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Øvelsen ledes av Hilde'), findsOneWidget);
      expect(find.textContaining('{{var.'), findsNothing);

      // ...and back to the editable field, with the token literal again.
      await tester.tap(find.byTooltip(l.formSectionEditAction));
      await tester.pumpAndSettle();
      expect(find.byType(BriefMarkdown), findsNothing);
      expect(find.textContaining('{{var.leader}}'), findsOneWidget);
    },
  );

  testWidgets('preview state is remembered per section, not editor-wide', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 1, 1);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlanFormScreen(
          plan: Plan(
            uuid: 'pgm-2',
            name: 'Vinterøvelse',
            description: '',
            metadata: PlanMetadata(
              created: now,
              updated: now,
              version: '1.0',
              languageCode: 'nb',
            ),
            teams: const [],
            sessions: const [],
            exercises: const [],
            briefIntroMd: 'intro-tekst',
            commsMd: 'samband-tekst',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l.briefSectionPlanIntro).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.formSectionPreviewAction));
    await tester.pumpAndSettle();

    // Samband is untouched: still offering "preview", not "edit".
    await tester.tap(find.text(l.briefSectionPlanComms).first);
    await tester.pumpAndSettle();
    expect(find.byTooltip(l.formSectionPreviewAction), findsOneWidget);

    // Coming back to the intro, its own preview is still on.
    await tester.tap(find.text(l.briefSectionPlanIntro).first);
    await tester.pumpAndSettle();
    expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);
  });
}
