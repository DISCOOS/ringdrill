import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget field, {
  List<DrillVariable>? scopeVariables,
}) {
  final home = scopeVariables == null
      ? field
      : PlanScope(variables: scopeVariables, child: field);
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
}

Color? _chipColor(WidgetTester tester, String token) {
  final editableFinder = find.byType(EditableText);
  final controller =
      tester.widget<EditableText>(editableFinder).controller
          as TokenTextEditingController;
  final span = controller.buildTextSpan(
    context: tester.element(editableFinder),
    style: const TextStyle(),
    withComposing: false,
  );
  Color? found;
  span.visitChildren((child) {
    if (child is TextSpan && child.text == token) {
      found = child.style?.color;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  group('RingDrillTextArea — tokenAware: false (legacy, default)', () {
    testWidgets('renders a plain field with no insertion menu', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'plain markdown');
      await _pump(
        tester,
        RingDrillTextArea(controller: controller, label: 'Intro'),
      );

      expect(find.text('plain markdown'), findsOneWidget);
      expect(find.byType(TokenInsertionMenu), findsNothing);

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller, same(controller));
    });

    testWidgets('typing "/" does not open a menu', (tester) async {
      final controller = TextEditingController();
      await _pump(
        tester,
        RingDrillTextArea(controller: controller, label: 'Intro'),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      expect(find.byType(TokenInsertionMenu), findsNothing);
    });
  });

  group('RingDrillTextArea — tokenAware: true', () {
    testWidgets(
      'renders chips resolved from PlanScope, not an explicit variables list',
      (tester) async {
        final controller = TokenTextEditingController(
          text: 'Kanal {{var.frekvens}}',
        );
        await _pump(
          tester,
          RingDrillTextArea(
            controller: controller,
            label: 'Comms',
            tokenAware: true,
          ),
          scopeVariables: const [
            DrillVariable(name: 'frekvens', value: 'Kanal 6'),
          ],
        );

        expect(find.byType(TokenInsertionMenu), findsOneWidget);
        expect(find.text('Kanal {{var.frekvens}}'), findsOneWidget);
        expect(_chipColor(tester, '{{var.frekvens}}'), Colors.blue.shade800);
      },
    );

    testWidgets(
      'a variable added to the scope re-resolves an amber chip to blue on rebuild',
      (tester) async {
        final controller = TokenTextEditingController(
          text: '{{var.frekvens}}',
        );

        Widget host(List<DrillVariable> variables) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlanScope(
              variables: variables,
              child: RingDrillTextArea(
                controller: controller,
                label: 'Comms',
                tokenAware: true,
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          host(const [DrillVariable(name: 'frekvens')]),
        );
        expect(_chipColor(tester, '{{var.frekvens}}'), Colors.amber.shade900);

        await tester.pumpWidget(
          host(const [DrillVariable(name: 'frekvens', value: 'Kanal 6')]),
        );
        expect(_chipColor(tester, '{{var.frekvens}}'), Colors.blue.shade800);
      },
    );

    testWidgets('overrides shadow the declared value', (tester) async {
      final controller = TokenTextEditingController(
        text: '{{var.frekvens}}',
      );
      await _pump(
        tester,
        RingDrillTextArea(
          controller: controller,
          label: 'Comms',
          tokenAware: true,
          overrides: const {'frekvens': 'Kanal 8'},
        ),
        scopeVariables: const [
          DrillVariable(name: 'frekvens', value: 'Kanal 6'),
        ],
      );

      expect(_chipColor(tester, '{{var.frekvens}}'), Colors.blue.shade800);
      final editableFinder = find.byType(EditableText);
      final resolvedController =
          tester.widget<EditableText>(editableFinder).controller
              as TokenTextEditingController;
      expect(resolvedController.variables.single.effectiveValue, 'Kanal 8');
    });
  });

  group('RingDrillTextField — tokenAware: false (legacy, default)', () {
    testWidgets('renders a plain single-line field with no insertion menu', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Vinterøvelse');
      await _pump(
        tester,
        RingDrillTextField(controller: controller, label: 'Navn'),
      );

      expect(find.text('Vinterøvelse'), findsOneWidget);
      expect(find.byType(TokenInsertionMenu), findsNothing);
    });
  });

  group('RingDrillTextField — tokenAware: true', () {
    testWidgets('renders chips resolved from PlanScope', (tester) async {
      final controller = TokenTextEditingController(
        text: '{{var.frekvens}}',
      );
      await _pump(
        tester,
        RingDrillTextField(
          controller: controller,
          label: 'Navn',
          tokenAware: true,
        ),
        scopeVariables: const [
          DrillVariable(name: 'frekvens', value: 'Kanal 6'),
        ],
      );

      expect(find.byType(TokenInsertionMenu), findsOneWidget);
      expect(_chipColor(tester, '{{var.frekvens}}'), Colors.blue.shade800);
    });
  });
}
