import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/views/widgets/variable_overrides_section.dart';
import 'package:ringdrill/views/widgets/variable_value_field.dart';

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
    // The inherited default reads as a parenthesized value after the name
    // (DESIGN-008 follow-up 11, variable-overrides.html).
    expect(find.text('(Kanal 6)'), findsOneWidget);
    expect(
      find.textContaining('(—)'),
      findsNothing,
      reason: 'a declared-but-empty inherited value renders no parenthesis',
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

  testWidgets('the local-value field is accented only when overridden '
      '(DESIGN-008 follow-up 12)', (tester) async {
    await _pump(
      tester,
      variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      inherited: const {'frekvens': 'Kanal 6'},
      overrides: const {},
      onChanged: (_) {},
    );
    expect(
      tester.widget<VariableValueField>(find.byType(VariableValueField)).accent,
      isFalse,
      reason: 'inheriting (no local override) is not accented',
    );

    await _pump(
      tester,
      variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      inherited: const {'frekvens': 'Kanal 6'},
      overrides: const {'frekvens': 'Kanal 8'},
      onChanged: (_) {},
    );
    expect(
      tester.widget<VariableValueField>(find.byType(VariableValueField)).accent,
      isTrue,
      reason: 'a set local override is accented',
    );
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

  testWidgets(
    'the parenthesized inherited default is formatted per type — a time as '
    '12:00, a location as its UTM (DESIGN-008 follow-up 11)',
    (tester) async {
      await _pump(
        tester,
        variables: const [
          DrillVariable(name: 'tid', type: VariableType.time, value: '09:05'),
          DrillVariable(
            name: 'oppmote',
            type: VariableType.location,
            location: VariableLocation(position: LatLng(59.7445, 10.2045)),
          ),
        ],
        inherited: const {'tid': '09:05', 'oppmote': '59.744500,10.204500'},
        overrides: const {},
        onChanged: (_) {},
      );

      expect(find.text('(09:05)'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\(32V .+E .+N\)')), findsOneWidget);
    },
  );

  testWidgets('a typed local value is stored in its canonical encoding', (
    tester,
  ) async {
    Map<String, String>? captured;
    await _pump(
      tester,
      variables: const [
        DrillVariable(name: 'tid', type: VariableType.time, value: '09:05'),
      ],
      inherited: const {'tid': '09:05'},
      overrides: const {},
      onChanged: (updated) => captured = updated,
    );

    // A time field is picker-driven; drive the state through the widget's
    // own onChanged contract by tapping the picker and confirming.
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!['tid'], matches(RegExp(r'^\d{2}:\d{2}$')));
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
