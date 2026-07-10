import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// DESIGN-010 stage 2 — the per-section preview toggle's field-level
/// rendering: RingDrillTextArea/RingDrillTextField switch between the
/// editable chip field and the resolved read-only display, live with a
/// debounce.
final _vars = [const DrillVariable(name: 'name', value: 'World')];

Widget _harness(Widget field) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: PlanScope(variables: _vars, child: field),
  ),
);

void main() {
  group('RingDrillTextArea preview', () {
    testWidgets(
      'preview: false renders the editable field, not BriefMarkdown',
      (tester) async {
        final controller = TokenTextEditingController(
          text: 'Hello {{var.name}}',
        );
        await tester.pumpWidget(
          _harness(RingDrillTextArea(controller: controller, tokenAware: true)),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byType(BriefMarkdown), findsNothing);
      },
    );

    testWidgets('preview: true renders the resolved text via BriefMarkdown', (
      tester,
    ) async {
      final controller = TokenTextEditingController(text: 'Hello {{var.name}}');
      await tester.pumpWidget(
        _harness(
          RingDrillTextArea(
            controller: controller,
            tokenAware: true,
            preview: true,
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Hello World'), findsOneWidget);
    });

    testWidgets(
      'live: editing the controller while previewing updates the resolved '
      'text after the debounce',
      (tester) async {
        final controller = TokenTextEditingController(
          text: 'Hello {{var.name}}',
        );
        await tester.pumpWidget(
          _harness(
            RingDrillTextArea(
              controller: controller,
              tokenAware: true,
              preview: true,
            ),
          ),
        );
        expect(find.textContaining('Hello World'), findsOneWidget);

        controller.text = 'Goodbye {{var.name}}';
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.textContaining('Goodbye World'), findsOneWidget);
        expect(find.textContaining('Hello World'), findsNothing);
      },
    );

    testWidgets('an empty resolved result renders nothing', (tester) async {
      final controller = TokenTextEditingController(text: '');
      await tester.pumpWidget(
        _harness(
          RingDrillTextArea(
            controller: controller,
            tokenAware: true,
            preview: true,
          ),
        ),
      );

      expect(find.byType(BriefMarkdown), findsNothing);
    });
  });

  group('RingDrillTextField preview', () {
    testWidgets(
      'preview: true renders resolved plain Text, not BriefMarkdown',
      (tester) async {
        final controller = TokenTextEditingController(text: 'Hi {{var.name}}');
        await tester.pumpWidget(
          _harness(
            RingDrillTextField(
              controller: controller,
              label: 'Name',
              tokenAware: true,
              preview: true,
            ),
          ),
        );

        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(BriefMarkdown), findsNothing);
        expect(find.text('Hi World'), findsOneWidget);
      },
    );
  });
}
