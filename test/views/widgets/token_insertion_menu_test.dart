import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';

/// Types [text] (typically ending in a trigger) and pumps twice: the menu
/// opens via a post-frame callback (deferred so the caret position is read
/// only after `RenderEditable` has relaid out for the new text — see
/// `TokenInsertionMenuState._onChanged`), and inserting the resulting
/// `OverlayEntry` itself only schedules its first real build for the frame
/// after that.
Future<void> _typeAndOpen(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.pump();
}

Future<TextEditingController> _pump(
  WidgetTester tester, {
  ValueChanged<String>? onCreateVariable,
}) async {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TokenInsertionMenu(
          controller: controller,
          focusNode: focusNode,
          variables: const [
            VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
          ],
          planFields: const [
            PlanFieldToken(name: 'exercise.name', label: 'Øvelsesnavn'),
          ],
          onCreateVariable: onCreateVariable,
          child: TextField(controller: controller, focusNode: focusNode),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pump();
  return controller;
}

void main() {
  group('TokenInsertionMenu', () {
    testWidgets(
      '"/" opens the menu with the flat variable + plan-field list; selecting inserts and closes',
      (tester) async {
        final controller = await _pump(tester);

        await _typeAndOpen(tester, '/');

        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsOneWidget);

        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(controller.text, '{{var.frekvens}}');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      '"{{" opens the same picker directly; selecting a plan field inserts a bare cross-reference',
      (tester) async {
        final controller = await _pump(tester);

        await _typeAndOpen(tester, '{{');

        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsOneWidget);

        await tester.tap(find.text('Øvelsesnavn'));
        await tester.pump();

        expect(controller.text, '{{exercise.name}}');
      },
    );

    testWidgets('filters the flat list as the user types after the trigger', (
      tester,
    ) async {
      await _pump(tester);

      await _typeAndOpen(tester, '/frek');

      expect(find.text('frekvens'), findsOneWidget);
      expect(find.text('Øvelsesnavn'), findsNothing);
    });

    testWidgets(
      'typing "{{var." keeps the menu open across the dot and narrows to '
      'variables, filtering by the name after the prefix '
      '(regression: the dot used to fall outside the trigger filter and '
      'close the menu immediately)',
      (tester) async {
        await _pump(tester);

        await _typeAndOpen(tester, '{{var');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isTrue,
        );

        // The dot must not close the menu.
        await _typeAndOpen(tester, '{{var.');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isTrue,
        );
        // "var." is the namespace prefix, not a name to match — narrows to
        // variables (no plan fields) rather than showing "no matches".
        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsNothing);

        // Filters the variable list by what comes after the prefix.
        await _typeAndOpen(tester, '{{var.frek');
        expect(find.text('frekvens'), findsOneWidget);

        await _typeAndOpen(tester, '{{var.zzz');
        expect(find.text('frekvens'), findsNothing);

        // Closing the token (typing "}") ends the trigger.
        await tester.enterText(find.byType(TextField), '{{var.frekvens}}');
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      'the "Opprett variabel" entry is hidden when onCreateVariable is null, '
      'even with a no-match filter',
      (tester) async {
        await _pump(tester, onCreateVariable: null);

        await _typeAndOpen(tester, '/zzz');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.tokenMenuEmpty), findsOneWidget);
        expect(find.textContaining(l10n.tokenMenuCreateVariable('zzz')), findsNothing);
      },
    );

    testWidgets(
      'the "Opprett variabel" entry appears with a no-match filter once a '
      'callback is supplied, and invokes it on selection',
      (tester) async {
        String? created;
        final controller = await _pump(
          tester,
          onCreateVariable: (name) => created = name,
        );

        await _typeAndOpen(tester, '/zzz');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final createLabel = l10n.tokenMenuCreateVariable('zzz');
        expect(find.text(createLabel), findsOneWidget);

        await tester.tap(find.text(createLabel));
        await tester.pump();

        expect(created, 'zzz');
        expect(controller.text, '{{var.zzz}}');
      },
    );

    testWidgets(
      'typing "{{var.zzz" offers "Opprett variabel «zzz»", using the name '
      'after the prefix rather than the literal "var.zzz"',
      (tester) async {
        String? created;
        final controller = await _pump(
          tester,
          onCreateVariable: (name) => created = name,
        );

        await _typeAndOpen(tester, '{{var.zzz');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final createLabel = l10n.tokenMenuCreateVariable('zzz');
        expect(find.text(createLabel), findsOneWidget);

        await tester.tap(find.text(createLabel));
        await tester.pump();

        expect(created, 'zzz');
        expect(controller.text, '{{var.zzz}}');
      },
    );

    testWidgets(
      'anchors near the caret, not at the bottom of a full-screen field '
      '(regression: MarkdownSectionField sections use expands: true, so the '
      'field itself can be the height of the whole screen)',
      (tester) async {
        final controller = TextEditingController(text: '\n\n\n/');
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TokenInsertionMenu(
                controller: controller,
                focusNode: focusNode,
                variables: const [
                  VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
                ],
                // Fills the whole Scaffold body, like a section-navigated
                // markdown field does (MarkdownSectionField's `expands`).
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        // Moves the caret onto the trailing "/" and fires _onChanged (the
        // seed text was set before any listener was attached, so it never
        // ran the trigger detection on its own).
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        await tester.pump();
        await tester.pump();

        final screenHeight = tester.view.physicalSize.height /
            tester.view.devicePixelRatio;
        final positioned = tester.widgetList<Positioned>(find.byType(Positioned));
        final menuPositioned = positioned.firstWhere((p) => p.width != null);

        // The caret sits on the field's 4th line, near the top of an
        // 800-tall test viewport — the menu must anchor there, not at
        // (near) the bottom of the screen.
        expect(menuPositioned.top, isNotNull);
        expect(menuPositioned.top!, lessThan(screenHeight / 2));
      },
    );

    testWidgets('dismisses on Escape', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();
      expect(
        tester
            .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
            .isMenuOpen,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(
        tester
            .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
            .isMenuOpen,
        isFalse,
      );
    });
  });
}
