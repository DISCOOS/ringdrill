import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';

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

        await tester.enterText(find.byType(TextField), '/');
        await tester.pump();

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

        await tester.enterText(find.byType(TextField), '{{');
        await tester.pump();

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

      await tester.enterText(find.byType(TextField), '/frek');
      await tester.pump();

      expect(find.text('frekvens'), findsOneWidget);
      expect(find.text('Øvelsesnavn'), findsNothing);
    });

    testWidgets(
      'the "Opprett variabel" entry is hidden when onCreateVariable is null, '
      'even with a no-match filter',
      (tester) async {
        await _pump(tester, onCreateVariable: null);

        await tester.enterText(find.byType(TextField), '/zzz');
        await tester.pump();

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

        await tester.enterText(find.byType(TextField), '/zzz');
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final createLabel = l10n.tokenMenuCreateVariable('zzz');
        expect(find.text(createLabel), findsOneWidget);

        await tester.tap(find.text(createLabel));
        await tester.pump();

        expect(created, 'zzz');
        expect(controller.text, '{{var.zzz}}');
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
