import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_form_screen.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';
import 'package:ringdrill/views/widgets/variable_value_field.dart';

/// DESIGN-008 Stage 5 (+ follow-ups 01, 11, 12) — the Variabler declaration
/// section end-to-end inside the Program editor: declare (name+hint only),
/// expand a card to set its type/value/hint, rename (plan-wide rewrite),
/// delete via the context menu and via swipe (both reference-guarded), and
/// save-time validation.

Program _program({
  String? briefIntroMd,
  String? commsMd,
  List<DrillVariable> variables = const [],
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: 'pgm-1',
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
    briefIntroMd: briefIntroMd,
    commsMd: commsMd,
    variables: variables,
  );
}

/// Mutable holder for the popped [Program], since the value only becomes
/// available once Save is eventually tapped — long after `_openForm`
/// itself has returned (it only opens the form; awaiting `_openForm` does
/// NOT wait for the editor to close).
class _Captured {
  Program? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Program program,
  _Captured captured,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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

/// Opens the section switcher sheet by tapping the current section's label
/// in the compact bottom bar (DESIGN-008 follow-up 04 — the switcher moved
/// out of the AppBar title into `_CompactBottomBar`).
Future<void> _openSwitcherFrom(WidgetTester tester, String currentLabel) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.text(currentLabel),
    ),
  );
  await tester.pumpAndSettle();
}

