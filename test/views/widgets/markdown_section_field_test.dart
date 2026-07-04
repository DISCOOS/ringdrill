import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/markdown_section_field.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';

Future<void> _pump(WidgetTester tester, Widget field) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: field),
    ),
  );
}

void main() {
  group('MarkdownSectionField — tokenAware: false (legacy, default)', () {
    testWidgets('renders a plain field with no insertion menu', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'plain markdown');
      await _pump(
        tester,
        MarkdownSectionField(controller: controller, label: 'Intro'),
      );

      expect(find.text('plain markdown'), findsOneWidget);
      expect(find.byType(TokenInsertionMenu), findsNothing);

      // The field edits the caller's own controller directly — no
      // TokenTextEditingController swapped in underneath it.
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller, same(controller));
    });

    testWidgets('typing "/" does not open a menu', (tester) async {
      final controller = TextEditingController();
      await _pump(
        tester,
        MarkdownSectionField(controller: controller, label: 'Intro'),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      expect(find.byType(TokenInsertionMenu), findsNothing);
    });
  });

  group('MarkdownSectionField — tokenAware: true', () {
    testWidgets(
      'wraps the field in a TokenInsertionMenu and mirrors edits back into the owned controller',
      (tester) async {
        final owned = TextEditingController(text: 'Kanal {{var.frekvens}}');
        await _pump(
          tester,
          MarkdownSectionField(
            controller: owned,
            label: 'Comms',
            tokenAware: true,
            variables: const [
              VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
            ],
          ),
        );

        expect(find.byType(TokenInsertionMenu), findsOneWidget);
        // Seeded text renders (raw, chip styling aside).
        expect(find.text('Kanal {{var.frekvens}}'), findsOneWidget);

        await tester.tap(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'Kanal {{var.frekvens}} ekstra',
        );
        await tester.pump();

        // The owned controller (what the form's _save reads) sees the edit.
        expect(owned.text, 'Kanal {{var.frekvens}} ekstra');
      },
    );

    testWidgets('slash menu opens and inserts through the wired field', (
      tester,
    ) async {
      final owned = TextEditingController();
      await _pump(
        tester,
        MarkdownSectionField(
          controller: owned,
          label: 'Comms',
          tokenAware: true,
          variables: const [
            VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
          ],
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '/');
      // The menu opens via a post-frame callback (caret position is only
      // read once RenderEditable has relaid out for the new text), and
      // inserting the OverlayEntry schedules its first real build for the
      // next frame after that — two pumps, not one.
      await tester.pump();
      await tester.pump();

      expect(find.text('frekvens'), findsOneWidget);
      await tester.tap(find.text('frekvens'));
      await tester.pump();

      expect(owned.text, '{{var.frekvens}}');
    });
  });
}
