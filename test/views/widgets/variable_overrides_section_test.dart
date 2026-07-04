import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/views/widgets/variable_overrides_section.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<DrillVariable> variables,
  required Map<String, String> inherited,
  required Map<String, String> overrides,
  required ValueChanged<Map<String, String>> onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VariableOverridesSection(
          variables: variables,
          inherited: inherited,
          overrides: overrides,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lists declared variables with their inherited value', (
    tester,
  ) async {
    await _pump(
      tester,
      variables: const [
        DrillVariable(name: 'frekvens', value: 'Kanal 6'),
        DrillVariable(name: 'sted'),
      ],
      inherited: const {'frekvens': 'Kanal 6', 'sted': ''},
      overrides: const {},
      onChanged: (_) {},
    );

    expect(find.text('frekvens'), findsOneWidget);
    expect(find.text('sted'), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.variableOverridesSectionInheritedValueLabel('Kanal 6')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.variableOverridesSectionInheritedValueLabel('—')),
      findsOneWidget,
      reason: 'a declared-but-empty inherited value shows as an em dash',
    );
  });

  testWidgets('seeds the local-value field from the current override', (
    tester,
  ) async {
    await _pump(
      tester,
      variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      inherited: const {'frekvens': 'Kanal 6'},
      overrides: const {'frekvens': 'Kanal 8'},
      onChanged: (_) {},
    );

    expect(find.text('Kanal 8'), findsOneWidget);
  });

  testWidgets('typing a local value calls onChanged with it set', (
    tester,
  ) async {
    Map<String, String>? captured;
    await _pump(
      tester,
      variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      inherited: const {'frekvens': 'Kanal 6'},
      overrides: const {},
      onChanged: (updated) => captured = updated,
    );

    await tester.enterText(find.byType(TextFormField), 'Kanal 9');
    expect(captured, {'frekvens': 'Kanal 9'});
  });

  testWidgets('clearing a local value calls onChanged with it inheriting', (
    tester,
  ) async {
    Map<String, String>? captured;
    await _pump(
      tester,
      variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      inherited: const {'frekvens': 'Kanal 6'},
      overrides: const {'frekvens': 'Kanal 8'},
      onChanged: (updated) => captured = updated,
    );

    await tester.enterText(find.byType(TextFormField), '');
    expect(captured, <String, String>{});
  });

  testWidgets('has no add/rename/delete affordance', (tester) async {
    await _pump(
      tester,
      variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      inherited: const {'frekvens': 'Kanal 6'},
      overrides: const {},
      onChanged: (_) {},
    );

    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('shows the empty state when the plan has no variables', (
    tester,
  ) async {
    await _pump(
      tester,
      variables: const [],
      inherited: const {},
      overrides: const {},
      onChanged: (_) {},
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.variableOverridesSectionEmptyState), findsOneWidget);
  });
}