/// The chip color `TokenTextEditingController` assigned to [token] (the
/// full `{{var.<name>}}` text) in the currently visible token-aware field —
/// blue (known), amber (declared-but-empty) or red (undeclared). Reads the
/// live [EditableText]'s controller directly rather than a screenshot, so
/// it survives whatever the actual pixel color happens to be.
Color? _tokenChipColor(WidgetTester tester, String token) {
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

/// The declaration card for the variable named [name] (DESIGN-008
/// follow-up 12 — one collapsible card per variable, mirroring the
/// RolePlay "Identitet" card). Keyed off the card's own `Dismissible`
/// (`ValueKey(variable.name)`) rather than an ancestor-of-type search, so
/// this stays correct regardless of the card's internal widget shape
/// (a bordered `Container`, not a `Card`, per the Identitet mirror).
Finder _variableCardOf(String name) => find.byKey(ValueKey(name));

/// Expands [name]'s card by tapping its "Tilpass" disclosure bar — a no-op
/// if already expanded. Every value/type/hint/rename/delete interaction
/// below requires the card to be expanded first, per DESIGN-008 follow-up
/// 12 (only the name + formatted value are visible collapsed).
Future<void> _expandCard(
  WidgetTester tester,
  AppLocalizations l,
  String name,
) async {
  final tilpass = find.descendant(
    of: _variableCardOf(name),
    matching: find.text(l.variablesSectionCustomizeAction),
  );
  if (find.descendant(
    of: _variableCardOf(name),
    matching: find.byIcon(Icons.keyboard_arrow_up),
  ).evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(tilpass);
  await tester.pumpAndSettle();
}

/// The `⋮` context menu in [name]'s header — only present once the card is
/// expanded (DESIGN-008 follow-up 12); call [_expandCard] first.
Finder _variableCardMenu(String name) => find.descendant(
  of: _variableCardOf(name),
  matching: find.byIcon(Icons.more_vert),
);

/// The inline type-aware value field on [name]'s *expanded* card — distinct
/// from the hint field, which is a plain sibling `TextFormField` outside
/// [VariableValueField].
Finder _variableValueFieldOf(String name) => find.descendant(
  of: find.descendant(
    of: _variableCardOf(name),
    matching: find.byType(VariableValueField),
  ),
  matching: find.byType(TextFormField),
).first;

/// Swipes [name]'s card end-to-start past the dismiss threshold — the same
/// offset `station_form_screen_locations_persons_test.dart` uses for
/// Persons/Locations' own swipe-to-delete.
Future<void> _swipeToDelete(WidgetTester tester, String name) async {
  await tester.drag(_variableCardOf(name), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'declare a variable (name + hint only), expand its card to set a '
    'value, reference it, save: the popped Program has both',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _program(briefIntroMd: 'Intro'), captured);

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.variablesSectionAddAction));
      await tester.pumpAndSettle();
      // Only name + hint in the creation dialog — no value field.
      expect(
        find.widgetWithText(TextFormField, l.variablesSectionValueLabel),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.variablesSectionNameLabel),
        'frekvens',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l.variablesSectionAddAction),
      );
      await tester.pumpAndSettle();
      expect(find.text('frekvens'), findsOneWidget);
      expect(find.text(l.variablesSectionNoValuePlaceholder), findsOneWidget);

      await _expandCard(tester, l, 'frekvens');
      await tester.enterText(_variableValueFieldOf('frekvens'), 'Kanal 6');
      await tester.pumpAndSettle();

      await _openSwitcherFrom(tester, l.variablesSectionTitle);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.briefSectionProgramIntro),
        'Kanal {{var.frekvens}}',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      final saved = captured.value!;
      expect(saved.variables.single.name, 'frekvens');
      expect(saved.variables.single.value, 'Kanal 6');
      expect(saved.briefIntroMd, 'Kanal {{var.frekvens}}');
    },
  );

  testWidgets(
    'create-inline via the insertion menu declares an empty (amber) variable',
    (tester) async {
      await _openForm(tester, _program(briefIntroMd: 'Intro'), _Captured());

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Intro /freken');
      await tester.pump();
      await tester.pump();

      final createLabel = l.tokenMenuCreateVariable('freken');
      expect(find.text(createLabel), findsOneWidget);
      await tester.tap(find.text(createLabel));
      await tester.pump();

      expect(find.textContaining('{{var.freken}}'), findsOneWidget);

      await _openSwitcherFrom(tester, l.briefSectionProgramIntro);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text('freken'), findsOneWidget);
      // Declared but empty: the collapsed card shows the placeholder.
      expect(find.text(l.variablesSectionNoValuePlaceholder), findsOneWidget);
    },
  );

  testWidgets(
    'the ⋮ menu only appears once the card is expanded (DESIGN-008 '
    'follow-up 12)',
    (tester) async {
      await _openForm(
        tester,
        _program(
          variables: const [DrillVariable(name: 'frekvens', value: 'X')],
        ),
        _Captured(),
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      // Collapsed: neither the panel content nor the ⋮ menu is showing.
      expect(find.byType(VariableValueField), findsNothing);
      expect(_variableCardMenu('frekvens'), findsNothing);

      await _expandCard(tester, l, 'frekvens');
      expect(_variableCardMenu('frekvens'), findsOneWidget);

      await tester.tap(_variableCardMenu('frekvens'));
      await tester.pumpAndSettle();
      expect(find.text(l.variablesSectionRenameAction), findsOneWidget);
      expect(find.text(l.variablesSectionDeleteAction), findsOneWidget);
    },
  );

  testWidgets(
    'expanding a card collapses whichever other card was expanded '
    '(DESIGN-008 follow-up 12: mutually exclusive expansion)',
    (tester) async {
      await _openForm(
        tester,
        _program(
          variables: const [
            DrillVariable(name: 'frekvens', value: 'Kanal 6'),
            DrillVariable(name: 'talegruppe', value: 'VFOLD'),
          ],
        ),
        _Captured(),
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      await _expandCard(tester, l, 'frekvens');
      expect(find.byType(VariableValueField), findsOneWidget);

      await _expandCard(tester, l, 'talegruppe');
      // Only the newly expanded card's panel is showing — "frekvens"
      // collapsed back automatically.
      expect(find.byType(VariableValueField), findsOneWidget);
      expect(
        find.descendant(
          of: _variableCardOf('talegruppe'),
          matching: find.byType(VariableValueField),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _variableCardOf('frekvens'),
          matching: find.byType(VariableValueField),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('renaming a variable rewrites every reference in the editor', (
    tester,
  ) async {
    await _openForm(
      tester,
      _program(
        briefIntroMd: 'Kanal {{var.frekvens}}',
        commsMd: 'Bruk {{var.frekvens}} her også',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      ),
      _Captured(),
    );

    await _openSwitcherFrom(tester, l.programSectionPlan);
    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();
    await _expandCard(tester, l, 'frekvens');
    await tester.tap(_variableCardMenu('frekvens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.variablesSectionRenameAction));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, l.variablesSectionNameLabel),
      'kanal',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l.variablesSectionRenameAction),
    );
    await tester.pumpAndSettle();
    // Confirmation dialog (referenced twice).
    await tester.tap(
      find.widgetWithText(FilledButton, l.variablesSectionRenameAction),
    );
    await tester.pumpAndSettle();

    expect(find.text('kanal'), findsOneWidget);
    expect(find.text('frekvens'), findsNothing);

    await _openSwitcherFrom(tester, l.variablesSectionTitle);
    await tester.tap(find.text(l.briefSectionProgramIntro));
    await tester.pumpAndSettle();
    expect(find.text('Kanal {{var.kanal}}'), findsOneWidget);

    await _openSwitcherFrom(tester, l.briefSectionProgramIntro);
    await tester.tap(find.text(l.briefSectionProgramComms));
    await tester.pumpAndSettle();
    expect(find.text('Bruk {{var.kanal}} her også'), findsOneWidget);
  });

  testWidgets(
    'delete via the context menu is blocked while referenced, and removes '
    'once unreferenced',
    (tester) async {
      await _openForm(
        tester,
        _program(
          briefIntroMd: 'Kanal {{var.frekvens}}',
          variables: const [
            DrillVariable(name: 'frekvens', value: 'Kanal 6'),
            DrillVariable(name: 'ubrukt', value: 'X'),
          ],
        ),
        _Captured(),
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      // Referenced: blocked.
      await _expandCard(tester, l, 'frekvens');
      await tester.tap(_variableCardMenu('frekvens'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.variablesSectionDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text(l.variablesSectionDeleteBlockedTitle), findsOneWidget);
      await tester.tap(find.text(l.ok));
      await tester.pumpAndSettle();
      expect(find.text('frekvens'), findsOneWidget);

      // Unreferenced: removes immediately.
      await _expandCard(tester, l, 'ubrukt');
      await tester.tap(_variableCardMenu('ubrukt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.variablesSectionDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text('ubrukt'), findsNothing);
      expect(find.text('frekvens'), findsOneWidget);
    },
  );

  testWidgets(
    'swiping a card deletes it when unreferenced, and snaps back (blocked '
    'dialog) when referenced (DESIGN-008 follow-up 12)',
    (tester) async {
      await _openForm(
        tester,
        _program(
          briefIntroMd: 'Kanal {{var.frekvens}}',
          variables: const [
            DrillVariable(name: 'frekvens', value: 'Kanal 6'),
            DrillVariable(name: 'ubrukt', value: 'X'),
          ],
        ),
        _Captured(),
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      // Referenced: the blocked dialog appears and the card survives.
      await _swipeToDelete(tester, 'frekvens');
      expect(find.text(l.variablesSectionDeleteBlockedTitle), findsOneWidget);
      await tester.tap(find.text(l.ok));
      await tester.pumpAndSettle();
      expect(find.text('frekvens'), findsOneWidget);

      // Unreferenced: swiping removes it with no extra confirmation, the
      // same as the context-menu delete action.
      await _swipeToDelete(tester, 'ubrukt');
      expect(find.text('ubrukt'), findsNothing);
      expect(find.text('frekvens'), findsOneWidget);
    },
  );

  testWidgets('delete is blocked when the only reference is an exercise name '
      '(DESIGN-008 follow-up 10 regression)', (tester) async {
    final exercise = Exercise(
      uuid: 'ex-1',
      name: 'Øvelse {{var.frekvens}}',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: const [],
      schedule: const [],
    );
    await _openForm(
      tester,
      _program(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      ).copyWith(exercises: [exercise]),
      _Captured(),
    );

    await _openSwitcherFrom(tester, l.programSectionPlan);
    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();
    await _expandCard(tester, l, 'frekvens');
    await tester.tap(_variableCardMenu('frekvens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.variablesSectionDeleteAction));
    await tester.pumpAndSettle();

    expect(find.text(l.variablesSectionDeleteBlockedTitle), findsOneWidget);
    await tester.tap(find.text(l.ok));
    await tester.pumpAndSettle();
    expect(find.text('frekvens'), findsOneWidget);
  });

  testWidgets(
    'save is blocked on an undeclared token, and declaring it unblocks save',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _program(briefIntroMd: 'Kanal {{var.mangler}}'),
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.variablesSectionAddAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.variablesSectionNameLabel),
        'mangler',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l.variablesSectionAddAction),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value;
      expect(saved, isNotNull);
      expect(saved!.variables.single.name, 'mangler');
    },
  );

  testWidgets(
    'a declared-but-empty variable referenced in a field saves fine',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _program(
          briefIntroMd: 'Verdi:[{{var.tom}}]',
          variables: const [DrillVariable(name: 'tom')],
        ),
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value;
      expect(saved, isNotNull);
      expect(saved!.briefIntroMd, 'Verdi:[{{var.tom}}]');
    },
  );

  testWidgets('creating an invalid slug or a duplicate name is rejected', (
    tester,
  ) async {
    await _openForm(
      tester,
      _program(
        variables: const [DrillVariable(name: 'frekvens', value: 'X')],
      ),
      _Captured(),
    );

    await _openSwitcherFrom(tester, l.programSectionPlan);
    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.variablesSectionAddAction));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, l.variablesSectionNameLabel),
      '1bad',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l.variablesSectionAddAction),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.variablesSectionInvalidSlugError), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, l.variablesSectionNameLabel),
      'frekvens',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l.variablesSectionAddAction),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.variablesSectionDuplicateNameError), findsOneWidget);
  });

  testWidgets(
    'editing a declared-but-empty variable\'s value re-resolves its chip '
    'from amber to blue and saves the new value',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _program(
          briefIntroMd: 'Kanal {{var.frekvens}}',
          variables: const [DrillVariable(name: 'frekvens')],
        ),
        captured,
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();
      expect(
        _tokenChipColor(tester, '{{var.frekvens}}'),
        Colors.amber.shade900,
      );

      await _openSwitcherFrom(tester, l.briefSectionProgramIntro);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      await _expandCard(tester, l, 'frekvens');
      await tester.enterText(_variableValueFieldOf('frekvens'), 'Kanal 6');
      await tester.pumpAndSettle();
      // Shows twice while expanded: the collapsed-style summary above the
      // panel and the live value field itself, both reading "Kanal 6".
      expect(find.text('Kanal 6'), findsWidgets);

      await _openSwitcherFrom(tester, l.variablesSectionTitle);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();
      expect(_tokenChipColor(tester, '{{var.frekvens}}'), Colors.blue.shade800);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value;
      expect(saved, isNotNull);
      expect(saved!.variables.single.value, 'Kanal 6');
    },
  );

  testWidgets(
    'editing a variable\'s value leaves its name and references untouched',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _program(
          briefIntroMd: 'Kanal {{var.frekvens}}',
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        ),
        captured,
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      await _expandCard(tester, l, 'frekvens');
      await tester.enterText(_variableValueFieldOf('frekvens'), 'Kanal 8');
      await tester.pumpAndSettle();
      expect(find.text('frekvens'), findsOneWidget);
      // Shows twice while expanded: the summary above the panel and the
      // live value field itself.
      expect(find.text('Kanal 8'), findsWidgets);

      await _openSwitcherFrom(tester, l.variablesSectionTitle);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();
      // The reference is unchanged — {{var.frekvens}}, not rewritten to
      // some other name.
      expect(find.text('Kanal {{var.frekvens}}'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value;
      expect(saved, isNotNull);
      expect(saved!.variables.single.name, 'frekvens');
      expect(saved.briefIntroMd, 'Kanal {{var.frekvens}}');
    },
  );

  testWidgets('editing a variable\'s hint persists it on save', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      _program(
        variables: const [DrillVariable(name: 'frekvens', value: 'X')],
      ),
      captured,
    );

    await _openSwitcherFrom(tester, l.programSectionPlan);
    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();

    await _expandCard(tester, l, 'frekvens');
    await tester.enterText(
      find.widgetWithText(TextFormField, l.variablesSectionHintLabel),
      'Radiokanal',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    final saved = captured.value;
    expect(saved, isNotNull);
    expect(saved!.variables.single.hint, 'Radiokanal');
    expect(saved.variables.single.value, 'X');
  });

  testWidgets(
    'changing a type re-validates the kept default: an incompatible value '
    'blocks save inline, cross-section via the snackbar, and a fixed value '
    'saves canonical (DESIGN-008 follow-up 11)',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _program(
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        ),
        captured,
      );

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();
      await _expandCard(tester, l, 'frekvens');

      // Change the type via the card's type dropdown: Text → Number. The
      // kept value "Kanal 6" no longer reads as the type.
      await tester.tap(
        find.descendant(
          of: _variableCardOf('frekvens'),
          matching: find.byType(DropdownButtonFormField<VariableType>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.variableTypeLabelNumber));
      await tester.pumpAndSettle();

      // Surfaced inline rather than silently dropped, and save is blocked.
      expect(find.text(l.variableValueInvalidNumber), findsOneWidget);
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);

      // Blocked from another section too — the state-level gate, since the
      // Variabler section (and its inline validator) is no longer mounted.
      await _openSwitcherFrom(tester, l.variablesSectionTitle);
      await tester.tap(find.text(l.programSectionPlan));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);
      expect(
        find.text(l.variableSaveBlockedInvalidValue('frekvens')),
        findsOneWidget,
      );

      // A valid value unblocks; "3,14" stores canonical "3.14".
      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();
      await _expandCard(tester, l, 'frekvens');
      await tester.enterText(_variableValueFieldOf('frekvens'), '3,14');
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value;
      expect(saved, isNotNull);
      expect(saved!.variables.single.type, VariableType.number);
      expect(saved.variables.single.value, '3.14');
    },
  );

  testWidgets(
    'create-inline then expand-to-set-value closes the loop without ever '
    'deleting',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _program(briefIntroMd: 'Intro'), captured);

      await _openSwitcherFrom(tester, l.programSectionPlan);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Intro /freken');
      await tester.pump();
      await tester.pump();

      final createLabel = l.tokenMenuCreateVariable('freken');
      await tester.tap(find.text(createLabel));
      await tester.pump();
      expect(_tokenChipColor(tester, '{{var.freken}}'), Colors.amber.shade900);

      await _openSwitcherFrom(tester, l.briefSectionProgramIntro);
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      // Never blocked or deleted despite being referenced — expanding and
      // setting the value just works.
      await _expandCard(tester, l, 'freken');
      await tester.enterText(_variableValueFieldOf('freken'), 'Kanal 6');
      await tester.pumpAndSettle();
      expect(find.text('freken'), findsOneWidget);
      // Shows twice while expanded: the summary above the panel and the
      // live value field itself.
      expect(find.text('Kanal 6'), findsWidgets);

      await _openSwitcherFrom(tester, l.variablesSectionTitle);
      await tester.tap(find.text(l.briefSectionProgramIntro));
      await tester.pumpAndSettle();
      expect(_tokenChipColor(tester, '{{var.freken}}'), Colors.blue.shade800);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value?.variables.single.value, 'Kanal 6');
    },
  );
}
