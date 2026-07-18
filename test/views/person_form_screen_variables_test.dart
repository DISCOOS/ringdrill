import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-009 follow-up 4e — `PersonFormScreen`'s `name`/`signalement`/
/// `notes` fields: token-aware chip rendering, the insertion menu (plan
/// variables and `station.loc/person.*` cross-references), the
/// self-reference rule (`name` withholds its own `station.person` name
/// facet and bare default for the entity it is editing; `signalement`
/// withholds only its own
/// `signalement` facet; `notes` has no matching facet to withhold in the
/// first place), and the save-time unresolved-reference block (ADR-0047).
/// No preview toggle exists on this plain (non-section-navigated) form, so
/// resolution is checked via `resolveScopedField` directly, mirroring
/// `location_form_screen_variables_test.dart`.

class _Captured {
  PersonFormResult? value;
}

Future<void> _open(
  WidgetTester tester,
  _Captured captured, {
  Person? initial,
  List<Location> locations = const [],
  Set<String> existingSlugs = const {},
  List<DrillVariable> variables = const [],
  List<Person> stationPersons = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<PersonFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => PlanScope(
                  variables: variables,
                  child: StationScope(
                    locations: locations,
                    persons: stationPersons,
                    child: PersonFormScreen(
                      existingSlugs: existingSlugs,
                      locations: locations,
                      initial: initial,
                    ),
                  ),
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
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'the name field offers a declared plan variable and inserts its exact '
    'token',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        variables: const [DrillVariable(name: 'kanal', value: 'Kanal 6')],
      );

      final nameField = find.widgetWithText(TextFormField, l.roleName);
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, '{{var.');
      await tester.pump();
      await tester.pump();

      expect(find.text('kanal'), findsOneWidget);

      await tester.tap(find.text('kanal'));
      await tester.pump();

      expect(find.textContaining('{{var.kanal}}'), findsOneWidget);
    },
  );

  testWidgets(
    'the name field offers other persons but withholds its own name facet '
    'and bare default (self-reference rule, DESIGN-009)',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        initial: const Person(slug: 'anne', name: 'Anne Glemsk'),
        stationPersons: const [
          Person(slug: 'anne', name: 'Anne Glemsk'),
          Person(slug: 'ola', name: 'Ola Normann'),
        ],
      );

      final nameField = find.widgetWithText(TextFormField, l.roleName);
      await tester.ensureVisible(nameField);
      // No dot yet: the bare browsing list -- self's bare entry (its own
      // name, title *and* preview) is withheld here; another person's isn't.
      await tester.enterText(nameField, '{{station.person.');
      await tester.pump();
      await tester.pump();

      final menu = find.byType(ListView);
      expect(
        find.descendant(of: menu, matching: find.text('Ola Normann')),
        findsWidgets,
      );
      expect(
        find.descendant(of: menu, matching: find.text('Anne Glemsk')),
        findsNothing,
      );

      // One dot: facet completion always drops the bare entry regardless of
      // self-reference (pre-existing behaviour, DESIGN-009 follow-up 4d) --
      // this only checks that the withheld facet is `name`, not that the
      // bare entry reappears here.
      await tester.enterText(nameField, '{{station.person.anne.');
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: menu, matching: find.text(l.roleAge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text(l.roleName)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the signalement field withholds only its own signalement facet, not '
    'its own bare default (self-reference rule, DESIGN-009)',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        initial: const Person(slug: 'anne', name: 'Anne Glemsk'),
        stationPersons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );

      final signalementField = find.widgetWithText(
        TextFormField,
        l.roleSignalement,
      );
      await tester.ensureVisible(signalementField);

      // No dot yet: the bare browsing list -- unlike the name field, the
      // signalement field never withholds its own bare entry (the bare
      // default reads the person's *name*, not their signalement, so there
      // is no recursion risk).
      await tester.enterText(signalementField, '{{station.person.');
      await tester.pump();
      await tester.pump();

      final menu = find.byType(ListView);
      expect(
        find.descendant(of: menu, matching: find.text('Anne Glemsk')),
        findsWidgets,
      );

      // One dot: only the `signalement` facet itself is withheld; other
      // facets of the same (self) entity stay offered.
      await tester.enterText(signalementField, '{{station.person.anne.');
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: menu, matching: find.text(l.roleSignalement)),
        findsNothing,
      );
      expect(
        find.descendant(of: menu, matching: find.text(l.roleAge)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an unresolved station.person reference in the notes field blocks '
    'save; removing it unblocks',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleName),
        'Anne',
      );
      final notesField = find.widgetWithText(
        TextFormField,
        l.personsSectionNotesLabel,
      );
      await tester.ensureVisible(notesField);
      await tester.enterText(notesField, 'Se {{station.person.ghost}}.');

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(
          l.saveBlockedUnresolvedReference(
            l.personsSectionNotesLabel,
            'station.person.ghost',
          ),
        ),
        findsOneWidget,
      );

      await tester.enterText(notesField, 'Ingen merknad.');
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.person.notes, 'Ingen merknad.');
    },
  );

  testWidgets(
    'a var.* token entered in the notes field resolves via '
    'resolveScopedField -- no preview toggle on this plain form, so the '
    "brief's own fixpoint pass is what catches it once saved (no renderer "
    'change needed)',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        variables: const [DrillVariable(name: 'kanal', value: 'Kanal 6')],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleName),
        'Anne',
      );
      final notesField = find.widgetWithText(
        TextFormField,
        l.personsSectionNotesLabel,
      );
      await tester.ensureVisible(notesField);
      await tester.enterText(notesField, 'Bruk {{var.kanal}}.');
      await tester.pump();

      final context = tester.element(find.byType(PersonFormScreen));
      expect(
        resolveScopedField(context, 'Bruk {{var.kanal}}.'),
        'Bruk Kanal 6.',
      );
    },
  );
}
