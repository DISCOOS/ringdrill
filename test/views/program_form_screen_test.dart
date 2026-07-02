import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_form_screen.dart';

Program _baseProgram({
  String name = 'Vinterøvelse',
  String description = '',
  String? briefIntroMd,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: 'pgm-1',
    name: name,
    description: description,
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    briefIntroMd: briefIntroMd,
  );
}

Future<Program?> _openForm(WidgetTester tester, Program program) async {
  Program? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await Navigator.push<Program>(
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
  return result;
}

void main() {
  testWidgets('renders base fields with seeded values', (tester) async {
    await _openForm(
      tester,
      _baseProgram(description: 'En kjent rute'),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.programName), findsOneWidget);
    expect(find.text(l10n.programDescription), findsOneWidget);
    expect(find.text('Vinterøvelse'), findsOneWidget);
    expect(find.text('En kjent rute'), findsOneWidget);
  });

  testWidgets('shows add buttons for missing optional sections', (
    tester,
  ) async {
    await _openForm(tester, _baseProgram());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.briefSectionProgramIntro), findsOneWidget);
    expect(find.text(l10n.briefSectionProgramComms), findsOneWidget);
    expect(find.text(l10n.briefSectionProgramBeforeRound), findsOneWidget);
  });

  testWidgets('save edits name, description and a brief field', (tester) async {
    Program? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Program>(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      ProgramFormScreen(program: _baseProgram()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Edit name + description.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vinterøvelse'),
      'Vårøvelse',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.programDescription),
      'Ny undertittel',
    );

    // Add the intro brief section and type into it.
    await tester.tap(
      find.widgetWithText(OutlinedButton, l10n.briefSectionProgramIntro),
    );
    await tester.pumpAndSettle();
    final introField = find.widgetWithText(
      TextFormField,
      l10n.briefSectionProgramIntro,
    );
    expect(introField, findsOneWidget);
    await tester.enterText(introField, 'Generelt om spillet ...');

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.name, 'Vårøvelse');
    expect(captured!.description, 'Ny undertittel');
    expect(captured!.briefIntroMd, 'Generelt om spillet ...');
    expect(captured!.commsMd, isNull);
    expect(captured!.beforeRoundMd, isNull);
  });

  testWidgets('seeded optional sections appear pre-active and are editable', (
    tester,
  ) async {
    Program? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Program>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ProgramFormScreen(
                    program: _baseProgram(briefIntroMd: 'gammel intro'),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The intro section is already active; no add-button for it.
    expect(
      find.widgetWithText(OutlinedButton, l10n.briefSectionProgramIntro),
      findsNothing,
    );
    expect(find.text('gammel intro'), findsOneWidget);

    // Replace the content and save.
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.briefSectionProgramIntro),
      'ny intro',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.briefIntroMd, 'ny intro');
  });

  testWidgets('removing an optional section clears its value on save', (
    tester,
  ) async {
    Program? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Program>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ProgramFormScreen(
                    program: _baseProgram(briefIntroMd: 'noe innhold'),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Remove the seeded intro section via its suffix close button. The
    // AppBar leading also uses Icons.close, so scope the finder to the Form.
    await tester.tap(
      find.descendant(of: find.byType(Form), matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.briefIntroMd, isNull);
  });

  testWidgets('selecting a plan language saves languageCode', (tester) async {
    Program? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Program>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ProgramFormScreen(program: _baseProgram()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Norsk').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.metadata.languageCode, 'nb');
  });

  testWidgets('plan language stays null when left untouched', (tester) async {
    Program? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Program>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ProgramFormScreen(program: _baseProgram()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.metadata.languageCode, isNull);
  });
}
