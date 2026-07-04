import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_form_screen.dart';

/// DESIGN-008 follow-up 09 — the name field is now token-aware
/// (`RingDrillTextField(tokenAware: true)`): the slash menu inserts a
/// declared variable, and save-time validation extends to the name field
/// the same way it already covers the markdown sections.

Program _program({List<DrillVariable> variables = const []}) {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: 'pgm-name-vars',
    name: 'Vinterøvelse',
    description: '',
    metadata: ProgramMetadata(
      created: now,
      updated: now,
      version: '1.1',
      languageCode: 'nb',
    ),
    teams: const [],
    sessions: const [],
    exercises: const [],
    variables: variables,
  );
}

class _Captured {
  Program? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Program program,
  _Captured captured,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<Program>(
              ctx,
              MaterialPageRoute(
                builder: (_) => ProgramFormScreen(program: program),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'the name field accepts a slash-inserted declared variable and saves it',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _program(
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        ),
        captured,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, l.programName),
        'Plan /frek',
      );
      await tester.pump();
      await tester.pump();

      // An existing declared variable's suggestion tile shows its name —
      // distinct from the "create new" entry, which prefixes a localized
      // verb instead.
      await tester.tap(find.text('frekvens').last);
      await tester.pump();

      expect(find.textContaining('{{var.frekvens}}'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.name, 'Plan {{var.frekvens}}');
    },
  );

  testWidgets(
    'save is blocked on an undeclared token in the name; removing it unblocks save',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _program(), captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.programName),
        'Plan {{var.mangler}}',
      );
      await tester.pump();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(l.programSaveBlockedUndeclaredVariable(l.programName)),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, l.programName),
        'Plan uten variabel',
      );
      await tester.pump();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.name, 'Plan uten variabel');
    },
  );
}
