import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<DrillVariable>? scopeVariables,
}) {
  final home = scopeVariables == null
      ? child
      : PlanScope(variables: scopeVariables, child: child);
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: home)));
}

void main() {
  testWidgets('with no PlanScope ancestor, renders the raw text', (
    tester,
  ) async {
    await _pump(tester, const RingDrillText('Kanal {{var.frekvens}}'));

    expect(find.text('Kanal {{var.frekvens}}'), findsOneWidget);
  });

  testWidgets('resolves a declared variable from PlanScope', (tester) async {
    await _pump(
      tester,
      const RingDrillText('Kanal {{var.frekvens}}'),
      scopeVariables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
    );

    expect(find.text('Kanal Kanal 6'), findsOneWidget);
    expect(find.text('Kanal {{var.frekvens}}'), findsNothing);
  });

  testWidgets('an undeclared token is left raw, not a throw', (tester) async {
    await _pump(
      tester,
      const RingDrillText('Kanal {{var.mangler}}'),
      scopeVariables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
    );

    expect(find.text('Kanal {{var.mangler}}'), findsOneWidget);
  });

  testWidgets('overrides shadow the declared value', (tester) async {
    await _pump(
      tester,
      const RingDrillText(
        'Kanal {{var.frekvens}}',
        overrides: {'frekvens': 'Kanal 9'},
      ),
      scopeVariables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
    );

    expect(find.text('Kanal Kanal 9'), findsOneWidget);
  });

  testWidgets('passes through Text styling params', (tester) async {
    await _pump(
      tester,
      const RingDrillText(
        'plain',
        style: TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final text = tester.widget<Text>(find.text('plain'));
    expect(text.style?.fontWeight, FontWeight.bold);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
