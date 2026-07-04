import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_form_screen.dart';

/// DESIGN-008 Stage 3 — the section-navigated `ProgramFormScreen` behind
/// `RINGDRILL_PLAN_VARIABLES`. `RINGDRILL_PLAN_VARIABLES` is a compile-time
/// `bool.fromEnvironment`, so a widget test cannot flip it with a
/// `--dart-define`; every flag-on test below pumps `ProgramFormScreen` with
/// `debugPlanVariablesOverride: true` (a `@visibleForTesting`-only
/// constructor param) instead. The flag-off path is exercised without the
/// override, and is covered exhaustively by the pre-existing
/// `program_form_screen_test.dart`, which passes unmodified — this file
/// only adds one legacy-marker check for completeness.

Program _baseProgram({
  String? briefIntroMd = 'gammel intro',
  String? commsMd,
  String? beforeRoundMd,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: 'pgm-1',
    name: 'Vinterøvelse',
    description: '',
    metadata: ProgramMetadata(
      created: now,
      updated: now,
      version: '1.0',
      languageCode: 'nb',
    ),
    teams: const [],
    sessions: const [],
    exercises: const [],
    briefIntroMd: briefIntroMd,
    commsMd: commsMd,
    beforeRoundMd: beforeRoundMd,
  );
}

Future<Program?> _openForm(
  WidgetTester tester,
  Program program, {
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
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
                builder: (_) => ProgramFormScreen(
                  program: program,
                  debugPlanVariablesOverride: true,
                ),
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

/// Taps the compact bottom bar's section selector (DESIGN-008 follow-up 04
/// moved it out of the AppBar title into `_CompactBottomBar`). Scoped to
/// [BottomAppBar] because the current section's own label often repeats
/// elsewhere on screen — e.g. as a [TextFormField]'s floating label once
/// that section is selected.
Future<void> _tapSwitcher(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(BottomAppBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ProgramFormScreen — section-navigated (RINGDRILL_PLAN_VARIABLES)', () {
    testWidgets(
      'compact: switcher lists active sections and switches between them',
      (tester) async {
        await _openForm(
          tester,
          _baseProgram(commsMd: 'gamle talegrupper'),
          size: const Size(400, 800),
        );
        final l = await AppLocalizations.delegate.load(const Locale('en'));

        // Plan is selected initially; its fields render.
        expect(find.text('Vinterøvelse'), findsOneWidget);
        expect(find.text(l.briefSectionProgramIntro), findsNothing);

        // Open the switcher via the AppBar title and select "Intro".
        await _tapSwitcher(tester, l.programSectionPlan);
        expect(find.text(l.briefSectionProgramIntro), findsWidgets);
        expect(find.text(l.briefSectionProgramComms), findsOneWidget);
        await tester.tap(find.text(l.briefSectionProgramIntro).first);
        await tester.pumpAndSettle();

        expect(find.text('gammel intro'), findsOneWidget);
        expect(find.text('Vinterøvelse'), findsNothing);

        // Switch again, to "Comms".
        await _tapSwitcher(tester, l.briefSectionProgramIntro);
        await tester.tap(find.text(l.briefSectionProgramComms));
        await tester.pumpAndSettle();
        expect(find.text('gamle talegrupper'), findsOneWidget);
      },
    );

    testWidgets(
      'compact: "Add section" reveals and activates an inactive section',
      (tester) async {
        await _openForm(
          tester,
          _baseProgram(commsMd: null, beforeRoundMd: null),
          size: const Size(400, 800),
        );
        final l = await AppLocalizations.delegate.load(const Locale('en'));

        await tester.tap(find.text(l.programSectionPlan));
        await tester.pumpAndSettle();

        // "Comms" is not active yet, so it is not listed directly...
        expect(find.text(l.briefSectionProgramComms), findsNothing);

        // ...until "Add section" is tapped to reveal it.
        await tester.tap(find.text(l.formSectionAddAction));
        await tester.pumpAndSettle();
        expect(find.text(l.briefSectionProgramComms), findsOneWidget);

        await tester.tap(find.text(l.briefSectionProgramComms));
        await tester.pumpAndSettle();

        // The newly-activated section is selected and its (empty) field is
        // editable.
        final field = find.widgetWithText(
          TextFormField,
          l.briefSectionProgramComms,
        );
        expect(field, findsOneWidget);
        await tester.enterText(field, 'nye talegrupper');
        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'compact: removing the current section falls back to "Plan"; '
      '"Plan" itself offers a disabled remove action',
      (tester) async {
        await _openForm(
          tester,
          _baseProgram(commsMd: 'gamle talegrupper'),
          size: const Size(400, 800),
        );
        final l = await AppLocalizations.delegate.load(const Locale('en'));

        // The overflow is always rendered now (DESIGN-008 follow-up 02, so
        // the prev/next controls next to it never shift), but disabled on
        // the non-removable default "Plan" section — tapping it opens
        // nothing.
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text(l.formSectionRemoveAction), findsNothing);

        await tester.tap(find.text(l.programSectionPlan));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.briefSectionProgramComms));
        await tester.pumpAndSettle();

        // "Comms" is removable: its overflow menu offers "Remove section".
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.formSectionRemoveAction));
        await tester.pumpAndSettle();

        // Falls back to the default section, where the overflow is
        // disabled again.
        expect(find.text(l.programSectionPlan), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text(l.formSectionRemoveAction), findsNothing);

        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'wide: rail lists sections, detail pane switches, no duplicate '
      'AppBar or close button',
      (tester) async {
        await _openForm(
          tester,
          _baseProgram(commsMd: 'gamle talegrupper'),
          size: const Size(1200, 900),
        );
        final l = await AppLocalizations.delegate.load(const Locale('en'));

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.text(l.programSectionPlan), findsWidgets);
        expect(find.text(l.briefSectionProgramIntro), findsOneWidget);
        expect(find.text(l.briefSectionProgramComms), findsOneWidget);

        // Plan's fields render in the detail pane by default.
        expect(find.text('Vinterøvelse'), findsOneWidget);

        await tester.tap(find.text(l.briefSectionProgramComms));
        await tester.pumpAndSettle();
        expect(find.text('gamle talegrupper'), findsOneWidget);
        expect(find.text('Vinterøvelse'), findsNothing);
      },
    );

    testWidgets(
      'flag-off: the legacy single-scroll OptionalFieldSections form renders',
      (tester) async {
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
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final l = await AppLocalizations.delegate.load(const Locale('en'));

        // A marker unique to the legacy single-scroll body: an inactive
        // optional section shows as an add-button, a widget type the
        // section-navigated body never renders.
        expect(
          find.widgetWithText(OutlinedButton, l.briefSectionProgramComms),
          findsOneWidget,
        );
        expect(result, isNull);
      },
    );

    testWidgets(
      'save round-trips a name edit in "Plan" and a markdown section edit',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
                        program: _baseProgram(),
                        debugPlanVariablesOverride: true,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );
        final l = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Vinterøvelse'),
          'Vårøvelse',
        );

        await _tapSwitcher(tester, l.programSectionPlan);
        await tester.tap(find.text(l.briefSectionProgramIntro));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, l.briefSectionProgramIntro),
          'ny intro',
        );

        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();

        expect(captured, isNotNull);
        expect(captured!.name, 'Vårøvelse');
        expect(captured!.briefIntroMd, 'ny intro');
      },
    );
  });
}
